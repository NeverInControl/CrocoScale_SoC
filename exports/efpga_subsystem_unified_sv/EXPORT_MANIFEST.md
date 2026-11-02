# CrocoScale IP Package: `efpga_subsystem` (`unified`)

* **Source Repository**: [CrocoScale SoC](https://github.com/NeverInControl/CrocoScale_SoC)
* **Commit**: `6b2ab0f`
* **Target Flow**: `unified` (`FILE_LISTS/unified/efpga_subsystem_unified.f`)
* **Format**: `sv`
* **RTL Modules**: 176 files in `efpga_subsystem_global.f`

## Package Layout

* `efpga_subsystem_global.f`: Flat, standalone filelist (all paths relative to package root).
* `RTL/`: Synthesizable module sources (including `RTL/AXI_LIB/`).
* `UNIFIED/`: Compiler-directive switch wrappers dispatching across Simulation, Vivado, and ASIC flows.
* `TEST/`: Verification testbenches (5 files) and golden vectors (92 `.mem` files).
* `HAL/`: C hardware abstraction layer drivers (2 files).

## Simulation / Synthesis Quickstart

This unified package supports all target flows from a single filelist via standard compiler directives:

| Target Flow | Compiler Directives | Description |
| :--- | :--- | :--- |
| **Behavioral Simulation** | *(Default — no defines)* | Behavioral `sram_bank` & `cg_cell`, `USE_LADDER_CLOCKS=1`, full FABulous `eFPGA_top` |
| **Vivado Emulation** | `+define+TARGET_VIVADO` | Xilinx `BUFGCE` `cg_cell`, `USE_LADDER_CLOCKS=0`, BRAM-inferred `sram_bank`, full `eFPGA_top` |
| **ASIC (Flat / Tier-1)** | `+define+TARGET_ASIC` | IHP 130nm `sg13cmos5l_lgcp_1` `cg_cell`, `RM_IHPSG13_1P_*` SRAM macros, blackbox `eFPGA_top` |
| **ASIC (Tier-2 Subsystem)** | `+define+TARGET_ASIC +define+TARGET_ASIC_CONTAINERS` | Same as `TARGET_ASIC`, plus hardened Tier-1 blackboxes for `act_bank_container` & `psum_requant_container` |

```bash
# Behavioral Simulation (Default):
iverilog -g2012 -f efpga_subsystem_global.f -o sim.vvp

# Vivado FPGA Emulation Flow:
iverilog -g2012 -DTARGET_VIVADO -f efpga_subsystem_global.f -o sim_vivado.vvp

# ASIC Flow (Flat / Tier-1 Container Synthesis):
iverilog -g2012 -DTARGET_ASIC -f efpga_subsystem_global.f -o sim_asic_flat.vvp

# ASIC Flow (Tier-2 Hierarchical Subsystem Synthesis with Container Blackboxes):
iverilog -g2012 -DTARGET_ASIC -DTARGET_ASIC_CONTAINERS -f efpga_subsystem_global.f -o sim_asic_hier.vvp
```
