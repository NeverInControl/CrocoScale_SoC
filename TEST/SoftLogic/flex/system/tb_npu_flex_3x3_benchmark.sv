// =============================================================================
// File: TEST/SoftLogic/flex/system/tb_npu_flex_3x3_benchmark.sv
// Module: tb_npu_flex_3x3_benchmark
// Project: CrocoScale SoC — 8-Bank (4x2) 3x3 Soft-Logic + AXI-Lite + AXI4 Benchmark
//
// Description:
//   Full 36-block 3x3 convolution benchmark (48x48x128 -> 32, 144 passes/block,
//   5,184 passes total = 84,934,656 MACs) validating the 8-bank (4x2)
//   soft-logic sequencer (npu_flex_sequencer), AXI4-Lite CSR (npu_flex_axil_csr),
//   and AXI4 read engine (npu_flex_axi_reader) through the physical perimeter
//   BEL boundary harness (efpga_boundary_harness), AXI4 RAM (axi_ram), and
//   hardened NPU (npu_wrapper).
// =============================================================================

`timescale 1ns / 1ps

module tb_npu_flex_3x3_benchmark;

    parameter int ARRAY_HEIGHT     = 8;
    parameter int ARRAY_WIDTH      = 8;
    parameter int TILE_SIZE        = 16;
    parameter int ACT_HALO_PAD     = 2;
    parameter int ACTIVATION_WIDTH = 8;
    parameter int WEIGHT_WIDTH     = 8;
    parameter int PSUM_WIDTH       = 32;
    parameter int SCALE_WIDTH      = 16;
    parameter int WEIGHT_SPLIT     = 8;
    parameter int TOTAL_PASSES     = 144;
    parameter int CIN              = 128;
    parameter int COUT             = 32;

    localparam int CONV_H = 48;
    localparam int CONV_W = 48;
    localparam int POOL_H = 24;
    localparam int POOL_W = 24;

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

    localparam logic [31:0] ACT_BASE_ADDR    = 32'h0000_0000;
    localparam logic [31:0] OUT_BASE_ADDR    = 32'h0007_0000;
    localparam logic [31:0] WEIGHT_BASE_ADDR = 32'h0005_0000;
    localparam logic [31:0] BIAS_BASE_ADDR   = 32'h0006_0000;
    localparam logic [31:0] QUANT_BASE_ADDR  = 32'h0006_1000;
    localparam logic [31:0] LUT_BASE_ADDR    = 32'h0006_2000;

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
    // 1. System AXI4 RAM (512 KB, 32-bit AXI4 Slave)
    // =========================================================================
    axi_ram #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(19),
        .ID_WIDTH  (8),
        .PIPELINE_OUTPUT(0)
    ) sys_ram_inst (
        .clk          (clk),
        .rst          (~rst_n),
        .s_axi_awid   (8'd0),
        .s_axi_awaddr (m_axi_awaddr[18:0]),
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
        .s_axi_araddr (m_axi_araddr[18:0]),
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

    // =========================================================================
    // Reference Benchmark Arrays
    // =========================================================================
    logic signed [ACTIVATION_WIDTH-1:0] fmap_in [CONV_H * CONV_W * CIN];
    logic signed [WEIGHT_WIDTH-1:0]     w1_flat [3 * 3 * CIN * COUT];
    logic signed [31:0]                 b1_flat [COUT];
    logic [31:0]                        p1_cfg  [COUT];
    logic signed [ACTIVATION_WIDTH-1:0] gold_l1 [POOL_H * POOL_W * COUT];

    // Captured 16x16 unpooled tile output per block (36 blocks x 256 pixels x 8 channels)
    logic signed [7:0] drain_block_buf [0:35][0:255][0:7];

    int curr_block = 0;

    function automatic logic signed [7:0] get_weight_val(input int p, input int cout_b, input int r, input int c);
        int g_idx, cin_curr, tap_curr, ky_curr, kx_curr, ch_out;
        g_idx = p * 8 + r;
        if (g_idx < (CIN * 9)) begin
            cin_curr = g_idx / 9;
            tap_curr = g_idx % 9;
            ky_curr  = tap_curr / 3;
            kx_curr  = tap_curr % 3;
            ch_out   = cout_b * 8 + c;
            if (ch_out < COUT)
                return w1_flat[(ky_curr * 3 * CIN * COUT) + (kx_curr * CIN * COUT) + (cin_curr * COUT) + ch_out];
            else
                return 8'sd0;
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
    // Populate System AXI4 RAM (Untiled [C][H/4][W][4] + Weights/Bias/Quant)
    // =========================================================================
    task automatic populate_system_ram();
        int word_addr;
        logic [7:0] b0, b1, b2, b3;

        // 1. Untiled 4-Row Vertical Strip Activations: [C=128][H/4=12][W=48][4]
        for (int c = 0; c < CIN; c++) begin
            for (int strip = 0; strip < (CONV_H / 4); strip++) begin
                for (int gx = 0; gx < CONV_W; gx++) begin
                    b0 = fmap_in[((strip * 4 + 0) * CONV_W * CIN) + (gx * CIN) + c];
                    b1 = fmap_in[((strip * 4 + 1) * CONV_W * CIN) + (gx * CIN) + c];
                    b2 = fmap_in[((strip * 4 + 2) * CONV_W * CIN) + (gx * CIN) + c];
                    b3 = fmap_in[((strip * 4 + 3) * CONV_W * CIN) + (gx * CIN) + c];
                    word_addr = (ACT_BASE_ADDR >> 2) + c * ((CONV_H / 4) * CONV_W) + strip * CONV_W + gx;
                    sys_ram_inst.mem[word_addr] = {b3, b2, b1, b0};
                end
            end
        end

        // 2. Packed Weights per Cout Block (cout_b = 0..3) and Pass (p = 0..143)
        for (int cout_b = 0; cout_b < 4; cout_b++) begin
            for (int p = 0; p < TOTAL_PASSES; p++) begin
                for (int b = 0; b < 8; b++) begin
                    int col;
                    col = 7 - b;
                    b0 = get_weight_val(p, cout_b, 0, col);
                    b1 = get_weight_val(p, cout_b, 1, col);
                    b2 = get_weight_val(p, cout_b, 2, col);
                    b3 = get_weight_val(p, cout_b, 3, col);
                    word_addr = (WEIGHT_BASE_ADDR >> 2) + (cout_b * TOTAL_PASSES + p) * 16 + b;
                    sys_ram_inst.mem[word_addr] = {b3, b2, b1, b0};

                    b0 = get_weight_val(p, cout_b, 4, col);
                    b1 = get_weight_val(p, cout_b, 5, col);
                    b2 = get_weight_val(p, cout_b, 6, col);
                    b3 = get_weight_val(p, cout_b, 7, col);
                    word_addr = (WEIGHT_BASE_ADDR >> 2) + (cout_b * TOTAL_PASSES + p) * 16 + 8 + b;
                    sys_ram_inst.mem[word_addr] = {b3, b2, b1, b0};
                end
            end
        end

        // 3. Biases & Quantizer Configs per Cout Block (cout_b = 0..3)
        for (int cout_b = 0; cout_b < 4; cout_b++) begin
            for (int c = 0; c < 8; c++) begin
                sys_ram_inst.mem[(BIAS_BASE_ADDR  >> 2) + cout_b * 8 + c] = b1_flat[cout_b * 8 + c];
                sys_ram_inst.mem[(QUANT_BASE_ADDR >> 2) + cout_b * 8 + c] = p1_cfg[cout_b * 8 + (7 - c)];
            end
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

    // Watchdog (3,000,000 cycles)
    initial begin
        #30_000_000;
        $display("\n[ERROR] Simulation Watchdog Timeout in Benchmark!");
        $finish;
    end

    // =========================================================================
    // Main Benchmark Execution & Validation
    // =========================================================================
    initial begin
        string mem_dir;
        longint start_time, total_cycles;
        int max_blocks;
        int done_blks;
        int errs, tol_ok, exact_ok, max_diff, diff_val;
        int py, px, y_global, x_global, ch_global, flat_idx;
        logic signed [7:0] gold_val, act_val;

        if (!$value$plusargs("MAX_BLOCKS=%d", max_blocks)) begin
            max_blocks = 36;
        end

        $display("=====================================================================================");
        $display("   NPU 8-BANK (4x2) + AXI-LITE CSR + AXI4 BENCHMARK: 3x3 (48x48x128 -> 32, %0d BLKS) ", max_blocks);
        $display("=====================================================================================");

        resolve_mem_dir("bench_im2col_act.mem", mem_dir);
        $readmemh($sformatf("%sbench_im2col_act.mem",        mem_dir), fmap_in);
        $readmemh($sformatf("%sbench_im2col_w.mem",          mem_dir), w1_flat);
        $readmemh($sformatf("%sbench_im2col_b.mem",          mem_dir), b1_flat);
        $readmemh($sformatf("%sbench_im2col_cfg.mem",        mem_dir), p1_cfg);
        $readmemh($sformatf("%sbench_im2col_out_pooled.mem", mem_dir), gold_l1);

        populate_system_ram();

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

        repeat (5) @(negedge clk);
        rst_n = 1'b1;
        repeat (5) @(negedge clk);

        axil_write(REG_ACT_BASE, ACT_BASE_ADDR);
        axil_write(REG_LUT_BASE, LUT_BASE_ADDR);
        axil_write(REG_CONFIG,   {16'd0, 8'(TOTAL_PASSES), 8'h41}); // auto_drain=1, pool_en=1, lut_en=0

        done_blks  = 0;
        start_time = $time;

        for (int ty = 0; ty < 3; ty++) begin
            for (int tx = 0; tx < 3; tx++) begin
                for (int cout_b = 0; cout_b < 4; cout_b++) begin
                    if (done_blks < max_blocks) begin
                        curr_block = (ty * 3 + tx) * 4 + cout_b;

                        axil_write(REG_GEOM,        {8'(CIN), 8'(CONV_H), 8'(CONV_W), 4'(ty), 4'(tx)});
                        axil_write(REG_WEIGHT_BASE, WEIGHT_BASE_ADDR + cout_b * (TOTAL_PASSES * 64));
                        axil_write(REG_OUT_BASE,    OUT_BASE_ADDR    + cout_b * (8 * (POOL_H / 4) * POOL_W * 4));
                        axil_write(REG_BIAS_BASE,   BIAS_BASE_ADDR   + cout_b * 32);
                        axil_write(REG_QUANT_BASE,  QUANT_BASE_ADDR  + cout_b * 32);
                        axil_write(REG_CTRL,        32'h0000_0001);

                        while (!seq_done) @(posedge clk);
                        @(negedge clk);

                        done_blks++;
                        $display("  [Block %2d/%2d] Tile (%0d,%0d), Cout Blk %0d/4 | Cumulative Cycles: %0d",
                                 done_blks, max_blocks, ty, tx, cout_b + 1, ($time - start_time) / 10);
                    end
                end
            end
        end
        total_cycles = ($time - start_time) / 10;

        // Validate Pooled Outputs directly from System AXI4 RAM [C_out][POOL_H/4][POOL_W][4]
        errs = 0; tol_ok = 0; exact_ok = 0; max_diff = 0;
        for (int b_idx = 0; b_idx < max_blocks; b_idx++) begin
            int ty, tx, cout_b;
            ty     = (b_idx / 4) / 3;
            tx     = (b_idx / 4) % 3;
            cout_b = b_idx % 4;
            for (py = 0; py < 8; py++) begin
                for (px = 0; px < 8; px++) begin
                    y_global = ty * 8 + py;
                    x_global = tx * 8 + px;
                    for (int ch_idx = 0; ch_idx < 8; ch_idx++) begin
                        ch_global = cout_b * 8 + ch_idx;
                        flat_idx  = (y_global * POOL_W * COUT) + (x_global * COUT) + ch_global;
                        gold_val  = gold_l1[flat_idx];
                        act_val   = read_ram_strip_byte(
                            OUT_BASE_ADDR + cout_b * (8 * (POOL_H / 4) * POOL_W * 4),
                            POOL_H,
                            POOL_W,
                            ch_idx,
                            y_global,
                            x_global
                        );
                        diff_val = (act_val > gold_val) ? (act_val - gold_val) : (gold_val - act_val);
                        if (diff_val == 0) exact_ok++;
                        else if (diff_val <= 1) tol_ok++;
                        else errs++;
                        if (diff_val > max_diff) max_diff = diff_val;
                    end
                end
            end
        end

        $display("\n=====================================================================================");
        $display("   8-BANK (4x2) + AXI-LITE + AXI4 BENCHMARK SUMMARY (%0d BLOCKS, %0d POOLED OUTPUTS)",
                 max_blocks, max_blocks * 512);
        $display("=====================================================================================");
        $display("   Total Cycles          : %0d", total_cycles);
        $display("   Exact Matches (diff 0): %0d", exact_ok);
        $display("   Tol Matches   (diff 1): %0d", tol_ok);
        $display("   Errors        (diff>1): %0d (max diff: %0d)", errs, max_diff);
        $display("=====================================================================================\n");

        if (errs == 0 && (exact_ok + tol_ok) == max_blocks * 512) begin
            $display(">>> SUCCESS: 8-Bank (4x2) + AXI-Lite CSR + AXI4 Benchmark PASSED 100%%! <<<\n");
        end else begin
            $fatal(1, "8-Bank Benchmark Verification FAILED with %0d errors!", errs);
        end
        $finish;
    end

endmodule
