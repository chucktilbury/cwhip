#!/usr/bin/env python3
"""Regression tests for the scripts/setup developer shell and its helpers.

Each case copies the setup files into a private checkout whose path contains
spaces, uses an isolated HOME (the developer's rc file is never read), and
replaces cmake/git/debuggers with logging stubs. The project shell is a real
interactive bash fed commands on stdin, so it always terminates at EOF.
"""

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
SETUP_FILES = [".project_env", "scripts/setup", "scripts/build", "scripts/rebuild", "scripts/clean"]

STUB = """#!{python}
import json, os, sys
args = sys.argv[1:]
with open(os.environ["SETUP_TEST_LOG"], "a") as log:
    log.write(json.dumps({{"tool": {name!r}, "cwd": os.getcwd(), "args": args}}) + "\\n")
if {name!r} == "cmake" and "-S" in args:
    build = args[args.index("-B") + 1]
    os.makedirs(build, exist_ok=True)
    status = int(os.environ.get("SETUP_TEST_CMAKE_EXIT", "0"))
    if status:
        print("CMake Error: stub configure failure", file=sys.stderr)
        sys.exit(status)
    lines = ["CMAKE_BUILD_TYPE:STRING=" + next((a.split("=", 1)[1] for a in args
             if a.startswith("-DCMAKE_BUILD_TYPE=")), "")]
    for a in args:
        if a.startswith("-DCWHIP_STAGE_PREFIX="):
            lines.append("CWHIP_STAGE_PREFIX:PATH=" + a.split("=", 1)[1])
    with open(os.path.join(build, "CMakeCache.txt"), "w") as cache:
        cache.write("\\n".join(lines) + "\\n")
"""


class SetupTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="cwhip setup test ")
        self.base = Path(self.temporary.name)
        self.root = self.base / "my checkout" / "cwhip"
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
        self.decoy = self.base / "installed bin"
        for name in ("cmake", "git"):
            self.write_tool(self.stubs / name, STUB.format(python=sys.executable, name=name))
        self.write_tool(self.decoy / "cwhip", "#!/bin/sh\necho installed\n")

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def write_tool(self, path: Path, text: str) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        path.chmod(0o755)

    def environment(self, **extra: str) -> dict[str, str]:
        env = {
            "HOME": str(self.home),
            "PATH": os.pathsep.join([str(self.stubs), str(self.decoy), "/usr/bin", "/bin"]),
            "TERM": "dumb",
            "LANG": "C",
            "SETUP_TEST_LOG": str(self.log),
            "REPORT": str(self.report),
            "CWHIP_HOME": "/stale/prefix",
            "CWHIP_BUILTIN_DIR": "/stale/builtin",
        }
        env.update(extra)
        return env

    def minimal_path(self) -> str:
        """A PATH with the basic utilities setup needs, but no cmake or debuggers."""
        tools = self.base / "minimal bin"
        tools.mkdir(exist_ok=True)
        for name in ("bash", "env", "sed", "head", "dirname", "readlink", "mkdir", "touch", "cat"):
            found = shutil.which(name, path="/usr/bin:/bin")
            if found and not (tools / name).exists():
                (tools / name).symlink_to(found)
        return str(tools)

    def run_setup(self, *args: str, commands: str = "", cwd: Path | None = None,
                  env: dict[str, str] | None = None, setup: Path | None = None
                  ) -> subprocess.CompletedProcess:
        return subprocess.run(
            [str(setup or self.root / "scripts" / "setup"), *args],
            cwd=cwd or self.outside, env=env or self.environment(), input=commands,
            text=True, capture_output=True, timeout=60, check=False)

    def tool_calls(self, tool: str) -> list[dict]:
        if not self.log.exists():
            return []
        calls = [json.loads(line) for line in self.log.read_text().splitlines()]
        return [call for call in calls if call["tool"] == tool]

    def configure_args(self) -> list[str]:
        calls = [call for call in self.tool_calls("cmake") if "-S" in call["args"]]
        self.assertEqual(len(calls), 1, calls)
        return calls[0]["args"]

    def report_lines(self) -> list[str]:
        return self.report.read_text().splitlines()

    def test_build_type_modes(self) -> None:
        for mode, build_type in ((None, "Debug"), ("debug", "Debug"), ("release", "Release"),
                                 ("profile", "RelWithDebInfo")):
            with self.subTest(mode=mode):
                self.log.unlink(missing_ok=True)
                args = [mode] if mode else []
                result = self.run_setup(*args, commands='echo "$_BUILD_TYPE" > "$REPORT"\nexit 3\n')
                self.assertEqual(result.returncode, 3, result.stderr)
                self.assertIn(f"-DCMAKE_BUILD_TYPE={build_type}", self.configure_args())
                self.assertEqual(self.report_lines(), [build_type])

    def test_invalid_mode_and_arguments(self) -> None:
        for args in (["fast"], ["debug", "release"], ["--build-dir"], ["--bogus"]):
            with self.subTest(args=args):
                result = self.run_setup(*args, commands="touch \"$REPORT\"\n")
                self.assertEqual(result.returncode, 2)
                self.assertTrue(result.stderr.strip())
        self.assertIn("debug, release, or profile", self.run_setup("fast").stderr)
        self.assertEqual(self.tool_calls("cmake"), [])
        self.assertFalse(self.report.exists())

    def test_root_discovery_outside_checkout_with_spaces(self) -> None:
        link = self.base / "linked setup"
        link.symlink_to(self.root / "scripts" / "setup")
        for setup in (self.root / "scripts" / "setup", link):
            with self.subTest(setup=setup):
                self.log.unlink(missing_ok=True)
                result = self.run_setup(
                    setup=setup,
                    commands='printf "%s\\n" "$PWD" "$_PROJECT_LOC" "$_PROJECT_BUILD_DIR" "$_PROJECT_NAME" > "$REPORT"\n')
                self.assertEqual(result.returncode, 0, result.stderr)
                args = self.configure_args()
                self.assertEqual(args[args.index("-S") + 1], str(self.root))
                self.assertEqual(args[args.index("-B") + 1], str(self.root / "build"))
                build = str(self.root / "build")
                self.assertEqual(self.report_lines(), [build, str(self.root), build, "cwhip"])
        relative = self.run_setup("--build-dir", "custom build", commands='echo "$PWD" > "$REPORT"\n')
        self.assertEqual(relative.returncode, 0, relative.stderr)
        self.assertEqual(self.report_lines(), [str(self.outside / "custom build")])

    def test_caller_shell_is_untouched(self) -> None:
        script = (
            'before_path=$PATH; before_pwd=$PWD\n'
            '"$SETUP" release </dev/null >/dev/null 2>&1\n'
            'printf "%s\\n" "$?" "$([ "$PATH" = "$before_path" ] && echo same-path)" '
            '"$([ "$PWD" = "$before_pwd" ] && echo same-pwd)" "${_PROJECT_LOC-unset}" '
            '"${_BUILD_TYPE-unset}" "$CWHIP_HOME"\n'
            'source "$SETUP"; echo "source=$?"\n')
        env = self.environment(SETUP=str(self.root / "scripts" / "setup"))
        result = subprocess.run(["bash", "-c", script], cwd=self.outside, env=env, text=True,
                                capture_output=True, timeout=60, check=False)
        self.assertEqual(result.stdout.splitlines(),
                         ["0", "same-path", "same-pwd", "unset", "unset", "/stale/prefix", "source=2"],
                         result.stderr)
        self.assertIn("do not source", result.stderr)
        self.assertFalse((self.home / ".bashrc").exists())

    def test_path_and_local_resources(self) -> None:
        self.write_tool(self.root / "bin" / "cwhip", "#!/bin/sh\necho local\n")
        scripts = str(self.root / "scripts")
        stage_bin = str(self.root / "bin")
        env = self.environment()
        env["PATH"] = os.pathsep.join([scripts, env["PATH"], stage_bin, scripts])
        result = self.run_setup(env=env, commands=(
            '{ type -P cwhip; cwhip; type -P setup; echo "$PATH";'
            ' echo "${CWHIP_HOME-unset} ${CWHIP_BUILTIN_DIR-unset}"; } > "$REPORT"\n'))
        self.assertEqual(result.returncode, 0, result.stderr)
        lines = self.report_lines()
        self.assertEqual(lines[:3], [stage_bin + "/cwhip", "local", scripts + "/setup"])
        entries = lines[3].split(os.pathsep)
        self.assertEqual(entries[:2], [stage_bin, scripts])
        self.assertEqual(entries.count(scripts), 1)
        self.assertEqual(entries.count(stage_bin), 1)
        self.assertIn(str(self.decoy), entries)
        self.assertEqual(lines[4], "unset unset")
        self.assertNotIn("not built yet", result.stdout)

    def test_custom_stage_prefix_from_cache(self) -> None:
        stage = self.base / "stage dir"
        self.write_tool(stage / "bin" / "cwhip", "#!/bin/sh\necho staged\n")
        result = self.run_setup("-DCWHIP_STAGE_PREFIX=" + str(stage),
                                commands='{ cwhip; echo "$_PROJECT_STAGE_PREFIX"; } > "$REPORT"\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.report_lines(), ["staged", str(stage)])

    def test_unbuilt_compiler_is_reported(self) -> None:
        result = self.run_setup(commands='type -P cwhip > "$REPORT"\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("not built yet", result.stdout)
        self.assertEqual(self.report_lines(), [str(self.decoy / "cwhip")])

    def test_rc_file_cannot_override_project_environment(self) -> None:
        (self.home / ".bashrc").write_text(
            'export PATH=/usr/bin:/bin\nexport _BUILD_TYPE=Bogus _PROJECT_LOC=/nowhere\n'
            'export CWHIP_HOME=/rc/prefix\nPS1="rc> "\nRC_LOADED=yes\ncd /\n')
        result = self.run_setup("profile", commands=(
            '{ echo "$RC_LOADED $_BUILD_TYPE $_PROJECT_LOC ${CWHIP_HOME-unset} $PWD";'
            ' echo "${PATH%%:*}"; echo "$PS1"; } > "$REPORT"\n'))
        self.assertEqual(result.returncode, 0, result.stderr)
        lines = self.report_lines()
        self.assertEqual(lines[0], f"yes RelWithDebInfo {self.root} unset {self.root / 'build'}")
        self.assertEqual(lines[1], str(self.root / "bin"))
        self.assertTrue(lines[2].endswith("rc> "), lines[2])
        self.assertIn("$_PROJECT_NAME($_BUILD_TYPE)", lines[2])

    def test_configure_failure_starts_no_shell(self) -> None:
        result = self.run_setup(env=self.environment(SETUP_TEST_CMAKE_EXIT="5"),
                                commands='touch "$REPORT"\n')
        self.assertEqual(result.returncode, 5)
        self.assertIn("CMake configuration failed", result.stderr)
        self.assertIn("no project shell was started", result.stderr)
        self.assertFalse(self.report.exists())

    def test_missing_cmake_is_explicit(self) -> None:
        (self.stubs / "cmake").unlink()
        env = self.environment()
        env["PATH"] = os.pathsep.join([str(self.stubs), self.minimal_path()])
        result = self.run_setup(env=env, commands='touch "$REPORT"\n')
        self.assertEqual(result.returncode, 1)
        self.assertIn("cmake was not found", result.stderr)
        self.assertFalse(self.report.exists())

    def test_cmake_options_and_compiler_defaults(self) -> None:
        result = self.run_setup("release", "-DCWHIP_GTK=OFF", "-DCWHIP_GTK_SOURCEVIEW=OFF",
                                "--", "-DBUILD_TESTING=OFF")
        self.assertEqual(result.returncode, 0, result.stderr)
        args = self.configure_args()
        for expected in ("-DCWHIP_GTK=OFF", "-DCWHIP_GTK_SOURCEVIEW=OFF", "-DBUILD_TESTING=OFF",
                         "-DCMAKE_C_COMPILER=clang", "-DCMAKE_CXX_COMPILER=clang++",
                         "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON"):
            self.assertIn(expected, args)
        self.assertNotIn("-DCWHIP_GTK=ON", args)
        self.assertNotIn("-DCWHIP_GTK_SOURCEVIEW=ON", args)

        # An existing cache keeps its compilers.
        self.log.unlink()
        self.assertEqual(self.run_setup().returncode, 0)
        args = self.configure_args()
        self.assertFalse(any(a.startswith(("-DCMAKE_C_COMPILER", "-DCMAKE_CXX_COMPILER")) for a in args))

        self.log.unlink()
        result = self.run_setup("--build-dir", str(self.base / "gcc"), "-DCMAKE_C_COMPILER=gcc",
                                "-DCMAKE_CXX_COMPILER:FILEPATH=g++")
        self.assertEqual(result.returncode, 0, result.stderr)
        args = self.configure_args()
        self.assertIn("-DCMAKE_C_COMPILER=gcc", args)
        self.assertNotIn("-DCMAKE_C_COMPILER=clang", args)
        self.assertNotIn("-DCMAKE_CXX_COMPILER=clang++", args)

    def test_submodules_are_opt_in(self) -> None:
        self.assertEqual(self.run_setup().returncode, 0)
        self.assertEqual(self.tool_calls("git"), [])
        self.assertEqual(self.run_setup("--submodules").returncode, 0)
        calls = self.tool_calls("git")
        self.assertEqual(calls[0]["args"], ["-C", str(self.root), "submodule", "update", "--init", "--recursive"])

    def test_nested_setup_is_refused(self) -> None:
        result = self.run_setup(commands='"$_PROJECT_LOC/scripts/setup" release </dev/null; echo "$?" > "$REPORT"\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.report_lines(), ["1"])
        self.assertIn("already initialized", result.stderr)
        self.assertEqual(len([c for c in self.tool_calls("cmake") if "-S" in c["args"]]), 1)

    def test_build_helpers(self) -> None:
        result = self.run_setup(commands='build cedit cdbg; rebuild; cd /; build\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        build = str(self.root / "build")
        calls = [c["args"] for c in self.tool_calls("cmake") if "--build" in c["args"]]
        self.assertEqual(calls, [
            ["--build", build, "--parallel", "12", "--target", "cedit", "cdbg"],
            ["--build", build, "--parallel", "12", "--clean-first"],
            ["--build", build, "--parallel", "12"],
        ])
        # Outside a project shell the helpers keep building the current directory.
        self.log.unlink()
        subprocess.run([str(self.root / "scripts" / "build")], cwd=self.outside, env=self.environment(),
                       check=True, timeout=30)
        self.assertEqual(self.tool_calls("cmake")[0]["args"], ["--build", ".", "--parallel", "12"])
        self.assertEqual(self.tool_calls("cmake")[0]["cwd"], str(self.outside))

    def test_clean_uses_checkout_root(self) -> None:
        for name in ("bin", "build", "lib", "share", "doc/out"):
            (self.root / name).mkdir(parents=True)
            (self.outside / name).mkdir(parents=True)
        subprocess.run([str(self.root / "scripts" / "clean")], cwd=self.outside, check=True, timeout=30)
        for name in ("bin", "build", "lib", "share", "doc/out"):
            self.assertFalse((self.root / name).exists(), name)
            self.assertTrue((self.outside / name).exists(), name)
        self.assertTrue((self.root / "scripts" / "setup").exists())

    def test_git_helpers_preserve_working_directory(self) -> None:
        result = self.run_setup(commands=(
            'mkdir -p "$HOME/sub dir"; cd "$HOME/sub dir"; add; all; status -s; '
            'echo "$PWD" > "$REPORT"\n'))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.report_lines(), [str(self.home / "sub dir")])
        calls = self.tool_calls("git")
        self.assertEqual([c["args"] for c in calls],
                         [["add", "."], ["add", "."], ["commit"], ["push"], ["status", "-s"]])
        self.assertEqual([c["cwd"] for c in calls[:4]], [str(self.root)] * 4)

    def test_dbg_prefers_cdbg_and_falls_back(self) -> None:
        stub = STUB.format(python=sys.executable, name="dbg")
        self.write_tool(self.root / "bin" / "prog", "#!/bin/sh\n")
        self.write_tool(self.stubs / "kdbg", stub)
        result = self.run_setup(commands='dbg prog "a b" c; dbg; echo "$?" > "$REPORT"\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.tool_calls("dbg")[0]["args"], [str(self.root / "bin" / "prog"), "-a", "a b c"])
        self.assertEqual(self.report_lines(), ["2"])

        self.log.unlink()
        self.write_tool(self.root / "bin" / "cdbg", stub)
        result = self.run_setup(commands='dbg prog "a b" c; dbg ../x.cw\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([c["args"] for c in self.tool_calls("dbg")],
                         [[str(self.root / "bin" / "prog"), "--", "a b", "c"], ["../x.cw"]])

        (self.root / "bin" / "cdbg").unlink()
        (self.stubs / "kdbg").unlink()
        env = self.environment()
        env["PATH"] = os.pathsep.join([str(self.stubs), self.minimal_path()])
        result = self.run_setup(env=env, commands='dbg prog; echo "$?" > "$REPORT"\n')
        self.assertEqual(self.report_lines(), ["127"])
        self.assertIn("no debugger found", result.stderr)

    def test_real_cmake_configure_smoke(self) -> None:
        if REAL_CMAKE is None:
            self.skipTest("pass --cmake to run the real configure smoke")
        env = self.environment()
        env["PATH"] = os.pathsep.join([str(Path(REAL_CMAKE).parent), "/usr/bin", "/bin"])
        build = self.base / "real build"
        stage = self.base / "real stage"
        result = self.run_setup(
            "release", "--build-dir", str(build), "-DCWHIP_STAGE_PREFIX=" + str(stage),
            "-DCWHIP_GTK=OFF", "-DCWHIP_GTK_SOURCEVIEW=OFF", "-DBUILD_TESTING=OFF",
            setup=SOURCE_ROOT / "scripts" / "setup", env=env,
            commands='printf "%s\\n" "$_BUILD_TYPE" "${PATH%%:*}" "$PWD" > "$REPORT"\n')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.report_lines(), ["Release", str(stage / "bin"), str(build)])
        cache = (build / "CMakeCache.txt").read_text()
        self.assertIn("CMAKE_BUILD_TYPE:STRING=Release", cache)
        self.assertIn("CWHIP_GTK:BOOL=OFF", cache)
        self.assertFalse((SOURCE_ROOT / "build" / "real build").exists())


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--cmake", help="real CMake executable for the configure smoke")
    options, remaining = parser.parse_known_args()
    REAL_CMAKE = options.cmake
    unittest.main(argv=[sys.argv[0], *remaining])
