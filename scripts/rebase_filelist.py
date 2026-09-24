#!/usr/bin/env python3
"""
scripts/rebase_filelist.py

Utility to rebase path prefixes in HDL file lists (.f / .flist).
Adjusts relative path roots in place or writes the rebased output to a new file.
Does not move or modify any referenced hardware source files.
"""

import sys
import posixpath
from pathlib import Path


def print_help():
    help_text = """Usage: rebase_filelist.py <filelist> <rebase_path> [output_file]

Rebase file paths inside an HDL file list by adding or replacing a directory prefix.

Arguments:
  filelist     Path to the target file list (.f / .flist) to rebase.
  rebase_path  New path prefix to apply to all entries (e.g. '../f2', 'new_root', '../').
               If '..' is used, all files in the file list must share a common root
               directory component for each '..' level traversed.
  output_file  Optional. Path where the rebased file list should be written.
               If omitted, the source file list is updated in place.

Behavior:
  - If rebase_path contains leading '../', the shared root component(s) are stripped
    from each path and replaced with the remainder of rebase_path.
  - If no '..' is used, rebase_path is prepended to each file path.
  - Comments ('#', '//') and blank lines are preserved without modification.
  - Recursive include directives ('-f', '-c') have their referenced paths rebased.
  - No physical files on the filesystem are moved or touched.

Examples:
  # Replace shared root 'f1/' with 'f2/':
  #   f1/d1.v -> f2/d1.v
  rebase_filelist.py filelist.f ../f2

  # Strip top-level directory:
  #   RTL/core/pe.v -> core/pe.v
  rebase_filelist.py filelist.f ../

  # Prepend new directory prefix:
  #   core/pe.v -> RTL/core/pe.v
  rebase_filelist.py filelist.f RTL

  # Write rebased result to a new file:
  rebase_filelist.py filelist.f ../new_dir filelist_rebased.f
"""
    print(help_text)


def parse_rebase_path(rebase_str: str) -> tuple[int, str]:
    """
    Parses rebase_str to determine how many parent levels ('..') to ascend
    and extracts the remaining prefix to append.
    """
    norm = rebase_str.replace("\\", "/").strip()
    parts = [p for p in norm.split("/") if p and p != "."]

    up_count = 0
    rem_parts = []
    for p in parts:
        if p == "..":
            if not rem_parts:
                up_count += 1
            else:
                rem_parts.pop()
        else:
            rem_parts.append(p)

    remainder = "/".join(rem_parts)
    return up_count, remainder


def split_line(line: str) -> tuple[str, str, str]:
    """
    Splits a line into (directive_prefix, path_part, comment_or_trailing).
    Returns directive_prefix (e.g. '-f ', '-c ', or ''), the path, and any trailing content.
    """
    stripped = line.strip().rstrip("\r\n")
    if not stripped or stripped.startswith("#") or stripped.startswith("//"):
        return "", "", line

    parts = stripped.split(maxsplit=1)
    if parts[0] in ("-f", "-c") and len(parts) > 1:
        return parts[0] + " ", parts[1].replace("\\", "/"), ""

    return "", stripped.replace("\\", "/"), ""


def rebase_filelist(input_path: Path, rebase_str: str, output_path: Path):
    if not input_path.exists():
        print(f"Error: File list not found: '{input_path}'", file=sys.stderr)
        sys.exit(1)

    up_count, remainder = parse_rebase_path(rebase_str)

    with open(input_path, "r", encoding="utf-8", errors="replace") as f:
        raw_lines = f.readlines()

    # Collect and validate all active file paths
    active_paths = []
    for line in raw_lines:
        directive, path_str, _ = split_line(line)
        if path_str:
            active_paths.append(path_str)

    if not active_paths:
        print(f"Warning: File list '{input_path}' contains no file entries.")

    # Validate shared root condition when ascending directory levels
    if up_count > 0 and active_paths:
        root_components = None
        for path_str in active_paths:
            parts = [p for p in path_str.split("/") if p and p != "."]
            if len(parts) <= up_count:
                print(
                    f"Error: Path '{path_str}' has {len(parts) - 1} directory level(s), "
                    f"which is fewer than the {up_count} level(s) required by '{rebase_str}'.",
                    file=sys.stderr,
                )
                sys.exit(1)

            curr_root = tuple(parts[:up_count])
            if root_components is None:
                root_components = curr_root
            elif root_components != curr_root:
                mismatch_root = "/".join(curr_root)
                expected_root = "/".join(root_components)
                print(
                    f"Error: Inconsistent root hierarchy in file list.\n"
                    f"  Expected root prefix: '{expected_root}'\n"
                    f"  Mismatched path:      '{path_str}' (root: '{mismatch_root}')\n"
                    f"All paths must share the identical {up_count} root level(s) when rebasing with '..'.",
                    file=sys.stderr,
                )
                sys.exit(1)

    # Rebase lines
    new_lines = []
    for line in raw_lines:
        directive, path_str, original_comment = split_line(line)
        if not path_str:
            new_lines.append(original_comment.rstrip("\r\n") + "\n")
            continue

        parts = [p for p in path_str.split("/") if p and p != "."]
        remaining_parts = parts[up_count:]

        if remainder:
            new_path = remainder + "/" + "/".join(remaining_parts)
        else:
            new_path = "/".join(remaining_parts)

        # Normalize relative path formatting
        new_path = posixpath.normpath(new_path)
        new_lines.append(f"{directive}{new_path}\n")

    # Write output
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w", encoding="utf-8", newline="\n") as f:
        f.writelines(new_lines)

    target_desc = "Overwrote source" if input_path.resolve() == output_path.resolve() else f"Wrote to '{output_path}'"
    print(f"Rebase successful: {target_desc} ({len(active_paths)} entries rebased with '{rebase_str}').")


def main():
    args = sys.argv[1:]

    if not args or args[0] in ("-h", "--help"):
        print_help()
        sys.exit(0)

    if len(args) < 2:
        print("Error: Missing required arguments.\n", file=sys.stderr)
        print_help()
        sys.exit(1)

    input_file = Path(args[0])
    rebase_arg = args[1]
    output_file = Path(args[2]) if len(args) >= 3 else input_file

    rebase_filelist(input_file, rebase_arg, output_file)


if __name__ == "__main__":
    main()

