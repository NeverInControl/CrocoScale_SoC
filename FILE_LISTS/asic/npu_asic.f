# Target-Switched Primitives (IHP 130nm CMOS5L ASIC Hard Macros & Cells)
MACROS/Cells/sg13cmos5l_lgcp_1.v
MACROS/Cells/cg_cell.sv
RTL/eFPGA_Subsystem/NPU_complex/shared/clock_gate/npu_clk_ctrl.sv
MACROS/SRAM/sram_macros.v
MACROS/SRAM/sram_bank.sv

# NPU Containers & Core
RTL/eFPGA_Subsystem/NPU_complex/act_buffer/containers/act_bank_container.sv
RTL/eFPGA_Subsystem/NPU_complex/psum_requant/containers/requantizer/npu_requantizer_lane.sv
RTL/eFPGA_Subsystem/NPU_complex/psum_requant/containers/psum_requant_container.sv
-f ../npu_core.f

