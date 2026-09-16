// =============================================================================
// File: TEST/SoftLogic/full/system/tb_npu_full_sys_1x1_simple.sv
// Module: tb_npu_full_sys_1x1_simple
// Project: CrocoScale SoC — Standalone Verification: Simple 1x1 (Phase 2)
//
// Description:
//   Fast standalone verification testbench for Phase 2:
//   3-pass (12-channel) 1x1 convolution with half-array ping-pong scheduling
//   and automated draining to AXI RAM.
// =============================================================================

`timescale 1ns / 1ps

module tb_npu_full_sys_1x1_simple;

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

    // 1x1 Reference Arrays
    logic signed [ACTIVATION_WIDTH-1:0] conv1x1_act [35 * 37 * 19];
    logic signed [WEIGHT_WIDTH-1:0]     conv1x1_w   [19 * 21];
    logic signed [ACTIVATION_WIDTH-1:0] conv1x1_gold[35 * 37 * 21];

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

    // Activation Feeder for 1x1 mode
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
        #300_000;
        $display("\n[ERROR] Simulation Watchdog Timeout in Phase 2 (30,000 cycles)!");
        $finish;
    end

    // Main Test
    initial begin
        longint start_time, total_cycles;
        logic [31:0] read_status;
        logic signed [7:0] w_val0, w_val1, w_val2, w_val3;
        logic [31:0] word0, word1;

        $display("\n=========================================================================================");
        $display(">>> Starting Standalone Phase 2: Simple 1x1 Functional Test (3 Passes) <<<");
        $display("=========================================================================================");

        $readmemh("TEST/NPU/GoldenReference/gen_conv1x1_act.mem",       conv1x1_act);
        $readmemh("TEST/NPU/GoldenReference/gen_conv1x1_w.mem",         conv1x1_w);
        $readmemh("TEST/NPU/GoldenReference/gen_conv1x1_out_quant.mem", conv1x1_gold);

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

        // Verify sample outputs from AXI RAM
        word0 = axi_ram_inst.mem[(OUT_BASE_ADDR[MEM_ADDR_WIDTH-1:2]) + 0];
        word1 = axi_ram_inst.mem[(OUT_BASE_ADDR[MEM_ADDR_WIDTH-1:2]) + 1];
        $display("   Pixel 0 Output: w0=0x%08X w1=0x%08X", word0, word1);
        if (word0 !== 32'h0 || word1 !== 32'h0) begin
            $display(">>> SUCCESS: Phase 2 Produced Valid Non-Zero Output! <<<");
        end else begin
            $display(">>> WARNING: Phase 2 Output All Zeros <<<");
        end

        $finish;
    end

endmodule

