#!/usr/bin/env python3
"""
scripts/clean_filelists_crlf.py

Recursively converts Windows CRLF (\\r\\n) and standalone CR (\\r) line endings
to pure Unix LF (\\n) across all file lists (.f and .flist files).
Prevents Icarus Verilog parser errors ("ERROR: File name not terminated.").
"""

import sys
import argparse
from pathlib import Path


def clean_file(path: Path) -> bool:
    """Reads file in binary mode and replaces all CRLF/CR with LF. Returns True if modified."""
    with open(path, "rb") as f:
        data = f.read()

    cleaned = data.replace(b"\r\n", b"\n").replace(b"\r", b"\n")
    if not cleaned.endswith(b"\n") and len(cleaned) > 0:
        cleaned += b"\n"

    if cleaned == data:
        return False

    with open(path, "wb") as f:
        f.write(cleaned)

    return True


def clean_directory(dir_path: Path) -> tuple[int, int]:
    """Scans directory recursively for .f and .flist files and cleans line endings."""
    total = 0
    modified = 0

    patterns = ["*.f", "*.flist"]
    for pattern in patterns:
        for file_path in dir_path.rglob(pattern):
            # Skip files inside git internal directories
            if ".git" in file_path.parts:
                continue

            total += 1
            if clean_file(file_path):
                print(f"Cleaned CRLF -> LF: {file_path}")
                modified += 1

    return total, modified


def main():
    epilog_text = """
Examples:
  # Default: recursively sanitize all .f and .flist files in FILE_LISTS/:
  python3 scripts/clean_filelists_crlf.py

  # Sanitize specific directories or files:
  python3 scripts/clean_filelists_crlf.py FILE_LISTS exports
"""
    parser = argparse.ArgumentParser(
        prog="python3 scripts/clean_filelists_crlf.py",
        description="CrocoScale SoC — Filelist Line-Ending Sanitizer (CRLF -> Unix LF).\n"
                    "Strips Windows carriage returns (\\r\\n) across .f and .flist files to prevent\n"
                    "Icarus Verilog 'File name not terminated' parser errors.",
        epilog=epilog_text,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "targets",
        nargs="*",
        metavar="PATH",
        help="Directories or .f files to sanitize (default: FILE_LISTS/).",
    )
    args = parser.parse_args()

    script_dir = Path(__file__).resolve().parent
    repo_root = script_dir.parent

    target_dirs = []
    if args.targets:
        for arg in args.targets:
            p = Path(arg)
            if not p.is_absolute():
                p = repo_root / p
            target_dirs.append(p)
    else:
        target_dirs = [repo_root / "FILE_LISTS"]

    print("=== Sanitizing File List Line Endings (CRLF -> Unix LF) ===")
    total_scanned = 0
    total_cleaned = 0

    for target in target_dirs:
        if target.is_file():
            total_scanned += 1
            if clean_file(target):
                print(f"Cleaned CRLF -> LF: {target}")
                total_cleaned += 1
        elif target.is_dir():
            scanned, cleaned = clean_directory(target)
            total_scanned += scanned
            total_cleaned += cleaned
        else:
            print(f"Warning: Target path does not exist: {target}", file=sys.stderr)

    print(f"Summary: {total_scanned} files inspected, {total_cleaned} files sanitized to Unix LF.")


if __name__ == "__main__":
    main()

