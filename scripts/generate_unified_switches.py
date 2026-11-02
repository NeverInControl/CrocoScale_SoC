#!/usr/bin/env python3
"""
scripts/generate_unified_switches.py
CrocoScale SoC — Automated Multi-Target Unified Switch & Filelist Generator

Automatically discovers modules and packages that have target-specific overrides
across the repository's flow filelists (Simulation, Vivado, ASIC Tier-1, and
ASIC Tier-2), transpiles any SystemVerilog (.sv) variants into IEEE 1364-2001
Verilog (.v) via sv2v, wraps them into compiler-directive switch files in
UNIFIED_GENERATED/, and auto-generates FILE_LISTS/unified/*.f.

OpenTitan-Scale Hardening Features:
  - Zero AST/Logic Merging: Every variant remains a complete, self-contained
    `module ... endmodule` block wrapped at the file level in `ifdef / `elsif / `else.
  - Automatic Flow Diffing: Indexes all modules/packages across FILE_LISTS/*.f,
    FILE_LISTS/vivado/*.f, and FILE_LISTS/asic/*.f without hardcoded module names.
  - Transitive Multi-Hop Helper BFS + Header Guards: Recursively resolves
    ASIC leaf blackboxes (e.g. sg13cmos5l_lgcp_1, RM_IHPSG13_1P_*) in bottom-up
    dependency order and wraps each helper file in an `ifndef / `define include
    guard so shared macro libraries never cause duplicate module definitions.
  - Package-Aware sv2v Transpilation: Passes flow `*_pkg.sv` files to sv2v
    when transpiling `.sv` branches, stripping inlined package headers afterward.
  - Automated Unified Filelist Rewriting: Automatically generates
    FILE_LISTS/unified/*_unified.f from base filelists whenever any direct or
    transitive file dependency is replaced by a unified switch wrapper.
"""

import os
import re
import sys
import shutil
import argparse
import subprocess
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent
sys.path.insert(0, str(SCRIPT_DIR))

from flatten_filelists import parse_flist

TIMESCALE_RE = re.compile(r"^\s*`timescale\b.*$", re.MULTILINE)


def find_sv2v() -> str:
    """Locates the sv2v binary in PATH or ~/.local/bin."""
    sv2v_path = shutil.which("sv2v")
    if sv2v_path:
        return sv2v_path
    local_sv2v = Path.home() / ".local" / "bin" / "sv2v"
    if local_sv2v.exists():
        return str(local_sv2v)
    return None


def extract_defined_entities(file_path: Path) -> list:
    """Returns a list of (kind, name) for all modules/packages declared in file_path."""
    if not file_path.exists():
        return []
    text = file_path.read_text(encoding="utf-8", errors="replace")
    text_no_comments = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    text_no_comments = re.sub(r"//.*$", "", text_no_comments, flags=re.MULTILINE)
    entities = []
    for m in re.finditer(r"^\s*(module|package)\s+([a-zA-Z_][a-zA-Z0-9_]*)\b", text_no_comments, re.MULTILINE):
        entities.append((m.group(1), m.group(2)))
    return entities


def to_verilog_2001(src_path: Path, repo_root: Path, sv2v_bin: str, pkg_files: list = None) -> str:
    """
    Returns pure IEEE 1364-2001 Verilog source for src_path.
    - If src_path is already .v, reads it directly.
    - If src_path is .sv, transpiles it via sv2v (passing flow pkg_files if needed)
      or falls back to VERILOG_MIRROR_GENERATED.
    Strips `timescale directives so a single header `timescale can be placed at the top.
    """
    if src_path.suffix == ".v":
        raw = src_path.read_text(encoding="utf-8", errors="replace")
    elif sv2v_bin:
        cmd = [sv2v_bin]
        if pkg_files:
            for pf in pkg_files:
                pf_abs = repo_root / pf
                if pf_abs.exists() and pf_abs.resolve() != src_path.resolve():
                    cmd.append(str(pf_abs))
        cmd.append(str(src_path))
        res = subprocess.run(cmd, capture_output=True, text=True, check=True)
        raw = res.stdout
    else:
        rel = src_path.relative_to(repo_root)
        mirror_v = repo_root / "VERILOG_MIRROR_GENERATED" / rel.with_suffix(".v")
        if mirror_v.exists():
            raw = mirror_v.read_text(encoding="utf-8", errors="replace")
        else:
            raw = src_path.read_text(encoding="utf-8", errors="replace")

    cleaned = TIMESCALE_RE.sub("", raw).strip()
    return cleaned


def collect_flow_map(flist_rel_paths: list, repo_root: Path) -> tuple:
    """
    Parses a list of relative .f filelists and returns:
      - entity_to_file: dict mapping entity_name -> relative file path
      - kind_map      : dict mapping entity_name -> 'module' | 'package'
      - pkg_files     : ordered list of relative package (.sv) file paths in this flow
    """
    entity_to_file = {}
    kind_map = {}
    pkg_files = []

    for fl_rel in flist_rel_paths:
        fl_path = repo_root / fl_rel
        if not fl_path.exists():
            continue
        for rel_f in parse_flist(fl_path, repo_root):
            abs_f = repo_root / rel_f
            ents = extract_defined_entities(abs_f)
            for kind, name in ents:
                entity_to_file[name] = rel_f
                kind_map[name] = kind
                if kind == "package" and rel_f not in pkg_files:
                    pkg_files.append(rel_f)

    return entity_to_file, kind_map, pkg_files


def find_instantiated_helpers_transitive(wrapper_file: Path, helper_pool: dict, repo_root: Path) -> list:
    """
    Transitively resolves ASIC-only leaf modules (e.g. sg13cmos5l_lgcp_1 or RM_IHPSG13_1P_*)
    instantiated directly or indirectly by wrapper_file, returning helper file paths in
    bottom-up dependency order (deepest leaves first).
    """
    visited_files = []

    def dfs(file_path: Path):
        if not file_path.exists():
            return
        text = file_path.read_text(encoding="utf-8", errors="replace")
        text_no_comments = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
        text_no_comments = re.sub(r"//.*$", "", text_no_comments, flags=re.MULTILINE)
        for ent_name, rel_path in helper_pool.items():
            if re.search(rf"\b{re.escape(ent_name)}\b", text_no_comments):
                child_path = repo_root / rel_path
                if rel_path not in visited_files and child_path.resolve() != file_path.resolve():
                    dfs(child_path)
                    if rel_path not in visited_files:
                        visited_files.append(rel_path)

    dfs(wrapper_file)
    return visited_files


def sanitize_guard_macro(rel_path: str) -> str:
    """Creates a clean uppercase Verilog macro identifier for a helper file include guard."""
    clean = re.sub(r"[^a-zA-Z0-9_]", "_", rel_path).upper()
    return f"UNIFIED_HELPER_{clean}_INCLUDED"


def flist_contains_replaced_files(flist_path: Path, repo_root: Path, replaced_files: dict, bundled_helpers: set) -> bool:
    """Returns True if flist_path (directly or transitively) references any switched/replaced file."""
    for rel_f in parse_flist(flist_path, repo_root):
        if rel_f in replaced_files or rel_f in bundled_helpers:
            return True
    return False


def generate_unified_filelists(repo_root: Path, flist_out_dir: Path, replaced_files: dict, bundled_helpers: set):
    """
    Auto-generates FILE_LISTS/unified/*_unified.f from base filelists in FILE_LISTS/
    and Tier-1 container filelists in FILE_LISTS/asic/.
    """
    flist_root = repo_root / "FILE_LISTS"
    if flist_out_dir.exists():
        shutil.rmtree(flist_out_dir)
    flist_out_dir.mkdir(parents=True, exist_ok=True)

    generated_flists = []

    # 1. Process root FILE_LISTS/*.f that contain switched files
    for base_flist in sorted(flist_root.glob("*.f")):
        if not flist_contains_replaced_files(base_flist, repo_root, replaced_files, bundled_helpers):
            continue

        out_flist = flist_out_dir / f"{base_flist.stem}_unified.f"
        out_lines = []
        seen_entries = set()

        with open(base_flist, "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                raw_line = line.rstrip("\r\n")
                clean = raw_line.strip()
                if not clean or clean.startswith(("#", "//")):
                    out_lines.append(raw_line)
                    continue

                parts = clean.split()
                if parts[0] in ("-f", "-c") and len(parts) >= 2:
                    sub_rel = parts[1].replace("\\", "/")
                    sub_path = (base_flist.parent / sub_rel).resolve()
                    if not sub_path.exists():
                        sub_path = (flist_root / sub_rel).resolve()

                    if sub_path.exists() and flist_contains_replaced_files(sub_path, repo_root, replaced_files, bundled_helpers):
                        new_entry = f"{parts[0]} {sub_path.stem}_unified.f"
                    else:
                        new_entry = f"{parts[0]} ../{sub_rel}"

                    if new_entry not in seen_entries:
                        out_lines.append(new_entry)
                        seen_entries.add(new_entry)
                else:
                    norm_path = clean.replace("\\", "/")
                    if norm_path in bundled_helpers:
                        continue
                    mapped_path = replaced_files.get(norm_path, norm_path)
                    if mapped_path not in seen_entries:
                        out_lines.append(mapped_path)
                        seen_entries.add(mapped_path)

        out_lines.append("")
        out_flist.write_text("\n".join(out_lines), encoding="utf-8", newline="\n")
        generated_flists.append(out_flist)

    # 2. Process Tier-1 container filelists from FILE_LISTS/asic/*container*_asic.f
    asic_flist_dir = flist_root / "asic"
    if asic_flist_dir.exists():
        for container_flist in sorted(asic_flist_dir.glob("*container*_asic.f")):
            stem = container_flist.stem[:-len("_asic")]
            out_flist = flist_out_dir / f"{stem}_unified.f"
            out_lines = []
            seen_entries = set()

            with open(container_flist, "r", encoding="utf-8", errors="replace") as f:
                for line in f:
                    raw_line = line.rstrip("\r\n")
                    clean = raw_line.strip()
                    if not clean or clean.startswith(("#", "//")):
                        out_lines.append(raw_line)
                        continue
                    norm_path = clean.replace("\\", "/")
                    if norm_path in bundled_helpers:
                        continue
                    mapped_path = replaced_files.get(norm_path, norm_path)
                    if mapped_path not in seen_entries:
                        out_lines.append(mapped_path)
                        seen_entries.add(mapped_path)

            out_lines.append("")
            out_flist.write_text("\n".join(out_lines), encoding="utf-8", newline="\n")
            generated_flists.append(out_flist)

    return generated_flists


def generate_unified_switches(repo_root: Path, out_dir: Path, flist_out_dir: Path):
    sv2v_bin = find_sv2v()
    print("=" * 80)
    print(f"CrocoScale Unified Switch & Filelist Generator")
    print(f"  Switch Output Dir   : {out_dir.relative_to(repo_root)}")
    print(f"  Filelist Output Dir : {flist_out_dir.relative_to(repo_root)}")
    print(f"  sv2v Transpiler     : {sv2v_bin or 'Fallback to VERILOG_MIRROR_GENERATED'}")
    print("=" * 80)

    # Index entities across the 4 canonical flows
    sim_map, kind_map, sim_pkgs = collect_flow_map(["FILE_LISTS/soc.f"], repo_root)
    vivado_map, v_kinds, viv_pkgs = collect_flow_map(["FILE_LISTS/vivado/soc_vivado.f"], repo_root)
    asic_t1_map, a1_kinds, a1_pkgs = collect_flow_map(
        [
            "FILE_LISTS/asic/act_bank_container_asic.f",
            "FILE_LISTS/asic/psum_requant_container_asic.f",
        ],
        repo_root,
    )
    asic_t2_map, a2_kinds, a2_pkgs = collect_flow_map(["FILE_LISTS/asic/efpga_subsystem_asic.f"], repo_root)

    kind_map.update(v_kinds)
    kind_map.update(a1_kinds)
    kind_map.update(a2_kinds)

    # Combine ASIC Tier-1 and Tier-2 maps to identify ASIC-only helper blackbox files
    all_asic_entities = {}
    all_asic_entities.update(asic_t1_map)
    all_asic_entities.update(asic_t2_map)

    asic_only_helpers = {
        ent: path
        for ent, path in all_asic_entities.items()
        if ent not in sim_map and ent not in vivado_map
    }

    if out_dir.exists():
        shutil.rmtree(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    # Document auto-generated nature of UNIFIED_GENERATED/
    (out_dir / "README.md").write_text(
        "# UNIFIED_GENERATED\n\n"
        "> **AUTO-GENERATED DIRECTORY — DO NOT EDIT DIRECTLY**\n>\n"
        "> This directory is automatically generated by `scripts/generate_unified_switches.py`.\n"
        "> All hardware changes must be made to the golden source files in `RTL/`, `MACROS/`,\n"
        "> `VIVADO/`, and `FABulousProject/`.\n",
        encoding="utf-8",
        newline="\n",
    )

    replaced_files = {}
    bundled_helper_files = set()
    generated_count = 0

    for ent_name, sim_rel in sim_map.items():
        viv_rel = vivado_map.get(ent_name, sim_rel)
        asic_t1_rel = asic_t1_map.get(ent_name, asic_t2_map.get(ent_name, sim_rel))
        asic_t2_rel = asic_t2_map.get(ent_name, asic_t1_rel)

        if len({sim_rel, viv_rel, asic_t1_rel, asic_t2_rel}) == 1:
            continue

        ent_kind = kind_map.get(ent_name, "module")

        # Generalized SystemVerilog package wrapper generation
        if ent_kind == "package":
            def extract_pkg_body(pkg_rel: str) -> str:
                raw_txt = (repo_root / pkg_rel).read_text(encoding="utf-8", errors="replace")
                m = re.search(rf"\bpackage\s+{re.escape(ent_name)}\s*;(.*?)\bendpackage\b", raw_txt, flags=re.DOTALL)
                return m.group(1).strip() if m else ""

            sim_body = extract_pkg_body(sim_rel)
            viv_body = extract_pkg_body(viv_rel)
            asic_body = extract_pkg_body(asic_t1_rel)

            pkg_lines = [
                "`timescale 1ns / 1ps",
                "",
                "/* ===============================================================================================",
                f" * Auto-Generated Unified Package: {ent_name}",
                " * Generated by scripts/generate_unified_switches.py — DO NOT EDIT MANUALLY",
                " * =============================================================================================== */",
                "",
                f"package {ent_name};",
            ]
            pkg_ifdef = False
            if asic_body != sim_body:
                pkg_lines.append("`ifdef TARGET_ASIC")
                pkg_lines.append(f"    {asic_body}")
                pkg_ifdef = True
            if viv_body != sim_body:
                pkg_lines.append("`elsif TARGET_VIVADO" if pkg_ifdef else "`ifdef TARGET_VIVADO")
                pkg_lines.append(f"    {viv_body}")
                pkg_ifdef = True
            if pkg_ifdef:
                pkg_lines.append("`else")
                pkg_lines.append(f"    {sim_body}")
                pkg_lines.append("`endif")
            else:
                pkg_lines.append(f"    {sim_body}")
            pkg_lines.append("endpackage")
            pkg_lines.append("")

            out_pkg = out_dir / f"{ent_name}.sv"
            out_pkg.write_text("\n".join(pkg_lines), encoding="utf-8", newline="\n")
            for p in {sim_rel, viv_rel, asic_t1_rel, asic_t2_rel}:
                replaced_files[p] = out_pkg.relative_to(repo_root).as_posix()
            generated_count += 1
            print(f"[GEN PKG]    {out_pkg.relative_to(repo_root)} (from { {sim_rel, viv_rel, asic_t2_rel} })")
            continue

        # Build the compiler-directive branches for this module
        lines = [
            "`timescale 1ns / 1ps",
            "",
            "/* ===============================================================================================",
            f" * Auto-Generated Unified Switch Module: {ent_name} (Pure IEEE 1364-2001 Verilog)",
            " * Generated by scripts/generate_unified_switches.py — DO NOT EDIT MANUALLY",
            f" * - Simulation Default      : {sim_rel}",
        ]
        if viv_rel != sim_rel:
            lines.append(f" * - TARGET_VIVADO           : {viv_rel}")
        if asic_t1_rel != sim_rel:
            lines.append(f" * - TARGET_ASIC             : {asic_t1_rel}")
        if asic_t2_rel != asic_t1_rel:
            lines.append(f" * - TARGET_ASIC_CONTAINERS  : {asic_t2_rel}")
        lines.append(" * =============================================================================================== */")
        lines.append("")

        opened_ifdef = False

        # Branch A: Tier-2 Container Blackbox Override (`ifdef TARGET_ASIC_CONTAINERS)
        if asic_t2_rel != asic_t1_rel:
            lines.append("`ifdef TARGET_ASIC_CONTAINERS")
            lines.append("")
            opened_ifdef = True
            t2_code = to_verilog_2001(repo_root / asic_t2_rel, repo_root, sv2v_bin, pkg_files=a2_pkgs)
            lines.append(t2_code)
            lines.append("")

        # Branch B: General ASIC Override (`ifdef / `elsif TARGET_ASIC)
        helper_files = []
        if asic_t1_rel != sim_rel:
            kw = "`elsif TARGET_ASIC" if opened_ifdef else "`ifdef TARGET_ASIC"
            lines.append(kw)
            lines.append("")
            opened_ifdef = True

            # Transitively resolve ASIC-only leaf blackbox modules and guard each with `ifndef
            helper_files = find_instantiated_helpers_transitive(repo_root / asic_t1_rel, asic_only_helpers, repo_root)
            for hf_rel in helper_files:
                bundled_helper_files.add(hf_rel)
                guard_macro = sanitize_guard_macro(hf_rel)
                hf_code = to_verilog_2001(repo_root / hf_rel, repo_root, sv2v_bin, pkg_files=a1_pkgs + a2_pkgs)
                lines.append(f"/* --- Bundled ASIC Leaf Primitive: {hf_rel} --- */")
                lines.append(f"`ifndef {guard_macro}")
                lines.append(f"`define {guard_macro}")
                lines.append(hf_code)
                lines.append(f"`endif /* {guard_macro} */")
                lines.append("")

            t1_code = to_verilog_2001(repo_root / asic_t1_rel, repo_root, sv2v_bin, pkg_files=a1_pkgs + a2_pkgs)
            lines.append(t1_code)
            lines.append("")

        # Branch C: Vivado Emulation Override (`ifdef / `elsif TARGET_VIVADO)
        if viv_rel != sim_rel:
            kw = "`elsif TARGET_VIVADO" if opened_ifdef else "`ifdef TARGET_VIVADO"
            lines.append(kw)
            lines.append("")
            opened_ifdef = True
            viv_code = to_verilog_2001(repo_root / viv_rel, repo_root, sv2v_bin, pkg_files=viv_pkgs)
            lines.append(viv_code)
            lines.append("")

        # Branch D: Default Behavioral / Synthesizable RTL (`else)
        lines.append("`else")
        lines.append("")
        sim_code = to_verilog_2001(repo_root / sim_rel, repo_root, sv2v_bin, pkg_files=sim_pkgs)
        lines.append(sim_code)
        lines.append("")
        lines.append("`endif")
        lines.append("")

        out_v = out_dir / f"{ent_name}.v"
        out_v.write_text("\n".join(lines), encoding="utf-8", newline="\n")

        for p in {sim_rel, viv_rel, asic_t1_rel, asic_t2_rel}:
            replaced_files[p] = out_v.relative_to(repo_root).as_posix()

        generated_count += 1
        print(f"[GEN SWITCH] {out_v.relative_to(repo_root)}")
        print(f"               Default : {sim_rel}")
        if viv_rel != sim_rel:
            print(f"               Vivado  : {viv_rel}")
        if asic_t1_rel != sim_rel:
            print(f"               ASIC    : {asic_t1_rel} (helpers: {helper_files})")
        if asic_t2_rel != asic_t1_rel:
            print(f"               ASIC_BB : {asic_t2_rel}")

    # Auto-generate FILE_LISTS/unified/*.f
    gen_flists = generate_unified_filelists(repo_root, flist_out_dir, replaced_files, bundled_helper_files)
    for gfl in gen_flists:
        print(f"[GEN FLIST]  {gfl.relative_to(repo_root)}")

    print("=" * 80)
    print(f"[SUCCESS] Auto-generated {generated_count} unified switches in {out_dir.relative_to(repo_root)}/ and {len(gen_flists)} filelists in {flist_out_dir.relative_to(repo_root)}/")
    print("=" * 80)


def main():
    parser = argparse.ArgumentParser(
        description="Auto-discover flow overrides and generate unified compiler-directive switch wrappers."
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=REPO_ROOT / "UNIFIED_GENERATED",
        help="Destination directory for generated unified switch files (default: UNIFIED_GENERATED/).",
    )
    parser.add_argument(
        "--flist-dir",
        type=Path,
        default=REPO_ROOT / "FILE_LISTS" / "unified",
        help="Destination directory for generated unified filelists (default: FILE_LISTS/unified/).",
    )
    args = parser.parse_args()
    out_dir = args.output_dir if args.output_dir.is_absolute() else REPO_ROOT / args.output_dir
    flist_dir = args.flist_dir if args.flist_dir.is_absolute() else REPO_ROOT / args.flist_dir
    generate_unified_switches(REPO_ROOT, out_dir, flist_dir)


if __name__ == "__main__":
    main()
