# CrocoScale SoC — `efpga_subsystem_top` Hard Macro Pinout Specification

```systemverilog
module efpga_subsystem_top #(
    parameter int NUM_SLOTS        = 1,
    parameter int AXI_ID_WIDTH     = 8,
    parameter logic [31:0] HW_VERSION = 32'hFAB00001,
    parameter int WEIGHT_SPLIT      = 8,
    parameter int USE_LADDER_CLOCKS = target_config_pkg::TARGET_USE_LADDER_CLOCKS
) (
    // #########################################################################
    // # NORTH (26 Pins — Chip I/O Padring Facing)
    // #   1. North of AXI Slice (2p): BitBang Config (efpga_cfg_*)
    // #   2. North Routing Channel above Fabric Cols 1..2 (24p): PMOD (pmod_io_*)
    // #########################################################################

    // =========================================================================
    // External BitBang Configuration Interface (2 Pins — North of AXI Slice)
    // =========================================================================
    input  logic                                efpga_cfg_sclk_i = 1'b0,
    input  logic                                efpga_cfg_sdata_i = 1'b0,

    // =========================================================================
    // External Padring PMOD Interface (24 Pins — Left North Routing Channel)
    // =========================================================================
    input  logic [7:0]                          pmod_io_i,
    output logic [7:0]                          pmod_io_o,
    output logic [7:0]                          pmod_io_oe_o,


    // #########################################################################
    // # WEST (490 Pins — Exclusively AXI Signals on AXI Slice West Edge)
    // # Placement: Ordered North-to-South along AXI Connector Slice West boundary (~9.18 um/pin):
    // #   1. m_axi_dma_* (222p)
    // #   2. s_axil_ctrl_* (152p)
    // #   3. s_axil_mgr_* AW + W + B + AR Channels (116p)
    // #########################################################################

    // =========================================================================
    // AXI4 Full Master: Slot DMA Interface (222 Pins)
    // =========================================================================
    output logic [NUM_SLOTS*AXI_ID_WIDTH-1:0]   m_axi_dma_awid,
    output logic [NUM_SLOTS*32-1:0]             m_axi_dma_awaddr,
    output logic [NUM_SLOTS*8-1:0]              m_axi_dma_awlen,
    output logic [NUM_SLOTS*3-1:0]              m_axi_dma_awsize,
    output logic [NUM_SLOTS*2-1:0]              m_axi_dma_awburst,
    output logic [NUM_SLOTS-1:0]                m_axi_dma_awlock,
    output logic [NUM_SLOTS*4-1:0]              m_axi_dma_awcache,
    output logic [NUM_SLOTS*3-1:0]              m_axi_dma_awprot,
    output logic [NUM_SLOTS-1:0]                m_axi_dma_awvalid,
    input  logic [NUM_SLOTS-1:0]                m_axi_dma_awready,
    output logic [NUM_SLOTS*32-1:0]             m_axi_dma_wdata,
    output logic [NUM_SLOTS*4-1:0]              m_axi_dma_wstrb,
    output logic [NUM_SLOTS-1:0]                m_axi_dma_wlast,
    output logic [NUM_SLOTS-1:0]                m_axi_dma_wvalid,
    input  logic [NUM_SLOTS-1:0]                m_axi_dma_wready,
    input  logic [NUM_SLOTS*AXI_ID_WIDTH-1:0]   m_axi_dma_bid,
    input  logic [NUM_SLOTS*2-1:0]              m_axi_dma_bresp,
    input  logic [NUM_SLOTS-1:0]                m_axi_dma_bvalid,
    output logic [NUM_SLOTS-1:0]                m_axi_dma_bready,
    output logic [NUM_SLOTS*AXI_ID_WIDTH-1:0]   m_axi_dma_arid,
    output logic [NUM_SLOTS*32-1:0]             m_axi_dma_araddr,
    output logic [NUM_SLOTS*8-1:0]              m_axi_dma_arlen,
    output logic [NUM_SLOTS*3-1:0]              m_axi_dma_arsize,
    output logic [NUM_SLOTS*2-1:0]              m_axi_dma_arburst,
    output logic [NUM_SLOTS-1:0]                m_axi_dma_arlock,
    output logic [NUM_SLOTS*4-1:0]              m_axi_dma_arcache,
    output logic [NUM_SLOTS*3-1:0]              m_axi_dma_arprot,
    output logic [NUM_SLOTS-1:0]                m_axi_dma_arvalid,
    input  logic [NUM_SLOTS-1:0]                m_axi_dma_arready,
    input  logic [NUM_SLOTS*AXI_ID_WIDTH-1:0]   m_axi_dma_rid,
    input  logic [NUM_SLOTS*32-1:0]             m_axi_dma_rdata,
    input  logic [NUM_SLOTS*2-1:0]              m_axi_dma_rresp,
    input  logic [NUM_SLOTS-1:0]                m_axi_dma_rlast,
    input  logic [NUM_SLOTS-1:0]                m_axi_dma_rvalid,
    output logic [NUM_SLOTS-1:0]                m_axi_dma_rready,

    // =========================================================================
    // AXI4-Lite Slave: Slot Control Interface (152 Pins)
    // =========================================================================
    input  logic [NUM_SLOTS*32-1:0]             s_axil_ctrl_awaddr,
    input  logic [NUM_SLOTS*3-1:0]              s_axil_ctrl_awprot,
    input  logic [NUM_SLOTS-1:0]                s_axil_ctrl_awvalid,
    output logic [NUM_SLOTS-1:0]                s_axil_ctrl_awready,
    input  logic [NUM_SLOTS*32-1:0]             s_axil_ctrl_wdata,
    input  logic [NUM_SLOTS*4-1:0]              s_axil_ctrl_wstrb,
    input  logic [NUM_SLOTS-1:0]                s_axil_ctrl_wvalid,
    output logic [NUM_SLOTS-1:0]                s_axil_ctrl_wready,
    output logic [NUM_SLOTS*2-1:0]              s_axil_ctrl_bresp,
    output logic [NUM_SLOTS-1:0]                s_axil_ctrl_bvalid,
    input  logic [NUM_SLOTS-1:0]                s_axil_ctrl_bready,
    input  logic [NUM_SLOTS*32-1:0]             s_axil_ctrl_araddr,
    input  logic [NUM_SLOTS*3-1:0]              s_axil_ctrl_arprot,
    input  logic [NUM_SLOTS-1:0]                s_axil_ctrl_arvalid,
    output logic [NUM_SLOTS-1:0]                s_axil_ctrl_arready,
    output logic [NUM_SLOTS*32-1:0]             s_axil_ctrl_rdata,
    output logic [NUM_SLOTS*2-1:0]              s_axil_ctrl_rresp,
    output logic [NUM_SLOTS-1:0]                s_axil_ctrl_rvalid,
    input  logic [NUM_SLOTS-1:0]                s_axil_ctrl_rready,

    // =========================================================================
    // AXI4-Lite Slave: Global Manager AW + W + B + AR Channels (116 Pins)
    // =========================================================================
    input  logic [31:0]                         s_axil_mgr_awaddr,
    input  logic [2:0]                          s_axil_mgr_awprot,
    input  logic                                s_axil_mgr_awvalid,
    output logic                                s_axil_mgr_awready,
    input  logic [31:0]                         s_axil_mgr_wdata,
    input  logic [3:0]                          s_axil_mgr_wstrb,
    input  logic                                s_axil_mgr_wvalid,
    output logic                                s_axil_mgr_wready,
    output logic [1:0]                          s_axil_mgr_bresp,
    output logic                                s_axil_mgr_bvalid,
    input  logic                                s_axil_mgr_bready,
    input  logic [31:0]                         s_axil_mgr_araddr,
    input  logic [2:0]                          s_axil_mgr_arprot,
    input  logic                                s_axil_mgr_arvalid,
    output logic                                s_axil_mgr_arready,


    // #########################################################################
    // # SOUTH (50 Pins — 36p South AXI Slice + 14p in Left South Routing Channel)
    // #   1. South of AXI Slice (36p):
    // #      s_axil_mgr Read Data (R) Channel (rdata[31:0], rresp[1:0], rvalid, rready)
    // #   2. Left Half of South Routing Channel (14p — All Clk, Resets & Interrupts)
    // #########################################################################

    // =========================================================================
    // AXI4-Lite Slave: Global Manager Read Data R Channel (36 Pins — South of AXI Slice)
    // =========================================================================
    output logic [31:0]                         s_axil_mgr_rdata,
    output logic [1:0]                          s_axil_mgr_rresp,
    output logic                                s_axil_mgr_rvalid,
    input  logic                                s_axil_mgr_rready,

    // =========================================================================
    // Interrupt Lines to CPU and SoC Subsystems (5 Pins — Left South Routing Channel)
    // =========================================================================
    output logic [3:0]                          efpga_usr_irq_o,
    output logic [NUM_SLOTS-1:0]                efpga_fault_irq_o,

    // =========================================================================
    // Global Clock & eFPGA Subsystem Reset Domain Inputs (9 Pins — Left South Routing Channel)
    // =========================================================================
    input  logic                                clk_i,
    input  logic                                rst_efpga_connector_n_i, // Active-Low Reset for eFPGA AXI Connector
    input  logic                                rst_efpga_connector_i,   // Active-High Reset for AXI Register Slices
    input  logic                                rst_efpga_fabric_n_i,    // Active-Low Configuration FSM Reset for eFPGA
    input  logic [NUM_SLOTS-1:0][3:0]           rst_efpga_slot_n_i,      // Active-Low Soft Resets for User Softlogic Slots
    input  logic [NUM_SLOTS-1:0]                rst_efpga_npu_n_i        // Active-Low Reset for Hardened NPU Complex
);
```