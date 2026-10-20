#!/usr/bin/env python3
"""
scripts/export_subsystem.py
CrocoScale SoC — Standalone Subsystem & Modular IP Packaging Exporter

Exports standalone subsystems (e.g. eFPGA Subsystem, NPU Complex, Soft-Logic
Sequencers, or any custom .f filelist) into isolated, self-contained packages.

Defaults:
  --target     : efpga_subsystem
  --format     : v (IEEE 1364-2001 pure Verilog from VERILOG_MIRROR_GENERATED)
  --include-tb : False (Tests excluded by default; use --include-tb to include)
  --include-hal: False (HAL excluded by default; use --include-hal to include)
  --output-dir : exports/<target>/

Features:
  - Dynamic discovery: resolves filelists, testbenches, and HAL drivers automatically.
  - Dual format: resolves RTL from VERILOG_MIRROR_GENERATED (v) or RTL/ (sv) or both.
  - Submodule remapping: configurable YAML rules map external IP into target trees.
  - Clean global filelist: writes standalone filelist with zero library dependencies.
  - Packaging manifest: generates EXPORT_MANIFEST.md with simulation quickstart.
"""

import os
import sys
import shutil
import argparse
import subprocess
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent
sys.path.insert(0, str(SCRIPT_DIR))

try:
    from flatten_filelists import parse_flist
except ImportError:
    def parse_flist(flist_path: Path, repo_root: Path, visited: set = None) -> list:
        if visited is None:
            visited = set()
        real_path = flist_path.resolve()
        if real_path in visited or not flist_path.exists():
            return []
        visited.add(real_path)
        files = []
        with open(flist_path, "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                clean = line.strip().rstrip("\r\n")
                if not clean or clean.startswith(("#", "//")):
                    continue
                parts = clean.split()
                if parts[0] in ("-f", "-c") and len(parts) >= 2:
                    sub_name = parts[1]
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
                    norm = clean.replace("\\", "/")
                    if norm not in files:
                        files.append(norm)
        return files


# -----------------------------------------------------------------------------
# Dynamic Detection Utilities (Zero Hardcoding)
# -----------------------------------------------------------------------------

def resolve_target_filelist(target: str, custom_flist: Path, repo_root: Path, flow: str = "simulation") -> Path:
    """
    Dynamically finds the root filelist for any target across the 3 flow trees:
    - 'simulation': resolves FILE_LISTS/<target>.f
    - 'asic'      : resolves FILE_LISTS/asic/<target>_asic.f (falls back to FILE_LISTS/<target>.f)
    - 'vivado'    : resolves FILE_LISTS/vivado/<target>_vivado.f (falls back to FILE_LISTS/<target>.f)
    """
    if custom_flist:
        p = custom_flist if custom_flist.is_absolute() else repo_root / custom_flist
        if p.exists():
            return p
        raise FileNotFoundError(f"Custom filelist not found: {p}")

    candidates = []
    if flow == "asic":
        candidates.extend([
            repo_root / "FILE_LISTS" / "asic" / f"{target}_asic.f",
            repo_root / "FILE_LISTS" / "asic" / f"{target}_subsystem_asic.f",
            repo_root / "FILE_LISTS" / "asic" / f"{target}.f",
        ])
    elif flow == "vivado":
        candidates.extend([
            repo_root / "FILE_LISTS" / "vivado" / f"{target}_vivado.f",
            repo_root / "FILE_LISTS" / "vivado" / f"{target}_subsystem_vivado.f",
            repo_root / "FILE_LISTS" / "vivado" / f"{target}.f",
        ])
    candidates.extend([
        repo_root / "FILE_LISTS" / f"{target}.f",
        repo_root / "FILE_LISTS" / f"{target}_subsystem.f",
        repo_root / "FILE_LISTS" / target,
    ])
    for c in candidates:
        if c.exists():
            return c
    raise FileNotFoundError(f"No filelist found for target '{target}' (flow='{flow}') in FILE_LISTS/. Tried: {[str(c) for c in candidates]}")


def collect_included_flists(flist_path: Path, repo_root: Path, visited: set = None) -> set:
    """Recursively collects normalized filelist names (e.g. 'npu_asic.f' -> 'npu.f') included by flist_path."""
    if visited is None:
        visited = set()
    real_path = flist_path.resolve()
    if real_path in visited or not flist_path.exists():
        return set()
    visited.add(real_path)

    stem = flist_path.stem
    for sfx in ("_asic", "_vivado"):
        if stem.endswith(sfx):
            stem = stem[:-len(sfx)]
    names = {flist_path.name, f"{stem}.f"}

    with open(flist_path, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            clean = line.strip().rstrip("\r\n")
            if not clean or clean.startswith(("#", "//")):
                continue
            parts = clean.split()
            if parts[0] in ("-f", "-c") and len(parts) >= 2:
                sub_name = parts[1]
                sub_path = (flist_path.parent / sub_name).resolve()
                if not sub_path.exists():
                    sub_path = (repo_root / "FILE_LISTS" / sub_name).resolve()
                if not sub_path.exists():
                    sub_path = (repo_root / sub_name).resolve()
                names |= collect_included_flists(sub_path, repo_root, visited)
    return names


def discover_associated_testbenches(target_name: str, target_flist: Path, repo_root: Path, raw_rtl_files: list) -> list:
    """
    Dynamically discovers testbench filelists in FILE_LISTS/tb/ whose dependencies
    are satisfied by the target filelist tree and its RTL files.
    """
    tb_dir = repo_root / "FILE_LISTS" / "tb"
    if not tb_dir.exists():
        return []

    included_flists = collect_included_flists(target_flist, repo_root)
    rtl_basenames = {Path(f).name for f in raw_rtl_files}
    matched_tb_flists = []

    for tb_flist in sorted(tb_dir.glob("*.f")):
        with open(tb_flist, "r", encoding="utf-8", errors="replace") as f:
            lines = [ln.strip().rstrip("\r\n") for ln in f if ln.strip() and not ln.strip().startswith(("#", "//"))]

        sub_flists = []
        rtl_refs = []
        tb_refs = []
        for ln in lines:
            parts = ln.split()
            if parts[0] in ("-f", "-c") and len(parts) >= 2:
                sub_flists.append(Path(parts[1]).name)
            elif Path(ln).name.startswith("tb_"):
                tb_refs.append(ln)
            else:
                rtl_refs.append(Path(ln).name)

        if not tb_refs:
            continue

        # Check if all -f dependencies and direct RTL references are covered by our target
        flists_covered = all(sf in included_flists for sf in sub_flists)
        rtl_covered = all(rf in rtl_basenames for rf in rtl_refs)
        if flists_covered and rtl_covered and (sub_flists or rtl_refs):
            matched_tb_flists.append(tb_flist)

    return matched_tb_flists


def discover_associated_hal(target_name: str, repo_root: Path, raw_rtl_files: list) -> list:
    """
    Dynamically discovers C HAL header and source files in HAL/ matching the
    target name or any module name contained within the subsystem.
    """
    hal_dir = repo_root / "HAL"
    if not hal_dir.exists():
        return []

    # Clean target tokens (e.g. 'efpga_subsystem' -> {'efpga', 'subsystem'})
    tokens = {t.lower() for t in target_name.replace("-", "_").split("_") if len(t) > 2}
    matched_hal_files = []

    for hal_file in hal_dir.glob("*.[ch]"):
        stem_lower = hal_file.stem.lower()
        # Direct target name match
        if any(tok in stem_lower for tok in tokens):
            matched_hal_files.append(hal_file)
            continue
        # Check against RTL module basenames
        for rf in raw_rtl_files:
            rf_stem = Path(rf).stem.lower()
            if rf_stem in stem_lower and len(rf_stem) > 4:
                matched_hal_files.append(hal_file)
                break

    return sorted(list(set(matched_hal_files)))


def discover_test_directories(target_name: str, repo_root: Path) -> list:
    """Finds associated directories in TEST/ matching target tokens."""
    test_root = repo_root / "TEST"
    if not test_root.exists():
        return []

    matched = []
    tokens = {t.lower() for t in target_name.replace("-", "_").split("_") if len(t) > 2}

    for child in test_root.iterdir():
        if child.is_dir():
            child_lower = child.name.lower()
            if any(tok in child_lower for tok in tokens):
                matched.append(child)

    return matched


def get_git_commit(repo_root: Path) -> str:
    """Safely retrieves current git commit hash if available, without modifying state."""
    try:
        res = subprocess.run(
            ["git", "rev-parse", "--short", "HEAD"],
            cwd=str(repo_root),
            capture_output=True,
            text=True,
            timeout=5,
        )
        if res.returncode == 0:
            return res.stdout.strip()
    except Exception:
        pass
    return "unknown"


def resolve_source_file(rel_path: str, fmt: str, repo_root: Path) -> Path:
    """Resolves source file from VERILOG_MIRROR_GENERATED (for 'v') or repo root (for 'sv')."""
    if fmt == "v":
        mirror_root = repo_root / "VERILOG_MIRROR_GENERATED"
        rel_v = rel_path[:-3] + ".v" if rel_path.endswith(".sv") else rel_path
        cand = mirror_root / rel_v
        try:
            if cand.exists() and cand.stat().st_size > 0:
                return cand
        except OSError:
            pass
        cand_direct = mirror_root / rel_path
        try:
            if cand_direct.exists() and cand_direct.stat().st_size > 0:
                return cand_direct
        except OSError:
            pass
        # Fallback to repo root if mirror file does not exist or is empty
        cand_src = repo_root / rel_v
        try:
            if cand_src.exists() and cand_src.stat().st_size > 0:
                return cand_src
        except OSError:
            pass
        return repo_root / rel_path
    else:
        # SystemVerilog source
        return repo_root / rel_path


# -----------------------------------------------------------------------------
# Configuration & Submodule Path Remapping
# -----------------------------------------------------------------------------

DEFAULT_CONFIG = {
    "path_mappings": [
        {
            "source_prefix": "FABulousProject/CrocoScale_Fabric",
            "export_prefix": "eFPGA_Subsystem/FABulous",
        }
    ],
    "strip_prefixes": ["RTL", "VERILOG_MIRROR_GENERATED"],
}


def load_export_config(config_path: Path = None, repo_root: Path = REPO_ROOT) -> dict:
    """
    Loads exporter configuration from a YAML file.
    Falls back gracefully to built-in path mapping defaults if YAML parser or file is unavailable.
    """
    cfg_file = config_path if config_path else repo_root / "scripts" / "export_config.yaml"
    if not cfg_file.exists():
        return DEFAULT_CONFIG

    try:
        import yaml
        with open(cfg_file, "r", encoding="utf-8") as f:
            data = yaml.safe_load(f)
            if isinstance(data, dict):
                return {
                    "path_mappings": data.get("path_mappings", DEFAULT_CONFIG["path_mappings"]),
                    "strip_prefixes": data.get("strip_prefixes", DEFAULT_CONFIG["strip_prefixes"]),
                }
    except Exception as exc:
        print(f"[WARNING] Could not parse {cfg_file}: {exc}. Using default mappings.")

    return DEFAULT_CONFIG


def remap_export_path(rel_path: str, path_mappings: list, strip_prefixes: list) -> Path:
    """
    Remaps repository-relative file paths into the exported package directory layout.
    Matches external submodule path prefixes before applying standard top-level folder stripping.
    """
    norm = rel_path.replace("\\", "/").strip("/")

    for mapping in path_mappings:
        src_pfx = mapping.get("source_prefix", "").replace("\\", "/").strip("/")
        exp_pfx = mapping.get("export_prefix", "").replace("\\", "/").strip("/")
        if not src_pfx:
            continue
        if norm == src_pfx or norm.startswith(src_pfx + "/"):
            remainder = norm[len(src_pfx):].lstrip("/")
            return Path(exp_pfx) / Path(remainder)

    p = Path(norm)
    if p.parts and p.parts[0] in strip_prefixes:
        return Path(*p.parts[1:])

    return p


# -----------------------------------------------------------------------------
# Main Exporter Routine
# -----------------------------------------------------------------------------

def export_subsystem(
    target: str,
    output_dir: Path,
    custom_flist: Path = None,
    config_path: Path = None,
    flow: str = "simulation",
    fmt: str = "v",
    include_tb: bool = False,
    include_hal: bool = False,
    include_lib: bool = False,
    include_macros: bool = False,
    clean: bool = True,
    repo_root: Path = REPO_ROOT,
):
    print("=" * 80)
    print(f"CrocoScale IP Exporter — Target: '{target}' | Flow: '{flow}' | Format: '{fmt}'")
    print("=" * 80)

    # Resolve target filelist path ('simulation' -> FILE_LISTS/, 'asic' -> FILE_LISTS/asic/, 'vivado' -> FILE_LISTS/vivado/)
    flist_path = resolve_target_filelist(target, custom_flist, repo_root, flow=flow)
    print(f"[INFO] Root filelist: {flist_path}")

    # Parse and flatten RTL dependencies from filelists
    raw_files = parse_flist(flist_path, repo_root)
    print(f"[INFO] Discovered {len(raw_files)} RTL files in dependency tree.")

    # Discover associated testbenches, verification vectors, and HAL drivers
    associated_tb_flists = discover_associated_testbenches(target, flist_path, repo_root, raw_files)
    associated_hal_files = discover_associated_hal(target, repo_root, raw_files)

    print(f"[INFO] Auto-detected {len(associated_tb_flists)} testbench filelists.")
    print(f"[INFO] Auto-detected {len(associated_hal_files)} HAL driver files.")

    # Load path remapping rules and prefix stripping configuration
    config = load_export_config(config_path, repo_root)
    path_mappings = config.get("path_mappings", DEFAULT_CONFIG["path_mappings"])
    strip_prefixes = config.get("strip_prefixes", DEFAULT_CONFIG["strip_prefixes"])

    # Clean up previous export and legacy directories for this module
    if clean:
        if output_dir.exists():
            print(f"[INFO] Removing previous export directory: {output_dir}")
            shutil.rmtree(output_dir)

        for legacy_dir in (
            repo_root / "exports" / target,
            repo_root / "exports" / f"{target}_{fmt}",
        ):
            if legacy_dir.exists() and legacy_dir.resolve() != output_dir.resolve():
                print(f"[INFO] Removing legacy export directory: {legacy_dir}")
                shutil.rmtree(legacy_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    rtl_out_dir = output_dir / "RTL"
    rtl_out_dir.mkdir(parents=True, exist_ok=True)

    # Optionally bundle external AXI library (RTL/AXI_LIB) for backend macro synthesis
    copied_lib_entries = []
    if include_lib:
        axi_lib_src = repo_root / "RTL" / "AXI_LIB"
        axi_lib_dst = rtl_out_dir / "AXI_LIB"
        if axi_lib_src.exists():
            axi_lib_dst.mkdir(parents=True, exist_ok=True)
            for v_file in sorted(axi_lib_src.glob("*.v")):
                shutil.copy2(v_file, axi_lib_dst / v_file.name)
            # Determine which AXI_LIB modules are needed in the flat synthesis filelist
            if target == "soc":
                for v_file in sorted(axi_lib_src.glob("*.v")):
                    copied_lib_entries.append((axi_lib_dst / v_file.name).relative_to(output_dir).as_posix())
            else:
                req_axi_mods = [
                    "axil_register_wr.v",
                    "axil_register_rd.v",
                    "axil_register.v",
                    "axi_register_wr.v",
                    "axi_register_rd.v",
                    "axi_register.v",
                ]
                for mod_name in req_axi_mods:
                    if (axi_lib_dst / mod_name).exists():
                        copied_lib_entries.append((axi_lib_dst / mod_name).relative_to(output_dir).as_posix())
            print(f"[INFO] Bundled RTL/AXI_LIB ({len(list(axi_lib_dst.glob('*.v')))} files; {len(copied_lib_entries)} in global filelist).")

    # Copy RTL source modules preserving directory hierarchy
    copied_rtl_entries = list(copied_lib_entries)
    formats_to_export = ["sv", "v"] if fmt == "both" else [fmt]

    for f_fmt in formats_to_export:
        curr_rtl_dir = rtl_out_dir if fmt != "both" else rtl_out_dir / f_fmt
        curr_rtl_dir.mkdir(parents=True, exist_ok=True)

        for rel_path in raw_files:
            src_file = resolve_source_file(rel_path, f_fmt, repo_root)
            if not src_file.exists():
                print(f"[WARNING] Source file not found: {src_file}")
                continue

            norm_rel = rel_path.replace("\\", "/").strip("/")
            if norm_rel.startswith("MACROS/"):
                curr_macro_dir = output_dir / "MACROS" if fmt != "both" else output_dir / "MACROS" / f_fmt
                rel_macro = Path(*Path(norm_rel).parts[1:])
                dst_file = curr_macro_dir / rel_macro.with_suffix(src_file.suffix)
            elif norm_rel.startswith("VIVADO/"):
                curr_vivado_dir = output_dir / "VIVADO" if fmt != "both" else output_dir / "VIVADO" / f_fmt
                rel_vivado = Path(*Path(norm_rel).parts[1:])
                dst_file = curr_vivado_dir / rel_vivado.with_suffix(src_file.suffix)
            else:
                rel_target = remap_export_path(rel_path, path_mappings, strip_prefixes)
                dst_file = curr_rtl_dir / rel_target.with_suffix(src_file.suffix)

            dst_file.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src_file, dst_file)
            rel_entry = dst_file.relative_to(output_dir).as_posix()
            if rel_entry not in copied_rtl_entries:
                copied_rtl_entries.append(rel_entry)

            # For MACROS/ entries in the ASIC export, also copy any physical collaterals (.gds, .lef, .lib, .def, .spef) in that folder
            if norm_rel.startswith("MACROS/"):
                src_macro_folder = (repo_root / norm_rel).parent
                if src_macro_folder.exists():
                    for ext in ("*.gds", "*.lef", "*.lib", "*.def", "*.spef"):
                        for phys_f in src_macro_folder.glob(ext):
                            dst_phys = dst_file.parent / phys_f.name
                            if not dst_phys.exists():
                                shutil.copy2(phys_f, dst_phys)

        # Optionally copy the complete MACROS/ directory tree (blackboxes, cell/SRAM behavioral models, collaterals)
        if include_macros:
            macros_src_root = repo_root / "MACROS"
            macros_dst_root = output_dir / "MACROS" if fmt != "both" else output_dir / "MACROS" / f_fmt
            if macros_src_root.exists():
                macro_file_count = 0
                for mf_src in sorted(macros_src_root.rglob("*")):
                    if mf_src.is_file():
                        rel_m = mf_src.relative_to(macros_src_root)
                        if f_fmt == "v" and mf_src.suffix == ".sv":
                            resolved_m = resolve_source_file(f"MACROS/{rel_m.as_posix()}", "v", repo_root)
                            dst_m = macros_dst_root / rel_m.with_suffix(resolved_m.suffix)
                            dst_m.parent.mkdir(parents=True, exist_ok=True)
                            shutil.copy2(resolved_m, dst_m)
                        else:
                            dst_m = macros_dst_root / rel_m
                            dst_m.parent.mkdir(parents=True, exist_ok=True)
                            if not dst_m.exists():
                                shutil.copy2(mf_src, dst_m)
                        macro_file_count += 1
                print(f"[INFO] Bundled complete MACROS/ directory ({macro_file_count} files).")

        # For full SoC SystemVerilog export, copy the NeoRV32 VHDL CPU complex 1-to-1
        copied_vhdl_entries = []
        if target == "soc" and f_fmt == "sv":
            cpu_src_dir = repo_root / "RTL" / "CPU"
            if cpu_src_dir.exists():
                cpu_dst_dir = curr_rtl_dir / "CPU"
                cpu_dst_dir.mkdir(parents=True, exist_ok=True)
                for vhd_file in cpu_src_dir.rglob("*.vhd"):
                    rel_vhd = vhd_file.relative_to(cpu_src_dir)
                    target_vhd = cpu_dst_dir / rel_vhd
                    target_vhd.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(vhd_file, target_vhd)
                    copied_vhdl_entries.append(target_vhd.relative_to(output_dir).as_posix())

            wrapper_src = repo_root / "RTL" / "Integration" / "neorv32_axi_wrapper.vhd"
            if wrapper_src.exists():
                wrapper_dst = curr_rtl_dir / "Integration" / wrapper_src.name
                wrapper_dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(wrapper_src, wrapper_dst)
                copied_vhdl_entries.append(wrapper_dst.relative_to(output_dir).as_posix())

            if copied_vhdl_entries:
                vhdl_flist_path = output_dir / f"{target}_vhdl.f"
                with open(vhdl_flist_path, "w", encoding="utf-8", newline="\n") as vf:
                    vf.write("# =============================================================================\n")
                    vf.write(f"# CrocoScale SoC — VHDL CPU Complex Filelist: {target}\n")
                    vf.write("# Auto-generated for mixed-language tools (Vivado read_vhdl)\n")
                    vf.write("# =============================================================================\n\n")
                    pkg_entry = next((e for e in copied_vhdl_entries if "package" in e.lower()), None)
                    if pkg_entry:
                        vf.write(f"{pkg_entry}\n")
                    for ve in sorted(copied_vhdl_entries):
                        if ve != pkg_entry:
                            vf.write(f"{ve}\n")
                print(f"[INFO] Bundled {len(copied_vhdl_entries)} VHDL CPU files and generated {vhdl_flist_path}")

    print(f"[INFO] Copied {len(raw_files)} RTL files into {rtl_out_dir}")

    # Generate root-level standalone flat filelist
    global_flist_name = f"{target}_global.f"
    global_flist_path = output_dir / global_flist_name
    print(f"[INFO] Writing standalone flat filelist: {global_flist_path}")

    lib_note = "Includes AXI_LIB" if include_lib else "External AXI_LIB decoupled"
    with open(global_flist_path, "w", encoding="utf-8", newline="\n") as gf:
        gf.write("# =============================================================================\n")
        gf.write(f"# CrocoScale SoC — Standalone IP Export: {target}\n")
        gf.write(f"# Auto-generated by scripts/export_subsystem.py\n")
        gf.write(f"# Format: {fmt} | {lib_note}\n")
        gf.write("# =============================================================================\n\n")
        for f in copied_rtl_entries:
            gf.write(f"{f}\n")

    # Bundle testbenches and simulation vectors
    copied_tb_count = 0
    copied_mem_count = 0
    if include_tb:
        test_out_dir = output_dir / "TEST"
        test_out_dir.mkdir(parents=True, exist_ok=True)

        # Copy testbenches referenced by associated_tb_flists and rebase their .f filelists
        needs_golden_mem = False
        copied_tb_names = set()
        tb_fmt = "v" if fmt == "v" else "sv"

        for tb_flist_path in associated_tb_flists:
            dst_tb_flist = test_out_dir / tb_flist_path.name
            with open(tb_flist_path, "r", encoding="utf-8") as sf, open(dst_tb_flist, "w", encoding="utf-8", newline="\n") as df:
                df.write(f"# Standalone Testbench Filelist for {tb_flist_path.stem}\n")
                df.write(f"# Run from package root (e.g. iverilog -g2012 -f TEST/{tb_flist_path.name})\n")
                df.write(f"-f ../{global_flist_name}\n\n")
                for line in sf:
                    clean = line.strip().rstrip("\r\n")
                    if clean.startswith(("-f", "-c", "#")) or not clean:
                        continue
                    norm_line = clean.replace("\\", "/").strip("/")
                    if Path(norm_line).name.startswith("tb_"):
                        if "NPU" in norm_line or "SoftLogic" in norm_line:
                            needs_golden_mem = True
                        src_tb = resolve_source_file(norm_line, tb_fmt, repo_root)
                        if src_tb.exists():
                            dst_tb = test_out_dir / src_tb.name
                            if dst_tb.name not in copied_tb_names:
                                shutil.copy2(src_tb, dst_tb)
                                copied_tb_names.add(dst_tb.name)
                                copied_tb_count += 1
                            df.write(f"TEST/{dst_tb.name}\n")

        # Copy GoldenReference .mem vectors if NPU/SoftLogic testbenches are included
        if needs_golden_mem:
            gold_src_dir = repo_root / "TEST" / "GoldenReference"
            gold_out_dir = test_out_dir / "GoldenReference"
            if gold_src_dir.exists():
                gold_out_dir.mkdir(parents=True, exist_ok=True)
                for mem_file in sorted(gold_src_dir.glob("*.mem")):
                    shutil.copy2(mem_file, gold_out_dir / mem_file.name)
                    copied_mem_count += 1

        print(f"[INFO] Bundled TEST/: {copied_tb_count} testbenches and {copied_mem_count} .mem vectors.")

    # Bundle C hardware abstraction layer drivers
    copied_hal_count = 0
    if include_hal:
        if associated_hal_files:
            hal_out_dir = output_dir / "HAL"
            hal_out_dir.mkdir(parents=True, exist_ok=True)
            for hf in associated_hal_files:
                shutil.copy2(hf, hal_out_dir / hf.name)
                copied_hal_count += 1
            print(f"[INFO] Bundled HAL/: {copied_hal_count} C driver files.")
        else:
            print(f"[INFO] No associated HAL driver files found for '{target}' (skipped).")

    # Generate export manifest with metadata and run instructions
    git_sha = get_git_commit(repo_root)
    manifest_path = output_dir / "EXPORT_MANIFEST.md"
    with open(manifest_path, "w", encoding="utf-8", newline="\n") as mf:
        mf.write(f"# CrocoScale IP Package: `{target}` (`{flow}`)\n\n")
        mf.write(f"* **Source Repository**: [CrocoScale SoC](https://github.com/NeverInControl/CrocoScale_SoC)\n")
        mf.write(f"* **Commit**: `{git_sha}`\n")
        mf.write(f"* **Target Flow**: `{flow}` (`{flist_path.relative_to(repo_root).as_posix()}`)\n")
        mf.write(f"* **Format**: `{fmt}`\n")
        mf.write(f"* **RTL Modules**: {len(copied_rtl_entries)} files in `{global_flist_name}`\n\n")
        mf.write("## Package Layout\n\n")
        mf.write(f"* `{global_flist_name}`: Flat, standalone filelist (all paths relative to package root).\n")
        mf.write(f"* `RTL/`: Synthesizable module sources{' (including `RTL/AXI_LIB/`)' if include_lib else ''}.\n")
        if include_macros or any(e.startswith("MACROS/") for e in copied_rtl_entries):
            mf.write(f"* `MACROS/`: Foundry hard macro wrappers, blackbox models, and cell collaterals.\n")
        if any(e.startswith("VIVADO/") for e in copied_rtl_entries):
            mf.write(f"* `VIVADO/`: Vivado emulation primitive wrappers.\n")
        if include_tb:
            mf.write(f"* `TEST/`: Verification testbenches ({copied_tb_count} files) and golden vectors ({copied_mem_count} `.mem` files).\n")
        if include_hal and copied_hal_count > 0:
            mf.write(f"* `HAL/`: C hardware abstraction layer drivers ({copied_hal_count} files).\n")
        mf.write("\n## Simulation / Synthesis Quickstart\n\n")
        mf.write("```bash\n")
        if include_lib:
            mf.write("# Standalone compilation (AXI_LIB included in package):\n")
            mf.write(f"iverilog -g2012 -f {global_flist_name} -o sim.vvp\n")
        else:
            mf.write("# Pass external AXI library via -y <path/to/axi_lib>:\n")
            mf.write(f"iverilog -g2012 -y <path/to/axi_lib> -f {global_flist_name} -o sim.vvp\n")
        mf.write("```\n")

    print(f"[INFO] Generated manifest: {manifest_path}")
    print("=" * 80)
    print(f"[SUCCESS] Export complete! Package ready at: {output_dir}")
    print("=" * 80)


def main():
    parser = argparse.ArgumentParser(
        description="Export standalone subsystems from CrocoScale SoC into self-contained packages."
    )
    parser.add_argument(
        "--target",
        type=str,
        default="efpga_subsystem",
        help="Subsystem target name (default: 'efpga_subsystem').",
    )
    parser.add_argument(
        "--flow",
        "--platform",
        dest="flow",
        type=str,
        choices=["simulation", "sim", "asic", "vivado"],
        default=None,
        help="Filelist flow tree to walk: 'simulation' (FILE_LISTS/<target>.f), 'asic' (FILE_LISTS/asic/<target>_asic.f), or 'vivado' (FILE_LISTS/vivado/<target>_vivado.f).",
    )
    parser.add_argument(
        "--filelist",
        type=Path,
        default=None,
        help="Optional path to a custom .f filelist to export.",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=None,
        help="Destination directory for the exported package (default: exports/<target>_<flow>_<format>/).",
    )
    parser.add_argument(
        "--format",
        type=str,
        choices=["v", "sv", "both"],
        default="v",
        help="HDL format to export: 'v' (pure Verilog from mirror, default), 'sv' (SystemVerilog), or 'both'.",
    )
    parser.add_argument(
        "--include-tb",
        action="store_true",
        default=False,
        help="Include TEST/ directory with testbenches and .mem vectors (default: False).",
    )
    parser.add_argument(
        "--include-hal",
        action="store_true",
        default=False,
        help="Include HAL/ directory with C driver files (default: False).",
    )
    parser.add_argument(
        "--include-lib",
        action="store_true",
        default=False,
        help="Include RTL/AXI_LIB directory and register slice modules for standalone macro synthesis (default: False).",
    )
    parser.add_argument(
        "--include-macros",
        action="store_true",
        default=False,
        help="Include complete MACROS/ directory with all hard macro blackboxes and models (default: False).",
    )
    parser.add_argument(
        "--config",
        type=Path,
        default=None,
        help="Optional path to exporter YAML configuration file (default: scripts/export_config.yaml).",
    )
    parser.add_argument(
        "--no-clean",
        action="store_true",
        help="Do not delete existing output directory before exporting.",
    )

    args = parser.parse_args()

    # Determine flow ('simulation', 'asic', or 'vivado')
    if args.flow:
        flow_name = "simulation" if args.flow == "sim" else args.flow
    elif args.filelist:
        fl_parts = [p.lower() for p in args.filelist.parts]
        if "asic" in fl_parts or args.filelist.stem.endswith("_asic"):
            flow_name = "asic"
        elif "vivado" in fl_parts or args.filelist.stem.endswith("_vivado"):
            flow_name = "vivado"
        else:
            flow_name = "simulation"
    else:
        flow_name = "asic" if args.format == "sv" else "simulation"

    # Normalize target name (strip _asic / _vivado if derived from --filelist)
    if args.filelist:
        target_name = args.filelist.stem
        for sfx in ("_asic", "_vivado"):
            if target_name.endswith(sfx):
                target_name = target_name[:-len(sfx)]
    else:
        target_name = args.target

    if args.output_dir:
        out_dir = args.output_dir
    else:
        fmt_sfx = f"_{args.format}" if args.format != "both" else ""
        out_dir = REPO_ROOT / "exports" / f"{target_name}_{flow_name}{fmt_sfx}"

    export_subsystem(
        target=target_name,
        output_dir=out_dir,
        custom_flist=args.filelist,
        config_path=args.config,
        flow=flow_name,
        fmt=args.format,
        include_tb=args.include_tb,
        include_hal=args.include_hal,
        include_lib=args.include_lib,
        include_macros=args.include_macros,
        clean=not args.no_clean,
    )


if __name__ == "__main__":
    main()
