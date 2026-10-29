"""Verify -g emits complete class member DWARF matching the LLVM object layout."""

import argparse
import subprocess
import tempfile
from pathlib import Path


def run(command, work):
    result = subprocess.run(command, cwd=work, text=True, capture_output=True)
    assert result.returncode == 0, f"{command}\n{result.stdout}\n{result.stderr}"
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--compiler", required=True, type=Path)
    parser.add_argument("--fixture", required=True, type=Path)
    args = parser.parse_args()

    with tempfile.TemporaryDirectory(prefix="class-dwarf-") as directory:
        work = Path(directory)
        ir = work / "out.ll"
        exe = work / "out"
        run([str(args.compiler), "-g", str(args.fixture), "--emit-llvm", str(ir),
             "-o", str(exe)], work)
        text = ir.read_text()
        assert 'name: "Point"' in text and "DIFlagFwdDecl" not in text.split('name: "Point"')[1].split('\n')[0]
        assert 'name: "x"' in text and 'name: "y"' in text
        assert 'name: "__metadata"' in text and 'name: "__owner"' in text
        assert 'name: "Derived"' in text and 'name: "d"' in text
        assert 'name: "Base"' in text and 'name: "b"' in text
        # Point must be a complete composite with elements, not only a forward decl.
        assert 'DICompositeType(tag: DW_TAG_structure_type, name: "Point"' in text
        assert 'flags: DIFlagFwdDecl)' not in [
            line for line in text.splitlines()
            if 'DICompositeType(tag: DW_TAG_structure_type, name: "Point"' in line
        ][0]
        print("PASS class member DWARF")


if __name__ == "__main__":
    main()
