#!/usr/bin/env python3
"""Exercise setup and project-shell functions in a private checkout and HOME."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

SOURCE_ROOT = Path(__file__).resolve().parent.parent
REAL_CMAKE: str | None = None
SETUP_FILES = [".project_env", "scripts/setup", "scripts/clean"]

STUB = """#!{python}
import json, os, sys
from pathlib import Path
args = sys.argv[1:]
with open(os.environ["SETUP_TEST_LOG"], "a") as log:
    log.write(json.dumps({{"tool": {name!r}, "cwd": os.getcwd(), "args": args}}) + "\\n")
if {name!r} == "cmake":
    if "-S" in args:
        status = int(os.environ.get("SETUP_TEST_CONFIGURE_EXIT", "0"))
        if status:
            sys.exit(status)
        build = Path(args[args.index("-B") + 1])
        build.mkdir(parents=True, exist_ok=True)
        cache = build / "CMakeCache.txt"
        mode = next((a.split("=", 1)[1] for a in args
                     if a.startswith("-DCMAKE_BUILD_TYPE=")), None)
        if mode is not None or not cache.exists():
            cache.write_text("CMAKE_BUILD_TYPE:STRING=" + (mode or "") + "\\n")
    else:
        sys.exit(int(os.environ.get("SETUP_TEST_BUILD_EXIT", "0")))
"""


class SetupTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="cwhip setup test ")
        self.base = Path(self.temporary.name)
        self.root = self.base / "my checkout"
        for relative in SETUP_FILES:
            target = self.root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(SOURCE_ROOT / relative, target)
        (self.root / "CMakeLists.txt").write_text("# stub\n")
        self.home = self.base / "home"
        self.home.mkdir()
        self.outside = self.base / "elsewhere dir"
        self.outside.mkdir()
        self.log = self.base / "tools.log"
        self.report = self.base / "report.txt"
        self.stubs = self.base / "stub bin"
        for name in ("cmake", "git", "cdbg"):
            self.write_tool(self.stubs / name, STUB.format(python=sys.executable, name=name))

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def write_tool(self, path: Path, text: str) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        path.chmod(0o755)

    def environment(self, **extra: str) -> dict[str, str]:
        env = {
            "HOME": str(self.home),
            "XDG_CONFIG_HOME": str(self.base / "config"),
            "TMPDIR": str(self.base),
            "PATH": os.pathsep.join([str(self.stubs), "/usr/bin", "/bin"]),
            "TERM": "dumb",
            "LANG": "C",
            "SETUP_TEST_LOG": str(self.log),
            "REPORT": str(self.report),
            "CWHIP_HOME": "/stale/prefix",
            "CWHIP_BUILTIN_DIR": "/stale/builtin",
        }
        env.update(extra)
        return env

    def run_setup(self, *args: str, commands: str = "", env: dict[str, str] | None = None
                  ) -> subprocess.CompletedProcess:
        return subprocess.run(
            [str(self.root / "scripts/setup"), *args], cwd=self.outside,
            env=env or self.environment(), input=commands, text=True,
            capture_output=True, timeout=60, check=False)

    def calls(self, tool: str = "cmake") -> list[list[str]]:
        if not self.log.exists():
            return []
        return [call["args"] for line in self.log.read_text().splitlines()
                if (call := json.loads(line))["tool"] == tool]

    def test_modes_and_cached_default(self) -> None:
        for mode, cmake_mode in (("debug", "Debug"), ("release", "Release"),
                                 ("profile", "RelWithDebInfo")):
            with self.subTest(mode=mode):
                result = self.run_setup(mode, commands=(
                    'printf "%s\\n" "$_BUILD_TYPE" "$CWHIP_BUILD_TYPE" > "$REPORT"\nexit 3\n'))
                self.assertEqual(result.returncode, 3, result.stderr)
                self.assertEqual(self.report.read_text().splitlines(), [mode, cmake_mode])
                self.assertIn("-DCMAKE_BUILD_TYPE=" + cmake_mode, self.calls()[-1])
        result = self.run_setup(commands='echo "$_BUILD_TYPE" > "$REPORT"\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.report.read_text().strip(), "profile")
        self.assertEqual(self.calls()[-1], ["-S", str(self.root), "-B", str(self.root / "build")])
        shutil.rmtree(self.root / "build")
        result = self.run_setup(commands='echo "$_BUILD_TYPE" > "$REPORT"\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.report.read_text().strip(), "default")

    def test_invalid_arguments_do_not_clean_or_configure(self) -> None:
        marker = self.root / "bin/keep"
        self.write_tool(marker, "keep")
        for args in (["fast"], ["debug", "release"], ["--clean", "--clean"],
                     ["--clean", "--bogus"], ["--build-dir", "other"],
                     ["--submodules"], ["-DBUILD_TESTING=OFF"], ["--help"]):
            with self.subTest(args=args):
                result = self.run_setup(*args)
                self.assertEqual(result.returncode, 2, result.stderr)
                self.assertIn("Usage:", result.stderr)
                self.assertTrue(marker.exists())
        self.assertEqual(self.calls(), [])

    def test_active_shell_guard_precedes_arguments_and_clean(self) -> None:
        self.write_tool(self.root / "bin/keep", "keep")
        result = self.run_setup("--clean", "bogus", env=self.environment(_PROJECT_NAME="other"))
        self.assertEqual(result.returncode, 1)
        self.assertIn("already active", result.stderr)
        self.assertTrue((self.root / "bin/keep").exists())
        self.assertEqual(self.calls(), [])
        result = self.run_setup(commands=(
            '"$_PROJECT_LOC/scripts/setup" --clean </dev/null; echo "$?" > "$REPORT"\n'))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.report.read_text().strip(), "1")

    def test_clean_before_configure_in_either_order(self) -> None:
        for args in (("--clean", "debug"), ("release", "--clean"), ("--clean",)):
            for name in ("bin", "build", "lib", "share", "doc/out"):
                self.write_tool(self.root / name / "stale", "stale")
                self.write_tool(self.outside / name / "keep", "keep")
            result = self.run_setup(*args, commands='echo "$PWD" > "$REPORT"\n')
            self.assertEqual(result.returncode, 0, result.stderr)
            for name in ("bin", "build", "lib", "share", "doc/out"):
                self.assertFalse((self.root / name / "stale").exists(), name)
                self.assertTrue((self.outside / name / "keep").exists(), name)
            self.assertTrue((self.root / "build/CMakeCache.txt").exists())
            self.assertEqual(self.report.read_text().strip(), str(self.root / "build"))
            self.assertTrue((self.root / "scripts/setup").exists())

    def test_clean_failure_starts_no_configure_or_shell(self) -> None:
        self.write_tool(self.root / "scripts/clean", "#!/bin/sh\nexit 7\n")
        result = self.run_setup("--clean", commands='touch "$REPORT"\n')
        self.assertEqual(result.returncode, 7)
        self.assertEqual(self.calls(), [])
        self.assertFalse(self.report.exists())

    def test_configure_failure_starts_no_shell(self) -> None:
        result = self.run_setup(env=self.environment(SETUP_TEST_CONFIGURE_EXIT="5"),
                                commands='touch "$REPORT"\n')
        self.assertEqual(result.returncode, 1)
        self.assertIn("CMake configuration failed; project shell was not started", result.stderr)
        self.assertFalse(self.report.exists())

    def test_sdk_consumer_settings_are_not_used(self) -> None:
        settings = self.base / "config/cwhip/sdk.toml"
        settings.parent.mkdir(parents=True)
        settings.write_text("not valid TOML\n")
        result = self.run_setup(env=self.environment(CWHIP_SDK="/nonexistent/sdk"))
        self.assertEqual(result.returncode, 0, result.stderr)
        result = self.run_setup()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("/nonexistent/sdk", self.calls()[-1])

    def test_shell_environment_and_caller(self) -> None:
        (self.home / ".bashrc").write_text('RC_LOADED=yes\nPS1="rc> "\n')
        result = self.run_setup("debug", commands=(
            '{ echo "$RC_LOADED $_PROJECT_NAME $_BUILD_TYPE"; echo "$PATH";'
            ' echo "${CWHIP_HOME-unset} ${CWHIP_BUILTIN_DIR-unset}"; echo "$PS1"; } > "$REPORT"\n'))
        self.assertEqual(result.returncode, 0, result.stderr)
        lines = self.report.read_text().splitlines()
        self.assertEqual(lines[0], "yes my checkout debug")
        self.assertEqual(lines[1].split(os.pathsep)[:2],
                         [str(self.root / "bin"), str(self.root / "scripts")])
        self.assertEqual(lines[2], "unset unset")
        self.assertTrue(lines[3].endswith("rc> "))
        script = (
            'before_path=$PATH; before_pwd=$PWD\n'
            '"$SETUP" release </dev/null >/dev/null 2>&1\n'
            '[[ "$PATH" = "$before_path" && "$PWD" = "$before_pwd" && '
            '-z "${_PROJECT_NAME:-}" && "$CWHIP_HOME" = /stale/prefix ]]\n')
        result = subprocess.run(
            ["bash", "-c", script], cwd=self.outside,
            env=self.environment(SETUP=str(self.root / "scripts/setup")),
            capture_output=True, text=True, timeout=60, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_build_functions_targets_status_and_shell_survival(self) -> None:
        result = self.run_setup(commands=(
            'declare -F build rebuild > "$REPORT"\n'
            'build cwhip "target with spaces"; rebuild; cd /; build; rebuild cwhip\n'
            'echo survived >> "$REPORT"\n'))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.report.read_text().splitlines(), ["build", "rebuild", "survived"])
        build = str(self.root / "build")
        self.assertEqual(self.calls()[1:], [
            ["--build", build, "--parallel", "12", "--target", "cwhip", "target with spaces"],
            ["--build", build, "--parallel", "12", "--clean-first"],
            ["--build", build, "--parallel", "12"],
            ["--build", build, "--parallel", "12", "--clean-first", "--target", "cwhip"],
        ])
        result = self.run_setup(env=self.environment(SETUP_TEST_BUILD_EXIT="9"), commands=(
            'build; echo "$?" > "$REPORT"; rebuild cwhip; echo "$?" >> "$REPORT"\n'))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.report.read_text().splitlines(), ["9", "9"])
        self.assertFalse((self.root / "scripts/build").exists())
        self.assertFalse((self.root / "scripts/rebuild").exists())

    def test_git_and_debugger_helpers(self) -> None:
        result = self.run_setup(commands=(
            'cd /; status -s; add; add "a b"; commit -m message; push; all -m message;'
            ' dbg; echo "$?" > "$REPORT"; dbg "../a b.cw" -- "x y"\n'))
        self.assertEqual(result.returncode, 0, result.stderr)
        prefix = ["-C", str(self.root)]
        self.assertEqual(self.calls("git"), [
            prefix + ["status", "-s"], prefix + ["add", "."], prefix + ["add", "a b"],
            prefix + ["commit", "-m", "message"], prefix + ["push"],
            prefix + ["add", "-A"], prefix + ["commit", "-m", "message"], prefix + ["push"],
        ])
        self.assertEqual(self.report.read_text().strip(), "2")
        self.assertEqual(self.calls("cdbg"), [["../a b.cw", "--", "x y"]])

    def test_real_cmake_build_and_rebuild(self) -> None:
        if REAL_CMAKE is None:
            self.skipTest("pass --cmake for a real CMake build")
        (self.root / "CMakeLists.txt").write_text(
            "cmake_minimum_required(VERSION 3.16)\nproject(setup_test NONE)\n"
            "add_custom_target(marker ALL COMMAND ${CMAKE_COMMAND} -E touch "
            "${CMAKE_BINARY_DIR}/built)\n")
        env = self.environment()
        env["PATH"] = os.pathsep.join([str(Path(REAL_CMAKE).parent), "/usr/bin", "/bin"])
        result = self.run_setup("--clean", "debug", env=env, commands=(
            'build marker && test -f built && rm built && rebuild && test -f built\nexit $?\n'))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--cmake", help="real CMake executable for the build exercise")
    options, remaining = parser.parse_known_args()
    REAL_CMAKE = options.cmake
    unittest.main(argv=[sys.argv[0], *remaining])
