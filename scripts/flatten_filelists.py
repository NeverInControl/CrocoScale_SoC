#!/usr/bin/env python3
"""
scripts/flatten_filelists.py

Resolves recursive file lists (-f / -c directives) into flat, unified
file lists suitable for toolchains that do not support nested includes.
"""

import os
import sys
import argparse
from pathlib import Path


def parse_flist(flist_path: Path, repo_root: Path, visited: set = None) -> list[str]:
    """Recursively parses a filelist and returns an ordered list of unique files."""
    if visited is None:
        visited = set()

    real_path = flist_path.resolve()
    if real_path in visited:
        return []
    visited.add(real_path)

    if not flist_path.exists():
        raise FileNotFoundError(f"File list not found: {flist_path}")

    files = []
    with open(flist_path, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            # Strip whitespace and Windows CRLF
            clean_line = line.strip().rstrip("\r\n")

            # Skip comments and empty lines
            if not clean_line or clean_line.startswith("#") or clean_line.startswith("//"):
                continue

            # Check for recursive include (-f or -c)
            parts = clean_line.split()
            if parts[0] in ("-f", "-c"):
                if len(parts) < 2:
                    continue
                sub_name = parts[1]

                # Resolve include path relative to current flist dir, then FILE_LISTS, then repo root
                sub_path = flist_path.parent / sub_name
                if not sub_path.exists():
                    sub_path = repo_root / "FILE_LISTS" / sub_name
                if not sub_path.exists():
                    sub_path = repo_root / sub_name

                sub_files = parse_flist(sub_path, repo_root, visited)
                for sf in sub_files:
                    if sf not in files:
                        files.append(sf)
            else:
                # Regular file entry
                file_rel = clean_line.replace("\\", "/")
                # Normalize relative to repo root if path exists
                full_test = repo_root / file_rel
                if full_test.exists():
                    entry = file_rel
                else:
                    # Check relative to flist location
                    from_flist = flist_path.parent / file_rel
                    if from_flist.exists():
                        entry = os.path.relpath(from_flist, repo_root).replace("\\", "/")
                    else:
                        entry = file_rel

                if entry not in files:
                    files.append(entry)

    return files


def generate_flat_filelist(input_flist: Path, output_flist: Path, repo_root: Path):
    """Parses input_flist and writes the flattened list to output_flist."""
    files = parse_flist(input_flist, repo_root)

    output_flist.parent.mkdir(parents=True, exist_ok=True)
    with open(output_flist, "w", encoding="utf-8", newline="\n") as f:
        f.write(f"# Auto-generated flat file list\n")
        f.write(f"# Source: {os.path.relpath(input_flist, repo_root).replace(chr(92), '/')}\n")
        f.write(f"# Total files: {len(files)}\n\n")
        for file_path in files:
            f.write(f"{file_path}\n")

    print(f"Generated flat file list: {output_flist} ({len(files)} files)")


def main():
    parser = argparse.ArgumentParser(description="Flatten nested filelists for EDA tools.")
    parser.add_argument("input", nargs="?", default="FILE_LISTS/efpga_subsystem.f",
                        help="Input file list (default: FILE_LISTS/efpga_subsystem.f)")
    parser.add_argument("-o", "--output", default=None,
                        help="Output flat file list path")
    parser.add_argument("--repo-root", default=None,
                        help="Repository root directory")
    args = parser.parse_args()

    script_dir = Path(__file__).resolve().parent
    repo_root = Path(args.repo_root).resolve() if args.repo_root else script_dir.parent

    input_path = Path(args.input)
    if not input_path.is_absolute():
        input_path = repo_root / input_path

    if args.output:
        output_path = Path(args.output)
        if not output_path.is_absolute():
            output_path = repo_root / output_path
    else:
        out_name = f"{input_path.stem}_global.f"
        output_path = repo_root / "FILE_LISTS" / out_name

    generate_flat_filelist(input_path, output_path, repo_root)


if __name__ == "__main__":
    main()

