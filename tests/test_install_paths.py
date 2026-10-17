import argparse
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


CMAKE = "cmake"
SCRIPT_DIR = Path(__file__).resolve().parent / "cmake"


class InstallPathTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="cwhip-install-paths-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.source = self.root / "cwhip"
        self.build = self.root / "build [debug]+"
        self.source.mkdir()
        self.build.mkdir()

    def run_script(self, body, *, temporary_root=None):
        script = self.root / "check.cmake"
        script.write_text(
            "cmake_minimum_required(VERSION 3.16)\n"
            f'set(SOURCE_DIR "{self.source}")\n'
            f'set(BUILD_DIR "{self.build}")\n'
            f'include("{SCRIPT_DIR}/InstallLayoutPaths.cmake")\n'
            + body,
            encoding="utf-8",
        )
        environment = os.environ.copy()
        if temporary_root is not None:
            environment["TMPDIR"] = str(temporary_root)
        return subprocess.run(
            [CMAKE, "-P", str(script)], env=environment,
            capture_output=True, text=True, check=False,
        )

    def check_directory(self, directory, *, rejected):
        result = self.run_script(f'require_external_install_directory("{directory}")\n')
        if rejected:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("must be outside", result.stderr)
        else:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_directory_boundaries(self):
        for root in (self.source, self.build):
            for suffix, rejected in (
                ("", True), ("/", True), ("/tmp/new", True),
                ("-workspace/tmp/new", False), ("2/tmp/new", False),
            ):
                with self.subTest(root=root, suffix=suffix):
                    self.check_directory(str(root) + suffix, rejected=rejected)
        self.check_directory(self.root, rejected=False)
        self.check_directory(self.root / "outside/../cwhip/tmp", rejected=True)
        self.check_directory(self.source / "../cwhip-workspace/tmp", rejected=False)

    def test_symlink_boundaries(self):
        sibling = self.root / "cwhip-workspace"
        sibling.mkdir()
        for root in (self.source, self.build):
            alias = self.root / "alias"
            alias.symlink_to(root, target_is_directory=True)
            self.check_directory(alias / "new", rejected=True)
            alias.unlink()
        alias = self.source / "external"
        alias.symlink_to(sibling, target_is_directory=True)
        self.check_directory(alias / "new", rejected=False)
        original_source = self.source
        self.source = self.root / "source-alias"
        self.source.symlink_to(original_source, target_is_directory=True)
        self.check_directory(original_source / "new", rejected=True)

    def test_output_references(self):
        for root in (self.source, self.build):
            for suffix, rejected in (
                ("", True), ("/file.cw", True), (" (default)", True),
                ('"', True), ("'", True), (")", True), ("]", True),
                (";", True), (":", True), (",", True), ("\n", True),
                ("-workspace/tmp/file.cw", False), ("2/file.cw", False),
            ):
                with self.subTest(root=root, suffix=suffix):
                    text = str(root) + suffix
                    result = self.run_script(
                        f'require_no_tree_references([==[{text}]==] "fixture")\n'
                    )
                    if rejected:
                        self.assertNotEqual(result.returncode, 0, result.stderr)
                        self.assertIn("references the source or build tree", result.stderr)
                    else:
                        self.assertEqual(result.returncode, 0, result.stderr)

    def test_output_references_canonical_source(self):
        original_source = self.source
        self.source = self.root / "source-alias"
        self.source.symlink_to(original_source, target_is_directory=True)
        result = self.run_script(
            f'require_no_tree_references("{original_source}/file.cw" "fixture")\n'
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("references the source or build tree", result.stderr)

    def test_output_reference_after_sibling(self):
        result = self.run_script(
            f'require_no_tree_references("{self.source}-workspace/file.cw '
            f'{self.source}/file.cw" "fixture")\n'
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("references the source or build tree", result.stderr)

    def test_rejected_tmpdir_is_untouched(self):
        alias = self.root / "alias"
        alias.symlink_to(self.source, target_is_directory=True)
        for root in (self.source, self.build, alias):
            marker = root / "keep"
            marker.write_text("preserve me", encoding="utf-8")
            before = sorted(root.iterdir())
            result = self.run_script(
                "foreach(required IN ITEMS FIXTURE MODULE_FIXTURE EXPECTED_OUTPUT_FILE "
                "BINDIR LIBDIR INCLUDEDIR DATADIR DOCDIR MANDIR RUNTIME_LIBRARY_NAME CLANG)\n"
                '    set(${required} "unused")\n'
                "endforeach()\n"
                f'include("{SCRIPT_DIR}/InstallLayoutTest.cmake")\n',
                temporary_root=root,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("must be outside", result.stderr)
            self.assertEqual(sorted(root.iterdir()), before)
            self.assertEqual(marker.read_text(encoding="utf-8"), "preserve me")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--cmake", default="cmake")
    arguments, remaining = parser.parse_known_args()
    CMAKE = arguments.cmake
    unittest.main(argv=[__file__, *remaining])
