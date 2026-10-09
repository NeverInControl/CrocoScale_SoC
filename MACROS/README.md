# Subsystem Macros

This directory contains ASIC hard macro models, simulation blackboxes, and behavioral collaterals for the eFPGA Subsystem and associated SoC components.

## Directory Structure

* **`FABulous/`**: Hard macro interface wrapper and simulation models for the reconfigurable eFPGA fabric core.
* **`NPU_core/`**: Hard macro model for the systolic array compute core, including the systolic matrix engine, accumulation registers, and requantizer pipeline.
* **`SRAM/`**: ASIC SRAM macro models and memory wrappers replacing generic behavioral arrays.

## Preprocessor Directives
 
* **`SRAM_MACROS`**:
  Defines instantiation of IHP 130nm CMOS5L foundry SRAM hard macros (`RM_IHPSG13_1P_*`) inside `sram_bank.sv` (used inside floorplan container macros). When undefined (default), behavioral memory arrays are inferred (targeting FPGA BRAMs in Vivado).
 
* **`ASIC_MACROS`**:
  Controls instantiation of top-level hardened physical macro blocks (such as the eFPGA fabric core `eFPGA_top` and floorplan container macros) across subsystem wrappers. When undefined, synthesizable/behavioral RTL descriptions are elaborated.

