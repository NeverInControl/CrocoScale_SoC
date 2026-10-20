# Target Configuration & Primitives (IHP 130nm CMOS5L ASIC Hard Macros & Cells)
MACROS/target_config_pkg.sv
MACROS/Cells/sg13cmos5l_lgcp_1.v
MACROS/Cells/cg_cell.sv

# Hardened NPU Container Macros (Tier-1 Blackboxes)
MACROS/act_buffer/act_bank_container.v
MACROS/psum_requant/psum_requant_container.v

# NPU Core & Wrapper
-f ../npu_core.f

