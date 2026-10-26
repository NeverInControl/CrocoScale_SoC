// =============================================================================
// File: TEST/SoftLogic/flex/system/tb_npu_flex_crossbar_stress.sv
// Module: tb_npu_flex_crossbar_stress
// Project: CrocoScale SoC — 5-Layer Chained Weird-Dimension CNN + Shared-Bus Stress Suite
//
// Description:
//   End-to-end 5-layer heterogeneous CNN inference stress testbench for the
//   8-bank (4x2) dual-mode (3x3 & 1x1) soft-logic controller (npu_flex_sequencer).
//
//   Only Layer 1's input activations (52x76x5) are uploaded by the CPU; all 5
//   consecutive layers execute directly from System RAM by ping-ponging between
//   ACT_BUF_A_BASE and ACT_BUF_B_BASE using power-of-two strip strides:
//     - L1 (3x3 Conv, Mode A Linear):
//         52x76x5  -> 52x76x16 (4x5=20 tiles, 2 Cout groups of 8, 6 passes/tile)
//     - L2 (1x1 Conv, Mode B Mish LUT):
//         52x76x11 -> 52x76x8  (4x5=20 tiles, 3 passes/tile [odd], slices 11 of 16 ch)
//     - L3 (3x3 Conv, Mode D Mish LUT + 2x2 MaxPool):
//         52x76x6  -> 26x38x16 (4x5=20 tiles, 2 Cout groups of 8, 7 passes/tile [odd], slices 6 of 8 ch)
//     - L4 (1x1 Conv, Mode C Linear + 2x2 MaxPool):
//         26x38x13 -> 13x19x8  (2x3=6 tiles, 4 passes/tile, slices 13 of 16 ch)
//     - L5 (3x3 Conv, Mode B Mish LUT):
//         13x19x7  -> 13x19x8  (1x2=2 tiles, 8 passes/tile, slices 7 of 8 ch, odd 13x19 input)
//
//   Randomized Shared-Bus Contention:
//   - While the NPU DMA engine bursts on S1 <-> M0 across all 5 layers, the
//     emulated CPU (S0) issues randomized read and write bursts (random burst
//     lengths 1..16, random scratchpad offsets, random inter-burst gaps, and
//     random intra-burst WVALID/RREADY/BREADY wait-state jitter) over the shared
//     axi_interconnect to verify full stall/latency resilience.
// =============================================================================

`timescale 1ns / 1ps

module tb_npu_flex_crossbar_stress;

    parameter int ARRAY_HEIGHT     = 8;
    parameter int ARRAY_WIDTH      = 8;
    parameter int TILE_SIZE        = 16;
    parameter int ACT_HALO_PAD     = 2;
    parameter int ACTIVATION_WIDTH = 8;
    parameter int WEIGHT_WIDTH     = 8;
    parameter int PSUM_WIDTH       = 32;
    parameter int SCALE_WIDTH      = 16;
    parameter int WEIGHT_SPLIT     = 8;
    parameter int TOTAL_PASSES     = 6;
    parameter int CIN              = 5;
    parameter int COUT             = 8;

    // 5-Layer Chained Network Dimensions
    localparam int L1_H = 52, L1_W = 76, L1_CIN = 5,  L1_COUT = 16, L1_PASSES = 6;
    localparam int L2_H = 52, L2_W = 76, L2_CIN = 11, L2_COUT = 8,  L2_PASSES = 3;
    localparam int L3_H = 52, L3_W = 76, L3_CIN = 6,  L3_COUT = 16, L3_PASSES = 7;
    localparam int L3_OUT_H = 26, L3_OUT_W = 38;
    localparam int L4_H = 26, L4_W = 38, L4_CIN = 13, L4_COUT = 8,  L4_PASSES = 4;
    localparam int L4_OUT_H = 13, L4_OUT_W = 19;
    localparam int L5_H = 13, L5_W = 19, L5_CIN = 7,  L5_COUT = 8,  L5_PASSES = 8;

    // =========================================================================
    // Crossbar & Memory Map Parameters (Matching CrocoScale_SoC.sv)
    // =========================================================================
    localparam int S_COUNT      = 2; // S0: TB CPU Master | S1: Fabric DMA Master
    localparam int M_COUNT      = 2; // M0: System AXI RAM | M1: Slot 0 Control Bridge
    localparam int AXI_ID_WIDTH = 8;
    localparam int M_ID_WIDTH   = AXI_ID_WIDTH;
    localparam int RAM_ADDR_W   = 19; // 512 KB System RAM for ping-pong buffers & weights

    localparam logic [31:0] RAM_BASE_ADDR  = 32'h0000_0000;
    localparam logic [31:0] CTRL_BASE_ADDR = 32'h2000_0000;

    localparam logic [M_COUNT*32-1:0] CROSSBAR_BASE_ADDRS  = {CTRL_BASE_ADDR, RAM_BASE_ADDR};
    localparam logic [M_COUNT*32-1:0] CROSSBAR_ADDR_WIDTHS = {32'd16, 32'(RAM_ADDR_W)};

    // Slot 0 Control CSR Offsets (Accessed by CPU at CTRL_BASE_ADDR + REG_*)
    localparam logic [31:0] REG_CTRL        = 32'h0000_0000;
    localparam logic [31:0] REG_STATUS      = 32'h0000_0004;
    localparam logic [31:0] REG_CONFIG      = 32'h0000_0008;
    localparam logic [31:0] REG_IRQ_STATUS  = 32'h0000_000C;
    localparam logic [31:0] REG_ACT_BASE    = 32'h0000_0010;
    localparam logic [31:0] REG_WEIGHT_BASE = 32'h0000_0014;
    localparam logic [31:0] REG_OUT_BASE    = 32'h0000_0018;
    localparam logic [31:0] REG_BIAS_BASE   = 32'h0000_001C;
    localparam logic [31:0] REG_QUANT_BASE  = 32'h0000_0020;
    localparam logic [31:0] REG_LUT_BASE    = 32'h0000_0024;
    localparam logic [31:0] REG_GEOM        = 32'h0000_0028;

    // System RAM Buffer Addresses (Byte Addresses inside 512 KB RAM)
    localparam logic [31:0] ACT_BUF_A_BASE   = 32'h0000_0000; // 128 KB Ping Buffer (L1 in, L2 out, L4 out)
    localparam logic [31:0] ACT_BUF_B_BASE   = 32'h0002_0000; // 128 KB Pong Buffer (L1 out, L3 out, L5 out)
    localparam logic [31:0] WEIGHT_BASE_ADDR = 32'h0004_0000;
    localparam logic [31:0] BIAS_BASE_ADDR   = 32'h0005_0000;
    localparam logic [31:0] QUANT_BASE_ADDR  = 32'h0005_1000;
    localparam logic [31:0] LUT_BASE_ADDR    = 32'h0005_2000;
    localparam logic [31:0] CPU_SCRATCH_BASE = 32'h0006_0000; // For concurrent random CPU R/W stress

    // Per-Layer Weight, Bias & Quantizer Sub-Offsets in System RAM
    localparam logic [31:0] L1_W_BASE = WEIGHT_BASE_ADDR + 32'h0000_0000;
    localparam logic [31:0] L2_W_BASE = WEIGHT_BASE_ADDR + 32'h0000_1000;
    localparam logic [31:0] L3_W_BASE = WEIGHT_BASE_ADDR + 32'h0000_2000;
    localparam logic [31:0] L4_W_BASE = WEIGHT_BASE_ADDR + 32'h0000_3000;
    localparam logic [31:0] L5_W_BASE = WEIGHT_BASE_ADDR + 32'h0000_4000;

    localparam logic [31:0] L1_B_BASE = BIAS_BASE_ADDR   + 32'h0000_0000;
    localparam logic [31:0] L2_B_BASE = BIAS_BASE_ADDR   + 32'h0000_0100;
    localparam logic [31:0] L3_B_BASE = BIAS_BASE_ADDR   + 32'h0000_0200;
    localparam logic [31:0] L4_B_BASE = BIAS_BASE_ADDR   + 32'h0000_0300;
    localparam logic [31:0] L5_B_BASE = BIAS_BASE_ADDR   + 32'h0000_0400;

    localparam logic [31:0] L1_Q_BASE = QUANT_BASE_ADDR  + 32'h0000_0000;
    localparam logic [31:0] L2_Q_BASE = QUANT_BASE_ADDR  + 32'h0000_0100;
    localparam logic [31:0] L3_Q_BASE = QUANT_BASE_ADDR  + 32'h0000_0200;
    localparam logic [31:0] L4_Q_BASE = QUANT_BASE_ADDR  + 32'h0000_0300;
    localparam logic [31:0] L5_Q_BASE = QUANT_BASE_ADDR  + 32'h0000_0400;

    logic clk;
    logic rst_n;
    wire  rst = ~rst_n;

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // =========================================================================
    // Crossbar Slave Signals (S0: Emulated CPU, S1: Fabric DMA Master)
    // =========================================================================
    logic [S_COUNT*AXI_ID_WIDTH-1:0] s_axi_awid;
    logic [S_COUNT*32-1:0]           s_axi_awaddr;
    logic [S_COUNT*8-1:0]            s_axi_awlen;
    logic [S_COUNT*3-1:0]            s_axi_awsize;
    logic [S_COUNT*2-1:0]            s_axi_awburst;
    logic [S_COUNT-1:0]              s_axi_awlock;
    logic [S_COUNT*4-1:0]            s_axi_awcache;
    logic [S_COUNT*3-1:0]            s_axi_awprot;
    logic [S_COUNT-1:0]              s_axi_awvalid;
    wire  [S_COUNT-1:0]              s_axi_awready;
    logic [S_COUNT*32-1:0]           s_axi_wdata;
    logic [S_COUNT*4-1:0]            s_axi_wstrb;
    logic [S_COUNT-1:0]              s_axi_wlast;
    logic [S_COUNT-1:0]              s_axi_wvalid;
    wire  [S_COUNT-1:0]              s_axi_wready;
    wire  [S_COUNT*AXI_ID_WIDTH-1:0] s_axi_bid;
    wire  [S_COUNT*2-1:0]            s_axi_bresp;
    wire  [S_COUNT-1:0]              s_axi_bvalid;
    logic [S_COUNT-1:0]              s_axi_bready;
    logic [S_COUNT*AXI_ID_WIDTH-1:0] s_axi_arid;
    logic [S_COUNT*32-1:0]           s_axi_araddr;
    logic [S_COUNT*8-1:0]            s_axi_arlen;
    logic [S_COUNT*3-1:0]            s_axi_arsize;
    logic [S_COUNT*2-1:0]            s_axi_arburst;
    logic [S_COUNT-1:0]              s_axi_arlock;
    logic [S_COUNT*4-1:0]            s_axi_arcache;
    logic [S_COUNT*3-1:0]            s_axi_arprot;
    logic [S_COUNT-1:0]              s_axi_arvalid;
    wire  [S_COUNT-1:0]              s_axi_arready;
    wire  [S_COUNT*AXI_ID_WIDTH-1:0] s_axi_rid;
    wire  [S_COUNT*32-1:0]           s_axi_rdata;
    wire  [S_COUNT*2-1:0]            s_axi_rresp;
    wire  [S_COUNT-1:0]              s_axi_rlast;
    wire  [S_COUNT-1:0]              s_axi_rvalid;
    logic [S_COUNT-1:0]              s_axi_rready;

    // =========================================================================
    // Crossbar Master Signals (M0: System RAM, M1: Slot Control Bridge)
    // =========================================================================
    wire [M_COUNT*M_ID_WIDTH-1:0]    m_axi_awid;
    wire [M_COUNT*32-1:0]            m_axi_awaddr;
    wire [M_COUNT*8-1:0]             m_axi_awlen;
    wire [M_COUNT*3-1:0]             m_axi_awsize;
    wire [M_COUNT*2-1:0]             m_axi_awburst;
    wire [M_COUNT-1:0]               m_axi_awlock;
    wire [M_COUNT*4-1:0]             m_axi_awcache;
    wire [M_COUNT*3-1:0]             m_axi_awprot;
    wire [M_COUNT*4-1:0]             m_axi_awqos;
    wire [M_COUNT*4-1:0]             m_axi_awregion;
    wire [M_COUNT-1:0]               m_axi_awvalid;
    wire [M_COUNT-1:0]               m_axi_awready;
    wire [M_COUNT*32-1:0]            m_axi_wdata;
    wire [M_COUNT*4-1:0]             m_axi_wstrb;
    wire [M_COUNT-1:0]               m_axi_wlast;
    wire [M_COUNT-1:0]               m_axi_wvalid;
    wire [M_COUNT-1:0]               m_axi_wready;
    wire [M_COUNT*M_ID_WIDTH-1:0]    m_axi_bid;
    wire [M_COUNT*2-1:0]             m_axi_bresp;
    wire [M_COUNT-1:0]               m_axi_bvalid;
    wire [M_COUNT-1:0]               m_axi_bready;
    wire [M_COUNT*M_ID_WIDTH-1:0]    m_axi_arid;
    wire [M_COUNT*32-1:0]            m_axi_araddr;
    wire [M_COUNT*8-1:0]             m_axi_arlen;
    wire [M_COUNT*3-1:0]             m_axi_arsize;
    wire [M_COUNT*2-1:0]             m_axi_arburst;
    wire [M_COUNT-1:0]               m_axi_arlock;
    wire [M_COUNT*4-1:0]             m_axi_arcache;
    wire [M_COUNT*3-1:0]             m_axi_arprot;
    wire [M_COUNT*4-1:0]             m_axi_arqos;
    wire [M_COUNT*4-1:0]             m_axi_arregion;
    wire [M_COUNT-1:0]               m_axi_arvalid;
    wire [M_COUNT-1:0]               m_axi_arready;
    wire [M_COUNT*M_ID_WIDTH-1:0]    m_axi_rid;
    wire [M_COUNT*32-1:0]            m_axi_rdata;
    wire [M_COUNT*2-1:0]             m_axi_rresp;
    wire [M_COUNT-1:0]               m_axi_rlast;
    wire [M_COUNT-1:0]               m_axi_rvalid;
    wire [M_COUNT-1:0]               m_axi_rready;

    // =========================================================================
    // Testbench Emulated CPU Master Port Signals (Connected to Crossbar S0)
    // =========================================================================
    logic [AXI_ID_WIDTH-1:0] tb_axi_awid;
    logic [31:0]             tb_axi_awaddr;
    logic [7:0]              tb_axi_awlen;
    logic [2:0]              tb_axi_awsize;
    logic [1:0]              tb_axi_awburst;
    logic                    tb_axi_awlock;
    logic [3:0]              tb_axi_awcache;
    logic [2:0]              tb_axi_awprot;
    logic                    tb_axi_awvalid;
    wire                     tb_axi_awready = s_axi_awready[0];
    logic [31:0]             tb_axi_wdata;
    logic [3:0]              tb_axi_wstrb;
    logic                    tb_axi_wlast;
    logic                    tb_axi_wvalid;
    wire                     tb_axi_wready  = s_axi_wready[0];
    wire  [AXI_ID_WIDTH-1:0] tb_axi_bid     = s_axi_bid[0*AXI_ID_WIDTH +: AXI_ID_WIDTH];
    wire  [1:0]              tb_axi_bresp   = s_axi_bresp[0*2 +: 2];
    wire                     tb_axi_bvalid  = s_axi_bvalid[0];
    logic                    tb_axi_bready;
    logic [AXI_ID_WIDTH-1:0] tb_axi_arid;
    logic [31:0]             tb_axi_araddr;
    logic [7:0]              tb_axi_arlen;
    logic [2:0]              tb_axi_arsize;
    logic [1:0]              tb_axi_arburst;
    logic                    tb_axi_arlock;
    logic [3:0]              tb_axi_arcache;
    logic [2:0]              tb_axi_arprot;
    logic                    tb_axi_arvalid;
    wire                     tb_axi_arready = s_axi_arready[0];
    wire  [AXI_ID_WIDTH-1:0] tb_axi_rid     = s_axi_rid[0*AXI_ID_WIDTH +: AXI_ID_WIDTH];
    wire  [31:0]             tb_axi_rdata   = s_axi_rdata[0*32 +: 32];
    wire  [1:0]              tb_axi_rresp   = s_axi_rresp[0*2 +: 2];
    wire                     tb_axi_rlast   = s_axi_rlast[0];
    wire                     tb_axi_rvalid  = s_axi_rvalid[0];
    logic                    tb_axi_rready;

    // Bind S0 to Testbench Emulated CPU Master
    assign s_axi_awid   [0*AXI_ID_WIDTH +: AXI_ID_WIDTH] = tb_axi_awid;
    assign s_axi_awaddr [0*32 +: 32]                     = tb_axi_awaddr;
    assign s_axi_awlen  [0*8 +: 8]                       = tb_axi_awlen;
    assign s_axi_awsize [0*3 +: 3]                       = tb_axi_awsize;
    assign s_axi_awburst[0*2 +: 2]                       = tb_axi_awburst;
    assign s_axi_awlock [0]                              = tb_axi_awlock;
    assign s_axi_awcache[0*4 +: 4]                       = tb_axi_awcache;
    assign s_axi_awprot [0*3 +: 3]                       = tb_axi_awprot;
    assign s_axi_awvalid[0]                              = tb_axi_awvalid;
    assign s_axi_wdata  [0*32 +: 32]                     = tb_axi_wdata;
    assign s_axi_wstrb  [0*4 +: 4]                       = tb_axi_wstrb;
    assign s_axi_wlast  [0]                              = tb_axi_wlast;
    assign s_axi_wvalid [0]                              = tb_axi_wvalid;
    assign s_axi_bready [0]                              = tb_axi_bready;
    assign s_axi_arid   [0*AXI_ID_WIDTH +: AXI_ID_WIDTH] = tb_axi_arid;
    assign s_axi_araddr [0*32 +: 32]                     = tb_axi_araddr;
    assign s_axi_arlen  [0*8 +: 8]                       = tb_axi_arlen;
    assign s_axi_arsize [0*3 +: 3]                       = tb_axi_arsize;
    assign s_axi_arburst[0*2 +: 2]                       = tb_axi_arburst;
    assign s_axi_arlock [0]                              = tb_axi_arlock;
    assign s_axi_arcache[0*4 +: 4]                       = tb_axi_arcache;
    assign s_axi_arprot [0*3 +: 3]                       = tb_axi_arprot;
    assign s_axi_arvalid[0]                              = tb_axi_arvalid;
    assign s_axi_rready [0]                              = tb_axi_rready;

    // Bind S1 Tie-Offs (Fabric DMA Master ID & PROT)
    assign s_axi_awid  [1*AXI_ID_WIDTH +: AXI_ID_WIDTH] = {AXI_ID_WIDTH{1'b0}};
    assign s_axi_arid  [1*AXI_ID_WIDTH +: AXI_ID_WIDTH] = {AXI_ID_WIDTH{1'b0}};
    assign s_axi_awprot[1*3 +: 3]                       = 3'b000;
    assign s_axi_arprot[1*3 +: 3]                       = 3'b000;

    // =========================================================================
    // 1. Shared-Bus AXI4 Interconnect (axi_interconnect)
    // =========================================================================
    axi_interconnect #(
        .S_COUNT      (S_COUNT),
        .M_COUNT      (M_COUNT),
        .DATA_WIDTH   (32),
        .ADDR_WIDTH   (32),
        .STRB_WIDTH   (4),
        .ID_WIDTH     (AXI_ID_WIDTH),
        .FORWARD_ID   (1),
        .M_BASE_ADDR  (CROSSBAR_BASE_ADDRS),
        .M_ADDR_WIDTH (CROSSBAR_ADDR_WIDTHS)
    ) u_axi_interconnect (
        .clk           (clk),
        .rst           (rst),

        .s_axi_awid    (s_axi_awid),    .s_axi_awaddr  (s_axi_awaddr),
        .s_axi_awlen   (s_axi_awlen),   .s_axi_awsize  (s_axi_awsize),
        .s_axi_awburst (s_axi_awburst), .s_axi_awlock  (s_axi_awlock),
        .s_axi_awcache (s_axi_awcache), .s_axi_awprot  (s_axi_awprot),
        .s_axi_awqos   ('0),            .s_axi_awuser  ('0),
        .s_axi_awvalid (s_axi_awvalid), .s_axi_awready (s_axi_awready),
        .s_axi_wdata   (s_axi_wdata),   .s_axi_wstrb   (s_axi_wstrb),
        .s_axi_wlast   (s_axi_wlast),   .s_axi_wuser   ('0),
        .s_axi_wvalid  (s_axi_wvalid),  .s_axi_wready  (s_axi_wready),
        .s_axi_bid     (s_axi_bid),     .s_axi_bresp   (s_axi_bresp),
        .s_axi_buser   (),              .s_axi_bvalid  (s_axi_bvalid),
        .s_axi_bready  (s_axi_bready),
        .s_axi_arid    (s_axi_arid),    .s_axi_araddr  (s_axi_araddr),
        .s_axi_arlen   (s_axi_arlen),   .s_axi_arsize  (s_axi_arsize),
        .s_axi_arburst (s_axi_arburst), .s_axi_arlock  (s_axi_arlock),
        .s_axi_arcache (s_axi_arcache), .s_axi_arprot  (s_axi_arprot),
        .s_axi_arqos   ('0),            .s_axi_aruser  ('0),
        .s_axi_arvalid (s_axi_arvalid), .s_axi_arready (s_axi_arready),
        .s_axi_rid     (s_axi_rid),     .s_axi_rdata   (s_axi_rdata),
        .s_axi_rresp   (s_axi_rresp),   .s_axi_rlast   (s_axi_rlast),
        .s_axi_ruser   (),              .s_axi_rvalid  (s_axi_rvalid),
        .s_axi_rready  (s_axi_rready),

        .m_axi_awid    (m_axi_awid),    .m_axi_awaddr  (m_axi_awaddr),
        .m_axi_awlen   (m_axi_awlen),   .m_axi_awsize  (m_axi_awsize),
        .m_axi_awburst (m_axi_awburst), .m_axi_awlock  (m_axi_awlock),
        .m_axi_awcache (m_axi_awcache), .m_axi_awprot  (m_axi_awprot),
        .m_axi_awqos   (m_axi_awqos),   .m_axi_awregion(m_axi_awregion),
        .m_axi_awuser  (),
        .m_axi_awvalid (m_axi_awvalid), .m_axi_awready (m_axi_awready),
        .m_axi_wdata   (m_axi_wdata),   .m_axi_wstrb   (m_axi_wstrb),
        .m_axi_wlast   (m_axi_wlast),   .m_axi_wuser   (),
        .m_axi_wvalid  (m_axi_wvalid),  .m_axi_wready  (m_axi_wready),
        .m_axi_bid     (m_axi_bid),     .m_axi_bresp   (m_axi_bresp),
        .m_axi_buser   ('0),            .m_axi_bvalid  (m_axi_bvalid),
        .m_axi_bready  (m_axi_bready),
        .m_axi_arid    (m_axi_arid),    .m_axi_araddr  (m_axi_araddr),
        .m_axi_arlen   (m_axi_arlen),   .m_axi_arsize  (m_axi_arsize),
        .m_axi_arburst (m_axi_arburst), .m_axi_arlock  (m_axi_arlock),
        .m_axi_arcache (m_axi_arcache), .m_axi_arprot  (m_axi_arprot),
        .m_axi_arqos   (m_axi_arqos),   .m_axi_arregion(m_axi_arregion),
        .m_axi_aruser  (),
        .m_axi_arvalid (m_axi_arvalid), .m_axi_arready (m_axi_arready),
        .m_axi_rid     (m_axi_rid),     .m_axi_rdata   (m_axi_rdata),
        .m_axi_rresp   (m_axi_rresp),   .m_axi_rlast   (m_axi_rlast),
        .m_axi_ruser   ('0),            .m_axi_rvalid  (m_axi_rvalid),
        .m_axi_rready  (m_axi_rready)
    );

    // =========================================================================
    // 2. Crossbar Master 0: System AXI4 RAM (256 KB @ 0x0000_0000)
    // =========================================================================
    axi_ram #(
        .DATA_WIDTH     (32),
        .ADDR_WIDTH     (RAM_ADDR_W),
        .ID_WIDTH       (M_ID_WIDTH),
        .PIPELINE_OUTPUT(0)
    ) sys_ram_inst (
        .clk           (clk),
        .rst           (rst),
        .s_axi_awid    (m_axi_awid   [0*M_ID_WIDTH +: M_ID_WIDTH]),
        .s_axi_awaddr  (m_axi_awaddr [0*32 +: RAM_ADDR_W]),
        .s_axi_awlen   (m_axi_awlen  [0*8 +: 8]),
        .s_axi_awsize  (m_axi_awsize [0*3 +: 3]),
        .s_axi_awburst (m_axi_awburst[0*2 +: 2]),
        .s_axi_awlock  (m_axi_awlock [0]),
        .s_axi_awcache (m_axi_awcache[0*4 +: 4]),
        .s_axi_awprot  (m_axi_awprot [0*3 +: 3]),
        .s_axi_awvalid (m_axi_awvalid[0]),
        .s_axi_awready (m_axi_awready[0]),
        .s_axi_wdata   (m_axi_wdata  [0*32 +: 32]),
        .s_axi_wstrb   (m_axi_wstrb  [0*4 +: 4]),
        .s_axi_wlast   (m_axi_wlast  [0]),
        .s_axi_wvalid  (m_axi_wvalid [0]),
        .s_axi_wready  (m_axi_wready [0]),
        .s_axi_bid     (m_axi_bid    [0*M_ID_WIDTH +: M_ID_WIDTH]),
        .s_axi_bresp   (m_axi_bresp  [0*2 +: 2]),
        .s_axi_bvalid  (m_axi_bvalid [0]),
        .s_axi_bready  (m_axi_bready [0]),
        .s_axi_arid    (m_axi_arid   [0*M_ID_WIDTH +: M_ID_WIDTH]),
        .s_axi_araddr  (m_axi_araddr [0*32 +: RAM_ADDR_W]),
        .s_axi_arlen   (m_axi_arlen  [0*8 +: 8]),
        .s_axi_arsize  (m_axi_arsize [0*3 +: 3]),
        .s_axi_arburst (m_axi_arburst[0*2 +: 2]),
        .s_axi_arlock  (m_axi_arlock [0]),
        .s_axi_arcache (m_axi_arcache[0*4 +: 4]),
        .s_axi_arprot  (m_axi_arprot [0*3 +: 3]),
        .s_axi_arvalid (m_axi_arvalid[0]),
        .s_axi_arready (m_axi_arready[0]),
        .s_axi_rid     (m_axi_rid    [0*M_ID_WIDTH +: M_ID_WIDTH]),
        .s_axi_rdata   (m_axi_rdata  [0*32 +: 32]),
        .s_axi_rresp   (m_axi_rresp  [0*2 +: 2]),
        .s_axi_rlast   (m_axi_rlast  [0]),
        .s_axi_rvalid  (m_axi_rvalid [0]),
        .s_axi_rready  (m_axi_rready [0])
    );

    // =========================================================================
    // 3. Crossbar Master 1: AXI4-to-AXI4-Lite Slot Control Bridge (@ 0x2000_0000)
    // =========================================================================
    wire [31:0] axil_ctrl_awaddr;
    wire [2:0]  axil_ctrl_awprot;
    wire        axil_ctrl_awvalid;
    wire        axil_ctrl_awready;
    wire [31:0] axil_ctrl_wdata;
    wire [3:0]  axil_ctrl_wstrb;
    wire        axil_ctrl_wvalid;
    wire        axil_ctrl_wready;
    wire [1:0]  axil_ctrl_bresp;
    wire        axil_ctrl_bvalid;
    wire        axil_ctrl_bready;
    wire [31:0] axil_ctrl_araddr;
    wire [2:0]  axil_ctrl_arprot;
    wire        axil_ctrl_arvalid;
    wire        axil_ctrl_arready;
    wire [31:0] axil_ctrl_rdata;
    wire [1:0]  axil_ctrl_rresp;
    wire        axil_ctrl_rvalid;
    wire        axil_ctrl_rready;

    axi_axil_adapter #(
        .ADDR_WIDTH     (32),
        .AXI_DATA_WIDTH (32),
        .AXIL_DATA_WIDTH(32),
        .AXI_ID_WIDTH   (M_ID_WIDTH)
    ) u_ctrl_bridge (
        .clk           (clk),
        .rst           (rst),
        .s_axi_awid    (m_axi_awid   [1*M_ID_WIDTH +: M_ID_WIDTH]),
        .s_axi_awaddr  (m_axi_awaddr [1*32 +: 32]),
        .s_axi_awlen   (m_axi_awlen  [1*8 +: 8]),
        .s_axi_awsize  (m_axi_awsize [1*3 +: 3]),
        .s_axi_awburst (m_axi_awburst[1*2 +: 2]),
        .s_axi_awlock  (m_axi_awlock [1]),
        .s_axi_awcache (m_axi_awcache[1*4 +: 4]),
        .s_axi_awprot  (m_axi_awprot [1*3 +: 3]),
        .s_axi_awvalid (m_axi_awvalid[1]),
        .s_axi_awready (m_axi_awready[1]),
        .s_axi_wdata   (m_axi_wdata  [1*32 +: 32]),
        .s_axi_wstrb   (m_axi_wstrb  [1*4 +: 4]),
        .s_axi_wlast   (m_axi_wlast  [1]),
        .s_axi_wvalid  (m_axi_wvalid [1]),
        .s_axi_wready  (m_axi_wready [1]),
        .s_axi_bid     (m_axi_bid    [1*M_ID_WIDTH +: M_ID_WIDTH]),
        .s_axi_bresp   (m_axi_bresp  [1*2 +: 2]),
        .s_axi_bvalid  (m_axi_bvalid [1]),
        .s_axi_bready  (m_axi_bready [1]),
        .s_axi_arid    (m_axi_arid   [1*M_ID_WIDTH +: M_ID_WIDTH]),
        .s_axi_araddr  (m_axi_araddr [1*32 +: 32]),
        .s_axi_arlen   (m_axi_arlen  [1*8 +: 8]),
        .s_axi_arsize  (m_axi_arsize [1*3 +: 3]),
        .s_axi_arburst (m_axi_arburst[1*2 +: 2]),
        .s_axi_arlock  (m_axi_arlock [1]),
        .s_axi_arcache (m_axi_arcache[1*4 +: 4]),
        .s_axi_arprot  (m_axi_arprot [1*3 +: 3]),
        .s_axi_arvalid (m_axi_arvalid[1]),
        .s_axi_arready (m_axi_arready[1]),
        .s_axi_rid     (m_axi_rid    [1*M_ID_WIDTH +: M_ID_WIDTH]),
        .s_axi_rdata   (m_axi_rdata  [1*32 +: 32]),
        .s_axi_rresp   (m_axi_rresp  [1*2 +: 2]),
        .s_axi_rlast   (m_axi_rlast  [1]),
        .s_axi_rvalid  (m_axi_rvalid [1]),
        .s_axi_rready  (m_axi_rready [1]),

        .m_axil_awaddr (axil_ctrl_awaddr),
        .m_axil_awprot (axil_ctrl_awprot),
        .m_axil_awvalid(axil_ctrl_awvalid),
        .m_axil_awready(axil_ctrl_awready),
        .m_axil_wdata  (axil_ctrl_wdata),
        .m_axil_wstrb  (axil_ctrl_wstrb),
        .m_axil_wvalid (axil_ctrl_wvalid),
        .m_axil_wready (axil_ctrl_wready),
        .m_axil_bresp  (axil_ctrl_bresp),
        .m_axil_bvalid (axil_ctrl_bvalid),
        .m_axil_bready (axil_ctrl_bready),
        .m_axil_araddr (axil_ctrl_araddr),
        .m_axil_arprot (axil_ctrl_arprot),
        .m_axil_arvalid(axil_ctrl_arvalid),
        .m_axil_arready(axil_ctrl_arready),
        .m_axil_rdata  (axil_ctrl_rdata),
        .m_axil_rresp  (axil_ctrl_rresp),
        .m_axil_rvalid (axil_ctrl_rvalid),
        .m_axil_rready (axil_ctrl_rready)
    );

    // =========================================================================
    // 4. Perimeter BEL Boundary Harness + Soft-Logic Sequencer + Hardened NPU
    // =========================================================================
    wire [9:0]   fab_axil_awaddr;
    wire [2:0]   fab_axil_awprot;
    wire         fab_axil_awvalid;
    wire         fab_axil_awready;
    wire [31:0]  fab_axil_wdata;
    wire [3:0]   fab_axil_wstrb;
    wire         fab_axil_wvalid;
    wire         fab_axil_wready;
    wire [1:0]   fab_axil_bresp;
    wire         fab_axil_bvalid;
    wire         fab_axil_bready;
    wire [9:0]   fab_axil_araddr;
    wire [2:0]   fab_axil_arprot;
    wire         fab_axil_arvalid;
    wire         fab_axil_arready;
    wire [31:0]  fab_axil_rdata;
    wire [1:0]   fab_axil_rresp;
    wire         fab_axil_rvalid;
    wire         fab_axil_rready;

    wire [31:0]  fab_axi_awaddr;
    wire [7:0]   fab_axi_awlen;
    wire         fab_axi_awvalid;
    wire         fab_axi_awready;
    wire [31:0]  fab_axi_wdata;
    wire [3:0]   fab_axi_wstrb;
    wire         fab_axi_wlast;
    wire         fab_axi_wvalid;
    wire         fab_axi_wready;
    wire [1:0]   fab_axi_bresp;
    wire         fab_axi_bvalid;
    wire         fab_axi_bready;
    wire [31:0]  fab_axi_araddr;
    wire [7:0]   fab_axi_arlen;
    wire         fab_axi_arvalid;
    wire         fab_axi_arready;
    wire [31:0]  fab_axi_rdata;
    wire [1:0]   fab_axi_rresp;
    wire         fab_axi_rlast;
    wire         fab_axi_rvalid;
    wire         fab_axi_rready;

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
    wire        [3:0]                                soc_usr_irq;
    wire        [3:0]                                fab_slot_soft_rst_n;

    wire        [ARRAY_HEIGHT-1:0]                   npu_act_clk;
    wire                                             npu_array_en;
    wire                                             npu_psum_systolic_en;
    wire                                             npu_psum_lut_en;
    wire                                             npu_psum_skew_en;
    wire                                             npu_compute_bank_swap;
    wire                                             npu_swap_weights;
    wire        [29:0]                               npu_quant_shift_in;
    wire                                             npu_quant_shift_en;
    wire        [ARRAY_HEIGHT-1:0][3:0]              npu_crossbar_sel;
    wire signed [ARRAY_HEIGHT-1:0][WEIGHT_WIDTH-1:0] npu_weight_shift_in;
    wire        [ARRAY_HEIGHT-1:0]                   npu_weight_shift_en;
    wire        [ARRAY_HEIGHT-1:0]                   npu_ext_act_sram_we;
    wire        [ARRAY_HEIGHT-1:0][8:0]              npu_ext_act_sram_addr;
    wire        [ARRAY_HEIGHT-1:0][ACTIVATION_WIDTH-1:0] npu_ext_act_sram_wdata;
    wire        [ARRAY_HEIGHT-1:0][ACTIVATION_WIDTH-1:0] npu_act_sram_rdata;
    wire        [ARRAY_WIDTH-1:0][ACTIVATION_WIDTH-1:0]  npu_out_act;
    wire        [7:0]                                npu_psum_A_addr;
    wire        [ARRAY_WIDTH-1:0]                    npu_psum_A_we;
    wire signed [PSUM_WIDTH-1:0]                     npu_psum_A_wdata;
    wire        [2:0]                                npu_psum_A_read_bank_sel;
    wire signed [PSUM_WIDTH-1:0]                     npu_psum_A_rdata;
    wire        [7:0]                                npu_psum_B_addr;
    wire        [ARRAY_WIDTH-1:0]                    npu_psum_B_we;
    wire signed [PSUM_WIDTH-1:0]                     npu_psum_B_wdata;
    wire        [2:0]                                npu_psum_B_read_bank_sel;
    wire signed [PSUM_WIDTH-1:0]                     npu_psum_B_rdata;

    efpga_boundary_harness #(
        .ARRAY_HEIGHT    (ARRAY_HEIGHT),
        .ARRAY_WIDTH     (ARRAY_WIDTH),
        .ACTIVATION_WIDTH(ACTIVATION_WIDTH),
        .WEIGHT_WIDTH    (WEIGHT_WIDTH),
        .PSUM_WIDTH      (PSUM_WIDTH),
        .CFG_AXI_M       (12'hF3E),
        .CFG_NPU_CTRL    (1'b0),
        .CFG_DEBUG       (16'h0004)
    ) harness_inst (
        .clk_i                   (clk),

        // SoC Facing Ports: Connected to u_ctrl_bridge (M1) and u_axi_crossbar (S1)
        .s_axil_awaddr           (axil_ctrl_awaddr[9:0]),
        .s_axil_awprot           (axil_ctrl_awprot),
        .s_axil_awvalid          (axil_ctrl_awvalid),
        .s_axil_awready          (axil_ctrl_awready),
        .s_axil_wdata            (axil_ctrl_wdata),
        .s_axil_wstrb            (axil_ctrl_wstrb),
        .s_axil_wvalid           (axil_ctrl_wvalid),
        .s_axil_wready           (axil_ctrl_wready),
        .s_axil_bresp            (axil_ctrl_bresp),
        .s_axil_bvalid           (axil_ctrl_bvalid),
        .s_axil_bready           (axil_ctrl_bready),
        .s_axil_araddr           (axil_ctrl_araddr[9:0]),
        .s_axil_arprot           (axil_ctrl_arprot),
        .s_axil_arvalid          (axil_ctrl_arvalid),
        .s_axil_arready          (axil_ctrl_arready),
        .s_axil_rdata            (axil_ctrl_rdata),
        .s_axil_rresp            (axil_ctrl_rresp),
        .s_axil_rvalid           (axil_ctrl_rvalid),
        .s_axil_rready           (axil_ctrl_rready),

        .m_axi_awaddr            (s_axi_awaddr [1*32 +: 32]),
        .m_axi_awlen             (s_axi_awlen  [1*8 +: 8]),
        .m_axi_awsize            (s_axi_awsize [1*3 +: 3]),
        .m_axi_awburst           (s_axi_awburst[1*2 +: 2]),
        .m_axi_awlock            (s_axi_awlock [1]),
        .m_axi_awcache           (s_axi_awcache[1*4 +: 4]),
        .m_axi_awvalid           (s_axi_awvalid[1]),
        .m_axi_awready           (s_axi_awready[1]),
        .m_axi_wdata             (s_axi_wdata  [1*32 +: 32]),
        .m_axi_wstrb             (s_axi_wstrb  [1*4 +: 4]),
        .m_axi_wlast             (s_axi_wlast  [1]),
        .m_axi_wvalid            (s_axi_wvalid [1]),
        .m_axi_wready            (s_axi_wready [1]),
        .m_axi_bresp             (s_axi_bresp  [1*2 +: 2]),
        .m_axi_bvalid            (s_axi_bvalid [1]),
        .m_axi_bready            (s_axi_bready [1]),
        .m_axi_araddr            (s_axi_araddr [1*32 +: 32]),
        .m_axi_arlen             (s_axi_arlen  [1*8 +: 8]),
        .m_axi_arsize            (s_axi_arsize [1*3 +: 3]),
        .m_axi_arburst           (s_axi_arburst[1*2 +: 2]),
        .m_axi_arlock            (s_axi_arlock [1]),
        .m_axi_arcache           (s_axi_arcache[1*4 +: 4]),
        .m_axi_arvalid           (s_axi_arvalid[1]),
        .m_axi_arready           (s_axi_arready[1]),
        .m_axi_rdata             (s_axi_rdata  [1*32 +: 32]),
        .m_axi_rresp             (s_axi_rresp  [1*2 +: 2]),
        .m_axi_rlast             (s_axi_rlast  [1]),
        .m_axi_rvalid            (s_axi_rvalid [1]),
        .m_axi_rready            (s_axi_rready [1]),

        .soc_debug_out_i         (32'd0),
        .soc_debug_in_o          (),
        .soc_usr_irq_o           (soc_usr_irq),
        .soc_slot_soft_rst_n_i   ({3'b0, rst_n}),

        // NPU Facing Ports
        .npu_act_clk             (npu_act_clk),
        .npu_array_en            (npu_array_en),
        .npu_psum_systolic_en    (npu_psum_systolic_en),
        .npu_psum_lut_en         (npu_psum_lut_en),
        .npu_psum_skew_en        (npu_psum_skew_en),
        .npu_compute_bank_swap   (npu_compute_bank_swap),
        .npu_swap_weights        (npu_swap_weights),
        .npu_quant_shift_in      (npu_quant_shift_in),
        .npu_quant_shift_en      (npu_quant_shift_en),
        .npu_crossbar_sel        (npu_crossbar_sel),
        .npu_weight_shift_in     (npu_weight_shift_in),
        .npu_weight_shift_en     (npu_weight_shift_en),
        .npu_ext_act_sram_we     (npu_ext_act_sram_we),
        .npu_ext_act_sram_addr   (npu_ext_act_sram_addr),
        .npu_ext_act_sram_wdata  (npu_ext_act_sram_wdata),
        .npu_act_sram_rdata      (npu_act_sram_rdata),
        .npu_out_act             (npu_out_act),
        .npu_psum_A_addr         (npu_psum_A_addr),
        .npu_psum_A_we           (npu_psum_A_we),
        .npu_psum_A_wdata        (npu_psum_A_wdata),
        .npu_psum_A_read_bank_sel(npu_psum_A_read_bank_sel),
        .npu_psum_A_rdata        (npu_psum_A_rdata),
        .npu_psum_B_addr         (npu_psum_B_addr),
        .npu_psum_B_we           (npu_psum_B_we),
        .npu_psum_B_wdata        (npu_psum_B_wdata),
        .npu_psum_B_read_bank_sel(npu_psum_B_read_bank_sel),
        .npu_psum_B_rdata        (npu_psum_B_rdata),

        // Fabric Facing AXI-Lite & AXI4 Ports
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

        // Fabric Facing NPU Control & Data Ports (No PSUM Peek Backdoor)
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

    npu_flex_sequencer #(
        .ARRAY_HEIGHT(ARRAY_HEIGHT),
        .ARRAY_WIDTH (ARRAY_WIDTH),
        .TILE_SIZE   (TILE_SIZE),
        .ACT_HALO_PAD(ACT_HALO_PAD),
        .TOTAL_PASSES(TOTAL_PASSES),
        .CIN         (CIN),
        .COUT        (COUT),
        .DEFAULT_H   (L1_H),
        .DEFAULT_W   (L1_W),
        .FIFO_DEPTH  (4)
    ) dut (
        .clk_i                (clk),
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

    npu_wrapper #(
        .ARRAY_HEIGHT    (ARRAY_HEIGHT),
        .ARRAY_WIDTH     (ARRAY_WIDTH),
        .TILE_SIZE       (TILE_SIZE),
        .ACT_HALO_PAD    (ACT_HALO_PAD),
        .ACTIVATION_WIDTH(ACTIVATION_WIDTH),
        .WEIGHT_WIDTH    (WEIGHT_WIDTH),
        .PSUM_WIDTH      (PSUM_WIDTH),
        .SCALE_WIDTH     (SCALE_WIDTH),
        .WEIGHT_SPLIT    (WEIGHT_SPLIT)
    ) npu_inst (
        .clk_i               (clk),
        .act_clk_i           (npu_act_clk),
        .rst_n               (rst_n),
        .array_en            (npu_array_en),
        .psum_systolic_en    (npu_psum_systolic_en),
        .psum_lut_en         (npu_psum_lut_en),
        .psum_skew_en        (npu_psum_skew_en),
        .compute_bank_swap   (npu_compute_bank_swap),
        .crossbar_sel        (npu_crossbar_sel),
        .weight_shift_in     (npu_weight_shift_in),
        .weight_shift_en     (npu_weight_shift_en),
        .swap_weights        (npu_swap_weights),
        .quant_shift_in      (npu_quant_shift_in),
        .quant_shift_en      (npu_quant_shift_en),
        .psum_A_addr         (npu_psum_A_addr),
        .psum_A_we           (npu_psum_A_we),
        .psum_A_wdata        (npu_psum_A_wdata),
        .psum_A_read_bank_sel(npu_psum_A_read_bank_sel),
        .psum_A_rdata        (npu_psum_A_rdata),
        .psum_B_addr         (npu_psum_B_addr),
        .psum_B_we           (npu_psum_B_we),
        .psum_B_wdata        (npu_psum_B_wdata),
        .psum_B_read_bank_sel(npu_psum_B_read_bank_sel),
        .psum_B_rdata        (npu_psum_B_rdata),
        .ext_act_sram_we     (npu_ext_act_sram_we),
        .ext_act_sram_addr   (npu_ext_act_sram_addr),
        .ext_act_sram_wdata  (npu_ext_act_sram_wdata),
        .act_sram_rdata      (npu_act_sram_rdata),
        .out_act             (npu_out_act)
    );

    // =========================================================================
    // Emulated CPU AXI4 Master Bus Transactions (Crossbar Slave S0)
    // =========================================================================
    task automatic cpu_axi_write_word(input logic [31:0] addr, input logic [31:0] data);
        @(posedge clk);
        tb_axi_awid    <= 8'h01;
        tb_axi_awaddr  <= addr;
        tb_axi_awlen   <= 8'd0;
        tb_axi_awsize  <= 3'd2;
        tb_axi_awburst <= 2'b01;
        tb_axi_awlock  <= 1'b0;
        tb_axi_awcache <= 4'd0;
        tb_axi_awprot  <= 3'd0;
        tb_axi_awvalid <= 1'b1;

        tb_axi_wdata   <= data;
        tb_axi_wstrb   <= 4'hF;
        tb_axi_wlast   <= 1'b1;
        tb_axi_wvalid  <= 1'b1;
        tb_axi_bready  <= 1'b1;

        begin
            bit aw_done, w_done;
            aw_done = 1'b0;
            w_done  = 1'b0;
            while (!(aw_done && w_done)) begin
                @(posedge clk);
                if (!aw_done && tb_axi_awready) begin
                    tb_axi_awvalid <= 1'b0;
                    aw_done = 1'b1;
                end
                if (!w_done && tb_axi_wready) begin
                    tb_axi_wvalid <= 1'b0;
                    tb_axi_wlast  <= 1'b0;
                    w_done = 1'b1;
                end
            end
        end

        do @(posedge clk); while (!tb_axi_bvalid);
        if (tb_axi_bresp != 2'b00) begin
            $fatal(1, "[CPU AXI WRITE ERR] BRESP=%0b at addr=0x%08x", tb_axi_bresp, addr);
        end
        tb_axi_bready <= 1'b0;
    endtask

    task automatic cpu_axi_read_word(input logic [31:0] addr, output logic [31:0] data);
        @(posedge clk);
        tb_axi_arid    <= 8'h02;
        tb_axi_araddr  <= addr;
        tb_axi_arlen   <= 8'd0;
        tb_axi_arsize  <= 3'd2;
        tb_axi_arburst <= 2'b01;
        tb_axi_arlock  <= 1'b0;
        tb_axi_arcache <= 4'd0;
        tb_axi_arprot  <= 3'd0;
        tb_axi_arvalid <= 1'b1;
        tb_axi_rready  <= 1'b1;

        do @(posedge clk); while (!tb_axi_arready);
        tb_axi_arvalid <= 1'b0;

        do @(posedge clk); while (!tb_axi_rvalid);
        data = tb_axi_rdata;
        if (tb_axi_rresp != 2'b00) begin
            $fatal(1, "[CPU AXI READ ERR] RRESP=%0b at addr=0x%08x", tb_axi_rresp, addr);
        end
        tb_axi_rready <= 1'b0;
    endtask

    // Multi-Beat AXI4 Write Burst (Up to 256 words) over Crossbar Slave S0
    logic [31:0] cpu_burst_wbuf [0:255];
    task automatic cpu_axi_write_burst(input logic [31:0] start_addr, input int num_beats);
        if (num_beats <= 0 || num_beats > 256)
            $fatal(1, "Invalid burst length: %0d", num_beats);

        @(posedge clk);
        tb_axi_awid    <= 8'h10;
        tb_axi_awaddr  <= start_addr;
        tb_axi_awlen   <= 8'(num_beats - 1);
        tb_axi_awsize  <= 3'd2;
        tb_axi_awburst <= 2'b01;
        tb_axi_awlock  <= 1'b0;
        tb_axi_awcache <= 4'd0;
        tb_axi_awprot  <= 3'd0;
        tb_axi_awvalid <= 1'b1;
        tb_axi_bready  <= 1'b1;

        do @(posedge clk); while (!tb_axi_awready);
        tb_axi_awvalid <= 1'b0;

        for (int b = 0; b < num_beats; b++) begin
            tb_axi_wdata  <= cpu_burst_wbuf[b];
            tb_axi_wstrb  <= 4'hF;
            tb_axi_wlast  <= (b == (num_beats - 1));
            tb_axi_wvalid <= 1'b1;
            do @(posedge clk); while (!tb_axi_wready);
        end
        tb_axi_wvalid <= 1'b0;
        tb_axi_wlast  <= 1'b0;

        do @(posedge clk); while (!tb_axi_bvalid);
        if (tb_axi_bresp != 2'b00) begin
            $fatal(1, "[CPU AXI BURST WRITE ERR] BRESP=%0b at addr=0x%08x", tb_axi_bresp, start_addr);
        end
        tb_axi_bready <= 1'b0;
    endtask

    // Multi-Beat AXI4 Read Burst (Up to 256 words) over Crossbar Slave S0
    logic [31:0] cpu_burst_rbuf [0:255];
    task automatic cpu_axi_read_burst(input logic [31:0] start_addr, input int num_beats);
        if (num_beats <= 0 || num_beats > 256)
            $fatal(1, "Invalid burst length: %0d", num_beats);

        @(posedge clk);
        tb_axi_arid    <= 8'h20;
        tb_axi_araddr  <= start_addr;
        tb_axi_arlen   <= 8'(num_beats - 1);
        tb_axi_arsize  <= 3'd2;
        tb_axi_arburst <= 2'b01;
        tb_axi_arlock  <= 1'b0;
        tb_axi_arcache <= 4'd0;
        tb_axi_arprot  <= 3'd0;
        tb_axi_arvalid <= 1'b1;
        tb_axi_rready  <= 1'b1;

        do @(posedge clk); while (!tb_axi_arready);
        tb_axi_arvalid <= 1'b0;

        for (int b = 0; b < num_beats; b++) begin
            do @(posedge clk); while (!tb_axi_rvalid);
            cpu_burst_rbuf[b] = tb_axi_rdata;
            if (tb_axi_rresp != 2'b00) begin
                $fatal(1, "[CPU AXI BURST READ ERR] RRESP=%0b at addr=0x%08x", tb_axi_rresp, start_addr);
            end
            if ((b == (num_beats - 1)) && !tb_axi_rlast) begin
                $fatal(1, "[CPU AXI BURST READ ERR] Missing RLAST on final beat at addr=0x%08x", start_addr);
            end
        end
        tb_axi_rready <= 1'b0;
    endtask

    // CSR Access Helpers (Routed via Crossbar S0 -> M1 -> axi_axil_adapter)
    task automatic cpu_csr_write(input logic [31:0] reg_offset, input logic [31:0] data);
        cpu_axi_write_word(CTRL_BASE_ADDR + reg_offset, data);
    endtask

    task automatic cpu_csr_read(input logic [31:0] reg_offset, output logic [31:0] data);
        cpu_axi_read_word(CTRL_BASE_ADDR + reg_offset, data);
    endtask

    // =========================================================================
    // Randomized Shared-Bus Read/Write Traffic & Contention Engine (Slave S0)
    // =========================================================================
    logic [31:0] prng_state = 32'hC0DE_CAFE;
    logic [31:0] cpu_scratch_shadow [0:255];
    int          arb_stress_wr_txns   = 0;
    int          arb_stress_rd_txns   = 0;
    int          arb_stress_words_xfr = 0;

    function automatic logic [31:0] next_prng();
        logic [31:0] x;
        x = prng_state;
        x = x ^ (x << 13);
        x = x ^ (x >> 17);
        x = x ^ (x << 5);
        prng_state = x;
        return x;
    endfunction

    task automatic cpu_init_scratchpad_ram();
        for (int i = 0; i < 256; i++) begin
            cpu_scratch_shadow[i] = next_prng();
            cpu_burst_wbuf[i]     = cpu_scratch_shadow[i];
        end
        cpu_axi_write_burst(CPU_SCRATCH_BASE, 256);
    endtask

    // Multi-beat AXI4 write burst with random intra-burst WVALID and BREADY stalls
    // to hold the shared axi_interconnect write bus for random durations
    task automatic cpu_axi_write_burst_jitter(input logic [31:0] start_addr, input int num_beats);
        int stall_cycles;
        logic [31:0] rng;

        @(posedge clk);
        tb_axi_awid    <= 8'h11;
        tb_axi_awaddr  <= start_addr;
        tb_axi_awlen   <= 8'(num_beats - 1);
        tb_axi_awsize  <= 3'd2;
        tb_axi_awburst <= 2'b01;
        tb_axi_awlock  <= 1'b0;
        tb_axi_awcache <= 4'd0;
        tb_axi_awprot  <= 3'd0;
        tb_axi_awvalid <= 1'b1;
        tb_axi_bready  <= 1'b0;

        do @(posedge clk); while (!tb_axi_awready);
        tb_axi_awvalid <= 1'b0;

        for (int b = 0; b < num_beats; b++) begin
            rng = next_prng();
            stall_cycles = (rng[3:0] < 4'd4) ? int'(rng[5:4]) : 0;
            for (int s = 0; s < stall_cycles; s++) begin
                tb_axi_wvalid <= 1'b0;
                @(posedge clk);
            end
            tb_axi_wdata  <= cpu_burst_wbuf[b];
            tb_axi_wstrb  <= 4'hF;
            tb_axi_wlast  <= (b == (num_beats - 1));
            tb_axi_wvalid <= 1'b1;
            do @(posedge clk); while (!tb_axi_wready);
        end
        tb_axi_wvalid <= 1'b0;
        tb_axi_wlast  <= 1'b0;

        rng = next_prng();
        stall_cycles = int'(rng[1:0]);
        repeat (stall_cycles) @(posedge clk);
        tb_axi_bready <= 1'b1;

        do @(posedge clk); while (!tb_axi_bvalid);
        if (tb_axi_bresp != 2'b00) begin
            $fatal(1, "[CPU JITTER WRITE ERR] BRESP=%0b at addr=0x%08x", tb_axi_bresp, start_addr);
        end
        tb_axi_bready <= 1'b0;
    endtask

    // Multi-beat AXI4 read burst with random intra-burst RREADY stalls
    // to hold the shared axi_interconnect read bus for random durations
    task automatic cpu_axi_read_burst_jitter(input logic [31:0] start_addr, input int num_beats);
        int stall_cycles;
        logic [31:0] rng;

        @(posedge clk);
        tb_axi_arid    <= 8'h21;
        tb_axi_araddr  <= start_addr;
        tb_axi_arlen   <= 8'(num_beats - 1);
        tb_axi_arsize  <= 3'd2;
        tb_axi_arburst <= 2'b01;
        tb_axi_arlock  <= 1'b0;
        tb_axi_arcache <= 4'd0;
        tb_axi_arprot  <= 3'd0;
        tb_axi_arvalid <= 1'b1;
        tb_axi_rready  <= 1'b0;

        do @(posedge clk); while (!tb_axi_arready);
        tb_axi_arvalid <= 1'b0;

        for (int b = 0; b < num_beats; b++) begin
            rng = next_prng();
            stall_cycles = (rng[3:0] < 4'd4) ? int'(rng[5:4]) : 0;
            for (int s = 0; s < stall_cycles; s++) begin
                tb_axi_rready <= 1'b0;
                @(posedge clk);
            end
            tb_axi_rready <= 1'b1;
            do @(posedge clk); while (!tb_axi_rvalid);
            cpu_burst_rbuf[b] = tb_axi_rdata;
            if (tb_axi_rresp != 2'b00) begin
                $fatal(1, "[CPU JITTER READ ERR] RRESP=%0b at addr=0x%08x", tb_axi_rresp, start_addr);
            end
            if ((b == (num_beats - 1)) && !tb_axi_rlast) begin
                $fatal(1, "[CPU JITTER READ ERR] Missing RLAST on final beat at addr=0x%08x", start_addr);
            end
        end
        tb_axi_rready <= 1'b0;
    endtask

    // Wait for NPU completion while injecting randomized CPU S0 <-> M0 RAM read/write
    // operations over the shared bus to induce random AXI stalls and latency on S1
    task automatic cpu_wait_for_npu_done_with_bus_stress();
        logic [31:0] status_val;
        logic [31:0] rng;
        int          num_txns, burst_len, word_offset, idle_gap;
        bit          is_write;
        status_val = 32'd0;

        while (!status_val[1]) begin
            rng      = next_prng();
            num_txns = 1 + int'(rng[1:0]); // 1..4 random transactions per status poll

            for (int t = 0; t < num_txns; t++) begin
                rng         = next_prng();
                is_write    = rng[0];
                burst_len   = 1 + int'(rng[4:1]); // 1..16 beats per burst
                word_offset = int'(rng[12:5]) % (256 - burst_len + 1);
                idle_gap    = int'(rng[15:13]);   // 0..7 idle cycles between bursts

                repeat (idle_gap) @(posedge clk);

                if (is_write) begin
                    for (int i = 0; i < burst_len; i++) begin
                        logic [31:0] wval;
                        wval = next_prng();
                        cpu_scratch_shadow[word_offset + i] = wval;
                        cpu_burst_wbuf[i]                   = wval;
                    end
                    cpu_axi_write_burst_jitter(CPU_SCRATCH_BASE + (32'(word_offset) << 2), burst_len);
                    arb_stress_wr_txns++;
                end else begin
                    cpu_axi_read_burst_jitter(CPU_SCRATCH_BASE + (32'(word_offset) << 2), burst_len);
                    for (int i = 0; i < burst_len; i++) begin
                        if (cpu_burst_rbuf[i] !== cpu_scratch_shadow[word_offset + i]) begin
                            $fatal(1, "[SHARED BUS ARBITRATION CORRUPTION] Offset=%0d Beat=%0d | Exp: 0x%08x | Got: 0x%08x",
                                   word_offset, i, cpu_scratch_shadow[word_offset + i], cpu_burst_rbuf[i]);
                        end
                    end
                    arb_stress_rd_txns++;
                end
                arb_stress_words_xfr += burst_len;
            end

            // Poll NPU REG_STATUS via Shared Interconnect M1 (axi_axil_adapter)
            cpu_csr_read(REG_STATUS, status_val);
        end
    endtask

    // =========================================================================
    // Golden Reference Vectors for 5-Layer Chained Weird-Dimension Network
    // =========================================================================
    logic [7:0]                         mish_lut_mem [0:255];

    // Layer 1 (3x3 Conv, Mode A Linear): 52x76x5 -> 52x76x16 (2 Cout groups, 6 passes)
    logic signed [ACTIVATION_WIDTH-1:0] l1_in_act    [L1_H * L1_W * L1_CIN];
    logic signed [WEIGHT_WIDTH-1:0]     l1_w         [2 * 3 * 3 * L1_CIN * 8];
    logic signed [31:0]                 l1_b         [L1_COUT];
    logic [31:0]                        l1_cfg       [L1_COUT];
    logic signed [ACTIVATION_WIDTH-1:0] l1_gold_out  [L1_H * L1_W * L1_COUT];

    // Layer 2 (1x1 Conv, Mode B Mish LUT): 52x76x11 -> 52x76x8 (1 Cout group, 3 passes)
    logic signed [WEIGHT_WIDTH-1:0]     l2_w         [L2_CIN * 8];
    logic signed [31:0]                 l2_b         [L2_COUT];
    logic [31:0]                        l2_cfg       [L2_COUT];
    logic signed [ACTIVATION_WIDTH-1:0] l2_gold_out  [L2_H * L2_W * L2_COUT];

    // Layer 3 (3x3 Conv, Mode D Mish+Pool): 52x76x6 -> 26x38x16 (2 Cout groups, 7 passes)
    logic signed [WEIGHT_WIDTH-1:0]     l3_w         [2 * 3 * 3 * L3_CIN * 8];
    logic signed [31:0]                 l3_b         [L3_COUT];
    logic [31:0]                        l3_cfg       [L3_COUT];
    logic signed [ACTIVATION_WIDTH-1:0] l3_gold_out  [L3_OUT_H * L3_OUT_W * L3_COUT];

    // Layer 4 (1x1 Conv, Mode C Linear+Pool): 26x38x13 -> 13x19x8 (1 Cout group, 4 passes)
    logic signed [WEIGHT_WIDTH-1:0]     l4_w         [L4_CIN * 8];
    logic signed [31:0]                 l4_b         [L4_COUT];
    logic [31:0]                        l4_cfg       [L4_COUT];
    logic signed [ACTIVATION_WIDTH-1:0] l4_gold_out  [L4_OUT_H * L4_OUT_W * L4_COUT];

    // Layer 5 (3x3 Conv, Mode B Mish LUT): 13x19x7 -> 13x19x8 (1 Cout group, 8 passes)
    logic signed [WEIGHT_WIDTH-1:0]     l5_w         [3 * 3 * L5_CIN * 8];
    logic signed [31:0]                 l5_b         [L5_COUT];
    logic [31:0]                        l5_cfg       [L5_COUT];
    logic signed [ACTIVATION_WIDTH-1:0] l5_gold_out  [L5_H * L5_W * L5_COUT];

    function automatic int get_w_stride(input int w_dim);
        if      (w_dim <= 16)  return 16;
        else if (w_dim <= 32)  return 32;
        else if (w_dim <= 64)  return 64;
        else if (w_dim <= 128) return 128;
        else                   return 256;
    endfunction

    function automatic logic signed [7:0] get_3x3_weight_byte(
        input int layer_id,
        input int grp,
        input int p,
        input int r,
        input int c,
        input int cin_limit
    );
        int g_idx, cin_curr, tap_curr, ky_curr, kx_curr, idx;
        g_idx = p * 8 + r;
        if (g_idx < (cin_limit * 9)) begin
            cin_curr = g_idx / 9;
            tap_curr = g_idx % 9;
            ky_curr  = tap_curr / 3;
            kx_curr  = tap_curr % 3;
            idx      = grp * (9 * cin_limit * 8) +
                       ky_curr * (3 * cin_limit * 8) +
                       kx_curr * (cin_limit * 8) +
                       cin_curr * 8 + c;
            case (layer_id)
                1: return l1_w[idx];
                3: return l3_w[idx];
                default: return l5_w[idx];
            endcase
        end else begin
            return 8'sd0;
        end
    endfunction

    task automatic cpu_upload_3x3_weights(
        input int          layer_id,
        input logic [31:0] w_base,
        input int          cout_groups,
        input int          cin_dim,
        input int          num_passes
    );
        logic [7:0] b0, b1, b2, b3;
        for (int g = 0; g < cout_groups; g++) begin
            for (int p = 0; p < num_passes; p++) begin
                for (int b = 0; b < 8; b++) begin
                    int col;
                    col = 7 - b;
                    b0 = get_3x3_weight_byte(layer_id, g, p, 0, col, cin_dim);
                    b1 = get_3x3_weight_byte(layer_id, g, p, 1, col, cin_dim);
                    b2 = get_3x3_weight_byte(layer_id, g, p, 2, col, cin_dim);
                    b3 = get_3x3_weight_byte(layer_id, g, p, 3, col, cin_dim);
                    cpu_burst_wbuf[b] = {b3, b2, b1, b0};

                    b0 = get_3x3_weight_byte(layer_id, g, p, 4, col, cin_dim);
                    b1 = get_3x3_weight_byte(layer_id, g, p, 5, col, cin_dim);
                    b2 = get_3x3_weight_byte(layer_id, g, p, 6, col, cin_dim);
                    b3 = get_3x3_weight_byte(layer_id, g, p, 7, col, cin_dim);
                    cpu_burst_wbuf[8 + b] = {b3, b2, b1, b0};
                end
                cpu_axi_write_burst(w_base + (g * num_passes + p) * 64, 16);
            end
        end
    endtask

    task automatic cpu_upload_1x1_weights(
        input int          layer_id,
        input logic [31:0] w_base,
        input int          cin_dim,
        input int          num_passes
    );
        logic [7:0] b0, b1, b2, b3;
        for (int p = 0; p < num_passes; p++) begin
            for (int b = 0; b < 8; b++) begin
                int col;
                col = 7 - b;
                if (layer_id == 2) begin
                    b0 = ((p * 4 + 0) < cin_dim) ? l2_w[(p * 4 + 0) * 8 + col] : 8'h55;
                    b1 = ((p * 4 + 1) < cin_dim) ? l2_w[(p * 4 + 1) * 8 + col] : 8'h55;
                    b2 = ((p * 4 + 2) < cin_dim) ? l2_w[(p * 4 + 2) * 8 + col] : 8'h55;
                    b3 = ((p * 4 + 3) < cin_dim) ? l2_w[(p * 4 + 3) * 8 + col] : 8'h55;
                end else begin
                    b0 = ((p * 4 + 0) < cin_dim) ? l4_w[(p * 4 + 0) * 8 + col] : 8'h55;
                    b1 = ((p * 4 + 1) < cin_dim) ? l4_w[(p * 4 + 1) * 8 + col] : 8'h55;
                    b2 = ((p * 4 + 2) < cin_dim) ? l4_w[(p * 4 + 2) * 8 + col] : 8'h55;
                    b3 = ((p * 4 + 3) < cin_dim) ? l4_w[(p * 4 + 3) * 8 + col] : 8'h55;
                end
                cpu_burst_wbuf[b] = {b3, b2, b1, b0};
            end
            cpu_axi_write_burst(w_base + (p * 32), 8);
        end
    endtask

    // =========================================================================
    // Upload Initial Model Parameters & L1 Input Tensor via CPU AXI4 Master (S0)
    // =========================================================================
    task automatic cpu_upload_model_and_l1_input();
        int num_strips, w_stride;
        logic [31:0] byte_addr;
        logic [7:0] b0, b1, b2, b3;

        num_strips = (L1_H + 3) / 4; // 13 strips
        w_stride   = get_w_stride(L1_W); // 128 words (512 bytes/strip)

        // Upload L1 Input Activations (52x76x5) into ACT_BUF_A_BASE with power-of-two strip stride
        // Dead-spot padding words (gx = 76..127) are poisoned with 0xDEADBEEF to verify hardware burst clamping
        for (int c = 0; c < L1_CIN; c++) begin
            for (int strip = 0; strip < num_strips; strip++) begin
                for (int gx = 0; gx < w_stride; gx++) begin
                    if (gx < L1_W) begin
                        b0 = ((strip * 4 + 0) < L1_H) ? l1_in_act[((strip * 4 + 0) * L1_W * L1_CIN) + (gx * L1_CIN) + c] : 8'hAA;
                        b1 = ((strip * 4 + 1) < L1_H) ? l1_in_act[((strip * 4 + 1) * L1_W * L1_CIN) + (gx * L1_CIN) + c] : 8'hAA;
                        b2 = ((strip * 4 + 2) < L1_H) ? l1_in_act[((strip * 4 + 2) * L1_W * L1_CIN) + (gx * L1_CIN) + c] : 8'hAA;
                        b3 = ((strip * 4 + 3) < L1_H) ? l1_in_act[((strip * 4 + 3) * L1_W * L1_CIN) + (gx * L1_CIN) + c] : 8'hAA;
                        cpu_burst_wbuf[gx] = {b3, b2, b1, b0};
                    end else begin
                        cpu_burst_wbuf[gx] = 32'hDEAD_BEEF;
                    end
                end
                byte_addr = ACT_BUF_A_BASE + ((c * (num_strips * w_stride) + strip * w_stride) << 2);
                cpu_axi_write_burst(byte_addr, w_stride);
            end
        end

        // Upload Weights for all 5 layers into System RAM
        cpu_upload_3x3_weights(1, L1_W_BASE, 2, L1_CIN, L1_PASSES);
        cpu_upload_1x1_weights(2, L2_W_BASE,    L2_CIN, L2_PASSES);
        cpu_upload_3x3_weights(3, L3_W_BASE, 2, L3_CIN, L3_PASSES);
        cpu_upload_1x1_weights(4, L4_W_BASE,    L4_CIN, L4_PASSES);
        cpu_upload_3x3_weights(5, L5_W_BASE, 1, L5_CIN, L5_PASSES);

        // Upload Biases & Quantizer Configs for all 5 layers
        for (int g = 0; g < 2; g++) begin
            for (int c = 0; c < 8; c++) cpu_burst_wbuf[c] = l1_b[g * 8 + c];
            cpu_axi_write_burst(L1_B_BASE + g * 32, 8);
            for (int c = 0; c < 8; c++) cpu_burst_wbuf[c] = l1_cfg[g * 8 + (7 - c)];
            cpu_axi_write_burst(L1_Q_BASE + g * 32, 8);

            for (int c = 0; c < 8; c++) cpu_burst_wbuf[c] = l3_b[g * 8 + c];
            cpu_axi_write_burst(L3_B_BASE + g * 32, 8);
            for (int c = 0; c < 8; c++) cpu_burst_wbuf[c] = l3_cfg[g * 8 + (7 - c)];
            cpu_axi_write_burst(L3_Q_BASE + g * 32, 8);
        end

        for (int c = 0; c < 8; c++) cpu_burst_wbuf[c] = l2_b[c];
        cpu_axi_write_burst(L2_B_BASE, 8);
        for (int c = 0; c < 8; c++) cpu_burst_wbuf[c] = l2_cfg[7 - c];
        cpu_axi_write_burst(L2_Q_BASE, 8);

        for (int c = 0; c < 8; c++) cpu_burst_wbuf[c] = l4_b[c];
        cpu_axi_write_burst(L4_B_BASE, 8);
        for (int c = 0; c < 8; c++) cpu_burst_wbuf[c] = l4_cfg[7 - c];
        cpu_axi_write_burst(L4_Q_BASE, 8);

        for (int c = 0; c < 8; c++) cpu_burst_wbuf[c] = l5_b[c];
        cpu_axi_write_burst(L5_B_BASE, 8);
        for (int c = 0; c < 8; c++) cpu_burst_wbuf[c] = l5_cfg[7 - c];
        cpu_axi_write_burst(L5_Q_BASE, 8);

        // Upload Mish LUT (64 words = 256 bytes)
        for (int w = 0; w < 64; w++) begin
            cpu_burst_wbuf[w] = {
                mish_lut_mem[w * 4 + 3],
                mish_lut_mem[w * 4 + 2],
                mish_lut_mem[w * 4 + 1],
                mish_lut_mem[w * 4 + 0]
            };
        end
        cpu_axi_write_burst(LUT_BASE_ADDR, 64);
    endtask

    // Fetch a full output tensor [cout_dim][ceil(H/4)][W_stride][4] from System RAM over S0 AXI4
    localparam int MAX_OUT_WORDS = 16 * ((L1_H + 3) / 4) * 128;
    logic [31:0] cpu_fetched_strip_words [0:MAX_OUT_WORDS-1];

    task automatic cpu_fetch_output_tensor_from_ram(
        input logic [31:0] base_addr,
        input int          h_dim,
        input int          w_dim,
        input int          cout_dim
    );
        int num_strips, w_stride, word_idx;
        logic [31:0] strip_addr;

        num_strips = (h_dim + 3) / 4;
        w_stride   = get_w_stride(w_dim);
        for (int c = 0; c < cout_dim; c++) begin
            for (int s = 0; s < num_strips; s++) begin
                strip_addr = base_addr + ((c * num_strips * w_stride + s * w_stride) << 2);
                cpu_axi_read_burst(strip_addr, w_dim);
                for (int gx = 0; gx < w_dim; gx++) begin
                    word_idx = c * (num_strips * w_stride) + s * w_stride + gx;
                    cpu_fetched_strip_words[word_idx] = cpu_burst_rbuf[gx];
                end
            end
        end
    endtask

    function automatic logic signed [7:0] get_fetched_strip_byte(
        input int h_dim,
        input int w_dim,
        input int c,
        input int gy,
        input int gx
    );
        int num_strips, w_stride, strip_idx, r_sub, word_idx;
        logic [31:0] w_val;
        num_strips = (h_dim + 3) / 4;
        w_stride   = get_w_stride(w_dim);
        strip_idx  = gy / 4;
        r_sub      = gy % 4;
        word_idx   = c * (num_strips * w_stride) + strip_idx * w_stride + gx;
        w_val      = cpu_fetched_strip_words[word_idx];
        case (r_sub)
            0: return $signed(w_val[7:0]);
            1: return $signed(w_val[15:8]);
            2: return $signed(w_val[23:16]);
            3: return $signed(w_val[31:24]);
        endcase
    endfunction

    // Execute a single CNN layer across all tiles and Cout groups with concurrent random bus traffic
    task automatic execute_cnn_layer(
        input string       layer_name,
        input logic [31:0] act_base,
        input logic [31:0] out_base,
        input logic [31:0] w_base,
        input logic [31:0] b_base,
        input logic [31:0] q_base,
        input int          h_in,
        input int          w_in,
        input int          cin_dim,
        input int          cout_groups,
        input int          num_passes,
        input logic [7:0]  cfg_flags
    );
        int tiles_y, tiles_x, h_out, w_out, num_strips_out, w_stride_out, grp_out_bytes, w_pass_bytes;
        bit is_pool, is_1x1;
        logic [31:0] irq_reg;

        tiles_y        = (h_in + 15) / 16;
        tiles_x        = (w_in + 15) / 16;
        is_1x1         = cfg_flags[4];
        is_pool        = cfg_flags[6];
        h_out          = is_pool ? (h_in / 2) : h_in;
        w_out          = is_pool ? (w_in / 2) : w_in;
        num_strips_out = (h_out + 3) / 4;
        w_stride_out   = get_w_stride(w_out);
        grp_out_bytes  = 8 * num_strips_out * w_stride_out * 4;
        w_pass_bytes   = is_1x1 ? 32 : 64;

        cpu_csr_write(REG_ACT_BASE, act_base);
        cpu_csr_write(REG_LUT_BASE, LUT_BASE_ADDR);
        cpu_csr_write(REG_CONFIG,   {16'd0, 8'(num_passes), cfg_flags});

        for (int g = 0; g < cout_groups; g++) begin
            cpu_csr_write(REG_WEIGHT_BASE, w_base   + g * (num_passes * w_pass_bytes));
            cpu_csr_write(REG_BIAS_BASE,   b_base   + g * 32);
            cpu_csr_write(REG_QUANT_BASE,  q_base   + g * 32);
            cpu_csr_write(REG_OUT_BASE,    out_base + g * grp_out_bytes);

            for (int ty = 0; ty < tiles_y; ty++) begin
                for (int tx = 0; tx < tiles_x; tx++) begin
                    cpu_csr_write(REG_GEOM, {8'(cin_dim), 8'(h_in), 8'(w_in), 4'(ty), 4'(tx)});
                    cpu_csr_write(REG_CTRL, 32'h0000_0001); // START (Compute + Auto-Drain)
                    cpu_wait_for_npu_done_with_bus_stress();

                    cpu_csr_read(REG_IRQ_STATUS, irq_reg);
                    if (!irq_reg[0])
                        $fatal(1, "IRQ_STATUS not set on %s Group %0d Tile (%0d,%0d)!", layer_name, g, ty, tx);
                    cpu_csr_write(REG_IRQ_STATUS, 32'h0000_0001);
                end
            end
            $display("  -> %s Group %0d/%0d (%0dx%0d tiles) complete | Bus Stress: %0d WR, %0d RD bursts (%0d words)",
                     layer_name, g + 1, cout_groups, tiles_y, tiles_x,
                     arb_stress_wr_txns, arb_stress_rd_txns, arb_stress_words_xfr);
        end
    endtask

    task automatic verify_layer_output(
        input int          layer_id,
        input string       layer_name,
        input logic [31:0] out_base,
        input int          h_out,
        input int          w_out,
        input int          cout_dim,
        output int         err_cnt
    );
        int exact_cnt, tol_cnt, total_elems;
        cpu_fetch_output_tensor_from_ram(out_base, h_out, w_out, cout_dim);
        err_cnt     = 0;
        tol_cnt     = 0;
        exact_cnt   = 0;
        total_elems = h_out * w_out * cout_dim;

        for (int y = 0; y < h_out; y++) begin
            for (int x = 0; x < w_out; x++) begin
                for (int c = 0; c < cout_dim; c++) begin
                    int flat_idx, diff_v;
                    logic signed [7:0] exp_v, got_v;
                    flat_idx = (y * w_out * cout_dim) + (x * cout_dim) + c;
                    case (layer_id)
                        1: exp_v = l1_gold_out[flat_idx];
                        2: exp_v = l2_gold_out[flat_idx];
                        3: exp_v = l3_gold_out[flat_idx];
                        4: exp_v = l4_gold_out[flat_idx];
                        default: exp_v = l5_gold_out[flat_idx];
                    endcase
                    got_v  = get_fetched_strip_byte(h_out, w_out, c, y, x);
                    diff_v = (got_v > exp_v) ? (got_v - exp_v) : (exp_v - got_v);
                    if (diff_v == 0) begin
                        exact_cnt++;
                    end else if (diff_v <= 1) begin
                        tol_cnt++;
                    end else begin
                        if (err_cnt < 5)
                            $display("     [ERR %s] Y=%0d X=%0d C=%0d | Exp: %0d | Got: %0d",
                                     layer_name, y, x, c, exp_v, got_v);
                        err_cnt++;
                    end
                end
            end
        end

        $display("  -> [%s] %s (%0dx%0dx%0d): %0d/%0d matches (exact: %0d, tol: %0d, err: %0d)",
                 (err_cnt == 0) ? "PASS" : "FAIL",
                 layer_name, h_out, w_out, cout_dim,
                 exact_cnt + tol_cnt, total_elems, exact_cnt, tol_cnt, err_cnt);
        if (err_cnt != 0)
            $fatal(1, "%s Verification FAILED with %0d errors!", layer_name, err_cnt);
    endtask

    task automatic resolve_mem_dir(input string sample_file, output string mem_dir);
        int fd;
        int found;
        found = 0;

        if ($value$plusargs("MEM_DIR=%s", mem_dir)) begin
            if (mem_dir.len() > 0 && mem_dir[mem_dir.len()-1] != "/" && mem_dir[mem_dir.len()-1] != "\\")
                mem_dir = $sformatf("%s/", mem_dir);
            fd = $fopen($sformatf("%s%s", mem_dir, sample_file), "r");
            if (fd != 0) begin $fclose(fd); found = 1; end
        end

        if (!found) begin
            mem_dir = "TEST/GoldenReference/";
            fd = $fopen($sformatf("%s%s", mem_dir, sample_file), "r");
            if (fd != 0) begin $fclose(fd); found = 1; end
        end

        if (!found) begin
            $fatal(1, "Required test vector file '%s' was NOT found!", sample_file);
        end
    endtask

    // Watchdog timer
    initial begin
        #300_000_000;
        $display("\n[ERROR] Simulation Watchdog Timeout in 5-Layer Chained Stress Test!");
        $finish;
    end

    // =========================================================================
    // Main 5-Layer Chained Execution & Verification Sequence
    // =========================================================================
    initial begin
        string mem_dir;
        int err_l1, err_l2, err_l3, err_l4, err_l5;

        $display("\n=========================================================================================");
        $display("   CrocoScale SoC — 5-LAYER CHAINED WEIRD-DIM CNN + RANDOM SHARED-BUS STRESS SUITE       ");
        $display("=========================================================================================");

        resolve_mem_dir("stress_l1_in_act.mem", mem_dir);
        $display("[INFO] Resolved memory directory: '%s'", mem_dir);

        $readmemh({mem_dir, "stress_lut_mish.mem"},  mish_lut_mem);

        $readmemh({mem_dir, "stress_l1_in_act.mem"}, l1_in_act);
        $readmemh({mem_dir, "stress_l1_w.mem"},      l1_w);
        $readmemh({mem_dir, "stress_l1_b.mem"},      l1_b);
        $readmemh({mem_dir, "stress_l1_cfg.mem"},    l1_cfg);
        $readmemh({mem_dir, "stress_l1_out.mem"},    l1_gold_out);

        $readmemh({mem_dir, "stress_l2_w.mem"},      l2_w);
        $readmemh({mem_dir, "stress_l2_b.mem"},      l2_b);
        $readmemh({mem_dir, "stress_l2_cfg.mem"},    l2_cfg);
        $readmemh({mem_dir, "stress_l2_out.mem"},    l2_gold_out);

        $readmemh({mem_dir, "stress_l3_w.mem"},      l3_w);
        $readmemh({mem_dir, "stress_l3_b.mem"},      l3_b);
        $readmemh({mem_dir, "stress_l3_cfg.mem"},    l3_cfg);
        $readmemh({mem_dir, "stress_l3_out.mem"},    l3_gold_out);

        $readmemh({mem_dir, "stress_l4_w.mem"},      l4_w);
        $readmemh({mem_dir, "stress_l4_b.mem"},      l4_b);
        $readmemh({mem_dir, "stress_l4_cfg.mem"},    l4_cfg);
        $readmemh({mem_dir, "stress_l4_out.mem"},    l4_gold_out);

        $readmemh({mem_dir, "stress_l5_w.mem"},      l5_w);
        $readmemh({mem_dir, "stress_l5_b.mem"},      l5_b);
        $readmemh({mem_dir, "stress_l5_cfg.mem"},    l5_cfg);
        $readmemh({mem_dir, "stress_l5_out.mem"},    l5_gold_out);

        // Initialize Emulated CPU AXI4 Master Signals (S0)
        rst_n          = 1'b0;
        #1;
        tb_axi_awid    = 8'd0;
        tb_axi_awaddr  = 32'd0;
        tb_axi_awlen   = 8'd0;
        tb_axi_awsize  = 3'd2;
        tb_axi_awburst = 2'b01;
        tb_axi_awlock  = 1'b0;
        tb_axi_awcache = 4'd0;
        tb_axi_awprot  = 3'd0;
        tb_axi_awvalid = 1'b0;
        tb_axi_wdata   = 32'd0;
        tb_axi_wstrb   = 4'd0;
        tb_axi_wlast   = 1'b0;
        tb_axi_wvalid  = 1'b0;
        tb_axi_bready  = 1'b0;
        tb_axi_arid    = 8'd0;
        tb_axi_araddr  = 32'd0;
        tb_axi_arlen   = 8'd0;
        tb_axi_arsize  = 3'd2;
        tb_axi_arburst = 2'b01;
        tb_axi_arlock  = 1'b0;
        tb_axi_arcache = 4'd0;
        tb_axi_arprot  = 3'd0;
        tb_axi_arvalid = 1'b0;
        tb_axi_rready  = 1'b0;

        repeat (10) @(negedge clk);
        rst_n = 1'b1;
        repeat (10) @(negedge clk);

        cpu_init_scratchpad_ram();

        $display("\n--- [INIT] Uploading L1 Input (52x76x5) & All 5 Layers' Weights/Biases/Quant/LUT via S0 ---");
        cpu_upload_model_and_l1_input();
        $display("  -> [OK] Model parameters & L1 input uploaded. Layers 1->2->3->4->5 will chain in RAM.");

        // ---------------------------------------------------------------------
        // LAYER 1: 3x3 Conv, Mode A (Linear) — 52x76x5 -> 52x76x16 (BUF_A -> BUF_B)
        // ---------------------------------------------------------------------
        $display("\n--- [LAYER 1] 3x3 Conv, Mode A Linear: 52x76x5 -> 52x76x16 (BUF_A -> BUF_B, 2 Groups, 6 Passes) ---");
        execute_cnn_layer("L1_3x3_Lin", ACT_BUF_A_BASE, ACT_BUF_B_BASE,
                          L1_W_BASE, L1_B_BASE, L1_Q_BASE,
                          L1_H, L1_W, L1_CIN, 2, L1_PASSES, 8'h01);
        verify_layer_output(1, "L1_3x3_Lin", ACT_BUF_B_BASE, L1_H, L1_W, L1_COUT, err_l1);

        // ---------------------------------------------------------------------
        // LAYER 2: 1x1 Conv, Mode B (Mish LUT) — 52x76x11 -> 52x76x8 (BUF_B -> BUF_A)
        // ---------------------------------------------------------------------
        $display("\n--- [LAYER 2] 1x1 Conv, Mode B Mish LUT: 52x76x11 -> 52x76x8 (BUF_B -> BUF_A, 1 Group, 3 Passes) ---");
        execute_cnn_layer("L2_1x1_Mish", ACT_BUF_B_BASE, ACT_BUF_A_BASE,
                          L2_W_BASE, L2_B_BASE, L2_Q_BASE,
                          L2_H, L2_W, L2_CIN, 1, L2_PASSES, 8'h31);
        verify_layer_output(2, "L2_1x1_Mish", ACT_BUF_A_BASE, L2_H, L2_W, L2_COUT, err_l2);

        // ---------------------------------------------------------------------
        // LAYER 3: 3x3 Conv, Mode D (Mish + 2x2 MaxPool) — 52x76x6 -> 26x38x16 (BUF_A -> BUF_B)
        // ---------------------------------------------------------------------
        $display("\n--- [LAYER 3] 3x3 Conv, Mode D Mish+Pool: 52x76x6 -> 26x38x16 (BUF_A -> BUF_B, 2 Groups, 7 Passes) ---");
        execute_cnn_layer("L3_3x3_MishPool", ACT_BUF_A_BASE, ACT_BUF_B_BASE,
                          L3_W_BASE, L3_B_BASE, L3_Q_BASE,
                          L3_H, L3_W, L3_CIN, 2, L3_PASSES, 8'h61);
        verify_layer_output(3, "L3_3x3_MishPool", ACT_BUF_B_BASE, L3_OUT_H, L3_OUT_W, L3_COUT, err_l3);

        // ---------------------------------------------------------------------
        // LAYER 4: 1x1 Conv, Mode C (Linear + 2x2 MaxPool) — 26x38x13 -> 13x19x8 (BUF_B -> BUF_A)
        // ---------------------------------------------------------------------
        $display("\n--- [LAYER 4] 1x1 Conv, Mode C Lin+Pool: 26x38x13 -> 13x19x8 (BUF_B -> BUF_A, 1 Group, 4 Passes) ---");
        execute_cnn_layer("L4_1x1_LinPool", ACT_BUF_B_BASE, ACT_BUF_A_BASE,
                          L4_W_BASE, L4_B_BASE, L4_Q_BASE,
                          L4_H, L4_W, L4_CIN, 1, L4_PASSES, 8'h51);
        verify_layer_output(4, "L4_1x1_LinPool", ACT_BUF_A_BASE, L4_OUT_H, L4_OUT_W, L4_COUT, err_l4);

        // ---------------------------------------------------------------------
        // LAYER 5: 3x3 Conv, Mode B (Mish LUT) — 13x19x7 -> 13x19x8 (BUF_A -> BUF_B)
        // ---------------------------------------------------------------------
        $display("\n--- [LAYER 5] 3x3 Conv, Mode B Mish LUT: 13x19x7 -> 13x19x8 (BUF_A -> BUF_B, 1 Group, 8 Passes) ---");
        execute_cnn_layer("L5_3x3_Mish", ACT_BUF_A_BASE, ACT_BUF_B_BASE,
                          L5_W_BASE, L5_B_BASE, L5_Q_BASE,
                          L5_H, L5_W, L5_CIN, 1, L5_PASSES, 8'h21);
        verify_layer_output(5, "L5_3x3_Mish", ACT_BUF_B_BASE, L5_H, L5_W, L5_COUT, err_l5);

        $display("\n  -> [PASS] Shared-Bus Random Stress Summary: %0d Write Bursts, %0d Read Bursts (%0d total 32-bit words verified with 0 errors)",
                 arb_stress_wr_txns, arb_stress_rd_txns, arb_stress_words_xfr);

        $display("\n=========================================================================================");
        if (err_l1 == 0 && err_l2 == 0 && err_l3 == 0 && err_l4 == 0 && err_l5 == 0) begin
            $display(" >>> ALL 5 CHAINED WEIRD-DIM LAYERS + RANDOM SHARED-BUS STRESS PASSED (100%%) <<< ");
            $display("=========================================================================================\n");
        end else begin
            $fatal(1, "5-Layer Chained Stress Verification FAILED!");
        end

        $finish;
    end

endmodule

