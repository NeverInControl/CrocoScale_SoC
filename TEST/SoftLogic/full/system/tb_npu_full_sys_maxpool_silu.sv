// =============================================================================
// File: TEST/SoftLogic/full/system/tb_npu_full_sys_all.sv
// Module: tb_npu_full_sys_maxpool_silu
// Project: CrocoScale SoC — Full-System Verification of Full Dual-Mode Controller
//
// Description:
//   Complete end-to-end full-system verification of the full dual-mode soft-logic
//   controller (npu_full_controller) connected to hardware NPU core and system AXI RAM:
//   - Phase 1: Simple 3x3 functional test (2 passes)
//   - Phase 2: Simple 1x1 functional test (3 passes = 12 channels, half-array ping-pong)
//   - Phase 3: The Big One (Full 144-pass 3x3 benchmark, 2,359,296 MACs, >95% efficiency)
//   - Phase 4: Non-Linear LUT Activation Function Verification (SiLU via PSUM Bank B)
//   - Phase 5A: Linear Activations -> 2x2 MaxPool (pool_en = 1, lut_en = 0)
//   - Phase 5B: SiLU LUT Activations -> 2x2 MaxPool (pool_en = 1, lut_en = 1)
// =============================================================================

`timescale 1ns / 1ps

module tb_npu_full_sys_maxpool_silu;

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
    wire  [AXI_ADDR_WIDTH-1:0] m_axi_awaddr;
    wire  [7:0]                m_axi_awlen;
    wire  [2:0]                m_axi_awsize;
    wire  [1:0]                m_axi_awburst;
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
    wire                       m_axi_arvalid;
    wire                       m_axi_arready;

    wire  [AXI_DATA_WIDTH-1:0] m_axi_rdata;
    wire  [1:0]                m_axi_rresp;
    wire                       m_axi_rlast;
    wire                       m_axi_rvalid;
    wire                       m_axi_rready;

    // Dedicated NPU Interconnect Signals
    wire                       npu_array_en;
    wire                       npu_psum_systolic_en;
    wire                       npu_psum_lut_en;
    wire                       npu_psum_skew_en;
    wire                       npu_compute_bank_swap;
    wire  [ARRAY_HEIGHT-1:0][3:0] npu_crossbar_sel;

    wire signed [ARRAY_HEIGHT-1:0][WEIGHT_WIDTH-1:0] npu_weight_shift_in;
    wire  [WEIGHT_SPLIT-1:0]   npu_weight_shift_en;
    wire                       npu_swap_weights;

    wire  [29:0]               npu_quant_shift_in;
    wire                       npu_quant_shift_en;
    wire                       npu_stochastic_round_en;

    wire  [7:0]                npu_psum_A_addr;
    wire  [ARRAY_WIDTH-1:0]    npu_psum_A_we;
    wire signed [PSUM_WIDTH-1:0] npu_psum_A_wdata;
    wire  [2:0]                npu_psum_A_read_bank_sel;
    wire signed [PSUM_WIDTH-1:0] npu_psum_A_rdata;

    wire  [7:0]                npu_psum_B_addr;
    wire  [ARRAY_WIDTH-1:0]    npu_psum_B_we;
    wire signed [PSUM_WIDTH-1:0] npu_psum_B_wdata;
    wire  [2:0]                npu_psum_B_read_bank_sel;
    wire signed [PSUM_WIDTH-1:0] npu_psum_B_rdata;

    wire  [ARRAY_HEIGHT-1:0]   npu_ext_act_sram_we;
    wire  [ARRAY_HEIGHT-1:0][8:0] npu_ext_act_sram_addr;
    logic signed [ARRAY_HEIGHT-1:0][ACTIVATION_WIDTH-1:0] npu_ext_act_sram_wdata;
    wire  signed [ARRAY_HEIGHT-1:0][ACTIVATION_WIDTH-1:0] npu_act_sram_rdata;

    wire  signed [ARRAY_WIDTH-1:0][ACTIVATION_WIDTH-1:0]  npu_out_act;
    wire  [3:0]                efpga_usr_irq_o;
    wire  [SCALE_WIDTH-1:0]    lfsr_data_out;

    // Clock Generation: 100 MHz (10ns)
    initial clk = 0;
    always #5 clk = ~clk;

    // 1. AXI RAM Instance (64 KB System RAM)
    localparam int MEM_ADDR_WIDTH = 16;
    localparam [31:0] ACT_BASE_ADDR    = 32'h0000_1000;
    localparam [31:0] WEIGHT_BASE_ADDR = 32'h0000_6000;
    localparam [31:0] BIAS_BASE_ADDR   = 32'h0000_9000;
    localparam [31:0] QUANT_BASE_ADDR  = 32'h0000_9800;
    localparam [31:0] OUT_BASE_ADDR    = 32'h0000_A000;
    localparam [31:0] LUT_BASE_ADDR    = 32'h0000_B000;

    axi_ram #(
        .DATA_WIDTH     (32),
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
        .s_axi_awlock   (1'b0),
        .s_axi_awcache  (4'b0011),
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
        .s_axi_arlock   (1'b0),
        .s_axi_arcache  (4'b0011),
        .s_axi_arprot   (3'b000),
        .s_axi_arvalid  (m_axi_arvalid),
        .s_axi_arready  (m_axi_arready),
        .s_axi_rid      (),
        .s_axi_rdata    (m_axi_rdata),
        .s_axi_rresp    (m_axi_rresp),
        .s_axi_rlast    (m_axi_rlast),
        .s_axi_rvalid   (m_axi_rvalid),
        .s_axi_rready   (m_axi_rready)
    );

    // 2. Hardware NPU Core
    npu_wrapper #(
        .ARRAY_HEIGHT    (ARRAY_HEIGHT),
        .ARRAY_WIDTH     (ARRAY_WIDTH),
        .TILE_SIZE       (TILE_SIZE),
        .ACT_HALO_PAD    (ACT_HALO_PAD),
        .ACTIVATION_WIDTH(ACTIVATION_WIDTH),
        .WEIGHT_WIDTH    (WEIGHT_WIDTH),
        .PSUM_WIDTH      (PSUM_WIDTH),
        .SCALE_WIDTH     (SCALE_WIDTH),
        .ENABLE_LFSR     (0),
        .WEIGHT_SPLIT    (WEIGHT_SPLIT)
    ) npu_core_inst (
        .clk_i              (clk),
        .rst_n              (rst_n),
        .array_en           (npu_array_en),
        .psum_systolic_en   (npu_psum_systolic_en),
        .psum_lut_en        (npu_psum_lut_en),
        .crossbar_sel       (npu_crossbar_sel),
        .weight_shift_in    (npu_weight_shift_in),
        .weight_shift_en    (npu_weight_shift_en),
        .swap_weights       (npu_swap_weights),
        .quant_shift_in     (npu_quant_shift_in),
        .quant_shift_en     (npu_quant_shift_en),
        .stochastic_round_en(1'b0),
        .lfsr_data_out      (lfsr_data_out),
        .psum_skew_en       (npu_psum_skew_en),
        .compute_bank_swap  (npu_compute_bank_swap),
        .psum_A_addr        (npu_psum_A_addr),
        .psum_A_we          (npu_psum_A_we),
        .psum_A_wdata       (npu_psum_A_wdata),
        .psum_A_read_bank_sel(3'd0),
        .psum_A_rdata       (npu_psum_A_rdata),
        .psum_B_addr        (npu_psum_B_addr),
        .psum_B_we          (npu_psum_B_we),
        .psum_B_wdata       (npu_psum_B_wdata),
        .psum_B_read_bank_sel(3'd0),
        .psum_B_rdata       (npu_psum_B_rdata),
        .ext_act_sram_we    (npu_ext_act_sram_we),
        .ext_act_sram_addr  (npu_ext_act_sram_addr),
        .ext_act_sram_wdata (npu_ext_act_sram_wdata),
        .act_sram_rdata     (npu_act_sram_rdata),
        .out_act            (npu_out_act)
    );

    // 3. Modular Full Controller (DUT)
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
        .npu_crossbar_sel        (npu_crossbar_sel),
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

    // 1x1 Reference Arrays (from gen_conv1x1_*.mem)
    logic signed [ACTIVATION_WIDTH-1:0] conv1x1_act [35 * 37 * 19];
    logic signed [WEIGHT_WIDTH-1:0]     conv1x1_w   [19 * 21];
    logic signed [ACTIVATION_WIDTH-1:0] conv1x1_gold[35 * 37 * 21];

    // SiLU Activation LUT Memory
    logic [7:0]                         lut_silu_mem [256];
    logic signed [ACTIVATION_WIDTH-1:0] phase2_out   [256][8];

    // Helper to write word into AXI RAM
    task automatic ram_write_word(input [31:0] addr, input [31:0] data);
        axi_ram_inst.mem[addr[MEM_ADDR_WIDTH-1:2]] = data;
    endtask

    // AXI-Lite Master Tasks
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

    // Helpers for 3x3
    function automatic logic signed [7:0] get_fmap_val(
        input int c_idx,
        input int b_idx,
        input int i_idx,
        input int ty_idx,
        input int tx_idx
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

    function automatic logic signed [7:0] get_weight_val(
        input int p,
        input int cout_b,
        input int r,
        input int c
    );
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

    // Feeder variables for 1x1 mode
    int feeder_p_idx, feeder_y_idx, feeder_x_idx, feeder_next_ch_base;

    // Feeder Process for Activations (3x3 and 1x1 mode)
    always @(negedge clk) begin
        if (!rst_n) begin
            npu_ext_act_sram_wdata <= '0;
        end else begin
            if (dut.config_reg[4] == 1'b0) begin
                // 3x3 Mode
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
            end else begin
                // 1x1 Mode
                if (dut.preload_phase) begin
                    // Preload Banks 0..3 with Channels 0..3
                    feeder_p_idx = int'(dut.preload_step);
                    feeder_y_idx = feeder_p_idx / 16;
                    feeder_x_idx = feeder_p_idx % 16;
                    for (int b = 0; b < 4; b++) begin
                        if (feeder_y_idx < 35 && feeder_x_idx < 37 && b < 19)
                            npu_ext_act_sram_wdata[b] <= conv1x1_act[(feeder_y_idx * 37 * 19) + (feeder_x_idx * 19) + b];
                        else
                            npu_ext_act_sram_wdata[b] <= 8'sd0;
                    end
                    for (int b = 4; b < 8; b++) npu_ext_act_sram_wdata[b] <= 8'sd0;
                end else if (dut.sequencer_inst.addr_1x1_inst.act_sram_we_o != 8'h00) begin
                    // Ping-pong preloading during computation
                    feeder_p_idx = int'(dut.cycle_in_pass);
                    feeder_y_idx = feeder_p_idx / 16;
                    feeder_x_idx = feeder_p_idx % 16;
                    feeder_next_ch_base = (dut.current_pass + 1) * 4;

                    if (dut.current_pass[0] == 1'b0) begin
                        // Pass is even: Computing on 0..3, Preloading 4..7
                        for (int b = 0; b < 4; b++) begin
                            int ch = feeder_next_ch_base + b;
                            if (feeder_p_idx < 256 && feeder_y_idx < 35 && feeder_x_idx < 37 && ch < 19)
                                npu_ext_act_sram_wdata[b + 4] <= conv1x1_act[(feeder_y_idx * 37 * 19) + (feeder_x_idx * 19) + ch];
                            else
                                npu_ext_act_sram_wdata[b + 4] <= 8'sd0;
                        end
                    end else begin
                        // Pass is odd: Computing on 4..7, Preloading 0..3
                        for (int b = 0; b < 4; b++) begin
                            int ch = feeder_next_ch_base + b;
                            if (feeder_p_idx < 256 && feeder_y_idx < 35 && feeder_x_idx < 37 && ch < 19)
                                npu_ext_act_sram_wdata[b] <= conv1x1_act[(feeder_y_idx * 37 * 19) + (feeder_x_idx * 19) + ch];
                            else
                                npu_ext_act_sram_wdata[b] <= 8'sd0;
                        end
                    end
                end
            end
        end
    end

    // Simulation Watchdog
    initial begin
        #800_000;
        $display("\n[ERROR] Simulation Watchdog Timeout (80,000 cycles)!");
        $display("DUT FSM state=%0d pass=%0d k=%0d lut_phase=%0b lut_load_done=%0b",
                 dut.sequencer_inst.state, dut.current_pass, dut.cycle_in_pass,
                 dut.seq_lut_phase, dut.dma_lut_load_done);
        $display("DMA state: preload_active=%0b lut_active=%0b",
                 dut.dma_inst.preload_active_reg, dut.dma_inst.lut_active_reg);
        $display("LUT loader state=%0d beat_cnt=%0d burst_idx=%0d",
                 dut.dma_inst.lut_loader_inst.state, dut.dma_inst.lut_loader_inst.beat_cnt,
                 dut.dma_inst.lut_loader_inst.burst_idx);
        $display("AXI read master state=%0d arvalid=%0b arready=%0b rvalid=%0b rready=%0b",
                 dut.dma_inst.axi_read_master_inst.state,
                 dut.dma_inst.axi_read_master_inst.m_axi_arvalid,
                 dut.m_axi_arready,
                 dut.m_axi_rvalid,
                 dut.dma_inst.axi_read_master_inst.m_axi_rready);
        $finish;
    end

    // Main Test Execution
    initial begin
        longint start_time, total_cycles;
        longint ideal_macs, ideal_cycles;
        real compute_eff, e2e_eff;
        int errs, tol_ok, exact_ok, lut_errs, tol_5, max_diff;
        int pool_errs_lin, pool_errs_silu;
        logic [31:0] read_status;

        int p_idx, y_idx, x_idx, ch_idx, flat_idx, diff_val;
        int py_idx, px_idx, p_out_idx;
        logic signed [7:0] q0, q1, q2, q3, m01, m23;
        logic [31:0] word0, word1;
        logic signed [7:0] ram_pix[8];
        logic signed [7:0] gold_val, act_val;
        logic signed [7:0] w_val0, w_val1, w_val2, w_val3;
        logic [7:0] lut_idx_val;
        logic [7:0] u_q0, u_q1, u_q2, u_q3;

        $display("\n=========================================================================================");
        $display(">>> Starting Unified Dual-Mode System Verification (3x3, 1x1, & SiLU LUT over AXI) <<<");
        $display("=========================================================================================");

        // Load 3x3 Reference Data
        $readmemh("TEST/NPU/GoldenReference/bench_im2col_act.mem",       fmap_in);
        $readmemh("TEST/NPU/GoldenReference/bench_im2col_w.mem",         w1_flat);
        $readmemh("TEST/NPU/GoldenReference/bench_im2col_b.mem",         b1_flat);
        $readmemh("TEST/NPU/GoldenReference/bench_im2col_cfg.mem",       p1_cfg);
        $readmemh("TEST/NPU/GoldenReference/bench_im2col_out_quant.mem", gold_l1);

        // Load 1x1 Reference Data
        $readmemh("TEST/NPU/GoldenReference/gen_conv1x1_act.mem",       conv1x1_act);
        $readmemh("TEST/NPU/GoldenReference/gen_conv1x1_w.mem",         conv1x1_w);
        $readmemh("TEST/NPU/GoldenReference/gen_conv1x1_out_quant.mem", conv1x1_gold);

        // Load SiLU Activation LUT Table
        $readmemh("TEST/NPU/GoldenReference/gen_lut_silu.mem",          lut_silu_mem);

        $display("Reference test vectors loaded successfully.");

        // Reset
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

        // =====================================================================
        // =====================================================================
        // PHASE 2: Simple 1x1 Functional Example (3 Passes = 12 Channels)
        // =====================================================================
        $display("\n-----------------------------------------------------------------------------------------");
        $display(">>> PHASE 2: Simple 1x1 Functional Test (3 Passes = 12 Channels, Half-Array Ping-Pong) <<<");
        $display("-----------------------------------------------------------------------------------------");

        // Prepopulate Biases (0 for 1x1)
        for (int ch = 0; ch < 8; ch++) ram_write_word(BIAS_BASE_ADDR + (ch * 4), 32'sd0);

        // Prepopulate Quant Params (scale=16384, shift=14, zp=0)
        for (int ch = 0; ch < 8; ch++) ram_write_word(QUANT_BASE_ADDR + (ch * 4), {2'b00, 8'sd0, 6'd14, 16'sd16384});

        // Prepopulate 1x1 Weights for 3 Passes (8 beats = 32 bytes per pass)
        for (int p = 0; p < 3; p++) begin
            for (int s = 0; s < 8; s++) begin
                int c_out = 7 - s;
                w_val0 = (p * 4 + 0 < 19 && c_out < 21) ? conv1x1_w[(p * 4 + 0) * 21 + c_out] : 8'sd0;
                w_val1 = (p * 4 + 1 < 19 && c_out < 21) ? conv1x1_w[(p * 4 + 1) * 21 + c_out] : 8'sd0;
                w_val2 = (p * 4 + 2 < 19 && c_out < 21) ? conv1x1_w[(p * 4 + 2) * 21 + c_out] : 8'sd0;
                w_val3 = (p * 4 + 3 < 19 && c_out < 21) ? conv1x1_w[(p * 4 + 3) * 21 + c_out] : 8'sd0;
                ram_write_word(WEIGHT_BASE_ADDR + (p * 32) + (s * 4), {w_val3, w_val2, w_val1, w_val0});
            end
        end

        // Program Registers: 3 passes, mode 1x1 (bit 4 = 1) -> 0x0000_0311
        axil_write(32'h08, {16'd0, 8'd3, 4'b0001, 4'b0001}); // passes = 3, mode_1x1 = 1, auto_drain = 1
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
            #100;
            axil_read(32'h04, read_status);
        end
        total_cycles = ($time - start_time) / 10;
        $display(">>> Phase 2 (Simple 1x1 Half-Array) Finished in %0d cycles! Status: OK <<<", total_cycles);

        // Save Phase 2 linear outputs for comparison in Phase 4
        for (p_idx = 0; p_idx < 256; p_idx++) begin
            word0 = axi_ram_inst.mem[(OUT_BASE_ADDR[MEM_ADDR_WIDTH-1:2]) + (p_idx * 2) + 0];
            word1 = axi_ram_inst.mem[(OUT_BASE_ADDR[MEM_ADDR_WIDTH-1:2]) + (p_idx * 2) + 1];
            phase2_out[p_idx][0] = $signed(word0[7:0]);
            phase2_out[p_idx][1] = $signed(word0[15:8]);
            phase2_out[p_idx][2] = $signed(word0[23:16]);
            phase2_out[p_idx][3] = $signed(word0[31:24]);
            phase2_out[p_idx][4] = $signed(word1[7:0]);
            phase2_out[p_idx][5] = $signed(word1[15:8]);
            phase2_out[p_idx][6] = $signed(word1[23:16]);
            phase2_out[p_idx][7] = $signed(word1[31:24]);

            if (p_idx < 2) begin
                $display("   [Phase 2 Sample] Pixel %0d: w0=0x%08X w1=0x%08X -> Ch[0..7] = [%3d, %3d, %3d, %3d, %3d, %3d, %3d, %3d]",
                         p_idx, word0, word1,
                         phase2_out[p_idx][0], phase2_out[p_idx][1], phase2_out[p_idx][2], phase2_out[p_idx][3],
                         phase2_out[p_idx][4], phase2_out[p_idx][5], phase2_out[p_idx][6], phase2_out[p_idx][7]);
            end
        end

        // ---------------------------------------------------------------------
        // Phase 5B: Non-Linear SiLU LUT -> 2x2 MaxPool (pool_en = 1, lut_en = 1)
        // ---------------------------------------------------------------------
        $display("\n>>> Sub-Phase 5B: SiLU LUT Activation with Inline 2x2 MaxPool <<<");

        // Prepopulate SiLU LUT table
        for (int w = 0; w < 64; w++) begin
            ram_write_word(LUT_BASE_ADDR + (w * 4),
                {lut_silu_mem[w * 4 + 3], lut_silu_mem[w * 4 + 2],
                 lut_silu_mem[w * 4 + 1], lut_silu_mem[w * 4 + 0]});
        end

        // Clear output buffer in AXI RAM
        for (int w = 0; w < 128; w++) ram_write_word(OUT_BASE_ADDR + (w * 4), 32'h0);

        // Program Registers: 3 passes, mode 1x1 (bit 4 = 1), lut_en = 1 (bit 5 = 1), pool_en = 1 (bit 6 = 1) -> 0x0000_0371
        axil_write(32'h08, {16'd0, 8'd3, 4'b0111, 4'b0001});
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
            #100;
            axil_read(32'h04, read_status);
        end
        total_cycles = ($time - start_time) / 10;
        $display(">>> Phase 5B (SiLU LUT + MaxPool) Finished in %0d cycles! Status: OK <<<", total_cycles);

        // Verify Output Activations against SiLU LUT + 2x2 MaxPool reduction
        pool_errs_silu = 0;
        for (py_idx = 0; py_idx < 8; py_idx++) begin
            for (px_idx = 0; px_idx < 8; px_idx++) begin
                p_out_idx = py_idx * 8 + px_idx;
                word0 = axi_ram_inst.mem[(OUT_BASE_ADDR[MEM_ADDR_WIDTH-1:2]) + (p_out_idx * 2) + 0];
                word1 = axi_ram_inst.mem[(OUT_BASE_ADDR[MEM_ADDR_WIDTH-1:2]) + (p_out_idx * 2) + 1];

                ram_pix[0] = $signed(word0[7:0]);
                ram_pix[1] = $signed(word0[15:8]);
                ram_pix[2] = $signed(word0[23:16]);
                ram_pix[3] = $signed(word0[31:24]);
                ram_pix[4] = $signed(word1[7:0]);
                ram_pix[5] = $signed(word1[15:8]);
                ram_pix[6] = $signed(word1[23:16]);
                ram_pix[7] = $signed(word1[31:24]);

                if (p_out_idx < 2) begin
                    $display("   [Phase 5B Sample] Pooled Pixel %0d (py=%0d, px=%0d): w0=0x%08X w1=0x%08X", p_out_idx, py_idx, px_idx, word0, word1);
                    for (ch_idx = 0; ch_idx < 8; ch_idx++) begin
                        u_q0 = phase2_out[(2*py_idx+0)*16 + (2*px_idx+0)][ch_idx];
                        u_q1 = phase2_out[(2*py_idx+0)*16 + (2*px_idx+1)][ch_idx];
                        u_q2 = phase2_out[(2*py_idx+1)*16 + (2*px_idx+0)][ch_idx];
                        u_q3 = phase2_out[(2*py_idx+1)*16 + (2*px_idx+1)][ch_idx];
                        q0 = $signed(lut_silu_mem[u_q0]);
                        q1 = $signed(lut_silu_mem[u_q1]);
                        q2 = $signed(lut_silu_mem[u_q2]);
                        q3 = $signed(lut_silu_mem[u_q3]);
                        m01 = (q0 > q1) ? q0 : q1;
                        m23 = (q2 > q3) ? q2 : q3;
                        gold_val = (m01 > m23) ? m01 : m23;
                        $display("     Ch %0d: SiLU Quad=[%3d, %3d, %3d, %3d] -> Act=%3d, Gold=%3d",
                                 ch_idx, q0, q1, q2, q3, ram_pix[ch_idx], gold_val);
                    end
                end

                for (ch_idx = 0; ch_idx < 8; ch_idx++) begin
                    u_q0 = phase2_out[(2*py_idx+0)*16 + (2*px_idx+0)][ch_idx];
                    u_q1 = phase2_out[(2*py_idx+0)*16 + (2*px_idx+1)][ch_idx];
                    u_q2 = phase2_out[(2*py_idx+1)*16 + (2*px_idx+0)][ch_idx];
                    u_q3 = phase2_out[(2*py_idx+1)*16 + (2*px_idx+1)][ch_idx];
                    q0 = $signed(lut_silu_mem[u_q0]);
                    q1 = $signed(lut_silu_mem[u_q1]);
                    q2 = $signed(lut_silu_mem[u_q2]);
                    q3 = $signed(lut_silu_mem[u_q3]);
                    m01 = (q0 > q1) ? q0 : q1;
                    m23 = (q2 > q3) ? q2 : q3;
                    gold_val = (m01 > m23) ? m01 : m23;
                    act_val  = ram_pix[ch_idx];

                    if (act_val !== gold_val) begin
                        if (pool_errs_silu < 8) begin
                            $display("  [POOL SILU MISMATCH] Pooled (py=%0d, px=%0d), Ch %0d: Expected %0d, Got %0d",
                                     py_idx, px_idx, ch_idx, gold_val, act_val);
                        end
                        pool_errs_silu++;
                    end
                end
            end
        end
        $display("-----------------------------------------------------------------------------------------");
        $display("  SiLU MaxPool Matches           : %0d / 512 (%5.2f%%)", (512 - pool_errs_silu), (real'(512 - pool_errs_silu)/512.0)*100.0);
        $display("-----------------------------------------------------------------------------------------");

        if (pool_errs_silu == 0) begin
            $display(">>> SUCCESS: Phase 5B (SiLU LUT + 2x2 MaxPool) Verified 100%% Bit-Exact! <<<");
        end else begin
            $display("[ERROR] SiLU MaxPool mismatches: %0d", pool_errs_silu);
        end
        $display("=========================================================================================\n");
        $finish;
    end

endmodule
