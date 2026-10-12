# Subsystem Macros

This directory contains ASIC hard macro models, simulation blackboxes, and behavioral collaterals for the eFPGA Subsystem, NPU Complex, and associated SoC components.

## Macro Architecture & Drop-In Filelist Substitution

CrocoScale SoC utilizes a **1-to-1 Filelist Drop-In Substitution Strategy** rather than in-RTL preprocessor directives (`ifdef MACROS`). Every macro model in this directory matches its production synthesizable RTL counterpart in module name, parameters, and pinout:

* **Zero RTL Clutter**: Production RTL modules contain no conditional macro compilation guards, guaranteeing deterministic elaboration across all linting, transpilation, and simulation tools.
* **Drop-In Binding**: During ASIC physical synthesis, hierarchical macro integration, or fast blackbox simulation, subsystem filelists substitute the RTL source paths with the corresponding macro collateral from this directory (`FILE_LISTS/macros.f`).

## Directory Structure

* **`FABulous/`**:
  - `eFPGA_top.v`: 1-to-1 drop-in blackbox model for the FABulous soft-fabric core (`FABulousProject/CrocoScale_Fabric/Fabric/eFPGA_top.v`). Exposes identical AXI, AXIL, NPU, RAM_IO, and configuration interfaces.
* **`SRAM/`**:
  - `sram_bank.v`: Drop-in hard macro wrapper replacing synthesizable `sram_bank.sv`. Instantiates IHP 130nm CMOS5L foundry macros (`RM_IHPSG13_1P_*`).
  - `sram_macros.v`: Behavioral simulation models for IHP single-port SRAM macros (`RM_IHPSG13_1P_512x8_c3_bm_bist` and `RM_IHPSG13_1P_256x32_c2_bm_bist`).
* **`act_buffer/`**:
  - `act_bank_container.v`: Drop-in blackbox model for the activation memory bank container macro (`act_bank_container.sv`).
* **`psum_requant/`**:
  - `psum_requant_container.v`: Drop-in blackbox model for the partial sum accumulator & requantizer container macro (`psum_requant_container.sv`).
