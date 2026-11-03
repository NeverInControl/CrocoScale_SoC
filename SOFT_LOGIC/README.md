# SOFT_LOGIC

NPU controller variants that run as soft logic in the CrocoScale eFPGA
(`../FABulousProject/CrocoScale_Fabric`). `Taskfile.yml` maps them onto the fabric,
generates the bitstream, and runs the system testbenches on the real fabric.

| design | top module | wrapper | status |
|---|---|---|---|
| `flex` | `npu_flex_sequencer` | `flex/fabulous_top_wrapper.v` | builds, 1098/1152 FLUTs |
| `flex_unoptimized` | `npu_flex_sequencer` | `flex/fabulous_top_wrapper.v` | doesn't fit (~3325 FLUTs) |
| `full` | `npu_full_controller` | `full/fabulous_top_wrapper.v` | doesn't fit (~1781 FLUTs) |
| `minimal` | `npu_min_controller` | none | not buildable |

## Requirements

- [Task](https://taskfile.dev) (`task`; some distros package it as `go-task`)
- `uv`/`uvx` and SSH access to `FPGA-Research/FAB-mapper` and `FPGA-Research/FABulous-bit-gen-OWAS`
- Yosys with the slang plugin (oss-cad-suite)
- For the automatic nextpnr build: git, cmake, a C++ compiler, Boost, Python 3 dev headers
- Vivado xsim, for the `sim*` tasks
- A generated fabric: `../FABulousProject/CrocoScale_Fabric/.FABulous/{bel.v3.txt,pips.txt,placement_estimate.txt,bitStreamSpec.bin}`

## Tasks

Run from this directory, or from the repo root with `task -d SOFT_LOGIC <task>`.

| task | what it does |
|---|---|
| `build DESIGN= TOP= [WRAPPER=]` | FAB-mapper (map, equivalence, route), `bit_gen`, hex |
| `build-flex`, `build-flex-unoptimized`, `build-full`, `all` | `build` with the right TOP/WRAPPER |
| `sim DESIGN= TB=` | `TEST/SoftLogic` system tb in xsim on the real fabric, loaded with DESIGN's bitstream |
| `sim-flex-stress`, `sim-flex-yolo` | `sim` for the flex crossbar-stress / Tiny-YOLOv2 tb (yolo is very slow) |
| `nextpnr` | Build upstream nextpnr (`NEXTPNR_REV`) into `.tools/`; `build` runs it unless `NEXTPNR` is usable |
| `clean` | Remove `build/` |

A build takes ~25 min (mapping) plus ~1 min (routing). Outputs go to `build/<design>/`:
`<design>.bin`, `<design>.hex`, `fab_mapper/` (mapping reports, `routing/design.fasm`).
A sim run goes to `build/<design>/<tb>/sim.log`. It passes only if the tb prints its
`>>> ALL ... <<<` line and no `Fatal:`/`[ERROR]` (xsim exits 0 either way).

## Variables

Override on the command line, e.g. `task build-flex NEXTPNR=/path/to/nextpnr-generic`.

| variable | default |
|---|---|
| `NEXTPNR` | `.tools/nextpnr/build/nextpnr-generic`, built by `task nextpnr`. Any nextpnr with the constant-driver fix works; oss-cad-suite's 0.10 doesn't |
| `NEXTPNR_REV` | `42fc4d5b` (known-good upstream commit) |
| `FAB_MAPPER` | `sat-fab-flut5` from FAB-mapper via uvx |
| `BIT_GEN` | `bit_gen` from FABulous-bit-gen-OWAS via uvx (upstream `bit_gen` fails on this fabric) |
| `MAPPER_WORKERS` / `MAPPER_SELECTION_SECONDS` / `MAPPER_CAPACITY` | `12` / `300` / `1152` |
| `MAPPER_EXTRA_ARGS` | empty; passed to the mapper as-is (e.g. `--mode timing_0`) |
| `MAX_BITBYTES` | `40960`; hex size, must match `TEST/SoftLogic/common/load_fabric_bitstream.svh` |
| `BUILD_DIR` | `build` |

## Fabric simulation

`sim` uses `FILE_LISTS/tb/<tb>_fabric.f`: the tb's filelist with the real fabric (`fabulous.f`)
instead of the RTL harness. With `-d FABRIC_SIM` the tb includes
`TEST/SoftLogic/common/load_fabric_bitstream.svh`. It writes `+bitstream_hex` through the
efpga_manager `CONFIG_DATA` register, as firmware would, then pulses `rst_n`. Without
`FABRIC_SIM` the tbs and the Vivado project are unchanged.

## Gotchas

- FAB-mapper merges the wrapper only after mapping. A port mismatch shows up only in
  `build/<d>/fab_mapper/mapping/*/progress.log` (grep `ERROR`), after ~25 min.
- Keep the wrappers in sync with the RTL ports. The interfaces of flex, full and minimal still differ.
