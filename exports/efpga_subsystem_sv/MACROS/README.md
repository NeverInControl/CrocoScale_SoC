# Subsystem Macros (`MACROS/`)

This directory contains ASIC hard macro wrappers, synthesis blackboxes, physical collaterals (`.gds`, `.lef`, `.lib`), and simulation models for the **IHP 130nm CMOS5L (`sg13cmos5l`)** physical implementation flow.

## 1-to-1 Filelist Drop-In Substitution Architecture

CrocoScale SoC uses a **100% Filelist-Driven Target Architecture** with **zero preprocessor directives (`` `ifdef ``)** in production RTL:

* **Zero RTL Clutter**: Production modules in `RTL/` contain pure, behavioral/synthesizable SystemVerilog with no target-specific `` `ifdef `` blocks.
* **Three Target Flows via Filelists**:
  - **Simulation (Default)**: `FILE_LISTS/npu.f`, `FILE_LISTS/efpga_subsystem.f`, `FILE_LISTS/soc.f` use pure behavioral primitives in `RTL/`.
  - **ASIC (`MACROS/`)**: `FILE_LISTS/asic/*.f` swap leaf primitives and/or hardened sub-macros with their 1-to-1 counterparts in `MACROS/`.
  - **Vivado Emulation (`VIVADO/`)**: `FILE_LISTS/vivado/*.f` swap clock/reset leaf primitives with Xilinx Artix-7 primitives in `VIVADO/`.

## Directory Structure

* **`Cells/`**:
  - `cg_cell.sv`: 1-to-1 drop-in ASIC clock-gate wrapper replacing `RTL/.../cg_cell.sv`. Instantiates the IHP 130nm CMOS5L integrated clock gating cell (`sg13cmos5l_lgcp_1`).
  - `sg13cmos5l_lgcp_1.v`: Behavioral model of the `sg13cmos5l_lgcp_1` standard cell for standalone lint/simulation.
* **`SRAM/`**:
  - `sram_bank.sv`: 1-to-1 drop-in ASIC SRAM wrapper replacing `RTL/.../sram_bank.sv`. Instantiates IHP 130nm single-port SRAM hard macros (`RM_IHPSG13_1P_512x8_c3_bm_bist` and `RM_IHPSG13_1P_256x32_c2_bm_bist`).
  - `sram_macros.v`: Behavioral simulation models for the IHP single-port SRAM macros.
  - Place foundry `.gds`, `.lef`, and `.lib` files for SRAM macros in this directory.
* **`act_buffer/`**:
  - `act_bank_container.v`: `(* blackbox *)` 1-to-1 drop-in stub for the hardened activation memory bank container macro (`act_bank_container`). Place hardened `act_bank_container.{gds,lef,lib}` files here.
* **`psum_requant/`**:
  - `psum_requant_container.v`: `(* blackbox *)` 1-to-1 drop-in stub for the hardened partial sum accumulator & requantizer container macro (`psum_requant_container`). Place hardened `psum_requant_container.{gds,lef,lib}` files here.
* **`FABulous/`**:
  - `eFPGA_top.v`: `(* blackbox *)` 1-to-1 drop-in stub for the hardened FABulous soft-fabric core (`eFPGA_top`). Place hardened `eFPGA_top.{gds,lef,lib}` files here.
