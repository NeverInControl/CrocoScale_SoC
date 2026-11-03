# CrocoScale SoC — eFPGA Soft-Logic Controllers (`SOFT_LOGIC/`)

This directory contains the reconfigurable NPU sequencers and DMA controllers synthesized onto the CrocoScale **FABulous eFPGA fabric** ($9 \times 16$ tile architecture, `144` `FLUT51PSDM` tiles = `1,152` FLUT5s).

---

## Controller Variants & Fabric Utilization

| Variant | Directory | Top Module | Fabric Wrapper | Utilization (`1,152` FLUT5 Capacity) | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`flex`** *(Production)* | `SOFT_LOGIC/flex/` | `npu_flex_sequencer` | `flex/fabulous_top_wrapper.v` | **`1,098 / 1,152` FLUTs (`95.3%`)** | Fits fabric; dual-mode $3 \times 3$ and $1 \times 1$ controller |
| **`flex_unoptimized`** | `SOFT_LOGIC/flex_unoptimized/` | `npu_flex_sequencer` | `flex/fabulous_top_wrapper.v` | `~3,325 / 1,152` FLUTs (`288.6%`) | Baseline unoptimized reference; exceeds fabric capacity |
| **`minimal`** | `SOFT_LOGIC/minimal/` | `npu_min_controller` | — | — | Minimal single-pass RTL test controller |

---

## 1. Bitstream Generation (`scripts/generate_bitstream.py`)

Maps, packs, routes, and generates bitstreams (`SOFT_LOGIC/build/<design>/<design>.bin` and `.hex`) using `FAB-mapper`, `nextpnr-generic`, and `FABulous-bit-gen-OWAS`.

```bash
python3 scripts/generate_bitstream.py --help
```

### Tool Setup & Isolation (`--install-tools`)
To prevent accidental multi-GB downloads, `generate_bitstream.py` **never** downloads or compiles external tools unless `--install-tools` is explicitly passed.
* When `--install-tools` is run, partner tools (`FAB-mapper`, `FABulous-bit-gen-OWAS` — updated to latest) and `nextpnr-generic` (pinned commit `42fc4d5b` for constant-driver compatibility) are installed strictly inside `<repo_root>/tools/` (git-ignored).
* If `yosys` is already active in your shell (`pyenv Yosys`), it is used directly; otherwise `--install-tools` downloads `oss-cad-suite` into `tools/oss-cad-suite/`.

```bash
# One-time setup (or to pull newer versions of FAB-mapper & bit_gen into tools/):
source ~/custom_functions/custom_functions.sh && pyenv Yosys
python3 scripts/generate_bitstream.py --install-tools

# Build the default 'flex' bitstream into SOFT_LOGIC/build/flex/flex.{bin,hex}:
python3 scripts/generate_bitstream.py
```

---

## 2. Full-Fabric Bitstream Simulation (`scripts/run_fabric_sim.py`)

For running a system testbench (`FILE_LISTS/tb/tb_npu_flex_*_fabric.f`) on the real `eFPGA_top` fabric in Vivado `xsim` with the generated bitstream preloaded via `efpga_manager`:

```bash
python3 scripts/run_fabric_sim.py --help

# Run crossbar stress test on the real fabric (requires SOFT_LOGIC/build/flex/flex.hex or --bitstream <file>):
python3 scripts/run_fabric_sim.py --tb tb_npu_flex_crossbar_stress
```
