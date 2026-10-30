"""Compile and run checked-in tests/repro programs against manifest expectations."""

import argparse
import json
from pathlib import Path
import tempfile

from program_runner import check_program, environment


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repro", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--list", action="store_true")
    parser.add_argument("--compiler", type=Path)
    parser.add_argument("--work", type=Path)
    parser.add_argument("--case")
    args = parser.parse_args()
    cases = json.loads(args.manifest.read_text())
    sources = {p.name for p in args.repro.glob("*.cw")}
    assert sources == set(cases), (
        f"Repro expectations differ: missing={sources - set(cases)}, "
        f"obsolete={set(cases) - sources}")
    if args.list:
        print(";".join(sorted(cases)))
        return
    args.work.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=args.work, prefix="repro-") as directory:
        work = Path(directory)
        env = environment(work)
        source = args.repro / args.case
        check_program(args.compiler.resolve(), source, work, cases[args.case], env)


if __name__ == "__main__":
    main()
