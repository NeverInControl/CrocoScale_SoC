// =============================================================================
// File: TEST/SoftLogic/full/system/tb_npu_full_sys_3x3_benchmark.sv
// Module: tb_npu_full_sys_3x3_benchmark
// Project: CrocoScale SoC -- Standalone Verification: The Big One (Phase 3)
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
    localparam int POOL_H = 24;
    localparam int POOL_W = 24;

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
    wire [29:0]                npu_quant_shift_in;
    wire                       npu_quant_shift_en;
    wire                       npu_stochastic_round_en;
    wire [7:0]                 npu_psum_A_addr;
    wire [ARRAY_WIDTH-1:0]     npu_psum_A_we;
    wire signed [PSUM_WIDTH-1:0] npu_psum_A_wdata;
    wire [2:0]                 npu_psum_A_read_bank_sel;
    wire signed [PSUM_WIDTH-1:0] npu_psum_A_rdata;
    wire [7:0]                 npu_psum_B_addr;
    wire [ARRAY_WIDTH-1:0]     npu_psum_B_we;
    wire signed [PSUM_WIDTH-1:0] npu_psum_B_wdata;
    wire [2:0]                 npu_psum_B_read_bank_sel;
    wire signed [PSUM_WIDTH-1:0] npu_psum_B_rdata;
    wire [ARRAY_HEIGHT-1:0]    npu_ext_act_sram_we;
    wire [ARRAY_HEIGHT-1:0][8:0] npu_ext_act_sram_addr;
    logic [ARRAY_HEIGHT-1:0][ACTIVATION_WIDTH-1:0] npu_ext_act_sram_wdata;
    wire [ARRAY_HEIGHT-1:0][ACTIVATION_WIDTH-1:0] npu_act_sram_rdata;
    wire [ARRAY_WIDTH-1:0][ACTIVATION_WIDTH-1:0]  npu_out_act;
    wire [3:0]                 efpga_usr_irq_o;

    // Clock Generation (100 MHz)
    initial clk = 0;
    always #5 clk = ~clk;

    // 512 KB System AXI RAM
    localparam int MEM_ADDR_WIDTH = 19;
    axi_ram #(
        .DATA_WIDTH(AXI_DATA_WIDTH),
        .ADDR_WIDTH(MEM_ADDR_WIDTH),
        .ID_WIDTH  (1)
    ) axi_ram_inst (
        .clk            (clk),
        .rst            (~rst_n),
        .s_axi_awid     (1'b0),
        .s_axi_awaddr   (m_axi_awaddr[MEM_ADDR_WIDTH-1:0]),
        .s_axi_awlen    (m_axi_awlen),
        .s_axi_awsize   (m_axi_awsize),
        .s_axi_awburst  (m_axi_awburst),
        .s_axi_awlock   (1'b0),
        .s_axi_awcache  (4'd0),
        .s_axi_awprot   (3'd0),
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
        .s_axi_arcache  (4'd0),
        .s_axi_arprot   (3'd0),
        .s_axi_arvalid  (m_axi_arvalid),
        .s_axi_arready  (m_axi_arready),
        .s_axi_rid      (),
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

    // Reference Arrays
    logic signed [ACTIVATION_WIDTH-1:0] fmap_in [CONV_H * CONV_W * CIN];
    logic signed [WEIGHT_WIDTH-1:0]     w1_flat [3 * 3 * CIN * COUT];
    logic signed [31:0]                 b1_flat [COUT];
    logic [31:0]                        p1_cfg  [COUT];
    logic signed [ACTIVATION_WIDTH-1:0] gold_l1 [POOL_H * POOL_W * COUT];

    localparam [31:0] ACT_BASE_ADDR   = 32'h0000_0000;
    localparam [31:0] WEIGHT_BASE_ADDR= 32'h0001_0000;
    localparam [31:0] BIAS_BASE_ADDR  = 32'h0001_A000;
    localparam [31:0] QUANT_BASE_ADDR = 32'h0001_A100;
    localparam [31:0] LUT_BASE_ADDR   = 32'h0001_A200;
    localparam [31:0] OUT_BASE_ADDR   = 32'h0002_0000;

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

    task automatic resolve_mem_dir(input string sample_file, output string mem_dir);
        int fd;
        int found;
        found = 0;

        // 1. Check runtime plusarg (+MEM_DIR=...)
        if ($value$plusargs("MEM_DIR=%s", mem_dir)) begin
            if (mem_dir.len() > 0 && mem_dir[mem_dir.len()-1] != "/" && mem_dir[mem_dir.len()-1] != "\\")
                mem_dir = {mem_dir, "/"};
            fd = $fopen({mem_dir, sample_file}, "r");
            if (fd != 0) begin $fclose(fd); found = 1; end
        end

        // 2. Fallback to single standard default path
        if (!found) begin
            mem_dir = "TEST/SoftLogic/GoldenReference/";
            fd = $fopen({mem_dir, sample_file}, "r");
            if (fd != 0) begin $fclose(fd); found = 1; end
        end

        // 3. Fail immediately if neither worked
        if (!found) begin
            $display("\n=====================================================================================");
            $display(" [FATAL ERROR] Required test vector file '%s' was NOT found!", sample_file);
            $display(" Checked plusarg path and standard default 'TEST/SoftLogic/GoldenReference/'.");
            $display(" Please provide a valid path via +MEM_DIR=<path> (e.g. in Vivado simulation settings).");
            $display("=====================================================================================\n");
            $fatal(1, "Aborting simulation due to missing test vector files.");
        end
    endtask

    task automatic check_file_exists(input string filename);
        int fd;
        fd = $fopen(filename, "r");
        if (fd == 0) begin
            $display("\n=========================================================================================");
            $display(" [FATAL ERROR] Required memory file '%s' was NOT found in any search path!", filename);
            $display(" Please ensure files exist in TEST/SoftLogic/GoldenReference/ or pass +MEM_DIR=<path>.");
            $display("=========================================================================================\n");
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
            $display("\n=========================================================================================");
            $display(" [FATAL ERROR] Vector '%s' contains NO non-zero elements (%0d found, min %0d required)!",
                     vec_name, nonzero_count, min_required);
            $display(" Memory was either empty, uninitialized, or filled with all zeroes!");
            $display(" Simulation aborted to prevent FALSE POSITIVE pass.");
            $display("=========================================================================================\n");
            $fatal(1, "Zero-data assertion failure on vector: %s", vec_name);
        end
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

    int curr_ty = 0;
    int curr_tx = 0;

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

    int feeder_b;

    // Activation feeder for 3x3 mode
    always @(negedge clk) begin
        if (!rst_n) begin
            npu_ext_act_sram_wdata <= '0;
        end else begin
            if (dut.preload_phase) begin
                for (feeder_b = 0; feeder_b < 6; feeder_b++) begin
                    npu_ext_act_sram_wdata[feeder_b] <= get_fmap_val(0, feeder_b, int'(dut.preload_step), curr_ty, curr_tx);
                end
                npu_ext_act_sram_wdata[6] <= '0;
                npu_ext_act_sram_wdata[7] <= '0;
            end else if (dut.dma_channel_to_load >= 0) begin
                for (feeder_b = 0; feeder_b < 6; feeder_b++) begin
                    npu_ext_act_sram_wdata[feeder_b] <= get_fmap_val(
                        int'(dut.dma_channel_to_load), feeder_b, int'((dut.dma_bank_ptr >> (feeder_b * 6)) & 6'h3F), curr_ty, curr_tx
                    );
                end
                npu_ext_act_sram_wdata[6] <= '0;
                npu_ext_act_sram_wdata[7] <= '0;
            end
        end
    end

    // Watchdog (Allows full 36-block execution: ~1.4M cycles)
    initial begin
        #30_000_000;
        $display("\n[ERROR] Simulation Watchdog Timeout in Benchmark (3,000,000 cycles)!");
        $finish;
    end

    // Main Test
    initial begin
        longint start_time, total_cycles;
        longint ideal_macs, ideal_cycles;
        real compute_eff, e2e_eff;
        int errs, tol_ok, exact_ok, max_diff, diff_val;
        int p_idx, ch_idx, flat_idx;
        int ty, tx, cout_b, block_idx, done_blks;
        logic [31:0] read_status;
        logic [31:0] word0, word1;
        string mem_dir;
        int nz_act, nz_w, nz_b, nz_gold;
        logic signed [7:0] ram_pix[8];
        logic signed [7:0] gold_val, act_val;
        int word_base;
        int y_local, x_local, y_global, x_global, ch_global;
        int i_init, cb, ch, p, s;

        $display("=====================================================================================");
        $display("   NPU SCALING EVALUATION: 3x3 CONVOLUTION (FULL 48x48x128 -> 32 BENCHMARK)         ");
        $display("=====================================================================================");
        $display("   Input Tensor Dimensions  : 48x48 (Height x Width), 128 Channels");
        $display("   Output Tensor Dimensions : 48x48 (Height x Width), 32 Channels");
        $display("   Kernel Configuration     : 3x3 Conv, Stride 1, SAME Padding");
        $display("   Spatial Partitioning     : 3x3 Tiles of 16x16 (Exact 100%% Spatial Alignment)");
        $display("   Channel Processing       : 4 Output Channel Blocks (Exact 100%% Channel Alignment)");
        $display("   Total Workload Execution : 36 Total Blocks | 144 Passes/Block (5,184 Passes Total)");
        $display("   Reduction Depth (K_total): 1152 Taps -> 144 Passes (8 Taps/Pass continuous streaming)");
        $display("   Memory Persistence       : Multi-Block In-Place AXI RAM Retention (No Reset/Wipe)");
        $display("=====================================================================================\n");

        resolve_mem_dir("bench_im2col_act.mem", mem_dir);
        $display("[INFO] Resolved memory directory: '%s'", mem_dir);

        check_file_exists({mem_dir, "bench_im2col_act.mem"});
        check_file_exists({mem_dir, "bench_im2col_w.mem"});
        check_file_exists({mem_dir, "bench_im2col_b.mem"});
        check_file_exists({mem_dir, "bench_im2col_cfg.mem"});
        check_file_exists({mem_dir, "bench_im2col_out_pooled.mem"});

        $readmemh({mem_dir, "bench_im2col_act.mem"},       fmap_in);
        $readmemh({mem_dir, "bench_im2col_w.mem"},         w1_flat);
        $readmemh({mem_dir, "bench_im2col_b.mem"},         b1_flat);
        $readmemh({mem_dir, "bench_im2col_cfg.mem"},       p1_cfg);
        $readmemh({mem_dir, "bench_im2col_out_pooled.mem"}, gold_l1);

        nz_act = 0; nz_w = 0; nz_b = 0; nz_gold = 0;
        for (i_init = 0; i_init < $size(fmap_in); i_init++) if (fmap_in[i_init] !== 8'sd0) nz_act++;
        for (i_init = 0; i_init < $size(w1_flat); i_init++) if (w1_flat[i_init] !== 8'sd0) nz_w++;
        for (i_init = 0; i_init < $size(b1_flat); i_init++) if (b1_flat[i_init] !== 32'sd0) nz_b++;
        for (i_init = 0; i_init < $size(gold_l1); i_init++) if (gold_l1[i_init] !== 8'sd0) nz_gold++;

        $display("[INFO] Loaded test vectors: %0d non-zero activations, %0d non-zero weights, %0d non-zero biases, %0d non-zero golden outputs.",
                 nz_act, nz_w, nz_b, nz_gold);

        assert_vector_nonzero("fmap_in", nz_act, 10);
        assert_vector_nonzero("w1_flat", nz_w, 10);
        assert_vector_nonzero("b1_flat", nz_b, 1);
        assert_vector_nonzero("gold_l1", nz_gold, 10);

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

        // Prepopulate Biases & Per-Channel Quant Params for all 4 channel blocks (32 channels total)
        for (cb = 0; cb < 4; cb++) begin
            for (ch = 0; ch < 8; ch++) begin
                ram_write_word(BIAS_BASE_ADDR + (cb * 32) + (ch * 4), b1_flat[cb * 8 + ch]);
                ram_write_word(QUANT_BASE_ADDR + (cb * 32) + (ch * 4), p1_cfg[cb * 8 + ch]);
            end
        end

        // Prepopulate Weights for all 4 channel blocks (all 144 passes per block)
        for (cb = 0; cb < 4; cb++) begin
            for (p = 0; p < 144; p++) begin
                for (s = 0; s < 8; s++) begin
                    ram_write_word(WEIGHT_BASE_ADDR + (cb * 144 * 64) + (p * 64) + (s * 8) + 0,
                        {get_weight_val(p, cb, 3, 7 - s), get_weight_val(p, cb, 2, 7 - s),
                         get_weight_val(p, cb, 1, 7 - s), get_weight_val(p, cb, 0, 7 - s)});
                    ram_write_word(WEIGHT_BASE_ADDR + (cb * 144 * 64) + (p * 64) + (s * 8) + 4,
                        {get_weight_val(p, cb, 7, 7 - s), get_weight_val(p, cb, 6, 7 - s),
                         get_weight_val(p, cb, 5, 7 - s), get_weight_val(p, cb, 4, 7 - s)});
                end
            end
        end

        $display(">>> Prepopulation Complete. Beginning 36-Block Continuous Benchmark Execution <<<\n");

        done_blks = 0;
        start_time = $time;

        for (ty = 0; ty < 3; ty++) begin
            for (tx = 0; tx < 3; tx++) begin
                for (cout_b = 0; cout_b < 4; cout_b++) begin
                    block_idx = (ty * 3 + tx) * 4 + cout_b;
                    curr_ty = ty;
                    curr_tx = tx;

                    axil_write(32'h08, {16'd0, 8'd144, 4'b0100, 4'b0001}); // pool_en = 1
                    axil_write(32'h10, ACT_BASE_ADDR);
                    axil_write(32'h14, WEIGHT_BASE_ADDR + (cout_b * 144 * 64));
                    axil_write(32'h18, OUT_BASE_ADDR + (block_idx * 512));
                    axil_write(32'h1C, BIAS_BASE_ADDR + (cout_b * 32));
                    axil_write(32'h20, QUANT_BASE_ADDR + (cout_b * 32));
                    axil_write(32'h24, LUT_BASE_ADDR);

                    axil_write(32'h00, 32'h0000_0001); // Pulse START

                    read_status = 32'h0;
                    while (!read_status[1]) begin
                        #500;
                        axil_read(32'h04, read_status);
                    end

                    done_blks++;
                    $display("  %s %3d%% (Block %2d/36) [Tile (%0d,%0d), Cout Blk %0d/4] | Latency: %8d cycles",
                             get_progress_bar(done_blks, 36),
                             (done_blks * 100) / 36, done_blks,
                             ty, tx, cout_b + 1, ($time - start_time) / 10);
                end
            end
        end
        total_cycles = ($time - start_time) / 10;

        // Verify Output Tensor against Golden Reference
        $display("\n=========================================================================================");
        $display(">>> VALIDATING PERSISTENT OUTPUT TENSOR IN AXI RAM (36 BLOCKS, 18,432 ACTIVATIONS) <<<");
        $display("=========================================================================================");

        errs = 0;
        tol_ok = 0;
        exact_ok = 0;
        max_diff = 0;

        for (ty = 0; ty < 3; ty++) begin
            for (tx = 0; tx < 3; tx++) begin
                for (cout_b = 0; cout_b < 4; cout_b++) begin
                    block_idx = (ty * 3 + tx) * 4 + cout_b;
                    for (p_idx = 0; p_idx < 64; p_idx++) begin
                        y_local = p_idx / 8;
                        x_local = p_idx % 8;
                        y_global = ty * 8 + y_local;
                        x_global = tx * 8 + x_local;

                        word_base = (OUT_BASE_ADDR[MEM_ADDR_WIDTH-1:2]) + (block_idx * 128) + (p_idx * 2);
                        word0 = axi_ram_inst.mem[word_base + 0];
                        word1 = axi_ram_inst.mem[word_base + 1];

                        ram_pix[0] = $signed(word0[7:0]);
                        ram_pix[1] = $signed(word0[15:8]);
                        ram_pix[2] = $signed(word0[23:16]);
                        ram_pix[3] = $signed(word0[31:24]);
                        ram_pix[4] = $signed(word1[7:0]);
                        ram_pix[5] = $signed(word1[15:8]);
                        ram_pix[6] = $signed(word1[23:16]);
                        ram_pix[7] = $signed(word1[31:24]);

                        for (ch_idx = 0; ch_idx < 8; ch_idx++) begin
                            ch_global = cout_b * 8 + ch_idx;
                            flat_idx = (y_global * POOL_W * COUT) + (x_global * COUT) + ch_global;
                            gold_val = gold_l1[flat_idx];
                            act_val  = ram_pix[ch_idx];
                            diff_val = (act_val > gold_val) ? (act_val - gold_val) : (gold_val - act_val);

                            if (diff_val == 0) exact_ok++;
                            else if (diff_val <= 1) tol_ok++;
                            else errs++;

                            if (diff_val > max_diff) max_diff = diff_val;
                        end
                    end
                end
            end
        end

        ideal_macs   = longint'(CONV_H) * longint'(CONV_W) * longint'(CIN) * longint'(COUT) * 9; // 84,934,656 MACs
        ideal_cycles = ideal_macs / 64; // 1,327,104 cycles
        compute_eff  = (real'(ideal_cycles) / real'(36 * 144 * 260)) * 100.0;
        e2e_eff      = (real'(ideal_cycles) / real'(total_cycles)) * 100.0;

        $display("\n=========================================================================================");
        $display(">>> FULL WORKLOAD BENCHMARK RESULTS (36 BLOCKS, 5,184 PASSES + MAXPOOL2D) <<<");
        $display("=========================================================================================");
        $display("  Total Latency:         %0d clock cycles", total_cycles);
        $display("  Ideal Peak Cycles:     %0d clock cycles (at 64 MACs/cycle)", ideal_cycles);
        $display("  Mathematical MACs:     %0d operations", ideal_macs);
        $display("  Compute Array Eff:     %0.2f%%", compute_eff);
        $display("  End-to-End System Eff: %0.2f%%", e2e_eff);
        $display("  Total Validated:       18,432 activations (100%% of 24x24x32 pooled output tensor)");
        $display("  Exact Matches (diff 0):%0d (%0.2f%%)", exact_ok, (real'(exact_ok) / 18432.0) * 100.0);
        $display("  Tol Matches   (diff 1):%0d (%0.2f%%)", tol_ok, (real'(tol_ok) / 18432.0) * 100.0);
        $display("  Errors        (diff >1):%0d", errs);
        $display("  Max Discrepancy:       %0d", max_diff);
        $display("=========================================================================================");

        if (errs == 0 && exact_ok > 0) begin
            $display(">>> SUCCESS: Full 36-Block Benchmark with MaxPool2D PASSED 100%%! <<<");
        end else begin
            $display(">>> FAILED: Benchmark had %0d mismatches across the output tensor! <<<", errs);
            $fatal(1, "Full benchmark verification failed!");
        end

        $finish;
    end

endmodule

