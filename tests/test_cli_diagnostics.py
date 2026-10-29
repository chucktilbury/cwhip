#!/usr/bin/env python3
"""Offline checks of the compiler/package diagnostic contract."""

import argparse
import errno
import hashlib
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import tomllib
import unittest


class DiagnosticTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="cwhip-diagnostics-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.environment = {
            key: value for key, value in os.environ.items()
            if not key.startswith("CWHIP_") and key not in ("CC", "XDG_CONFIG_HOME")
        }
        self.environment.update(HOME=str(self.root), XDG_CONFIG_HOME=str(self.root / "config"))
        self.source = self.root / "source.cw"
        self.source.write_text("start {}\n", encoding="utf-8")

    def run_tool(self, tool, *arguments, env=None, cwd=None):
        return subprocess.run(
            [str(tool), *map(str, arguments)], cwd=cwd or self.root,
            env={**self.environment, **(env or {})}, text=True,
            capture_output=True, timeout=30, check=False,
        )

    def assert_error(self, result, tool, code, status):
        self.assertEqual(result.returncode, status, result.stdout + result.stderr)
        self.assertEqual(result.stdout, "")
        self.assertIn(f"{tool}: error[{code}]: ", result.stderr)
        self.assertNotIn("\x1b", result.stderr)
        self.assertNotIn("Traceback", result.stderr)

    def test_compiler_usage_and_input(self):
        for arguments in ([], ["--not-an-option"], ["--trace", "invalid"],
                          ["--verbosity", "4"], ["--check-only", "-c", self.source]):
            with self.subTest(arguments=arguments):
                result = self.run_tool(self.args.compiler, *arguments)
                self.assert_error(result, "cwhip", "CWHIP0001", 2)
        result = self.run_tool(self.args.compiler, self.root / "missing.cw")
        self.assert_error(result, "cwhip", "CWHIP0002", 2)
        self.assertIn(str(self.root / "missing.cw"), result.stderr)

    def test_source_location_and_include_detail(self):
        self.source.write_text("start {\n @\n}\n", encoding="utf-8")
        result = self.run_tool(self.args.compiler, self.source, "--check-only")
        self.assert_error(result, "cwhip", "CWHIP1001", 1)
        self.assertIn(f"{self.source}:2:2: error: unexpected character\n", result.stderr)
        self.source.write_text('include "absent.cw"\nstart {}\n', encoding="utf-8")
        result = self.run_tool(self.args.compiler, self.source, "--check-only")
        self.assert_error(result, "cwhip", "CWHIP1001", 1)
        self.assertIn(f"{self.source}:1:9: error: cannot resolve included source 'absent.cw'",
                      result.stderr)

    def test_recovers_later_errors(self):
        self.source.write_text(
            "start {\n"
            " int64 a = \"no\"\n"
            " int64 b = missing\n"
            "}\n",
            encoding="utf-8",
        )
        result = self.run_tool(self.args.compiler, self.source, "--check-only")
        self.assert_error(result, "cwhip", "CWHIP1001", 1)
        self.assertEqual(result.stderr.count(": error:"), 2)
        self.assertIn("cannot initialize int64 variable with String", result.stderr)
        self.assertIn("undefined variable 'missing'", result.stderr)
        self.assertNotIn("built ", result.stdout)

    def test_semantic_detail(self):
        self.source.write_text("start {\n print(missing)\n}\n", encoding="utf-8")
        result = self.run_tool(self.args.compiler, self.source, "--check-only")
        self.assert_error(result, "cwhip", "CWHIP1001", 1)
        self.assertRegex(result.stderr, r":2:\d+: error: undefined variable 'missing'")

    def test_sdk_and_no_selection_fallback(self):
        result = self.run_tool(self.args.compiler, "--print-paths",
                               env={"XDG_CONFIG_HOME": "relative"})
        self.assert_error(result, "cwhip", "CWHIP2001", 1)
        result = self.run_tool(self.args.compiler, self.source,
                               env={"CWHIP_RUNTIME_DIR": str(self.root / "absent")})
        self.assert_error(result, "cwhip", "CWHIP2001", 1)
        self.assertIn("CWHIP_RUNTIME_DIR", result.stderr)
        self.assertIn("--print-paths", result.stderr)

    def test_backend_detail_is_not_lost_or_success_shaped(self):
        backend = self.root / "compiler with spaces"
        backend.write_text(
            f"#!{sys.executable}\n"
            "import sys\n"
            "assert '-fno-color-diagnostics' in sys.argv\n"
            "print('backend stdout detail')\n"
            "print('native.c:4:2: error: upstream failure\\n  broken();\\n  ^', file=sys.stderr)\n"
            "sys.exit(17)\n", encoding="utf-8",
        )
        backend.chmod(0o755)
        result = self.run_tool(self.args.compiler, self.source, env={"CC": str(backend)})
        self.assert_error(result, "cwhip", "CWHIP3001", 1)
        self.assertIn("backend stdout detail\n", result.stderr)
        self.assertIn("native.c:4:2: error: upstream failure\n  broken();\n  ^\n", result.stderr)
        self.assertIn("exit status 17", result.stderr)
        self.assertIn(str(backend), result.stderr)
        self.assertNotIn("built ", result.stderr)
        self.assertEqual(list(self.root.glob("*.tmp")), [])
        result = self.run_tool(self.args.compiler, self.source,
                               env={"CC": str(self.root / "missing compiler")})
        self.assert_error(result, "cwhip", "CWHIP3001", 1)
        self.assertIn("missing compiler", result.stderr)
        self.assertNotIn("built ", result.stderr)

    def test_driver_write_failure(self):
        output = self.root / "directory"
        output.mkdir()
        result = self.run_tool(self.args.compiler, self.source,
                               "--emit-llvm", output)
        self.assert_error(result, "cwhip", "CWHIP9001", 1)
        self.assertIn(str(output), result.stderr)

    def test_package_integrity_reports_evidence_and_requires_explicit_refresh(self):
        modules = self.root / "sdk-modules"
        package = modules / "gtk/0.1.0"
        package.mkdir(parents=True)
        (package / "cwhip-package.toml").write_text(
            '[package]\nsdk-abi = "numeric-v2"\nname = "gtk"\n'
            'version = "0.1.0"\nsource = "gtk.cw"\nexport = "namespace:Gtk"\n',
            encoding="utf-8",
        )
        package_source = package / "gtk.cw"
        package_source.write_text("namespace Gtk {}\n", encoding="utf-8")
        archive = package / "native.a"
        archive.write_bytes(b"native archive fixture\0")
        environment = {"CWHIP_STDLIB_MODULE_DIR": str(modules)}

        for changed in (package_source, archive):
            for builtin in (True, False):
                with self.subTest(changed=changed.name, builtin=builtin):
                    project = self.root / f"locked-{changed.name}-{builtin}"
                    result = self.run_tool(self.args.package_tool, "init", project,
                                           env=environment)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    source = project / "main.cw"
                    source.write_text("import gtk\nstart {}\n", encoding="utf-8")
                    lock_path = project / "cwhip-pkg.lock"
                    if not builtin:
                        manifest_path = project / "cwhip-pkg.toml"
                        old_manifest_hash = hashlib.sha256(manifest_path.read_bytes()).hexdigest()
                        manifest_path.write_text(
                            'schema = 1\n[dependencies.gtk]\nrepo = "acme/gtk"\nversion = "=0.1.0"\n',
                            encoding="utf-8",
                        )
                        lock_path.write_text(
                            lock_path.read_text()
                            .replace(old_manifest_hash, hashlib.sha256(manifest_path.read_bytes()).hexdigest())
                            .replace('repo = "builtin"', 'repo = "acme/gtk"')
                            .replace('ref = "builtin"', 'ref = "refs/tags/0.1.0"')
                            .replace('commit = "builtin"', 'commit = "' + "1" * 40 + '"'),
                            encoding="utf-8",
                        )
                    lock = lock_path.read_bytes()
                    manifest = (project / "cwhip-pkg.toml").read_bytes()
                    expected = tomllib.loads(lock.decode())["packages"]["gtk"]["sha256"]
                    changed.write_bytes(changed.read_bytes() + b"\n")
                    files = {path.relative_to(package).as_posix(): path.read_bytes()
                             for path in package.rglob("*") if path.is_file()}
                    digest = hashlib.sha256()
                    for name, content in sorted(files.items()):
                        digest.update(name.encode() + b"\0" + content + b"\0")
                    output = project / "must-not-exist"
                    result = self.run_tool(self.args.compiler, source, "-M", modules,
                                           "-o", output, env=environment)
                    self.assert_error(result, "cwhip", "CWHIP9001", 1)
                    for detail in ("package integrity mismatch for 'gtk' version '0.1.0'",
                                   str(package), str(lock_path),
                                   f"expects SHA256 {expected}",
                                   f"actual SHA256 {digest.hexdigest()}",
                                   "refusing to compile"):
                        self.assertIn(detail, result.stderr)
                    self.assertEqual("same-version SDK rebuild" in result.stderr, builtin)
                    self.assertFalse(output.exists())
                    result = self.run_tool(self.args.package_tool, "install", "--yes",
                                           cwd=project, env=environment)
                    self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertIn("integrity mismatch", result.stderr)
                    self.assertEqual(lock_path.read_bytes(), lock)
                    self.assertEqual((project / "cwhip-pkg.toml").read_bytes(), manifest)
                    self.assertEqual(files, {
                        path.relative_to(package).as_posix(): path.read_bytes()
                        for path in package.rglob("*") if path.is_file()
                    })

                    fresh = self.root / f"fresh-{changed.name}-{builtin}"
                    result = self.run_tool(self.args.package_tool, "init", fresh,
                                           env=environment)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    fresh_source = fresh / "main.cw"
                    fresh_source.write_bytes(source.read_bytes())
                    result = self.run_tool(self.args.compiler, fresh_source, "-M", modules,
                                           "--check-only", env=environment)
                    self.assertEqual((result.returncode, result.stdout, result.stderr),
                                     (0, "", ""))

    def test_package_usage_and_domain_error(self):
        for arguments in ([], ["unknown"], ["env", "--unknown"]):
            with self.subTest(arguments=arguments):
                result = self.run_tool(self.args.package_tool, *arguments)
                self.assert_error(result, "cwhip-pkg", "PKG0001", 2)
                self.assertIn("usage:", result.stderr)
        result = self.run_tool(self.args.package_tool, "list")
        self.assert_error(result, "cwhip-pkg", "PKG1001", 1)
        self.assertIn("cwhip-pkg init", result.stderr)
        result = self.run_tool(self.args.package_tool, "env", "--preferences",
                               self.root / "missing.toml")
        self.assert_error(result, "cwhip-pkg", "PKG1001", 1)
        self.assertIn("missing.toml", result.stderr)

    def test_package_sdk_io_and_toml(self):
        result = self.run_tool(self.args.package_tool, "init",
                               env={"CWHIP_STDLIB_MODULE_DIR": str(self.root / "absent")})
        self.assert_error(result, "cwhip-pkg", "PKG2001", 1)
        self.assertNotIn("Initialized", result.stdout)
        result = self.run_tool(self.args.package_tool, "init", self.source)
        self.assert_error(result, "cwhip-pkg", "PKG1002", 1)
        preferences = self.root / "preferences.toml"
        preferences.write_text("[bad\n", encoding="utf-8")
        result = self.run_tool(self.args.package_tool, "env", "--preferences", preferences)
        self.assert_error(result, "cwhip-pkg", "PKG1001", 1)
        self.assertIn(str(preferences), result.stderr)

    def test_success_streams(self):
        for tool in (self.args.compiler, self.args.package_tool):
            result = self.run_tool(tool, "--help")
            self.assertEqual(result.returncode, 0)
            self.assertIn("usage:", result.stdout.lower())
            self.assertEqual(result.stderr, "")
        result = self.run_tool(self.args.compiler, self.source, "--check-only")
        self.assertEqual((result.returncode, result.stdout, result.stderr), (0, "", ""))
        result = self.run_tool(self.args.compiler, self.source)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("cwhip: built ", result.stdout)
        self.assertEqual(result.stderr, "")
        result = self.run_tool(self.args.package_tool, "init")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Initialized Cwhip project", result.stdout)
        self.assertEqual(result.stderr, "")
        preferences = self.root / "preferences.toml"
        preferences.write_text('[environment]\nEXAMPLE = "value"\n', encoding="utf-8")
        result = self.run_tool(self.args.package_tool, "env", "--preferences", preferences)
        self.assertEqual((result.returncode, result.stdout, result.stderr),
                         (0, "export EXAMPLE='value'\n", ""))

    def test_color_is_not_required(self):
        for tool in (self.args.compiler, self.args.package_tool):
            for no_color in (None, "", "1"):
                with self.subTest(tool=tool, no_color=no_color):
                    environment = self.environment.copy()
                    environment.pop("NO_COLOR", None)
                    environment["TERM"] = "xterm-256color"
                    if no_color is not None:
                        environment["NO_COLOR"] = no_color
                    master, slave = os.openpty()
                    try:
                        result = subprocess.run(
                            [str(tool), "--unknown"], cwd=self.root, env=environment,
                            stdout=subprocess.PIPE, stderr=slave, timeout=30, check=False,
                        )
                    finally:
                        os.close(slave)
                    try:
                        chunks = []
                        while True:
                            try:
                                chunk = os.read(master, 4096)
                            except OSError as error:
                                if error.errno != errno.EIO:
                                    raise
                                break
                            if not chunk:
                                break
                            chunks.append(chunk)
                    finally:
                        os.close(master)
                    self.assertEqual(result.returncode, 2)
                    self.assertEqual(result.stdout, b"")
                    output = b"".join(chunks)
                    self.assertIn(b": error[", output)
                    self.assertNotIn(b"\x1b", output)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--compiler", required=True, type=Path)
    parser.add_argument("--package-tool", required=True, type=Path)
    DiagnosticTests.args, remaining = parser.parse_known_args()
    unittest.main(argv=[sys.argv[0], *remaining])
