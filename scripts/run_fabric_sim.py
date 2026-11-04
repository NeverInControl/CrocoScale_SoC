#!/usr/bin/env python3
"""
scripts/run_fabric_sim.py
CrocoScale SoC — Full-Fabric Bitstream Simulation Runner (Vivado xsim)

Compiles and runs a system testbench (FILE_LISTS/tb/<tb>_fabric.f) on the real
FABulous eFPGA_top fabric in Vivado xsim, preloading a generated bitstream (.hex
or .bin) through the efpga_manager CONFIG_DATA register.

Note: Simulating the full gate-level FABulous fabric (1,152 FLUT5s + routing
matrices + bitstream shifting) across multi-layer CNN workloads is extremely
compute-intensive and can take many hours.
"""

import os
import re
import sys
import shutil
import subprocess
import argparse
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent
sys.path.insert(0, str(SCRIPT_DIR))

from flatten_filelists import parse_flist
from generate_bitstream import convert_bin_to_hex, MAX_BITBYTES


def locate_vivado_tool(tool_name: str) -> list:
    """Locates xvlog / xelab / xsim across Linux, native Windows, or WSL calling Windows Vivado."""
    in_path = shutil.which(tool_name)
    if in_path:
        return [in_path]

    bat_in_path = shutil.which(f"{tool_name}.bat")
    if bat_in_path:
        return ["cmd.exe", "/c", bat_in_path] if os.name != "nt" else [bat_in_path]

    search_roots = [
        Path("C:/Xilinx/Vivado"),
        Path("C:/Xilinx"),
        Path("C:/AMDDesignTools/Vivado"),
        Path("C:/AMDDesignTools"),
        Path("/mnt/c/Xilinx/Vivado"),
        Path("/mnt/c/Xilinx"),
        Path("/mnt/c/AMDDesignTools/Vivado"),
        Path("/mnt/c/AMDDesignTools"),
        Path("/tools/Xilinx/Vivado"),
        Path("/opt/Xilinx/Vivado"),
    ]
    for root in search_roots:
        if not root.exists():
            continue
        for ver_dir in sorted(root.iterdir(), reverse=True):
            if not ver_dir.is_dir():
                continue
            for bin_dir in (ver_dir / "bin", ver_dir / "Vivado" / "bin"):
                if not bin_dir.exists():
                    continue
                if os.name == "nt":
                    cand = bin_dir / f"{tool_name}.bat"
                    if cand.exists():
                        return [str(cand)]
                elif str(root).startswith("/mnt/"):
                    cand = bin_dir / f"{tool_name}.bat"
                    if cand.exists():
                        win_path = "C:" + str(cand)[len("/mnt/c"):].replace("/", "\\")
                        return ["cmd.exe", "/c", win_path]
                else:
                    cand = bin_dir / tool_name
                    if cand.exists():
                        return [str(cand)]

    raise FileNotFoundError(
        f"Could not find Vivado '{tool_name}' in PATH or standard Xilinx installation directories."
    )


def to_tool_path(path: Path, is_windows_cmd: bool) -> str:
    """Converts a WSL /mnt/c/... path to C:/... when invoking Windows Vivado from WSL."""
    posix_str = path.resolve().as_posix()
    if is_windows_cmd and posix_str.startswith("/mnt/") and len(posix_str) > 6:
        drive = posix_str[5].upper()
        return f"{drive}:{posix_str[6:]}"
    return posix_str


def main():
    epilog_text = """
Available Fabric Testbenches (-t / --tb):
  tb_npu_flex_crossbar_stress   5-layer CNN crossbar & mode stress test (default)
  tb_npu_flex_yolo_tiny         Full 9-layer Tiny-YOLOv2 end-to-end network test

Examples:
  # Fast single-tile smoke verification of SOFT_LOGIC/build/flex/flex.hex (~6-10 min):
  python3 scripts/run_fabric_sim.py --quick

  # Run full 5-layer crossbar stress test on the real fabric:
  python3 scripts/run_fabric_sim.py

  # Run with a custom .bin or .hex bitstream file:
  python3 scripts/run_fabric_sim.py --tb tb_npu_flex_crossbar_stress --bitstream SOFT_LOGIC/build/flex/flex.bin --quick
"""
    parser = argparse.ArgumentParser(
        prog="python3 scripts/run_fabric_sim.py",
        description="CrocoScale SoC — Full-Fabric Bitstream Simulation Runner (Vivado xsim).",
        epilog=epilog_text,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "-t",
        "--tb",
        default="tb_npu_flex_crossbar_stress",
        help="Fabric system testbench name (default: 'tb_npu_flex_crossbar_stress').",
    )
    parser.add_argument(
        "-b",
        "--bitstream",
        type=Path,
        default=REPO_ROOT / "SOFT_LOGIC" / "build" / "flex" / "flex.hex",
        metavar="FILE",
        help="Bitstream .hex or .bin file to load (default: SOFT_LOGIC/build/flex/flex.hex).",
    )
    parser.add_argument(
        "-q",
        "--quick",
        action="store_true",
        help="Fast single-tile smoke test mode (QUICK_SMOKE=1): verifies 1 tile (2,048 golden outputs) in minutes instead of hours.",
    )
    parser.add_argument(
        "-o",
        "--output-dir",
        type=Path,
        default=None,
        metavar="DIR",
        help="Simulation working directory (default: SOFT_LOGIC/build/sim/<tb>/).",
    )
    args = parser.parse_args()

    flist_path = REPO_ROOT / "FILE_LISTS" / "tb" / f"{args.tb}_fabric.f"
    if not flist_path.exists():
        raise FileNotFoundError(f"Fabric testbench filelist not found: {flist_path}")

    bs_src = args.bitstream if args.bitstream.is_absolute() else (REPO_ROOT / args.bitstream)
    if not bs_src.exists():
        raise FileNotFoundError(
            f"Bitstream file not found: {bs_src}\n"
            f"Generate it first with `python3 scripts/generate_bitstream.py` or pass `--bitstream <path>`."
        )

    sim_dir = (args.output_dir if args.output_dir else (REPO_ROOT / "SOFT_LOGIC" / "build" / "sim" / args.tb)).resolve()
    if sim_dir.exists():
        shutil.rmtree(sim_dir)
    sim_dir.mkdir(parents=True, exist_ok=True)

    hex_path = sim_dir / "bitstream.hex"
    if bs_src.suffix.lower() == ".hex":
        shutil.copy2(bs_src, hex_path)
    else:
        convert_bin_to_hex(bs_src, hex_path, MAX_BITBYTES)

    xvlog_cmd = locate_vivado_tool("xvlog")
    xelab_cmd = locate_vivado_tool("xelab")
    xsim_cmd = locate_vivado_tool("xsim")
    is_win_cmd = xvlog_cmd[0].lower().endswith("cmd.exe") or os.name == "nt"

    files = parse_flist(flist_path, REPO_ROOT)
    v_files = [to_tool_path(REPO_ROOT / f, is_win_cmd) for f in files if f.endswith(".v")]
    sv_files = [to_tool_path(REPO_ROOT / f, is_win_cmd) for f in files if f.endswith(".sv")]
    inc_dir = to_tool_path(REPO_ROOT / "TEST" / "SoftLogic" / "common", is_win_cmd)
    mem_dir = to_tool_path(REPO_ROOT / "TEST" / "GoldenReference", is_win_cmd)
    hex_arg = to_tool_path(hex_path, is_win_cmd)

    print("=" * 80)
    print(f"[SIM] Compiling & running '{args.tb}' on real eFPGA_top fabric")
    print(f"      Mode      : {'QUICK SMOKE (1 tile, 2,048 golden outputs)' if args.quick else 'FULL SUITE'}")
    print(f"      Bitstream : {bs_src}")
    print(f"      Work Dir  : {sim_dir.relative_to(REPO_ROOT)}")
    print("=" * 80)

    if v_files:
        v_flist = sim_dir / "v_files.f"
        v_flist.write_text("\n".join(v_files) + "\n", encoding="utf-8", newline="\n")
        subprocess.run(xvlog_cmd + ["--nolog", "-f", "v_files.f"], cwd=sim_dir, stdin=subprocess.DEVNULL, check=True)
    if sv_files:
        sv_flist = sim_dir / "sv_files.f"
        sv_flist.write_text("\n".join(sv_files) + "\n", encoding="utf-8", newline="\n")
        subprocess.run(
            xvlog_cmd + ["--nolog", "-sv", "-i", inc_dir, "-f", "sv_files.f"],
            cwd=sim_dir,
            stdin=subprocess.DEVNULL,
            check=True,
        )

    snap_name = f"{args.tb}_xsim"
    xelab_lines = [
        "--nolog",
        "-debug off",
        "-O3",
        "-timescale 1ns/1ps",
        "-generic_top FABRIC_SIM=1",
    ]
    if args.quick:
        xelab_lines.append("-generic_top QUICK_SMOKE=1")
    xelab_lines.extend([f"-s {snap_name}", args.tb])

    xelab_opt = sim_dir / "xelab.opt"
    xelab_opt.write_text("\n".join(xelab_lines) + "\n", encoding="utf-8", newline="\n")
    subprocess.run(
        xelab_cmd + ["-f", "xelab.opt"],
        cwd=sim_dir,
        stdin=subprocess.DEVNULL,
        check=True,
    )

    sim_log = sim_dir / "sim.log"
    xsim_lines = [
        snap_name,
        "-R",
        "--log sim.log",
        f"--testplusarg MEM_DIR={mem_dir}",
        f"--testplusarg bitstream_hex={hex_arg}",
    ]
    if args.quick:
        xsim_lines.append("--testplusarg quick_smoke")

    xsim_opt = sim_dir / "xsim.opt"
    xsim_opt.write_text("\n".join(xsim_lines) + "\n", encoding="utf-8", newline="\n")
    subprocess.run(
        xsim_cmd + ["-f", "xsim.opt"],
        cwd=sim_dir,
        stdin=subprocess.DEVNULL,
        check=True,
    )

    log_text = sim_log.read_text(encoding="utf-8", errors="replace")
    if re.search(r"(^Fatal:|\[ERROR\])", log_text, flags=re.MULTILINE) or not re.search(r">>> ALL .*<<<", log_text):
        print(f"[FAIL] Simulation failed! Inspect log at: {sim_log}", file=sys.stderr)
        sys.exit(1)

    print(f"[PASS] Fabric simulation '{args.tb}' passed! Log: {sim_log.relative_to(REPO_ROOT)}")


if __name__ == "__main__":
    main()

