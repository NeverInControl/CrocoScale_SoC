# CrocoScale SoC — Backport to Main Checklist

This document tracks all architectural improvements, modular refactorings, and bugfixes developed on the **`OWAS130`** branch that must be cleanly backported to the **`main`** branch.

---

## 1. Filelist Drop-In Substitution for ASIC Hard Macros

* **Architectural Rationale**:
  In-RTL preprocessor directives (`` `ifdef SRAM_MACROS ``, `` `ifdef ASIC_MACROS ``) introduce fragile compilation branches, break ANSI port list parsing in older tools/transpilers (`sv2v`), and create elaboration errors when parent modules have mismatched define flags.
* **Changes on `OWAS130`**:
  - **Pure Synthesizable RTL**: Removed `` `ifdef SRAM_MACROS `` from [`RTL/eFPGA_Subsystem/NPU_complex/shared/sram/sram_bank.sv`](file:///c:/Users/Niels/Documents/nct/MyProjects/CrocoScale_SoC/RTL/eFPGA_Subsystem/NPU_complex/shared/sram/sram_bank.sv). The module is now pure synthesizable behavioral RTL that cleanly infers BRAMs in Vivado and simulates deterministically in Icarus Verilog and Verilator.
  - **Drop-In Hard Macro Wrapper**: Created [`MACROS/SRAM/sram_bank.v`](file:///c:/Users/Niels/Documents/nct/MyProjects/CrocoScale_SoC/MACROS/SRAM/sram_bank.v) sharing the exact module name (`sram_bank`) and port interface, instantiating IHP 130nm CMOS5L foundry macros (`RM_IHPSG13_1P_*`).
  - **eFPGA Drop-In Model**: Renamed `module eFPGA_top_macro` to `module eFPGA_top` in [`MACROS/FABulous/eFPGA_top.v`](file:///c:/Users/Niels/Documents/nct/MyProjects/CrocoScale_SoC/MACROS/FABulous/eFPGA_top.v) to serve as a 1-to-1 drop-in replacement for [`FABulousProject/CrocoScale_Fabric/Fabric/eFPGA_top.v`](file:///c:/Users/Niels/Documents/nct/MyProjects/CrocoScale_SoC/FABulousProject/CrocoScale_Fabric/Fabric/eFPGA_top.v).
  - **Floorplan Container Macro Stubs**: Created drop-in blackbox models [`MACROS/act_buffer/act_bank_container.v`](file:///c:/Users/Niels/Documents/nct/MyProjects/CrocoScale_SoC/MACROS/act_buffer/act_bank_container.v) and [`MACROS/psum_requant/psum_requant_container.v`](file:///c:/Users/Niels/Documents/nct/MyProjects/CrocoScale_SoC/MACROS/psum_requant/psum_requant_container.v).
  - **Macro Filelist**: Updated [`FILE_LISTS/macros.f`](file:///c:/Users/Niels/Documents/nct/MyProjects/CrocoScale_SoC/FILE_LISTS/macros.f) and [`MACROS/README.md`](file:///c:/Users/Niels/Documents/nct/MyProjects/CrocoScale_SoC/MACROS/README.md) to document the filelist substitution workflow.
* **Backport Action**:
  - Replace `sram_bank.sv` on `main` with the clean behavioral version.
  - Copy updated `MACROS/` files and `FILE_LISTS/macros.f` to `main`.

---

## 2. NPU Complex 3-Subsystem Modular Restructuring

* **Architectural Rationale**:
  The previous monolithic `npu_top.sv` grouped the activation buffer, systolic array, crossbar, and requantizer into a single unhardened block. To support floorplanned macros aligned with the 8 eFPGA rows, the complex was split into 3 functional subsystems matching the physical slices.
* **Changes on `OWAS130`**:
  - **Slice 3 (`act_buffer/`)**:
    - [`act_bank_container.sv`](file:///c:/Users/Niels/Documents/nct/MyProjects/CrocoScale_SoC/RTL/eFPGA_Subsystem/NPU_complex/act_buffer/containers/act_bank_container.sv): Encapsulates row SRAM bank with West (fabric facing) and East (compute facing) pinouts and feedthrough channels (`weight_shift`, `xbar_sel`, `out_act`).
    - [`act_buffer_top.sv`](file:///c:/Users/Niels/Documents/nct/MyProjects/CrocoScale_SoC/RTL/eFPGA_Subsystem/NPU_complex/act_buffer/act_buffer_TOP/act_buffer_top.sv): Array of 8 container tiles with East/West boundary routing.
  - **Slice 4 (`compute_core/`)**:
    - [`compute_core_top.sv`](file:///c:/Users/Niels/Documents/nct/MyProjects/CrocoScale_SoC/RTL/eFPGA_Subsystem/NPU_complex/compute_core/compute_core_TOP/compute_core_top.sv): Houses the $8 \times 8$ systolic array ([`systolic_array.sv`](file:///c:/Users/Niels/Documents/nct/MyProjects/CrocoScale_SoC/RTL/eFPGA_Subsystem/NPU_complex/compute_core/systolic_array/systolic_array.sv), [`pe.sv`](file:///c:/Users/Niels/Documents/nct/MyProjects/CrocoScale_SoC/RTL/eFPGA_Subsystem/NPU_complex/compute_core/systolic_array/pe.sv)), activation crossbar ([`npu_crossbar.sv`](file:///c:/Users/Niels/Documents/nct/MyProjects/CrocoScale_SoC/RTL/eFPGA_Subsystem/NPU_complex/compute_core/crossbar/npu_crossbar.sv)), and requantizer configuration chain ([`quant_shift_chain.sv`](file:///c:/Users/Niels/Documents/nct/MyProjects/CrocoScale_SoC/RTL/eFPGA_Subsystem/NPU_complex/compute_core/quant_config/quant_shift_chain.sv)).
  - **Slice 5 (`psum_requant/`)**:
    - [`psum_requant_container.sv`](file:///c:/Users/Niels/Documents/nct/MyProjects/CrocoScale_SoC/RTL/eFPGA_Subsystem/NPU_complex/psum_requant/containers/psum_requant_container.sv): Combines dual ping-pong partial sum accumulators (Bank A and Bank B `sram_bank`s) with the [`npu_requantizer_lane.sv`](file:///c:/Users/Niels/Documents/nct/MyProjects/CrocoScale_SoC/RTL/eFPGA_Subsystem/NPU_complex/psum_requant/containers/requantizer/npu_requantizer_lane.sv).
    - [`psum_requant_top.sv`](file:///c:/Users/Niels/Documents/nct/MyProjects/CrocoScale_SoC/RTL/eFPGA_Subsystem/NPU_complex/psum_requant/psum_requant_TOP/psum_requant_top.sv): Array of 8 accumulator & requantizer container tiles.
  - **Shared Directory (`shared/`)**:
    - [`sram_bank.sv`](file:///c:/Users/Niels/Documents/nct/MyProjects/CrocoScale_SoC/RTL/eFPGA_Subsystem/NPU_complex/shared/sram/sram_bank.sv): Shared memory bank instantiated by both Slice 3 and Slice 5.
  - **Top Wrapper & Filelist**:
    - [`npu_wrapper.sv`](file:///c:/Users/Niels/Documents/nct/MyProjects/CrocoScale_SoC/RTL/eFPGA_Subsystem/NPU_complex/NPU_complex_TOP/npu_wrapper.sv): Top-level harness instantiating the 3 slices with feedthrough wiring.
    - [`FILE_LISTS/npu.f`](file:///c:/Users/Niels/Documents/nct/MyProjects/CrocoScale_SoC/FILE_LISTS/npu.f): Hierarchically ordered filelist of the 12 modular sources.
* **Backport Action**:
  - Remove deprecated `NPU_core/` files (`npu_top.sv`, `npu_requantizer.sv`, etc.).
  - Copy new modular directory structure (`act_buffer/`, `compute_core/`, `psum_requant/`, `shared/`, `NPU_complex_TOP/`) and `FILE_LISTS/npu.f` to `main`.

---

## 3. Fabric Clock Ladder Forwarding & Core Clocking

* **Architectural Rationale**:
  FABulous distributes `UserCLK` horizontally through West-to-East buffer ladders across 9 CLB columns. Tapping a global chip clock for the NPU creates massive clock skew across the FPGA-to-NPU boundary. Driving activation SRAMs from the matching row ladder and clocking the core from the middle container eliminates boundary skew while maintaining a single synchronous core domain.
* **Changes on `OWAS130`**:
  - **Row Clock Forwarding**: `act_buffer_top.sv` accepts `act_clk_i[7:0]`, driving Container $r$ directly from row $r$'s ladder clock.
  - **Middle Container Clock Output**: Container 3 forwards `clk_o[3]` as `npu_clk_core`, which drives `compute_core_top` and `psum_requant_top`.
  - **FPGA Emulation Protection**: In Vivado (`ifdef VIVADO`), `npu_clk_core = clk_i` taps the global `BUFG` directly to avoid Artix-7 fabric routing skew and `CKLD-1` DRC violations.
* **Backport Action**:
  - Ensure clock ladder connections in `act_buffer_top.sv` and `npu_wrapper.sv` are merged to `main`.

---

## 4. Parameter Typing & Inline Datapath Sizing Standards

* **Standard Contract**:
  - Parameters representing dimensions, widths, depths, and limits declared as `parameter int <NAME> = <VAL>;`.
  - In RTL logic expressions (comparisons, arithmetic, slice indexing), parameters cast inline to exact datapath widths: `<WIDTH>'(<PARAM>)`.
  - Zero un-sized integer literal comparisons against sized vectors.
* **Backport Action**:
  - Verify parameter declarations across all backported modules adhere to this sizing contract.

---

## 5. Verification & Mirror Collateral

* **Verification Status on `OWAS130`**:
  - `tb_npu_minimal_functional.sv`: 100% bit-exact pass (2048/2048 hits on both 1x1 and 3x3 halo convolutions).
  - `tb_npu_full_sys_functional.sv`: 100% bit-exact pass across all 10 sweeps (Raw PSUM peek, Linear Requant, Mish LUT, 2x2 MaxPool; 20,480 activations matched).
* **Verilog Mirror**:
  - Mirror updated via `scripts/generate_verilog_mirror.sh -e none -d RTL/eFPGA_Subsystem/NPU_complex`.
  - All 12 modular sources transpiled cleanly to pure IEEE 1364-2001 Verilog in `VERILOG_MIRROR_GENERATED/`.

