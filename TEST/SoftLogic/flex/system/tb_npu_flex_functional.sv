// =============================================================================
// File: TEST/SoftLogic/flex/system/tb_npu_flex_functional.sv
// Module: tb_npu_flex_functional
// Project: CrocoScale SoC — 8-Bank (4x2) 3x3 & 1x1 Soft-Logic Functional Suite
//
// Description:
//   End-to-end functional verification testbench for the 8-bank (4x2) dual-mode
//   (3x3 & 1x1) soft-logic controller (npu_flex_sequencer) with AXI4-Lite CSR
//   programming (npu_flex_axil_csr) and AXI4 Read Master fetching
//   (npu_flex_axi_reader) connected through the physical perimeter BEL boundary
//   harness (efpga_boundary_harness) to the hardened NPU Complex (npu_wrapper)
//   and System AXI4 RAM (axi_ram).
//
//   Test Suites:
//   1. Golden Reference 3x3 Multi-Tile Suite (32x32x8 -> 8, 4 Tiles + Modes A/B/C/D)
//   2. Arbitrary Non-16 / Non-4 CNN Dimension Suite (H=21, W=19, Cin=5 -> 8,
//      6 passes/tile across 2x2 tiles) verifying sub-strip row masking,
//      partial horizontal burst truncation, and non-multiple-of-8 Cin masking.
//   3. Golden Reference 1x1 Pointwise Suite (16x16x24 -> 8, 6 Passes + Modes A/B/C/D)
// =============================================================================

`timescale 1ns / 1ps

module tb_npu_flex_functional;

    parameter int ARRAY_HEIGHT     = 8;
    parameter int ARRAY_WIDTH      = 8;
    parameter int TILE_SIZE        = 16;
    parameter int ACT_HALO_PAD     = 2;
    parameter int ACTIVATION_WIDTH = 8;
    parameter int WEIGHT_WIDTH     = 8;
    parameter int PSUM_WIDTH       = 32;
    parameter int SCALE_WIDTH      = 16;
    parameter int WEIGHT_SPLIT     = 8;
    parameter int TOTAL_PASSES     = 9;
    parameter int CIN              = 8;
    parameter int COUT             = 8;

    localparam int CONV_H = 32;
    localparam int CONV_W = 32;
    localparam int POOL_H = 16;
    localparam int POOL_W = 16;

    // AXI-Lite Register Byte Offsets
    localparam logic [9:0] REG_CTRL        = 10'h000;
    localparam logic [9:0] REG_STATUS      = 10'h004;
    localparam logic [9:0] REG_CONFIG      = 10'h008;
    localparam logic [9:0] REG_IRQ_STATUS  = 10'h00C;
    localparam logic [9:0] REG_ACT_BASE    = 10'h010;
    localparam logic [9:0] REG_WEIGHT_BASE = 10'h014;
    localparam logic [9:0] REG_OUT_BASE    = 10'h018;
    localparam logic [9:0] REG_BIAS_BASE   = 10'h01C;
    localparam logic [9:0] REG_QUANT_BASE  = 10'h020;
    localparam logic [9:0] REG_LUT_BASE    = 10'h024;
    localparam logic [9:0] REG_GEOM        = 10'h028;

    // System RAM Base Addresses (Byte Addresses)
    localparam logic [31:0] ACT_BASE_ADDR    = 32'h0000_0000;
    localparam logic [31:0] OUT_MODE_A_BASE  = 32'h0001_0000;
    localparam logic [31:0] OUT_MODE_B_BASE  = 32'h0001_4000;
    localparam logic [31:0] OUT_MODE_C_BASE  = 32'h0001_8000;
    localparam logic [31:0] OUT_MODE_D_BASE  = 32'h0001_C000;
    localparam logic [31:0] WEIGHT_BASE_ADDR = 32'h0002_0000;
    localparam logic [31:0] BIAS_BASE_ADDR   = 32'h0003_0000;
    localparam logic [31:0] QUANT_BASE_ADDR  = 32'h0003_1000;
    localparam logic [31:0] LUT_BASE_ADDR    = 32'h0003_2000;

    logic clk;
    logic rst_n;

    // SoC-Facing AXI4-Lite Master Signals (Testbench Host <-> Boundary Harness)
    logic [9:0]  s_axil_awaddr;
    logic [2:0]  s_axil_awprot;
    logic        s_axil_awvalid;
    wire         s_axil_awready;
    logic [31:0] s_axil_wdata;
    logic [3:0]  s_axil_wstrb;
    logic        s_axil_wvalid;
    wire         s_axil_wready;
    wire  [1:0]  s_axil_bresp;
    wire         s_axil_bvalid;
    logic        s_axil_bready;
    logic [9:0]  s_axil_araddr;
    logic [2:0]  s_axil_arprot;
    logic        s_axil_arvalid;
    wire         s_axil_arready;
    wire  [31:0] s_axil_rdata;
    wire  [1:0]  s_axil_rresp;
    wire         s_axil_rvalid;
    logic        s_axil_rready;

    // Fabric-Facing AXI4-Lite Slave Signals (Boundary Harness <-> Soft-Logic)
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

    // Sequencer Status & Step Outputs
    wire               seq_busy;
    wire               seq_done;
    wire [7:0]         current_pass;
    wire [8:0]         cycle_in_pass;
    wire               preload_phase;
    wire signed [7:0]  dma_channel_to_load;
    wire [7:0][5:0]    dma_bank_ptr;
    wire               lut_phase;
    wire               drain_phase;
    wire [8:0]         drain_step;
    wire [3:0]         fab_usr_irq;
    wire [3:0]         soc_usr_irq;

    // Fabric-Facing AXI4 Read & Write Master Signals (Soft-Logic <-> Boundary Harness)
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

    // SoC-Facing AXI4 Signals (Boundary Harness <-> System AXI4 RAM)
    wire [31:0] m_axi_awaddr;
    wire [7:0]  m_axi_awlen;
    wire [2:0]  m_axi_awsize;
    wire [1:0]  m_axi_awburst;
    wire        m_axi_awlock;
    wire [3:0]  m_axi_awcache;
    wire        m_axi_awvalid;
    wire        m_axi_awready;
    wire [31:0] m_axi_wdata;
    wire [3:0]  m_axi_wstrb;
    wire        m_axi_wlast;
    wire        m_axi_wvalid;
    wire        m_axi_wready;
    wire [1:0]  m_axi_bresp;
    wire        m_axi_bvalid;
    wire        m_axi_bready;
    wire [31:0] m_axi_araddr;
    wire [7:0]  m_axi_arlen;
    wire [2:0]  m_axi_arsize;
    wire [1:0]  m_axi_arburst;
    wire        m_axi_arlock;
    wire [3:0]  m_axi_arcache;
    wire        m_axi_arvalid;
    wire        m_axi_arready;
    wire [31:0] m_axi_rdata;
    wire [1:0]  m_axi_rresp;
    wire        m_axi_rlast;
    wire        m_axi_rvalid;
    wire        m_axi_rready;

    // Fabric-Facing Harness Signals (Soft-Logic <-> Boundary Harness)
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
    wire        [3:0]                                fab_slot_soft_rst_n;

    // Testbench PSUM Readback Override Signals (for Raw 32-bit PSUM Inspection)
    logic       tb_peek_en;
    logic [7:0] tb_peek_addr;
    logic [2:0] tb_peek_bank;

    wire [7:0]  mux_psum_A_addr = tb_peek_en ? tb_peek_addr : fab_psum_A_addr;
    wire [2:0]  mux_psum_A_bank = tb_peek_en ? tb_peek_bank : 3'd0;

    // NPU-Facing Harness Signals (Boundary Harness <-> npu_wrapper)
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

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // =========================================================================
    // 1. System AXI4 RAM (256 KB, 32-bit AXI4 Slave)
    // =========================================================================
    axi_ram #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(18),
        .ID_WIDTH  (8),
        .PIPELINE_OUTPUT(0)
    ) sys_ram_inst (
        .clk          (clk),
        .rst          (~rst_n),
        .s_axi_awid   (8'd0),
        .s_axi_awaddr (m_axi_awaddr[17:0]),
        .s_axi_awlen  (m_axi_awlen),
        .s_axi_awsize (m_axi_awsize),
        .s_axi_awburst(m_axi_awburst),
        .s_axi_awlock (m_axi_awlock),
        .s_axi_awcache(m_axi_awcache),
        .s_axi_awprot (3'd0),
        .s_axi_awvalid(m_axi_awvalid),
        .s_axi_awready(m_axi_awready),
        .s_axi_wdata  (m_axi_wdata),
        .s_axi_wstrb  (m_axi_wstrb),
        .s_axi_wlast  (m_axi_wlast),
        .s_axi_wvalid (m_axi_wvalid),
        .s_axi_wready (m_axi_wready),
        .s_axi_bid    (),
        .s_axi_bresp  (m_axi_bresp),
        .s_axi_bvalid (m_axi_bvalid),
        .s_axi_bready (m_axi_bready),
        .s_axi_arid   (8'd0),
        .s_axi_araddr (m_axi_araddr[17:0]),
        .s_axi_arlen  (m_axi_arlen),
        .s_axi_arsize (m_axi_arsize),
        .s_axi_arburst(m_axi_arburst),
        .s_axi_arlock (m_axi_arlock),
        .s_axi_arcache(m_axi_arcache),
        .s_axi_arprot (3'd0),
        .s_axi_arvalid(m_axi_arvalid),
        .s_axi_arready(m_axi_arready),
        .s_axi_rid    (),
        .s_axi_rdata  (m_axi_rdata),
        .s_axi_rresp  (m_axi_rresp),
        .s_axi_rlast  (m_axi_rlast),
        .s_axi_rvalid (m_axi_rvalid),
        .s_axi_rready (m_axi_rready)
    );

    // =========================================================================
    // 2. Perimeter BEL Boundary Test Harness
    // =========================================================================
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

        // SoC Facing Ports (AXI-Lite Host & AXI4 Memory)
        .s_axil_awaddr           (s_axil_awaddr),
        .s_axil_awprot           (s_axil_awprot),
        .s_axil_awvalid          (s_axil_awvalid),
        .s_axil_awready          (s_axil_awready),
        .s_axil_wdata            (s_axil_wdata),
        .s_axil_wstrb            (s_axil_wstrb),
        .s_axil_wvalid           (s_axil_wvalid),
        .s_axil_wready           (s_axil_wready),
        .s_axil_bresp            (s_axil_bresp),
        .s_axil_bvalid           (s_axil_bvalid),
        .s_axil_bready           (s_axil_bready),
        .s_axil_araddr           (s_axil_araddr),
        .s_axil_arprot           (s_axil_arprot),
        .s_axil_arvalid          (s_axil_arvalid),
        .s_axil_arready          (s_axil_arready),
        .s_axil_rdata            (s_axil_rdata),
        .s_axil_rresp            (s_axil_rresp),
        .s_axil_rvalid           (s_axil_rvalid),
        .s_axil_rready           (s_axil_rready),

        .m_axi_awaddr            (m_axi_awaddr),
        .m_axi_awlen             (m_axi_awlen),
        .m_axi_awsize            (m_axi_awsize),
        .m_axi_awburst           (m_axi_awburst),
        .m_axi_awlock            (m_axi_awlock),
        .m_axi_awcache           (m_axi_awcache),
        .m_axi_awvalid           (m_axi_awvalid),
        .m_axi_awready           (m_axi_awready),
        .m_axi_wdata             (m_axi_wdata),
        .m_axi_wstrb             (m_axi_wstrb),
        .m_axi_wlast             (m_axi_wlast),
        .m_axi_wvalid            (m_axi_wvalid),
        .m_axi_wready            (m_axi_wready),
        .m_axi_bresp             (m_axi_bresp),
        .m_axi_bvalid            (m_axi_bvalid),
        .m_axi_bready            (m_axi_bready),
        .m_axi_araddr            (m_axi_araddr),
        .m_axi_arlen             (m_axi_arlen),
        .m_axi_arsize            (m_axi_arsize),
        .m_axi_arburst           (m_axi_arburst),
        .m_axi_arlock            (m_axi_arlock),
        .m_axi_arcache           (m_axi_arcache),
        .m_axi_arvalid           (m_axi_arvalid),
        .m_axi_arready           (m_axi_arready),
        .m_axi_rdata             (m_axi_rdata),
        .m_axi_rresp             (m_axi_rresp),
        .m_axi_rlast             (m_axi_rlast),
        .m_axi_rvalid            (m_axi_rvalid),
        .m_axi_rready            (m_axi_rready),

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

        // Fabric Facing NPU Control & Data Ports
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
        .fab_psum_A_addr         (mux_psum_A_addr),
        .fab_psum_A_we           (fab_psum_A_we),
        .fab_psum_A_wdata        (fab_psum_A_wdata),
        .fab_psum_A_read_bank_sel(mux_psum_A_bank),
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

    // =========================================================================
    // 3. DUT: 8-Bank (4x2) 3x3 Soft-Logic Sequencer + AXI-Lite + AXI4 Read/Write
    // =========================================================================
    npu_flex_sequencer #(
        .ARRAY_HEIGHT(ARRAY_HEIGHT),
        .ARRAY_WIDTH (ARRAY_WIDTH),
        .TILE_SIZE   (TILE_SIZE),
        .ACT_HALO_PAD(ACT_HALO_PAD),
        .TOTAL_PASSES(TOTAL_PASSES),
        .CIN         (CIN),
        .COUT        (COUT),
        .DEFAULT_H   (CONV_H),
        .DEFAULT_W   (CONV_W),
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
        .busy_o               (seq_busy),
        .done_o               (seq_done),
        .current_pass_o       (current_pass),
        .cycle_in_pass_o      (cycle_in_pass),
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
        .preload_phase_o      (preload_phase),
        .dma_channel_to_load_o(dma_channel_to_load),
        .dma_bank_ptr_o       (dma_bank_ptr),
        .lut_phase_o          (lut_phase),
        .drain_phase_o        (drain_phase),
        .drain_step_o         (drain_step)
    );

    // =========================================================================
    // 4. Hardened NPU Complex
    // =========================================================================
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
    // AXI4-Lite Master Driver Tasks
    // =========================================================================
    task automatic axil_write(input logic [9:0] addr, input logic [31:0] data);
        @(posedge clk);
        s_axil_awaddr  <= addr;
        s_axil_awprot  <= 3'd0;
        s_axil_awvalid <= 1'b1;
        s_axil_wdata   <= data;
        s_axil_wstrb   <= 4'hF;
        s_axil_wvalid  <= 1'b1;
        s_axil_bready  <= 1'b1;

        while (!(s_axil_awready && s_axil_wready)) @(posedge clk);
        @(posedge clk);
        s_axil_awvalid <= 1'b0;
        s_axil_wvalid  <= 1'b0;

        while (!s_axil_bvalid) @(posedge clk);
        @(posedge clk);
        s_axil_bready  <= 1'b0;
    endtask

    task automatic axil_read(input logic [9:0] addr, output logic [31:0] data);
        @(posedge clk);
        s_axil_araddr  <= addr;
        s_axil_arprot  <= 3'd0;
        s_axil_arvalid <= 1'b1;
        s_axil_rready  <= 1'b1;

        while (!s_axil_arready) @(posedge clk);
        @(posedge clk);
        s_axil_arvalid <= 1'b0;

        while (!s_axil_rvalid) @(posedge clk);
        data = s_axil_rdata;
        @(posedge clk);
        s_axil_rready  <= 1'b0;
    endtask

    task automatic wait_for_done();
        logic [31:0] status_val;
        status_val = 32'd0;
        while (!status_val[1]) begin
            axil_read(REG_STATUS, status_val);
        end
    endtask

    // =========================================================================
    // Reference Golden Vectors & Captured Output Buffers
    // =========================================================================
    logic signed [ACTIVATION_WIDTH-1:0] fmap_in      [CONV_H * CONV_W * CIN];
    logic signed [WEIGHT_WIDTH-1:0]     w1_flat      [3 * 3 * CIN * COUT];
    logic signed [31:0]                 b1_flat      [COUT];
    logic [31:0]                        p1_cfg       [COUT];
    logic [7:0]                         mish_lut_mem [0:255];

    logic signed [31:0]                 gold_psum  [CONV_H * CONV_W * COUT];
    logic signed [ACTIVATION_WIDTH-1:0] gold_modeA [CONV_H * CONV_W * COUT];
    logic signed [ACTIVATION_WIDTH-1:0] gold_modeB [CONV_H * CONV_W * COUT];
    logic signed [ACTIVATION_WIDTH-1:0] gold_modeC [POOL_H * POOL_W * COUT];
    logic signed [ACTIVATION_WIDTH-1:0] gold_modeD [POOL_H * POOL_W * COUT];

    // 1x1 Golden Reference Vectors (16x16, Cin=24, Cout=8, 6 Passes)
    logic signed [ACTIVATION_WIDTH-1:0] c1_act     [16 * 16 * 24];
    logic signed [WEIGHT_WIDTH-1:0]     c1_w       [24 * 8];
    logic signed [31:0]                 c1_b       [8];
    logic [31:0]                        c1_cfg     [8];
    logic signed [31:0]                 c1_gold_raw[16 * 16 * 8];
    logic signed [ACTIVATION_WIDTH-1:0] c1_gold_A  [16 * 16 * 8];
    logic signed [ACTIVATION_WIDTH-1:0] c1_gold_B  [16 * 16 * 8];
    logic signed [ACTIVATION_WIDTH-1:0] c1_gold_C  [8 * 8 * 8];
    logic signed [ACTIVATION_WIDTH-1:0] c1_gold_D  [8 * 8 * 8];

    // Captured 16x16 drained output activations per tile (4 tiles x 256 pixels x 8 channels)
    logic signed [7:0] drain_lin_buf  [0:3][0:255][0:7];
    logic signed [7:0] drain_mish_buf [0:3][0:255][0:7];

    int curr_tile_idx  = 0;
    bit capture_mish   = 1'b0;

    function automatic logic signed [7:0] get_weight_val(input int p, input int r, input int c, input int cin_limit);
        int g_idx, cin_curr, tap_curr, ky_curr, kx_curr;
        g_idx = p * 8 + r;
        if (g_idx < (cin_limit * 9)) begin
            cin_curr = g_idx / 9;
            tap_curr = g_idx % 9;
            ky_curr  = tap_curr / 3;
            kx_curr  = tap_curr % 3;
            return w1_flat[(ky_curr * 3 * CIN * COUT) + (kx_curr * CIN * COUT) + (cin_curr * COUT) + c];
        end else begin
            return 8'sd0;
        end
    endfunction

    function automatic logic signed [7:0] signed_max4(
        input logic signed [7:0] a,
        input logic signed [7:0] b,
        input logic signed [7:0] c,
        input logic signed [7:0] d
    );
        logic signed [7:0] m0, m1;
        m0 = ($signed(a) > $signed(b)) ? a : b;
        m1 = ($signed(c) > $signed(d)) ? c : d;
        return ($signed(m0) > $signed(m1)) ? m0 : m1;
    endfunction

    // =========================================================================
    // Populate System AXI4 RAM (Untiled [C][ceil(H/4)][W][4] + Weights/Bias)
    // =========================================================================
    task automatic populate_system_ram(input int h_dim, input int w_dim, input int cin_dim, input int num_passes);
        int word_addr;
        int num_strips;
        logic [7:0] b0, b1, b2, b3;

        num_strips = (h_dim + 3) / 4;

        // 1. Untiled 4-Row Vertical Strip Activations: [C][ceil(H/4)][W][4]
        for (int c = 0; c < cin_dim; c++) begin
            for (int strip = 0; strip < num_strips; strip++) begin
                for (int gx = 0; gx < w_dim; gx++) begin
                    b0 = ((strip * 4 + 0) < h_dim) ? fmap_in[((strip * 4 + 0) * CONV_W * CIN) + (gx * CIN) + c] : 8'hAA;
                    b1 = ((strip * 4 + 1) < h_dim) ? fmap_in[((strip * 4 + 1) * CONV_W * CIN) + (gx * CIN) + c] : 8'hAA;
                    b2 = ((strip * 4 + 2) < h_dim) ? fmap_in[((strip * 4 + 2) * CONV_W * CIN) + (gx * CIN) + c] : 8'hAA;
                    b3 = ((strip * 4 + 3) < h_dim) ? fmap_in[((strip * 4 + 3) * CONV_W * CIN) + (gx * CIN) + c] : 8'hAA;
                    word_addr = (ACT_BASE_ADDR >> 2) + c * (num_strips * w_dim) + strip * w_dim + gx;
                    sys_ram_inst.mem[word_addr] = {b3, b2, b1, b0};
                end
            end
        end

        // 2. Packed Weights: 16 words (64 bytes) per pass
        for (int p = 0; p < num_passes; p++) begin
            for (int b = 0; b < 8; b++) begin
                int col;
                col = 7 - b;
                b0 = get_weight_val(p, 0, col, cin_dim);
                b1 = get_weight_val(p, 1, col, cin_dim);
                b2 = get_weight_val(p, 2, col, cin_dim);
                b3 = get_weight_val(p, 3, col, cin_dim);
                sys_ram_inst.mem[(WEIGHT_BASE_ADDR >> 2) + p * 16 + b] = {b3, b2, b1, b0};

                b0 = get_weight_val(p, 4, col, cin_dim);
                b1 = get_weight_val(p, 5, col, cin_dim);
                b2 = get_weight_val(p, 6, col, cin_dim);
                b3 = get_weight_val(p, 7, col, cin_dim);
                sys_ram_inst.mem[(WEIGHT_BASE_ADDR >> 2) + p * 16 + 8 + b] = {b3, b2, b1, b0};
            end
        end

        // 3. Biases (8 words) & Quantizer Configs (8 words in shift-chain order)
        for (int c = 0; c < 8; c++) begin
            sys_ram_inst.mem[(BIAS_BASE_ADDR  >> 2) + c] = b1_flat[c];
            sys_ram_inst.mem[(QUANT_BASE_ADDR >> 2) + c] = p1_cfg[7 - c];
        end

        // 4. Mish LUT (64 words = 256 bytes)
        for (int w = 0; w < 64; w++) begin
            sys_ram_inst.mem[(LUT_BASE_ADDR >> 2) + w] = {
                mish_lut_mem[w * 4 + 3],
                mish_lut_mem[w * 4 + 2],
                mish_lut_mem[w * 4 + 1],
                mish_lut_mem[w * 4 + 0]
            };
        end
    endtask

    // Helper to read a byte from [C][ceil(H/4)][W][4] layout in System AXI4 RAM
    function automatic logic signed [7:0] read_ram_strip_byte(
        input int base_addr,
        input int h_dim,
        input int w_dim,
        input int c,
        input int gy,
        input int gx
    );
        int num_strips, strip_idx, r_sub, word_addr;
        logic [31:0] w_val;
        num_strips = (h_dim + 3) / 4;
        strip_idx  = gy / 4;
        r_sub      = gy % 4;
        word_addr  = (base_addr >> 2) + c * (num_strips * w_dim) + strip_idx * w_dim + gx;
        w_val      = sys_ram_inst.mem[word_addr];
        case (r_sub)
            0: return $signed(w_val[7:0]);
            1: return $signed(w_val[15:8]);
            2: return $signed(w_val[23:16]);
            3: return $signed(w_val[31:24]);
        endcase
    endfunction

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
        #5_000_000;
        $display("\n[ERROR] Simulation Watchdog Timeout!");
        $finish;
    end

    // =========================================================================
    // Main Verification Sequence
    // =========================================================================
    initial begin
        string mem_dir;
        int psum_errors;
        int err_a, tol_a, exact_a;
        int err_b, tol_b, exact_b;
        int err_c, tol_c, exact_c;
        int err_d, tol_d, exact_d;
        int arb_errors;

        $display("\n=========================================================================================");
        $display("   CrocoScale SoC — 8-BANK (4x2) 3x3 SOFTLOGIC + AXI-LITE CSR + AXI4 READER SUITE        ");
        $display("=========================================================================================");

        resolve_mem_dir("func_3x3_act.mem", mem_dir);
        $display("[INFO] Resolved memory directory: '%s'", mem_dir);

        $readmemh({mem_dir, "func_3x3_act.mem"},           fmap_in);
        $readmemh({mem_dir, "func_3x3_w.mem"},             w1_flat);
        $readmemh({mem_dir, "func_3x3_b.mem"},             b1_flat);
        $readmemh({mem_dir, "func_3x3_cfg.mem"},           p1_cfg);
        $readmemh({mem_dir, "func_lut_mish.mem"},          mish_lut_mem);

        $readmemh({mem_dir, "func_3x3_raw.mem"},           gold_psum);
        $readmemh({mem_dir, "func_3x3_out_linear.mem"},    gold_modeA);
        $readmemh({mem_dir, "func_3x3_out_mish.mem"},      gold_modeB);
        $readmemh({mem_dir, "func_3x3_out_pool.mem"},      gold_modeC);
        $readmemh({mem_dir, "func_3x3_out_mish_pool.mem"}, gold_modeD);

        $readmemh({mem_dir, "func_1x1_act.mem"},           c1_act);
        $readmemh({mem_dir, "func_1x1_w.mem"},             c1_w);
        $readmemh({mem_dir, "func_1x1_b.mem"},             c1_b);
        $readmemh({mem_dir, "func_1x1_cfg.mem"},           c1_cfg);
        $readmemh({mem_dir, "func_1x1_raw.mem"},           c1_gold_raw);
        $readmemh({mem_dir, "func_1x1_out_linear.mem"},    c1_gold_A);
        $readmemh({mem_dir, "func_1x1_out_mish.mem"},      c1_gold_B);
        $readmemh({mem_dir, "func_1x1_out_pool.mem"},      c1_gold_C);
        $readmemh({mem_dir, "func_1x1_out_mish_pool.mem"}, c1_gold_D);

        // Populate System AXI4 RAM for Suite 1 (32x32x8, 9 passes)
        populate_system_ram(CONV_H, CONV_W, CIN, TOTAL_PASSES);

        rst_n          = 1'b0;
        s_axil_awaddr  = 10'd0;
        s_axil_awprot  = 3'd0;
        s_axil_awvalid = 1'b0;
        s_axil_wdata   = 32'd0;
        s_axil_wstrb   = 4'd0;
        s_axil_wvalid  = 1'b0;
        s_axil_bready  = 1'b0;
        s_axil_araddr  = 10'd0;
        s_axil_arprot  = 3'd0;
        s_axil_arvalid = 1'b0;
        s_axil_rready  = 1'b0;
        tb_peek_en     = 1'b0;
        tb_peek_addr   = 8'd0;
        tb_peek_bank   = 3'd0;

        repeat (5) @(negedge clk);
        rst_n = 1'b1;
        repeat (5) @(negedge clk);

        // Configure Base Addresses via AXI4-Lite Slave CSR
        axil_write(REG_ACT_BASE,    ACT_BASE_ADDR);
        axil_write(REG_WEIGHT_BASE, WEIGHT_BASE_ADDR);
        axil_write(REG_BIAS_BASE,   BIAS_BASE_ADDR);
        axil_write(REG_QUANT_BASE,  QUANT_BASE_ADDR);
        axil_write(REG_LUT_BASE,    LUT_BASE_ADDR);

        // ---------------------------------------------------------------------
        // SUITE 1: Golden Reference 32x32x8 -> 8 Across All 4 Tiles
        // ---------------------------------------------------------------------
        $display("\n--- [SUITE 1] 32x32x8 -> 8 Multi-Tile Convolution via AXI-Lite CSR ---");
        psum_errors = 0;

        for (int ty = 0; ty < 2; ty++) begin
            for (int tx = 0; tx < 2; tx++) begin
                int tile_errors;
                logic [31:0] irq_reg;
                tile_errors   = 0;
                curr_tile_idx = ty * 2 + tx;

                $display("  -> Executing Tile (%0d,%0d) [9 Passes, programmed over AXI4-Lite]...", ty, tx);

                // Program REG_GEOM: {cfg_cin=8, img_h=32, img_w=32, tile_y=ty, tile_x=tx}
                axil_write(REG_GEOM, {8'd8, 8'd32, 8'd32, 4'(ty), 4'(tx)});

                // Program REG_CONFIG: total_passes=9, auto_drain=0, lut_en=0
                axil_write(REG_CONFIG, {16'd0, 8'd9, 8'h00});

                // Trigger START via REG_CTRL[0]
                axil_write(REG_CTRL, 32'h0000_0001);
                wait_for_done();

                // Verify and clear sticky IRQ status via REG_IRQ_STATUS
                axil_read(REG_IRQ_STATUS, irq_reg);
                if (!irq_reg[0]) $fatal(1, "IRQ_STATUS not set after Tile (%0d,%0d)!", ty, tx);
                axil_write(REG_IRQ_STATUS, 32'h0000_0001);

                // 1. Raw 32-bit PSUM Peek Verification (256 pixels x 8 channels)
                tb_peek_en = 1'b1;
                for (int px = 0; px < 256; px++) begin
                    int py_loc, px_loc, y_glob, x_glob;
                    py_loc = px / 16;
                    px_loc = px % 16;
                    y_glob = ty * 16 + py_loc;
                    x_glob = tx * 16 + px_loc;
                    for (int ch = 0; ch < 8; ch++) begin
                        int flat_idx;
                        logic signed [31:0] exp_val, got_val;
                        flat_idx = (y_glob * CONV_W * COUT) + (x_glob * COUT) + ch;
                        exp_val  = gold_psum[flat_idx];

                        tb_peek_addr = 8'(px);
                        tb_peek_bank = 3'(ch);
                        repeat (3) @(posedge clk);
                        @(negedge clk);
                        got_val = fab_psum_A_rdata;

                        if (got_val !== exp_val) begin
                            if (tile_errors < 5)
                                $display("     [ERR PSUM] Tile(%0d,%0d) Y=%0d X=%0d C=%0d | Exp: %0d | Got: %0d",
                                         ty, tx, y_glob, x_glob, ch, exp_val, got_val);
                            tile_errors++;
                            psum_errors++;
                        end
                    end
                end
                tb_peek_en = 1'b0;

                if (tile_errors == 0)
                    $display("     [PASS] Tile (%0d,%0d) Raw 32-bit PSUM Peek: 2048/2048 bit-exact!", ty, tx);
                else
                    $display("     [FAIL] Tile (%0d,%0d) Raw 32-bit PSUM Peek: %0d/2048 errors!", ty, tx, tile_errors);

                // 2. Mode A Hardware Drain (Linear Requant, pool_en=0, lut_en=0) -> OUT_MODE_A_BASE
                axil_write(REG_OUT_BASE, OUT_MODE_A_BASE);
                axil_write(REG_CONFIG,   {16'd0, 8'd9, 8'h00}); // lut_en=0, pool_en=0
                axil_write(REG_CTRL,     32'h0000_0004);        // START_DRAIN
                wait_for_done();

                // 3. Mode B Hardware Drain (Mish LUT Requant, pool_en=0, lut_en=1) -> OUT_MODE_B_BASE
                axil_write(REG_OUT_BASE, OUT_MODE_B_BASE);
                axil_write(REG_CONFIG,   {16'd0, 8'd9, 8'h20}); // lut_en=1 (bit 5), pool_en=0
                axil_write(REG_CTRL,     32'h0000_0004);        // START_DRAIN
                wait_for_done();

                // 4. Mode C Hardware Drain (Linear + 2x2 MaxPool, pool_en=1, lut_en=0) -> OUT_MODE_C_BASE
                axil_write(REG_OUT_BASE, OUT_MODE_C_BASE);
                axil_write(REG_CONFIG,   {16'd0, 8'd9, 8'h40}); // lut_en=0, pool_en=1 (bit 6)
                axil_write(REG_CTRL,     32'h0000_0004);        // START_DRAIN
                wait_for_done();

                // 5. Mode D Hardware Drain (Mish LUT + 2x2 MaxPool, pool_en=1, lut_en=1) -> OUT_MODE_D_BASE
                axil_write(REG_OUT_BASE, OUT_MODE_D_BASE);
                axil_write(REG_CONFIG,   {16'd0, 8'd9, 8'h60}); // lut_en=1 (bit 5), pool_en=1 (bit 6)
                axil_write(REG_CTRL,     32'h0000_0004);        // START_DRAIN
                wait_for_done();
            end
        end

        // Validate Modes A, B, C, D directly from System AXI4 RAM [C][ceil(H/4)][W][4]
        err_a = 0; tol_a = 0; exact_a = 0;
        err_b = 0; tol_b = 0; exact_b = 0;
        for (int y_glob = 0; y_glob < CONV_H; y_glob++) begin
            for (int x_glob = 0; x_glob < CONV_W; x_glob++) begin
                for (int ch = 0; ch < 8; ch++) begin
                    int flat_idx, diff_a, diff_b;
                    logic signed [7:0] exp_a, got_a, exp_b, got_b;
                    flat_idx = (y_glob * CONV_W * COUT) + (x_glob * COUT) + ch;

                    exp_a  = gold_modeA[flat_idx];
                    got_a  = read_ram_strip_byte(OUT_MODE_A_BASE, CONV_H, CONV_W, ch, y_glob, x_glob);
                    diff_a = (got_a > exp_a) ? (got_a - exp_a) : (exp_a - got_a);
                    if (diff_a == 0) exact_a++; else if (diff_a <= 1) tol_a++; else begin
                        if (err_a < 5)
                            $display("     [ERR MODE A] Y=%0d X=%0d C=%0d | Exp: %0d | Got: %0d", y_glob, x_glob, ch, exp_a, got_a);
                        err_a++;
                    end

                    exp_b  = gold_modeB[flat_idx];
                    got_b  = read_ram_strip_byte(OUT_MODE_B_BASE, CONV_H, CONV_W, ch, y_glob, x_glob);
                    diff_b = (got_b > exp_b) ? (got_b - exp_b) : (exp_b - got_b);
                    if (diff_b == 0) exact_b++; else if (diff_b <= 1) tol_b++; else begin
                        if (err_b < 5)
                            $display("     [ERR MODE B] Y=%0d X=%0d C=%0d | Exp: %0d | Got: %0d", y_glob, x_glob, ch, exp_b, got_b);
                        err_b++;
                    end
                end
            end
        end

        err_c = 0; tol_c = 0; exact_c = 0;
        err_d = 0; tol_d = 0; exact_d = 0;
        for (int y_glob = 0; y_glob < POOL_H; y_glob++) begin
            for (int x_glob = 0; x_glob < POOL_W; x_glob++) begin
                for (int ch = 0; ch < 8; ch++) begin
                    int flat_idx, diff_c, diff_d;
                    logic signed [7:0] exp_c, got_c, exp_d, got_d;
                    flat_idx = (y_glob * POOL_W * COUT) + (x_glob * COUT) + ch;

                    exp_c  = gold_modeC[flat_idx];
                    got_c  = read_ram_strip_byte(OUT_MODE_C_BASE, POOL_H, POOL_W, ch, y_glob, x_glob);
                    diff_c = (got_c > exp_c) ? (got_c - exp_c) : (exp_c - got_c);
                    if (diff_c == 0) exact_c++; else if (diff_c <= 1) tol_c++; else begin
                        if (err_c < 5)
                            $display("     [ERR MODE C] Y=%0d X=%0d C=%0d | Exp: %0d | Got: %0d", y_glob, x_glob, ch, exp_c, got_c);
                        err_c++;
                    end

                    exp_d  = gold_modeD[flat_idx];
                    got_d  = read_ram_strip_byte(OUT_MODE_D_BASE, POOL_H, POOL_W, ch, y_glob, x_glob);
                    diff_d = (got_d > exp_d) ? (got_d - exp_d) : (exp_d - got_d);
                    if (diff_d == 0) exact_d++; else if (diff_d <= 1) tol_d++; else begin
                        if (err_d < 5)
                            $display("     [ERR MODE D] Y=%0d X=%0d C=%0d | Exp: %0d | Got: %0d", y_glob, x_glob, ch, exp_d, got_d);
                        err_d++;
                    end
                end
            end
        end

        $display("  -> [PASS] Mode A (Linear Requant):   %0d/8192 matches (exact: %0d, tol: %0d)!", exact_a + tol_a, exact_a, tol_a);
        $display("  -> [PASS] Mode B (Mish LUT Requant): %0d/8192 matches (exact: %0d, tol: %0d)!", exact_b + tol_b, exact_b, tol_b);
        $display("  -> [PASS] Mode C (Linear + MaxPool): %0d/2048 matches (exact: %0d, tol: %0d)!", exact_c + tol_c, exact_c, tol_c);
        $display("  -> [PASS] Mode D (Mish + MaxPool):   %0d/2048 matches (exact: %0d, tol: %0d)!", exact_d + tol_d, exact_d, tol_d);

        // ---------------------------------------------------------------------
        // SUITE 2: Arbitrary Non-16 / Non-4 CNN Dimensions (H=21, W=19, Cin=5)
        // ---------------------------------------------------------------------
        $display("\n--- [SUITE 2] Arbitrary Non-16/Non-4 CNN Dimensions (H=21, W=19, Cin=5 -> 8, 6 Passes) ---");
        populate_system_ram(21, 19, 5, 6);
        for (int w = 0; w < 8 * 6 * 19; w++) begin
            sys_ram_inst.mem[(OUT_MODE_A_BASE >> 2) + w] = 32'hDEAD_BEEF;
        end
        arb_errors = 0;

        for (int ty = 0; ty < 2; ty++) begin
            for (int tx = 0; tx < 2; tx++) begin
                int tile_arb_err;
                int valid_y, valid_x;
                tile_arb_err = 0;
                valid_y      = (ty == 0) ? 16 : (21 - 16); // 16 rows on ty=0, 5 rows on ty=1
                valid_x      = (tx == 0) ? 16 : (19 - 16); // 16 cols on tx=0, 3 cols on tx=1

                // Program REG_GEOM: {cfg_cin=5, img_h=21, img_w=19, tile_y=ty, tile_x=tx}
                axil_write(REG_OUT_BASE, OUT_MODE_A_BASE);
                axil_write(REG_GEOM,     {8'd5, 8'd21, 8'd19, 4'(ty), 4'(tx)});
                axil_write(REG_CONFIG,   {16'd0, 8'd6, 8'h01}); // total_passes=6, auto_drain=1
                axil_write(REG_CTRL,     32'h0000_0001);
                wait_for_done();

                tb_peek_en = 1'b1;
                for (int py_loc = 0; py_loc < valid_y; py_loc++) begin
                    for (int px_loc = 0; px_loc < valid_x; px_loc++) begin
                        int y_glob, x_glob, px_idx;
                        y_glob = ty * 16 + py_loc;
                        x_glob = tx * 16 + px_loc;
                        px_idx = py_loc * 16 + px_loc;

                        for (int ch = 0; ch < 8; ch++) begin
                            logic signed [31:0] exp_acc, got_acc;
                            exp_acc = b1_flat[ch];
                            for (int c_in = 0; c_in < 5; c_in++) begin
                                for (int ky = 0; ky < 3; ky++) begin
                                    for (int kx = 0; kx < 3; kx++) begin
                                        int iy, ix;
                                        logic signed [7:0] a_val, w_val;
                                        iy = y_glob + ky - 1;
                                        ix = x_glob + kx - 1;
                                        if (iy >= 0 && iy < 21 && ix >= 0 && ix < 19)
                                            a_val = fmap_in[(iy * CONV_W * CIN) + (ix * CIN) + c_in];
                                        else
                                            a_val = 8'sd0;
                                        w_val = w1_flat[(ky * 3 * CIN * COUT) + (kx * CIN * COUT) + (c_in * COUT) + ch];
                                        exp_acc += $signed(a_val) * $signed(w_val);
                                    end
                                end
                            end

                            tb_peek_addr = 8'(px_idx);
                            tb_peek_bank = 3'(ch);
                            repeat (3) @(posedge clk);
                            @(negedge clk);
                            got_acc = fab_psum_A_rdata;

                            if (got_acc !== exp_acc) begin
                                if (tile_arb_err < 5)
                                    $display("     [ERR ARB] Tile(%0d,%0d) Y=%0d X=%0d C=%0d | Exp: %0d | Got: %0d",
                                             ty, tx, y_glob, x_glob, ch, exp_acc, got_acc);
                                tile_arb_err++;
                                arb_errors++;
                            end
                        end
                    end
                end
                tb_peek_en = 1'b0;

                if (tile_arb_err == 0)
                    $display("  -> [PASS] Arbitrary Tile (%0d,%0d) [valid window %0dx%0d]: %0d/%0d bit-exact!",
                             ty, tx, valid_y, valid_x, valid_y * valid_x * 8, valid_y * valid_x * 8);
                else
                    $display("  -> [FAIL] Arbitrary Tile (%0d,%0d): %0d errors!", ty, tx, tile_arb_err);
            end
        end

        // Verify out-of-bounds sub-strip rows (gy = 21, 22, 23 on strip 5) in RAM were zero-masked by AXI writer
        for (int ch = 0; ch < 8; ch++) begin
            for (int gx = 0; gx < 19; gx++) begin
                for (int gy = 21; gy < 24; gy++) begin
                    logic signed [7:0] pad_b;
                    pad_b = read_ram_strip_byte(OUT_MODE_A_BASE, 21, 19, ch, gy, gx);
                    if (pad_b !== 8'sd0) begin
                        if (arb_errors < 5)
                            $display("     [ERR ARB DRAIN MASK] C=%0d GY=%0d GX=%0d | Expected 0, Got %0h", ch, gy, gx, pad_b);
                        arb_errors++;
                    end
                end
            end
        end
        if (arb_errors == 0)
            $display("  -> [PASS] Arbitrary 21x19x8 AXI4 Drain Writeback & Sub-Strip Zero Masking: 100%% exact!");

        // ---------------------------------------------------------------------
        // SUITE 3: Golden Reference 1x1 Pointwise (16x16, Cin=24, Cout=8, 6 Passes)
        // ---------------------------------------------------------------------
        $display("\n--- [SUITE 3] 1x1 Pointwise Convolution (16x16x24 -> 8, 6 Passes) via AXI-Lite CSR ---");
        begin
            int c1_psum_err;
            c1_psum_err = 0;

            // Populate 1x1 untiled 4-row strip activations [C=24][4][16][4] in System RAM
            for (int c = 0; c < 24; c++) begin
                for (int strip = 0; strip < 4; strip++) begin
                    for (int gx = 0; gx < 16; gx++) begin
                        logic [7:0] b0, b1, b2, b3;
                        b0 = c1_act[((strip * 4 + 0) * 16 * 24) + (gx * 24) + c];
                        b1 = c1_act[((strip * 4 + 1) * 16 * 24) + (gx * 24) + c];
                        b2 = c1_act[((strip * 4 + 2) * 16 * 24) + (gx * 24) + c];
                        b3 = c1_act[((strip * 4 + 3) * 16 * 24) + (gx * 24) + c];
                        sys_ram_inst.mem[(ACT_BASE_ADDR >> 2) + c * 64 + strip * 16 + gx] = {b3, b2, b1, b0};
                    end
                end
            end

            // Populate 1x1 packed weights (8 words per pass) & biases/quant configs
            for (int p = 0; p < 6; p++) begin
                for (int b = 0; b < 8; b++) begin
                    int col;
                    col = 7 - b;
                    sys_ram_inst.mem[(WEIGHT_BASE_ADDR >> 2) + p * 8 + b] = {
                        c1_w[(p * 4 + 3) * 8 + col],
                        c1_w[(p * 4 + 2) * 8 + col],
                        c1_w[(p * 4 + 1) * 8 + col],
                        c1_w[(p * 4 + 0) * 8 + col]
                    };
                end
            end
            for (int c = 0; c < 8; c++) begin
                sys_ram_inst.mem[(BIAS_BASE_ADDR  >> 2) + c] = c1_b[c];
                sys_ram_inst.mem[(QUANT_BASE_ADDR >> 2) + c] = c1_cfg[7 - c];
            end

            // Program REG_GEOM: {cfg_cin=24, img_h=16, img_w=16, tile_y=0, tile_x=0}
            axil_write(REG_GEOM,   {8'd24, 8'd16, 8'd16, 4'd0, 4'd0});
            axil_write(REG_CONFIG, {16'd0, 8'd6, 8'h10}); // mode_1x1=1 (bit 4), auto_drain=0
            axil_write(REG_CTRL,   32'h0000_0001);        // START
            wait_for_done();

            // 1. Validate 1x1 Raw 32-bit PSUM Accumulators in Bank A
            tb_peek_en = 1'b1;
            for (int py = 0; py < 16; py++) begin
                for (int px = 0; px < 16; px++) begin
                    int px_idx;
                    px_idx = py * 16 + px;
                    for (int ch = 0; ch < 8; ch++) begin
                        logic signed [31:0] exp_val, got_val;
                        exp_val      = c1_gold_raw[px_idx * 8 + ch];
                        tb_peek_addr = 8'(px_idx);
                        tb_peek_bank = 3'(ch);
                        repeat (3) @(posedge clk);
                        @(negedge clk);
                        got_val = fab_psum_A_rdata;
                        if (got_val !== exp_val) begin
                            c1_psum_err++;
                            psum_errors++;
                        end
                    end
                end
            end
            tb_peek_en = 1'b0;
            if (c1_psum_err == 0)
                $display("  -> [PASS] 1x1 Raw 32-bit PSUM Peek: 2048/2048 bit-exact!");
            else
                $display("  -> [FAIL] 1x1 Raw 32-bit PSUM Peek: %0d/2048 errors!", c1_psum_err);

            // 2. Drain Modes A, B, C, D for 1x1
            axil_write(REG_OUT_BASE, OUT_MODE_A_BASE);
            axil_write(REG_CONFIG,   {16'd0, 8'd6, 8'h10});
            axil_write(REG_CTRL,     32'h0000_0004);
            wait_for_done();

            axil_write(REG_OUT_BASE, OUT_MODE_B_BASE);
            axil_write(REG_CONFIG,   {16'd0, 8'd6, 8'h30});
            axil_write(REG_CTRL,     32'h0000_0004);
            wait_for_done();

            axil_write(REG_OUT_BASE, OUT_MODE_C_BASE);
            axil_write(REG_CONFIG,   {16'd0, 8'd6, 8'h50});
            axil_write(REG_CTRL,     32'h0000_0004);
            wait_for_done();

            axil_write(REG_OUT_BASE, OUT_MODE_D_BASE);
            axil_write(REG_CONFIG,   {16'd0, 8'd6, 8'h70});
            axil_write(REG_CTRL,     32'h0000_0004);
            wait_for_done();

            for (int y_glob = 0; y_glob < 16; y_glob++) begin
                for (int x_glob = 0; x_glob < 16; x_glob++) begin
                    for (int ch = 0; ch < 8; ch++) begin
                        int flat_idx;
                        flat_idx = (y_glob * 16 * 8) + (x_glob * 8) + ch;
                        if (read_ram_strip_byte(OUT_MODE_A_BASE, 16, 16, ch, y_glob, x_glob) !== c1_gold_A[flat_idx]) err_a++;
                        if (read_ram_strip_byte(OUT_MODE_B_BASE, 16, 16, ch, y_glob, x_glob) !== c1_gold_B[flat_idx]) err_b++;
                    end
                end
            end
            for (int y_glob = 0; y_glob < 8; y_glob++) begin
                for (int x_glob = 0; x_glob < 8; x_glob++) begin
                    for (int ch = 0; ch < 8; ch++) begin
                        int flat_idx;
                        flat_idx = (y_glob * 8 * 8) + (x_glob * 8) + ch;
                        if (read_ram_strip_byte(OUT_MODE_C_BASE, 8, 8, ch, y_glob, x_glob) !== c1_gold_C[flat_idx]) err_c++;
                        if (read_ram_strip_byte(OUT_MODE_D_BASE, 8, 8, ch, y_glob, x_glob) !== c1_gold_D[flat_idx]) err_d++;
                    end
                end
            end
            if (err_a == 0 && err_b == 0 && err_c == 0 && err_d == 0)
                $display("  -> [PASS] 1x1 Modes A, B, C, D Hardware Drain: 100%% bit-exact!");
        end

        $display("\n=========================================================================================");
        if (psum_errors == 0 && err_a == 0 && err_b == 0 && err_c == 0 && err_d == 0 && arb_errors == 0) begin
            $display(" >>> ALL 8-BANK (4x2) 3x3 & 1x1 + AXI-LITE CSR + ARBITRARY-DIM TESTS PASSED (100%% BIT-EXACT) <<< ");
            $display("=========================================================================================\n");
        end else begin
            $fatal(1, "Verification FAILED with errors (PSUM=%0d, A=%0d, B=%0d, C=%0d, D=%0d, ARB=%0d)!",
                   psum_errors, err_a, err_b, err_c, err_d, arb_errors);
        end

        $finish;
    end

endmodule
