# CrocoScale SoC — Automation Scripts & IP Exporter Guide

This directory contains project automation tools for transpilation, formal verification, filelist manipulation, and standalone subsystem IP packaging.

> [!NOTE]
> Canonical documentation is maintained in [`docs/Scripts.md`](file:///c:/Users/Niels/Documents/nct/MyProjects/CrocoScale_SoC/docs/Scripts.md).

---

## 🚀 Standalone IP Subsystem Export Workflow

Because the CrocoScale SoC serves as a **modular IP consortium and test vehicle**, core subsystems (such as the eFPGA Subsystem, NPU Complex, and Soft-Logic Sequencers) can be exported into self-contained packages for third-party chips or external partner projects.

### The 2-Step Export Sequence (Best Practice)

Exporting pure, verified IEEE 1364-2001 Verilog requires running the mirror generator first, followed by the exporter:

```bash
# Step 1: Generate & formally verify pure Verilog mirror
source ~/custom_functions/custom_functions.sh && pyenv Yosys
./scripts/generate_verilog_mirror.sh

# Step 2: Package standalone subsystem into exports/<target>/
python3 scripts/export_subsystem.py --target efpga_subsystem
```

> **Why Step 1 is required before Step 2:**
> The exporter pulls `.v` files directly from `VERILOG_MIRROR_GENERATED/`, which ensures the exported code has passed all 29 Yosys formal SAT equivalence proofs and structural audits before being packaged.

---

## 🛠️ Complete Scripts Reference

### 1. `export_subsystem.py` — Subsystem & IP Packaging Tool

Traverses a subsystem's dependency tree and packages it into an isolated folder under `exports/<target>/` with a root-level flat filelist (`<target>_global.f`) that has **zero external library dependencies**.

#### Syntax & Options
```bash
python3 scripts/export_subsystem.py [OPTIONS]
```

| Argument | Type | Default | Description |
| :--- | :---: | :---: | :--- |
| `--target` | `str` | `efpga_subsystem` | Target subsystem name. Automatically resolves to `FILE_LISTS/<target>.f`. |
| `--filelist` | `path` | `None` | Optional path to export any custom `.f` filelist instead of predefined targets. |
| `--format` | `choice` | `v` | HDL format to package: `v` (pure Verilog from mirror), `sv` (SystemVerilog), or `both`. |
| `--include-tb` | `flag` | `False` | Dynamically discover and bundle associated testbenches, test filelists, and `.mem` vectors into `TEST/`. |
| `--include-hal`| `flag` | `False` | Dynamically discover and bundle matching C driver headers/sources into `HAL/`. |
| `--output-dir` | `path` | `exports/<target>/` | Custom destination directory for the exported package. |
| `--no-clean` | `flag` | `False` | Do not wipe the destination directory before exporting. |

#### HAL Automatic Detection Naming Rule
For C driver files in `HAL/` to be automatically detected and bundled when `--include-hal` is used:
* **The filename in `HAL/` must match the target name or its tokens** (e.g. `HAL/efpga_subsystem_hal.h` matches `--target efpga_subsystem`).
* Alternatively, the filename must match a prominent Verilog module name contained in the exported RTL filelist (e.g. `efpga_manager`).

#### Examples
```bash
# Default: export eFPGA subsystem as pure Verilog (RTL + root filelist, no tests, no HAL)
python3 scripts/export_subsystem.py

# Export NPU Complex with testbenches and golden .mem tensors
python3 scripts/export_subsystem.py --target npu --include-tb

# Export eFPGA Subsystem with both SystemVerilog and Verilog, plus C HAL drivers
python3 scripts/export_subsystem.py --target efpga_subsystem --format both --include-hal

# Export a custom filelist to a custom folder
python3 scripts/export_subsystem.py --filelist FILE_LISTS/soft_logic_full.f --output-dir exports/custom_sequencer/
```

---

### 2. `generate_verilog_mirror.sh` — Verilog Transpilation & Formal Verification

Converts SystemVerilog production code into IEEE 1364-2001 Verilog for legacy toolchains, synthesizes the VHDL CPU wrapper via GHDL/Yosys, and runs formal SAT equivalence checking.

#### Environment Requirement
Must be run inside WSL with the `pyenv Yosys` environment active:
```bash
source ~/custom_functions/custom_functions.sh && pyenv Yosys
./scripts/generate_verilog_mirror.sh [OPTIONS]
```

| Flag | Description |
| :--- | :--- |
| *(no flags)* | Runs full mirror generation, GHDL VHDL synthesis, 29 formal SAT proofs, and Icarus SoC elaboration. |
| `--clean` | Deletes `VERILOG_MIRROR_GENERATED/` before rebuilding from scratch. |
| `--skip-transpile` | Skips `sv2v` conversion and only runs verification checks. |
| `--equiv leaf` | (Default) Runs formal SAT equivalence checking across leaf modules. |
| `--equiv none` | Skips formal equivalence proofs (faster). |

---

### 3. `flatten_filelists.py` — Recursive Filelist Flattener

Recursively traverses nested `-f` and `-c` filelist directives and outputs a single, flat list of unique files. Essential for simulators or synthesis tools that cannot resolve nested includes.

#### Syntax & Options
```bash
python3 scripts/flatten_filelists.py [OPTIONS]
```

| Argument | Type | Default | Description |
| :--- | :---: | :---: | :--- |
| `-f`, `--filelist` | `path` | `FILE_LISTS/soc.f` | Root filelist to parse and flatten. |
| `-o`, `--output` | `path` | stdout | Output file destination (e.g. `FILE_LISTS/global_filelists/soc_global.f`). |
| `--repo-root` | `path` | Repository root | Root directory used for resolving relative paths. |

#### Examples
```bash
# Generate flat global filelist for eFPGA subsystem:
python3 scripts/flatten_filelists.py -f FILE_LISTS/efpga_subsystem.f -o FILE_LISTS/global_filelists/efpga_subsystem_global.f
```

---

### 4. `rebase_filelist.py` — Filelist Path Root Rebaser

Rebases all file paths inside a `.f` filelist from one working directory to another (e.g. converting paths from `.` to `..` or to a target simulator run directory).

#### Syntax & Options
```bash
python3 scripts/rebase_filelist.py [OPTIONS]
```

| Argument | Type | Default | Description |
| :--- | :---: | :---: | :--- |
| `-f`, `--filelist` | `path` | *(required)* | Filelist to rebase. |
| `--old-root` | `path` | `.` | Current base directory of paths in the filelist. |
| `--new-root` | `path` | *(required)* | New base directory that paths should be relative to. |
| `-o`, `--output` | `path` | None | Write rebased filelist to a new file (if omitted, modifies in-place). |

#### Examples
```bash
# Rebase a filelist so paths are relative to a testbench run directory (one level up):
python3 scripts/rebase_filelist.py -f FILE_LISTS/tb/run.f --old-root . --new-root ..
```

---

### 5. `clean_filelists_crlf.py` — Filelist Line-Ending Sanitizer

Strips Windows carriage returns (`\r\n` $\to$ `\n`) and ensures a clean trailing newline on every `.f` filelist across the repository. Prevents Icarus Verilog's command parser from reporting `ERROR: File name not terminated.`

#### Syntax
```bash
python3 scripts/clean_filelists_crlf.py
```
*(Automatically scans `FILE_LISTS/` and subdirectories, cleaning in-place and reporting any modified files).*

