`timescale 1ns / 1ps

module tb_npu_im2col;

    // =========================================================================
    // Architecture & Layer Parameters
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

    // Layer 1 Dimensions (3x3 Convolution)
    localparam int CONV_H  = 35;
    localparam int CONV_W  = 37;
    localparam int Cin     = 16;
    localparam int Cout    = 20;

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
    // Diagnostic Inspection & Reporting
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

                    if (act_psum === exp_psum) psum_exact++;
                    else                       psum_errs++;

                    if (act_quant === exp_quant) quant_exact++;
                    else                         quant_exact_errs++;

                    if (abs_diff_quant <= 1) quant_tol_ok++;
                    else                     quant_tol_errs++;
                end
            end
        end

        if (psum_errs > 0 || quant_tol_errs > 0) begin
            $display("\n=========================================================================================================");
            $display(" >>> [ADVANCED LAYER 1 DIAGNOSTIC: HARD MISMATCH DUMP (|Delta Q| > 1 or PSUM Err)] <<<");
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
            $display("  >>> LAYER 1 PASSED (100%% PSUM EXACT & 100%% INT8 WITHIN +/-1 LSB TOLERANCE) <<<");
        else
            $display("  >>> LAYER 1 VERIFICATION FAILED (Hard Errors Detected) <<<");
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

        total_macs           = longint'(CONV_H) * longint'(CONV_W) * longint'(Cin) * longint'(Cout) * 9;
        ideal_compute_cycles = total_macs / 64;
        
        compute_eff = (real'(ideal_compute_cycles) / real'(compute_active_cycles)) * 100.0;
        e2e_eff     = (real'(ideal_compute_cycles) / real'(e2e_total_cycles)) * 100.0;
        compute_pct = (real'(compute_active_cycles) / real'(e2e_total_cycles)) * 100.0;

        $display("\n=====================================================================================");
        $display("   NPU 3x3 IM2COL PIPELINE PERFORMANCE & UTILIZATION REPORT                          ");
        $display("=====================================================================================");
        $display("  Mathematical Operations Evaluated: %10d MACs", total_macs);
        $display("  Ideal Peak Cycles (64 MACs/cycle): %10d cycles", ideal_compute_cycles);
        $display("  -----------------------------------------------------------------------------------");
        $display("  Active Compute Cycles (array_en) : %10d cycles (%5.1f%% of E2E)", compute_active_cycles, compute_pct);
        $display("  End-to-End Execution Cycles      : %10d cycles (100.0%%)", e2e_total_cycles);
        $display("  -----------------------------------------------------------------------------------");
        $display("  In-Compute Systolic Utilization  : %5.2f%%", compute_eff);
        $display("  End-to-End System Efficiency     : %5.2f%% of theoretical peak", e2e_eff);
        $display("=====================================================================================\n");
    endtask

    // =========================================================================
    // Bias Preload Task
    // =========================================================================
    task automatic preload_bias(input logic signed [31:0] bias_arr[], input int cout_b, input bit use_bank_b);
        int c, ch, m;
        logic signed [31:0] b_val;
        @(negedge clk_i);
        psum_systolic_en = 0; psum_lut_en = 0; psum_skew_en = 0;
        for (c = 0; c < 8; c++) begin
            ch = cout_b * 8 + c;
            b_val = (ch < Cout) ? bias_arr[ch] : 32'sd0;
            for (m = 0; m < 256; m++) begin
                @(negedge clk_i);
                if (!use_bank_b) begin
                    psum_A_addr  = (PSUM_ADDR_WIDTH)'(m);
                    psum_A_wdata = b_val;
                    psum_A_we    = (8'b1 << c);
                end else begin
                    psum_B_addr  = (PSUM_ADDR_WIDTH)'(m);
                    psum_B_wdata = b_val;
                    psum_B_we    = (8'b1 << c);
                end
            end
        end
        @(negedge clk_i);
        psum_A_we = 8'h00; psum_B_we = 8'h00;
    endtask

    // =========================================================================
    // Main Simulation Process
    // =========================================================================
    initial begin
        int num_ty, num_tx, cout_blks, k_total, total_passes;
        int ty, tx, cout_b, p_idx, r, c, s, k, m, m_p, ch_out;
        int g_idx, cin_curr, tap_curr, ky_curr, kx_curr;
        int cin_a, cin_b_ch;
        int ly, lx, gy, gx;
        int target_ly, target_lx, target_bank, target_addr;
        int out_y, out_x, py, px, d_idx;
        logic swap_val;
        bit init_bank_b;
        logic signed [7:0] w_slice[8][8];
        string mem_dir;
        int fd;

        num_ty       = (CONV_H + 15) / 16;
        num_tx       = (CONV_W + 15) / 16;
        cout_blks    = (Cout + 7) / 8;
        k_total      = Cin * 9;             // 16 * 9 = 144 reduction taps
        total_passes = (k_total + 7) / 8;   // 144 / 8 = 18 passes exact

        // Informative Header Banner
        $display("=====================================================================================");
        $display("   NPU BENCHMARK: 3x3 CONVOLUTION (CONTINUOUS UNROLLED IM2COL PIPELINE)               ");
        $display("=====================================================================================");
        $display("   Input Tensor Dimensions  : %0dx%0d (Height x Width), %0d Channels", CONV_H, CONV_W, Cin);
        $display("   Output Tensor Dimensions : %0dx%0d (Height x Width), %0d Channels", CONV_H, CONV_W, Cout);
        $display("   Kernel Configuration     : 3x3 Conv, Stride 1, SAME Padding");
        $display("   Spatial Partitioning     : %0dx%0d Tiles of %0dx%0d (16x16 Output + 2px Halo Window)", num_ty, num_tx, TILE_SIZE, TILE_SIZE);
        $display("   Channel Processing       : %0d Output Channel Blocks (8 Ch/Block)", cout_blks);
        $display("   Reduction Depth (K_total): %0d Taps -> %0d Passes (8 Taps/Pass continuous streaming)", k_total, total_passes);
        $display("   SRAM Bank Architecture   : 6-Bank Orthogonal Act Mapping (0..5), Dual Ping-Pong PSUM");
        $display("=====================================================================================\n");

        // Resolve memory file path: runtime plusarg (+MEM_DIR=...) -> local working dir -> relative GoldenReference
        if (!$value$plusargs("MEM_DIR=%s", mem_dir)) begin
            fd = $fopen("im2col_conv3x3_act.mem", "r");
            if (fd != 0) begin
                $fclose(fd);
                mem_dir = "./";
            end else begin
                fd = $fopen("../GoldenReference/im2col_conv3x3_act.mem", "r");
                if (fd != 0) begin
                    $fclose(fd);
                    mem_dir = "../GoldenReference/";
                end else begin
                    fd = $fopen("TEST_RTL/NPU/GoldenReference/im2col_conv3x3_act.mem", "r");
                    if (fd != 0) begin
                        $fclose(fd);
                        mem_dir = "TEST_RTL/NPU/GoldenReference/";
                    end else begin
                        mem_dir = "./";
                    end
                end
            end
        end
        if (mem_dir.len() > 0 && mem_dir[mem_dir.len()-1] != "/" && mem_dir[mem_dir.len()-1] != "\\") begin
            mem_dir = {mem_dir, "/"};
        end

        // Load reference test vectors
        $readmemh({mem_dir, "im2col_conv3x3_act.mem"},       fmap_in);
        $readmemh({mem_dir, "im2col_conv3x3_w.mem"},         w1_flat);
        $readmemh({mem_dir, "im2col_conv3x3_b.mem"},         b1_flat);
        $readmemh({mem_dir, "im2col_conv3x3_cfg.mem"},       p1_cfg);
        $readmemh({mem_dir, "im2col_conv3x3_out_quant.mem"}, gold_l1);

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
                    
                    // Initialize destination accumulator with bias
                    init_bank_b = (total_passes % 2 == 1);
                    preload_bias(b1_flat, cout_b, init_bank_b);

                    // Requantization parameter setup for current channel block
                    @(negedge clk_i); quant_shift_en = 1;
                    for (c = 7; c >= 0; c--) begin
                        int ch = cout_b * 8 + c;
                        quant_shift_in = (ch < Cout) ? p1_cfg[ch][QUANT_CFG_WIDTH-1:0] : '0;
                        @(negedge clk_i);
                    end
                    quant_shift_en = 0; quant_shift_in = '0;

                    // =========================================================================
                    // Continuous Reduction Passes
                    // =========================================================================
                    for (p_idx = 0; p_idx < total_passes; p_idx++) begin
                        cin_a    = (p_idx * 8) / 9;
                        cin_b_ch = ((p_idx * 8 + 7) < k_total) ? ((p_idx * 8 + 7) / 9) : cin_a;

                        // Stream input activations for current channel block into Banks 0..5
                        @(negedge clk_i);
                        for (ly = 0; ly < 18; ly++) begin
                            for (lx = 0; lx < 18; lx++) begin
                                gy = ty * 16 + ly - 1;
                                gx = tx * 16 + lx - 1;

                                @(negedge clk_i);
                                get_sram_loc(cin_a, ly, lx, target_bank, target_addr);
                                for (r = 0; r < 8; r++) begin
                                    if (r == target_bank) begin
                                        ext_act_sram_we[r]   = 1'b1;
                                        ext_act_sram_addr[r] = (ACT_ADDR_WIDTH)'(target_addr);
                                        if (gy >= 0 && gy < CONV_H && gx >= 0 && gx < CONV_W && cin_a < Cin)
                                            ext_act_sram_wdata[r] = fmap_in[(gy * CONV_W * Cin) + (gx * Cin) + cin_a];
                                        else
                                            ext_act_sram_wdata[r] = 8'sd0;
                                    end else begin
                                        ext_act_sram_we[r]   = 1'b0;
                                    end
                                end

                                // Stream second channel if this reduction pass bridges channel boundaries
                                if (cin_b_ch != cin_a) begin
                                    @(negedge clk_i);
                                    get_sram_loc(cin_b_ch, ly, lx, target_bank, target_addr);
                                    for (r = 0; r < 8; r++) begin
                                        if (r == target_bank) begin
                                            ext_act_sram_we[r]   = 1'b1;
                                            ext_act_sram_addr[r] = (ACT_ADDR_WIDTH)'(target_addr);
                                            if (gy >= 0 && gy < CONV_H && gx >= 0 && gx < CONV_W && cin_b_ch < Cin)
                                                ext_act_sram_wdata[r] = fmap_in[(gy * CONV_W * Cin) + (gx * Cin) + cin_b_ch];
                                            else
                                                ext_act_sram_wdata[r] = 8'sd0;
                                        end else begin
                                            ext_act_sram_we[r]   = 1'b0;
                                        end
                                    end
                                end
                            end
                        end
                        @(negedge clk_i); ext_act_sram_we = '0;

                        // Slices weights for 8 active PEs and shifts them across horizontal chains
                        for (r = 0; r < 8; r++) begin
                            g_idx = p_idx * 8 + r;
                            if (g_idx < k_total) begin
                                cin_curr = g_idx / 9;
                                tap_curr = g_idx % 9;
                                ky_curr  = tap_curr / 3;
                                kx_curr  = tap_curr % 3;

                                for (c = 0; c < 8; c++) begin
                                    ch_out = cout_b * 8 + c;
                                    if (ch_out < Cout)
                                        w_slice[r][c] = w1_flat[(ky_curr * 3 * Cin * Cout) + (kx_curr * Cin * Cout) + (cin_curr * Cout) + ch_out];
                                    else
                                        w_slice[r][c] = 8'sd0;
                                end
                            end else begin
                                for (c = 0; c < 8; c++) w_slice[r][c] = 8'sd0;
                            end
                        end
                        
                        @(negedge clk_i); weight_shift_en = {WEIGHT_SPLIT{1'b1}};
                        for (s = 0; s < 8; s++) begin
                            for (r = 0; r < 8; r++) weight_shift_in[r] = w_slice[r][7 - s];
                            @(negedge clk_i);
                        end
                        weight_shift_en = '0; 
                        @(negedge clk_i); swap_weights = 1; 
                        @(negedge clk_i); swap_weights = 0;

                        // Execute compute wave across the 8x8 PE array
                        swap_val = (total_passes % 2 == 0) ? ((p_idx % 2 == 0) ? 1'b0 : 1'b1) : ((p_idx % 2 == 0) ? 1'b1 : 1'b0);

                        @(negedge clk_i);
                        array_en          = 1; 
                        psum_systolic_en  = 1; 
                        psum_lut_en       = 0; 
                        psum_skew_en      = 1; 
                        compute_bank_swap = swap_val;

                        for (k = 0; k < 256 + ARRAY_HEIGHT + ARRAY_WIDTH; k++) begin
                            @(negedge clk_i);
                            
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

                                    crossbar_sel[r]                = 4'(target_bank);
                                    ext_act_sram_addr[target_bank] = (ACT_ADDR_WIDTH)'(target_addr);
                                end else begin
                                    crossbar_sel[r] = 4'b1000;
                                end
                            end

                            if (!swap_val) begin
                                psum_A_addr = (k < 256) ? (PSUM_ADDR_WIDTH)'(k) : '0;
                                psum_B_addr = (k >= 9 && (k - 9) < 256) ? (PSUM_ADDR_WIDTH)'(k - 9) : '0;
                                psum_A_we   = 8'h00;
                                for (c = 0; c < ARRAY_WIDTH; c++) begin
                                    psum_B_we[c] = (k >= (9 + c) && (k - (9 + c)) < 256) ? 1'b1 : 1'b0;
                                end
                            end else begin
                                psum_B_addr = (k < 256) ? (PSUM_ADDR_WIDTH)'(k) : '0;
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
                    end

                    // =========================================================================
                    // Drain Sweep 1: Quantized INT8 Output Read (Via 2-cycle Requantizer)
                    // =========================================================================
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

                    // =========================================================================
                    // Drain Sweep 2: Raw PSUM Sanity-Check Read (Direct from SRAM)
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

                end
            end
        end

        // Calculate Final Deployment End-to-End Latency
        e2e_total_cycles = (global_cycle - e2e_start_cycle) - raw_drain_cycles;

        // =========================================================================
        // Diagnostic & Utilization Reporting
        // =========================================================================
        inspect_full_layer_diagnostics();
        print_performance_report();

        #200; $finish;
    end
endmodule