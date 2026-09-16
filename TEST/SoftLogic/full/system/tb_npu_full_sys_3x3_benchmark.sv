// =============================================================================
// File: TEST/SoftLogic/full/system/tb_npu_full_sys_3x3_benchmark.sv
// Module: tb_npu_full_sys_3x3_benchmark
// Project: CrocoScale SoC — Standalone Verification: The Big One (Phase 3)
//
// Description:
//   Standalone benchmark testbench for Phase 3:
//   Full 144-pass 3x3 im2col convolution (2,359,296 MACs) with full
//   hardware efficiency breakdown and bit-exact golden tensor comparison.
// =============================================================================

`timescale 1ns / 1ps

module tb_npu_full_sys_3x3_benchmark;

    parameter int ARRAY_HEIGHT     = 8;
    parameter int ARRAY_WIDTH      = 8;
    parameter int TILE_SIZE        = 16;
    parameter int ACT_HALO_PAD     = 2;
    parameter int ACTIVATION_WIDTH = 8;
    parameter int WEIGHT_WIDTH     = 8;
    parameter int PSUM_WIDTH       = 32;
    parameter int SCALE_WIDTH      = 16;
    parameter int WEIGHT_SPLIT     = 2;
    parameter int AXI_ADDR_WIDTH   = 32;
    parameter int AXI_DATA_WIDTH   = 32;
    parameter int TOTAL_PASSES     = 144;
    parameter int CIN              = 128;
    parameter int COUT             = 32;

    localparam int CONV_H = 48;
    localparam int CONV_W = 48;

    logic clk;
    logic rst_n;

    // AXI-Lite Slave Signals
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

    // AXI4 Master Signals
    wire [AXI_ADDR_WIDTH-1:0]  m_axi_awaddr;
    wire [7:0]                 m_axi_awlen;
    wire [2:0]                 m_axi_awsize;
    wire [1:0]                 m_axi_awburst;
    wire                       m_axi_awvalid;
    wire                       m_axi_awready;

    wire [AXI_DATA_WIDTH-1:0]  m_axi_wdata;
    wire [(AXI_DATA_WIDTH/8)-1:0] m_axi_wstrb;
    wire                       m_axi_wlast;
    wire                       m_axi_wvalid;
    wire                       m_axi_wready;

    wire [1:0]                 m_axi_bresp;
    wire                       m_axi_bvalid;
    wire                       m_axi_bready;

    wire [AXI_ADDR_WIDTH-1:0]  m_axi_araddr;
    wire [7:0]                 m_axi_arlen;
    wire [2:0]                 m_axi_arsize;
    wire [1:0]                 m_axi_arburst;
    wire                       m_axi_arvalid;
    wire                       m_axi_arready;

    wire [AXI_DATA_WIDTH-1:0]  m_axi_rdata;
    wire [1:0]                 m_axi_rresp;
    wire                       m_axi_rlast;
    wire                       m_axi_rvalid;
    wire                       m_axi_rready;

    // NPU Wrapper Interconnect Signals
    wire                       npu_array_en;
    wire                       npu_psum_systolic_en;
    wire                       npu_psum_lut_en;
    wire                       npu_psum_skew_en;
    wire                       npu_compute_bank_swap;
    wire [ARRAY_HEIGHT-1:0][3:0] npu_crossbar_sel;
    wire [ARRAY_WIDTH-1:0][WEIGHT_WIDTH-1:0] npu_weight_shift_in;
    wire [1:0]                 npu_weight_shift_en;
    wire                       npu_swap_weights;
    wire [SCALE_WIDTH-1:0]     npu_quant_shift_in;
    wire                       npu_quant_shift_en;
    wire                       npu_stochastic_round_en;
    wire [7:0]                 npu_psum_A_addr;
    wire [ARRAY_WIDTH-1:0]     npu_psum_A_we;
    wire [ARRAY_WIDTH-1:0][PSUM_WIDTH-1:0] npu_psum_A_wdata;
    wire                       npu_psum_A_read_bank_sel;
    wire [ARRAY_WIDTH-1:0][PSUM_WIDTH-1:0] npu_psum_A_rdata;
    wire [7:0]                 npu_psum_B_addr;
    wire [ARRAY_WIDTH-1:0]     npu_psum_B_we;
    wire [ARRAY_WIDTH-1:0][PSUM_WIDTH-1:0] npu_psum_B_wdata;
    wire                       npu_psum_B_read_bank_sel;
    wire [ARRAY_WIDTH-1:0][PSUM_WIDTH-1:0] npu_psum_B_rdata;
    wire [ARRAY_HEIGHT-1:0]    npu_ext_act_sram_we;
    wire [ARRAY_HEIGHT-1:0][8:0] npu_ext_act_sram_addr;
    logic [ARRAY_HEIGHT-1:0][ACTIVATION_WIDTH-1:0] npu_ext_act_sram_wdata;
    wire [ARRAY_HEIGHT-1:0][ACTIVATION_WIDTH-1:0] npu_act_sram_rdata;
    wire [ARRAY_WIDTH-1:0][ACTIVATION_WIDTH-1:0]  npu_out_act;
    wire [3:0]                 efpga_usr_irq_o;

    // Clock Generation (100 MHz)
    initial clk = 0;
    always #5 clk = ~clk;

    // 128 KB System AXI RAM
    localparam int MEM_ADDR_WIDTH = 17;
    axi_ram #(
        .DATA_WIDTH(AXI_DATA_WIDTH),
        .ADDR_WIDTH(MEM_ADDR_WIDTH)
    ) axi_ram_inst (
        .clk            (clk),
        .rst_n          (rst_n),
        .s_axi_awaddr   (m_axi_awaddr[MEM_ADDR_WIDTH-1:0]),
        .s_axi_awlen    (m_axi_awlen),
        .s_axi_awsize   (m_axi_awsize),
        .s_axi_awburst  (m_axi_awburst),
        .s_axi_awvalid  (m_axi_awvalid),
        .s_axi_awready  (m_axi_awready),
        .s_axi_wdata    (m_axi_wdata),
        .s_axi_wstrb    (m_axi_wstrb),
        .s_axi_wlast    (m_axi_wlast),
        .s_axi_wvalid   (m_axi_wvalid),
        .s_axi_wready   (m_axi_wready),
        .s_axi_bresp    (m_axi_bresp),
        .s_axi_bvalid   (m_axi_bvalid),
        .s_axi_bready   (m_axi_bready),
        .s_axi_araddr   (m_axi_araddr[MEM_ADDR_WIDTH-1:0]),
        .s_axi_arlen    (m_axi_arlen),
        .s_axi_arsize   (m_axi_arsize),
        .s_axi_arburst  (m_axi_arburst),
        .s_axi_arvalid  (m_axi_arvalid),
        .s_axi_arready  (m_axi_arready),
        .s_axi_rdata    (m_axi_rdata),
        .s_axi_rresp    (m_axi_rresp),
        .s_axi_rlast    (m_axi_rlast),
        .s_axi_rvalid   (m_axi_rvalid),
        .s_axi_rready   (m_axi_rready)
    );

    // NPU Core Wrapper
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
        .clk                (clk),
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
        .stochastic_round_en(npu_stochastic_round_en),
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

    // Full Controller (DUT)
    npu_full_controller #(
        .ARRAY_HEIGHT    (ARRAY_HEIGHT),
        .ARRAY_WIDTH     (ARRAY_WIDTH),
        .TILE_SIZE       (TILE_SIZE),
        .ACT_HALO_PAD    (ACT_HALO_PAD),
        .ACTIVATION_WIDTH(ACTIVATION_WIDTH),
        .WEIGHT_WIDTH    (WEIGHT_WIDTH),
        .PSUM_WIDTH      (PSUM_WIDTH),
        .SCALE_WIDTH     (SCALE_WIDTH),
        .WEIGHT_SPLIT    (WEIGHT_SPLIT),
        .AXI_ADDR_WIDTH  (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH  (AXI_DATA_WIDTH),
        .TOTAL_PASSES    (TOTAL_PASSES),
        .CIN             (CIN),
        .COUT            (COUT)
    ) dut (
        .clk_i                   (clk),
        .rst_n                   (rst_n),
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
        .m_axi_arvalid           (m_axi_arvalid),
        .m_axi_arready           (m_axi_arready),
        .m_axi_rdata             (m_axi_rdata),
        .m_axi_rresp             (m_axi_rresp),
        .m_axi_rlast             (m_axi_rlast),
        .m_axi_rvalid            (m_axi_rvalid),
        .m_axi_rready            (m_axi_rready),
        .npu_array_en            (npu_array_en),
        .npu_psum_systolic_en    (npu_psum_systolic_en),
        .npu_psum_lut_en         (npu_psum_lut_en),
        .npu_psum_skew_en        (npu_psum_skew_en),
        .npu_compute_bank_swap   (npu_compute_bank_swap),
        .crossbar_sel        (npu_crossbar_sel),
        .npu_weight_shift_in     (npu_weight_shift_in),
        .npu_weight_shift_en     (npu_weight_shift_en),
        .npu_swap_weights        (npu_swap_weights),
        .npu_quant_shift_in      (npu_quant_shift_in),
        .npu_quant_shift_en      (npu_quant_shift_en),
        .npu_stochastic_round_en (npu_stochastic_round_en),
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
        .npu_ext_act_sram_we     (npu_ext_act_sram_we),
        .npu_ext_act_sram_addr   (npu_ext_act_sram_addr),
        .npu_out_act             (npu_out_act),
        .efpga_usr_irq_o         (efpga_usr_irq_o)
    );

    // Reference Arrays
    logic signed [ACTIVATION_WIDTH-1:0] fmap_in [CONV_H * CONV_W * CIN];
    logic signed [WEIGHT_WIDTH-1:0]     w1_flat [3 * 3 * CIN * COUT];
    logic signed [31:0]                 b1_flat [COUT];
    logic [31:0]                        p1_cfg  [COUT];
    logic signed [ACTIVATION_WIDTH-1:0] gold_l1 [CONV_H * CONV_W * COUT];

    localparam [31:0] ACT_BASE_ADDR   = 32'h0000_0000;
    localparam [31:0] WEIGHT_BASE_ADDR= 32'h0001_0000;
    localparam [31:0] OUT_BASE_ADDR   = 32'h0001_8000;
    localparam [31:0] BIAS_BASE_ADDR  = 32'h0001_C000;
    localparam [31:0] QUANT_BASE_ADDR = 32'h0001_D000;
    localparam [31:0] LUT_BASE_ADDR   = 32'h0001_E000;

    task automatic ram_write_word(input [31:0] addr, input [31:0] data);
        axi_ram_inst.mem[addr[MEM_ADDR_WIDTH-1:2]] = data;
    endtask

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

    function automatic logic signed [7:0] get_fmap_val(
        input int c_idx, input int b_idx, input int i_idx, input int ty_idx, input int tx_idx
    );
        int ly_val, lx_val, gy_val, gx_val;
        ly_val = (b_idx / 2) + (i_idx / 9) * 3;
        lx_val = (b_idx % 2 == 1 ? 9 : 0) + (i_idx % 9);
        gy_val = ty_idx * 16 + ly_val - 1;
        gx_val = tx_idx * 16 + lx_val - 1;

        if (gy_val >= 0 && gy_val < CONV_H && gx_val >= 0 && gx_val < CONV_W && c_idx < CIN)
            return fmap_in[(gy_val * CONV_W * CIN) + (gx_val * CIN) + c_idx];
        else
            return 8'sd0;
    endfunction

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

    // Activation feeder for 3x3 mode
    always @(negedge clk) begin
        if (!rst_n) begin
            npu_ext_act_sram_wdata <= '0;
        end else begin
            if (dut.preload_phase) begin
                for (int b = 0; b < 6; b++) begin
                    npu_ext_act_sram_wdata[b] <= get_fmap_val(0, b, int'(dut.preload_step), 0, 0);
                end
                npu_ext_act_sram_wdata[6] <= '0;
                npu_ext_act_sram_wdata[7] <= '0;
            end else if (dut.dma_channel_to_load >= 0) begin
                for (int b = 0; b < 6; b++) begin
                    npu_ext_act_sram_wdata[b] <= get_fmap_val(
                        int'(dut.dma_channel_to_load), b, int'(dut.dma_bank_ptr[b]), 0, 0
                    );
                end
                npu_ext_act_sram_wdata[6] <= '0;
                npu_ext_act_sram_wdata[7] <= '0;
            end
        end
    end

    // Watchdog
    initial begin
        #800_000;
        $display("\n[ERROR] Simulation Watchdog Timeout in Benchmark (80,000 cycles)!");
        $finish;
    end

    // Main Test
    initial begin
        longint start_time, total_cycles;
        longint ideal_macs, ideal_cycles;
        real compute_eff, e2e_eff;
        int errs, tol_ok, exact_ok, max_diff, diff_val;
        int p_idx, y_idx, x_idx, ch_idx, flat_idx;
        logic [31:0] read_status;
        logic [31:0] word0, word1;
        logic signed [7:0] ram_pix[8];
        logic signed [7:0] gold_val, act_val;

        $display("\n=========================================================================================");
        $display(">>> Starting Standalone Phase 3: The Big One (144-Pass 3x3 Benchmark) <<<");
        $display("=========================================================================================");

        $readmemh("TEST/NPU/GoldenReference/bench_im2col_act.mem",       fmap_in);
        $readmemh("TEST/NPU/GoldenReference/bench_im2col_w.mem",         w1_flat);
        $readmemh("TEST/NPU/GoldenReference/bench_im2col_b.mem",         b1_flat);
        $readmemh("TEST/NPU/GoldenReference/bench_im2col_cfg.mem",       p1_cfg);
        $readmemh("TEST/NPU/GoldenReference/bench_im2col_out_quant.mem", gold_l1);

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

        // Prepopulate Biases & Per-Channel Quant Params for all 144 passes
        for (int ch = 0; ch < 8; ch++) ram_write_word(BIAS_BASE_ADDR + (ch * 4), b1_flat[ch]);
        for (int ch = 0; ch < 8; ch++) ram_write_word(QUANT_BASE_ADDR + (ch * 4), p1_cfg[ch]);

        // Prepopulate Weights for all 144 passes
        for (int p = 0; p < 144; p++) begin
            for (int s = 0; s < 8; s++) begin
                ram_write_word(WEIGHT_BASE_ADDR + (p * 64) + (s * 8) + 0,
                    {get_weight_val(p, 0, 3, 7 - s), get_weight_val(p, 0, 2, 7 - s),
                     get_weight_val(p, 0, 1, 7 - s), get_weight_val(p, 0, 0, 7 - s)});
                ram_write_word(WEIGHT_BASE_ADDR + (p * 64) + (s * 8) + 4,
                    {get_weight_val(p, 0, 7, 7 - s), get_weight_val(p, 0, 6, 7 - s),
                     get_weight_val(p, 0, 5, 7 - s), get_weight_val(p, 0, 4, 7 - s)});
            end
        end

        // Program Registers: 144 passes, mode 3x3
        axil_write(32'h08, {16'd0, 8'd144, 4'b0000, 4'b0001});
        axil_write(32'h10, ACT_BASE_ADDR);
        axil_write(32'h14, WEIGHT_BASE_ADDR);
        axil_write(32'h18, OUT_BASE_ADDR);
        axil_write(32'h1C, BIAS_BASE_ADDR);
        axil_write(32'h20, QUANT_BASE_ADDR);
        axil_write(32'h24, LUT_BASE_ADDR);

        start_time = $time;
        axil_write(32'h00, 32'h0000_0001); // Pulse START

        read_status = 32'h0;
        while (!read_status[1]) begin
            #500;
            axil_read(32'h04, read_status);
        end
        total_cycles = ($time - start_time) / 10;

        // Verify Output Tensor
        errs = 0;
        tol_ok = 0;
        exact_ok = 0;
        max_diff = 0;

        for (p_idx = 0; p_idx < 256; p_idx++) begin
            y_idx = p_idx / 16;
            x_idx = p_idx % 16;

            word0 = axi_ram_inst.mem[(OUT_BASE_ADDR[MEM_ADDR_WIDTH-1:2]) + (p_idx * 2) + 0];
            word1 = axi_ram_inst.mem[(OUT_BASE_ADDR[MEM_ADDR_WIDTH-1:2]) + (p_idx * 2) + 1];

            ram_pix[0] = $signed(word0[7:0]);
            ram_pix[1] = $signed(word0[15:8]);
            ram_pix[2] = $signed(word0[23:16]);
            ram_pix[3] = $signed(word0[31:24]);
            ram_pix[4] = $signed(word1[7:0]);
            ram_pix[5] = $signed(word1[15:8]);
            ram_pix[6] = $signed(word1[23:16]);
            ram_pix[7] = $signed(word1[31:24]);

            for (ch_idx = 0; ch_idx < 8; ch_idx++) begin
                flat_idx = (y_idx * CONV_W * COUT) + (x_idx * COUT) + ch_idx;
                gold_val = gold_l1[flat_idx];
                act_val  = ram_pix[ch_idx];
                diff_val = (act_val > gold_val) ? (act_val - gold_val) : (gold_val - act_val);

                if (diff_val == 0) exact_ok++;
                else if (diff_val <= 1) tol_ok++;
                else errs++;

                if (diff_val > max_diff) max_diff = diff_val;
            end
        end

        ideal_macs   = 144 * 256 * 64; // 2,359,296 MACs
        ideal_cycles = ideal_macs / 64; // 36,864 cycles
        compute_eff  = (real'(ideal_cycles) / real'(144 * 260)) * 100.0;
        e2e_eff      = (real'(ideal_cycles) / real'(total_cycles)) * 100.0;

        $display("\n=========================================================================================");
        $display(">>> BENCHMARK RESULTS (144 PASSES) <<<");
        $display("=========================================================================================");
        $display("  Total Latency:         %0d clock cycles", total_cycles);
        $display("  Ideal Compute Cycles:  %0d clock cycles", ideal_cycles);
        $display("  Compute Array Eff:     %0.2f%%", compute_eff);
        $display("  End-to-End System Eff: %0.2f%%", e2e_eff);
        $display("  Total Validated:       2048 activations");
        $display("  Exact Matches (diff 0):%0d", exact_ok);
        $display("  Tol Matches   (diff 1):%0d", tol_ok);
        $display("  Errors        (diff >1):%0d", errs);
        $display("  Max Discrepancy:       %0d", max_diff);
        $display("=========================================================================================");

        if (errs == 0) begin
            $display(">>> SUCCESS: 144-Pass Benchmark PASSED 100%%! <<<");
        end else begin
            $display(">>> FAILED: Benchmark had %0d mismatches! <<<", errs);
        end

        $finish;
    end

endmodule

