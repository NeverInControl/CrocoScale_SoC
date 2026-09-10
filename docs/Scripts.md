# Project Automation & Build Scripts

All project automation, code generation, and verification scripts are located in the `scripts/` directory.

---

## `generate_verilog_mirror.sh`

### Purpose
Generates an IEEE Verilog-2001 compliant mirror in `VERILOG_MIRROR_GENERATED/` from the SystemVerilog sources (`RTL/*.sv`) and VHDL CPU complex (`RTL/CPU/`). This enables compatibility with simulators and ASIC flows that do not natively support modern SystemVerilog or VHDL (such as Icarus Verilog).

### Required Toolchain (Must be in `$PATH`)
Before executing the script, ensure the following tools are installed and present in your system `$PATH` or loaded environment:
* **`sv2v`**: SystemVerilog to Verilog transpiler (v0.0.13 or newer).
* **`yosys`**: Open-source synthesis suite with:
  * **`ghdl`** plugin: For synthesizing the VHDL NEORV32 CPU complex.
  * **`slang`** plugin: For SystemVerilog frontend parsing during formal equivalence checks.
* **`iverilog`**: Icarus Verilog (v11 or v12) for automated structural linting and full-SoC elaboration.

### Usage
Execute the script from the repository root:
```bash
./scripts/generate_verilog_mirror.sh
```

### Execution Flow & Actions
The script automatically executes the following pipeline:
* **Directory Mirroring**: Recreates the entire directory structure under `VERILOG_MIRROR_GENERATED/RTL/`.
* **Static File Passthrough**: Copies all static Verilog files (`.v`), headers (`.vh`, `.svh`), and memory initialization tables (`.hex`, `.mem`, `.csv`).
* **SystemVerilog Transpilation**: Converts all SystemVerilog (`.sv`) files to IEEE Verilog-2001 using `sv2v`.
* **VHDL CPU Synthesis**: Synthesizes the NEORV32 RISC-V CPU and its AXI wrapper (`neorv32_axi_wrapper.vhd`) into a standalone Verilog module via Yosys GHDL.
* **Mirrored File Lists**: Translates all file lists (`FILE_LISTS/*.f`) into `VERILOG_MIRROR_GENERATED/FILE_LISTS/`, converting `.sv` references to `.v`.
* **Two-Tier Verification**:
  * **Tier 1 (Formal SAT Proof)**: Runs automated per-file logical equivalence checking (LEC) via Yosys Minisat on all computational leaf modules and state controllers.
  * **Tier 2 (Structural Hierarchy Audit)**: Runs structural elaboration and port binding validation via Icarus Verilog on composite and structural top-level modules.
* **Full-SoC Elaboration**: Runs an end-to-end Icarus Verilog lint check on the entire chip (`iverilog -g2012 -D__ICARUS__ -f FILE_LISTS/soc.f`), confirming zero broken wires or unresolved references across the entire SoC.