# CrocoScale SoC — Automation Scripts & IP Exporter Guide (`scripts/`)

All build automation, code generation, formal verification, and standalone IP packaging tools live in `scripts/`. Every script supports `-h` / `--help` directly from the terminal.

---

## ⚡ Quick Cheat-Sheet: Which Command Do I Run?

| Goal | Command to Run (in WSL) |
| :--- | :--- |
| **Build everything & export all 6 IP packages** (Full formal SAT proofs) | `source ~/custom_functions/custom_functions.sh && pyenv Yosys && ./scripts/export_all.sh` |
| **Fast export of all 6 IP packages** (~10s, skips SAT proofs) | `source ~/custom_functions/custom_functions.sh && pyenv Yosys && ./scripts/export_all.sh -e none` |
| **Export Icarus Simulation package** (`.v` + TBs + C HAL) | `python3 scripts/export_subsystem.py --target efpga_subsystem --flow simulation --format v --include-tb --include-hal` |
| **Export Tier-1 ASIC Container Macros** (`act_bank` / `psum_requant`) | `python3 scripts/export_subsystem.py --target act_bank_container --flow asic --format sv`<br>`python3 scripts/export_subsystem.py --target psum_requant_container --flow asic --format sv` |
| **Export Tier-2 ASIC eFPGA Subsystem** (`.sv` + TBs + `AXI_LIB`) | `python3 scripts/export_subsystem.py --target efpga_subsystem --flow asic --format sv --include-tb --include-lib` |
| **Export Unified Multi-Target package** (`+define+` switched, `.sv` or `.v`) | `python3 scripts/export_subsystem.py --target efpga_subsystem --flow unified --format sv --include-tb --include-hal --include-lib`<br>`python3 scripts/export_subsystem.py --target efpga_subsystem --flow unified --format v --include-tb --include-hal --include-lib` |
| **Regenerate `UNIFIED_GENERATED/` & `FILE_LISTS/unified/`** | `python3 scripts/generate_unified_switches.py` |
| **Sync `MACROS/FABulous/eFPGA_top.v` blackbox after FABulous regen** | `python3 scripts/generate_blackbox_stub.py` |
| **Regenerate `VERILOG_MIRROR_GENERATED/` only** | `./scripts/generate_verilog_mirror.sh` *(or `-e none` for fast mode)* |
| **Flatten a nested `.f` filelist into a single file** | `python3 scripts/flatten_filelists.py -f FILE_LISTS/soc.f -o gemini_workspace/soc_flat.f` |
| **Strip Windows CRLF line endings from all `.f` files** | `python3 scripts/clean_filelists_crlf.py` |

---

## 🛠️ Complete Scripts Reference

### 1. `export_subsystem.py` — Standalone Subsystem & IP Packaging Tool

Resolves a subsystem's filelist tree, rebases submodule paths (via `scripts/export_config.yaml`), and packages a self-contained directory under `exports/<target>_<flow>_<format>/` with a flat `<target>_global.f` filelist and an `EXPORT_MANIFEST.md`.

```bash
python3 scripts/export_subsystem.py --help
```

#### Target & Flow Selection
| Flag | Choices / Default | Description |
| :--- | :--- | :--- |
| `-t`, `--target <NAME>` | `efpga_subsystem` *(default)*, `npu`, `soc`, `act_bank_container`, `psum_requant_container` | Predefined subsystem target to export. |
| `--flow <FLOW>` | `simulation` (`sim`), `asic`, `vivado`, `unified` | Filelist flow tree to walk (`FILE_LISTS/`, `FILE_LISTS/asic/`, `FILE_LISTS/vivado/`, or `FILE_LISTS/unified/`). Defaults to `simulation` when `--format v` and `asic` when `--format sv`. |
| `-f`, `--filelist <PATH>` | `None` | Export any custom `.f` filelist instead of a named `--target`. |

#### Output Format & Destination
| Flag | Choices / Default | Description |
| :--- | :--- | :--- |
| `--format <FMT>` | `v` *(default)*, `sv`, `both` | `v`: pure IEEE 1364-2001 Verilog from `VERILOG_MIRROR_GENERATED/`.<br>`sv`: SystemVerilog from `RTL/` & `MACROS/`.<br>`both`: exports both `.sv` and `.v` side-by-side. |
| `-o`, `--output-dir <DIR>` | `exports/<target>_<flow>_<format>/` | Custom output directory path. |
| `--config <YAML>` | `scripts/export_config.yaml` | YAML file mapping external submodules (e.g. `FABulousProject/`) into clean export subdirectories. |
| `--no-clean` | `False` | Keep existing files in the output directory instead of wiping first. |

#### Optional Bundling Flags
| Flag | Default | Description |
| :--- | :---: | :--- |
| `--include-tb` | `False` | Auto-detects and bundles matching testbenches, test filelists, and `.mem` vectors into `TEST/`. |
| `--include-hal` | `False` | Auto-detects and bundles matching C HAL headers/sources into `HAL/`. |
| `--include-lib` | `False` | Bundles `RTL/AXI_LIB/` into the package and appends required register-slice modules to `<target>_global.f`. |
| `--include-macros` | `False` | Bundles the entire `MACROS/` directory into the exported package. |

---

### 2. `export_all.sh` — Full Pipeline & Multi-Tier Export Wrapper

Runs `generate_unified_switches.py`, `generate_verilog_mirror.sh`, and exports all 6 standard packages (`efpga_subsystem_simulation_v`, `act_bank_container_asic_sv`, `psum_requant_container_asic_sv`, `efpga_subsystem_asic_sv`, `efpga_subsystem_unified_sv`, `efpga_subsystem_unified_v`).

```bash
./scripts/export_all.sh --help
./scripts/export_all.sh           # Full run with Yosys SAT equivalence proofs
./scripts/export_all.sh -e none   # Fast run without SAT proofs
```

---

### 3. `generate_unified_switches.py` — Multi-Target Compiler-Directive Generator

Automatically diffs module/package definitions across `FILE_LISTS/soc.f`, `FILE_LISTS/vivado/soc_vivado.f`, and `FILE_LISTS/asic/*.f`, transpiles `.sv` variants to Verilog-2001 via `sv2v`, wraps them in `` `ifdef `` switches in `UNIFIED_GENERATED/`, and generates `FILE_LISTS/unified/*_unified.f`.

```bash
python3 scripts/generate_unified_switches.py --help
python3 scripts/generate_unified_switches.py
```

#### Supported Compiler Directives in Unified Packages
* *(Default — no defines)*: Behavioral Simulation
* `+define+TARGET_VIVADO`: Xilinx Vivado Emulation
* `+define+TARGET_ASIC`: IHP 130nm CMOS5L ASIC (`sg13cmos5l_lgcp_1`, `RM_IHPSG13_1P_*` SRAMs, `eFPGA_top` blackbox)
* `+define+TARGET_ASIC_CONTAINERS`: Tier-2 Hierarchical ASIC (blackboxes `act_bank_container` & `psum_requant_container`)

---

### 4. `generate_blackbox_stub.py` — Hard Macro Blackbox Stub Generator

Parses a structural/RTL Verilog or SystemVerilog module header and generates a synthesis/lint-ready `(* blackbox *)` Verilog stub with all parameters, ports, and deterministic output tie-offs.

```bash
python3 scripts/generate_blackbox_stub.py --help

# Default: updates MACROS/FABulous/eFPGA_top.v from FABulousProject/CrocoScale_Fabric/Fabric/eFPGA_top.v
python3 scripts/generate_blackbox_stub.py

# Custom module:
python3 scripts/generate_blackbox_stub.py -i <src.v> -o <dst_blackbox.v>
```

---

### 5. `generate_verilog_mirror.sh` — Verilog-2001 Mirror & Formal LEC Runner

Transpiles SystemVerilog sources (`RTL/`, `MACROS/`, `VIVADO/`, `SOFT_LOGIC/`, `TEST/`) into `VERILOG_MIRROR_GENERATED/`, synthesizes the VHDL NEORV32 CPU wrapper via Yosys GHDL, and runs formal SAT equivalence checking.

```bash
./scripts/generate_verilog_mirror.sh --help
```

| Flag | Description |
| :--- | :--- |
| `-e`, `--equiv <mode>` | `leaf` *(default)*: Yosys formal SAT proofs on leaf modules + structural audit fallback.<br>`none`: Fast transpilation only (skips formal verification and lints).<br>`full`: Full hierarchical formal equivalence checking. |
| `-d`, `--dir <path>` | Scope transpilation and verification to a single subdirectory (e.g. `-d SOFT_LOGIC/full`). |
| `-h`, `--help` | Show help message and examples. |

---

### 6. `flatten_filelists.py` — Recursive Filelist Flattener

Resolves nested `-f` / `-c` directives into a single deduplicated flat filelist.

```bash
python3 scripts/flatten_filelists.py --help
python3 scripts/flatten_filelists.py -f FILE_LISTS/efpga_subsystem.f -o gemini_workspace/efpga_flat.f
```

---

### 7. `rebase_filelist.py` — Filelist Path Prefix Rebaser

Rebases path prefixes inside a `.f` filelist without touching the underlying hardware files.

```bash
python3 scripts/rebase_filelist.py --help
python3 scripts/rebase_filelist.py <filelist.f> <rebase_prefix> [output_file.f]
```

---

### 8. `clean_filelists_crlf.py` — Filelist Line-Ending Sanitizer

Converts Windows CRLF (`\r\n`) to Unix LF (`\n`) across `.f` and `.flist` files.

```bash
python3 scripts/clean_filelists_crlf.py --help
python3 scripts/clean_filelists_crlf.py
```
