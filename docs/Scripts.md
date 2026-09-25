# Project Automation, Build & IP Exporter Scripts

All project automation, code generation, verification, and IP export scripts are located in the `scripts/` directory.

---

## 🚀 Standalone IP Subsystem Export Workflow

CrocoScale SoC serves not only as a tapeout-ready Edge AI SoC, but fundamentally as a **test vehicle and modular IP library consortium**. Core subsystems (such as the eFPGA Subsystem, NPU Complex, and Soft-Logic Sequencers) are designed for frequent extraction and integration into external partner projects, research chips, or third-party SoCs.

### The 2-Step Export Sequence (Best Practice)

Exporting pure, formally verified IEEE 1364-2001 Verilog requires running the Verilog mirror generator first, followed by the subsystem exporter:

```bash
# Step 1: Transpile SystemVerilog to Verilog-2001 and run formal SAT proofs
source ~/custom_functions/custom_functions.sh && pyenv Yosys
./scripts/generate_verilog_mirror.sh

# Step 2: Package standalone subsystem into exports/<target>/
python3 scripts/export_subsystem.py --target efpga_subsystem
```

> **Why Step 1 is required before Step 2:**
> When exporting with `--format v` (the default), `export_subsystem.py` pulls `.v` files directly from `VERILOG_MIRROR_GENERATED/`. Running `generate_verilog_mirror.sh` beforehand guarantees that all exported Verilog files have passed all 29 Yosys formal SAT equivalence proofs and structural audits before packaging.

---

## 🛠️ Complete Scripts Reference

### 1. `export_subsystem.py` — Subsystem & IP Packaging Tool

Traverses a subsystem's dependency tree and packages it into an isolated, self-contained directory under `exports/<target>/`. It generates a root-level flat filelist (`<target>_global.f`) with **zero external library dependencies**, ready for drag-and-drop integration into external toolchains.

#### Syntax & Options
```bash
python3 scripts/export_subsystem.py [OPTIONS]
```

| Argument | Type | Default | Description |
| :--- | :---: | :---: | :--- |
| `--target` | `str` | `efpga_subsystem` | Target subsystem name. Automatically maps to `FILE_LISTS/<target>.f`. |
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

#### Testbench Auto-Detection
When `--include-tb` is set, the exporter automatically searches `FILE_LISTS/tb/*.f` and testbench directories for files matching the target name tokens or RTL modules, rewriting paths to be self-contained within `exports/<target>/TEST/`.

#### Examples
```bash
# Default: export eFPGA subsystem as pure Verilog (RTL + root filelist, no tests, no HAL)
python3 scripts/export_subsystem.py

# Export NPU Complex with testbenches and golden .mem tensors
python3 scripts/export_subsystem.py --target npu --include-tb

# Export eFPGA Subsystem with both SystemVerilog and Verilog, plus C HAL drivers
python3 scripts/export_subsystem.py --target efpga_subsystem --format both --include-hal

# Export a custom filelist to an arbitrary directory
python3 scripts/export_subsystem.py --filelist FILE_LISTS/soft_logic_full.f --output-dir exports/custom_sequencer/
```

---

### 2. `generate_verilog_mirror.sh` — Verilog Transpilation & Formal Verification

Generates an IEEE Verilog-2001 compliant mirror in `VERILOG_MIRROR_GENERATED/` from SystemVerilog sources (`RTL/*.sv`) and the VHDL CPU complex (`RTL/CPU/neorv32_axi_wrapper.vhd`). Runs formal SAT equivalence checks to prove mathematical equality between SystemVerilog and transpiled Verilog.

#### Required Toolchain (Must be in `$PATH`)
Inside WSL Ubuntu, activate the OSS-CAD-Suite environment:
```bash
source ~/custom_functions/custom_functions.sh && pyenv Yosys
```
Required tools:
* **`sv2v`**: SystemVerilog to Verilog transpiler (`~/.local/bin/sv2v`).
* **`yosys`**: Synthesis suite with `ghdl` plugin (for VHDL NEORV32 CPU synthesis) and `slang` plugin (SystemVerilog parsing during formal equivalence checks).
* **`iverilog`** & **`vvp`**: Icarus Verilog for structural linting and full-SoC elaboration.

#### Usage & Options
```bash
./scripts/generate_verilog_mirror.sh [OPTIONS]
```

| Flag | Description |
| :--- | :--- |
| *(no flags)* | Runs full mirror generation, GHDL VHDL synthesis, 29 formal SAT proofs, and Icarus SoC elaboration. |
| `--clean` | Deletes `VERILOG_MIRROR_GENERATED/` before rebuilding from scratch. |
| `--skip-transpile` | Skips `sv2v` conversion and only runs verification checks. |
| `--equiv leaf` | (Default) Runs formal SAT equivalence checking across leaf modules. |
| `--equiv none` | Skips formal equivalence proofs (faster run). |

#### Execution Pipeline
1. **Directory Mirroring**: Mirrors the directory tree under `VERILOG_MIRROR_GENERATED/RTL/`.
2. **Static File Passthrough**: Copies static Verilog (`.v`), headers (`.vh`, `.svh`), and memory tables (`.hex`, `.mem`, `.csv`).
3. **SystemVerilog Transpilation**: Converts `.sv` files to Verilog-2001 using `sv2v`.
4. **VHDL CPU Synthesis**: Synthesizes `neorv32_axi_wrapper.vhd` into a standalone Verilog module via Yosys GHDL.
5. **Mirrored File Lists**: Translates all `FILE_LISTS/*.f` into `VERILOG_MIRROR_GENERATED/FILE_LISTS/`, updating `.sv` references to `.v`.
6. **Two-Tier Verification**:
   * **Tier 1 (Formal SAT Proof)**: Automated per-file logical equivalence checking (LEC) via Yosys Minisat on all computational leaf modules and state controllers.
   * **Tier 2 (Structural Hierarchy Audit)**: Structural elaboration and port binding validation via Icarus Verilog on composite and structural top-level modules.
7. **Full-SoC Elaboration**: Runs end-to-end Icarus Verilog elaboration on the full chip (`iverilog -g2012 -D__ICARUS__ -f FILE_LISTS/soc.f`), verifying zero unresolved wires or port mismatches across the entire SoC.

---

### 3. `flatten_filelists.py` — Recursive Filelist Flattener

Recursively traverses nested `-f` and `-c` filelist directives and outputs a single, flat list of unique files. Essential for simulators, synthesis tools, or third-party environments that do not support nested filelist includes.

#### Syntax & Options
```bash
python3 scripts/flatten_filelists.py [OPTIONS]
```

| Argument | Type | Default | Description |
| :--- | :---: | :---: | :--- |
| `-f`, `--filelist` | `path` | `FILE_LISTS/soc.f` | Root filelist to parse and recursively flatten. |
| `-o`, `--output` | `path` | `stdout` | Destination file (e.g. `FILE_LISTS/global_filelists/soc_global.f`). |
| `--repo-root` | `path` | Repository root | Root directory used for resolving relative paths. |

#### Examples
```bash
# Generate flat global filelist for eFPGA subsystem:
python3 scripts/flatten_filelists.py -f FILE_LISTS/efpga_subsystem.f -o FILE_LISTS/global_filelists/efpga_subsystem_global.f

# Output flattened SoC filelist directly to console:
python3 scripts/flatten_filelists.py -f FILE_LISTS/soc.f
```

---

### 4. `rebase_filelist.py` — Filelist Path Root Rebaser

Rebases all relative file paths inside a `.f` filelist from one working directory to another (e.g. converting paths from `.` to `..` or to a target simulator execution directory).

#### Syntax & Options
```bash
python3 scripts/rebase_filelist.py [OPTIONS]
```

| Argument | Type | Default | Description |
| :--- | :---: | :---: | :--- |
| `-f`, `--filelist` | `path` | *(required)* | Filelist to rebase. |
| `--old-root` | `path` | `.` | Current base directory of paths in the filelist. |
| `--new-root` | `path` | *(required)* | New base directory that paths should be relative to. |
| `-o`, `--output` | `path` | `None` | Write rebased filelist to a new file (if omitted, modifies in-place). |

#### Examples
```bash
# Rebase a filelist so paths are relative to a testbench run directory (one level up):
python3 scripts/rebase_filelist.py -f FILE_LISTS/tb/run.f --old-root . --new-root ..
```

---

### 5. `clean_filelists_crlf.py` — Filelist Line-Ending Sanitizer

Strips Windows carriage returns (`\r\n` $\to$ `\n`) and ensures a clean trailing newline on every `.f` filelist across the repository. Prevents Icarus Verilog's command-line parser from throwing `ERROR: File name not terminated.`

#### Syntax
```bash
python3 scripts/clean_filelists_crlf.py
```
*(Scans `FILE_LISTS/` and subdirectories recursively, sanitizing files in-place and reporting any modifications).*