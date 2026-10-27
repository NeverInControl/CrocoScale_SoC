// =============================================================================
// File: TEST/SoftLogic/flex/eFPGA_top_flex_harness.sv
// Module: eFPGA_top
// Project: CrocoScale SoC — Filelist-Swappable eFPGA_top Wrapper for Flex Soft-Logic
//
// Description:
//   Drop-in simulation replacement for FABulous eFPGA_top that instantiates the
//   physical perimeter BEL boundary harness (efpga_boundary_harness) wired
//   directly to the 8-bank (4x2) dual-mode soft-logic controller
//   (npu_flex_sequencer).
//
//   Allows efpga_subsystem_top (including efpga_connector, efpga_manager,
//   watchdogs, decouplers, PMP, and npu_wrapper) to be simulated at full RTL
//   speed purely by swapping the fabric filelist entry from fabulous.f to
//   fabulous_bels.f + soft_logic_flex.f + eFPGA_top_flex_harness.sv.
// =============================================================================

`timescale 1ns / 1ps

module eFPGA_top #(
    parameter int include_eFPGA    = 1,
    parameter int NumberOfRows     = 18,
    parameter int NumberOfCols     = 11,
    parameter int FrameBitsPerRow  = 32,
    parameter int MaxFramesPerCol  = 20,
    parameter int desync_flag      = 20,
    parameter int FrameSelectWidth = 5,
    parameter int RowSelectWidth   = 5
) (
    // AXI4-Lite Slave (Slot 0 Control from efpga_connector)
    input  wire  [9:0]  AXIL_S_SOC_ARADDR,
    input  wire  [2:0]  AXIL_S_SOC_ARPROT,
    output wire  [0:0]  AXIL_S_SOC_ARREADY,
    input  wire  [0:0]  AXIL_S_SOC_ARVALID,
    input  wire  [9:0]  AXIL_S_SOC_AWADDR,
    input  wire  [2:0]  AXIL_S_SOC_AWPROT,
    output wire  [0:0]  AXIL_S_SOC_AWREADY,
    input  wire  [0:0]  AXIL_S_SOC_AWVALID,
    input  wire  [0:0]  AXIL_S_SOC_BREADY,
    output wire  [1:0]  AXIL_S_SOC_BRESP,
    output wire  [0:0]  AXIL_S_SOC_BVALID,
    output wire  [31:0] AXIL_S_SOC_RDATA,
    input  wire  [0:0]  AXIL_S_SOC_RREADY,
    output wire  [1:0]  AXIL_S_SOC_RRESP,
    output wire  [0:0]  AXIL_S_SOC_RVALID,
    input  wire  [31:0] AXIL_S_SOC_WDATA,
    output wire  [0:0]  AXIL_S_SOC_WREADY,
    input  wire  [3:0]  AXIL_S_SOC_WSTRB,
    input  wire  [0:0]  AXIL_S_SOC_WVALID,

    // AXI4 Full Master (Slot 0 DMA to efpga_connector)
    output wire  [31:0] AXI_M_SOC_ARADDR,
    output wire  [1:0]  AXI_M_SOC_ARBURST,
    output wire  [3:0]  AXI_M_SOC_ARCACHE,
    output wire  [7:0]  AXI_M_SOC_ARLEN,
    output wire  [0:0]  AXI_M_SOC_ARLOCK,
    input  wire  [0:0]  AXI_M_SOC_ARREADY,
    output wire  [2:0]  AXI_M_SOC_ARSIZE,
    output wire  [0:0]  AXI_M_SOC_ARVALID,
    output wire  [31:0] AXI_M_SOC_AWADDR,
    output wire  [1:0]  AXI_M_SOC_AWBURST,
    output wire  [3:0]  AXI_M_SOC_AWCACHE,
    output wire  [7:0]  AXI_M_SOC_AWLEN,
    output wire  [0:0]  AXI_M_SOC_AWLOCK,
    input  wire  [0:0]  AXI_M_SOC_AWREADY,
    output wire  [2:0]  AXI_M_SOC_AWSIZE,
    output wire  [0:0]  AXI_M_SOC_AWVALID,
    output wire  [0:0]  AXI_M_SOC_BREADY,
    input  wire  [1:0]  AXI_M_SOC_BRESP,
    input  wire  [0:0]  AXI_M_SOC_BVALID,
    input  wire  [31:0] AXI_M_SOC_RDATA,
    input  wire  [0:0]  AXI_M_SOC_RLAST,
    output wire  [0:0]  AXI_M_SOC_RREADY,
    input  wire  [1:0]  AXI_M_SOC_RRESP,
    input  wire  [0:0]  AXI_M_SOC_RVALID,
    output wire  [31:0] AXI_M_SOC_WDATA,
    output wire  [0:0]  AXI_M_SOC_WLAST,
    input  wire  [0:0]  AXI_M_SOC_WREADY,
    output wire  [3:0]  AXI_M_SOC_WSTRB,
    output wire  [0:0]  AXI_M_SOC_WVALID,

    // Debug & Slot Control
    output wire  [31:0] DEBUG_IN,
    input  wire  [31:0] DEBUG_OUT,
    output wire  [7:0]  FAB_USER_CLK,

    // Dedicated NPU Complex Interconnect
    output wire  [71:0] NPU_ACT_ADDR,
    input  wire  [63:0] NPU_ACT_RDATA,
    output wire  [63:0] NPU_ACT_WDATA,
    output wire  [7:0]  NPU_ACT_WE,
    output wire  [15:0] NPU_ADDR,
    output wire  [0:0]  NPU_ARRAY_EN,
    output wire  [0:0]  NPU_COMPUTE_BANK_SWAP,
    input  wire  [63:0] NPU_OUT_ACT,
    output wire  [0:0]  NPU_PSUM_LUT_EN,
    output wire  [0:0]  NPU_PSUM_SKEW_EN,
    output wire  [0:0]  NPU_PSUM_SYSTOLIC_EN,
    output wire  [0:0]  NPU_QUANT_SHIFT_EN,
    output wire  [29:0] NPU_QUANT_SHIFT_IN,
    input  wire  [63:0] NPU_RDATA,
    output wire  [5:0]  NPU_READ_BANK_SEL,
    output wire  [0:0]  NPU_SWAP_WEIGHTS,
    output wire  [63:0] NPU_WDATA,
    output wire  [15:0] NPU_WE,
    output wire  [63:0] NPU_WEIGHT_IN,
    output wire  [7:0]  NPU_WEIGHT_SHIFT_EN,
    output wire  [31:0] NPU_XBAR_SEL,

    // External PMOD Padring & Slot Signals
    input  wire  [7:0]  PMOD_IO_I,
    output wire  [7:0]  PMOD_IO_O,
    output wire  [7:0]  PMOD_IO_OE_O,
    input  wire  [3:0]  SLOT_SOFT_RST_N,
    output wire  [3:0]  USR_IRQ,

    // Configuration Ports (Unused in Pre-Configured Harness Mode)
    input  wire         CLK,
    input  wire         resetn,
    input  wire         SelfWriteStrobe,
    input  wire  [31:0] SelfWriteData,
    input  wire         Rx,
    output wire         ComActive,
    output wire         ReceiveLED,
    input  wire         s_clk,
    input  wire         s_data
);

    localparam int ARRAY_HEIGHT     = 8;
    localparam int ARRAY_WIDTH      = 8;
    localparam int TILE_SIZE        = 16;
    localparam int ACT_HALO_PAD     = 2;
    localparam int ACTIVATION_WIDTH = 8;
    localparam int WEIGHT_WIDTH     = 8;
    localparam int PSUM_WIDTH       = 32;

    assign ComActive    = 1'b0;
    assign ReceiveLED   = 1'b0;
    assign PMOD_IO_O    = 8'h00;
    assign PMOD_IO_OE_O = 8'h00;

    // Internal Fabric-Facing Wires (Boundary BELs <-> Soft-Logic Sequencer)
    wire [9:0]  fab_axil_awaddr;
    wire [2:0]  fab_axil_awprot;
    wire        fab_axil_awvalid;
    wire        fab_axil_awready;
    wire [31:0] fab_axil_wdata;
    wire [3:0]  fab_axil_wstrb;
    wire        fab_axil_wvalid;
    wire        fab_axil_wready;
    wire [1:0]  fab_axil_bresp;
    wire        fab_axil_bvalid;
    wire        fab_axil_bready;
    wire [9:0]  fab_axil_araddr;
    wire [2:0]  fab_axil_arprot;
    wire        fab_axil_arvalid;
    wire        fab_axil_arready;
    wire [31:0] fab_axil_rdata;
    wire [1:0]  fab_axil_rresp;
    wire        fab_axil_rvalid;
    wire        fab_axil_rready;

    wire [31:0] fab_axi_awaddr;
    wire [7:0]  fab_axi_awlen;
    wire        fab_axi_awvalid;
    wire        fab_axi_awready;
    wire [31:0] fab_axi_wdata;
    wire [3:0]  fab_axi_wstrb;
    wire        fab_axi_wlast;
    wire        fab_axi_wvalid;
    wire        fab_axi_wready;
    wire [1:0]  fab_axi_bresp;
    wire        fab_axi_bvalid;
    wire        fab_axi_bready;
    wire [31:0] fab_axi_araddr;
    wire [7:0]  fab_axi_arlen;
    wire        fab_axi_arvalid;
    wire        fab_axi_arready;
    wire [31:0] fab_axi_rdata;
    wire [1:0]  fab_axi_rresp;
    wire        fab_axi_rlast;
    wire        fab_axi_rvalid;
    wire        fab_axi_rready;

    wire                                             fab_npu_array_en;
    wire                                             fab_npu_psum_systolic_en;
    wire                                             fab_npu_psum_skew_en;
    wire                                             fab_npu_psum_lut_en;
    wire                                             fab_npu_compute_bank_swap;
    wire        [ARRAY_HEIGHT-1:0][3:0]              fab_crossbar_sel;
    wire signed [ARRAY_HEIGHT-1:0][WEIGHT_WIDTH-1:0] fab_weight_shift_in;
    wire        [ARRAY_HEIGHT-1:0]                   fab_weight_shift_en;
    wire                                             fab_npu_swap_weights;
    wire        [29:0]                               fab_npu_quant_shift_in;
    wire                                             fab_npu_quant_shift_en;
    wire        [7:0]                                fab_psum_A_addr;
    wire        [ARRAY_WIDTH-1:0]                    fab_psum_A_we;
    wire signed [PSUM_WIDTH-1:0]                     fab_psum_A_wdata;
    wire signed [PSUM_WIDTH-1:0]                     fab_psum_A_rdata;
    wire        [7:0]                                fab_psum_B_addr;
    wire        [ARRAY_WIDTH-1:0]                    fab_psum_B_we;
    wire signed [PSUM_WIDTH-1:0]                     fab_psum_B_wdata;
    wire signed [PSUM_WIDTH-1:0]                     fab_psum_B_rdata;
    wire        [ARRAY_HEIGHT-1:0]                   fab_ext_act_sram_we;
    wire        [ARRAY_HEIGHT-1:0][8:0]              fab_ext_act_sram_addr;
    wire        [ARRAY_HEIGHT-1:0][ACTIVATION_WIDTH-1:0] fab_ext_act_sram_wdata;
    wire        [ARRAY_HEIGHT-1:0][ACTIVATION_WIDTH-1:0] fab_act_sram_rdata;
    wire        [ARRAY_WIDTH-1:0][ACTIVATION_WIDTH-1:0]  fab_out_act;
    wire        [3:0]                                fab_usr_irq;
    wire        [3:0]                                fab_slot_soft_rst_n;

    // 1. Physical Perimeter BEL Boundary Harness
    efpga_boundary_harness #(
        .ARRAY_HEIGHT    (ARRAY_HEIGHT),
        .ARRAY_WIDTH     (ARRAY_WIDTH),
        .ACTIVATION_WIDTH(ACTIVATION_WIDTH),
        .WEIGHT_WIDTH    (WEIGHT_WIDTH),
        .PSUM_WIDTH      (PSUM_WIDTH),
        .CFG_AXI_M       (12'hF3E),
        .CFG_NPU_CTRL    (1'b0),
        .CFG_DEBUG       (16'h0004)
    ) u_boundary_harness (
        .clk_i                   (CLK),

        // External / Connector Facing Ports
        .s_axil_awaddr           (AXIL_S_SOC_AWADDR),
        .s_axil_awprot           (AXIL_S_SOC_AWPROT),
        .s_axil_awvalid          (AXIL_S_SOC_AWVALID),
        .s_axil_awready          (AXIL_S_SOC_AWREADY),
        .s_axil_wdata            (AXIL_S_SOC_WDATA),
        .s_axil_wstrb            (AXIL_S_SOC_WSTRB),
        .s_axil_wvalid           (AXIL_S_SOC_WVALID),
        .s_axil_wready           (AXIL_S_SOC_WREADY),
        .s_axil_bresp            (AXIL_S_SOC_BRESP),
        .s_axil_bvalid           (AXIL_S_SOC_BVALID),
        .s_axil_bready           (AXIL_S_SOC_BREADY),
        .s_axil_araddr           (AXIL_S_SOC_ARADDR),
        .s_axil_arprot           (AXIL_S_SOC_ARPROT),
        .s_axil_arvalid          (AXIL_S_SOC_ARVALID),
        .s_axil_arready          (AXIL_S_SOC_ARREADY),
        .s_axil_rdata            (AXIL_S_SOC_RDATA),
        .s_axil_rresp            (AXIL_S_SOC_RRESP),
        .s_axil_rvalid           (AXIL_S_SOC_RVALID),
        .s_axil_rready           (AXIL_S_SOC_RREADY),

        .m_axi_awaddr            (AXI_M_SOC_AWADDR),
        .m_axi_awlen             (AXI_M_SOC_AWLEN),
        .m_axi_awsize            (AXI_M_SOC_AWSIZE),
        .m_axi_awburst           (AXI_M_SOC_AWBURST),
        .m_axi_awlock            (AXI_M_SOC_AWLOCK),
        .m_axi_awcache           (AXI_M_SOC_AWCACHE),
        .m_axi_awvalid           (AXI_M_SOC_AWVALID),
        .m_axi_awready           (AXI_M_SOC_AWREADY),
        .m_axi_wdata             (AXI_M_SOC_WDATA),
        .m_axi_wstrb             (AXI_M_SOC_WSTRB),
        .m_axi_wlast             (AXI_M_SOC_WLAST),
        .m_axi_wvalid            (AXI_M_SOC_WVALID),
        .m_axi_wready            (AXI_M_SOC_WREADY),
        .m_axi_bresp             (AXI_M_SOC_BRESP),
        .m_axi_bvalid            (AXI_M_SOC_BVALID),
        .m_axi_bready            (AXI_M_SOC_BREADY),
        .m_axi_araddr            (AXI_M_SOC_ARADDR),
        .m_axi_arlen             (AXI_M_SOC_ARLEN),
        .m_axi_arsize            (AXI_M_SOC_ARSIZE),
        .m_axi_arburst           (AXI_M_SOC_ARBURST),
        .m_axi_arlock            (AXI_M_SOC_ARLOCK),
        .m_axi_arcache           (AXI_M_SOC_ARCACHE),
        .m_axi_arvalid           (AXI_M_SOC_ARVALID),
        .m_axi_arready           (AXI_M_SOC_ARREADY),
        .m_axi_rdata             (AXI_M_SOC_RDATA),
        .m_axi_rresp             (AXI_M_SOC_RRESP),
        .m_axi_rlast             (AXI_M_SOC_RLAST),
        .m_axi_rvalid            (AXI_M_SOC_RVALID),
        .m_axi_rready            (AXI_M_SOC_RREADY),

        .soc_debug_out_i         (DEBUG_OUT),
        .soc_debug_in_o          (DEBUG_IN),
        .soc_usr_irq_o           (USR_IRQ),
        .soc_slot_soft_rst_n_i   (SLOT_SOFT_RST_N),

        // NPU Facing Ports
        .npu_act_clk             (FAB_USER_CLK),
        .npu_array_en            (NPU_ARRAY_EN),
        .npu_psum_systolic_en    (NPU_PSUM_SYSTOLIC_EN),
        .npu_psum_lut_en         (NPU_PSUM_LUT_EN),
        .npu_psum_skew_en        (NPU_PSUM_SKEW_EN),
        .npu_compute_bank_swap   (NPU_COMPUTE_BANK_SWAP),
        .npu_swap_weights        (NPU_SWAP_WEIGHTS),
        .npu_quant_shift_in      (NPU_QUANT_SHIFT_IN),
        .npu_quant_shift_en      (NPU_QUANT_SHIFT_EN),
        .npu_crossbar_sel        (NPU_XBAR_SEL),
        .npu_weight_shift_in     (NPU_WEIGHT_IN),
        .npu_weight_shift_en     (NPU_WEIGHT_SHIFT_EN),
        .npu_ext_act_sram_we     (NPU_ACT_WE),
        .npu_ext_act_sram_addr   (NPU_ACT_ADDR),
        .npu_ext_act_sram_wdata  (NPU_ACT_WDATA),
        .npu_act_sram_rdata      (NPU_ACT_RDATA),
        .npu_out_act             (NPU_OUT_ACT),
        .npu_psum_A_addr         (NPU_ADDR[7:0]),
        .npu_psum_A_we           (NPU_WE[7:0]),
        .npu_psum_A_wdata        (NPU_WDATA[31:0]),
        .npu_psum_A_read_bank_sel(NPU_READ_BANK_SEL[2:0]),
        .npu_psum_A_rdata        (NPU_RDATA[31:0]),
        .npu_psum_B_addr         (NPU_ADDR[15:8]),
        .npu_psum_B_we           (NPU_WE[15:8]),
        .npu_psum_B_wdata        (NPU_WDATA[63:32]),
        .npu_psum_B_read_bank_sel(NPU_READ_BANK_SEL[5:3]),
        .npu_psum_B_rdata        (NPU_RDATA[63:32]),

        // Fabric Facing Ports
        .fab_axil_awaddr         (fab_axil_awaddr),
        .fab_axil_awprot         (fab_axil_awprot),
        .fab_axil_awvalid        (fab_axil_awvalid),
        .fab_axil_awready        (fab_axil_awready),
        .fab_axil_wdata          (fab_axil_wdata),
        .fab_axil_wstrb          (fab_axil_wstrb),
        .fab_axil_wvalid         (fab_axil_wvalid),
        .fab_axil_wready         (fab_axil_wready),
        .fab_axil_bresp          (fab_axil_bresp),
        .fab_axil_bvalid         (fab_axil_bvalid),
        .fab_axil_bready         (fab_axil_bready),
        .fab_axil_araddr         (fab_axil_araddr),
        .fab_axil_arprot         (fab_axil_arprot),
        .fab_axil_arvalid        (fab_axil_arvalid),
        .fab_axil_arready        (fab_axil_arready),
        .fab_axil_rdata          (fab_axil_rdata),
        .fab_axil_rresp          (fab_axil_rresp),
        .fab_axil_rvalid         (fab_axil_rvalid),
        .fab_axil_rready         (fab_axil_rready),

        .fab_axi_awaddr          (fab_axi_awaddr),
        .fab_axi_awlen           (fab_axi_awlen),
        .fab_axi_awsize          (3'd2),
        .fab_axi_awburst         (2'b01),
        .fab_axi_awlock          (1'b0),
        .fab_axi_awcache         (4'd0),
        .fab_axi_awvalid         (fab_axi_awvalid),
        .fab_axi_awready         (fab_axi_awready),
        .fab_axi_wdata           (fab_axi_wdata),
        .fab_axi_wstrb           (fab_axi_wstrb),
        .fab_axi_wlast           (fab_axi_wlast),
        .fab_axi_wvalid          (fab_axi_wvalid),
        .fab_axi_wready          (fab_axi_wready),
        .fab_axi_bresp           (fab_axi_bresp),
        .fab_axi_bvalid          (fab_axi_bvalid),
        .fab_axi_bready          (fab_axi_bready),
        .fab_axi_araddr          (fab_axi_araddr),
        .fab_axi_arlen           (fab_axi_arlen),
        .fab_axi_arsize          (3'd2),
        .fab_axi_arburst         (2'b01),
        .fab_axi_arlock          (1'b0),
        .fab_axi_arcache         (4'd0),
        .fab_axi_arvalid         (fab_axi_arvalid),
        .fab_axi_arready         (fab_axi_arready),
        .fab_axi_rdata           (fab_axi_rdata),
        .fab_axi_rresp           (fab_axi_rresp),
        .fab_axi_rlast           (fab_axi_rlast),
        .fab_axi_rvalid          (fab_axi_rvalid),
        .fab_axi_rready          (fab_axi_rready),

        .fab_npu_array_en        (fab_npu_array_en),
        .fab_npu_psum_systolic_en(fab_npu_psum_systolic_en),
        .fab_npu_psum_lut_en     (fab_npu_psum_lut_en),
        .fab_npu_psum_skew_en    (fab_npu_psum_skew_en),
        .fab_npu_compute_bank_swap(fab_npu_compute_bank_swap),
        .fab_npu_swap_weights    (fab_npu_swap_weights),
        .fab_npu_quant_shift_in  (fab_npu_quant_shift_in),
        .fab_npu_quant_shift_en  (fab_npu_quant_shift_en),
        .fab_crossbar_sel        (fab_crossbar_sel),
        .fab_weight_shift_in     (fab_weight_shift_in),
        .fab_weight_shift_en     (fab_weight_shift_en),
        .fab_ext_act_sram_we     (fab_ext_act_sram_we),
        .fab_ext_act_sram_addr   (fab_ext_act_sram_addr),
        .fab_ext_act_sram_wdata  (fab_ext_act_sram_wdata),
        .fab_act_sram_rdata      (fab_act_sram_rdata),
        .fab_out_act             (fab_out_act),
        .fab_psum_A_addr         (fab_psum_A_addr),
        .fab_psum_A_we           (fab_psum_A_we),
        .fab_psum_A_wdata        (fab_psum_A_wdata),
        .fab_psum_A_read_bank_sel(3'd0),
        .fab_psum_A_rdata        (fab_psum_A_rdata),
        .fab_psum_B_addr         (fab_psum_B_addr),
        .fab_psum_B_we           (fab_psum_B_we),
        .fab_psum_B_wdata        (fab_psum_B_wdata),
        .fab_psum_B_read_bank_sel(3'd0),
        .fab_psum_B_rdata        (fab_psum_B_rdata),

        .fab_debug_out_o         (),
        .fab_debug_in_i          (32'd0),
        .fab_usr_irq_i           (fab_usr_irq),
        .fab_slot_soft_rst_n_o   (fab_slot_soft_rst_n)
    );

    // 2. Flex Soft-Logic Sequencer
    npu_flex_sequencer #(
        .ARRAY_HEIGHT(ARRAY_HEIGHT),
        .ARRAY_WIDTH (ARRAY_WIDTH),
        .TILE_SIZE   (TILE_SIZE),
        .ACT_HALO_PAD(ACT_HALO_PAD),
        .FIFO_DEPTH  (4)
    ) u_flex_sequencer (
        .clk_i                (CLK),
        .rst_n                (fab_slot_soft_rst_n[0]),
        .s_axil_awaddr        (fab_axil_awaddr),
        .s_axil_awprot        (fab_axil_awprot),
        .s_axil_awvalid       (fab_axil_awvalid),
        .s_axil_awready       (fab_axil_awready),
        .s_axil_wdata         (fab_axil_wdata),
        .s_axil_wstrb         (fab_axil_wstrb),
        .s_axil_wvalid        (fab_axil_wvalid),
        .s_axil_wready        (fab_axil_wready),
        .s_axil_bresp         (fab_axil_bresp),
        .s_axil_bvalid        (fab_axil_bvalid),
        .s_axil_bready        (fab_axil_bready),
        .s_axil_araddr        (fab_axil_araddr),
        .s_axil_arprot        (fab_axil_arprot),
        .s_axil_arvalid       (fab_axil_arvalid),
        .s_axil_arready       (fab_axil_arready),
        .s_axil_rdata         (fab_axil_rdata),
        .s_axil_rresp         (fab_axil_rresp),
        .s_axil_rvalid        (fab_axil_rvalid),
        .s_axil_rready        (fab_axil_rready),
        .m_axi_awaddr         (fab_axi_awaddr),
        .m_axi_awlen          (fab_axi_awlen),
        .m_axi_awvalid        (fab_axi_awvalid),
        .m_axi_awready        (fab_axi_awready),
        .m_axi_wdata          (fab_axi_wdata),
        .m_axi_wstrb          (fab_axi_wstrb),
        .m_axi_wlast          (fab_axi_wlast),
        .m_axi_wvalid         (fab_axi_wvalid),
        .m_axi_wready         (fab_axi_wready),
        .m_axi_bresp          (fab_axi_bresp),
        .m_axi_bvalid         (fab_axi_bvalid),
        .m_axi_bready         (fab_axi_bready),
        .m_axi_araddr         (fab_axi_araddr),
        .m_axi_arlen          (fab_axi_arlen),
        .m_axi_arvalid        (fab_axi_arvalid),
        .m_axi_arready        (fab_axi_arready),
        .m_axi_rdata          (fab_axi_rdata),
        .m_axi_rresp          (fab_axi_rresp),
        .m_axi_rlast          (fab_axi_rlast),
        .m_axi_rvalid         (fab_axi_rvalid),
        .m_axi_rready         (fab_axi_rready),
        .usr_irq_o            (fab_usr_irq),
        .busy_o               (),
        .done_o               (),
        .current_pass_o       (),
        .cycle_in_pass_o      (),
        .array_en_o           (fab_npu_array_en),
        .psum_systolic_en_o   (fab_npu_psum_systolic_en),
        .psum_skew_en_o       (fab_npu_psum_skew_en),
        .psum_lut_en_o        (fab_npu_psum_lut_en),
        .compute_bank_swap_o  (fab_npu_compute_bank_swap),
        .crossbar_sel_o       (fab_crossbar_sel),
        .act_sram_addr_o      (fab_ext_act_sram_addr),
        .act_sram_we_o        (fab_ext_act_sram_we),
        .act_sram_wdata_o     (fab_ext_act_sram_wdata),
        .act_sram_rdata_i     (fab_act_sram_rdata),
        .out_act_i            (fab_out_act),
        .weight_shift_in_o    (fab_weight_shift_in),
        .weight_shift_en_o    (fab_weight_shift_en),
        .swap_weights_o       (fab_npu_swap_weights),
        .quant_shift_in_o     (fab_npu_quant_shift_in),
        .quant_shift_en_o     (fab_npu_quant_shift_en),
        .psum_A_addr_o        (fab_psum_A_addr),
        .psum_A_we_o          (fab_psum_A_we),
        .psum_A_wdata_o       (fab_psum_A_wdata),
        .psum_B_addr_o        (fab_psum_B_addr),
        .psum_B_we_o          (fab_psum_B_we),
        .psum_B_wdata_o       (fab_psum_B_wdata),
        .preload_phase_o      (),
        .dma_channel_to_load_o(),
        .dma_bank_ptr_o       (),
        .lut_phase_o          (),
        .drain_phase_o        (),
        .drain_step_o         ()
    );

endmodule

