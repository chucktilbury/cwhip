#!/usr/bin/env python3
"""Offline checks of the compiler/package diagnostic contract."""

import argparse
import errno
import os
from pathlib import Path
import subprocess
import sys
import tempfile
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

    def run_tool(self, tool, *arguments, env=None):
        return subprocess.run(
            [str(tool), *map(str, arguments)], cwd=self.root,
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
