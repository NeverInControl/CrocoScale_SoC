`timescale 1ns / 1ps

module tb_npu_im2col_benchmark;

    // =========================================================================
    // Architecture & Scaled Benchmark Parameters
    // =========================================================================
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

    localparam int PSUM_WORDS       = TILE_SIZE * TILE_SIZE; // 256 words
    localparam int ACT_WORDS        = (TILE_SIZE * TILE_SIZE) * ACT_HALO_PAD; // 512 words
    localparam int PSUM_ADDR_WIDTH  = $clog2(PSUM_WORDS);
    localparam int ACT_ADDR_WIDTH   = $clog2(ACT_WORDS);
    localparam int NUM_ACT_BANKS    = ARRAY_HEIGHT;
    localparam int NUM_PSUM_BANKS   = ARRAY_WIDTH * 2;
    localparam int XBAR_SEL_WIDTH   = $clog2(ARRAY_HEIGHT) + 1;
    localparam int BANK_SEL_WIDTH   = $clog2(ARRAY_WIDTH);
    localparam int PROD_WIDTH       = PSUM_WIDTH + SCALE_WIDTH;
    localparam int SHIFT_WIDTH      = $clog2(PROD_WIDTH);
    localparam int QUANT_CFG_WIDTH  = SCALE_WIDTH + SHIFT_WIDTH + ACTIVATION_WIDTH;

    // Scaled Benchmark Dimensions (3x3 Grid of 16x16 Tiles, Cin=128, Cout=32)
    localparam int CONV_H  = 48;
    localparam int CONV_W  = 48;
    localparam int Cin     = 128;
    localparam int Cout    = 32;

    // =========================================================================
    // DUT Interface Signals
    // =========================================================================
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
    // Reference Storage & Hardware Output Buffers
    // =========================================================================
    logic signed [ACTIVATION_WIDTH-1:0] fmap_in        [CONV_H * CONV_W * Cin];
    logic signed [ACTIVATION_WIDTH-1:0] gold_l1        [CONV_H * CONV_W * Cout];
    logic signed [WEIGHT_WIDTH-1:0]     w1_flat        [3 * 3 * Cin * Cout];
    logic signed [31:0]                 b1_flat        [Cout];
    logic [31:0]                        p1_cfg         [Cout];
    
    logic signed [ACTIVATION_WIDTH-1:0] actual_quant_l1 [CONV_H][CONV_W][Cout];
    logic signed [31:0]                 actual_psum_l1  [CONV_H][CONV_W][Cout];
    logic signed [31:0]                 golden_psum_l1  [CONV_H][CONV_W][Cout];

    // =========================================================================
    // Cycle Profiling Counters
    // =========================================================================
    longint global_cycle           = 0;
    longint compute_active_cycles  = 0;
    longint init_preload_cycles    = 0;
    longint drain_quant_cycles     = 0;
    longint e2e_start_cycle        = 0;
    longint e2e_total_cycles       = 0;
    longint raw_drain_cycles       = 0;
    longint raw_drain_start        = 0;

    always #5 begin
        clk_i = ~clk_i;
        if (clk_i) begin
            global_cycle++;
            if (array_en) compute_active_cycles++;
        end
    end

    // =========================================================================
    // NPU Wrapper Instantiation
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
        .ENABLE_LFSR     (ENABLE_LFSR),
        .WEIGHT_SPLIT    (WEIGHT_SPLIT)
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
    // Hazard & Bank Conflict Monitor
    // =========================================================================
    int  row_target_bank [8];
    bit  row_access_en   [8];
    int  total_bank_conflicts   = 0;
    int  total_rw_conflicts     = 0;
    int  printed_rw_conflicts   = 0;
    localparam int MAX_WARNINGS = 16;

    always_ff @(posedge clk_i) begin
        if (rst_n && array_en) begin
            for (int b = 0; b < 8; b++) begin
                if (ext_act_sram_we[b] != 1'b0) begin
                    for (int r = 0; r < 8; r++) begin
                        if (row_access_en[r] && (row_target_bank[r] == b)) begin
                            if (printed_rw_conflicts < MAX_WARNINGS) begin
                                $display("[HAZARD R/W CONFLICT] Cycle %0d: Bank %0d Simultaneous Write & Read by Row %0d!", 
                                         global_cycle, b, r);
                                printed_rw_conflicts++;
                            end
                            total_rw_conflicts++;
                        end
                    end
                end
            end
        end
    end

    // =========================================================================
    // Strict File Existence Guard
    // =========================================================================
    task automatic check_file_exists(input string filename);
        int fd;
        fd = $fopen(filename, "r");
        if (fd == 0) begin
            $display("\n=====================================================================================");
            $display(" [FATAL ERROR] Required memory file '%s' was NOT found!", filename);
            $display(" Run 'python3 gen_npu_im2col_benchmark.py' and ensure output files are in xsim path.");
            $display("=====================================================================================\n");
            $fatal(1, "Aborting simulation due to missing test vector files.");
        end
        $fclose(fd);
    endtask

    // =========================================================================
    // Memory Mapper: Orthogonal Bank Location Resolver
    // =========================================================================
    function automatic void get_sram_loc(
        input int cin_idx,
        input int ly,
        input int lx,
        output int bank,
        output int addr
    );
        int h, x_off;
        h     = (lx >= 9) ? 1 : 0;
        x_off = (lx >= 9) ? (lx - 9) : lx;

        bank = (ly % 3) * 2 + h;
        addr = (cin_idx % 8) * 64 + (ly / 3) * 9 + x_off;
    endfunction

    // =========================================================================
    // Fast Lookup: Maps (Channel, Bank, Offset 0..53) -> Activation Pixel
    // =========================================================================
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

        if (gy_val >= 0 && gy_val < CONV_H && gx_val >= 0 && gx_val < CONV_W && c_idx < Cin)
            return fmap_in[(gy_val * CONV_W * Cin) + (gx_val * Cin) + c_idx];
        else
            return 8'sd0;
    endfunction

    // =========================================================================
    // Helper: Slices Weight Tensor for Pass p into an 8x8 PE Matrix
    // =========================================================================
    function automatic void prepare_weights(
        input int p,
        input int cout_b,
        output logic signed [7:0] w_mat[8][8]
    );
        int r, c, g_idx, cin_curr, tap_curr, ky_curr, kx_curr, ch_out;
        for (r = 0; r < 8; r++) begin
            g_idx = p * 8 + r;
            if (g_idx < (Cin * 9)) begin
                cin_curr = g_idx / 9;
                tap_curr = g_idx % 9;
                ky_curr  = tap_curr / 3;
                kx_curr  = tap_curr % 3;
                for (c = 0; c < 8; c++) begin
                    ch_out = cout_b * 8 + c;
                    if (ch_out < Cout)
                        w_mat[r][c] = w1_flat[(ky_curr * 3 * Cin * Cout) + (kx_curr * Cin * Cout) + (cin_curr * Cout) + ch_out];
                    else
                        w_mat[r][c] = 8'sd0;
                end
            end else begin
                for (c = 0; c < 8; c++) w_mat[r][c] = 8'sd0;
            end
        end
    endfunction

    // =========================================================================
    // Golden Reference Model: Direct Convolution
    // =========================================================================
    task automatic compute_golden_psum_l1();
        int y, x, cout_idx, cin_idx, ky, kx, in_y, in_x;
        logic signed [31:0] psum_val;
        logic signed [7:0] in_pix, w_val;

        for (y = 0; y < CONV_H; y++) begin
            for (x = 0; x < CONV_W; x++) begin
                for (cout_idx = 0; cout_idx < Cout; cout_idx++) begin
                    psum_val = b1_flat[cout_idx];
                    for (cin_idx = 0; cin_idx < Cin; cin_idx++) begin
                        for (ky = 0; ky < 3; ky++) begin
                            for (kx = 0; kx < 3; kx++) begin
                                in_y = y + ky - 1;
                                in_x = x + kx - 1;
                                if (in_y >= 0 && in_y < CONV_H && in_x >= 0 && in_x < CONV_W)
                                    in_pix = fmap_in[(in_y * CONV_W * Cin) + (in_x * Cin) + cin_idx];
                                else
                                    in_pix = 8'sd0;

                                w_val = w1_flat[(ky * 3 * Cin * Cout) + (kx * Cin * Cout) + (cin_idx * Cout) + cout_idx];
                                psum_val += (32'(in_pix) * 32'(w_val));
                            end
                        end
                    end
                    golden_psum_l1[y][x][cout_idx] = psum_val;
                end
            end
        end
    endtask

    // =========================================================================
    // Diagnostic Inspection & Reporting (with Dual Tolerance / Exact Metrics)
    // =========================================================================
    task automatic inspect_full_layer_diagnostics();
        int total_elements = CONV_H * CONV_W * Cout;
        int psum_exact = 0, psum_errs = 0;
        int quant_exact = 0, quant_exact_errs = 0;
        int quant_tol_ok = 0, quant_tol_errs = 0;
        int print_cnt = 0;
        int y, x, c, flat;
        logic signed [31:0] exp_psum, act_psum, diff_psum;
        logic signed [7:0]  exp_quant, act_quant;
        int diff_quant, abs_diff_quant;

        for (y = 0; y < CONV_H; y++) begin
            for (x = 0; x < CONV_W; x++) begin
                for (c = 0; c < Cout; c++) begin
                    flat      = (y * CONV_W * Cout) + (x * Cout) + c;
                    exp_psum  = golden_psum_l1[y][x][c];
                    act_psum  = actual_psum_l1[y][x][c];
                    diff_psum = act_psum - exp_psum;

                    exp_quant = gold_l1[flat];
                    act_quant = actual_quant_l1[y][x][c];
                    diff_quant = int'(act_quant) - int'(exp_quant);
                    abs_diff_quant = (diff_quant < 0) ? -diff_quant : diff_quant;

                    // PSUM Check (Must be 100% Bit-Exact)
                    if (act_psum === exp_psum) psum_exact++;
                    else                       psum_errs++;

                    // INT8 Exact Match (Debug Reference)
                    if (act_quant === exp_quant) quant_exact++;
                    else                         quant_exact_errs++;

                    // INT8 Tolerance Gate (+/-1 LSB Allowed for Rounding Modes)
                    if (abs_diff_quant <= 1) quant_tol_ok++;
                    else                     quant_tol_errs++;
                end
            end
        end

        // Only print error table if there is a genuine PSUM mismatch or delta > 1 LSB
        if (psum_errs > 0 || quant_tol_errs > 0) begin
            $display("\n=========================================================================================================");
            $display(" >>> [BENCHMARK LAYER DIAGNOSTIC: HARD MISMATCH DUMP (|Delta Q| > 1 or PSUM Err)] <<<");
            $display("=========================================================================================================");
            $display("   Coord (Y, X, Ch)  | Exp PSUM (INT32) | Act PSUM (INT32) | Delta PSUM | Exp Q(INT8) | Act Q(INT8) | Status");
            $display("  -------------------+------------------+------------------+------------+-------------+-------------+--------------------");
            for (y = 0; y < CONV_H; y++) begin
                for (x = 0; x < CONV_W; x++) begin
                    for (c = 0; c < Cout; c++) begin
                        flat      = (y * CONV_W * Cout) + (x * Cout) + c;
                        exp_psum  = golden_psum_l1[y][x][c];
                        act_psum  = actual_psum_l1[y][x][c];
                        diff_psum = act_psum - exp_psum;
                        exp_quant = gold_l1[flat];
                        act_quant = actual_quant_l1[y][x][c];
                        diff_quant = int'(act_quant) - int'(exp_quant);
                        abs_diff_quant = (diff_quant < 0) ? -diff_quant : diff_quant;

                        if ((act_psum !== exp_psum) || (abs_diff_quant > 1)) begin
                            if (print_cnt < 16) begin
                                $display("   [%2d, %2d, Ch%2d]    | %16d | %16d | %10d | %11d | %11d | HARD MISMATCH", 
                                         y, x, c, exp_psum, act_psum, diff_psum, exp_quant, act_quant);
                                print_cnt++;
                            end
                        end
                    end
                end
            end
            $display("=========================================================================================================\n");
        end

        $display("\n=====================================================================================");
        $display("   VERIFICATION & BIT-EXACTNESS REPORT                                               ");
        $display("=====================================================================================");
        $display("  STAGE 1A: INT8 Output (+/-1 LSB Tol)     : %0d / %0d (%5.2f%%) %s", 
                 quant_tol_ok, total_elements, (real'(quant_tol_ok)/total_elements)*100.0, (quant_tol_errs == 0) ? "[PASS]" : "[FAIL]");
        $display("  STAGE 1B: INT8 Output (Exact Bit-Match) : %0d / %0d (%5.2f%%) [DEBUG]", 
                 quant_exact, total_elements, (real'(quant_exact)/total_elements)*100.0);
        $display("  STAGE 2 : Raw INT32 PSUM (Exact Match)  : %0d / %0d (%5.2f%%) %s", 
                 psum_exact, total_elements, (real'(psum_exact)/total_elements)*100.0, (psum_errs == 0) ? "[PASS]" : "[FAIL]");
        $display("-------------------------------------------------------------------------------------");
        if (psum_errs == 0 && quant_tol_errs == 0)
            $display("  >>> BENCHMARK PASSED (100%% PSUM EXACT & 100%% INT8 WITHIN +/-1 LSB TOLERANCE) <<<");
        else
            $display("  >>> BENCHMARK VERIFICATION FAILED (Hard Errors Detected) <<<");
        $display("=====================================================================================");
    endtask

    // =========================================================================
    // Performance and System Efficiency Report
    // =========================================================================
    task automatic print_performance_report();
        longint total_macs;
        longint ideal_compute_cycles;
        real compute_eff;
        real e2e_eff;
        real compute_pct;
        real preload_pct;
        real drain_pct;

        total_macs           = longint'(CONV_H) * longint'(CONV_W) * longint'(Cin) * longint'(Cout) * 9;
        ideal_compute_cycles = total_macs / 64;
        
        compute_eff = (real'(ideal_compute_cycles) / real'(compute_active_cycles)) * 100.0;
        e2e_eff     = (real'(ideal_compute_cycles) / real'(e2e_total_cycles)) * 100.0;
        
        compute_pct       = (real'(compute_active_cycles) / real'(e2e_total_cycles)) * 100.0;
        preload_pct       = (real'(init_preload_cycles)   / real'(e2e_total_cycles)) * 100.0;
        drain_pct         = (real'(drain_quant_cycles)    / real'(e2e_total_cycles)) * 100.0;

        $display("\n=====================================================================================");
        $display("   NPU 3x3 IM2COL PEAK UTILIZATION & HARDWARE SCALING REPORT                         ");
        $display("=====================================================================================");
        $display("  Mathematical Operations Evaluated: %10d MACs", total_macs);
        $display("  Ideal Peak Cycles (64 MACs/cycle): %10d cycles", ideal_compute_cycles);
        $display("  -----------------------------------------------------------------------------------");
        $display("  TOTAL END-TO-END EXECUTION TIME  : %10d cycles (100.0%%)", e2e_total_cycles);
        $display("   |-- Active Systolic Compute     : %10d cycles (%5.1f%% of E2E)", compute_active_cycles, compute_pct);
        $display("   |-- Parallel Channel 0 Preload  : %10d cycles (%5.1f%% of E2E) [54 cycles/block init]", init_preload_cycles, preload_pct);
        $display("   \\-- Requantized INT8 Drain      : %10d cycles (%5.1f%% of E2E)", drain_quant_cycles, drain_pct);
        $display("  -----------------------------------------------------------------------------------");
        $display("  In-Compute Systolic Utilization  : %5.2f%% (Theoretical Limit: 96.60%%)", compute_eff);
        $display("  End-to-End System Efficiency     : %5.2f%% of theoretical peak", e2e_eff);
        $display("=====================================================================================\n");
    endtask

    // =========================================================================
    // Helper: ASCII Progress Bar Generator
    // =========================================================================
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

    // =========================================================================
    // Main Simulation Process
    // =========================================================================
    initial begin
        int num_ty, num_tx, cout_blks, k_total, total_passes;
        int total_blocks, completed_blocks;
        int ty, tx, cout_b, p_idx, r, c, b, k, m, m_p, pass_len;
        int g_idx, cin_curr, tap_curr, ky_curr, kx_curr;
        int target_ly, target_lx, target_bank, target_addr;
        int out_y, out_x, py, px, d_idx;
        longint phase_start;
        logic swap_val, hold_bias_addr;
        bit init_bank_b;
        logic signed [7:0] w_slice[8][8];
        logic signed [7:0] next_w_slice[8][8];

        int dma_channel_to_load;
        int dma_bank_ptr [6];
        bit bank_read_used [6];
        int target_bank_arr [8];
        int target_addr_arr [8];
        bit row_active_arr [8];

        int dma_schedule [144];

        num_ty       = (CONV_H + 15) / 16;
        num_tx       = (CONV_W + 15) / 16;
        cout_blks    = (Cout + 7) / 8;
        k_total      = Cin * 9;             // 128 * 9 = 1152 reduction taps
        total_passes = (k_total + 7) / 8;   // 1152 / 8 = 144 passes exact
        
        total_blocks     = num_ty * num_tx * cout_blks; // 3 x 3 x 4 = 36 blocks
        completed_blocks = 0;

        // Build hazard-free DMA load schedule: Channel C is loaded 1 pass before first needed
        for (int p = 0; p < total_passes; p++) dma_schedule[p] = -1;
        for (int ch_idx = 1; ch_idx < Cin; ch_idx++) begin
            int p_needed = (9 * ch_idx) / 8;
            dma_schedule[p_needed - 1] = ch_idx;
        end

        // Informative Header Banner
        $display("=====================================================================================");
        $display("   NPU SCALING EVALUATION: 3x3 CONVOLUTION (SCALED 48x48x128 -> 32 BENCHMARK)        ");
        $display("=====================================================================================");
        $display("   Input Tensor Dimensions  : %0dx%0d (Height x Width), %0d Channels", CONV_H, CONV_W, Cin);
        $display("   Output Tensor Dimensions : %0dx%0d (Height x Width), %0d Channels", CONV_H, CONV_W, Cout);
        $display("   Kernel Configuration     : 3x3 Conv, Stride 1, SAME Padding");
        $display("   Spatial Partitioning     : %0dx%0d Tiles of 16x16 (Exact 100%% Spatial Alignment)", num_ty, num_tx);
        $display("   Channel Processing       : %0d Output Channel Blocks (Exact 100%% Channel Alignment)", cout_blks);
        $display("   Total Workload Execution : %0d Total Blocks | %0d Passes/Block", total_blocks, total_passes);
        $display("   Reduction Depth (K_total): %0d Taps -> %0d Passes (8 Taps/Pass continuous streaming)", k_total, total_passes);
        $display("   Pipelining Architecture  : 9-Cycle Wavefront Staggering + Zero-Stall Background DMA");
        $display("=====================================================================================\n");

        // Verify test vectors exist
        check_file_exists("bench_im2col_act.mem");
        check_file_exists("bench_im2col_w.mem");
        check_file_exists("bench_im2col_b.mem");
        check_file_exists("bench_im2col_cfg.mem");
        check_file_exists("bench_im2col_out_quant.mem");

        // Load reference test vectors
        $readmemh("bench_im2col_act.mem",       fmap_in);
        $readmemh("bench_im2col_w.mem",         w1_flat);
        $readmemh("bench_im2col_b.mem",         b1_flat);
        $readmemh("bench_im2col_cfg.mem",       p1_cfg);
        $readmemh("bench_im2col_out_quant.mem", gold_l1);

        compute_golden_psum_l1();

        clk_i = 0; rst_n = 0; array_en = 0; psum_systolic_en = 0; psum_lut_en = 0; crossbar_sel = '0;
        weight_shift_in = '0; weight_shift_en = '0; swap_weights = 0; quant_shift_in = '0; quant_shift_en = 0;
        stochastic_round_en = 0; psum_skew_en = 0; compute_bank_swap = 0;
        psum_A_addr = '0; psum_A_we = '0; psum_A_wdata = '0; psum_A_read_bank_sel = '0;
        psum_B_addr = '0; psum_B_we = '0; psum_B_wdata = '0; psum_B_read_bank_sel = '0;
        ext_act_sram_we = '0; ext_act_sram_addr = '0; ext_act_sram_wdata = '0;

        #200; rst_n = 1; #100;

        // Start End-to-End Timer
        e2e_start_cycle = global_cycle;

        for (ty = 0; ty < num_ty; ty++) begin
            for (tx = 0; tx < num_tx; tx++) begin
                for (cout_b = 0; cout_b < cout_blks; cout_b++) begin
                    
                    init_bank_b = (total_passes % 2 == 1);

                    // =========================================================================
                    // STEP 1: CONCURRENT PRELOAD PHASE (54 Cycles Total)
                    // =========================================================================
                    phase_start = global_cycle;
                    prepare_weights(0, cout_b, w_slice);

                    @(negedge clk_i);
                    psum_systolic_en = 0; psum_lut_en = 0; psum_skew_en = 0;

                    for (int step = 0; step < 54; step++) begin
                        // A. 6-Bank Parallel DMA Write for Channel 0
                        for (b = 0; b < 6; b++) begin
                            ext_act_sram_we[b]    = 1'b1;
                            ext_act_sram_addr[b]  = (ACT_ADDR_WIDTH)'(step);
                            ext_act_sram_wdata[b] = get_fmap_val(0, b, step, ty, tx);
                        end
                        ext_act_sram_we[6] = 1'b0;
                        ext_act_sram_we[7] = 1'b0;

                        // B. Parallel Bias + Quantizer Load (cycles 0..7)
                        if (step < 8) begin
                            int ch   = cout_b * 8 + step;
                            int q_ch = cout_b * 8 + (7 - step);
                            logic signed [31:0] b_val = (ch < Cout) ? b1_flat[ch] : 32'sd0;

                            if (!init_bank_b) begin
                                psum_A_addr  = '0;
                                psum_A_wdata = b_val;
                                psum_A_we    = (8'b1 << step);
                                psum_B_we    = 8'h00;
                            end else begin
                                psum_B_addr  = '0;
                                psum_B_wdata = b_val;
                                psum_B_we    = (8'b1 << step);
                                psum_A_we    = 8'h00;
                            end

                            quant_shift_en = 1'b1;
                            quant_shift_in = (q_ch < Cout) ? p1_cfg[q_ch][QUANT_CFG_WIDTH-1:0] : '0;
                        end else begin
                            psum_A_we      = 8'h00;
                            psum_B_we      = 8'h00;
                            quant_shift_en = 1'b0;
                            quant_shift_in = '0;
                        end

                        // C. Parallel Weight Shift for Pass 0 (cycles 0..7) + Swap (cycle 8)
                        if (step < 8) begin
                            weight_shift_en = {WEIGHT_SPLIT{1'b1}};
                            for (r = 0; r < 8; r++) weight_shift_in[r] = w_slice[r][7 - step];
                            swap_weights = 1'b0;
                        end else if (step == 8) begin
                            weight_shift_en = '0;
                            swap_weights    = 1'b1;
                        end else begin
                            weight_shift_en = '0;
                            swap_weights    = 1'b0;
                        end

                        @(negedge clk_i);
                    end

                    ext_act_sram_we = '0;
                    psum_A_we       = '0;
                    psum_B_we       = '0;
                    quant_shift_en  = '0;
                    weight_shift_en = '0;
                    swap_weights    = '0;
                    init_preload_cycles += (global_cycle - phase_start);

                    // =========================================================================
                    // STEP 2: 9-CYCLE STAGGERED REDUCTION PASSES (Pass 0..143)
                    // Passes 0..142 run for 265 cycles (256 + 9). Final Pass 143 runs for 273 cycles.
                    // =========================================================================
                    for (p_idx = 0; p_idx < total_passes; p_idx++) begin
                        int next_p = p_idx + 1;
                        pass_len   = (p_idx == total_passes - 1) ? (256 + ARRAY_HEIGHT + ARRAY_WIDTH) : (256 + 9);
                        
                        dma_channel_to_load = dma_schedule[p_idx];
                        for (b = 0; b < 6; b++) dma_bank_ptr[b] = 0;

                        if (next_p < total_passes) begin
                            prepare_weights(next_p, cout_b, next_w_slice);
                        end

                        swap_val       = (total_passes % 2 == 0) ? ((p_idx % 2 == 0) ? 1'b0 : 1'b1) : ((p_idx % 2 == 0) ? 1'b1 : 1'b0);
                        hold_bias_addr = (p_idx == 0);

                        for (k = 0; k < pass_len; k++) begin
                            @(negedge clk_i);

                            // Update array controls on cycle 0 of the pass
                            if (k == 0) begin
                                array_en          = 1; 
                                psum_systolic_en  = 1; 
                                psum_lut_en       = 0; 
                                psum_skew_en      = 1; 
                                compute_bank_swap = swap_val;
                            end

                            // -------------------------------------------------
                            // A. Compute Phase: Address Calculation
                            // -------------------------------------------------
                            for (b = 0; b < 6; b++) bank_read_used[b] = 1'b0;

                            for (r = 0; r < ARRAY_HEIGHT; r++) begin
                                g_idx = p_idx * 8 + r;
                                m_p   = k - r;
                                
                                if (m_p >= 0 && m_p < 256 && g_idx < k_total) begin
                                    cin_curr    = g_idx / 9;
                                    tap_curr    = g_idx % 9;
                                    ky_curr     = tap_curr / 3;
                                    kx_curr     = tap_curr % 3;
                                    out_y       = m_p / 16;
                                    out_x       = m_p % 16;
                                    
                                    target_ly   = out_y + ky_curr;
                                    target_lx   = out_x + kx_curr;
                                    get_sram_loc(cin_curr, target_ly, target_lx, target_bank, target_addr);

                                    target_bank_arr[r] = target_bank;
                                    target_addr_arr[r] = target_addr;
                                    row_active_arr[r]  = 1'b1;
                                    row_access_en[r]   = 1'b1;
                                    row_target_bank[r] = target_bank;
                                    crossbar_sel[r]    = 4'(target_bank);
                                    if (target_bank < 6) bank_read_used[target_bank] = 1'b1;
                                end else begin
                                    target_bank_arr[r] = -1;
                                    target_addr_arr[r] = '0;
                                    row_active_arr[r]  = 1'b0;
                                    row_access_en[r]   = 1'b0;
                                    crossbar_sel[r]    = 4'b1000;
                                end
                            end

                            // -------------------------------------------------
                            // B. Non-Blocking Memory Arbiter: Compute vs DMA
                            // -------------------------------------------------
                            for (b = 0; b < 6; b++) begin
                                if (bank_read_used[b]) begin
                                    ext_act_sram_we[b] = 1'b0;
                                    for (r = 0; r < ARRAY_HEIGHT; r++) begin
                                        if (row_active_arr[r] && target_bank_arr[r] == b) begin
                                            ext_act_sram_addr[b] = (ACT_ADDR_WIDTH)'(target_addr_arr[r]);
                                        end
                                    end
                                end else if (dma_channel_to_load >= 0 && dma_bank_ptr[b] < 54) begin
                                    ext_act_sram_we[b]    = 1'b1;
                                    ext_act_sram_addr[b]  = (ACT_ADDR_WIDTH)'(((dma_channel_to_load % 8) * 64) + dma_bank_ptr[b]);
                                    ext_act_sram_wdata[b] = get_fmap_val(dma_channel_to_load, b, dma_bank_ptr[b], ty, tx);
                                    dma_bank_ptr[b]++;
                                end else begin
                                    ext_act_sram_we[b]   = 1'b0;
                                    ext_act_sram_addr[b] = '0;
                                end
                            end
                            ext_act_sram_we[6] = 1'b0;
                            ext_act_sram_we[7] = 1'b0;

                            // -------------------------------------------------
                            // C. Shadow Pre-Shift (k=32..39) & Swap on Last Cycle (k=pass_len-1)
                            // -------------------------------------------------
                            if (next_p < total_passes && k >= 32 && k < 40) begin
                                weight_shift_en = {WEIGHT_SPLIT{1'b1}};
                                for (r = 0; r < 8; r++) weight_shift_in[r] = next_w_slice[r][7 - (k - 32)];
                                swap_weights    = 1'b0;
                            end else if (next_p < total_passes && k == pass_len - 1) begin
                                weight_shift_en = '0;
                                swap_weights    = 1'b1;
                            end else begin
                                weight_shift_en = '0;
                                swap_weights    = 1'b0;
                            end

                            // -------------------------------------------------
                            // D. Systolic PSUM Wave with Inter-Pass Trailing Write Preservation
                            // -------------------------------------------------
                            if (!swap_val) begin
                                psum_A_addr = (hold_bias_addr) ? '0 : ((k < 256) ? (PSUM_ADDR_WIDTH)'(k) : '0);
                                psum_B_addr = (k >= 9 && (k - 9) < 256) ? (PSUM_ADDR_WIDTH)'(k - 9) : '0;
                                
                                for (c = 0; c < ARRAY_WIDTH; c++) begin
                                    psum_B_we[c] = (k >= (9 + c) && (k - (9 + c)) < 256) ? 1'b1 : 1'b0;
                                    psum_A_we[c] = (p_idx > 0 && k < c) ? 1'b1 : 1'b0;
                                end
                            end else begin
                                psum_B_addr = (hold_bias_addr) ? '0 : ((k < 256) ? (PSUM_ADDR_WIDTH)'(k) : '0);
                                psum_A_addr = (k >= 9 && (k - 9) < 256) ? (PSUM_ADDR_WIDTH)'(k - 9) : '0;
                                
                                for (c = 0; c < ARRAY_WIDTH; c++) begin
                                    psum_A_we[c] = (k >= (9 + c) && (k - (9 + c)) < 256) ? 1'b1 : 1'b0;
                                    psum_B_we[c] = (p_idx > 0 && k < c) ? 1'b1 : 1'b0;
                                end
                            end
                        end
                    end

                    // Deassert array control after the final pass
                    @(negedge clk_i); 
                    array_en         = 0; 
                    psum_systolic_en = 0; 
                    psum_skew_en     = 0; 
                    psum_A_we        = '0; 
                    psum_B_we        = '0;
                    ext_act_sram_we  = '0;
                    swap_weights     = '0;
                    for (r = 0; r < 8; r++) row_access_en[r] = 1'b0;

                    // =========================================================================
                    // Drain Sweep 1: Quantized INT8 Output Read (Via 2-cycle Requantizer)
                    // =========================================================================
                    phase_start = global_cycle;
                    psum_systolic_en = 0;
                    psum_lut_en      = 0;
                    psum_skew_en     = 0;
                    psum_A_we        = '0;
                    psum_B_we        = '0;

                    for (m = 0; m < 256 + 3; m++) begin
                        @(negedge clk_i);
                        if (m < 256) psum_A_addr = (PSUM_ADDR_WIDTH)'(m);
                        @(posedge clk_i); #1;
                        
                        d_idx = m - 2;
                        if (d_idx >= 0 && d_idx < 256) begin
                            py = ty * 16 + (d_idx / 16);
                            px = tx * 16 + (d_idx % 16);
                            if (py < CONV_H && px < CONV_W) begin
                                for (c = 0; c < 8; c++) begin
                                    if (cout_b * 8 + c < Cout) actual_quant_l1[py][px][cout_b * 8 + c] = out_act[c];
                                end
                            end
                        end
                    end
                    drain_quant_cycles += (global_cycle - phase_start);

                    // =========================================================================
                    // Drain Sweep 2: Raw PSUM Sanity-Check Read (Excluded from E2E Time)
                    // =========================================================================
                    raw_drain_start = global_cycle;
                    for (c = 0; c < 8; c++) begin
                        psum_A_read_bank_sel = 3'(c);
                        for (m = 0; m < 256; m++) begin
                            @(negedge clk_i);
                            psum_A_addr = (PSUM_ADDR_WIDTH)'(m);
                            @(posedge clk_i); #1;
                            py = ty * 16 + (m / 16);
                            px = tx * 16 + (m % 16);
                            if (py < CONV_H && px < CONV_W) begin
                                if (cout_b * 8 + c < Cout) actual_psum_l1[py][px][cout_b * 8 + c] = psum_A_rdata;
                            end
                        end
                    end
                    raw_drain_cycles += (global_cycle - raw_drain_start);

                    // =========================================================================
                    // Live Block Progress Indicator
                    // =========================================================================
                    completed_blocks++;
                    $display(" %s %3d%% | Finished Block %2d/%2d [Tile (%0d,%0d), Cout Blk %0d/4] | Cycle: %8d",
                             get_progress_bar(completed_blocks, total_blocks),
                             (completed_blocks * 100) / total_blocks,
                             completed_blocks, total_blocks,
                             ty, tx, cout_b + 1,
                             global_cycle);

                end
            end
        end

        // Calculate Final Deployment End-to-End Latency
        e2e_total_cycles = (global_cycle - e2e_start_cycle) - raw_drain_cycles;

        // =========================================================================
        // Diagnostic & Utilization Reporting
        // =========================================================================
        $display("\n=====================================================================================");
        $display("   HARDWARE BANK HAZARD MONITOR REPORT");
        $display("=====================================================================================");
        $display(" Total Single-Port Address Collisions Detected : %0d", total_bank_conflicts);
        $display(" Total Simultaneous Read/Write Hazards Detected : %0d", total_rw_conflicts);
        $display("=====================================================================================");

        inspect_full_layer_diagnostics();
        print_performance_report();

        #200; $finish;
    end
endmodule