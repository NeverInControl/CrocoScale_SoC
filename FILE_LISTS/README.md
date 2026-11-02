# CrocoScale SoC — Filelist Directory (`FILE_LISTS/`)

To keep the root directory clean, **only top-level runnable entry points** sit at the top of each flow folder. Modular building-block fragments (included via `-f` by parent lists) are tucked inside `internal/`.

---

## Which Filelist Do I Use?

| Task / Target | Simulation Flow (`FILE_LISTS/`) | Unified Multi-Target Flow (`FILE_LISTS/unified/`) | ASIC Synthesis Flow (`FILE_LISTS/asic/`) | Vivado Emulation (`FILE_LISTS/vivado/`) |
| :--- | :--- | :--- | :--- | :--- |
| **Full SoC** | `FILE_LISTS/soc.f` | `FILE_LISTS/unified/soc_unified.f` | `FILE_LISTS/asic/soc_asic.f` | `FILE_LISTS/vivado/soc_vivado.f` |
| **Standalone eFPGA + NPU Subsystem** | `FILE_LISTS/efpga_subsystem.f` | `FILE_LISTS/unified/efpga_subsystem_unified.f` | `FILE_LISTS/asic/efpga_subsystem_asic.f` | `FILE_LISTS/vivado/efpga_subsystem_vivado.f` |
| **Standalone NPU Complex** | `FILE_LISTS/npu.f` | `FILE_LISTS/unified/npu_unified.f` | `FILE_LISTS/asic/internal/npu_asic.f` | `FILE_LISTS/vivado/internal/npu_vivado.f` |
| **Tier-1 Activation Bank Macro** | *(included in `npu.f`)* | `FILE_LISTS/unified/act_bank_container_unified.f` | `FILE_LISTS/asic/act_bank_container_asic.f` | *(included in `npu_vivado.f`)* |
| **Tier-1 Psum + Requant Macro** | *(included in `npu.f`)* | `FILE_LISTS/unified/psum_requant_container_unified.f` | `FILE_LISTS/asic/psum_requant_container_asic.f` | *(included in `npu_vivado.f`)* |
| **Regression Testbenches** | `FILE_LISTS/tb/tb_*.f` | — | — | — |

> **Note on `RTL/AXI_LIB`**: Subsystem filelists (`efpga_subsystem.f`, `npu.f`) do not hardcode `RTL/AXI_LIB`. When compiling standalone subsystems in Icarus Verilog or Yosys, pass `-y RTL/AXI_LIB` (or `-y VERILOG_MIRROR_GENERATED/RTL/AXI_LIB`).

---

## Compiler Directives for `FILE_LISTS/unified/`

When using the Unified filelists (`FILE_LISTS/unified/*_unified.f`), select the target hardware architecture via `+define+` (or `-D` in Icarus Verilog / Yosys):

* **Default (no defines)**: Behavioral Simulation (`sram_bank`, `cg_cell`, simulatable FABulous fabric).
* **`+define+TARGET_VIVADO`**: Xilinx FPGA Emulation (`BUFGCE` clock gate, MMCM clock generator).
* **`+define+TARGET_ASIC`**: IHP 130nm CMOS5L ASIC (`sg13cmos5l_lgcp_1` clock gate, `RM_IHPSG13_1P_*` SRAM macros, `eFPGA_top` blackbox).
* **`+define+TARGET_ASIC +define+TARGET_ASIC_CONTAINERS`**: Tier-2 Hierarchical ASIC Subsystem (`act_bank_container` and `psum_requant_container` blackboxed as pre-hardened macros).

---

## Directory Layout

```text
FILE_LISTS/
├── README.md                  # This quick-reference guide
├── soc.f                      # Full SoC (Simulation)
├── efpga_subsystem.f          # Standalone eFPGA + NPU Subsystem (Simulation)
├── npu.f                      # Standalone NPU Complex (Simulation)
├── asic/                      # IHP 130nm CMOS5L ASIC entry points (+ internal/)
├── vivado/                    # Xilinx Vivado FPGA emulation entry points (+ internal/)
├── unified/                   # Auto-generated compiler-directive entry points (+ internal/)
├── tb/                        # Regression & benchmark testbench filelists
├── libs/                      # External AXI library filelist (axi_lib.f)
└── internal/                  # Modular sub-block fragments included via -f
```

