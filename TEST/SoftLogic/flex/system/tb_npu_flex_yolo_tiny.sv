// =============================================================================
// File: TEST/SoftLogic/flex/system/tb_npu_flex_yolo_tiny.sv
// Module: tb_npu_flex_yolo_tiny
// Project: CrocoScale SoC — Full Unpruned 9-Layer Tiny-YOLOv2 Object Detection Suite
//
// Description:
//   End-to-end 100% full, unpruned 9-layer Pascal VOC Tiny-YOLOv2 (20-class)
//   object detection testbench (Vivado xsim target) running on the full
//   efpga_subsystem_top (with eFPGA_top_flex_harness) over the shared SoC AXI4
//   interconnect and 32 MB System AXI4 RAM.
//
//   3-Step Image & Golden Reference Flow (TEST/GoldenReference/yolo_tiny/):
//     1. 1_prepare_image.py     : Resizes input_image.{png,jpg,bmp} -> input_416x416.rgb
//     2. 2_generate_yolo_mem.py : Generates all AXI4 .mem vectors + yolo_meta.mem
//     3. 3_render_detections.py : Renders bounding boxes & stats -> output_detections.png
//
//   Pretrained Weights & Architecture (9 Chained Layers in System RAM):
//     Official ONNX Model Zoo Pascal VOC Tiny-YOLOv2 (tinyyolov2-8.onnx, 20 classes)
//     with folded BatchNorm, LeakyReLU(0.1) LUT, Layer 6 2x2 stride-1 asymmetric
//     MaxPool (pool_s1_en=1), and full unpruned channel counts up to 1024:
//       - L1 (3x3 Conv + LeakyReLU + 2x2 s2 MaxPool): 416x416x3    -> 208x208x16   (676 tiles,   2 groups,    4 passes)
//       - L2 (3x3 Conv + LeakyReLU + 2x2 s2 MaxPool): 208x208x16   -> 104x104x32   (169 tiles,   4 groups,   18 passes)
//       - L3 (3x3 Conv + LeakyReLU + 2x2 s2 MaxPool): 104x104x32   ->  52x52x64    ( 49 tiles,   8 groups,   36 passes)
//       - L4 (3x3 Conv + LeakyReLU + 2x2 s2 MaxPool):  52x52x64    ->  26x26x128   ( 16 tiles,  16 groups,   72 passes)
//       - L5 (3x3 Conv + LeakyReLU + 2x2 s2 MaxPool):  26x26x128   ->  13x13x256   (  4 tiles,  32 groups,  144 passes)
//       - L6 (3x3 Conv + LeakyReLU + 2x2 s1 MaxPool):  13x13x256   ->  13x13x512   (  1 tile,   64 groups,  288 passes)
//       - L7 (3x3 Conv + LeakyReLU):                   13x13x512   ->  13x13x1024  (  1 tile,  128 groups,  576 passes)
//       - L8 (3x3 Conv + LeakyReLU):                   13x13x1024  ->  13x13x1024  (  1 tile,  128 groups, 1152 passes)
//       - L9 (1x1 Conv Linear Detection Head):         13x13x1024  ->  13x13x125   (  1 tile,   16 groups,  256 passes)
//
//   Execution & Verification:
//     - Only Layer 1's 416x416x3 input image and model parameters (15.12 MB) are
//       uploaded by the emulated CPU (Slave S0) via 256-beat AXI4 bursts before
//       inference starts.
//     - Layers 1..9 chain directly in System RAM by ping-ponging between
//       ACT_BUF_A_BASE (0x0000_0000) and ACT_BUF_B_BASE (0x0010_0000).
//     - After each layer, S0 reads back the output tensor over AXI4 and verifies
//       bit-exact agreement against the golden reference.
//     - After Layer 9, S0 writes yolo_l9_hw_out_axi.mem for post-processing and
//       decodes the 13x13x125 (5 anchors x 25 Pascal VOC attrs) detection grid.
// =============================================================================

`timescale 1ns / 1ps

module tb_npu_flex_yolo_tiny;

    // =========================================================================
    // Crossbar & 32 MB System RAM Parameters
    // =========================================================================
    localparam int S_COUNT      = 2; // S0: TB CPU Master | S1: eFPGA Subsystem DMA Master
    localparam int M_COUNT      = 3; // M0: System AXI RAM | M1: Global eFPGA Manager | M2: Slot 0 Control
    localparam int AXI_ID_WIDTH = 8;
    localparam int M_ID_WIDTH   = AXI_ID_WIDTH;
    parameter  int RAM_ADDR_W   = 25; // 32 MB System AXI RAM (0x0000_0000 .. 0x01FF_FFFF)
    localparam int WEIGHT_SPLIT = 8;  // 8-bit row-wise weight_shift_en matching efpga_subsystem_top

    localparam logic [31:0] RAM_BASE_ADDR  = 32'h0000_0000;
    localparam logic [31:0] MGR_BASE_ADDR  = 32'h1000_0000;
    localparam logic [31:0] CTRL_BASE_ADDR = 32'h2000_0000;

    localparam logic [M_COUNT*32-1:0] CROSSBAR_BASE_ADDRS  = {CTRL_BASE_ADDR, MGR_BASE_ADDR, RAM_BASE_ADDR};
    localparam logic [M_COUNT*32-1:0] CROSSBAR_ADDR_WIDTHS = {32'd16, 32'd16, 32'(RAM_ADDR_W)};

    // eFPGA Manager Slot 0 Register Offsets (Accessed by CPU at MGR_BASE_ADDR + MGR_*)
    localparam logic [31:0] MGR_SLOT0_CTRL   = 32'h0000_1004;
    localparam logic [31:0] MGR_SLOT0_STATUS = 32'h0000_1008;

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

    // System RAM Buffer Addresses (Byte Addresses inside 32 MB RAM)
    localparam logic [31:0] ACT_BUF_A_BASE   = 32'h0000_0000; // 1 MB Ping Buffer (L1 in, L2/L4/L6/L8 out)
    localparam logic [31:0] ACT_BUF_B_BASE   = 32'h0010_0000; // 1 MB Pong Buffer (L1/L3/L5/L7/L9 out)
    localparam logic [31:0] BIAS_BASE_ADDR   = 32'h0020_0000; // 3,184 words (12.4 KB)
    localparam logic [31:0] QUANT_BASE_ADDR  = 32'h0020_8000; // 3,184 words (12.4 KB)
    localparam logic [31:0] LUT_BASE_ADDR    = 32'h0021_0000; // 64 words (256 B LeakyReLU(0.1) LUT)
    localparam logic [31:0] WEIGHT_BASE_ADDR = 32'h0022_0000; // 3,964,672 words (15.12 MB)

    // Per-Layer Weight, Bias & Quantizer Byte Offsets (Full Unpruned Tiny-YOLOv2)
    localparam logic [31:0] L1_W_BASE = WEIGHT_BASE_ADDR + 32'h0000_0000;
    localparam logic [31:0] L2_W_BASE = WEIGHT_BASE_ADDR + 32'h0000_0200;
    localparam logic [31:0] L3_W_BASE = WEIGHT_BASE_ADDR + 32'h0000_1400;
    localparam logic [31:0] L4_W_BASE = WEIGHT_BASE_ADDR + 32'h0000_5C00;
    localparam logic [31:0] L5_W_BASE = WEIGHT_BASE_ADDR + 32'h0001_7C00;
    localparam logic [31:0] L6_W_BASE = WEIGHT_BASE_ADDR + 32'h0005_FC00;
    localparam logic [31:0] L7_W_BASE = WEIGHT_BASE_ADDR + 32'h0017_FC00;
    localparam logic [31:0] L8_W_BASE = WEIGHT_BASE_ADDR + 32'h005F_FC00;
    localparam logic [31:0] L9_W_BASE = WEIGHT_BASE_ADDR + 32'h00EF_FC00;

    localparam logic [31:0] L1_B_BASE = BIAS_BASE_ADDR   + 32'h0000_0000;
    localparam logic [31:0] L2_B_BASE = BIAS_BASE_ADDR   + 32'h0000_0040;
    localparam logic [31:0] L3_B_BASE = BIAS_BASE_ADDR   + 32'h0000_00C0;
    localparam logic [31:0] L4_B_BASE = BIAS_BASE_ADDR   + 32'h0000_01C0;
    localparam logic [31:0] L5_B_BASE = BIAS_BASE_ADDR   + 32'h0000_03C0;
    localparam logic [31:0] L6_B_BASE = BIAS_BASE_ADDR   + 32'h0000_07C0;
    localparam logic [31:0] L7_B_BASE = BIAS_BASE_ADDR   + 32'h0000_0FC0;
    localparam logic [31:0] L8_B_BASE = BIAS_BASE_ADDR   + 32'h0000_1FC0;
    localparam logic [31:0] L9_B_BASE = BIAS_BASE_ADDR   + 32'h0000_2FC0;

    localparam logic [31:0] L1_Q_BASE = QUANT_BASE_ADDR  + 32'h0000_0000;
    localparam logic [31:0] L2_Q_BASE = QUANT_BASE_ADDR  + 32'h0000_0040;
    localparam logic [31:0] L3_Q_BASE = QUANT_BASE_ADDR  + 32'h0000_00C0;
    localparam logic [31:0] L4_Q_BASE = QUANT_BASE_ADDR  + 32'h0000_01C0;
    localparam logic [31:0] L5_Q_BASE = QUANT_BASE_ADDR  + 32'h0000_03C0;
    localparam logic [31:0] L6_Q_BASE = QUANT_BASE_ADDR  + 32'h0000_07C0;
    localparam logic [31:0] L7_Q_BASE = QUANT_BASE_ADDR  + 32'h0000_0FC0;
    localparam logic [31:0] L8_Q_BASE = QUANT_BASE_ADDR  + 32'h0000_1FC0;
    localparam logic [31:0] L9_Q_BASE = QUANT_BASE_ADDR  + 32'h0000_2FC0;

    localparam int TOTAL_L1_IN_WORDS  = 159744;
    localparam int TOTAL_WEIGHT_WORDS = 3964672;
    localparam int TOTAL_BIAS_WORDS   = 3184;
    localparam int TOTAL_QUANT_WORDS  = 3184;
    localparam int TOTAL_LUT_WORDS    = 64;

    logic clk;
    logic rst_n;
    wire  rst = ~rst_n;

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // =========================================================================
    // Crossbar Slave Signals (S0: Emulated CPU, S1: eFPGA Subsystem DMA Master)
    // =========================================================================
    wire  [S_COUNT*AXI_ID_WIDTH-1:0] s_axi_awid;
    wire  [S_COUNT*32-1:0]           s_axi_awaddr;
    wire  [S_COUNT*8-1:0]            s_axi_awlen;
    wire  [S_COUNT*3-1:0]            s_axi_awsize;
    wire  [S_COUNT*2-1:0]            s_axi_awburst;
    wire  [S_COUNT-1:0]              s_axi_awlock;
    wire  [S_COUNT*4-1:0]            s_axi_awcache;
    wire  [S_COUNT*3-1:0]            s_axi_awprot;
    wire  [S_COUNT-1:0]              s_axi_awvalid;
    wire  [S_COUNT-1:0]              s_axi_awready;
    wire  [S_COUNT*32-1:0]           s_axi_wdata;
    wire  [S_COUNT*4-1:0]            s_axi_wstrb;
    wire  [S_COUNT-1:0]              s_axi_wlast;
    wire  [S_COUNT-1:0]              s_axi_wvalid;
    wire  [S_COUNT-1:0]              s_axi_wready;
    wire  [S_COUNT*AXI_ID_WIDTH-1:0] s_axi_bid;
    wire  [S_COUNT*2-1:0]            s_axi_bresp;
    wire  [S_COUNT-1:0]              s_axi_bvalid;
    wire  [S_COUNT-1:0]              s_axi_bready;
    wire  [S_COUNT*AXI_ID_WIDTH-1:0] s_axi_arid;
    wire  [S_COUNT*32-1:0]           s_axi_araddr;
    wire  [S_COUNT*8-1:0]            s_axi_arlen;
    wire  [S_COUNT*3-1:0]            s_axi_arsize;
    wire  [S_COUNT*2-1:0]            s_axi_arburst;
    wire  [S_COUNT-1:0]              s_axi_arlock;
    wire  [S_COUNT*4-1:0]            s_axi_arcache;
    wire  [S_COUNT*3-1:0]            s_axi_arprot;
    wire  [S_COUNT-1:0]              s_axi_arvalid;
    wire  [S_COUNT-1:0]              s_axi_arready;
    wire  [S_COUNT*AXI_ID_WIDTH-1:0] s_axi_rid;
    wire  [S_COUNT*32-1:0]           s_axi_rdata;
    wire  [S_COUNT*2-1:0]            s_axi_rresp;
    wire  [S_COUNT-1:0]              s_axi_rlast;
    wire  [S_COUNT-1:0]              s_axi_rvalid;
    wire  [S_COUNT-1:0]              s_axi_rready;

    // =========================================================================
    // Crossbar Master Signals (M0: System RAM, M1: Manager, M2: Slot 0 Control)
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
    // Emulated CPU Master Signals (Connected to Crossbar Slave S0)
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

    // =========================================================================
    // 1. Shared SoC AXI4 Interconnect (2 Slaves x 3 Masters)
    // =========================================================================
    axi_interconnect #(
        .S_COUNT    (S_COUNT),
        .M_COUNT    (M_COUNT),
        .DATA_WIDTH (32),
        .ADDR_WIDTH (32),
        .ID_WIDTH   (AXI_ID_WIDTH),
        .M_REGIONS  (1),
        .M_BASE_ADDR(CROSSBAR_BASE_ADDRS),
        .M_ADDR_WIDTH(CROSSBAR_ADDR_WIDTHS),
        .M_CONNECT_READ ({M_COUNT{{S_COUNT{1'b1}}}}),
        .M_CONNECT_WRITE({M_COUNT{{S_COUNT{1'b1}}}})
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
    // 2. Crossbar Master 0: System AXI4 RAM (32 MB @ 0x0000_0000)
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
    // 3. Crossbar Masters M1 & M2: AXI4-to-AXI4-Lite Bridges (Manager & Slot 0)
    // =========================================================================
    wire [31:0] axil_mgr_awaddr;
    wire [2:0]  axil_mgr_awprot;
    wire        axil_mgr_awvalid;
    wire        axil_mgr_awready;
    wire [31:0] axil_mgr_wdata;
    wire [3:0]  axil_mgr_wstrb;
    wire        axil_mgr_wvalid;
    wire        axil_mgr_wready;
    wire [1:0]  axil_mgr_bresp;
    wire        axil_mgr_bvalid;
    wire        axil_mgr_bready;
    wire [31:0] axil_mgr_araddr;
    wire [2:0]  axil_mgr_arprot;
    wire        axil_mgr_arvalid;
    wire        axil_mgr_arready;
    wire [31:0] axil_mgr_rdata;
    wire [1:0]  axil_mgr_rresp;
    wire        axil_mgr_rvalid;
    wire        axil_mgr_rready;

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
    ) u_mgr_bridge (
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
        .m_axil_awaddr (axil_mgr_awaddr),
        .m_axil_awprot (axil_mgr_awprot),
        .m_axil_awvalid(axil_mgr_awvalid),
        .m_axil_awready(axil_mgr_awready),
        .m_axil_wdata  (axil_mgr_wdata),
        .m_axil_wstrb  (axil_mgr_wstrb),
        .m_axil_wvalid (axil_mgr_wvalid),
        .m_axil_wready (axil_mgr_wready),
        .m_axil_bresp  (axil_mgr_bresp),
        .m_axil_bvalid (axil_mgr_bvalid),
        .m_axil_bready (axil_mgr_bready),
        .m_axil_araddr (axil_mgr_araddr),
        .m_axil_arprot (axil_mgr_arprot),
        .m_axil_arvalid(axil_mgr_arvalid),
        .m_axil_arready(axil_mgr_arready),
        .m_axil_rdata  (axil_mgr_rdata),
        .m_axil_rresp  (axil_mgr_rresp),
        .m_axil_rvalid (axil_mgr_rvalid),
        .m_axil_rready (axil_mgr_rready)
    );

    axi_axil_adapter #(
        .ADDR_WIDTH     (32),
        .AXI_DATA_WIDTH (32),
        .AXIL_DATA_WIDTH(32),
        .AXI_ID_WIDTH   (M_ID_WIDTH)
    ) u_ctrl_bridge (
        .clk           (clk),
        .rst           (rst),
        .s_axi_awid    (m_axi_awid   [2*M_ID_WIDTH +: M_ID_WIDTH]),
        .s_axi_awaddr  (m_axi_awaddr [2*32 +: 32]),
        .s_axi_awlen   (m_axi_awlen  [2*8 +: 8]),
        .s_axi_awsize  (m_axi_awsize [2*3 +: 3]),
        .s_axi_awburst (m_axi_awburst[2*2 +: 2]),
        .s_axi_awlock  (m_axi_awlock [2]),
        .s_axi_awcache (m_axi_awcache[2*4 +: 4]),
        .s_axi_awprot  (m_axi_awprot [2*3 +: 3]),
        .s_axi_awvalid (m_axi_awvalid[2]),
        .s_axi_awready (m_axi_awready[2]),
        .s_axi_wdata   (m_axi_wdata  [2*32 +: 32]),
        .s_axi_wstrb   (m_axi_wstrb  [2*4 +: 4]),
        .s_axi_wlast   (m_axi_wlast  [2]),
        .s_axi_wvalid  (m_axi_wvalid [2]),
        .s_axi_wready  (m_axi_wready [2]),
        .s_axi_bid     (m_axi_bid    [2*M_ID_WIDTH +: M_ID_WIDTH]),
        .s_axi_bresp   (m_axi_bresp  [2*2 +: 2]),
        .s_axi_bvalid  (m_axi_bvalid [2]),
        .s_axi_bready  (m_axi_bready [2]),
        .s_axi_arid    (m_axi_arid   [2*M_ID_WIDTH +: M_ID_WIDTH]),
        .s_axi_araddr  (m_axi_araddr [2*32 +: 32]),
        .s_axi_arlen   (m_axi_arlen  [2*8 +: 8]),
        .s_axi_arsize  (m_axi_arsize [2*3 +: 3]),
        .s_axi_arburst (m_axi_arburst[2*2 +: 2]),
        .s_axi_arlock  (m_axi_arlock [2]),
        .s_axi_arcache (m_axi_arcache[2*4 +: 4]),
        .s_axi_arprot  (m_axi_arprot [2*3 +: 3]),
        .s_axi_arvalid (m_axi_arvalid[2]),
        .s_axi_arready (m_axi_arready[2]),
        .s_axi_rid     (m_axi_rid    [2*M_ID_WIDTH +: M_ID_WIDTH]),
        .s_axi_rdata   (m_axi_rdata  [2*32 +: 32]),
        .s_axi_rresp   (m_axi_rresp  [2*2 +: 2]),
        .s_axi_rlast   (m_axi_rlast  [2]),
        .s_axi_rvalid  (m_axi_rvalid [2]),
        .s_axi_rready  (m_axi_rready [2]),
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
    // 4. Full eFPGA Subsystem Top (Connector + Manager + NPU + eFPGA_top Harness)
    // =========================================================================
    wire [3:0] soc_usr_irq;
    wire       soc_fault_irq;

    efpga_subsystem_top #(
        .NUM_SLOTS   (1),
        .AXI_ID_WIDTH(AXI_ID_WIDTH),
        .WEIGHT_SPLIT(WEIGHT_SPLIT)
    ) u_efpga_subsystem (
        .clk_i                   (clk),
        .rst_efpga_connector_n_i (rst_n),
        .rst_efpga_connector_i   (rst),
        .rst_efpga_fabric_n_i    (rst_n),
        .rst_efpga_slot_n_i      ({4{rst_n}}),
        .rst_efpga_npu_n_i       (rst_n),
        .s_axil_mgr_awaddr       (axil_mgr_awaddr),
        .s_axil_mgr_awprot       (axil_mgr_awprot),
        .s_axil_mgr_awvalid      (axil_mgr_awvalid),
        .s_axil_mgr_awready      (axil_mgr_awready),
        .s_axil_mgr_wdata        (axil_mgr_wdata),
        .s_axil_mgr_wstrb        (axil_mgr_wstrb),
        .s_axil_mgr_wvalid       (axil_mgr_wvalid),
        .s_axil_mgr_wready       (axil_mgr_wready),
        .s_axil_mgr_bresp        (axil_mgr_bresp),
        .s_axil_mgr_bvalid       (axil_mgr_bvalid),
        .s_axil_mgr_bready       (axil_mgr_bready),
        .s_axil_mgr_araddr       (axil_mgr_araddr),
        .s_axil_mgr_arprot       (axil_mgr_arprot),
        .s_axil_mgr_arvalid      (axil_mgr_arvalid),
        .s_axil_mgr_arready      (axil_mgr_arready),
        .s_axil_mgr_rdata        (axil_mgr_rdata),
        .s_axil_mgr_rresp        (axil_mgr_rresp),
        .s_axil_mgr_rvalid       (axil_mgr_rvalid),
        .s_axil_mgr_rready       (axil_mgr_rready),

        .s_axil_ctrl_awaddr      (axil_ctrl_awaddr),
        .s_axil_ctrl_awprot      (axil_ctrl_awprot),
        .s_axil_ctrl_awvalid     (axil_ctrl_awvalid),
        .s_axil_ctrl_awready     (axil_ctrl_awready),
        .s_axil_ctrl_wdata       (axil_ctrl_wdata),
        .s_axil_ctrl_wstrb       (axil_ctrl_wstrb),
        .s_axil_ctrl_wvalid      (axil_ctrl_wvalid),
        .s_axil_ctrl_wready      (axil_ctrl_wready),
        .s_axil_ctrl_bresp       (axil_ctrl_bresp),
        .s_axil_ctrl_bvalid      (axil_ctrl_bvalid),
        .s_axil_ctrl_bready      (axil_ctrl_bready),
        .s_axil_ctrl_araddr      (axil_ctrl_araddr),
        .s_axil_ctrl_arprot      (axil_ctrl_arprot),
        .s_axil_ctrl_arvalid     (axil_ctrl_arvalid),
        .s_axil_ctrl_arready     (axil_ctrl_arready),
        .s_axil_ctrl_rdata       (axil_ctrl_rdata),
        .s_axil_ctrl_rresp       (axil_ctrl_rresp),
        .s_axil_ctrl_rvalid      (axil_ctrl_rvalid),
        .s_axil_ctrl_rready      (axil_ctrl_rready),

        .m_axi_dma_awid          (s_axi_awid   [1*AXI_ID_WIDTH +: AXI_ID_WIDTH]),
        .m_axi_dma_awaddr        (s_axi_awaddr [1*32 +: 32]),
        .m_axi_dma_awlen         (s_axi_awlen  [1*8 +: 8]),
        .m_axi_dma_awsize        (s_axi_awsize [1*3 +: 3]),
        .m_axi_dma_awburst       (s_axi_awburst[1*2 +: 2]),
        .m_axi_dma_awlock        (s_axi_awlock [1]),
        .m_axi_dma_awcache       (s_axi_awcache[1*4 +: 4]),
        .m_axi_dma_awprot        (s_axi_awprot [1*3 +: 3]),
        .m_axi_dma_awvalid       (s_axi_awvalid[1]),
        .m_axi_dma_awready       (s_axi_awready[1]),
        .m_axi_dma_wdata         (s_axi_wdata  [1*32 +: 32]),
        .m_axi_dma_wstrb         (s_axi_wstrb  [1*4 +: 4]),
        .m_axi_dma_wlast         (s_axi_wlast  [1]),
        .m_axi_dma_wvalid        (s_axi_wvalid [1]),
        .m_axi_dma_wready        (s_axi_wready [1]),
        .m_axi_dma_bid           (s_axi_bid    [1*AXI_ID_WIDTH +: AXI_ID_WIDTH]),
        .m_axi_dma_bresp         (s_axi_bresp  [1*2 +: 2]),
        .m_axi_dma_bvalid        (s_axi_bvalid [1]),
        .m_axi_dma_bready        (s_axi_bready [1]),
        .m_axi_dma_arid          (s_axi_arid   [1*AXI_ID_WIDTH +: AXI_ID_WIDTH]),
        .m_axi_dma_araddr        (s_axi_araddr [1*32 +: 32]),
        .m_axi_dma_arlen         (s_axi_arlen  [1*8 +: 8]),
        .m_axi_dma_arsize        (s_axi_arsize [1*3 +: 3]),
        .m_axi_dma_arburst       (s_axi_arburst[1*2 +: 2]),
        .m_axi_dma_arlock        (s_axi_arlock [1]),
        .m_axi_dma_arcache       (s_axi_arcache[1*4 +: 4]),
        .m_axi_dma_arprot        (s_axi_arprot [1*3 +: 3]),
        .m_axi_dma_arvalid       (s_axi_arvalid[1]),
        .m_axi_dma_arready       (s_axi_arready[1]),
        .m_axi_dma_rid           (s_axi_rid    [1*AXI_ID_WIDTH +: AXI_ID_WIDTH]),
        .m_axi_dma_rdata         (s_axi_rdata  [1*32 +: 32]),
        .m_axi_dma_rresp         (s_axi_rresp  [1*2 +: 2]),
        .m_axi_dma_rlast         (s_axi_rlast  [1]),
        .m_axi_dma_rvalid        (s_axi_rvalid [1]),
        .m_axi_dma_rready        (s_axi_rready [1]),

        .pmod_io_i               (8'h00),
        .pmod_io_o               (),
        .pmod_io_oe_o            (),
        .efpga_cfg_sclk_i        (1'b0),
        .efpga_cfg_sdata_i       (1'b0),
        .efpga_usr_irq_o         (soc_usr_irq),
        .efpga_fault_irq_o       (soc_fault_irq)
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

    logic [31:0] cpu_burst_wbuf [0:255];
    task automatic cpu_axi_write_burst(input logic [31:0] start_addr, input int num_beats);
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

    logic [31:0] cpu_burst_rbuf [0:255];
    task automatic cpu_axi_read_burst(input logic [31:0] start_addr, input int num_beats);
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
        end
        tb_axi_rready <= 1'b0;
    endtask

    task automatic cpu_csr_write(input logic [31:0] reg_offset, input logic [31:0] data);
        cpu_axi_write_word(CTRL_BASE_ADDR + reg_offset, data);
    endtask

    task automatic cpu_csr_read(input logic [31:0] reg_offset, output logic [31:0] data);
        cpu_axi_read_word(CTRL_BASE_ADDR + reg_offset, data);
    endtask

    task automatic cpu_wait_for_npu_done();
        while (soc_usr_irq[0] !== 1'b1) begin
            @(posedge clk);
        end
    endtask

    // =========================================================================
    // Pre-Packed AXI4 Test Vectors & Golden Layer Outputs (Full 416x416 Model)
    // =========================================================================
    logic [31:0] yolo_l1_in_mem   [0:TOTAL_L1_IN_WORDS-1];
    logic [31:0] yolo_weights_mem [0:TOTAL_WEIGHT_WORDS-1];
    logic [31:0] yolo_bias_mem    [0:TOTAL_BIAS_WORDS-1];
    logic [31:0] yolo_quant_mem   [0:TOTAL_QUANT_WORDS-1];
    logic [31:0] yolo_lut_mem     [0:TOTAL_LUT_WORDS-1];
    logic [31:0] yolo_meta_mem    [0:4];

    logic [31:0] gold_l1_out [0:212992-1];
    logic [31:0] gold_l2_out [0:106496-1];
    logic [31:0] gold_l3_out [0:53248-1];
    logic [31:0] gold_l4_out [0:28672-1];
    logic [31:0] gold_l5_out [0:16384-1];
    logic [31:0] gold_l6_out [0:32768-1];
    logic [31:0] gold_l7_out [0:65536-1];
    logic [31:0] gold_l8_out [0:65536-1];
    logic [31:0] gold_l9_out [0:8192-1];

    function automatic int get_w_stride(input int w_dim);
        if      (w_dim <= 16)  return 16;
        else if (w_dim <= 32)  return 32;
        else if (w_dim <= 64)  return 64;
        else if (w_dim <= 128) return 128;
        else if (w_dim <= 256) return 256;
        else                   return 512;
    endfunction

    // Stream all model parameters and the L1 416x416x3 input image into System RAM via S0 256-beat AXI4 bursts
    task automatic cpu_upload_yolo_model_and_image();
        int idx, chunk;

        // Upload L1 Input Image (159,744 words = 624 KB) into ACT_BUF_A_BASE
        idx = 0;
        while (idx < TOTAL_L1_IN_WORDS) begin
            chunk = ((TOTAL_L1_IN_WORDS - idx) >= 256) ? 256 : (TOTAL_L1_IN_WORDS - idx);
            for (int b = 0; b < chunk; b++) cpu_burst_wbuf[b] = yolo_l1_in_mem[idx + b];
            cpu_axi_write_burst(ACT_BUF_A_BASE + (idx << 2), chunk);
            idx += chunk;
        end

        // Upload LeakyReLU(0.1) LUT (64 words = 256 B) into LUT_BASE_ADDR
        for (int b = 0; b < TOTAL_LUT_WORDS; b++) cpu_burst_wbuf[b] = yolo_lut_mem[b];
        cpu_axi_write_burst(LUT_BASE_ADDR, TOTAL_LUT_WORDS);

        // Upload All 9 Layers' Biases (3,184 words) into BIAS_BASE_ADDR
        idx = 0;
        while (idx < TOTAL_BIAS_WORDS) begin
            chunk = ((TOTAL_BIAS_WORDS - idx) >= 256) ? 256 : (TOTAL_BIAS_WORDS - idx);
            for (int b = 0; b < chunk; b++) cpu_burst_wbuf[b] = yolo_bias_mem[idx + b];
            cpu_axi_write_burst(BIAS_BASE_ADDR + (idx << 2), chunk);
            idx += chunk;
        end

        // Upload All 9 Layers' Quantizer Configs (3,184 words) into QUANT_BASE_ADDR
        idx = 0;
        while (idx < TOTAL_QUANT_WORDS) begin
            chunk = ((TOTAL_QUANT_WORDS - idx) >= 256) ? 256 : (TOTAL_QUANT_WORDS - idx);
            for (int b = 0; b < chunk; b++) cpu_burst_wbuf[b] = yolo_quant_mem[idx + b];
            cpu_axi_write_burst(QUANT_BASE_ADDR + (idx << 2), chunk);
            idx += chunk;
        end

        // Upload All 9 Layers' Weights (3,964,672 words = 15.12 MB) into WEIGHT_BASE_ADDR
        idx = 0;
        while (idx < TOTAL_WEIGHT_WORDS) begin
            chunk = ((TOTAL_WEIGHT_WORDS - idx) >= 256) ? 256 : (TOTAL_WEIGHT_WORDS - idx);
            for (int b = 0; b < chunk; b++) cpu_burst_wbuf[b] = yolo_weights_mem[idx + b];
            cpu_axi_write_burst(WEIGHT_BASE_ADDR + (idx << 2), chunk);
            idx += chunk;
        end
    endtask

    // Execute a single Tiny-YOLOv2 layer across all spatial tiles and Cout groups
    task automatic execute_yolo_layer(
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
        bit is_pool_s2, is_1x1;
        logic [10:0] cin_11b, passes_11b;
        logic [8:0]  h_9b, w_9b;
        logic [4:0]  ty_5b, tx_5b;

        tiles_y        = (h_in + 15) / 16;
        tiles_x        = (w_in + 15) / 16;
        is_1x1         = cfg_flags[4];
        is_pool_s2     = cfg_flags[6];
        h_out          = is_pool_s2 ? (h_in / 2) : h_in;
        w_out          = is_pool_s2 ? (w_in / 2) : w_in;
        num_strips_out = (h_out + 3) / 4;
        w_stride_out   = get_w_stride(w_out);
        grp_out_bytes  = 8 * num_strips_out * w_stride_out * 4;
        w_pass_bytes   = is_1x1 ? 32 : 64;
        cin_11b        = 11'(cin_dim);
        passes_11b     = 11'(num_passes);
        h_9b           = 9'(h_in);
        w_9b           = 9'(w_in);

        cpu_csr_write(REG_ACT_BASE, act_base);
        cpu_csr_write(REG_LUT_BASE, LUT_BASE_ADDR);

        for (int g = 0; g < cout_groups; g++) begin
            cpu_csr_write(REG_WEIGHT_BASE, w_base   + g * (num_passes * w_pass_bytes));
            cpu_csr_write(REG_BIAS_BASE,   b_base   + g * 32);
            cpu_csr_write(REG_QUANT_BASE,  q_base   + g * 32);
            cpu_csr_write(REG_OUT_BASE,    out_base + g * grp_out_bytes);

            for (int ty = 0; ty < tiles_y; ty++) begin
                for (int tx = 0; tx < tiles_x; tx++) begin
                    ty_5b = 5'(ty);
                    tx_5b = 5'(tx);
                    // REG_CONFIG: [30]=img_h[8], [29]=img_w[8], [28]=tile_y[4], [27]=tile_x[4],
                    //             [26:24]=cfg_cin[10:8], [18:8]=total_passes[10:0], [7:0]=cfg_flags
                    cpu_csr_write(REG_CONFIG, {1'b0, h_9b[8], w_9b[8], ty_5b[4], tx_5b[4], cin_11b[10:8], 5'd0, passes_11b, cfg_flags});
                    cpu_csr_write(REG_GEOM,   {cin_11b[7:0], h_9b[7:0], w_9b[7:0], ty_5b[3:0], tx_5b[3:0]});
                    cpu_csr_write(REG_CTRL,   32'h0000_0001); // START (Compute + Auto-Drain)
                    cpu_wait_for_npu_done();
                    cpu_csr_write(REG_IRQ_STATUS, 32'h0000_0001);
                end
            end
        end
        $display("  -> [DONE] %s (%0dx%0dx%0d -> %0dx%0dx%0d | %0d groups x %0dx%0d tiles x %0d passes)",
                 layer_name, h_in, w_in, cin_dim, h_out, w_out, cout_groups * 8,
                 cout_groups, tiles_y, tiles_x, num_passes);
    endtask

    // Read back layer output strips over S0 AXI4 and verify against golden reference
    logic [31:0] l9_hw_out_words [0:8192-1];

    task automatic verify_yolo_layer_output(
        input int          layer_id,
        input string       layer_name,
        input logic [31:0] out_base,
        input int          h_out,
        input int          w_out,
        input int          cout_pad,
        output int         err_cnt
    );
        int num_strips, w_stride, word_idx, exact_cnt, total_checked;
        logic [31:0] strip_addr, exp_word, got_word;

        num_strips    = (h_out + 3) / 4;
        w_stride      = get_w_stride(w_out);
        err_cnt       = 0;
        exact_cnt     = 0;
        total_checked = 0;

        for (int c = 0; c < cout_pad; c++) begin
            for (int s = 0; s < num_strips; s++) begin
                strip_addr = out_base + ((c * num_strips * w_stride + s * w_stride) << 2);
                cpu_axi_read_burst(strip_addr, w_out);
                for (int gx = 0; gx < w_out; gx++) begin
                    word_idx = c * (num_strips * w_stride) + s * w_stride + gx;
                    got_word = cpu_burst_rbuf[gx];
                    if (layer_id == 9) begin
                        l9_hw_out_words[word_idx] = got_word;
                    end
                    case (layer_id)
                        1: exp_word = gold_l1_out[word_idx];
                        2: exp_word = gold_l2_out[word_idx];
                        3: exp_word = gold_l3_out[word_idx];
                        4: exp_word = gold_l4_out[word_idx];
                        5: exp_word = gold_l5_out[word_idx];
                        6: exp_word = gold_l6_out[word_idx];
                        7: exp_word = gold_l7_out[word_idx];
                        8: exp_word = gold_l8_out[word_idx];
                        default: exp_word = gold_l9_out[word_idx];
                    endcase

                    for (int r_sub = 0; r_sub < 4; r_sub++) begin
                        if ((s * 4 + r_sub) < h_out) begin
                            logic signed [7:0] got_b, exp_b;
                            got_b = $signed(got_word[r_sub*8 +: 8]);
                            exp_b = $signed(exp_word[r_sub*8 +: 8]);
                            total_checked++;
                            if (got_b === exp_b) begin
                                exact_cnt++;
                            end else begin
                                if (err_cnt < 5)
                                    $display("     [ERR %s] C=%0d Y=%0d X=%0d | Exp: %0d | Got: %0d",
                                             layer_name, c, s * 4 + r_sub, gx, exp_b, got_b);
                                err_cnt++;
                            end
                        end
                    end
                end
            end
        end

        $display("  -> [%s] %s Verification: %0d/%0d bit-exact INT8 values matched (errors: %0d)",
                 (err_cnt == 0) ? "PASS" : "FAIL", layer_name, exact_cnt, total_checked, err_cnt);
        if (err_cnt != 0)
            $fatal(1, "%s Verification FAILED with %0d errors!", layer_name, err_cnt);
    endtask

    function automatic logic signed [7:0] get_l9_byte(input int c, input int gy, input int gx);
        int word_idx;
        logic [31:0] w_val;
        // For L9 (13x13x128): num_strips = 4, w_stride = 16 -> 64 words per channel
        word_idx = c * 64 + (gy / 4) * 16 + gx;
        w_val    = l9_hw_out_words[word_idx];
        case (gy % 4)
            0: return $signed(w_val[7:0]);
            1: return $signed(w_val[15:8]);
            2: return $signed(w_val[23:16]);
            default: return $signed(w_val[31:24]);
        endcase
    endfunction

    function automatic string get_voc_name(input int cls);
        case (cls)
            0:  return "aeroplane";
            1:  return "bicycle";
            2:  return "bird";
            3:  return "boat";
            4:  return "bottle";
            5:  return "bus";
            6:  return "car";
            7:  return "cat";
            8:  return "chair";
            9:  return "cow";
            10: return "diningtable";
            11: return "dog";
            12: return "horse";
            13: return "motorbike";
            14: return "person";
            15: return "pottedplant";
            16: return "sheep";
            17: return "sofa";
            18: return "train";
            default: return "tvmonitor";
        endcase
    endfunction

    // Decode the 13x13x125 hardware output grid into Pascal VOC 20-class detections
    task automatic decode_and_verify_yolo_detections();
        real anchor_w [0:4];
        real anchor_h [0:4];
        real s_out;
        real cls_best_score [0:19];
        real best_score;
        int  best_cls, best_anchor, best_gy, best_gx;
        int  exp_top1_cls;
        int  used [0:19];
        logic signed [7:0] win_tx, win_ty, win_tw, win_th, win_obj;

        anchor_w[0]  = 1.08; anchor_w[1] = 3.42; anchor_w[2] = 6.63; anchor_w[3] = 9.42; anchor_w[4] = 16.62;
        anchor_h[0]  = 1.19; anchor_h[1] = 4.41; anchor_h[2] = 11.38; anchor_h[3] = 5.11; anchor_h[4] = 10.52;
        s_out        = (yolo_meta_mem[0] != 32'd0 && ^yolo_meta_mem[0] !== 1'bx) ?
                       (real'(yolo_meta_mem[0]) / 1000000.0) : 0.119910;
        exp_top1_cls = (^yolo_meta_mem[1] !== 1'bx) ? int'(yolo_meta_mem[1]) : 7;
        best_score   = -1.0;
        best_cls     = -1;
        for (int c = 0; c < 20; c++) begin
            cls_best_score[c] = 0.0;
            used[c] = 0;
        end

        for (int a = 0; a < 5; a++) begin
            for (int gy = 0; gy < 13; gy++) begin
                for (int gx = 0; gx < 13; gx++) begin
                    int base_ch;
                    logic signed [7:0] raw_obj;
                    real obj_prob, max_logit, sum_exp;
                    real logits [0:19];

                    base_ch   = a * 25;
                    raw_obj   = get_l9_byte(base_ch + 4, gy, gx);
                    obj_prob  = 1.0 / (1.0 + $exp(-real'(raw_obj) * s_out));
                    max_logit = -1000.0;

                    for (int c = 0; c < 20; c++) begin
                        logits[c] = real'(get_l9_byte(base_ch + 5 + c, gy, gx)) * s_out;
                        if (logits[c] > max_logit) max_logit = logits[c];
                    end

                    sum_exp = 0.0;
                    for (int c = 0; c < 20; c++) begin
                        sum_exp += $exp(logits[c] - max_logit);
                    end

                    for (int c = 0; c < 20; c++) begin
                        real prob, conf;
                        prob = $exp(logits[c] - max_logit) / sum_exp;
                        conf = obj_prob * prob;
                        if (conf > cls_best_score[c]) cls_best_score[c] = conf;
                        if (conf > best_score) begin
                            best_score  = conf;
                            best_cls    = c;
                            best_anchor = a;
                            best_gy     = gy;
                            best_gx     = gx;
                        end
                    end
                end
            end
        end

        win_tx  = get_l9_byte(best_anchor * 25 + 0, best_gy, best_gx);
        win_ty  = get_l9_byte(best_anchor * 25 + 1, best_gy, best_gx);
        win_tw  = get_l9_byte(best_anchor * 25 + 2, best_gy, best_gx);
        win_th  = get_l9_byte(best_anchor * 25 + 3, best_gy, best_gx);
        win_obj = get_l9_byte(best_anchor * 25 + 4, best_gy, best_gx);

        $display("\n=========================================================================================");
        $display("   CROCSCALE NPU — FULL TINY-YOLOv2 PASCAL VOC OBJECT DETECTION REPORT (416x416)         ");
        $display("=========================================================================================");
        $display("  Winning Grid Cell : (GridY=%0d, GridX=%0d), Anchor=%0d (%.2fx%.2f)",
                 best_gy, best_gx, best_anchor, anchor_w[best_anchor], anchor_h[best_anchor]);
        $display("  Raw INT8 BBox/Obj : tx=%0d, ty=%0d, tw=%0d, th=%0d, obj_logit=%0d",
                 win_tx, win_ty, win_tw, win_th, win_obj);
        $display("  Top-1 Prediction  : Class #%0d -> \"%s\" (Confidence = %.4f, Raw INT8 Logit = %0d)",
                 best_cls, get_voc_name(best_cls), best_score,
                 get_l9_byte(best_anchor * 25 + 5 + best_cls, best_gy, best_gx));
        $display("-----------------------------------------------------------------------------------------");
        $display("  Top-5 Pascal VOC Class Scores:");
        for (int rank = 1; rank <= 5; rank++) begin
            int top_c;
            real top_s;
            top_c = 0;
            top_s = -1.0;
            for (int c = 0; c < 20; c++) begin
                if (!used[c] && cls_best_score[c] > top_s) begin
                    top_s = cls_best_score[c];
                    top_c = c;
                end
            end
            used[top_c] = 1;
            $display("    #%0d: Class %2d (%-11s) | Confidence = %.4f | Raw INT8 Logit = %+4d",
                     rank, top_c, get_voc_name(top_c), top_s,
                     get_l9_byte(best_anchor * 25 + 5 + top_c, best_gy, best_gx));
        end
        $display("=========================================================================================");

        if (best_cls != exp_top1_cls) begin
            $fatal(1, "Tiny-YOLOv2 Detection FAILED: expected class #%0d ('%s'), got #%0d ('%s')!",
                   exp_top1_cls, get_voc_name(exp_top1_cls), best_cls, get_voc_name(best_cls));
        end
    endtask

    task automatic resolve_mem_dir(input string sample_file, output string mem_dir);
        int fd;
        int found;
        found = 0;

        if ($value$plusargs("MEM_DIR=%s", mem_dir)) begin
            if (mem_dir.len() > 0 && mem_dir[mem_dir.len()-1] != "/" && mem_dir[mem_dir.len()-1] != "\\")
                mem_dir = $sformatf("%s/", mem_dir);
            fd = $fopen($sformatf("%syolo_tiny/%s", mem_dir, sample_file), "r");
            if (fd != 0) begin
                $fclose(fd);
                mem_dir = $sformatf("%syolo_tiny/", mem_dir);
                found = 1;
            end
        end

        if (!found) begin
            mem_dir = "TEST/GoldenReference/yolo_tiny/";
            fd = $fopen($sformatf("%s%s", mem_dir, sample_file), "r");
            if (fd != 0) begin $fclose(fd); found = 1; end
        end

        if (!found) begin
            $fatal(1, "Required Tiny-YOLOv2 vector file '%s' was NOT found!", sample_file);
        end
    endtask

    // =========================================================================
    // Main 9-Layer Full Tiny-YOLOv2 Execution & Object Detection Sequence
    // =========================================================================
    initial begin
        string mem_dir;
        int err_l1, err_l2, err_l3, err_l4, err_l5, err_l6, err_l7, err_l8, err_l9;

        $display("\n=========================================================================================");
        $display("   CrocoScale SoC — FULL UNPRUNED 9-LAYER TINY-YOLOv2 (416x416) OBJECT DETECTION SUITE   ");
        $display("=========================================================================================");

        resolve_mem_dir("yolo_l1_in_axi.mem", mem_dir);
        $display("[INFO] Resolved Tiny-YOLOv2 vector directory: '%s'", mem_dir);

        $readmemh({mem_dir, "yolo_l1_in_axi.mem"},   yolo_l1_in_mem);
        $readmemh({mem_dir, "yolo_weights_axi.mem"}, yolo_weights_mem);
        $readmemh({mem_dir, "yolo_bias_axi.mem"},    yolo_bias_mem);
        $readmemh({mem_dir, "yolo_quant_axi.mem"},   yolo_quant_mem);
        $readmemh({mem_dir, "yolo_lut_axi.mem"},     yolo_lut_mem);
        $readmemh({mem_dir, "yolo_meta.mem"},        yolo_meta_mem);

        $readmemh({mem_dir, "yolo_l1_out_axi.mem"},  gold_l1_out);
        $readmemh({mem_dir, "yolo_l2_out_axi.mem"},  gold_l2_out);
        $readmemh({mem_dir, "yolo_l3_out_axi.mem"},  gold_l3_out);
        $readmemh({mem_dir, "yolo_l4_out_axi.mem"},  gold_l4_out);
        $readmemh({mem_dir, "yolo_l5_out_axi.mem"},  gold_l5_out);
        $readmemh({mem_dir, "yolo_l6_out_axi.mem"},  gold_l6_out);
        $readmemh({mem_dir, "yolo_l7_out_axi.mem"},  gold_l7_out);
        $readmemh({mem_dir, "yolo_l8_out_axi.mem"},  gold_l8_out);
        $readmemh({mem_dir, "yolo_l9_out_axi.mem"},  gold_l9_out);

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

        // Un-decouple Slot 0 & enable user IRQs via Global eFPGA Manager (M1 @ 0x1000_0000)
        cpu_axi_write_word(MGR_BASE_ADDR + MGR_SLOT0_CTRL, 32'h0000_0004);
        repeat (4) @(negedge clk);

        $display("\n--- [INIT] Uploading Input Image (416x416x3) & Full Tiny-YOLOv2 Weights (15.12 MB) via S0 AXI4 ---");
        cpu_upload_yolo_model_and_image();
        $display("  -> [OK] All 9 layers' weights, biases, quant configs, LUT & L1 image uploaded to 32 MB System RAM.");

        // Layer 1: 3x3 Conv + LeakyReLU + 2x2 s2 MaxPool (416x416x3 -> 208x208x16, BUF_A -> BUF_B)
        $display("\n--- [LAYER 1/9] 3x3 Conv + LeakyReLU + 2x2 s2 MaxPool: 416x416x3 -> 208x208x16 (676 tiles, 2 groups, 4 passes) ---");
        execute_yolo_layer("L1_Conv3x3_PoolS2", ACT_BUF_A_BASE, ACT_BUF_B_BASE,
                           L1_W_BASE, L1_B_BASE, L1_Q_BASE, 416, 416, 3, 2, 4, 8'h61);
        verify_yolo_layer_output(1, "L1_Conv3x3_PoolS2", ACT_BUF_B_BASE, 208, 208, 16, err_l1);

        // Layer 2: 3x3 Conv + LeakyReLU + 2x2 s2 MaxPool (208x208x16 -> 104x104x32, BUF_B -> BUF_A)
        $display("\n--- [LAYER 2/9] 3x3 Conv + LeakyReLU + 2x2 s2 MaxPool: 208x208x16 -> 104x104x32 (169 tiles, 4 groups, 18 passes) ---");
        execute_yolo_layer("L2_Conv3x3_PoolS2", ACT_BUF_B_BASE, ACT_BUF_A_BASE,
                           L2_W_BASE, L2_B_BASE, L2_Q_BASE, 208, 208, 16, 4, 18, 8'h61);
        verify_yolo_layer_output(2, "L2_Conv3x3_PoolS2", ACT_BUF_A_BASE, 104, 104, 32, err_l2);

        // Layer 3: 3x3 Conv + LeakyReLU + 2x2 s2 MaxPool (104x104x32 -> 52x52x64, BUF_A -> BUF_B)
        $display("\n--- [LAYER 3/9] 3x3 Conv + LeakyReLU + 2x2 s2 MaxPool: 104x104x32 -> 52x52x64 (49 tiles, 8 groups, 36 passes) ---");
        execute_yolo_layer("L3_Conv3x3_PoolS2", ACT_BUF_A_BASE, ACT_BUF_B_BASE,
                           L3_W_BASE, L3_B_BASE, L3_Q_BASE, 104, 104, 32, 8, 36, 8'h61);
        verify_yolo_layer_output(3, "L3_Conv3x3_PoolS2", ACT_BUF_B_BASE, 52, 52, 64, err_l3);

        // Layer 4: 3x3 Conv + LeakyReLU + 2x2 s2 MaxPool (52x52x64 -> 26x26x128, BUF_B -> BUF_A)
        $display("\n--- [LAYER 4/9] 3x3 Conv + LeakyReLU + 2x2 s2 MaxPool: 52x52x64 -> 26x26x128 (16 tiles, 16 groups, 72 passes) ---");
        execute_yolo_layer("L4_Conv3x3_PoolS2", ACT_BUF_B_BASE, ACT_BUF_A_BASE,
                           L4_W_BASE, L4_B_BASE, L4_Q_BASE, 52, 52, 64, 16, 72, 8'h61);
        verify_yolo_layer_output(4, "L4_Conv3x3_PoolS2", ACT_BUF_A_BASE, 26, 26, 128, err_l4);

        // Layer 5: 3x3 Conv + LeakyReLU + 2x2 s2 MaxPool (26x26x128 -> 13x13x256, BUF_A -> BUF_B)
        $display("\n--- [LAYER 5/9] 3x3 Conv + LeakyReLU + 2x2 s2 MaxPool: 26x26x128 -> 13x13x256 (4 tiles, 32 groups, 144 passes) ---");
        execute_yolo_layer("L5_Conv3x3_PoolS2", ACT_BUF_A_BASE, ACT_BUF_B_BASE,
                           L5_W_BASE, L5_B_BASE, L5_Q_BASE, 26, 26, 128, 32, 144, 8'h61);
        verify_yolo_layer_output(5, "L5_Conv3x3_PoolS2", ACT_BUF_B_BASE, 13, 13, 256, err_l5);

        // Layer 6: 3x3 Conv + LeakyReLU + 2x2 s1 Asymmetric MaxPool (13x13x256 -> 13x13x512, BUF_B -> BUF_A, 288 passes)
        $display("\n--- [LAYER 6/9] 3x3 Conv + LeakyReLU + 2x2 s1 MaxPool: 13x13x256 -> 13x13x512 (1 tile, 64 groups, 288 passes) ---");
        execute_yolo_layer("L6_Conv3x3_PoolS1", ACT_BUF_B_BASE, ACT_BUF_A_BASE,
                           L6_W_BASE, L6_B_BASE, L6_Q_BASE, 13, 13, 256, 64, 288, 8'hA1);
        verify_yolo_layer_output(6, "L6_Conv3x3_PoolS1", ACT_BUF_A_BASE, 13, 13, 512, err_l6);

        // Layer 7: 3x3 Conv + LeakyReLU (13x13x512 -> 13x13x1024, BUF_A -> BUF_B, 576 passes)
        $display("\n--- [LAYER 7/9] 3x3 Conv + LeakyReLU: 13x13x512 -> 13x13x1024 (1 tile, 128 groups, 576 passes) ---");
        execute_yolo_layer("L7_Conv3x3_1024", ACT_BUF_A_BASE, ACT_BUF_B_BASE,
                           L7_W_BASE, L7_B_BASE, L7_Q_BASE, 13, 13, 512, 128, 576, 8'h21);
        verify_yolo_layer_output(7, "L7_Conv3x3_1024", ACT_BUF_B_BASE, 13, 13, 1024, err_l7);

        // Layer 8: 3x3 Conv + LeakyReLU (13x13x1024 -> 13x13x1024, BUF_B -> BUF_A, 1152 passes)
        $display("\n--- [LAYER 8/9] 3x3 Conv + LeakyReLU: 13x13x1024 -> 13x13x1024 (1 tile, 128 groups, 1152 passes) ---");
        execute_yolo_layer("L8_Conv3x3_1024", ACT_BUF_B_BASE, ACT_BUF_A_BASE,
                           L8_W_BASE, L8_B_BASE, L8_Q_BASE, 13, 13, 1024, 128, 1152, 8'h21);
        verify_yolo_layer_output(8, "L8_Conv3x3_1024", ACT_BUF_A_BASE, 13, 13, 1024, err_l8);

        // Layer 9: 1x1 Conv Linear Detection Head (13x13x1024 -> 13x13x125 [pad 128], BUF_A -> BUF_B, 256 passes)
        $display("\n--- [LAYER 9/9] 1x1 Conv Linear YOLO Head: 13x13x1024 -> 13x13x125 (1 tile, 16 groups, 256 passes) ---");
        execute_yolo_layer("L9_Conv1x1_Head", ACT_BUF_A_BASE, ACT_BUF_B_BASE,
                           L9_W_BASE, L9_B_BASE, L9_Q_BASE, 13, 13, 1024, 16, 256, 8'h11);
        verify_yolo_layer_output(9, "L9_Conv1x1_Head", ACT_BUF_B_BASE, 13, 13, 128, err_l9);

        // Dump Layer 9 hardware output words for Step 3 post-processor (3_render_detections.py)
        $writememh({mem_dir, "yolo_l9_hw_out_axi.mem"}, l9_hw_out_words);
        $display("  -> [DUMP] Wrote Layer 9 hardware output to '%syolo_l9_hw_out_axi.mem'", mem_dir);

        // Decode 13x13x125 YOLO grid and verify Top-1 detection class
        decode_and_verify_yolo_detections();

        $display("\n >>> ALL 9 FULL TINY-YOLOv2 LAYERS BIT-EXACT & OBJECT DETECTION VERIFIED! <<< \n");
        $finish;
    end

endmodule
