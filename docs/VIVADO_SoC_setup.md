# Vivado SoC Emulation & Simulation Setup

This guide details how to emulate the CrocoScale SoC on Xilinx Vivado (targeting the Digilent Nexys Video XC7A200T) and run simulation testbenches under Vivado XSim.

---

## 1. Resolving Duplicate Module Definitions from FABulous

### The Failure:
FABulous tile generators output common shared primitives (e.g., `models_pack.v`, `LUT4c_frame_config_dffesr.v`, `MUX8LUT_frame_config_mux.v`) redundantly inside *every* individual tile subfolder (`LUT4AB/`, `RAM_IO_W/`, `AXIL_S_IO_W/`, etc.). 

If you add the `FABulous/` tree recursively into a Vivado project, synthesis immediately halts with fatal errors:
```text
ERROR: [Synth 8-2490] overwriting previous definition of module 'LUT4c_frame_config_dffesr'
ERROR: [Synth 8-2490] overwriting previous definition of module 'cus_mux41'
```

### Option A: Curated File List (Recommended)
Do not perform a recursive folder import. Curate a single-instance file list ensuring each primitive is imported exactly once:

1. Create a dedicated shared primitives section in your file list (e.g. `FILE_LISTS/fabulous.f`).
2. Add only one instance of each primitive from the top-level `Fabric/` or primary tile directory:
   ```text
   RTL/eFPGA_Subsystem/FABulous/Fabric/models_pack.v
   RTL/eFPGA_Subsystem/FABulous/Tile/LUT4AB/LUT4c_frame_config_dffesr.v
   RTL/eFPGA_Subsystem/FABulous/Tile/LUT4AB/MUX8LUT_frame_config_mux.v
   RTL/eFPGA_Subsystem/FABulous/Tile/RegFile/RegFile_32x4.v
   ```
3. Import only unique tile top files (`<Tile>.v`), switch matrices (`<Tile>_switch_matrix.v`), and configuration memories (`<Tile>_ConfigMem.v`) for remaining tiles.
4. Exclude all redundant duplicate `.v` files located inside child tile subdirectories from the Vivado file set (`sources_1`).

### Option B: Post-Import Tcl Cleanup (If Entire Folder Was Imported)
If you imported the entire `FABulous/` directory recursively into Vivado (via GUI **Add Sources** -> **Add Directories** or `add_files [glob RTL/.../FABulous]`), you can remove the duplicate definitions directly from the Vivado Tcl console without re-creating your project.

#### Direct Removal via Explicit Tcl Patterns:
Run the following command in the Vivado Tcl Console to remove the duplicate child tile primitives from `sources_1`:

```tcl
# Remove duplicate primitives generated in secondary tile subdirectories
remove_files -quiet [get_files {
    */Tile/AXIL_S_IO_E/AXIL_S_BEL.v
    */Tile/AXI_M_IO_E/AXI_M_BEL.v
    */Tile/E_IO/Config_access.v
    */Tile/E_IO/IO_1_bidirectional_frame_config_pass.v
    */Tile/RAM_IO/Config_access.v
    */Tile/RAM_IO/InPass4_frame_config_mux.v
    */Tile/RAM_IO/OutPass4_frame_config_mux.v
    */Tile/RAM_IO_W/Config_access.v
    */Tile/S_IO/User_project_IO.v
}]
```

#### Automated Tcl Deduplication Script:
Alternatively, execute this dynamic loop in the Vivado Tcl Console. It automatically scans all Verilog/SystemVerilog files in `sources_1`, retains the first instance of each module file, and removes all subsequent duplicates:

```tcl
# Automatically detect and remove duplicate filename definitions from sources_1
set seen_files [dict create]
foreach f [get_files -of_objects [get_filesets sources_1] -filter {FILE_TYPE == "Verilog" || FILE_TYPE == "SystemVerilog"}] {
    set bname [file tail $f]
    if {[dict exists $seen_files $bname]} {
        puts "Removing duplicate file from project: $f"
        remove_files $f
    } else {
        dict set seen_files $bname $f
    }
}
```

---

## 2. Managing Combinational Loops in Soft-eFPGA Fabrics

Unconfigured eFPGA switch matrices contain bidirectional routing multiplexers that form physical combinational feedback loops. Vivado's placer and DRC checkers will crash or fail unless specific routing properties, case analysis constraints, and placer DRC bypass hooks are applied.

* Follow the complete step-by-step constraint and hook setup guide in [**`VIVADO_FPGA_loops.md`**](VIVADO_FPGA_loops.md).

---

## 3. Vivado Build Speedup & Interactive Checkpoints

Synthesizing a complete heterogeneous SoC with soft-eFPGA fabric can take 15 to 60+ minutes per iteration. You can reduce iteration turnaround to seconds using checkpoint-based flows (`.dcp`) and optimized placer strategies.

* Follow the acceleration techniques in [**`VIVADO_Speedup.md`**](VIVADO_Speedup.md).

---

## 4. Enabling the FPGA Emulation Build Flag (`VIVADO=1`)

To cleanly separate ASIC production silicon paths from Digilent Nexys Video FPGA emulation hardware, the top-level RTL ([`CrocoScale_SoC.sv`](../RTL/SOC_TOP/CrocoScale_SoC.sv)) guards the 100 MHz to 10 MHz clock divider, Xilinx `BUFG` global buffer, and `ASYNC_REG` placement attributes behind a `` `ifdef VIVADO `` compiler directive.

When building the design in Vivado, define the `VIVADO` macro across the synthesis and simulation filesets:

### Via Vivado Tcl Console / Build Scripts:
```tcl
# Enable VIVADO emulation define for RTL synthesis
set_property verilog_define {VIVADO=1} [get_filesets sources_1]

# Enable VIVADO emulation define for testbench simulation (xsim)
set_property verilog_define {VIVADO=1} [get_filesets sim_1]
```

### Via Vivado GUI:
1. Open **Tools** -> **Settings** -> **General**.
2. Scroll down to **Verilog options** -> click **Defines**.
3. Add `VIVADO=1` and click **OK** / **Apply**.

### Hardware Effect:
* **Inside Vivado (`VIVADO=1`)**: Divides the 100 MHz board oscillator down to 10 MHz (`clk_div == 3'd4`), routes it through physical global buffer `BUFG clk_bufg`, and applies `ASYNC_REG = "TRUE"` to the 2-FF reset synchronizer.
* **Outside Vivado (ASIC / Icarus / Verilator)**: `VIVADO` is undefined. The clock divider and `BUFG` are bypassed, allowing `clk_i` to directly drive the internal system clock net `clk_10mhz`, keeping the ASIC tapeout path 100% vendor-primitive-free.

---

## 5. Portable Simulation Memory Files (`$readmemh`)

SystemVerilog testbenches loading reference vectors via `$readmemh` face execution path mismatches in Vivado because XSim executes inside `<project>.sim/sim_1/behav/xsim/`.

### Multi-Tier Dynamic Path Resolution:
Rather than copying `.mem` files into the Vivado project or hardcoding machine-specific paths into Git, testbenches probe paths dynamically:
1. Command-line plusarg: `+MEM_DIR=<path>`
2. Local working directory: `./` (standard when running directly inside `GoldenReference/`)
3. Relative path: `../GoldenReference/` (standard when running from `TestBenches/`)
4. Root path: `TEST/NPU/GoldenReference/` (standard when running from repo root)

### Dynamic Vivado Integration (Zero Git Leaks):
In Vivado, pass the path dynamically to XSim by querying the repository layout at runtime:
```tcl
# Automatically resolve GoldenReference for whichever testbench is currently set as sim top:
set top_name [get_property top [get_filesets sim_1]]
set tb_file [get_property NAME [get_files -quiet "*${top_name}.sv"]]
if {$tb_file eq ""} { set tb_file [lindex [get_files -quiet *tb_npu_*.sv] 0] }
if {$tb_file ne ""} {
    set golden_dir [file normalize "[file dirname $tb_file]/../GoldenReference"]
    set_property -dict [list xsim.simulate.xsim.more_options "-testplusarg MEM_DIR=$golden_dir"] [get_filesets sim_1]
}
```

* **Benefits**:
  - Python test vector updates and newly generated `.mem` files are picked up instantly on every simulation run.
  - Zero file duplication or stale `.mem` copies inside the simulation directory.
  - 100% portable across developer machines, CI runners, and simulators (Vivado, Icarus Verilog, Verilator).

---

## 6. Target Toolchain Configuration Matrix

| Target Platform | Compiler Defines | Source Files Used | Key Architectural Behavior |
| :--- | :--- | :--- | :--- |
| **FPGA Emulation (Vivado)** | `VIVADO=1` | Golden RTL (`RTL/`) or Mirrored Verilog | Enables 10 MHz clock divider, Xilinx `BUFG`, and `ASYNC_REG` reset attributes. |
| **Simulation / Lint (Icarus)** | `__ICARUS__` | `VERILOG_MIRROR_GENERATED/` | Automatically set by `generate_verilog_mirror.sh`. Uses Verilog-2001 mirror. Soft-fabric loops are bypassed via `EXCLUDE_FPGA`. |
| **ASIC Tapeout (IHP 130nm)** | `ASIC_MACROS` | Golden RTL (`RTL/`) | Instantiates IHP SG13G2 hard macros (`eFPGA_top_macro`, `npu_core_macro`, `sram_bank`). **DO NOT SET `VIVADO=1`!** External clock directly drives core clock tree without FPGA divider or buffer. |

> [!CAUTION]
> **CRITICAL ASIC RULE**: **NEVER define `VIVADO` during ASIC synthesis or tapeout.** Setting `VIVADO` inserts FPGA-specific `BUFG` primitives and an unconstrained clock divider into the silicon path, breaking ASIC clock distribution.
