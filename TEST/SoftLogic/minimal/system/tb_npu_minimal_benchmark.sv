`timescale 1ns / 1ps

/* ===============================================================================================
 * File: TEST/SoftLogic/minimal/system/tb_npu_minimal_benchmark.sv
 * Module: tb_npu_minimal_benchmark
 * Project: CrocoScale SoC -- eFPGA NPU Minimal Soft-Logic Multi-Block Benchmark Suite
 *
 * Description:
 *   Full 36-block benchmark testbench for the minimal soft-logic controller:
 *   - Evaluates 3x3 halo convolution across a 3x3 spatial grid (48x48 input -> 48x48 output)
 *     and 4 output channel blocks (32 output channels total), yielding 36 total blocks.
 *   - Incorporates the efpga_boundary_harness with perimeter BEL bitstream configuration.
 *   - Loads the exact same dataset files as the full-system benchmark:
 *       bench_im2col_act.mem, bench_im2col_w.mem, bench_im2col_b.mem, bench_im2col_cfg.mem
 *   - Reports hardware efficiency metrics (Compute Array Eff, End-to-End System Eff, Throughput)
 *     and bit-exact validation statistics matching the full soft-logic benchmark suite.
 *
 * NOTE: Multi-block full-scale benchmarking is intended for Vivado xsim on the host system.
 * =============================================================================================== */

module tb_npu_minimal_benchmark;

    parameter int ARRAY_HEIGHT     = 8;
    parameter int ARRAY_WIDTH      = 8;
    parameter int TILE_SIZE        = 16;
    parameter int ACT_HALO_PAD     = 2;
    parameter int ACTIVATION_WIDTH = 8;
    parameter int WEIGHT_WIDTH     = 8;
    parameter int PSUM_WIDTH       = 32;
    parameter int SCALE_WIDTH      = 16;
    parameter int WEIGHT_SPLIT     = 8;
    parameter int AXI_ADDR_WIDTH   = 32;
    parameter int AXI_DATA_WIDTH   = 32;

    localparam int CONV_H          = 48;
    localparam int CONV_W          = 48;
    localparam int CIN             = 128;
    localparam int COUT            = 32;
    localparam int TOTAL_BLOCKS    = 36; // 3x3 spatial tiles x 4 output channel blocks

    // Clock and Reset
    logic clk;
    logic rst_n;

    // AXI-Lite Slave Interface (Host -> Boundary Harness SoC Ports)
    logic [AXI_ADDR_WIDTH-1:0] s_axil_awaddr;
    logic [2:0]                s_axil_awprot;
    logic                      s_axil_awvalid;
    wire                       s_axil_awready;

    logic [AXI_DATA_WIDTH-1:0] s_axil_wdata;
    logic [3:0]                s_axil_wstrb;
    logic                      s_axil_wvalid;
    wire                       s_axil_wready;

    wire  [1:0]                s_axil_bresp;
    wire                       s_axil_bvalid;
    logic                      s_axil_bready;

    logic [AXI_ADDR_WIDTH-1:0] s_axil_araddr;
    logic [2:0]                s_axil_arprot;
    logic                      s_axil_arvalid;
    wire                       s_axil_arready;

    wire  [AXI_DATA_WIDTH-1:0] s_axil_rdata;
    wire  [1:0]                s_axil_rresp;
    wire                       s_axil_rvalid;
    logic                      s_axil_rready;

    // AXI4 Master Interface (Boundary Harness SoC Ports -> AXI RAM)
    wire  [AXI_ADDR_WIDTH-1:0] m_axi_awaddr;
    wire  [7:0]                m_axi_awlen;
    wire  [2:0]                m_axi_awsize;
    wire  [1:0]                m_axi_awburst;
    wire                       m_axi_awlock;
    wire  [3:0]                m_axi_awcache;
    wire                       m_axi_awvalid;
    wire                       m_axi_awready;

    wire  [AXI_DATA_WIDTH-1:0] m_axi_wdata;
    wire  [3:0]                m_axi_wstrb;
    wire                       m_axi_wlast;
    wire                       m_axi_wvalid;
    wire                       m_axi_wready;

    wire  [1:0]                m_axi_bresp;
    wire                       m_axi_bvalid;
    wire                       m_axi_bready;

    wire  [AXI_ADDR_WIDTH-1:0] m_axi_araddr;
    wire  [7:0]                m_axi_arlen;
    wire  [2:0]                m_axi_arsize;
    wire  [1:0]                m_axi_arburst;
    wire                       m_axi_arlock;
    wire  [3:0]                m_axi_arcache;
    wire                       m_axi_arvalid;
    wire                       m_axi_arready;

    wire  [AXI_DATA_WIDTH-1:0] m_axi_rdata;
    wire  [1:0]                m_axi_rresp;
    wire                       m_axi_rlast;
    wire                       m_axi_rvalid;
    wire                       m_axi_rready;

    // Boundary Harness Fabric-Facing Wires (DUT <-> Harness)
    wire  [9:0]                fab_axil_awaddr;
    wire  [2:0]                fab_axil_awprot;
    wire                       fab_axil_awvalid;
    wire                       fab_axil_awready;
    wire  [31:0]               fab_axil_wdata;
    wire  [3:0]                fab_axil_wstrb;
    wire                       fab_axil_wvalid;
    wire                       fab_axil_wready;
    wire  [1:0]                fab_axil_bresp;
    wire                       fab_axil_bvalid;
    wire                       fab_axil_bready;
    wire  [9:0]                fab_axil_araddr;
    wire  [2:0]                fab_axil_arprot;
    wire                       fab_axil_arvalid;
    wire                       fab_axil_arready;
    wire  [31:0]               fab_axil_rdata;
    wire  [1:0]                fab_axil_rresp;
    wire                       fab_axil_rvalid;
    wire                       fab_axil_rready;

    wire  [31:0]               fab_axi_awaddr;
    wire  [7:0]                fab_axi_awlen;
    wire                       fab_axi_awvalid;
    wire                       fab_axi_awready;
    wire  [31:0]               fab_axi_wdata;
    wire                       fab_axi_wlast;
    wire                       fab_axi_wvalid;
    wire                       fab_axi_wready;
    wire  [1:0]                fab_axi_bresp;
    wire                       fab_axi_bvalid;
    wire                       fab_axi_bready;
    wire  [31:0]               fab_axi_araddr;
    wire  [7:0]                fab_axi_arlen;
    wire                       fab_axi_arvalid;
    wire                       fab_axi_arready;
    wire  [31:0]               fab_axi_rdata;
    wire  [1:0]                fab_axi_rresp;
    wire                       fab_axi_rlast;
    wire                       fab_axi_rvalid;
    wire                       fab_axi_rready;

    wire                       fab_npu_array_en;
    wire                       fab_npu_psum_systolic_en;
    wire                       fab_npu_psum_lut_en;
    wire                       fab_npu_compute_bank_swap;
    wire  signed [7:0][7:0]    fab_weight_shift_in;
    wire  [7:0]                fab_weight_shift_en;
    wire                       fab_npu_swap_weights;
    wire  [29:0]               fab_npu_quant_shift_in;
    wire                       fab_npu_quant_shift_en;
    wire  [7:0]                fab_psum_A_addr;
    wire  [7:0]                fab_psum_A_we;
    wire  signed [31:0]        fab_psum_A_wdata;
    wire  [2:0]                fab_psum_A_read_bank_sel;
    wire  signed [31:0]        fab_psum_A_rdata;
    wire  [7:0]                fab_psum_B_addr;
    wire  [7:0]                fab_psum_B_we;
    wire  signed [31:0]        fab_psum_B_wdata;
    wire  [2:0]                fab_psum_B_read_bank_sel;
    wire  signed [31:0]        fab_psum_B_rdata;
    wire  [7:0]                fab_ext_act_sram_we;
    wire  [7:0][8:0]           fab_ext_act_sram_addr;
    wire  signed [7:0][7:0]    fab_ext_act_sram_wdata;
    wire  signed [7:0][7:0]    fab_act_sram_rdata;
    wire  signed [7:0][7:0]    fab_out_act;
    wire  [3:0]                fab_slot_soft_rst_n;
    wire  [3:0]                fab_usr_irq;

    // Boundary Harness NPU-Facing Wires (Harness <-> npu_wrapper)
    wire                       npu_array_en;
    wire                       npu_psum_systolic_en;
    wire                       npu_psum_lut_en;
    wire                       npu_psum_skew_en;
    wire                       npu_compute_bank_swap;
    wire  [7:0][3:0]           npu_crossbar_sel;
    wire  signed [7:0][7:0]    npu_weight_shift_in;
    wire  [7:0]                npu_weight_shift_en;
    wire                       npu_swap_weights;
    wire  [29:0]               npu_quant_shift_in;
    wire                       npu_quant_shift_en;
    wire  [7:0]                npu_psum_A_addr;
    wire  [7:0]                npu_psum_A_we;
    wire  signed [31:0]        npu_psum_A_wdata;
    wire  [2:0]                npu_psum_A_read_bank_sel;
    wire  signed [31:0]        npu_psum_A_rdata;
    wire  [7:0]                npu_psum_B_addr;
    wire  [7:0]                npu_psum_B_we;
    wire  signed [31:0]        npu_psum_B_wdata;
    wire  [2:0]                npu_psum_B_read_bank_sel;
    wire  signed [31:0]        npu_psum_B_rdata;
    wire  [7:0]                npu_ext_act_sram_we;
    wire  [7:0][8:0]           npu_ext_act_sram_addr;
    wire  signed [7:0][7:0]    npu_ext_act_sram_wdata;
    wire  signed [7:0][7:0]    npu_act_sram_rdata;
    wire  signed [7:0][7:0]    npu_out_act;
    wire  [3:0]                efpga_usr_irq_o;

    // Clock Generation: 100 MHz (10ns period)
    initial clk = 0;
    always #5 clk = ~clk;

    // 1 MB System AXI RAM
    localparam int MEM_ADDR_WIDTH      = 20;
    localparam [31:0] ACT_BASE_ADDR    = 32'h0000_0000;
    localparam [31:0] WEIGHT_BASE_ADDR = 32'h0006_0000;
    localparam [31:0] BIAS_BASE_ADDR   = 32'h0007_0000;
    localparam [31:0] QUANT_BASE_ADDR  = 32'h0007_0100;
    localparam [31:0] OUT_BASE_ADDR    = 32'h0008_0000;

    axi_ram #(
        .DATA_WIDTH     (AXI_DATA_WIDTH),
        .ADDR_WIDTH     (MEM_ADDR_WIDTH),
        .ID_WIDTH       (1),
        .PIPELINE_OUTPUT(0)
    ) axi_ram_inst (
        .clk            (clk),
        .rst            (~rst_n),

        .s_axi_awid     (1'b0),
        .s_axi_awaddr   (m_axi_awaddr[MEM_ADDR_WIDTH-1:0]),
        .s_axi_awlen    (m_axi_awlen),
        .s_axi_awsize   (m_axi_awsize),
        .s_axi_awburst  (m_axi_awburst),
        .s_axi_awlock   (m_axi_awlock),
        .s_axi_awcache  (m_axi_awcache),
        .s_axi_awprot   (3'b000),
        .s_axi_awvalid  (m_axi_awvalid),
        .s_axi_awready  (m_axi_awready),

        .s_axi_wdata    (m_axi_wdata),
        .s_axi_wstrb    (m_axi_wstrb),
        .s_axi_wlast    (m_axi_wlast),
        .s_axi_wvalid   (m_axi_wvalid),
        .s_axi_wready   (m_axi_wready),

        .s_axi_bid      (),
        .s_axi_bresp    (m_axi_bresp),
        .s_axi_bvalid   (m_axi_bvalid),
        .s_axi_bready   (m_axi_bready),

        .s_axi_arid     (1'b0),
        .s_axi_araddr   (m_axi_araddr[MEM_ADDR_WIDTH-1:0]),
        .s_axi_arlen    (m_axi_arlen),
        .s_axi_arsize   (m_axi_arsize),
        .s_axi_arburst  (m_axi_arburst),
        .s_axi_arlock   (m_axi_arlock),
        .s_axi_arcache  (m_axi_arcache),
        .s_axi_arprot   (3'b000),
        .s_axi_arvalid  (m_axi_arvalid),
        .s_axi_arready  (m_axi_arready),

        .s_axi_rdata    (m_axi_rdata),
        .s_axi_rresp    (m_axi_rresp),
        .s_axi_rlast    (m_axi_rlast),
        .s_axi_rvalid   (m_axi_rvalid),
        .s_axi_rready   (m_axi_rready)
    );

    // =========================================================================
    // Perimeter BEL Boundary Test Harness
    // =========================================================================
    efpga_boundary_harness #(
        .ARRAY_HEIGHT    (ARRAY_HEIGHT),
        .ARRAY_WIDTH     (ARRAY_WIDTH),
        .ACTIVATION_WIDTH(ACTIVATION_WIDTH),
        .WEIGHT_WIDTH    (WEIGHT_WIDTH),
        .PSUM_WIDTH      (PSUM_WIDTH),

        .CFG_AXI_M       (12'hF3E),
        .CFG_SLICE       ({6'h1E, 6'h1A, 6'h16, 6'h12, 6'h0E, 6'h0A, 6'h06, 6'h02}),
        .CFG_NPU_CTRL    (1'b0),
        .CFG_DEBUG       (16'h0004)
    ) harness_inst (
        .clk_i                   (clk),

        // SoC Facing Ports
        .s_axil_awaddr           (s_axil_awaddr[9:0]),
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
        .s_axil_araddr           (s_axil_araddr[9:0]),
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

        .soc_debug_out_i         ('0),
        .soc_debug_in_o          (),
        .soc_usr_irq_o           (efpga_usr_irq_o),
        .soc_slot_soft_rst_n_i   ({3'b0, rst_n}),

        // NPU Facing Ports
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
        .fab_axi_awvalid         (fab_axi_awvalid),
        .fab_axi_awready         (fab_axi_awready),
        .fab_axi_wdata           (fab_axi_wdata),
        .fab_axi_wlast           (fab_axi_wlast),
        .fab_axi_wvalid          (fab_axi_wvalid),
        .fab_axi_wready          (fab_axi_wready),
        .fab_axi_bresp           (fab_axi_bresp),
        .fab_axi_bvalid          (fab_axi_bvalid),
        .fab_axi_bready          (fab_axi_bready),
        .fab_axi_araddr          (fab_axi_araddr),
        .fab_axi_arlen           (fab_axi_arlen),
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
        .fab_npu_psum_skew_en    (fab_npu_psum_systolic_en),
        .fab_npu_compute_bank_swap(fab_npu_compute_bank_swap),
        .fab_npu_swap_weights    (fab_npu_swap_weights),
        .fab_npu_quant_shift_in  (fab_npu_quant_shift_in),
        .fab_npu_quant_shift_en  (fab_npu_quant_shift_en),
        .fab_crossbar_sel        ('0),
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
        .fab_psum_A_read_bank_sel(fab_psum_A_read_bank_sel),
        .fab_psum_A_rdata        (fab_psum_A_rdata),
        .fab_psum_B_addr         (fab_psum_B_addr),
        .fab_psum_B_we           (fab_psum_B_we),
        .fab_psum_B_wdata        (fab_psum_B_wdata),
        .fab_psum_B_read_bank_sel(fab_psum_B_read_bank_sel),
        .fab_psum_B_rdata        (fab_psum_B_rdata),

        .fab_debug_out_o         (),
        .fab_debug_in_i          ('0),
        .fab_usr_irq_i           (fab_usr_irq),
        .fab_slot_soft_rst_n_o   (fab_slot_soft_rst_n)
    );

    // =========================================================================
    // NPU Hardware Complex Instance (npu_wrapper)
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
    ) npu_wrapper_inst (
        .clk_i              (clk),
        .rst_n              (rst_n),

        .array_en           (npu_array_en),
        .psum_systolic_en   (npu_psum_systolic_en),
        .psum_lut_en        (npu_psum_lut_en),
        .psum_skew_en       (npu_psum_skew_en),
        .compute_bank_swap  (npu_compute_bank_swap),
        .crossbar_sel       (npu_crossbar_sel),

        .weight_shift_in    (npu_weight_shift_in),
        .weight_shift_en    (npu_weight_shift_en),
        .swap_weights       (npu_swap_weights),

        .quant_shift_in     (npu_quant_shift_in),
        .quant_shift_en     (npu_quant_shift_en),
        .stochastic_round_en(1'b0),
        .lfsr_data_out      (),

        .psum_A_addr        (npu_psum_A_addr),
        .psum_A_we          (npu_psum_A_we),
        .psum_A_wdata       (npu_psum_A_wdata),
        .psum_A_read_bank_sel(npu_psum_A_read_bank_sel),
        .psum_A_rdata       (npu_psum_A_rdata),

        .psum_B_addr        (npu_psum_B_addr),
        .psum_B_we          (npu_psum_B_we),
        .psum_B_wdata       (npu_psum_B_wdata),
        .psum_B_read_bank_sel(npu_psum_B_read_bank_sel),
        .psum_B_rdata       (npu_psum_B_rdata),

        .ext_act_sram_we    (npu_ext_act_sram_we),
        .ext_act_sram_addr  (npu_ext_act_sram_addr),
        .ext_act_sram_wdata (npu_ext_act_sram_wdata),
        .act_sram_rdata     (npu_act_sram_rdata),

        .out_act            (npu_out_act)
    );

    // =========================================================================
    // DUT: Minimal Soft-Logic Controller (KERNEL_SIZE = 3)
    // =========================================================================
    npu_min_controller #(
        .KERNEL_SIZE     (3),
        .ARRAY_HEIGHT    (ARRAY_HEIGHT),
        .ARRAY_WIDTH     (ARRAY_WIDTH),
        .TILE_SIZE       (TILE_SIZE),
        .ACT_HALO_PAD    (ACT_HALO_PAD),
        .ACTIVATION_WIDTH(ACTIVATION_WIDTH),
        .WEIGHT_WIDTH    (WEIGHT_WIDTH),
        .PSUM_WIDTH      (PSUM_WIDTH),
        .SCALE_WIDTH     (SCALE_WIDTH),
        .WEIGHT_SPLIT    (WEIGHT_SPLIT),
        .AXIL_ADDR_WIDTH (10),
        .AXI_ADDR_WIDTH  (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH  (AXI_DATA_WIDTH)
    ) dut_inst (
        .clk_i              (clk),
        .rst_n              (fab_slot_soft_rst_n[0]),

        .s_axil_awaddr      (fab_axil_awaddr),
        .s_axil_awprot      (fab_axil_awprot),
        .s_axil_awvalid     (fab_axil_awvalid),
        .s_axil_awready     (fab_axil_awready),
        .s_axil_wdata       (fab_axil_wdata),
        .s_axil_wstrb       (fab_axil_wstrb),
        .s_axil_wvalid      (fab_axil_wvalid),
        .s_axil_wready      (fab_axil_wready),
        .s_axil_bresp       (fab_axil_bresp),
        .s_axil_bvalid      (fab_axil_bvalid),
        .s_axil_bready      (fab_axil_bready),
        .s_axil_araddr      (fab_axil_araddr),
        .s_axil_arprot      (fab_axil_arprot),
        .s_axil_arvalid     (fab_axil_arvalid),
        .s_axil_arready     (fab_axil_arready),
        .s_axil_rdata       (fab_axil_rdata),
        .s_axil_rresp       (fab_axil_rresp),
        .s_axil_rvalid      (fab_axil_rvalid),
        .s_axil_rready      (fab_axil_rready),

        .m_axi_awaddr       (fab_axi_awaddr),
        .m_axi_awlen        (fab_axi_awlen),
        .m_axi_awsize       (),
        .m_axi_awburst      (),
        .m_axi_awvalid      (fab_axi_awvalid),
        .m_axi_awready      (fab_axi_awready),
        .m_axi_wdata        (fab_axi_wdata),
        .m_axi_wstrb        (),
        .m_axi_wlast        (fab_axi_wlast),
        .m_axi_wvalid       (fab_axi_wvalid),
        .m_axi_wready       (fab_axi_wready),
        .m_axi_bresp        (fab_axi_bresp),
        .m_axi_bvalid       (fab_axi_bvalid),
        .m_axi_bready       (fab_axi_bready),
        .m_axi_araddr       (fab_axi_araddr),
        .m_axi_arlen        (fab_axi_arlen),
        .m_axi_arsize       (),
        .m_axi_arburst      (),
        .m_axi_arvalid      (fab_axi_arvalid),
        .m_axi_arready      (fab_axi_arready),
        .m_axi_rdata        (fab_axi_rdata),
        .m_axi_rresp        (fab_axi_rresp),
        .m_axi_rlast        (fab_axi_rlast),
        .m_axi_rvalid       (fab_axi_rvalid),
        .m_axi_rready       (fab_axi_rready),

        .npu_array_en           (fab_npu_array_en),
        .npu_psum_systolic_en   (fab_npu_psum_systolic_en),
        .npu_psum_lut_en        (fab_npu_psum_lut_en),
        .npu_psum_skew_en       (),
        .npu_compute_bank_swap  (fab_npu_compute_bank_swap),
        .npu_crossbar_sel       (),

        .npu_weight_shift_in    (fab_weight_shift_in),
        .npu_weight_shift_en    (fab_weight_shift_en),
        .npu_swap_weights       (fab_npu_swap_weights),

        .npu_quant_shift_in     (fab_npu_quant_shift_in),
        .npu_quant_shift_en     (fab_npu_quant_shift_en),
        .npu_stochastic_round_en(),

        .npu_psum_A_addr        (fab_psum_A_addr),
        .npu_psum_A_we          (fab_psum_A_we),
        .npu_psum_A_wdata       (fab_psum_A_wdata),
        .npu_psum_A_read_bank_sel(fab_psum_A_read_bank_sel),
        .npu_psum_A_rdata       (fab_psum_A_rdata),

        .npu_psum_B_addr        (fab_psum_B_addr),
        .npu_psum_B_we          (fab_psum_B_we),
        .npu_psum_B_wdata       (fab_psum_B_wdata),
        .npu_psum_B_read_bank_sel(fab_psum_B_read_bank_sel),
        .npu_psum_B_rdata       (fab_psum_B_rdata),

        .npu_ext_act_sram_we    (fab_ext_act_sram_we),
        .npu_ext_act_sram_addr  (fab_ext_act_sram_addr),
        .npu_ext_act_sram_wdata (fab_ext_act_sram_wdata),
        .npu_act_sram_rdata     (fab_act_sram_rdata),
        .npu_out_act            (fab_out_act),
        .efpga_usr_irq_o        (fab_usr_irq)
    );

    // =========================================================================
    // Reference Arrays & Workload Memory
    // =========================================================================
    logic signed [ACTIVATION_WIDTH-1:0] fmap_in [CONV_H * CONV_W * CIN];
    logic signed [WEIGHT_WIDTH-1:0]     w1_flat [3 * 3 * CIN * COUT];
    logic signed [31:0]                 b1_flat [COUT];
    logic [31:0]                        p1_cfg  [COUT];
    logic signed [ACTIVATION_WIDTH-1:0] gold_act [TOTAL_BLOCKS * 16 * 16 * 8];

    // Direct AXI RAM Byte & Word Access
    task automatic ram_write_byte(input int addr, input logic signed [7:0] val);
        int word_addr = addr >> 2;
        int byte_lane = addr & 2'd3;
        case (byte_lane)
            2'd0: axi_ram_inst.mem[word_addr][7:0]   = val;
            2'd1: axi_ram_inst.mem[word_addr][15:8]  = val;
            2'd2: axi_ram_inst.mem[word_addr][23:16] = val;
            2'd3: axi_ram_inst.mem[word_addr][31:24] = val;
        endcase
    endtask

    task automatic ram_write_word(input int addr, input logic [31:0] val);
        int word_addr = addr >> 2;
        axi_ram_inst.mem[word_addr] = val;
    endtask

    task automatic ram_read_byte(input int addr, output logic signed [7:0] val);
        int word_addr = addr >> 2;
        int byte_lane = addr & 2'd3;
        case (byte_lane)
            2'd0: val = $signed(axi_ram_inst.mem[word_addr][7:0]);
            2'd1: val = $signed(axi_ram_inst.mem[word_addr][15:8]);
            2'd2: val = $signed(axi_ram_inst.mem[word_addr][23:16]);
            2'd3: val = $signed(axi_ram_inst.mem[word_addr][31:24]);
        endcase
    endtask

    // AXI-Lite MMIO Helper Tasks
    task automatic axil_write(input logic [31:0] addr, input logic [31:0] data);
        @(posedge clk);
        #1;
        s_axil_awaddr  = addr;
        s_axil_awvalid = 1'b1;
        s_axil_wdata   = data;
        s_axil_wstrb   = 4'hF;
        s_axil_wvalid  = 1'b1;
        s_axil_bready  = 1'b0;

        fork
            begin
                while (!s_axil_awready) @(posedge clk);
                @(posedge clk);
                #1;
                s_axil_awvalid = 1'b0;
            end
            begin
                while (!s_axil_wready) @(posedge clk);
                @(posedge clk);
                #1;
                s_axil_wvalid = 1'b0;
            end
        join

        while (!s_axil_bvalid) @(posedge clk);
        #1;
        s_axil_bready = 1'b1;
        @(posedge clk);
        #1;
        s_axil_bready = 1'b0;
    endtask

    task automatic axil_read(input logic [31:0] addr, output logic [31:0] data);
        @(posedge clk);
        #1;
        s_axil_araddr  = addr;
        s_axil_arvalid = 1'b1;
        s_axil_rready  = 1'b0;

        while (!s_axil_arready) @(posedge clk);
        @(posedge clk);
        #1;
        s_axil_arvalid = 1'b0;

        while (!s_axil_rvalid) @(posedge clk);
        #1;
        data = s_axil_rdata;
        s_axil_rready = 1'b1;
        @(posedge clk);
        #1;
        s_axil_rready = 1'b0;
    endtask

    // Memory File Path Resolution
    task automatic resolve_mem_dir(input string sample_file, output string mem_dir);
        int fd;
        int found;
        found = 0;

        if ($value$plusargs("MEM_DIR=%s", mem_dir)) begin
            if (mem_dir.len() > 0 && mem_dir[mem_dir.len()-1] != "/" && mem_dir[mem_dir.len()-1] != "\\")
                mem_dir = {mem_dir, "/"};
            fd = $fopen({mem_dir, sample_file}, "r");
            if (fd != 0) begin $fclose(fd); found = 1; end
        end

        if (!found) begin
            mem_dir = "TEST/GoldenReference/";
            fd = $fopen({mem_dir, sample_file}, "r");
            if (fd != 0) begin $fclose(fd); found = 1; end
        end

        if (!found) begin
            $display("\n=====================================================================================");
            $display(" [FATAL ERROR] Required test vector file '%s' was NOT found!", sample_file);
            $display(" Checked plusarg path and standard default 'TEST/GoldenReference/'.");
            $display(" Please provide a valid path via +MEM_DIR=<path> (e.g. in Vivado simulation settings).");
            $display("=====================================================================================\n");
            $fatal(1, "Aborting simulation due to missing test vector files.");
        end
    endtask

    task automatic check_file_exists(input string filename);
        int fd;
        fd = $fopen(filename, "r");
        if (fd == 0) begin
            $display("\n[FATAL ERROR] Required memory file '%s' was NOT found!", filename);
            $fatal(1, "Aborting simulation due to missing test vector files.");
        end
        $fclose(fd);
    endtask

    task automatic assert_vector_nonzero(
        input string vec_name,
        input int nonzero_count,
        input int min_required = 1
    );
        if (nonzero_count < min_required) begin
            $display("\n[FATAL ERROR] Vector '%s' contains NO non-zero elements (%0d found, min %0d required)!",
                     vec_name, nonzero_count, min_required);
            $fatal(1, "Zero-data assertion failure on vector: %s", vec_name);
        end
    endtask

    function automatic string get_progress_bar(input int current, input int total);
        string bar;
        int filled;
        bar = "[";
        filled = (current * 20) / total;
        for (int i = 0; i < 20; i++) begin
            if (i < filled) bar = {bar, "="};
            else if (i == filled) bar = {bar, ">"};
            else bar = {bar, " "};
        end
        bar = {bar, "]"};
        return bar;
    endfunction

    function automatic logic signed [7:0] requantize(
        input logic signed [31:0] psum,
        input logic signed [15:0] scale_m0,
        input int shift_n,
        input logic signed [7:0] zp
    );
        logic signed [47:0] prod;
        logic signed [47:0] round_offset;
        logic signed [47:0] rounded_prod;
        logic signed [47:0] shifted_val;
        logic signed [47:0] offset_val;

        prod = psum * scale_m0;
        if (shift_n > 0) begin
            round_offset = (48'sd1 <<< (shift_n - 1)) - (prod[47] ? 48'sd1 : 48'sd0);
        end else begin
            round_offset = 48'sd0;
        end
        rounded_prod = prod + round_offset;
        shifted_val  = rounded_prod >>> shift_n;
        offset_val   = shifted_val + zp;
        if (offset_val > 48'sd127) return 8'sd127;
        else if (offset_val < -48'sd128) return -8'sd128;
        else return offset_val[7:0];
    endfunction

    function automatic logic signed [31:0] get_hw_psum_mem0(input int ch);
        case (ch)
            0: return npu_wrapper_inst.gen_psum_srams[0].psum_sram_inst.mem[0];
            1: return npu_wrapper_inst.gen_psum_srams[1].psum_sram_inst.mem[0];
            2: return npu_wrapper_inst.gen_psum_srams[2].psum_sram_inst.mem[0];
            3: return npu_wrapper_inst.gen_psum_srams[3].psum_sram_inst.mem[0];
            4: return npu_wrapper_inst.gen_psum_srams[4].psum_sram_inst.mem[0];
            5: return npu_wrapper_inst.gen_psum_srams[5].psum_sram_inst.mem[0];
            6: return npu_wrapper_inst.gen_psum_srams[6].psum_sram_inst.mem[0];
            7: return npu_wrapper_inst.gen_psum_srams[7].psum_sram_inst.mem[0];
            default: return 32'sd0;
        endcase
    endfunction

    // Simulation Watchdog: 50,000,000 cycles
    initial begin
        #500_000_000;
        $display("\n[ERROR] Simulation Watchdog Timeout in Benchmark (50,000,000 cycles)!");
        $finish;
    end

    // =========================================================================
    // Main Benchmark Scenario Execution
    // =========================================================================
    initial begin
        longint start_time, total_cycles;
        longint ideal_macs, ideal_cycles, compute_cycles;
        real compute_eff, e2e_eff;
        int errs, tol_ok, exact_ok, max_diff, diff_val;
        int p_idx, ch_idx, ch_global;
        int ty, tx, cout_b, block_idx, done_blks;
        int tile_id, flat_idx;
        logic [31:0] read_status;
        string mem_dir;
        int nz_act, nz_w, nz_b, nz_cfg, nz_gold;
        logic signed [7:0] act_val, gold_val;
        int i_init, p, s, ci, co, ky, kx, cb, cin_curr;
        int gy, gx, mem_addr, y, x;
        int max_blocks;
        int ch_exact [8], ch_tol [8], ch_err [8];
        int print_err_cnt, c;
        logic signed [31:0] diag_hw_psum, diag_math_psum;
        logic signed [15:0] diag_scale_m0;
        int diag_shift_n, d_ky, d_kx, d_ci, d_gy, d_gx;
        logic signed [7:0] diag_zp, diag_req_hw, diag_req_math, diag_axi_act, diag_gold;

        $display("=====================================================================================");
        $display("   NPU SCALING EVALUATION: 3x3 CONVOLUTION (MINIMAL SOFT-LOGIC BENCHMARK)            ");
        $display("=====================================================================================");
        $display("   Input Tensor Dimensions  : 48x48 (Height x Width), 128 Channels");
        $display("   Output Tensor Dimensions : 48x48 (Height x Width), 32 Channels");
        $display("   Kernel Configuration     : 3x3 Conv, Stride 1, SAME Padding");
        $display("   Spatial Partitioning     : 3x3 Tiles of 16x16 (Exact 100%% Spatial Alignment)");
        $display("   Channel Processing       : 4 Output Channel Blocks (Exact 100%% Channel Alignment)");
        $display("   Total Workload Execution : 36 Total Blocks | 144 Passes/Block (5,184 Passes Total)");
        $display("   Reduction Depth (K_total): 1152 Taps -> 144 Passes (8 Taps/Pass continuous streaming)");
        $display("   Harness Configuration    : efpga_boundary_harness (CFG_AXI_M=12'hF3E, CFG_SLICE=48'h1E1A16120E0A0602)");
        $display("   Memory Persistence       : Multi-Block In-Place AXI RAM Retention (No Reset/Wipe)");
        $display("=====================================================================================\n");

        resolve_mem_dir("bench_im2col_act.mem", mem_dir);
        $display("[INFO] Resolved memory directory: '%s'", mem_dir);

        check_file_exists({mem_dir, "bench_im2col_act.mem"});
        check_file_exists({mem_dir, "bench_im2col_w.mem"});
        check_file_exists({mem_dir, "bench_im2col_b.mem"});
        check_file_exists({mem_dir, "bench_im2col_cfg.mem"});
        check_file_exists({mem_dir, "bench_im2col_out_quant.mem"});

        $readmemh({mem_dir, "bench_im2col_act.mem"},       fmap_in);
        $readmemh({mem_dir, "bench_im2col_w.mem"},         w1_flat);
        $readmemh({mem_dir, "bench_im2col_b.mem"},         b1_flat);
        $readmemh({mem_dir, "bench_im2col_cfg.mem"},       p1_cfg);
        $readmemh({mem_dir, "bench_im2col_out_quant.mem"}, gold_act);

        nz_act = 0; nz_w = 0; nz_b = 0; nz_cfg = 0; nz_gold = 0;
        for (i_init = 0; i_init < $size(fmap_in); i_init++) if (fmap_in[i_init] !== 8'sd0) nz_act++;
        for (i_init = 0; i_init < $size(w1_flat); i_init++) if (w1_flat[i_init] !== 8'sd0) nz_w++;
        for (i_init = 0; i_init < $size(b1_flat); i_init++) if (b1_flat[i_init] !== 32'sd0) nz_b++;
        for (i_init = 0; i_init < $size(p1_cfg);  i_init++) if (p1_cfg[i_init]  !== 32'd0)  nz_cfg++;
        for (i_init = 0; i_init < $size(gold_act); i_init++) if (gold_act[i_init] !== 8'sd0) nz_gold++;

        $display("[INFO] Loaded test vectors: %0d non-zero activations, %0d non-zero weights, %0d non-zero biases, %0d non-zero golden outputs.",
                 nz_act, nz_w, nz_b, nz_gold);

        assert_vector_nonzero("fmap_in",  nz_act, 10);
        assert_vector_nonzero("w1_flat",  nz_w, 10);
        assert_vector_nonzero("b1_flat",  nz_b, 1);
        assert_vector_nonzero("gold_act", nz_gold, 10);

        rst_n          = 0;
        s_axil_awaddr  = '0;
        s_axil_awprot  = '0;
        s_axil_awvalid = '0;
        s_axil_wdata   = '0;
        s_axil_wstrb   = '0;
        s_axil_wvalid  = '0;
        s_axil_bready  = '0;
        s_axil_araddr  = '0;
        s_axil_arprot  = '0;
        s_axil_arvalid = '0;
        s_axil_rready  = '0;

        #50;
        @(negedge clk);
        rst_n = 1;
        #50;

        // Prepopulate Biases for all 4 output channel blocks (32 channels total)
        for (cout_b = 0; cout_b < 4; cout_b++) begin
            for (co = 0; co < 8; co++) begin
                ram_write_word(BIAS_BASE_ADDR + (cout_b * 32) + (co * 4), b1_flat[cout_b * 8 + co]);
            end
        end

        // Prepopulate Weights for all 4 output channel blocks (144 passes x 8x8 per block, systolic order)
        for (cout_b = 0; cout_b < 4; cout_b++) begin
            for (cb = 0; cb < 16; cb++) begin
                for (ky = 0; ky < 3; ky++) begin
                    for (kx = 0; kx < 3; kx++) begin
                        p = (cb * 9) + (ky * 3) + kx;
                        for (s = 0; s < 8; s++) begin
                            for (ci = 0; ci < 8; ci++) begin
                                co = 7 - s;
                                mem_addr = WEIGHT_BASE_ADDR + (cout_b * 144 * 64) + (p * 64) + (s * 8) + ci;
                                ram_write_byte(mem_addr, w1_flat[(ky * 3 * CIN * COUT) + (kx * CIN * COUT) + ((cb * 8 + ci) * COUT) + (cout_b * 8 + co)]);
                            end
                        end
                    end
                end
            end
        end

        // Prepopulate Spatial Tile Activations for all 9 spatial tiles across all 16 input chunks
        for (ty = 0; ty < 3; ty++) begin
            for (tx = 0; tx < 3; tx++) begin
                tile_id = ty * 3 + tx;
                for (cb = 0; cb < 16; cb++) begin
                    for (y = 0; y < 18; y++) begin
                        for (x = 0; x < 18; x++) begin
                            gy = ty * 16 + y - 1;
                            gx = tx * 16 + x - 1;
                            for (ci = 0; ci < 8; ci++) begin
                                cin_curr = cb * 8 + ci;
                                mem_addr = ACT_BASE_ADDR + (tile_id * 16 * 2592) + (cb * 2592) + ((y * 18 + x) * 8) + ci;
                                if (gy >= 0 && gy < CONV_H && gx >= 0 && gx < CONV_W && cin_curr < CIN)
                                    ram_write_byte(mem_addr, fmap_in[(gy * CONV_W * CIN) + (gx * CIN) + cin_curr]);
                                else
                                    ram_write_byte(mem_addr, 8'sd0);
                            end
                        end
                    end
                end
            end
        end

        $display(">>> Prepopulation Complete. Beginning 36-Block Continuous Benchmark Execution <<<\n");

        done_blks  = 0;
        start_time = $time;

        if (!$value$plusargs("MAX_BLOCKS=%d", max_blocks)) max_blocks = TOTAL_BLOCKS;

        for (c = 0; c < 8; c++) begin
            ch_exact[c] = 0; ch_tol[c] = 0; ch_err[c] = 0;
        end

        for (ty = 0; ty < 3; ty++) begin
            for (tx = 0; tx < 3; tx++) begin
                for (cout_b = 0; cout_b < 4; cout_b++) begin
                    if (done_blks < max_blocks) begin
                        block_idx = (ty * 3 + tx) * 4 + cout_b;

                        // Program Minimal Soft-Logic Controller via AXI-Lite MMIO
                        axil_write(32'h08, ACT_BASE_ADDR + ((ty * 3 + tx) * 16 * 2592));
                        axil_write(32'h0C, WEIGHT_BASE_ADDR + (cout_b * 144 * 64));
                        axil_write(32'h10, OUT_BASE_ADDR + (block_idx * 2048));
                        axil_write(32'h14, BIAS_BASE_ADDR + (cout_b * 32));
                        for (c = 7; c >= 0; c--) begin
                            axil_write(32'h18, {2'b00, p1_cfg[cout_b * 8 + c][29:0]});
                        end
                        axil_write(32'h1C, {16'd0, 8'd144, 7'd0, 1'b1}); // TOTAL_PASSES=144, AUTO_DRAIN=1

                        // Trigger Execution
                        axil_write(32'h00, 32'h0000_0001);

                        // Poll for Block Completion
                        read_status = 32'h0;
                        while (!read_status[1]) begin
                            #500;
                            axil_read(32'h04, read_status);
                        end

                        done_blks++;
                        $display("  %s %3d%% (Block %2d/%0d) [Tile (%0d,%0d), Cout Blk %0d/4] | Latency: %8d cycles",
                                 get_progress_bar(done_blks, max_blocks),
                                 (done_blks * 100) / max_blocks, done_blks, max_blocks,
                                 ty, tx, cout_b + 1, ($time - start_time) / 10);

                        if (done_blks == 1) begin
                            $display("\n=========================================================================================");
                            $display("   [DIAGNOSTIC BLOCK 0 COMPLETED] DIRECT PSUM SRAM INSPECTION (Pixel 0, Channels 0..7)   ");
                            $display("=========================================================================================");
                            for (c = 0; c < 8; c++) begin
                                diag_hw_psum = get_hw_psum_mem0(c);
                                diag_math_psum = b1_flat[c];
                                for (d_ky = 0; d_ky < 3; d_ky++) begin
                                    d_gy = d_ky - 1;
                                    for (d_kx = 0; d_kx < 3; d_kx++) begin
                                        d_gx = d_kx - 1;
                                        if (d_gy >= 0 && d_gy < CONV_H && d_gx >= 0 && d_gx < CONV_W) begin
                                            for (d_ci = 0; d_ci < CIN; d_ci++) begin
                                                diag_math_psum = diag_math_psum +
                                                    (32'(fmap_in[(d_gy * CONV_W * CIN) + (d_gx * CIN) + d_ci]) *
                                                     32'(w1_flat[(d_ky * 3 * CIN * COUT) + (d_kx * CIN * COUT) + (d_ci * COUT) + c]));
                                            end
                                        end
                                    end
                                end
                                diag_scale_m0  = p1_cfg[c][15:0];
                                diag_shift_n   = p1_cfg[c][21:16];
                                diag_zp        = $signed(p1_cfg[c][29:22]);
                                diag_req_hw    = requantize(diag_hw_psum, diag_scale_m0, diag_shift_n, diag_zp);
                                diag_req_math  = requantize(diag_math_psum, diag_scale_m0, diag_shift_n, diag_zp);
                                ram_read_byte(OUT_BASE_ADDR + c, diag_axi_act);
                                diag_gold      = gold_act[c];
                                $display("  Ch %0d: HW_PSUM=%8d | Math_PSUM=%8d | Diff_PSUM=%6d | HW_Req=%4d | Math_Req=%4d | AXI_RAM=%4d | Gold=%4d",
                                         c, diag_hw_psum, diag_math_psum, diag_hw_psum - diag_math_psum,
                                         diag_req_hw, diag_req_math, diag_axi_act, diag_gold);
                            end
                            $display("=========================================================================================\n");
                        end
                    end
                end
            end
        end

        total_cycles = ($time - start_time) / 10;

        // Verify Output Tensor against Golden Reference
        $display("\n=========================================================================================");
        $display(">>> VALIDATING PERSISTENT OUTPUT TENSOR IN AXI RAM (%0d BLOCKS, %0d ACTIVATIONS) <<<",
                 done_blks, done_blks * 2048);
        $display("=========================================================================================");

        errs          = 0;
        tol_ok        = 0;
        exact_ok      = 0;
        max_diff      = 0;
        print_err_cnt = 0;

        for (ty = 0; ty < 3; ty++) begin
            for (tx = 0; tx < 3; tx++) begin
                for (cout_b = 0; cout_b < 4; cout_b++) begin
                    block_idx = (ty * 3 + tx) * 4 + cout_b;
                    if (block_idx < done_blks) begin

                    for (p_idx = 0; p_idx < 256; p_idx++) begin
                        gy = ty * 16 + (p_idx / 16);
                        gx = tx * 16 + (p_idx % 16);
                        for (ch_idx = 0; ch_idx < 8; ch_idx++) begin
                            ch_global = cout_b * 8 + ch_idx;
                            flat_idx  = (gy * CONV_W * COUT) + (gx * COUT) + ch_global;
                            gold_val  = gold_act[flat_idx];
                            ram_read_byte(OUT_BASE_ADDR + (block_idx * 2048) + (p_idx * 8) + ch_idx, act_val);

                            if ($isunknown(act_val)) begin
                                errs++;
                                ch_err[ch_idx]++;
                                max_diff = 255;
                                if (errs <= 10) begin
                                    $display("[FATAL] RAM activation at flat_idx=%0d (block=%0d, p=%0d, ch=%0d) is UNKNOWN (X)!",
                                             flat_idx, block_idx, p_idx, ch_idx);
                                end
                            end else begin
                                diff_val = (act_val > gold_val) ? (act_val - gold_val) : (gold_val - act_val);

                                if (diff_val == 0) begin
                                    exact_ok++;
                                    ch_exact[ch_idx]++;
                                end else if (diff_val <= 1) begin
                                    tol_ok++;
                                    ch_tol[ch_idx]++;
                                end else begin
                                    errs++;
                                    ch_err[ch_idx]++;
                                    if (print_err_cnt < 16) begin
                                        $display("  [MISMATCH #%0d] Block %0d (Tile %0d,%0d, Cout %0d) p=%0d (gy=%0d, gx=%0d) ch_local=%0d (ch_glob=%0d) | Act=%4d Gold=%4d Diff=%2d",
                                                 print_err_cnt + 1, block_idx, ty, tx, cout_b, p_idx, gy, gx, ch_idx, ch_global,
                                                 $signed(act_val), $signed(gold_val), diff_val);
                                        print_err_cnt++;
                                    end
                                end

                                if (diff_val > max_diff) max_diff = diff_val;
                            end
                        end
                    end
                end
            end
        end
    end

        $display("\n=========================================================================================");
        $display("   PER-CHANNEL VERIFICATION BREAKDOWN (Across Local Channels 0..7)                       ");
        $display("=========================================================================================");
        for (c = 0; c < 8; c++) begin
            $display("  Local Ch %0d: Exact=%5d | Tol(+/-1)=%5d | Err(>1)=%5d",
                     c, ch_exact[c], ch_tol[c], ch_err[c]);
        end
        $display("=========================================================================================");

        ideal_macs     = 64'd48 * 64'd48 * 64'd128 * 64'd32 * 64'd9; // 84,934,656 MACs
        ideal_cycles   = ideal_macs / 64;                             // 1,327,104 cycles
        compute_cycles = 64'd36 * 64'd144 * 64'd260;                  // 36 * 144 * 260 = 1,347,840 compute cycles
        compute_eff    = ($itor(ideal_cycles) / $itor(compute_cycles)) * 100.0;
        e2e_eff        = ($itor(ideal_cycles) / $itor(total_cycles)) * 100.0;

        $display("\n=========================================================================================");
        $display(">>> MINIMAL CONTROLLER BENCHMARK RESULTS (%0d BLOCKS, %0d PASSES) <<<",
                 done_blks, done_blks * 144);
        $display("=========================================================================================");
        $display("  Total Latency:         %0d clock cycles", total_cycles);
        $display("  Ideal Peak Cycles:     %0d clock cycles (at 64 MACs/cycle)", ideal_cycles);
        $display("  Mathematical MACs:     %0d operations", ideal_macs);
        $display("  Compute Array Eff:     %0.2f%%", compute_eff);
        $display("  End-to-End System Eff: %0.2f%%", e2e_eff);
        $display("  Sustained Throughput:  %0.2f MACs/cycle", ($itor(ideal_macs) / $itor(total_cycles)));
        $display("  Peak Theoretical:      64.00 MACs/cycle");
        $display("  Total Validated:       %0d activations", done_blks * 2048);
        $display("  Exact Matches (diff 0):%0d (%0.2f%%)", exact_ok, ($itor(exact_ok) / (done_blks * 2048.0)) * 100.0);
        $display("  Tol Matches   (diff 1):%0d (%0.2f%%)", tol_ok, ($itor(tol_ok) / (done_blks * 2048.0)) * 100.0);
        $display("  Errors        (diff >1):%0d", errs);
        $display("  Max Discrepancy:       %0d", max_diff);
        $display("=========================================================================================");

        if (errs == 0 && exact_ok > 0) begin
            $display(">>> SUCCESS: Minimal 36-Block Benchmark PASSED 100%%! <<<");
        end else begin
            $display(">>> FAILED: Benchmark had %0d mismatches across the output tensor! <<<", errs);
            $fatal(1, "Minimal benchmark verification failed!");
        end

        $finish;
    end

endmodule
