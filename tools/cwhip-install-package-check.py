#!/usr/bin/env python3
"""Install-time check for packages left in the SDK module directory.

`cmake --install` runs this after copying the SDK's own packages. Packages that
other projects installed into the same prefix are never owned by the SDK, so a
reinstall does not replace them. A leftover package built for an older SDK ABI
makes every tool that scans installed packages fail (PKG2004). By default the
check only reports such packages. With CWHIP_QUARANTINE_INCOMPATIBLE_PACKAGES=1
it moves each complete incompatible package version directory to a new,
timestamped backup directory outside module discovery.
"""

from __future__ import annotations

import argparse
import datetime
import os
from pathlib import Path
import shlex
import sys

if sys.version_info < (3, 11):
    print("cwhip-install: error: Python 3.11 or newer is required", file=sys.stderr)
    raise SystemExit(2)

import tomllib

MANIFEST = "cwhip-package.toml"
QUARANTINE_VARIABLE = "CWHIP_QUARANTINE_INCOMPATIBLE_PACKAGES"


class CheckError(Exception):
    pass


def warn(message: str) -> None:
    print(f"cwhip-install: warning: {message}", file=sys.stderr)


def error(message: str) -> None:
    print(f"cwhip-install: error: {message}", file=sys.stderr)


def quarantine_requested() -> bool:
    value = os.environ.get(QUARANTINE_VARIABLE, "")
    if value in ("", "0"):
        return False
    if value == "1":
        return True
    raise CheckError(f"{QUARANTINE_VARIABLE} must be 1 (move incompatible packages to a backup) "
                     f"or unset/0 (report only); got {value!r}")


def package_versions(root: Path) -> list[tuple[str, str, Path, bool]]:
    """Return (name, version, directory, symlinked) for each directory discovery reads.

    Discovery follows symlinks, so symlinked package or version directories are
    listed too; `symlinked` marks them so a repair never moves through them.
    """
    try:
        if not root.is_dir():
            raise CheckError(f"package directory {root} does not exist or is not a directory")
        found = []
        for package_dir in sorted(root.iterdir()):
            if not package_dir.is_dir():
                continue
            for version_dir in sorted(package_dir.iterdir()):
                if version_dir.is_dir() and (version_dir / MANIFEST).is_file():
                    symlinked = package_dir.is_symlink() or version_dir.is_symlink()
                    found.append((package_dir.name, version_dir.name, version_dir, symlinked))
        return found
    except OSError as failure:
        raise CheckError(f"cannot scan package directory {root}: {failure}") from failure


def manifest_abi(manifest: Path) -> tuple[str | None, str | None]:
    """Return (sdk-abi or None when absent, problem or None) for one manifest."""
    try:
        content = manifest.read_bytes()
    except OSError as failure:
        return None, f"{manifest}: cannot read manifest: {failure}"
    try:
        document = tomllib.loads(content.decode("utf-8"))
    except (UnicodeDecodeError, tomllib.TOMLDecodeError) as failure:
        return None, f"{manifest}: malformed manifest: {failure}"
    package = document.get("package")
    if not isinstance(package, dict):
        return None, f"{manifest}: malformed manifest: missing [package] table"
    abi = package.get("sdk-abi")
    if abi is not None and not isinstance(abi, str):
        return None, f"{manifest}: malformed manifest: [package] sdk-abi must be a string"
    return abi, None


def nearest_existing(path: Path) -> Path:
    while not path.exists() and path != path.parent:
        path = path.parent
    return path


def check_repair_safety(incompatible: list[tuple[str, str, Path, str, bool]], modules: Path,
                        backup_root: Path) -> None:
    """Refuse the repair, before anything is created or moved, when it could be unsafe."""
    problems = []
    for _, _, directory, _, symlinked in incompatible:
        if symlinked:
            problems.append(f"{directory}: package or version directory is a symlink; "
                            "remove the link or fix the package it points to manually")
    try:
        real_modules = modules.resolve(strict=True)
        real_backup = backup_root.resolve()
        if real_backup == real_modules or real_backup.is_relative_to(real_modules):
            problems.append(f"backup directory {backup_root} resolves to {real_backup}, "
                            f"inside the package directory {real_modules}")
        backup_device = os.stat(nearest_existing(backup_root)).st_dev
        for _, _, directory, _, symlinked in incompatible:
            if symlinked:
                continue
            if not directory.resolve(strict=True).is_relative_to(real_modules):
                problems.append(f"{directory}: resolves outside the package directory {real_modules}")
            elif os.stat(directory).st_dev != backup_device:
                problems.append(f"{directory}: on a different filesystem from {backup_root}; "
                                "it cannot be moved without copying")
    except OSError as failure:
        raise CheckError(f"cannot inspect paths for the package repair; nothing was moved: "
                         f"{failure}") from failure
    if problems:
        raise CheckError(f"refusing {QUARANTINE_VARIABLE}=1 repair; nothing was moved:\n  "
                         + "\n  ".join(problems))


def create_backup_directory(backup_root: Path) -> Path:
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    try:
        backup_root.mkdir(parents=True, exist_ok=True)
        for attempt in range(1000):
            candidate = backup_root / (stamp if attempt == 0 else f"{stamp}-{attempt}")
            try:
                candidate.mkdir()
            except FileExistsError:
                continue
            return candidate
    except OSError as failure:
        raise CheckError(f"cannot create package backup directory under {backup_root}: {failure}") from failure
    raise CheckError(f"cannot create a unique package backup directory under {backup_root}")


def quarantine(incompatible: list[tuple[str, str, Path, str]], modules: Path,
               backup_root: Path) -> None:
    check_repair_safety(incompatible, modules, backup_root)
    backup = create_backup_directory(backup_root)
    try:
        if backup.resolve(strict=True).is_relative_to(modules.resolve(strict=True)):
            raise CheckError(f"backup directory {backup} resolves inside {modules}; nothing was moved")
    except OSError as failure:
        raise CheckError(f"cannot inspect backup directory {backup}; nothing was moved: "
                         f"{failure}") from failure
    moves = [(directory, backup / "modules" / name / version)
             for name, version, directory, _, _ in incompatible]
    restore = backup / "RESTORE.txt"
    lines = [
        "Cwhip SDK install moved these package versions out of module discovery",
        "because their sdk-abi did not match this SDK. Contents are unchanged.",
        "",
    ]
    for (source, destination), (_, _, _, reason, _) in zip(moves, incompatible):
        lines.append(f"{source} ({reason})")
        lines.append(f"  -> {destination}")
    lines += [
        "",
        "To restore a package after rebuilding it for the current SDK ABI, or to",
        "undo this repair, move its directory back, for example:",
        f"  mkdir -p {shlex.quote(str(moves[0][0].parent))} && "
        f"mv {shlex.quote(str(moves[0][1]))} {shlex.quote(str(moves[0][0]))}",
        "Delete this backup only when the packages are no longer needed.",
        "",
    ]
    try:
        restore.write_text("\n".join(lines), encoding="utf-8")
    except OSError as failure:
        raise CheckError(f"cannot write {restore}; no packages were moved: {failure}") from failure

    moved: list[tuple[Path, Path]] = []
    for source, destination in moves:
        try:
            destination.parent.mkdir(parents=True, exist_ok=True)
            # rename never copies or deletes contents; a cross-device move fails instead.
            os.rename(source, destination)
        except OSError as failure:
            done = "".join(f"\n  moved {src} -> {dst}" for src, dst in moved) or "\n  none"
            raise CheckError(
                f"cannot move {source} to {destination}: {failure}\n"
                f"packages already moved (see {restore}):{done}\n"
                f"remaining incompatible packages were left in {modules}") from failure
        moved.append((source, destination))
        package_dir = source.parent
        try:
            if not any(package_dir.iterdir()):
                package_dir.rmdir()
        except OSError as failure:
            raise CheckError(f"moved {source} but cannot inspect or remove the now-empty "
                             f"directory {package_dir}: {failure}") from failure

    warn(f"moved {len(moved)} incompatible package version(s) out of {modules}:")
    for source, destination in moved:
        print(f"  {source}\n    -> {destination}", file=sys.stderr)
    print(f"  Recovery instructions: {restore}", file=sys.stderr)


def check(modules: Path, owned_root: Path, backup_root: Path, sdk_abi: str) -> None:
    repair = quarantine_requested()
    owned = {(name, version) for name, version, _, _ in package_versions(owned_root)}
    problems: list[str] = []
    incompatible: list[tuple[str, str, Path, str, bool]] = []
    for name, version, directory, symlinked in package_versions(modules):
        abi, problem = manifest_abi(directory / MANIFEST)
        if problem is not None:
            problems.append(problem)
        elif abi != sdk_abi:
            reason = "sdk-abi missing" if abi is None else f"sdk-abi {abi!r}"
            if (name, version) in owned:
                problems.append(f"{directory / MANIFEST}: SDK-installed package has {reason}; "
                                f"expected {sdk_abi!r} (rebuild the SDK)")
            else:
                incompatible.append((name, version, directory, reason, symlinked))
    if problems:
        raise CheckError(
            "cannot classify installed packages; nothing was moved. Repair or remove:\n  "
            + "\n  ".join(problems))
    if not incompatible:
        return
    if repair:
        quarantine(incompatible, modules, backup_root)
        return
    warn(f"{len(incompatible)} installed package version(s) in {modules} were not built for "
         f"SDK ABI {sdk_abi!r} and were left unchanged:")
    for _, _, directory, reason, symlinked in incompatible:
        note = "; symlinked, so the repair below refuses it: fix manually" if symlinked else ""
        print(f"  {directory} ({reason}{note})", file=sys.stderr)
    print(
        "  These packages were not installed by this SDK. Commands that scan installed\n"
        "  packages, such as 'cwhip-pkg init', fail with PKG2004 until they are fixed.\n"
        "  Choose one:\n"
        "    - reinstall each package from a source version built for this SDK ABI;\n"
        "    - remove package directories you no longer need; or\n"
        f"    - rerun this install with {QUARANTINE_VARIABLE}=1 to move them, unchanged,\n"
        f"      to a new timestamped backup under {backup_root}.",
        file=sys.stderr,
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--modules-dir", required=True, type=Path,
                        help="installed SDK module directory to check")
    parser.add_argument("--owned-dir", required=True, type=Path,
                        help="staged module directory the SDK just installed")
    parser.add_argument("--backup-dir", required=True, type=Path,
                        help="directory for quarantined package backups")
    parser.add_argument("--sdk-abi", required=True)
    arguments = parser.parse_args()
    try:
        check(arguments.modules_dir, arguments.owned_dir, arguments.backup_dir, arguments.sdk_abi)
    except CheckError as failure:
        error(str(failure))
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
