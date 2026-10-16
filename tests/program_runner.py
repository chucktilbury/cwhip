"""Shared hermetic compile/run checks for examples and documentation."""

import os
from pathlib import Path
import subprocess
import shutil


def environment(work: Path) -> dict[str, str]:
    env = os.environ.copy()
    for key in list(env):
        if key.startswith("CWHIP_") or key in ("CC", "DESTDIR"):
            del env[key]
    for key, directory in (("HOME", "home"), ("XDG_CONFIG_HOME", "xdg"),
                           ("XDG_DATA_HOME", "data"), ("XDG_CACHE_HOME", "cache"),
                           ("XDG_STATE_HOME", "state"), ("XDG_RUNTIME_DIR", "runtime")):
        path = work / directory
        path.mkdir(mode=0o700, parents=True, exist_ok=True)
        env[key] = str(path)
    env["LC_ALL"] = "C"
    return env


def invoke(command: list[str], work: Path, env: dict[str, str],
           stdin: str = "", timeout: int = 30) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(command, cwd=work, env=env, input=stdin,
                            text=True, capture_output=True, timeout=timeout)
    if result.returncode == 0 and Path(command[0]).name == "cwhip" and "-o" in command and "-c" not in command:
        # Ad-hoc test executables need the same sidecars as installed applications.
        resources = Path(command[0]).resolve().parent.parent / "share/cwhip/modules/sourceview"
        if resources.is_dir():
            output = Path(command[command.index("-o") + 1])
            if not output.is_absolute():
                output = work / output
            shutil.copytree(resources, output.parent / "share/cwhip/modules/sourceview", dirs_exist_ok=True)
    if any(marker in result.stderr for marker in
           ("AddressSanitizer", "UndefinedBehaviorSanitizer", "runtime error:")):
        raise AssertionError(f"Instrumentation failure:\n{result.stderr}")
    return result


def check_program(compiler: Path, source: Path, work: Path, case: dict,
                  env: dict[str, str], executable: Path | None = None) -> None:
    output = executable or work / ("program.o" if case.get("object") else "program")
    if executable is None:
        command = [str(compiler), str(source), "-o", str(output)]
        if case.get("object"):
            command.append("-c")
        result = invoke(command, work, env)
        diagnostic = case.get("compile_diagnostic")
        if diagnostic:
            assert result.returncode != 0 and diagnostic in result.stderr, result
            return
        assert result.returncode == 0, f"{source} failed compilation:\n{result.stderr}"
    assert output.is_file(), f"No compiler output for {source}"
    if case.get("object"):
        return
    command = [str(output)] + case.get("args", [])
    result = invoke(command, work, env, case.get("stdin", ""))
    assert result.returncode == case.get("exit", 0), (
        f"{source}: exit {result.returncode}\n{result.stderr}")
    assert result.stdout == case["stdout"], (
        f"{source}: expected {case['stdout']!r}, got {result.stdout!r}")
    if "diagnostic" in case:
        assert case["diagnostic"] in result.stderr, result.stderr
    else:
        assert not result.stderr, result.stderr
