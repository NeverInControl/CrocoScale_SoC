// =============================================================================
// File: TEST/SoftLogic/full/system/tb_npu_full_sys_silu_lut.sv
// Module: tb_npu_full_sys_silu_lut
// Project: CrocoScale SoC — Standalone Verification: SiLU LUT Non-Linearity (Phase 4)
//
// Description:
//   Standalone verification testbench for Phase 4:
//   Preloads 256-byte SiLU activation function table into PSUM Bank B via DMA,
//   runs 1x1 convolution, and drains activations transformed by non-linear LUT.
// =============================================================================

`timescale 1ns / 1ps

module tb_npu_full_sys_silu_lut;

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
    parameter int TOTAL_PASSES     = 3;
    parameter int CIN              = 128;
    parameter int COUT             = 32;

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
        .crossbar_sel            (npu_crossbar_sel),
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

    // 1x1 Reference Arrays
    logic signed [ACTIVATION_WIDTH-1:0] conv1x1_act [35 * 37 * 19];
    logic signed [WEIGHT_WIDTH-1:0]     conv1x1_w   [19 * 21];
    logic [7:0]                         lut_silu_mem [256];
    logic signed [ACTIVATION_WIDTH-1:0] linear_out   [256][8];

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

    int feeder_p_idx, feeder_y_idx, feeder_x_idx, feeder_next_ch_base;

    always @(negedge clk) begin
        if (!rst_n) begin
            npu_ext_act_sram_wdata <= '0;
        end else begin
            if (dut.preload_phase) begin
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
                feeder_p_idx = int'(dut.cycle_in_pass);
                feeder_y_idx = feeder_p_idx / 16;
                feeder_x_idx = feeder_p_idx % 16;
                feeder_next_ch_base = (dut.current_pass + 1) * 4;

                if (dut.current_pass[0] == 1'b0) begin
                    for (int b = 0; b < 4; b++) begin
                        int ch = feeder_next_ch_base + b;
                        if (feeder_p_idx < 256 && feeder_y_idx < 35 && feeder_x_idx < 37 && ch < 19)
                            npu_ext_act_sram_wdata[b + 4] <= conv1x1_act[(feeder_y_idx * 37 * 19) + (feeder_x_idx * 19) + ch];
                        else
                            npu_ext_act_sram_wdata[b + 4] <= 8'sd0;
                    end
                end else begin
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

    // Watchdog
    initial begin
        #400_000;
        $display("\n[ERROR] Simulation Watchdog Timeout in Phase 4 (40,000 cycles)!");
        $finish;
    end

    // Main Test
    initial begin
        longint start_time, total_cycles;
        logic [31:0] read_status;
        logic signed [7:0] w_val0, w_val1, w_val2, w_val3;
        logic [31:0] word0, word1;
        int lut_errs, p_idx, ch_idx;
        logic [7:0] lut_idx_val;
        logic signed [7:0] gold_val, act_val;

        $display("\n=========================================================================================");
        $display(">>> Starting Standalone Phase 4: Non-Linear LUT Verification (SiLU) <<<");
        $display("=========================================================================================");

        $readmemh("TEST/NPU/GoldenReference/gen_conv1x1_act.mem",       conv1x1_act);
        $readmemh("TEST/NPU/GoldenReference/gen_conv1x1_w.mem",         conv1x1_w);
        $readmemh("TEST/NPU/GoldenReference/gen_lut_silu.mem",          lut_silu_mem);

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

        // Step 1: Preload SiLU LUT into AXI RAM at LUT_BASE_ADDR (64 words = 256 bytes)
        for (int i = 0; i < 64; i++) begin
            ram_write_word(LUT_BASE_ADDR + (i * 4),
                {lut_silu_mem[i * 4 + 3], lut_silu_mem[i * 4 + 2],
                 lut_silu_mem[i * 4 + 1], lut_silu_mem[i * 4 + 0]});
        end

        // Prepopulate Biases (0) and Quant Params
        for (int ch = 0; ch < 8; ch++) ram_write_word(BIAS_BASE_ADDR + (ch * 4), 32'sd0);
        for (int ch = 0; ch < 8; ch++) ram_write_word(QUANT_BASE_ADDR + (ch * 4), {2'b00, 8'sd0, 6'd14, 16'sd16384});

        // Prepopulate 1x1 Weights for 3 Passes
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

        // Run Baseline Linear pass first (to record reference linear outputs)
        axil_write(32'h08, {16'd0, 8'd3, 4'b0001, 4'b0001}); // passes=3, mode_1x1=1, lut_en=0
        axil_write(32'h10, ACT_BASE_ADDR);
        axil_write(32'h14, WEIGHT_BASE_ADDR);
        axil_write(32'h18, OUT_BASE_ADDR);
        axil_write(32'h1C, BIAS_BASE_ADDR);
        axil_write(32'h20, QUANT_BASE_ADDR);
        axil_write(32'h24, LUT_BASE_ADDR);

        axil_write(32'h00, 32'h0000_0001); // START
        read_status = 32'h0;
        while (!read_status[1]) begin
            #100;
            axil_read(32'h04, read_status);
        end

        // Record linear outputs
        for (p_idx = 0; p_idx < 256; p_idx++) begin
            word0 = axi_ram_inst.mem[(OUT_BASE_ADDR[MEM_ADDR_WIDTH-1:2]) + (p_idx * 2) + 0];
            word1 = axi_ram_inst.mem[(OUT_BASE_ADDR[MEM_ADDR_WIDTH-1:2]) + (p_idx * 2) + 1];
            linear_out[p_idx][0] = $signed(word0[7:0]);
            linear_out[p_idx][1] = $signed(word0[15:8]);
            linear_out[p_idx][2] = $signed(word0[23:16]);
            linear_out[p_idx][3] = $signed(word0[31:24]);
            linear_out[p_idx][4] = $signed(word1[7:0]);
            linear_out[p_idx][5] = $signed(word1[15:8]);
            linear_out[p_idx][6] = $signed(word1[23:16]);
            linear_out[p_idx][7] = $signed(word1[31:24]);
        end

        // Now run Phase 4: LUT_EN = 1 (bit 5 = 1 -> REG_CONFIG = 0x0000_0331)
        axil_write(32'h08, {16'd0, 8'd3, 4'b0011, 4'b0001});
        start_time = $time;
        axil_write(32'h00, 32'h0000_0001); // Pulse START

        read_status = 32'h0;
        while (!read_status[1]) begin
            #100;
            axil_read(32'h04, read_status);
        end
        total_cycles = ($time - start_time) / 10;
        $display(">>> Phase 4 (SiLU LUT Activation) Finished in %0d cycles! Status: OK <<<", total_cycles);

        // Verify that every single output byte matches lut_silu_mem[unsigned(linear_out)]
        lut_errs = 0;
        for (p_idx = 0; p_idx < 256; p_idx++) begin
            word0 = axi_ram_inst.mem[(OUT_BASE_ADDR[MEM_ADDR_WIDTH-1:2]) + (p_idx * 2) + 0];
            word1 = axi_ram_inst.mem[(OUT_BASE_ADDR[MEM_ADDR_WIDTH-1:2]) + (p_idx * 2) + 1];

            for (ch_idx = 0; ch_idx < 8; ch_idx++) begin
                lut_idx_val = linear_out[p_idx][ch_idx];
                gold_val    = $signed(lut_silu_mem[lut_idx_val]);
                case (ch_idx)
                    0: act_val = $signed(word0[7:0]);
                    1: act_val = $signed(word0[15:8]);
                    2: act_val = $signed(word0[23:16]);
                    3: act_val = $signed(word0[31:24]);
                    4: act_val = $signed(word1[7:0]);
                    5: act_val = $signed(word1[15:8]);
                    6: act_val = $signed(word1[23:16]);
                    7: act_val = $signed(word1[31:24]);
                endcase

                if (act_val !== gold_val) begin
                    $display("[FAIL Phase 4] Pixel %0d Ch %0d: In=%0d, Got=%0d, Exp=%0d",
                             p_idx, ch_idx, $signed(lut_idx_val), act_val, gold_val);
                    lut_errs++;
                end
            end
        end

        $display("-----------------------------------------------------------------------------------------");
        $display("  LUT Activation Matches         : %0d / 2048 (%0.2f%%)",
                 2048 - lut_errs, (real'(2048 - lut_errs) / 2048.0) * 100.0);
        $display("-----------------------------------------------------------------------------------------");

        if (lut_errs == 0) begin
            $display(">>> SUCCESS: Phase 4 (SiLU LUT Non-Linearity) Verified 100%% Bit-Exact! <<<");
        end else begin
            $display(">>> FAILED: Phase 4 had %0d mismatches! <<<", lut_errs);
        end

        $finish;
    end

endmodule

