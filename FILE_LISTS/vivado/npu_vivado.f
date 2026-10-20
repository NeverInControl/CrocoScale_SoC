# Target Configuration & Primitives (Xilinx Artix-7 Vivado Emulation)
VIVADO/target_config_pkg.sv
VIVADO/cg_cell.sv
RTL/eFPGA_Subsystem/NPU_complex/shared/sram/sram_bank.sv

# NPU Containers & Core
RTL/eFPGA_Subsystem/NPU_complex/act_buffer/containers/act_bank_container.sv
RTL/eFPGA_Subsystem/NPU_complex/psum_requant/containers/requantizer/npu_requantizer_lane.sv
RTL/eFPGA_Subsystem/NPU_complex/psum_requant/containers/psum_requant_container.sv
-f ../npu_core.f

