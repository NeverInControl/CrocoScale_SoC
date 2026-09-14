`timescale 1ns / 1ps

module tb_npu_general_math;

    parameter int ARRAY_HEIGHT     = 8;
    parameter int ARRAY_WIDTH      = 8;
    parameter int TILE_SIZE        = 16;
    parameter int ACT_HALO_PAD     = 2;
    parameter int ACTIVATION_WIDTH = 8;
    parameter int WEIGHT_WIDTH     = 8;
    parameter int PSUM_WIDTH       = 32;
    parameter int SCALE_WIDTH      = 16;
    parameter bit ENABLE_LFSR      = 0;
    parameter int WEIGHT_SPLIT     = 2;

    localparam int PSUM_WORDS       = TILE_SIZE * TILE_SIZE;
    localparam int ACT_WORDS        = (TILE_SIZE * TILE_SIZE) * ACT_HALO_PAD;
    localparam int PSUM_ADDR_WIDTH  = $clog2(PSUM_WORDS);
    localparam int ACT_ADDR_WIDTH   = $clog2(ACT_WORDS);
    localparam int NUM_ACT_BANKS    = ARRAY_HEIGHT;
    localparam int NUM_PSUM_BANKS   = ARRAY_WIDTH * 2;
    localparam int XBAR_SEL_WIDTH   = $clog2(ARRAY_HEIGHT) + 1;
    localparam int BANK_SEL_WIDTH   = $clog2(ARRAY_WIDTH);
    localparam int PROD_WIDTH       = PSUM_WIDTH + SCALE_WIDTH;
    localparam int SHIFT_WIDTH      = $clog2(PROD_WIDTH);
    localparam int QUANT_CFG_WIDTH  = SCALE_WIDTH + SHIFT_WIDTH + ACTIVATION_WIDTH;

    localparam int CONV_H  = 35;
    localparam int CONV_W  = 37;
    localparam int C0 = 16, C1 = 20, C2 = 24, C3 = 16;
    localparam int MAX_CH  = 32;

    localparam int GEMM_M    = 530;
    localparam int GEMM_K    = 27;
    localparam int GEMM_N    = 22;

    localparam int CONV_CIN  = 19;
    localparam int CONV_COUT = 21;

    logic clk_i, rst_n, array_en, psum_systolic_en, psum_lut_en;
    logic [ARRAY_HEIGHT-1:0][XBAR_SEL_WIDTH-1:0] crossbar_sel;
    
    logic signed [ARRAY_HEIGHT-1:0][WEIGHT_WIDTH-1:0] weight_shift_in;
    logic [WEIGHT_SPLIT-1:0]                          weight_shift_en;
    logic swap_weights;

    logic [QUANT_CFG_WIDTH-1:0] quant_shift_in;
    logic quant_shift_en, stochastic_round_en;
    wire  [SCALE_WIDTH-1:0] lfsr_data_out;

    logic psum_skew_en, compute_bank_swap;

    logic [PSUM_ADDR_WIDTH-1:0]   psum_A_addr, psum_B_addr;
    logic [ARRAY_WIDTH-1:0]       psum_A_we,   psum_B_we;
    logic signed [PSUM_WIDTH-1:0] psum_A_wdata, psum_B_wdata;
    logic [BANK_SEL_WIDTH-1:0]    psum_A_read_bank_sel, psum_B_read_bank_sel;
    wire  signed [PSUM_WIDTH-1:0] psum_A_rdata, psum_B_rdata;

    logic [NUM_ACT_BANKS-1:0]                     ext_act_sram_we;
    logic [NUM_ACT_BANKS-1:0][ACT_ADDR_WIDTH-1:0] ext_act_sram_addr;
    logic signed [NUM_ACT_BANKS-1:0][ACTIVATION_WIDTH-1:0] ext_act_sram_wdata;
    wire  signed [NUM_ACT_BANKS-1:0][ACTIVATION_WIDTH-1:0] act_sram_rdata;

    wire  signed [ARRAY_WIDTH-1:0][ACTIVATION_WIDTH-1:0] out_act;

    // =========================================================================
    // External Memory Storage for Reference Datasets
    // =========================================================================
    logic signed [ACTIVATION_WIDTH-1:0] lut_silu_flat                  [256];
    logic signed [ACTIVATION_WIDTH-1:0] raw_gemm_A_flat                [GEMM_M * GEMM_K];
    logic signed [WEIGHT_WIDTH-1:0]     raw_gemm_B_flat                [GEMM_K * GEMM_N];
    logic signed [PSUM_WIDTH-1:0]       golden_gemm_flat               [GEMM_M * GEMM_N];
    logic signed [PSUM_WIDTH-1:0]       actual_gemm                    [GEMM_M][GEMM_N];

    logic signed [ACTIVATION_WIDTH-1:0] raw_conv1x1_in_flat            [CONV_H * CONV_W * CONV_CIN];
    logic signed [WEIGHT_WIDTH-1:0]     raw_conv1x1_w_flat             [CONV_CIN * CONV_COUT];
    logic signed [PSUM_WIDTH-1:0]       golden_conv1x1_raw_flat        [CONV_H * CONV_W * CONV_COUT];
    logic signed [ACTIVATION_WIDTH-1:0] golden_conv1x1_quant_flat      [CONV_H * CONV_W * CONV_COUT];
    logic signed [ACTIVATION_WIDTH-1:0] golden_conv1x1_lut_flat        [CONV_H * CONV_W * CONV_COUT];
    logic signed [31:0]                 actual_conv1x1_raw             [CONV_H][CONV_W][CONV_COUT];
    logic signed [31:0]                 actual_conv1x1_quant           [CONV_H][CONV_W][CONV_COUT];
    logic signed [31:0]                 actual_conv1x1_lut             [CONV_H][CONV_W][CONV_COUT];

    logic signed [ACTIVATION_WIDTH-1:0] raw_conv3x3_halo_in_flat       [CONV_H * CONV_W * CONV_CIN];
    logic signed [WEIGHT_WIDTH-1:0]     raw_conv3x3_halo_w_flat        [3 * 3 * CONV_CIN * CONV_COUT];
    logic signed [PSUM_WIDTH-1:0]       golden_conv3x3_halo_raw_flat   [CONV_H * CONV_W * CONV_COUT];
    logic signed [ACTIVATION_WIDTH-1:0] golden_conv3x3_halo_quant_flat [CONV_H * CONV_W * CONV_COUT];
    logic signed [ACTIVATION_WIDTH-1:0] golden_conv3x3_halo_lut_flat   [CONV_H * CONV_W * CONV_COUT];
    logic signed [31:0]                 actual_conv3x3_halo_raw        [CONV_H][CONV_W][CONV_COUT];
    logic signed [31:0]                 actual_conv3x3_halo_quant      [CONV_H][CONV_W][CONV_COUT];
    logic signed [31:0]                 actual_conv3x3_halo_lut        [CONV_H][CONV_W][CONV_COUT];

    typedef struct {
        string  name;
        longint total_cycles;
        longint compute_cycles;
        longint dma_act_cycles;
        longint weight_cycles;
        longint drain_cycles;
        longint init_cycles;
        longint total_macs;
        int     raw_errors;
        int     quant_errors;
        int     lut_errors;
    } task_profile_t;

    task_profile_t prof_gemm;
    task_profile_t prof_conv1x1;
    task_profile_t prof_conv3x3_halo;

    longint global_cycle_count = 0;

    always #5 begin
        clk_i = ~clk_i;
        if (clk_i) global_cycle_count++;
    end

    npu_wrapper #(
        .ARRAY_HEIGHT     (ARRAY_HEIGHT),
        .ARRAY_WIDTH      (ARRAY_WIDTH),
        .TILE_SIZE        (TILE_SIZE),
        .ACT_HALO_PAD     (ACT_HALO_PAD),
        .ACTIVATION_WIDTH (ACTIVATION_WIDTH),
        .WEIGHT_WIDTH     (WEIGHT_WIDTH),
        .PSUM_WIDTH       (PSUM_WIDTH),
        .SCALE_WIDTH      (SCALE_WIDTH),
        .ENABLE_LFSR      (ENABLE_LFSR),
        .WEIGHT_SPLIT     (WEIGHT_SPLIT)
    ) dut (
        .clk_i              (clk_i),
        .rst_n              (rst_n),
        .array_en           (array_en),
        .psum_systolic_en   (psum_systolic_en),
        .psum_lut_en        (psum_lut_en),
        .crossbar_sel       (crossbar_sel),
        .weight_shift_in    (weight_shift_in),
        .weight_shift_en    (weight_shift_en),
        .swap_weights       (swap_weights),
        .quant_shift_in     (quant_shift_in),
        .quant_shift_en     (quant_shift_en),
        .stochastic_round_en(stochastic_round_en),
        .lfsr_data_out      (lfsr_data_out),
        .psum_skew_en       (psum_skew_en),
        .compute_bank_swap  (compute_bank_swap),
        .psum_A_addr        (psum_A_addr),
        .psum_A_we          (psum_A_we),
        .psum_A_wdata       (psum_A_wdata),
        .psum_A_read_bank_sel(psum_A_read_bank_sel),
        .psum_A_rdata       (psum_A_rdata),
        .psum_B_addr        (psum_B_addr),
        .psum_B_we          (psum_B_we),
        .psum_B_wdata       (psum_B_wdata),
        .psum_B_read_bank_sel(psum_B_read_bank_sel),
        .psum_B_rdata       (psum_B_rdata),
        .ext_act_sram_we    (ext_act_sram_we),
        .ext_act_sram_addr  (ext_act_sram_addr),
        .ext_act_sram_wdata (ext_act_sram_wdata),
        .act_sram_rdata     (act_sram_rdata),
        .out_act            (out_act)
    );

    // =========================================================================
    // Inspection & Debug Tasks
    // =========================================================================
    task automatic inspect_gemm(
        input string test_name,
        input logic signed [31:0] actual[GEMM_M][GEMM_N],
        input logic signed [PSUM_WIDTH-1:0] golden_flat[]
    );
        automatic int print_cnt = 0;
        automatic int const_diff = 0;
        automatic int off_by_const_cnt = 0;
        automatic bit first_diff = 1;
        automatic int m_idx, n_idx, flat;
        automatic logic signed [31:0] exp_val, act_val, diff_val;
        automatic string clue;

        $display("\n=====================================================================================");
        $display(" >>> [DIAGNOSTIC DUMP: %s] <<<", test_name);
        $display("=====================================================================================");
        $display("   Coord (M, N)      | Expected (Hex)  | Actual (Hex)    | Difference | Clue");
        $display("  -------------------+-----------------+-----------------+------------+-----------------");

        for (m_idx = 0; m_idx < GEMM_M; m_idx++) begin
            for (n_idx = 0; n_idx < GEMM_N; n_idx++) begin
                flat = m_idx * GEMM_N + n_idx;
                exp_val = golden_flat[flat];
                act_val = actual[m_idx][n_idx];
                diff_val = act_val - exp_val;

                if (act_val !== exp_val) begin
                    if (first_diff) begin
                        const_diff = diff_val;
                        first_diff = 0;
                        off_by_const_cnt = 1;
                    end else if (diff_val == const_diff) begin
                        off_by_const_cnt++;
                    end

                    if (print_cnt < 8) begin
                        clue = (diff_val == const_diff && const_diff != 0) ? "Bank Init Offset" : "Value Mismatch";
                        $display("   [%4d, %4d]        | %8d (0x%08X) | %8d (0x%08X) | %+10d | %s", 
                                 m_idx, n_idx, exp_val, exp_val, act_val, act_val, diff_val, clue);
                        print_cnt++;
                    end
                end
            end
        end
        $display("  -----------------------------------------------------------------------------------");
        if (off_by_const_cnt > 10) begin
            $display("  [!] ANALYZER: %0d values differ by exact constant %+0d", off_by_const_cnt, const_diff);
        end
        $display("=====================================================================================\n");
    endtask

    task automatic inspect_tensor(
        input string test_name,
        input int H, input int W, input int C,
        input logic signed [31:0] actual[CONV_H][CONV_W][CONV_COUT],
        input logic signed [ACTIVATION_WIDTH-1:0] golden_int8[],
        input logic signed [PSUM_WIDTH-1:0]       golden_int32[],
        input bit is_int8
    );
        automatic int print_cnt = 0;
        automatic int const_diff = 0;
        automatic int off_by_const_cnt = 0;
        automatic bit first_diff = 1;
        automatic int y_idx, x_idx, c_idx, flat;
        automatic logic signed [31:0] exp_val, act_val, diff_val;
        automatic string clue;

        $display("\n=====================================================================================");
        $display(" >>> [DIAGNOSTIC DUMP: %s] <<<", test_name);
        $display("=====================================================================================");
        $display("   Coord (Y, X, Ch)  | Expected (Hex)  | Actual (Hex)    | Difference | Clue");
        $display("  -------------------+-----------------+-----------------+------------+-----------------");

        for (y_idx = 0; y_idx < H; y_idx++) begin
            for (x_idx = 0; x_idx < W; x_idx++) begin
                for (c_idx = 0; c_idx < C; c_idx++) begin
                    flat = (y_idx * W * C) + (x_idx * C) + c_idx;
                    exp_val = is_int8 ? 32'(golden_int8[flat]) : golden_int32[flat];
                    act_val = actual[y_idx][x_idx][c_idx];
                    diff_val = act_val - exp_val;

                    if (act_val !== exp_val) begin
                        if (first_diff) begin
                            const_diff = diff_val;
                            first_diff = 0;
                            off_by_const_cnt = 1;
                        end else if (diff_val == const_diff) begin
                            off_by_const_cnt++;
                        end

                        if (print_cnt < 8) begin
                            clue = (diff_val == const_diff && const_diff != 0) ? "Bank Init Offset" : "Value Mismatch";
                            $display("   [%2d, %2d, Ch%2d]   | %8d (0x%02X) | %8d (0x%02X) | %+10d | %s", 
                                     y_idx, x_idx, c_idx, exp_val, exp_val[7:0], act_val, act_val[7:0], diff_val, clue);
                            print_cnt++;
                        end
                    end
                end
            end
        end
        $display("  -----------------------------------------------------------------------------------");
        if (off_by_const_cnt > 10) begin
            $display("  [!] ANALYZER: %0d values differ by exact constant %+0d", off_by_const_cnt, const_diff);
        end
        $display("=====================================================================================\n");
    endtask

    // =========================================================================
    // Control Helper Tasks
    // =========================================================================
    task automatic load_quant_params(
        input logic signed [SCALE_WIDTH-1:0] m0,
        input logic [SHIFT_WIDTH-1:0] shift,
        input logic signed [ACTIVATION_WIDTH-1:0] zp
    );
        logic [QUANT_CFG_WIDTH-1:0] cfg_word;
        cfg_word = {zp, shift, m0};
        @(negedge clk_i);
        quant_shift_en = 1;
        for (int c = 0; c < ARRAY_WIDTH; c++) begin
            quant_shift_in = cfg_word;
            @(negedge clk_i);
        end
        quant_shift_en = 0;
        quant_shift_in = '0;
    endtask

    task automatic dma_clear_all_psum_banks(ref task_profile_t prof);
        automatic longint start_c;
        start_c = global_cycle_count;
        @(negedge clk_i);
        psum_systolic_en = 0;
        psum_lut_en      = 0;
        psum_skew_en     = 0;
        psum_A_addr      = '0;
        psum_B_addr      = '0;
        psum_A_wdata     = '0;
        psum_B_wdata     = '0;
        psum_A_we        = 8'hFF;
        psum_B_we        = 8'hFF;
        @(negedge clk_i);
        psum_A_we        = 8'h00;
        psum_B_we        = 8'h00;
        prof.init_cycles += (global_cycle_count - start_c);
    endtask

    task automatic dma_preload_silu_lut();
        automatic int addr;
        @(negedge clk_i);
        psum_systolic_en = 0;
        psum_lut_en      = 0;
        psum_skew_en     = 0;
        psum_B_we        = 8'hFF;
        for (addr = 0; addr < 256; addr++) begin
            @(negedge clk_i);
            psum_B_addr  = (PSUM_ADDR_WIDTH)'(addr);
            psum_B_wdata = {24'd0, lut_silu_flat[addr]};
        end
        @(negedge clk_i);
        psum_B_we = 8'h00;
    endtask

    task automatic dma_load_weights_slice(input logic signed [WEIGHT_WIDTH-1:0] w[8][8], ref task_profile_t prof);
        automatic longint start_c;
        automatic int s, r;
        start_c = global_cycle_count;
        @(negedge clk_i);
        weight_shift_en = {WEIGHT_SPLIT{1'b1}};
        for (s = 0; s < 8; s++) begin
            for (r = 0; r < 8; r++) begin
                weight_shift_in[r] = w[r][7 - s];
            end
            @(negedge clk_i);
        end
        weight_shift_en = '0;
        @(negedge clk_i); swap_weights = 1; 
        @(negedge clk_i); swap_weights = 0;
        prof.weight_cycles += (global_cycle_count - start_c);
    endtask

    task automatic print_task_report(input task_profile_t p);
        real in_pass_eff  = (256.0 / 272.0) * 100.0;
        real sys_mac_eff  = ((real'(p.total_macs) / 64.0) / real'(p.total_cycles)) * 100.0;
        real comp_pct     = (real'(p.compute_cycles) / real'(p.total_cycles)) * 100.0;
        real dma_pct      = (real'(p.dma_act_cycles) / real'(p.total_cycles)) * 100.0;
        real drain_pct    = (real'(p.drain_cycles)   / real'(p.total_cycles)) * 100.0;
        real weight_pct   = (real'(p.weight_cycles)  / real'(p.total_cycles)) * 100.0;

        $display("-------------------------------------------------------------------------------------");
        $display(" TASK: %s", p.name);
        $display("-------------------------------------------------------------------------------------");
        $display("  Total Task Execution Cycles   : %10d cycles (100.0%%)", p.total_cycles);
        $display("   |-- Active Compute Cycles    : %10d cycles (%5.1f%%)", p.compute_cycles, comp_pct);
        $display("   |-- DMA Activation Load      : %10d cycles (%5.1f%%)", p.dma_act_cycles, dma_pct);
        $display("   |-- Parallel Drain & Requant : %10d cycles (%5.1f%%)", p.drain_cycles, drain_pct);
        $display("   |-- PE Weight Shift Chain    : %10d cycles (%5.1f%%)", p.weight_cycles, weight_pct);
        $display("   \\-- Memory Zero-Init Cycles  : %10d cycles", p.init_cycles);
        $display("  Mathematical MACs Executed    : %10d operations", p.total_macs);
        $display("  In-Pass Systolic Efficiency   : %5.2f%%", in_pass_eff);
        $display("  End-to-End System Efficiency  : %5.2f%% of theoretical peak", sys_mac_eff);
        $display("  Verification Results:");
        $display("   |-- Raw INT32 Accumulators   : %s (%0d mismatches)", (p.raw_errors == 0) ? "PASS [100%]" : "FAIL", p.raw_errors);
        $display("   |-- Quantized INT8 Output    : %s (%0d mismatches)", (p.quant_errors == 0) ? "PASS [100%]" : "FAIL", p.quant_errors);
        $display("   \\-- SiLU Non-Linear LUT Act  : %s (%0d mismatches)", (p.lut_errors == 0) ? "PASS [100%]" : "FAIL", p.lut_errors);
    endtask

    initial begin : main_proc
        automatic longint t_start, s_time, c_start, d_start;
        automatic logic swap_val, hold_zero;
        automatic logic signed [7:0] w_slice[8][8];
        automatic int num_m_tiles, num_k_passes, num_n_blocks;
        automatic int num_spat_tiles, num_cin_blocks, num_cout_blocks;
        automatic int total_passes, pass_idx;
        automatic int m_t, n_t, k_t, m, r, c, k;
        automatic int t_idx, cout_b, cin_b, ky, kx, tap;
        automatic int ty, tx, ly, lx;
        automatic int global_m, global_k, global_n;
        automatic int flat_p, flat;
        automatic int py, px, ch, ch_in, ch_out, co;
        automatic int gy, gx, m_p, ky_t, kx_t;
        string mem_dir;
        int fd;

        $display("=====================================================================================");
        $display("    NPU GENERAL MATH MULTI-TILE REGRESSION (GEMM, 1x1, 3x3 Halo)                     ");
        $display("=====================================================================================");

        // Resolve memory file path: runtime plusarg (+MEM_DIR=...) -> local working dir -> relative GoldenReference
        if (!$value$plusargs("MEM_DIR=%s", mem_dir)) begin
            fd = $fopen("gen_lut_silu.mem", "r");
            if (fd != 0) begin
                $fclose(fd);
                mem_dir = "./";
            end else begin
                fd = $fopen("../GoldenReference/gen_lut_silu.mem", "r");
                if (fd != 0) begin
                    $fclose(fd);
                    mem_dir = "../GoldenReference/";
                end else begin
                    fd = $fopen("TEST/NPU/GoldenReference/gen_lut_silu.mem", "r");
                    if (fd != 0) begin
                        $fclose(fd);
                        mem_dir = "TEST/NPU/GoldenReference/";
                    end else begin
                        mem_dir = "./";
                    end
                end
            end
        end
        if (mem_dir.len() > 0 && mem_dir[mem_dir.len()-1] != "/" && mem_dir[mem_dir.len()-1] != "\\") begin
            mem_dir = {mem_dir, "/"};
        end

        // Pre-load reference datasets generated by the Python script
        $readmemh({mem_dir, "gen_lut_silu.mem"},               lut_silu_flat);
        $readmemh({mem_dir, "gen_gemm_a.mem"},                 raw_gemm_A_flat);
        $readmemh({mem_dir, "gen_gemm_b.mem"},                 raw_gemm_B_flat);
        $readmemh({mem_dir, "gen_gemm_out_raw.mem"},           golden_gemm_flat);

        $readmemh({mem_dir, "gen_conv1x1_act.mem"},            raw_conv1x1_in_flat);
        $readmemh({mem_dir, "gen_conv1x1_w.mem"},              raw_conv1x1_w_flat);
        $readmemh({mem_dir, "gen_conv1x1_out_raw.mem"},        golden_conv1x1_raw_flat);
        $readmemh({mem_dir, "gen_conv1x1_out_quant.mem"},      golden_conv1x1_quant_flat);
        $readmemh({mem_dir, "gen_conv1x1_out_lut.mem"},        golden_conv1x1_lut_flat);

        $readmemh({mem_dir, "gen_conv3x3_halo_act.mem"},       raw_conv3x3_halo_in_flat);
        $readmemh({mem_dir, "gen_conv3x3_halo_w.mem"},         raw_conv3x3_halo_w_flat);
        $readmemh({mem_dir, "gen_conv3x3_halo_out_raw.mem"},   golden_conv3x3_halo_raw_flat);
        $readmemh({mem_dir, "gen_conv3x3_halo_out_quant.mem"}, golden_conv3x3_halo_quant_flat);
        $readmemh({mem_dir, "gen_conv3x3_halo_out_lut.mem"},   golden_conv3x3_halo_lut_flat);

        clk_i = 0; rst_n = 0; array_en = 0; psum_systolic_en = 0; psum_lut_en = 0; crossbar_sel = '0;
        weight_shift_in = '0; weight_shift_en = '0; swap_weights = 0;
        quant_shift_in = '0; quant_shift_en = 0; stochastic_round_en = 0;
        psum_skew_en = 0; compute_bank_swap = 0;
        psum_A_addr = '0; psum_A_we = '0; psum_A_wdata = '0; psum_A_read_bank_sel = '0;
        psum_B_addr = '0; psum_B_we = '0; psum_B_wdata = '0; psum_B_read_bank_sel = '0;
        ext_act_sram_we = '0; ext_act_sram_addr = '0; ext_act_sram_wdata = '0;

        #200; rst_n = 1; #100;
        for (r = 0; r < ARRAY_HEIGHT; r++) crossbar_sel[r] = 4'(r);

        // =====================================================================
        // TASK 1: GENERALIZED ARBITRARY GEMM (M=530, K=27, N=22)
        // =====================================================================
        num_m_tiles  = (GEMM_M + 255) / 256;
        num_k_passes = (GEMM_K + 7) / 8;
        num_n_blocks = (GEMM_N + 7) / 8;

        prof_gemm.name = $sformatf("Arbitrary Tiled GEMM (%0dx%0d @ %0dx%0d -> %0dx%0d)", GEMM_M, GEMM_K, GEMM_K, GEMM_N, GEMM_M, GEMM_N);
        prof_gemm.total_macs = GEMM_M * GEMM_K * GEMM_N;
        t_start = global_cycle_count;

        for (m_t = 0; m_t < num_m_tiles; m_t++) begin
            for (n_t = 0; n_t < num_n_blocks; n_t++) begin
                dma_clear_all_psum_banks(prof_gemm);

                for (k_t = 0; k_t < num_k_passes; k_t++) begin
                    swap_val = (num_k_passes % 2 == 0) 
                              ? ((k_t % 2 == 0) ? 1'b0 : 1'b1)
                              : ((k_t % 2 == 0) ? 1'b1 : 1'b0);
                    hold_zero = (k_t == 0);

                    // =========================================================================
                    // Activation DMA Transfer
                    // =========================================================================
                    s_time = global_cycle_count;
                    for (m = 0; m < 256; m++) begin
                        global_m = m_t * 256 + m;
                        @(negedge clk_i);
                        ext_act_sram_we = 8'hFF;
                        for (r = 0; r < 8; r++) begin
                            global_k = k_t * 8 + r;
                            ext_act_sram_addr[r] = (ACT_ADDR_WIDTH)'(m);
                            if (global_m < GEMM_M && global_k < GEMM_K)
                                ext_act_sram_wdata[r] = raw_gemm_A_flat[global_m * GEMM_K + global_k];
                            else
                                ext_act_sram_wdata[r] = 8'sd0;
                        end
                    end
                    @(negedge clk_i); ext_act_sram_we = '0;
                    prof_gemm.dma_act_cycles += (global_cycle_count - s_time);

                    // =========================================================================
                    // Weight Matrix Loading
                    // =========================================================================
                    for (r = 0; r < 8; r++) begin
                        for (c = 0; c < 8; c++) begin
                            global_k = k_t * 8 + r;
                            global_n = n_t * 8 + c;
                            if (global_k < GEMM_K && global_n < GEMM_N)
                                w_slice[r][c] = raw_gemm_B_flat[global_k * GEMM_N + global_n];
                            else
                                w_slice[r][c] = 8'sd0;
                        end
                    end
                    dma_load_weights_slice(w_slice, prof_gemm);

                    // =========================================================================
                    // Systolic Array Execution
                    // =========================================================================
                    begin
                        c_start = global_cycle_count;
                        for (r = 0; r < ARRAY_HEIGHT; r++) crossbar_sel[r] = 4'(r);
                        @(negedge clk_i);
                        array_en          = 1;
                        psum_systolic_en  = 1;
                        psum_lut_en       = 0;
                        psum_skew_en      = 1;
                        compute_bank_swap = swap_val;

                        for (k = 0; k < 256 + ARRAY_HEIGHT + ARRAY_WIDTH; k++) begin
                            @(negedge clk_i);
                            for (r = 0; r < ARRAY_HEIGHT; r++) begin
                                if ((k >= r) && ((k - r) < 256)) ext_act_sram_addr[r] = (ACT_ADDR_WIDTH)'(k - r);
                                else                             ext_act_sram_addr[r] = '0;
                            end

                            if (!swap_val) begin
                                psum_A_addr = (hold_zero) ? '0 : ((k < 256) ? (PSUM_ADDR_WIDTH)'(k) : '0);
                                psum_B_addr = (k >= 9 && (k - 9) < 256) ? (PSUM_ADDR_WIDTH)'(k - 9) : '0;
                                psum_A_we   = 8'h00;
                                for (c = 0; c < ARRAY_WIDTH; c++) begin
                                    psum_B_we[c] = (k >= (9 + c) && (k - (9 + c)) < 256) ? 1'b1 : 1'b0;
                                end
                            end else begin
                                psum_B_addr = (hold_zero) ? '0 : ((k < 256) ? (PSUM_ADDR_WIDTH)'(k) : '0);
                                psum_A_addr = (k >= 9 && (k - 9) < 256) ? (PSUM_ADDR_WIDTH)'(k - 9) : '0;
                                psum_B_we   = 8'h00;
                                for (c = 0; c < ARRAY_WIDTH; c++) begin
                                    psum_A_we[c] = (k >= (9 + c) && (k - (9 + c)) < 256) ? 1'b1 : 1'b0;
                                end
                            end
                        end
                        @(negedge clk_i);
                        array_en         = 0;
                        psum_systolic_en = 0;
                        psum_skew_en     = 0;
                        psum_A_we        = '0;
                        psum_B_we        = '0;
                        prof_gemm.compute_cycles += (global_cycle_count - c_start);
                    end
                end

                // =========================================================================
                // Synchronous 32-bit Burst Read
                // =========================================================================
                begin
                    d_start = global_cycle_count;
                    psum_systolic_en = 0;
                    psum_lut_en      = 0;
                    psum_skew_en     = 0;

                    for (c = 0; c < 8; c++) begin
                        psum_A_read_bank_sel = 3'(c);
                        for (m = 0; m < 256; m++) begin
                            @(negedge clk_i);
                            psum_A_addr = (PSUM_ADDR_WIDTH)'(m);
                            @(posedge clk_i); #1;
                            global_m = m_t * 256 + m;
                            global_n = n_t * 8 + c;
                            if (global_m < GEMM_M && global_n < GEMM_N)
                                actual_gemm[global_m][global_n] = psum_A_rdata;
                        end
                    end
                    prof_gemm.drain_cycles += (global_cycle_count - d_start);
                end
            end
        end
        prof_gemm.total_cycles = global_cycle_count - t_start;

        for (m_t = 0; m_t < GEMM_M; m_t++) begin
            for (n_t = 0; n_t < GEMM_N; n_t++) begin
                if (actual_gemm[m_t][n_t] !== golden_gemm_flat[m_t * GEMM_N + n_t]) prof_gemm.raw_errors++;
            end
        end

        // =====================================================================
        // TASK 2: ARBITRARY 1x1 CONVOLUTION (35x37, Cin=19, Cout=21)
        // =====================================================================
        num_spat_tiles  = ((CONV_H * CONV_W) + 255) / 256;
        num_cin_blocks  = (CONV_CIN + 7) / 8;
        num_cout_blocks = (CONV_COUT + 7) / 8;

        prof_conv1x1.name = $sformatf("Arbitrary 1x1 Conv (%0dx%0dx%0d -> %0d Cout)", CONV_H, CONV_W, CONV_CIN, CONV_COUT);
        prof_conv1x1.total_macs = CONV_H * CONV_W * CONV_CIN * CONV_COUT;
        load_quant_params(16'sd16384, 6'd14, 8'sd0);
        t_start = global_cycle_count;

        for (t_idx = 0; t_idx < num_spat_tiles; t_idx++) begin
            for (cout_b = 0; cout_b < num_cout_blocks; cout_b++) begin
                dma_clear_all_psum_banks(prof_conv1x1);

                for (cin_b = 0; cin_b < num_cin_blocks; cin_b++) begin
                    swap_val = (num_cin_blocks % 2 == 0)
                              ? ((cin_b % 2 == 0) ? 1'b0 : 1'b1)
                              : ((cin_b % 2 == 0) ? 1'b1 : 1'b0);
                    hold_zero = (cin_b == 0);

                    // =========================================================================
                    // Activation DMA Transfer
                    // =========================================================================
                    s_time = global_cycle_count;
                    for (m = 0; m < 256; m++) begin
                        flat_p = t_idx * 256 + m;
                        @(negedge clk_i);
                        ext_act_sram_we = 8'hFF;
                        for (r = 0; r < 8; r++) begin
                            ch = cin_b * 8 + r;
                            ext_act_sram_addr[r] = (ACT_ADDR_WIDTH)'(m);
                            if (flat_p < (CONV_H * CONV_W) && ch < CONV_CIN)
                                ext_act_sram_wdata[r] = raw_conv1x1_in_flat[flat_p * CONV_CIN + ch];
                            else
                                ext_act_sram_wdata[r] = 8'sd0;
                        end
                    end
                    @(negedge clk_i); ext_act_sram_we = '0;
                    prof_conv1x1.dma_act_cycles += (global_cycle_count - s_time);

                    // =========================================================================
                    // Weight Matrix Loading
                    // =========================================================================
                    for (r = 0; r < 8; r++) begin
                        for (c = 0; c < 8; c++) begin
                            ch_in  = cin_b * 8 + r;
                            ch_out = cout_b * 8 + c;
                            if (ch_in < CONV_CIN && ch_out < CONV_COUT)
                                w_slice[r][c] = raw_conv1x1_w_flat[ch_in * CONV_COUT + ch_out];
                            else
                                w_slice[r][c] = 8'sd0;
                        end
                    end
                    dma_load_weights_slice(w_slice, prof_conv1x1);

                    // =========================================================================
                    // Systolic Array Execution
                    // =========================================================================
                    begin
                        c_start = global_cycle_count;
                        for (r = 0; r < ARRAY_HEIGHT; r++) crossbar_sel[r] = 4'(r);
                        @(negedge clk_i);
                        array_en          = 1;
                        psum_systolic_en  = 1;
                        psum_lut_en       = 0;
                        psum_skew_en      = 1;
                        compute_bank_swap = swap_val;

                        for (k = 0; k < 256 + ARRAY_HEIGHT + ARRAY_WIDTH; k++) begin
                            @(negedge clk_i);
                            for (r = 0; r < ARRAY_HEIGHT; r++) begin
                                if ((k >= r) && ((k - r) < 256)) ext_act_sram_addr[r] = (ACT_ADDR_WIDTH)'(k - r);
                                else                             ext_act_sram_addr[r] = '0;
                            end

                            if (!swap_val) begin
                                psum_A_addr = (hold_zero) ? '0 : ((k < 256) ? (PSUM_ADDR_WIDTH)'(k) : '0);
                                psum_B_addr = (k >= 9 && (k - 9) < 256) ? (PSUM_ADDR_WIDTH)'(k - 9) : '0;
                                psum_A_we   = 8'h00;
                                for (c = 0; c < ARRAY_WIDTH; c++) begin
                                    psum_B_we[c] = (k >= (9 + c) && (k - (9 + c)) < 256) ? 1'b1 : 1'b0;
                                end
                            end else begin
                                psum_B_addr = (hold_zero) ? '0 : ((k < 256) ? (PSUM_ADDR_WIDTH)'(k) : '0);
                                psum_A_addr = (k >= 9 && (k - 9) < 256) ? (PSUM_ADDR_WIDTH)'(k - 9) : '0;
                                psum_B_we   = 8'h00;
                                for (c = 0; c < ARRAY_WIDTH; c++) begin
                                    psum_A_we[c] = (k >= (9 + c) && (k - (9 + c)) < 256) ? 1'b1 : 1'b0;
                                end
                            end
                        end
                        @(negedge clk_i);
                        array_en         = 0;
                        psum_systolic_en = 0;
                        psum_skew_en     = 0;
                        psum_A_we        = '0;
                        psum_B_we        = '0;
                        prof_conv1x1.compute_cycles += (global_cycle_count - c_start);
                    end
                end

                // =========================================================================
                // Multi-Phase Drain Sweep (Raw & Quantized)
                // =========================================================================
                begin
                    d_start = global_cycle_count;
                    psum_systolic_en = 0;
                    psum_lut_en      = 0;
                    psum_skew_en     = 0;

                    // Drain 64-bit Quantized stream
                    for (m = 0; m < 256 + 3; m++) begin
                        @(negedge clk_i);
                        if (m < 256) psum_A_addr = (PSUM_ADDR_WIDTH)'(m);
                        @(posedge clk_i); #1;
                        if (m >= 2 && m < 258) begin
                            flat_p = t_idx * 256 + (m - 2);
                            if (flat_p < (CONV_H * CONV_W)) begin
                                py = flat_p / CONV_W;
                                px = flat_p % CONV_W;
                                for (c = 0; c < 8; c++) begin
                                    co = cout_b * 8 + c;
                                    if (co < CONV_COUT) actual_conv1x1_quant[py][px][co] = $signed(out_act[c]);
                                end
                            end
                        end
                    end

                    // Drain 32-bit Raw accumulators
                    for (c = 0; c < 8; c++) begin
                        psum_A_read_bank_sel = 3'(c);
                        for (m = 0; m < 256; m++) begin
                            @(negedge clk_i);
                            psum_A_addr = (PSUM_ADDR_WIDTH)'(m);
                            @(posedge clk_i); #1;
                            flat_p = t_idx * 256 + m;
                            if (flat_p < (CONV_H * CONV_W)) begin
                                py = flat_p / CONV_W;
                                px = flat_p % CONV_W;
                                co = cout_b * 8 + c;
                                if (co < CONV_COUT) actual_conv1x1_raw[py][px][co] = psum_A_rdata;
                            end
                        end
                    end

                    // Preload SiLU LUT & Execute LUT Drain Sweep
                    dma_preload_silu_lut();
                    psum_systolic_en = 0;
                    psum_lut_en      = 1;
                    psum_skew_en     = 0;
                    for (m = 0; m < 256 + 4; m++) begin
                        @(negedge clk_i);
                        if (m < 256) psum_A_addr = (PSUM_ADDR_WIDTH)'(m);
                        @(posedge clk_i); #1;
                        if (m >= 3 && m < 259) begin
                            flat_p = t_idx * 256 + (m - 3);
                            if (flat_p < (CONV_H * CONV_W)) begin
                                py = flat_p / CONV_W;
                                px = flat_p % CONV_W;
                                for (c = 0; c < 8; c++) begin
                                    co = cout_b * 8 + c;
                                    if (co < CONV_COUT) actual_conv1x1_lut[py][px][co] = $signed(out_act[c]);
                                end
                            end
                        end
                    end
                    psum_lut_en = 0;
                    prof_conv1x1.drain_cycles += (global_cycle_count - d_start);
                end
            end
        end
        prof_conv1x1.total_cycles = global_cycle_count - t_start;

        for (py = 0; py < CONV_H; py++) begin
            for (px = 0; px < CONV_W; px++) begin
                for (co = 0; co < CONV_COUT; co++) begin
                    flat = (py * CONV_W * CONV_COUT) + (px * CONV_COUT) + co;
                    if (actual_conv1x1_raw[py][px][co]   !== golden_conv1x1_raw_flat[flat])    prof_conv1x1.raw_errors++;
                    if (actual_conv1x1_quant[py][px][co] !== golden_conv1x1_quant_flat[flat])  prof_conv1x1.quant_errors++;
                    if (actual_conv1x1_lut[py][px][co]   !== golden_conv1x1_lut_flat[flat])    prof_conv1x1.lut_errors++;
                end
            end
        end

        // =====================================================================
        // TASK 3: ARBITRARY 3x3 HALO CONVOLUTION (35x37, Cin=19, Cout=21)
        // =====================================================================
        prof_conv3x3_halo.name = $sformatf("Arbitrary 3x3 Halo Conv (%0dx%0dx%0d -> %0d Cout)", CONV_H, CONV_W, CONV_CIN, CONV_COUT);
        prof_conv3x3_halo.total_macs = CONV_H * CONV_W * CONV_CIN * CONV_COUT * 9;
        load_quant_params(16'sd16384, 6'd15, 8'sd0);
        t_start = global_cycle_count;

        for (ty = 0; ty < (CONV_H + 15)/16; ty++) begin
            for (tx = 0; tx < (CONV_W + 15)/16; tx++) begin
                for (cout_b = 0; cout_b < num_cout_blocks; cout_b++) begin
                    pass_idx = 0;
                    dma_clear_all_psum_banks(prof_conv3x3_halo);

                    for (cin_b = 0; cin_b < num_cin_blocks; cin_b++) begin
                        // =========================================================================
                        // Activation DMA Transfer
                        // =========================================================================
                        s_time = global_cycle_count;
                        for (ly = 0; ly < 18; ly++) begin
                            for (lx = 0; lx < 18; lx++) begin
                                gy = ty * 16 + ly - 1;
                                gx = tx * 16 + lx - 1;
                                @(negedge clk_i);
                                ext_act_sram_we = 8'hFF;
                                for (r = 0; r < 8; r++) begin
                                    ch = cin_b * 8 + r;
                                    ext_act_sram_addr[r] = (ACT_ADDR_WIDTH)'(ly * 18 + lx);
                                    if (gy >= 0 && gy < CONV_H && gx >= 0 && gx < CONV_W && ch < CONV_CIN)
                                        ext_act_sram_wdata[r] = raw_conv3x3_halo_in_flat[(gy * CONV_W * CONV_CIN) + (gx * CONV_CIN) + ch];
                                    else
                                        ext_act_sram_wdata[r] = 8'sd0;
                                end
                            end
                        end
                        @(negedge clk_i); ext_act_sram_we = '0;
                        prof_conv3x3_halo.dma_act_cycles += (global_cycle_count - s_time);

                        for (ky = 0; ky < 3; ky++) begin
                            for (kx = 0; kx < 3; kx++) begin
                                total_passes = num_cin_blocks * 9;
                                swap_val = (total_passes % 2 == 0)
                                          ? ((pass_idx % 2 == 0) ? 1'b0 : 1'b1)
                                          : ((pass_idx % 2 == 0) ? 1'b1 : 1'b0);
                                hold_zero = (pass_idx == 0);

                                // =========================================================================
                                // Weight Matrix Loading
                                // =========================================================================
                                for (r = 0; r < 8; r++) begin
                                    for (c = 0; c < 8; c++) begin
                                        ch_in  = cin_b * 8 + r;
                                        ch_out = cout_b * 8 + c;
                                        if (ch_in < CONV_CIN && ch_out < CONV_COUT)
                                            w_slice[r][c] = raw_conv3x3_halo_w_flat[(ky * 3 * CONV_CIN * CONV_COUT) + (kx * CONV_CIN * CONV_COUT) + (ch_in * CONV_COUT) + ch_out];
                                        else
                                            w_slice[r][c] = 8'sd0;
                                    end
                                end
                                dma_load_weights_slice(w_slice, prof_conv3x3_halo);

                                // =========================================================================
                                // Systolic Array Execution
                                // =========================================================================
                                begin
                                    c_start = global_cycle_count;
                                    for (r = 0; r < ARRAY_HEIGHT; r++) crossbar_sel[r] = 4'(r);
                                    @(negedge clk_i);
                                    array_en          = 1;
                                    psum_systolic_en  = 1;
                                    psum_lut_en       = 0;
                                    psum_skew_en      = 1;
                                    compute_bank_swap = swap_val;

                                    for (k = 0; k < 256 + ARRAY_HEIGHT + ARRAY_WIDTH; k++) begin
                                        @(negedge clk_i);
                                        for (r = 0; r < ARRAY_HEIGHT; r++) begin
                                            if ((k >= r) && ((k - r) < 256)) begin
                                                m_p = k - r;
                                                ext_act_sram_addr[r] = (ACT_ADDR_WIDTH)'(((m_p / 16) + ky) * 18 + ((m_p % 16) + kx));
                                            end else begin
                                                ext_act_sram_addr[r] = '0;
                                            end
                                        end

                                        if (!swap_val) begin
                                            psum_A_addr = (hold_zero) ? '0 : ((k < 256) ? (PSUM_ADDR_WIDTH)'(k) : '0);
                                            psum_B_addr = (k >= 9 && (k - 9) < 256) ? (PSUM_ADDR_WIDTH)'(k - 9) : '0;
                                            psum_A_we   = 8'h00;
                                            for (c = 0; c < ARRAY_WIDTH; c++) begin
                                                psum_B_we[c] = (k >= (9 + c) && (k - (9 + c)) < 256) ? 1'b1 : 1'b0;
                                            end
                                        end else begin
                                            psum_B_addr = (hold_zero) ? '0 : ((k < 256) ? (PSUM_ADDR_WIDTH)'(k) : '0);
                                            psum_A_addr = (k >= 9 && (k - 9) < 256) ? (PSUM_ADDR_WIDTH)'(k - 9) : '0;
                                            psum_B_we   = 8'h00;
                                            for (c = 0; c < ARRAY_WIDTH; c++) begin
                                                psum_A_we[c] = (k >= (9 + c) && (k - (9 + c)) < 256) ? 1'b1 : 1'b0;
                                            end
                                        end
                                    end
                                    @(negedge clk_i);
                                    array_en         = 0;
                                    psum_systolic_en = 0;
                                    psum_skew_en     = 0;
                                    psum_A_we        = '0;
                                    psum_B_we        = '0;
                                    prof_conv3x3_halo.compute_cycles += (global_cycle_count - c_start);
                                end
                                pass_idx++;
                            end
                        end
                    end

                    // =========================================================================
                    // Multi-Phase Drain Sweep (Raw & Quantized)
                    // =========================================================================
                    begin
                        d_start = global_cycle_count;
                        psum_systolic_en = 0;
                        psum_lut_en      = 0;
                        psum_skew_en     = 0;

                        // Drain 64-bit Quantized stream
                        for (m = 0; m < 256 + 3; m++) begin
                            @(negedge clk_i);
                            if (m < 256) psum_A_addr = (PSUM_ADDR_WIDTH)'(m);
                            @(posedge clk_i); #1;
                            if (m >= 2 && m < 258) begin
                                py = ty * 16 + ((m - 2) / 16);
                                px = tx * 16 + ((m - 2) % 16);
                                if (py < CONV_H && px < CONV_W) begin
                                    for (c = 0; c < 8; c++) begin
                                        co = cout_b * 8 + c;
                                        if (co < CONV_COUT) actual_conv3x3_halo_quant[py][px][co] = $signed(out_act[c]);
                                    end
                                end
                            end
                        end

                        // Drain 32-bit Raw accumulators
                        for (c = 0; c < 8; c++) begin
                            psum_A_read_bank_sel = 3'(c);
                            for (m = 0; m < 256; m++) begin
                                @(negedge clk_i);
                                psum_A_addr = (PSUM_ADDR_WIDTH)'(m);
                                @(posedge clk_i); #1;
                                py = ty * 16 + (m / 16);
                                px = tx * 16 + (m % 16);
                                if (py < CONV_H && px < CONV_W) begin
                                    co = cout_b * 8 + c;
                                    if (co < CONV_COUT) actual_conv3x3_halo_raw[py][px][co] = psum_A_rdata;
                                end
                            end
                        end

                        // Preload SiLU LUT & Execute LUT Drain Sweep
                        dma_preload_silu_lut();
                        psum_systolic_en = 0;
                        psum_lut_en      = 1;
                        psum_skew_en     = 0;
                        for (m = 0; m < 256 + 4; m++) begin
                            @(negedge clk_i);
                            if (m < 256) psum_A_addr = (PSUM_ADDR_WIDTH)'(m);
                            @(posedge clk_i); #1;
                            if (m >= 3 && m < 259) begin
                                py = ty * 16 + ((m - 3) / 16);
                                px = tx * 16 + ((m - 3) % 16);
                                if (py < CONV_H && px < CONV_W) begin
                                    for (c = 0; c < 8; c++) begin
                                        co = cout_b * 8 + c;
                                        if (co < CONV_COUT) actual_conv3x3_halo_lut[py][px][co] = $signed(out_act[c]);
                                    end
                                end
                            end
                        end
                        psum_lut_en = 0;
                        prof_conv3x3_halo.drain_cycles += (global_cycle_count - d_start);
                    end
                end
            end
        end
        prof_conv3x3_halo.total_cycles = global_cycle_count - t_start;

        for (py = 0; py < CONV_H; py++) begin
            for (px = 0; px < CONV_W; px++) begin
                for (co = 0; co < CONV_COUT; co++) begin
                    flat = (py * CONV_W * CONV_COUT) + (px * CONV_COUT) + co;
                    if (actual_conv3x3_halo_raw[py][px][co]   !== golden_conv3x3_halo_raw_flat[flat])    prof_conv3x3_halo.raw_errors++;
                    if (actual_conv3x3_halo_quant[py][px][co] !== golden_conv3x3_halo_quant_flat[flat])  prof_conv3x3_halo.quant_errors++;
                    if (actual_conv3x3_halo_lut[py][px][co]   !== golden_conv3x3_halo_lut_flat[flat])    prof_conv3x3_halo.lut_errors++;
                end
            end
        end

        // =====================================================================
        // REPORTS & DIAGNOSTIC DUMPS
        // =====================================================================
        $display("\n=====================================================================================");
        $display("                   NPU WORKLOAD EXECUTION & UTILIZATION REPORTS                      ");
        $display("=====================================================================================");
        print_task_report(prof_gemm);
        print_task_report(prof_conv1x1);
        print_task_report(prof_conv3x3_halo);
        $display("=====================================================================================");

        if (prof_gemm.raw_errors > 0) 
            inspect_gemm("GEMM Raw Accumulators", actual_gemm, golden_gemm_flat);

        if (prof_conv1x1.raw_errors > 0) 
            inspect_tensor("1x1 Conv Raw Accumulators", CONV_H, CONV_W, CONV_COUT, actual_conv1x1_raw, lut_silu_flat, golden_conv1x1_raw_flat, 0);
        if (prof_conv1x1.quant_errors > 0) 
            inspect_tensor("1x1 Conv Quantized INT8", CONV_H, CONV_W, CONV_COUT, actual_conv1x1_quant, golden_conv1x1_quant_flat, golden_conv1x1_raw_flat, 1);
        if (prof_conv1x1.lut_errors > 0) 
            inspect_tensor("1x1 Conv SiLU LUT INT8", CONV_H, CONV_W, CONV_COUT, actual_conv1x1_lut, golden_conv1x1_lut_flat, golden_conv1x1_raw_flat, 1);

        if (prof_conv3x3_halo.raw_errors > 0) 
            inspect_tensor("3x3 Halo Raw Accumulators", CONV_H, CONV_W, CONV_COUT, actual_conv3x3_halo_raw, lut_silu_flat, golden_conv3x3_halo_raw_flat, 0);
        if (prof_conv3x3_halo.quant_errors > 0) 
            inspect_tensor("3x3 Halo Quantized INT8", CONV_H, CONV_W, CONV_COUT, actual_conv3x3_halo_quant, golden_conv3x3_halo_quant_flat, golden_conv3x3_halo_raw_flat, 1);
        if (prof_conv3x3_halo.lut_errors > 0) 
            inspect_tensor("3x3 Halo SiLU LUT INT8", CONV_H, CONV_W, CONV_COUT, actual_conv3x3_halo_lut, golden_conv3x3_halo_lut_flat, golden_conv3x3_halo_raw_flat, 1);

        if ((prof_gemm.raw_errors + prof_conv1x1.raw_errors + prof_conv1x1.quant_errors + prof_conv1x1.lut_errors +
             prof_conv3x3_halo.raw_errors + prof_conv3x3_halo.quant_errors + prof_conv3x3_halo.lut_errors) == 0) begin
            $display(">>> ALL GENERAL MATH WORKLOADS PASSED 100%% WITH EXACT CONVERGENCE! <<<");
        end else begin
            $display(">>> BENCHMARK ENCOUNTERED MISMATCHES (See Diagnostic Tables Above) <<<");
        end
        $display("=====================================================================================\n");

        #200;
        $finish;
    end : main_proc

endmodule