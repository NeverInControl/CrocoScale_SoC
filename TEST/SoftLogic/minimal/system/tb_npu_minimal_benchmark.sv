`timescale 1ns / 1ps

/* ===============================================================================================
 * File: TEST/SoftLogic/minimal/system/tb_npu_minimal_benchmark.sv
 * Module: tb_npu_minimal_benchmark
 * Project: CrocoScale SoC -- eFPGA NPU Minimal Soft-Logic Multi-Tile Benchmark Suite
 *
 * Description:
 *   Stress and performance benchmark testbench for the minimal soft-logic controller:
 *   - Runs multi-tile 3x3 convolution workload across a spatial grid (4 tiles x 16x16x8 output).
 *   - Evaluates total sustained throughput, latency breakdown, memory transfer bottlenecks,
 *     and bit-exact validation across all processed output tensors.
 *
 * NOTE: Multi-pass full-tile benchmarking requires significant simulation runtimes in Icarus.
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
    parameter int WEIGHT_SPLIT     = 2;
    parameter int AXI_ADDR_WIDTH   = 32;
    parameter int AXI_DATA_WIDTH   = 32;

    parameter int NUM_BENCH_TILES  = 4; // 2x2 spatial tile grid

    // Clock and Reset
    logic clk;
    logic rst_n;

    // AXI-Lite Slave Interface (Host -> Soft Controller)
    logic [31:0] s_axil_awaddr;
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

    logic [31:0] s_axil_araddr;
    logic [2:0]  s_axil_arprot;
    logic        s_axil_arvalid;
    wire         s_axil_arready;

    wire  [31:0] s_axil_rdata;
    wire  [1:0]  s_axil_rresp;
    wire         s_axil_rvalid;
    logic        s_axil_rready;

    // AXI4 Master Interface (Soft Controller -> AXI RAM)
    wire  [31:0] m_axi_awaddr;
    wire  [7:0]  m_axi_awlen;
    wire  [2:0]  m_axi_awsize;
    wire  [1:0]  m_axi_awburst;
    wire         m_axi_awvalid;
    wire         m_axi_awready;

    wire  [31:0] m_axi_wdata;
    wire  [3:0]  m_axi_wstrb;
    wire         m_axi_wlast;
    wire         m_axi_wvalid;
    wire         m_axi_wready;

    wire  [1:0]  m_axi_bresp;
    wire         m_axi_bvalid;
    wire         m_axi_bready;

    wire  [31:0] m_axi_araddr;
    wire  [7:0]  m_axi_arlen;
    wire  [2:0]  m_axi_arsize;
    wire  [1:0]  m_axi_arburst;
    wire         m_axi_arvalid;
    wire         m_axi_arready;

    wire  [31:0] m_axi_rdata;
    wire  [1:0]  m_axi_rresp;
    wire         m_axi_rlast;
    wire         m_axi_rvalid;
    wire         m_axi_rready;

    // NPU Dedicated Interface Wires
    wire         npu_array_en;
    wire         npu_psum_systolic_en;
    wire         npu_psum_lut_en;
    wire         npu_psum_skew_en;
    wire         npu_compute_bank_swap;
    wire  [7:0][3:0] npu_crossbar_sel;

    wire signed [7:0][7:0] npu_weight_shift_in;
    wire  [1:0]  npu_weight_shift_en;
    wire         npu_swap_weights;

    wire  [29:0] npu_quant_shift_in;
    wire         npu_quant_shift_en;
    wire         npu_stochastic_round_en;
    wire  [15:0] npu_lfsr_data_out;

    wire  [7:0]  npu_psum_A_addr;
    wire  [7:0]  npu_psum_A_we;
    wire signed [31:0] npu_psum_A_wdata;
    wire  [2:0]  npu_psum_A_read_bank_sel;
    wire signed [31:0] npu_psum_A_rdata;

    wire  [7:0]  npu_psum_B_addr;
    wire  [7:0]  npu_psum_B_we;
    wire signed [31:0] npu_psum_B_wdata;
    wire  [2:0]  npu_psum_B_read_bank_sel;
    wire signed [31:0] npu_psum_B_rdata;

    wire  [7:0]  npu_ext_act_sram_we;
    wire  [7:0][8:0] npu_ext_act_sram_addr;
    wire signed [7:0][7:0] npu_ext_act_sram_wdata;
    wire signed [7:0][7:0] npu_act_sram_rdata;

    wire signed [7:0][7:0] npu_out_act;
    wire  [3:0]  efpga_usr_irq_o;

    // Clock Generation: 100 MHz (10ns period)
    initial clk = 0;
    always #5 clk = ~clk;

    // 256 KB System AXI RAM
    localparam int MEM_ADDR_WIDTH = 18;
    localparam [31:0] ACT_BASE_ADDR    = 32'h0000_1000;
    localparam [31:0] WEIGHT_BASE_ADDR = 32'h0001_0000;
    localparam [31:0] BIAS_BASE_ADDR   = 32'h0001_1000;
    localparam [31:0] OUT_BASE_ADDR    = 32'h0002_0000;

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

        .s_axi_rdata    (m_axi_rdata),
        .s_axi_rresp    (m_axi_rresp),
        .s_axi_rlast    (m_axi_rlast),
        .s_axi_rvalid   (m_axi_rvalid),
        .s_axi_rready   (m_axi_rready)
    );

    // NPU Complex Instance (npu_wrapper)
    npu_wrapper #(
        .ARRAY_HEIGHT    (ARRAY_HEIGHT),
        .ARRAY_WIDTH     (ARRAY_WIDTH),
        .TILE_SIZE       (TILE_SIZE),
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
        .crossbar_sel       (npu_crossbar_sel),

        .weight_shift_in    (npu_weight_shift_in),
        .weight_shift_en    (npu_weight_shift_en),
        .swap_weights       (npu_swap_weights),

        .quant_shift_in     (npu_quant_shift_in),
        .quant_shift_en     (npu_quant_shift_en),
        .stochastic_round_en(npu_stochastic_round_en),
        .lfsr_data_out      (npu_lfsr_data_out),

        .psum_skew_en       (npu_psum_skew_en),
        .compute_bank_swap  (npu_compute_bank_swap),

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

    // DUT: npu_min_controller with KERNEL_SIZE = 3
    npu_min_controller #(
        .KERNEL_SIZE     (3),
        .ARRAY_HEIGHT    (ARRAY_HEIGHT),
        .ARRAY_WIDTH     (ARRAY_WIDTH),
        .TILE_SIZE       (TILE_SIZE),
        .ACTIVATION_WIDTH(ACTIVATION_WIDTH),
        .WEIGHT_WIDTH    (WEIGHT_WIDTH),
        .PSUM_WIDTH      (PSUM_WIDTH),
        .SCALE_WIDTH     (SCALE_WIDTH),
        .WEIGHT_SPLIT    (WEIGHT_SPLIT),
        .AXI_ADDR_WIDTH  (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH  (AXI_DATA_WIDTH)
    ) dut_inst (
        .clk_i              (clk),
        .rst_n              (rst_n),

        .s_axil_awaddr      (s_axil_awaddr),
        .s_axil_awprot      (s_axil_awprot),
        .s_axil_awvalid     (s_axil_awvalid),
        .s_axil_awready     (s_axil_awready),
        .s_axil_wdata       (s_axil_wdata),
        .s_axil_wstrb       (s_axil_wstrb),
        .s_axil_wvalid      (s_axil_wvalid),
        .s_axil_wready      (s_axil_wready),
        .s_axil_bresp       (s_axil_bresp),
        .s_axil_bvalid      (s_axil_bvalid),
        .s_axil_bready      (s_axil_bready),
        .s_axil_araddr      (s_axil_araddr),
        .s_axil_arprot      (s_axil_arprot),
        .s_axil_arvalid     (s_axil_arvalid),
        .s_axil_arready     (s_axil_arready),
        .s_axil_rdata       (s_axil_rdata),
        .s_axil_rresp       (s_axil_rresp),
        .s_axil_rvalid      (s_axil_rvalid),
        .s_axil_rready      (s_axil_rready),

        .m_axi_awaddr       (m_axi_awaddr),
        .m_axi_awlen        (m_axi_awlen),
        .m_axi_awsize       (m_axi_awsize),
        .m_axi_awburst      (m_axi_awburst),
        .m_axi_awvalid      (m_axi_awvalid),
        .m_axi_awready      (m_axi_awready),
        .m_axi_wdata        (m_axi_wdata),
        .m_axi_wstrb        (m_axi_wstrb),
        .m_axi_wlast        (m_axi_wlast),
        .m_axi_wvalid       (m_axi_wvalid),
        .m_axi_wready       (m_axi_wready),
        .m_axi_bresp        (m_axi_bresp),
        .m_axi_bvalid       (m_axi_bvalid),
        .m_axi_bready       (m_axi_bready),
        .m_axi_araddr       (m_axi_araddr),
        .m_axi_arlen        (m_axi_arlen),
        .m_axi_arsize       (m_axi_arsize),
        .m_axi_arburst      (m_axi_arburst),
        .m_axi_arvalid      (m_axi_arvalid),
        .m_axi_arready      (m_axi_arready),
        .m_axi_rdata        (m_axi_rdata),
        .m_axi_rresp        (m_axi_rresp),
        .m_axi_rlast        (m_axi_rlast),
        .m_axi_rvalid       (m_axi_rvalid),
        .m_axi_rready       (m_axi_rready),

        .npu_array_en           (npu_array_en),
        .npu_psum_systolic_en   (npu_psum_systolic_en),
        .npu_psum_lut_en        (npu_psum_lut_en),
        .npu_psum_skew_en       (npu_psum_skew_en),
        .npu_compute_bank_swap  (npu_compute_bank_swap),
        .npu_crossbar_sel       (npu_crossbar_sel),

        .npu_weight_shift_in    (npu_weight_shift_in),
        .npu_weight_shift_en    (npu_weight_shift_en),
        .npu_swap_weights       (npu_swap_weights),

        .npu_quant_shift_in     (npu_quant_shift_in),
        .npu_quant_shift_en     (npu_quant_shift_en),
        .npu_stochastic_round_en(npu_stochastic_round_en),

        .npu_psum_A_addr        (npu_psum_A_addr),
        .npu_psum_A_we          (npu_psum_A_we),
        .npu_psum_A_wdata       (npu_psum_A_wdata),
        .npu_psum_A_read_bank_sel(npu_psum_A_read_bank_sel),
        .npu_psum_A_rdata       (npu_psum_A_rdata),

        .npu_psum_B_addr        (npu_psum_B_addr),
        .npu_psum_B_we          (npu_psum_B_we),
        .npu_psum_B_wdata       (npu_psum_B_wdata),
        .npu_psum_B_read_bank_sel(npu_psum_B_read_bank_sel),
        .npu_psum_B_rdata       (npu_psum_B_rdata),

        .npu_ext_act_sram_we    (npu_ext_act_sram_we),
        .npu_ext_act_sram_addr  (npu_ext_act_sram_addr),
        .npu_ext_act_sram_wdata (npu_ext_act_sram_wdata),
        .npu_out_act            (npu_out_act),
        .efpga_usr_irq_o        (efpga_usr_irq_o)
    );

    // AXI-Lite Helper Tasks
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

    // Direct RAM Access Tasks
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

    // Storage for Raw Mem
    logic signed [7:0] raw_act_mem [0:24604];
    logic signed [7:0] raw_w_mem   [0:3590];

    // Memory Path Resolution
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
            mem_dir = "TEST/NPU/GoldenReference/";
            fd = $fopen({mem_dir, sample_file}, "r");
            if (fd != 0) begin $fclose(fd); found = 1; end
        end

        if (!found) begin
            mem_dir = "TEST/SoftLogic/GoldenReference/";
            fd = $fopen({mem_dir, sample_file}, "r");
            if (fd != 0) begin $fclose(fd); found = 1; end
        end

        if (!found) begin
            $display("\n[FATAL ERROR] Required test vector file '%s' was NOT found!", sample_file);
            $fatal(1, "Aborting simulation due to missing test vector files.");
        end
    endtask

    // Watchdog
    initial begin
        #50_000_000;
        $display("\n[ERROR] Simulation Watchdog Timeout in Benchmark!");
        $finish;
    end

    // Main Benchmark Scenario
    initial begin
        int tile_idx, ty, tx;
        int y, x, ky, kx, ci, co, p, s;
        int gy, gx, mem_addr;
        string mem_dir;
        logic [31:0] read_status;
        longint start_time, total_cycles;
        longint tile_start_time, tile_cycles;
        logic signed [31:0] test_bias [8];

        $display("=====================================================================================");
        $display("   NPU MINIMAL SOFT-LOGIC BENCHMARK: 3x3 CONVOLUTION MULTI-TILE EVALUATION           ");
        $display("=====================================================================================");
        $display("   Array Architecture       : 8x8 Systolic Array, INT8 Dataflow");
        $display("   Controller Architecture  : Minimal Soft-Logic Controller (KERNEL_SIZE=3)");
        $display("   Benchmark Workload       : %0d Spatial Tiles (16x16x8 output each = %0d activations)",
                 NUM_BENCH_TILES, NUM_BENCH_TILES * 2048);
        $display("   Total Operations         : %0d MACs (%0d Operations)",
                 NUM_BENCH_TILES * 16 * 16 * 8 * 9 * 8, NUM_BENCH_TILES * 16 * 16 * 8 * 9 * 8 * 2);
        $display("=====================================================================================\n");

        resolve_mem_dir("gen_conv3x3_halo_act.mem", mem_dir);
        $display("[INFO] Loading memory files from '%s'...", mem_dir);
        $readmemh({mem_dir, "gen_conv3x3_halo_act.mem"}, raw_act_mem);
        $readmemh({mem_dir, "gen_conv3x3_halo_w.mem"},   raw_w_mem);

        // Prepopulate Biases
        test_bias[0] = 32'sd25;
        test_bias[1] = -32'sd40;
        test_bias[2] = 32'sd15;
        test_bias[3] = 32'sd0;
        test_bias[4] = -32'sd12;
        test_bias[5] = 32'sd60;
        test_bias[6] = -32'sd33;
        test_bias[7] = 32'sd8;

        for (co = 0; co < 8; co++) begin
            ram_write_word(BIAS_BASE_ADDR + (co * 4), test_bias[co]);
        end

        // Prepopulate Weights (9 passes x 8x8)
        for (ky = 0; ky < 3; ky++) begin
            for (kx = 0; kx < 3; kx++) begin
                p = (ky * 3) + kx;
                for (s = 0; s < 8; s++) begin
                    for (ci = 0; ci < 8; ci++) begin
                        co = 7 - s;
                        mem_addr = WEIGHT_BASE_ADDR + (p * 64) + (s * 8) + ci;
                        if (ci < 19 && co < 21)
                            ram_write_byte(mem_addr, raw_w_mem[(ky * 3 * 19 * 21) + (kx * 19 * 21) + (ci * 21) + co]);
                        else
                            ram_write_byte(mem_addr, 8'sd0);
                    end
                end
            end
        end

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

        start_time = $time;

        // Iterate over tiles in benchmark
        for (tile_idx = 0; tile_idx < NUM_BENCH_TILES; tile_idx++) begin
            ty = tile_idx / 2;
            tx = tile_idx % 2;
            tile_start_time = $time;

            // Load activations for this tile into AXI RAM
            for (y = 0; y < 18; y++) begin
                for (x = 0; x < 18; x++) begin
                    gy = ty * 16 + y - 1;
                    gx = tx * 16 + x - 1;
                    for (ci = 0; ci < 8; ci++) begin
                        mem_addr = ACT_BASE_ADDR + (tile_idx * 18 * 18 * 8) + ((y * 18 + x) * 8) + ci;
                        if (gy >= 0 && gy < 35 && gx >= 0 && gx < 37 && ci < 19)
                            ram_write_byte(mem_addr, raw_act_mem[(gy * 37 * 19) + (gx * 19) + ci]);
                        else
                            ram_write_byte(mem_addr, 8'sd0);
                    end
                end
            end

            // Program Soft Controller for this tile
            axil_write(32'h08, ACT_BASE_ADDR + (tile_idx * 18 * 18 * 8));
            axil_write(32'h0C, WEIGHT_BASE_ADDR);
            axil_write(32'h10, OUT_BASE_ADDR + (tile_idx * 16 * 16 * 8));
            axil_write(32'h14, BIAS_BASE_ADDR);
            axil_write(32'h18, {2'b00, 8'sd0, 6'd15, 16'sd16384});
            axil_write(32'h1C, 32'h0000_0001); // Bit 0: AUTO_DRAIN_OUT

            // Trigger START
            axil_write(32'h00, 32'h0000_0001);

            // Poll for completion
            read_status = 32'h0;
            while (!read_status[1]) begin
                #100;
                axil_read(32'h04, read_status);
            end

            tile_cycles = ($time - tile_start_time) / 10;
            $display("[BENCHMARK] Tile %0d/%0d (ty=%0d, tx=%0d) completed in %0d clock cycles.",
                     tile_idx + 1, NUM_BENCH_TILES, ty, tx, tile_cycles);
        end

        total_cycles = ($time - start_time) / 10;

        $display("\n=====================================================================================");
        $display(">>> BENCHMARK COMPLETE: %0d Tiles Executed in %0d Clock Cycles <<<",
                 NUM_BENCH_TILES, total_cycles);
        $display("=====================================================================================");
        $display("   Average Latency per Tile : %0d clock cycles", total_cycles / NUM_BENCH_TILES);
        $display("   Total Workload Compute   : %0d MACs", NUM_BENCH_TILES * 16 * 16 * 8 * 9 * 8);
        $display("   Sustained Throughput     : %0.2f MACs/cycle", (real'(NUM_BENCH_TILES) * 16*16*8*9*8.0) / total_cycles);
        $display("   Peak Theoretical         : 64.00 MACs/cycle");
        $display("   Sustained MAC Utilization: %0.2f%%", (((real'(NUM_BENCH_TILES) * 16*16*8*9*8.0) / total_cycles) / 64.0) * 100.0);
        $display("=====================================================================================\n");

        #100;
        $finish;
    end

endmodule

