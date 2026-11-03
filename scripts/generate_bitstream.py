#!/usr/bin/env python3
"""
scripts/generate_bitstream.py
CrocoScale SoC — Soft-Logic Bitstream Compiler

Maps, packs, routes, and generates bitstreams (.bin & .hex) for NPU soft-logic
controllers targeting the CrocoScale FABulous eFPGA fabric (9x16 architecture).

Safety & Tool Isolation Guarantee:
  - By default, this script NEVER downloads or compiles external tools. If a
    required tool is missing (e.g. wrong venv open), it exits immediately with
    a clear message instead of triggering a large download.
  - When `--install-tools` is explicitly passed, partner tools (`FAB-mapper`,
    `FABulous-bit-gen-OWAS`), `nextpnr-generic`, and (if `yosys` is not active
    in PATH) `oss-cad-suite` are installed/updated strictly inside `<repo_root>/tools/`.
"""

import os
import sys
import shutil
import tarfile
import urllib.request
import json
import subprocess
import argparse
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent
FAB_PROJ_ROOT = REPO_ROOT / "FABulousProject" / "CrocoScale_Fabric"
TOOLS_DIR = REPO_ROOT / "tools"
BUILD_ROOT = REPO_ROOT / "SOFT_LOGIC" / "build"

# Internal Mapper & Fabric Constants
NEXTPNR_REV = "42fc4d5b"
MAX_BITBYTES = 39316
FABRIC_CAPACITY = 1152
MAPPER_WORKERS = 4
MAPPER_SELECTION_SECONDS = 300

FAB_MAPPER_REPO = "git+ssh://git@github.com/FPGA-Research/FAB-mapper.git"
BIT_GEN_REPO = "git+ssh://git@github.com/FPGA-Research/FABulous-bit-gen-OWAS.git"

DESIGN_PRESETS = {
    "flex": {
        "subdir": "SOFT_LOGIC/flex",
        "top": "npu_flex_sequencer",
        "wrapper": "SOFT_LOGIC/flex/fabulous_top_wrapper.v",
        "desc": "Dual-mode (3x3 & 1x1) Flex NPU Sequencer (1098 / 1152 FLUTs — fits fabric)",
    },
    "flex_unoptimized": {
        "subdir": "SOFT_LOGIC/flex_unoptimized",
        "top": "npu_flex_sequencer",
        "wrapper": "SOFT_LOGIC/flex/fabulous_top_wrapper.v",
        "desc": "Unoptimized Flex Sequencer (~3325 FLUTs — exceeds 9x16 fabric)",
    },
}


def get_isolated_env() -> dict:
    """
    Returns an environment dict pointing uv/uvx and local tool binaries strictly
    to <repo_root>/tools/ without modifying system/user directories.
    """
    env = os.environ.copy()
    # Strip oss-cad-suite Python overrides and force system shared libraries first
    # so oss-cad-suite's bundled older glibc/libstdc++ never overrides Ubuntu's libs
    for var in ("PYTHONHOME", "PYTHONPATH", "PYTHONEXECUTABLE", "PYTHONNOUSERSITE"):
        env.pop(var, None)
    env["LD_LIBRARY_PATH"] = "/lib/x86_64-linux-gnu:/usr/lib/x86_64-linux-gnu"
    env["UV_CACHE_DIR"] = str((TOOLS_DIR / "uv_cache").resolve())
    env["UV_TOOL_DIR"] = str((TOOLS_DIR / "uv_tools").resolve())
    env["UV_TOOL_BIN_DIR"] = str((TOOLS_DIR / "bin").resolve())
    env["UV_PYTHON_INSTALL_DIR"] = str((TOOLS_DIR / "uv_python").resolve())

    # Prepend tools/bin and tools/oss-cad-suite/bin (if installed locally), plus ~/.local/bin for uv
    extra_paths = []
    tools_bin = TOOLS_DIR / "bin"
    oss_bin = TOOLS_DIR / "oss-cad-suite" / "bin"
    home_local_bin = Path.home() / ".local" / "bin"
    home_cargo_bin = Path.home() / ".cargo" / "bin"
    if tools_bin.exists():
        extra_paths.append(str(tools_bin.resolve()))
    if oss_bin.exists():
        extra_paths.append(str(oss_bin.resolve()))
    for p in (home_local_bin, home_cargo_bin):
        if p.exists():
            extra_paths.append(str(p.resolve()))
    if extra_paths:
        env["PATH"] = os.pathsep.join(extra_paths + [env.get("PATH", "")])
    return env


def resolve_tool_paths(env: dict) -> dict:
    """Checks where yosys, nextpnr-generic, sat-fab-flut5, and bit_gen are located."""
    path_var = env.get("PATH", "")

    yosys_bin = shutil.which("yosys", path=path_var)
    yosys_cfg = shutil.which("yosys-config", path=path_var)

    nextpnr_local = TOOLS_DIR / "nextpnr" / "build" / "nextpnr-generic"
    if nextpnr_local.exists():
        # Create a lightweight wrapper in tools/bin/ so nextpnr-generic always uses
        # system glibc/libstdc++ and (if linked against oss-cad-suite libpython) valid PYTHONHOME,
        # without polluting the outer Python 3.13 environment of FAB-mapper.
        wrapper_path = TOOLS_DIR / "bin" / "nextpnr-generic-wrapped"
        wrapper_path.parent.mkdir(parents=True, exist_ok=True)
        pyhome_line = ""
        if yosys_bin:
            oss_root = Path(yosys_bin).resolve().parent.parent
            if (oss_root / "lib").exists():
                pyhome_line = f'export PYTHONHOME="{oss_root}"\n'
        wrapper_content = (
            "#!/usr/bin/env bash\n"
            'export LD_LIBRARY_PATH="/lib/x86_64-linux-gnu:/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"\n'
            f"{pyhome_line}"
            f'exec "{nextpnr_local.resolve()}" "$@"\n'
        )
        wrapper_path.write_text(wrapper_content, encoding="utf-8", newline="\n")
        wrapper_path.chmod(0o755)
        nextpnr_bin = str(wrapper_path.resolve())
    else:
        nextpnr_bin = os.environ.get("NEXTPNR")

    mapper_local = TOOLS_DIR / "bin" / "sat-fab-flut5"
    mapper_bin = str(mapper_local.absolute()) if mapper_local.exists() else shutil.which("sat-fab-flut5", path=path_var)

    bitgen_local = TOOLS_DIR / "bin" / "bit_gen"
    bitgen_bin = str(bitgen_local.absolute()) if bitgen_local.exists() else shutil.which("bit_gen", path=path_var)

    return {
        "yosys": yosys_bin,
        "yosys_config": yosys_cfg,
        "nextpnr": nextpnr_bin,
        "fab_mapper": mapper_bin,
        "bit_gen": bitgen_bin,
    }


def install_or_update_tools():
    """
    Explicitly installs or updates isolated tools inside <repo_root>/tools/:
      - oss-cad-suite (only if yosys is not already active in PATH)
      - nextpnr-generic (pinned commit 42fc4d5b with constant-driver fix)
      - FAB-mapper (latest commit from FPGA-Research/FAB-mapper)
      - FABulous-bit-gen-OWAS (latest commit from FPGA-Research/FABulous-bit-gen-OWAS)
    """
    TOOLS_DIR.mkdir(parents=True, exist_ok=True)
    for sub in ("uv_cache", "uv_tools", "bin", "uv_python"):
        (TOOLS_DIR / sub).mkdir(parents=True, exist_ok=True)

    env = get_isolated_env()

    # Check Yosys (use active pyenv Yosys if present; otherwise download oss-cad-suite into tools/)
    if shutil.which("yosys", path=env.get("PATH", "")):
        print(f"[TOOLS] Found active Yosys: {shutil.which('yosys', path=env.get('PATH', ''))}")
    else:
        print("[TOOLS] Yosys not found in PATH; downloading latest oss-cad-suite into tools/oss-cad-suite/...")
        api_url = "https://api.github.com/repos/YosysHQ/oss-cad-suite-build/releases/latest"
        with urllib.request.urlopen(api_url) as resp:
            rel_data = json.loads(resp.read().decode("utf-8"))
        asset_url = None
        for asset in rel_data.get("assets", []):
            name = asset.get("name", "")
            if "linux-x64" in name and name.endswith(".tgz"):
                asset_url = asset.get("browser_download_url")
                break
        if not asset_url:
            raise RuntimeError("Could not find linux-x64 .tgz asset in oss-cad-suite-build latest release.")
        tgz_path = TOOLS_DIR / "oss-cad-suite.tgz"
        urllib.request.urlretrieve(asset_url, tgz_path)
        with tarfile.open(tgz_path, "r:gz") as tar:
            tar.extractall(path=TOOLS_DIR)
        tgz_path.unlink()
        env = get_isolated_env()
        print(f"[TOOLS] Installed oss-cad-suite into {TOOLS_DIR / 'oss-cad-suite'}")

    # Build or update nextpnr-generic (42fc4d5b) in tools/nextpnr/
    nextpnr_root = TOOLS_DIR / "nextpnr"
    nextpnr_bin = nextpnr_root / "build" / "nextpnr-generic"
    need_nextpnr_clone = True
    if (nextpnr_root / ".git").exists():
        curr_rev = subprocess.check_output(
            ["git", "-C", str(nextpnr_root), "rev-parse", "--short", "HEAD"], text=True
        ).strip()
        if curr_rev.startswith(NEXTPNR_REV[:7]):
            need_nextpnr_clone = False
            if nextpnr_bin.exists():
                print(f"[TOOLS] nextpnr-generic is already built at commit {curr_rev} ({nextpnr_bin.relative_to(REPO_ROOT)})")

    if not nextpnr_bin.exists() or need_nextpnr_clone:
        if need_nextpnr_clone:
            print(f"[TOOLS] Cloning nextpnr-generic ({NEXTPNR_REV}) into tools/nextpnr/...")
            if nextpnr_root.exists():
                shutil.rmtree(nextpnr_root)
            subprocess.run(["git", "clone", "https://github.com/YosysHQ/nextpnr.git", str(nextpnr_root)], check=True)
            subprocess.run(["git", "-C", str(nextpnr_root), "checkout", NEXTPNR_REV], check=True)
        else:
            print(f"[TOOLS] Resuming nextpnr-generic ({NEXTPNR_REV}) build in tools/nextpnr/build/...")

        if not (nextpnr_root / "build" / "Makefile").exists():
            subprocess.run(
                [
                    "cmake",
                    "-S", str(nextpnr_root),
                    "-B", str(nextpnr_root / "build"),
                    "-DARCH=generic",
                    "-DCMAKE_BUILD_TYPE=Release",
                    "-DBUILD_GUI=OFF",
                    "-DBUILD_PYTHON=OFF",
                ],
                check=True,
            )
        # Cap parallel C++ compile jobs to 4 to prevent WSL2 OOM-killer from terminating cc1plus
        subprocess.run(
            ["cmake", "--build", str(nextpnr_root / "build"), "--target", "nextpnr-generic", "--parallel", "4"],
            check=True,
        )
        print(f"[TOOLS] Built nextpnr-generic: {nextpnr_bin.relative_to(REPO_ROOT)}")

    # Install / upgrade FAB-mapper and FABulous-bit-gen-OWAS into tools/uv_tools/ & tools/bin/
    if not shutil.which("uv", path=env.get("PATH", "")):
        raise FileNotFoundError(
            "Required package manager 'uv' not found in PATH.\n"
            "Install uv (https://docs.astral.sh/uv/) to fetch FAB-mapper and FABulous-bit-gen-OWAS."
        )

    print("[TOOLS] Installing / updating latest FAB-mapper (sat-fab-flut5) into tools/...")
    subprocess.run(
        ["uv", "tool", "install", "--upgrade", "--python", "3.13", FAB_MAPPER_REPO],
        env=env,
        check=True,
    )

    print("[TOOLS] Installing / updating latest FABulous-bit-gen-OWAS (bit_gen) into tools/...")
    subprocess.run(
        ["uv", "tool", "install", "--upgrade", "--python", "3.13", BIT_GEN_REPO],
        env=env,
        check=True,
    )
    print("[TOOLS] All bitstream tools are installed and up to date in tools/.")


def verify_tools_ready(env: dict) -> dict:
    """Verifies all required tools exist before running a build; fails fast with a helpful message if not."""
    paths = resolve_tool_paths(env)
    missing = [name for name, p in paths.items() if not p]
    if missing:
        print("=" * 80, file=sys.stderr)
        print(f"[ERROR] Missing required bitstream build tools: {', '.join(missing)}", file=sys.stderr)
        print("", file=sys.stderr)
        print("To prevent accidental multi-GB downloads, automatic tool installation is disabled by default.", file=sys.stderr)
        print("  1. Make sure your Yosys environment is active (`source ~/custom_functions/custom_functions.sh && pyenv Yosys`).", file=sys.stderr)
        print("  2. Run once with `--install-tools` to download/build partner tools into `tools/`:", file=sys.stderr)
        print("       python3 scripts/generate_bitstream.py --install-tools", file=sys.stderr)
        print("=" * 80, file=sys.stderr)
        sys.exit(1)
    return paths


def convert_bin_to_hex(bin_path: Path, hex_path: Path, max_bytes: int = MAX_BITBYTES):
    """Converts a binary FABulous bitstream (.bin) to a byte-per-line .hex file."""
    data = bin_path.read_bytes()
    if len(data) > max_bytes:
        raise ValueError(f"Bitstream {bin_path} ({len(data)} B) exceeds MAX_BITBYTES ({max_bytes} B).")
    hex_path.parent.mkdir(parents=True, exist_ok=True)
    with open(hex_path, "w", encoding="utf-8", newline="\n") as f:
        for i in range(max_bytes):
            if i < len(data):
                f.write(f"{data[i]:02x}\n")
            else:
                f.write("0\n")
    print(f"[HEX] Wrote {hex_path.relative_to(REPO_ROOT)} ({len(data)} bitstream bytes, {max_bytes} total lines)")


def build_design(design_name: str, custom_out_dir: Path = None, route_only: bool = False):
    env = get_isolated_env()
    tools = verify_tools_ready(env)

    preset = DESIGN_PRESETS[design_name]
    design_dir = REPO_ROOT / preset["subdir"]
    top_mod = preset["top"]
    wrapper_path = (REPO_ROOT / preset["wrapper"]).resolve()
    out_dir = (custom_out_dir if custom_out_dir else (BUILD_ROOT / design_name)).resolve()

    if route_only:
        mapping_root = out_dir / "fab_mapper" / "mapping"
        netlist_candidates = sorted(mapping_root.glob("*/nextpnr.json")) if mapping_root.exists() else []
        if not netlist_candidates:
            raise FileNotFoundError(
                f"--route-only requested, but no existing mapped netlist found under {mapping_root}."
            )
        netlist_json = netlist_candidates[-1]
        routing_dir = out_dir / "fab_mapper" / "routing"
        if routing_dir.exists():
            shutil.rmtree(routing_dir)

        sat_fab_py = TOOLS_DIR / "uv_tools" / "sat-fab" / "bin" / "python"
        router2_matches = list(
            (TOOLS_DIR / "uv_tools" / "sat-fab").glob(
                "lib/python*/site-packages/flows/multi_map/fabulous_fabric_v2/assets/router2_settings.json"
            )
        )
        if not sat_fab_py.exists() or not router2_matches:
            raise FileNotFoundError("Could not locate sat-fab Python environment in tools/uv_tools/sat-fab.")

        route_cmd = [
            str(sat_fab_py.absolute()),
            "-m", "flows.multi_map.fabulous_fabric_v2.route",
            "--netlist", str(netlist_json.resolve()),
            "--bel-v3-file", str((FAB_PROJ_ROOT / ".FABulous" / "bel.v3.txt").resolve()),
            "--pips-file", str((FAB_PROJ_ROOT / ".FABulous" / "pips.txt").resolve()),
            "--placement-estimate-file", str((FAB_PROJ_ROOT / ".FABulous" / "placement_estimate.txt").resolve()),
            "--results-dir", str(routing_dir.resolve()),
            "--nextpnr-executable", tools["nextpnr"],
            "--router2-settings-file", str(router2_matches[0].resolve()),
        ]
        print("=" * 80)
        print(f"[1/3] Routing existing mapped netlist ({netlist_json.relative_to(REPO_ROOT)})...")
        print("=" * 80)
        subprocess.run(route_cmd, cwd=REPO_ROOT, env=env, check=True)
    else:
        if out_dir.exists():
            shutil.rmtree(out_dir)
        out_dir.mkdir(parents=True, exist_ok=True)

        yosys_datdir = subprocess.check_output([tools["yosys_config"], "--datdir"], text=True, env=env).strip()
        prims_fabulous = f"{yosys_datdir}/fabulous/prims.v"
        prims_custom = str((FAB_PROJ_ROOT / "user_design" / "custom_prims.v").resolve())

        sv_files = sorted(str(p.resolve()) for p in design_dir.glob("*.sv"))
        if not sv_files:
            raise FileNotFoundError(f"No .sv files found in {design_dir}")

        mapper_cmd = [
            tools["fab_mapper"],
            *sv_files,
            "--top-module", top_mod,
            "--merge-top-wrapper", str(wrapper_path),
            "--results-dir", str(out_dir / "fab_mapper"),
            "--bel-v3-file", str((FAB_PROJ_ROOT / ".FABulous" / "bel.v3.txt").resolve()),
            "--pips-file", str((FAB_PROJ_ROOT / ".FABulous" / "pips.txt").resolve()),
            "--placement-estimate-file", str((FAB_PROJ_ROOT / ".FABulous" / "placement_estimate.txt").resolve()),
            "--custom-primitives", prims_fabulous, prims_custom,
            "--workers", str(MAPPER_WORKERS),
            "--selection-seconds", str(MAPPER_SELECTION_SECONDS),
            "--source-lut-size", "4",
            "--capacity", str(FABRIC_CAPACITY),
            "--nextpnr-executable", tools["nextpnr"],
        ]

        print("=" * 80)
        print(f"[1/3] Mapping, Packing & Routing '{design_name}' ({top_mod})...")
        print("=" * 80)
        subprocess.run(mapper_cmd, cwd=REPO_ROOT, env=env, check=True)

    fasm_path = out_dir / "fab_mapper" / "routing" / "design.fasm"
    bin_path = out_dir / f"{design_name}.bin"
    hex_path = out_dir / f"{design_name}.hex"
    spec_bin = (FAB_PROJ_ROOT / ".FABulous" / "bitStreamSpec.bin").resolve()

    print("=" * 80)
    print(f"[2/3] Generating Bitstream Binary ({bin_path.relative_to(REPO_ROOT)})...")
    print("=" * 80)
    subprocess.run(
        [tools["bit_gen"], "-genBitstream", str(fasm_path), str(spec_bin), str(bin_path)],
        cwd=REPO_ROOT,
        env=env,
        check=True,
    )

    print("=" * 80)
    print(f"[3/3] Generating Bitstream Hex ({hex_path.relative_to(REPO_ROOT)})...")
    print("=" * 80)
    convert_bin_to_hex(bin_path, hex_path, MAX_BITBYTES)
    print("=" * 80)
    print(f"[SUCCESS] Bitstream ready in: {out_dir.relative_to(REPO_ROOT)}/")
    print("=" * 80)


def main():
    epilog_text = """
Available Designs (-d / --design):
  flex               Dual-mode (3x3 & 1x1) Flex NPU Sequencer (1098 / 1152 FLUTs — fits fabric)
  flex_unoptimized   Unoptimized Flex Sequencer (~3325 FLUTs — exceeds 9x16 fabric)
  all                Compile all designs sequentially

Tool Isolation & --install-tools:
  - No tools are ever downloaded unless `--install-tools` is explicitly passed.
  - `--install-tools` installs/updates `FAB-mapper` (latest), `FABulous-bit-gen-OWAS` (latest),
    `nextpnr-generic` (pinned commit 42fc4d5b), and `oss-cad-suite` (only if `yosys` is not
    already in PATH) strictly inside `<repo_root>/tools/` (git-ignored).

Examples:
  # First-time setup (or to pull newer versions of FAB-mapper & bit_gen into tools/):
  source ~/custom_functions/custom_functions.sh && pyenv Yosys
  python3 scripts/generate_bitstream.py --install-tools

  # Compile the default 'flex' bitstream into SOFT_LOGIC/build/flex/flex.{bin,hex}:
  python3 scripts/generate_bitstream.py

  # Clean SOFT_LOGIC/build/ directory:
  python3 scripts/generate_bitstream.py --clean
"""
    parser = argparse.ArgumentParser(
        prog="python3 scripts/generate_bitstream.py",
        description="CrocoScale SoC — Soft-Logic Bitstream Compiler (FAB-mapper + nextpnr + bit_gen).",
        epilog=epilog_text,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "-d",
        "--design",
        choices=list(DESIGN_PRESETS.keys()) + ["all"],
        default="flex",
        help="Soft-logic design under SOFT_LOGIC/ to compile (default: 'flex').",
    )
    parser.add_argument(
        "-o",
        "--output-dir",
        type=Path,
        default=None,
        metavar="DIR",
        help="Custom output directory (default: SOFT_LOGIC/build/<design>/).",
    )
    parser.add_argument(
        "--route-only",
        action="store_true",
        help="Skip synthesis/mapping and only run nextpnr routing + bit_gen on an existing mapped netlist.",
    )
    parser.add_argument(
        "--install-tools",
        action="store_true",
        help="Download/compile or update partner tools (FAB-mapper, bit_gen, nextpnr, yosys) in tools/.",
    )
    parser.add_argument(
        "--clean",
        action="store_true",
        help="Remove the SOFT_LOGIC/build/ output directory and exit.",
    )

    args = parser.parse_args()

    if args.clean:
        if BUILD_ROOT.exists():
            shutil.rmtree(BUILD_ROOT)
            print(f"[CLEAN] Removed {BUILD_ROOT.relative_to(REPO_ROOT)}/")
        else:
            print("[CLEAN] SOFT_LOGIC/build/ does not exist (nothing to clean).")
        return

    if args.install_tools:
        install_or_update_tools()
        # If the user only passed --install-tools (without -d/-o), stop after installing tools
        if len(sys.argv) == 2 and sys.argv[1] == "--install-tools":
            return

    designs = list(DESIGN_PRESETS.keys()) if args.design == "all" else [args.design]
    for d in designs:
        build_design(d, args.output_dir, route_only=args.route_only)


if __name__ == "__main__":
    main()
