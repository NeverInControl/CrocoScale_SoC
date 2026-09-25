`timescale 1ns / 1ps

module tb_npu_whole_net;

    // =========================================================================
    // Architecture & Multi-Layer Configuration
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

    localparam int PSUM_WORDS       = TILE_SIZE * TILE_SIZE; // 256
    localparam int ACT_WORDS        = (TILE_SIZE * TILE_SIZE) * ACT_HALO_PAD; // 512
    localparam int PSUM_ADDR_WIDTH  = $clog2(PSUM_WORDS);
    localparam int ACT_ADDR_WIDTH   = $clog2(ACT_WORDS);
    localparam int NUM_ACT_BANKS    = ARRAY_HEIGHT;
    localparam int NUM_PSUM_BANKS   = ARRAY_WIDTH * 2;
    localparam int XBAR_SEL_WIDTH   = $clog2(ARRAY_HEIGHT) + 1;
    localparam int BANK_SEL_WIDTH   = $clog2(ARRAY_WIDTH);
    localparam int PROD_WIDTH       = PSUM_WIDTH + SCALE_WIDTH;
    localparam int SHIFT_WIDTH      = $clog2(PROD_WIDTH);
    localparam int QUANT_CFG_WIDTH  = SCALE_WIDTH + SHIFT_WIDTH + ACTIVATION_WIDTH;

    localparam int H_IN = 64, W_IN = 64;
    localparam int H_OUT = 32, W_OUT = 32;
    localparam int C0 = 16, C1 = 24, C2 = 24, C3 = 24, C4 = 16, C5 = 16;

    // =========================================================================
    // DUT Interface Signals
    // =========================================================================
    logic clk_i, rst_n, array_en, psum_systolic_en, psum_lut_en;
    logic [ARRAY_HEIGHT-1:0][XBAR_SEL_WIDTH-1:0] crossbar_sel;
    logic signed [ARRAY_HEIGHT-1:0][WEIGHT_WIDTH-1:0] weight_shift_in;
    logic [WEIGHT_SPLIT-1:0] weight_shift_en;
    logic swap_weights;
    logic [QUANT_CFG_WIDTH-1:0] quant_shift_in;
    logic quant_shift_en, stochastic_round_en;
    wire  [SCALE_WIDTH-1:0] lfsr_data_out;
    logic psum_skew_en, compute_bank_swap;

    logic [PSUM_ADDR_WIDTH-1:0] psum_A_addr, psum_B_addr;
    logic [ARRAY_WIDTH-1:0]     psum_A_we,   psum_B_we;
    logic signed [PSUM_WIDTH-1:0] psum_A_wdata, psum_B_wdata;
    logic [BANK_SEL_WIDTH-1:0]  psum_A_read_bank_sel, psum_B_read_bank_sel;
    wire  signed [PSUM_WIDTH-1:0] psum_A_rdata, psum_B_rdata;

    logic [NUM_ACT_BANKS-1:0] ext_act_sram_we;
    logic [NUM_ACT_BANKS-1:0][ACT_ADDR_WIDTH-1:0] ext_act_sram_addr;
    logic signed [NUM_ACT_BANKS-1:0][ACTIVATION_WIDTH-1:0] ext_act_sram_wdata;
    wire  signed [NUM_ACT_BANKS-1:0][ACTIVATION_WIDTH-1:0] act_sram_rdata;
    wire  signed [ARRAY_WIDTH-1:0][ACTIVATION_WIDTH-1:0] out_act;

    // =========================================================================
    // On-Chip Ping-Pong Feature Map Memory & Weight Storage
    // =========================================================================
    logic signed [7:0] fmap_in    [H_IN * W_IN * C0];
    logic signed [7:0] fmap_buf_A [H_IN][W_IN][32]; // Scratchpad A
    logic signed [7:0] fmap_buf_B [H_IN][W_IN][32]; // Scratchpad B

    logic signed [7:0] gold_l1 [H_IN * W_IN * C1];
    logic signed [7:0] gold_l2 [H_IN * W_IN * C2];
    logic signed [7:0] gold_l3 [H_OUT * W_OUT * C3];
    logic signed [7:0] gold_l4 [H_OUT * W_OUT * C4];
    logic signed [7:0] gold_l5 [H_OUT * W_OUT * C5];

    logic signed [7:0]  w1_flat [3 * 3 * C0 * C1]; logic signed [31:0] b1_flat [C1]; logic [31:0] cfg1 [C1];
    logic signed [7:0]  w2_flat [C1 * C2];         logic signed [31:0] b2_flat [C2]; logic [31:0] cfg2 [C2];
    logic signed [7:0]  w3_flat [3 * 3 * C2 * C3]; logic signed [31:0] b3_flat [C3]; logic [31:0] cfg3 [C3];
    logic signed [7:0]  w4_flat [C3 * C4];         logic signed [31:0] b4_flat [C4]; logic [31:0] cfg4 [C4];
    logic signed [7:0]  w5_flat [3 * 3 * C4 * C5]; logic signed [31:0] b5_flat [C5]; logic [31:0] cfg5 [C5];
    logic signed [7:0]  lut_silu[256];

    longint global_cycle = 0;
    typedef struct {
        string  name;
        longint total_cycles;
        longint macs;
        int     exact_cnt;
        int     tol1_cnt;
        int     tol5_cnt;
        int     outlier_cnt;
        int     max_drift;
    } layer_profile_t;

    layer_profile_t profs[5];

    always #5 begin
        clk_i = ~clk_i;
        if (clk_i) global_cycle++;
    end

    npu_wrapper #(
        .ARRAY_HEIGHT(ARRAY_HEIGHT), .ARRAY_WIDTH(ARRAY_WIDTH), .TILE_SIZE(TILE_SIZE),
        .ACT_HALO_PAD(ACT_HALO_PAD), .ACTIVATION_WIDTH(ACTIVATION_WIDTH), .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .PSUM_WIDTH(PSUM_WIDTH), .SCALE_WIDTH(SCALE_WIDTH), .ENABLE_LFSR(ENABLE_LFSR), .WEIGHT_SPLIT(WEIGHT_SPLIT)
    ) dut (
        .clk_i(clk_i), .rst_n(rst_n), .array_en(array_en), .psum_systolic_en(psum_systolic_en),
        .psum_lut_en(psum_lut_en), .crossbar_sel(crossbar_sel), .weight_shift_in(weight_shift_in),
        .weight_shift_en(weight_shift_en), .swap_weights(swap_weights), .quant_shift_in(quant_shift_in),
        .quant_shift_en(quant_shift_en), .stochastic_round_en(stochastic_round_en), .lfsr_data_out(lfsr_data_out),
        .psum_skew_en(psum_skew_en), .compute_bank_swap(compute_bank_swap),
        .psum_A_addr(psum_A_addr), .psum_A_we(psum_A_we), .psum_A_wdata(psum_A_wdata),
        .psum_A_read_bank_sel(psum_A_read_bank_sel), .psum_A_rdata(psum_A_rdata),
        .psum_B_addr(psum_B_addr), .psum_B_we(psum_B_we), .psum_B_wdata(psum_B_wdata),
        .psum_B_read_bank_sel(psum_B_read_bank_sel), .psum_B_rdata(psum_B_rdata),
        .ext_act_sram_we(ext_act_sram_we), .ext_act_sram_addr(ext_act_sram_addr),
        .ext_act_sram_wdata(ext_act_sram_wdata), .act_sram_rdata(act_sram_rdata), .out_act(out_act)
    );

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
            mem_dir = "TEST/NPU/GoldenReference/";
            fd = $fopen({mem_dir, sample_file}, "r");
            if (fd != 0) begin $fclose(fd); found = 1; end
        end

        // 3. Fail immediately if neither worked
        if (!found) begin
            $display("\n=====================================================================================");
            $display(" [FATAL ERROR] Required test vector file '%s' was NOT found!", sample_file);
            $display(" Checked plusarg path and standard default 'TEST/NPU/GoldenReference/'.");
            $display(" Please provide a valid path via +MEM_DIR=<path> (e.g. in Vivado simulation settings).");
            $display("=====================================================================================");
            $fatal(1, "Aborting simulation due to missing test vector files.");
        end
    endtask

    function automatic void check_file_exists(input string filename);
        int fd = $fopen(filename, "r");
        if (fd == 0) begin
            $display("\n=====================================================================================");
            $display(" [FATAL ERROR] Required memory file '%s' was NOT found!", filename);
            $display("=====================================================================================\n");
            $fatal(1, "Aborting simulation due to missing test vector files.");
        end
        $fclose(fd);
    endfunction

    task automatic assert_vector_nonzero(
        input string vec_name,
        input int nonzero_count,
        input int min_required = 1
    );
        if (nonzero_count < min_required) begin
            $display("\n[FATAL ERROR] Test vector '%s' is empty or all-zero (%0d non-zero elements, min required: %0d)!",
                     vec_name, nonzero_count, min_required);
            $fatal(1, "Zero-vector guard triggered: preventing false-positive pass.");
        end
    endtask

    function automatic void get_sram_loc(input int cin, input int ly, input int lx, output int bank, output int addr);
        int h = (lx >= 9) ? 1 : 0;
        int x_off = (lx >= 9) ? (lx - 9) : lx;
        bank = (ly % 3) * 2 + h;
        addr = (cin % 8) * 64 + (ly / 3) * 9 + x_off;
    endfunction

    function automatic string get_progress_bar(input int current, input int total);
        string bar = "[";
        int filled = (current * 20) / total;
        for (int i = 0; i < 20; i++) begin
            if (i < filled) bar = {bar, "="};
            else if (i == filled) bar = {bar, ">"};
            else bar = {bar, " "};
        end
        bar = {bar, "]"};
        return bar;
    endfunction

    function automatic logic signed [7:0] read_input_pixel(
        input int src_sel, input int cur_h, input int cur_w, input int c, input int b, input int step, input int ty, input int tx, input logic signed [7:0] pad_zp
    );
        int ly = (b / 2) + (step / 9) * 3;
        int lx = (b % 2 == 1 ? 9 : 0) + (step % 9);
        int gy = ty * 16 + ly - 1;
        int gx = tx * 16 + lx - 1;
        if (gy >= 0 && gy < cur_h && gx >= 0 && gx < cur_w) begin
            if (src_sel == 0) return fmap_in[(gy * cur_w * C0) + (gx * C0) + c];
            if (src_sel == 1) return fmap_buf_A[gy][gx][c];
            if (src_sel == 2) return fmap_buf_B[gy][gx][c];
        end
        return pad_zp;
    endfunction

    task automatic evaluate_layer(input int l_idx, input string name, input int cur_h, input int cur_w, input int num_ch, input int src_buf, input logic signed [7:0] golden[]);
        int total = cur_h * cur_w * num_ch;
        int diff, abs_d;
        profs[l_idx].name = name;
        profs[l_idx].exact_cnt = 0; profs[l_idx].tol1_cnt = 0; profs[l_idx].tol5_cnt = 0;
        profs[l_idx].outlier_cnt = 0; profs[l_idx].max_drift = 0;

        for (int y = 0; y < cur_h; y++) begin
            for (int x = 0; x < cur_w; x++) begin
                for (int c = 0; c < num_ch; c++) begin
                    int flat = (y * cur_w * num_ch) + (x * num_ch) + c;
                    logic signed [7:0] act_val;
                    act_val = (src_buf == 1) ? fmap_buf_A[y][x][c] : fmap_buf_B[y][x][c];
                    diff = int'(act_val) - int'(golden[flat]);
                    abs_d = (diff < 0) ? -diff : diff;
                    if (abs_d > profs[l_idx].max_drift) profs[l_idx].max_drift = abs_d;
                    if (abs_d == 0) profs[l_idx].exact_cnt++;
                    if (abs_d <= 1) profs[l_idx].tol1_cnt++;
                    if (abs_d <= 5) profs[l_idx].tol5_cnt++;
                    else            profs[l_idx].outlier_cnt++;
                end
            end
        end
    endtask

    // =========================================================================
    // 3x3 Stride-1 Engine
    // =========================================================================
    task automatic execute_conv3x3(
        input string layer_label,
        input int src_sel, input int dst_sel,
        input int cur_h, input int cur_w,
        input int Cin_val, input int Cout_val,
        input logic signed [7:0] w_flat[],
        input logic signed [31:0] b_flat[],
        input logic [31:0] cfg_flat[],
        input logic signed [7:0] in_pad_zp,
        input bit use_silu
    );
        int total_passes = (Cin_val * 9 + 7) / 8;
        int cout_blks    = (Cout_val + 7) / 8;
        int num_ty       = cur_h / 16;
        int num_tx       = cur_w / 16;
        int total_blks   = num_ty * num_tx * cout_blks;
        int done_blks    = 0;
        int dma_sched [36];
        logic signed [7:0] w_slice[8][8];
        logic signed [7:0] next_w_slice[8][8];
        int dma_ch, dma_ptr[6], t_bank_arr[8], t_addr_arr[8];
        bit r_active[8], b_used[6];
        logic swap_val, hold_bias;
        bit init_bank_b;

        for (int p = 0; p < total_passes; p++) dma_sched[p] = -1;
        for (int ch = 1; ch < Cin_val; ch++) dma_sched[((9 * ch) / 8) - 1] = ch;

        for (int ty = 0; ty < num_ty; ty++) begin
            for (int tx = 0; tx < num_tx; tx++) begin
                for (int cout_b = 0; cout_b < cout_blks; cout_b++) begin
                    
                    init_bank_b = (total_passes % 2 == 1);

                    for (int r = 0; r < 8; r++) begin
                        for (int c = 0; c < 8; c++) begin
                            int ch_out = cout_b * 8 + c;
                            w_slice[r][c] = (r < (Cin_val * 9) && ch_out < Cout_val) ? 
                                            w_flat[((r % 9) / 3) * 3 * Cin_val * Cout_val + ((r % 9) % 3) * Cin_val * Cout_val + (r / 9) * Cout_val + ch_out] : 8'sd0;
                        end
                    end

                    for (int s = 0; s < 54; s++) begin
                        @(negedge clk_i);
                        for (int b = 0; b < 6; b++) begin
                            ext_act_sram_we[b] = 1'b1; ext_act_sram_addr[b] = (ACT_ADDR_WIDTH)'(s);
                            ext_act_sram_wdata[b] = read_input_pixel(src_sel, cur_h, cur_w, 0, b, s, ty, tx, in_pad_zp);
                        end
                        ext_act_sram_we[6] = 1'b0;
                        ext_act_sram_we[7] = 1'b0;

                        if (s < 8) begin
                            int ch = cout_b * 8 + s;
                            if (!init_bank_b) begin
                                psum_A_addr = '0; psum_A_wdata = (ch < Cout_val) ? b_flat[ch] : 32'sd0;
                                psum_A_we = (8'b1 << s); psum_B_we = 8'h00;
                            end else begin
                                psum_B_addr = '0; psum_B_wdata = (ch < Cout_val) ? b_flat[ch] : 32'sd0;
                                psum_B_we = (8'b1 << s); psum_A_we = 8'h00;
                            end
                            quant_shift_en = 1'b1; quant_shift_in = (cout_b * 8 + (7 - s) < Cout_val) ? cfg_flat[cout_b * 8 + (7 - s)][QUANT_CFG_WIDTH-1:0] : '0;
                            weight_shift_en = {WEIGHT_SPLIT{1'b1}};
                            for (int r = 0; r < 8; r++) weight_shift_in[r] = w_slice[r][7 - s];
                        end else begin
                            psum_A_we = '0; psum_B_we = '0; quant_shift_en = '0; weight_shift_en = '0;
                            swap_weights = (s == 8);
                        end
                    end
                    @(negedge clk_i); ext_act_sram_we = '0; swap_weights = 0;

                    for (int p_idx = 0; p_idx < total_passes; p_idx++) begin
                        int pass_len = (p_idx == total_passes - 1) ? (256 + 16) : (256 + 9);
                        dma_ch = dma_sched[p_idx];
                        for (int b = 0; b < 6; b++) dma_ptr[b] = 0;
                        swap_val = (total_passes % 2 == 0) ? ((p_idx % 2 == 0) ? 1'b0 : 1'b1) : ((p_idx % 2 == 0) ? 1'b1 : 1'b0);
                        hold_bias = (p_idx == 0);

                        if (p_idx + 1 < total_passes) begin
                            for (int r = 0; r < 8; r++) begin
                                for (int c = 0; c < 8; c++) begin
                                    int g = (p_idx + 1) * 8 + r;
                                    int ch_out = cout_b * 8 + c;
                                    next_w_slice[r][c] = (g < (Cin_val * 9) && ch_out < Cout_val) ? 
                                                        w_flat[((g % 9) / 3) * 3 * Cin_val * Cout_val + ((g % 9) % 3) * Cin_val * Cout_val + (g / 9) * Cout_val + ch_out] : 8'sd0;
                                end
                            end
                        end

                        for (int k = 0; k < pass_len; k++) begin
                            @(negedge clk_i);
                            if (k == 0) begin
                                array_en = 1; psum_systolic_en = 1; psum_skew_en = 1; compute_bank_swap = swap_val;
                            end

                            for (int b = 0; b < 6; b++) b_used[b] = 1'b0;
                            for (int r = 0; r < 8; r++) begin
                                int g = p_idx * 8 + r;
                                int m = k - r;
                                if (m >= 0 && m < 256 && g < (Cin_val * 9)) begin
                                    int tb, ta;
                                    get_sram_loc(g / 9, (m / 16) + ((g % 9) / 3), (m % 16) + ((g % 9) % 3), tb, ta);
                                    t_bank_arr[r] = tb; t_addr_arr[r] = ta; r_active[r] = 1'b1;
                                    crossbar_sel[r] = 4'(tb); if (tb < 6) b_used[tb] = 1'b1;
                                end else begin
                                    t_bank_arr[r] = -1; r_active[r] = 1'b0; crossbar_sel[r] = 4'b1000;
                                end
                            end

                            for (int b = 0; b < 6; b++) begin
                                if (b_used[b]) begin
                                    ext_act_sram_we[b] = 1'b0;
                                    for (int r = 0; r < 8; r++) if (r_active[r] && t_bank_arr[r] == b) ext_act_sram_addr[b] = (ACT_ADDR_WIDTH)'(t_addr_arr[r]);
                                end else if (dma_ch >= 0 && dma_ptr[b] < 54) begin
                                    ext_act_sram_we[b] = 1'b1;
                                    ext_act_sram_addr[b] = (ACT_ADDR_WIDTH)'(((dma_ch % 8) * 64) + dma_ptr[b]);
                                    ext_act_sram_wdata[b] = read_input_pixel(src_sel, cur_h, cur_w, dma_ch, b, dma_ptr[b], ty, tx, in_pad_zp);
                                    dma_ptr[b]++;
                                end else ext_act_sram_we[b] = 1'b0;
                            end
                            ext_act_sram_we[6] = 1'b0;
                            ext_act_sram_we[7] = 1'b0;

                            if (p_idx + 1 < total_passes && k >= 32 && k < 40) begin
                                weight_shift_en = {WEIGHT_SPLIT{1'b1}};
                                for (int r = 0; r < 8; r++) weight_shift_in[r] = next_w_slice[r][7 - (k - 32)];
                            end else if (p_idx + 1 < total_passes && k == pass_len - 1) begin
                                weight_shift_en = '0; swap_weights = 1'b1;
                            end else begin
                                weight_shift_en = '0; swap_weights = 1'b0;
                            end

                            if (!swap_val) begin
                                psum_A_addr = hold_bias ? '0 : ((k < 256) ? (PSUM_ADDR_WIDTH)'(k) : '0);
                                psum_B_addr = (k >= 9 && (k - 9) < 256) ? (PSUM_ADDR_WIDTH)'(k - 9) : '0;
                                for (int c = 0; c < 8; c++) begin
                                    psum_B_we[c] = (k >= (9 + c) && (k - (9 + c)) < 256);
                                    psum_A_we[c] = (p_idx > 0 && k < c);
                                end
                            end else begin
                                psum_B_addr = hold_bias ? '0 : ((k < 256) ? (PSUM_ADDR_WIDTH)'(k) : '0);
                                psum_A_addr = (k >= 9 && (k - 9) < 256) ? (PSUM_ADDR_WIDTH)'(k - 9) : '0;
                                for (int c = 0; c < 8; c++) begin
                                    psum_A_we[c] = (k >= (9 + c) && (k - (9 + c)) < 256);
                                    psum_B_we[c] = (p_idx > 0 && k < c);
                                end
                            end
                        end
                    end
                    @(negedge clk_i); array_en = 0; psum_systolic_en = 0; psum_skew_en = 0; psum_A_we = '0; psum_B_we = '0;

                    if (!use_silu) begin
                        for (int m = 0; m < 256 + 3; m++) begin
                            @(negedge clk_i); if (m < 256) psum_A_addr = (PSUM_ADDR_WIDTH)'(m);
                            @(posedge clk_i); #1;
                            if (m >= 2 && m < 258) begin
                                int py = ty * 16 + ((m - 2) / 16);
                                int px = tx * 16 + ((m - 2) % 16);
                                for (int c = 0; c < 8; c++) begin
                                    int ch = cout_b * 8 + c;
                                    if (ch < Cout_val) begin
                                        logic signed [7:0] zp_val = $signed(cfg_flat[ch][29:22]);
                                        logic signed [7:0] v = (out_act[c] < zp_val) ? zp_val : out_act[c];
                                        if (dst_sel == 1) fmap_buf_A[py][px][ch] = v;
                                        else              fmap_buf_B[py][px][ch] = v;
                                    end
                                end
                            end
                        end
                    end else begin
                        psum_B_we = 8'hFF;
                        for (int a = 0; a < 256; a++) begin
                            @(negedge clk_i); psum_B_addr = (PSUM_ADDR_WIDTH)'(a); psum_B_wdata = {24'd0, lut_silu[a]};
                        end
                        @(negedge clk_i); psum_B_we = '0; psum_lut_en = 1;
                        for (int m = 0; m < 256 + 4; m++) begin
                            @(negedge clk_i); if (m < 256) psum_A_addr = (PSUM_ADDR_WIDTH)'(m);
                            @(posedge clk_i); #1;
                            if (m >= 3 && m < 259) begin
                                int py = ty * 16 + ((m - 3) / 16);
                                int px = tx * 16 + ((m - 3) % 16);
                                for (int c = 0; c < 8; c++) begin
                                    int ch = cout_b * 8 + c;
                                    if (ch < Cout_val) begin
                                        if (dst_sel == 1) fmap_buf_A[py][px][ch] = out_act[c];
                                        else              fmap_buf_B[py][px][ch] = out_act[c];
                                    end
                                end
                            end
                        end
                        psum_lut_en = 0;
                    end

                    done_blks++;
                    if ((done_blks % 4) == 0 || done_blks == total_blks) begin
                        $display("  [%-16s] %s %3d%% (Block %2d/%2d) | Cycle: %8d",
                                 layer_label, get_progress_bar(done_blks, total_blks),
                                 (done_blks * 100) / total_blks, done_blks, total_blks, global_cycle);
                    end
                end
            end
        end
    endtask

    // =========================================================================
    // 3x3 Stride-2 Downsampling Engine (Clean Accumulator Isolation)
    // =========================================================================
    task automatic execute_conv3x3_stride2(
        input string layer_label,
        input int src_sel, input int dst_sel,
        input int Cin_val, input int Cout_val,
        input logic signed [7:0] w_flat[],
        input logic signed [31:0] b_flat[],
        input logic [31:0] cfg_flat[],
        input logic signed [7:0] in_pad_zp
    );
        int total_passes = (Cin_val * 9 + 7) / 8; // 216 / 8 = 27
        int cout_blks    = (Cout_val + 7) / 8;     // 24 / 8 = 3
        int num_ty       = H_OUT / 16;             // 2
        int num_tx       = W_OUT / 16;             // 2
        int total_blks   = num_ty * num_tx * cout_blks; // 12
        int done_blks    = 0;
        logic signed [7:0] w_slice[8][8];
        logic swap_val, hold_bias;
        bit init_bank_b;

        for (int ty = 0; ty < num_ty; ty++) begin
            for (int tx = 0; tx < num_tx; tx++) begin
                for (int cout_b = 0; cout_b < cout_blks; cout_b++) begin
                    
                    init_bank_b = (total_passes % 2 == 1);

                    for (int p_idx = 0; p_idx < total_passes; p_idx++) begin
                        swap_val  = (total_passes % 2 == 0) ? ((p_idx % 2 == 0) ? 1'b0 : 1'b1) : ((p_idx % 2 == 0) ? 1'b1 : 1'b0);
                        hold_bias = (p_idx == 0);

                        // 1. Sliced Weights for Current Pass
                        for (int r = 0; r < 8; r++) begin
                            for (int c = 0; c < 8; c++) begin
                                int g = p_idx * 8 + r;
                                int ch_out = cout_b * 8 + c;
                                w_slice[r][c] = (g < (Cin_val * 9) && ch_out < Cout_val) ? 
                                                w_flat[((g % 9) / 3) * 3 * Cin_val * Cout_val + ((g % 9) % 3) * Cin_val * Cout_val + (g / 9) * Cout_val + ch_out] : 8'sd0;
                            end
                        end

                        // 2. Parallel DMA Stream for Current 8 Reduction Taps
                        for (int m = 0; m < 256; m++) begin
                            int out_y = m / 16;
                            int out_x = m % 16;
                            int py = ty * 16 + out_y;
                            int px = tx * 16 + out_x;

                            @(negedge clk_i);
                            ext_act_sram_we = 8'hFF;
                            for (int r = 0; r < 8; r++) begin
                                int g = p_idx * 8 + r;
                                ext_act_sram_addr[r] = (ACT_ADDR_WIDTH)'(m);
                                if (g < (Cin_val * 9)) begin
                                    int cin = g / 9;
                                    int ky  = (g % 9) / 3;
                                    int kx  = (g % 9) % 3;
                                    int gy  = py * 2 + ky; // Stride-2
                                    int gx  = px * 2 + kx; // Stride-2
                                    if (gy >= 0 && gy < H_IN && gx >= 0 && gx < W_IN)
                                        ext_act_sram_wdata[r] = (src_sel == 1) ? fmap_buf_A[gy][gx][cin] : fmap_buf_B[gy][gx][cin];
                                    else
                                        ext_act_sram_wdata[r] = in_pad_zp;
                                end else begin
                                    ext_act_sram_wdata[r] = in_pad_zp;
                                end
                            end

                            if (p_idx == 0 && m < 8) begin
                                int ch = cout_b * 8 + m;
                                if (!init_bank_b) begin
                                    psum_A_addr = '0; psum_A_wdata = (ch < Cout_val) ? b_flat[ch] : 32'sd0;
                                    psum_A_we = (8'b1 << m); psum_B_we = 8'h00;
                                end else begin
                                    psum_B_addr = '0; psum_B_wdata = (ch < Cout_val) ? b_flat[ch] : 32'sd0;
                                    psum_B_we = (8'b1 << m); psum_A_we = 8'h00;
                                end
                                quant_shift_en = 1'b1; quant_shift_in = (cout_b * 8 + (7 - m) < Cout_val) ? cfg_flat[cout_b * 8 + (7 - m)][QUANT_CFG_WIDTH-1:0] : '0;
                            end else begin
                                psum_A_we = '0; psum_B_we = '0; quant_shift_en = '0;
                            end

                            if (m < 8) begin
                                weight_shift_en = {WEIGHT_SPLIT{1'b1}};
                                for (int r = 0; r < 8; r++) weight_shift_in[r] = w_slice[r][7 - m];
                                swap_weights = 1'b0;
                            end else if (m == 8) begin
                                weight_shift_en = '0; swap_weights = 1'b1;
                            end else begin
                                weight_shift_en = '0; swap_weights = 1'b0;
                            end
                        end
                        @(negedge clk_i); ext_act_sram_we = '0; swap_weights = 0;

                        // 3. Isolated Systolic Compute (Zero Stale Accumulator Overwrite)
                        for (int k = 0; k < 256 + 16; k++) begin
                            @(negedge clk_i);
                            if (k == 0) begin
                                array_en = 1; psum_systolic_en = 1; psum_skew_en = 1; compute_bank_swap = swap_val;
                                for (int r = 0; r < 8; r++) crossbar_sel[r] = 4'(r);
                            end
                            for (int r = 0; r < 8; r++) begin
                                ext_act_sram_addr[r] = (k >= r && (k - r) < 256) ? (ACT_ADDR_WIDTH)'(k - r) : '0;
                            end

                            if (!swap_val) begin
                                psum_A_addr = hold_bias ? '0 : ((k < 256) ? (PSUM_ADDR_WIDTH)'(k) : '0);
                                psum_B_addr = (k >= 9 && (k - 9) < 256) ? (PSUM_ADDR_WIDTH)'(k - 9) : '0;
                                psum_A_we   = '0; // Fixed: strictly disable Bank A during Bank B write phase
                                for (int c = 0; c < 8; c++) begin
                                    psum_B_we[c] = (k >= (9 + c) && (k - (9 + c)) < 256);
                                end
                            end else begin
                                psum_B_addr = hold_bias ? '0 : ((k < 256) ? (PSUM_ADDR_WIDTH)'(k) : '0);
                                psum_A_addr = (k >= 9 && (k - 9) < 256) ? (PSUM_ADDR_WIDTH)'(k - 9) : '0;
                                psum_B_we   = '0; // Fixed: strictly disable Bank B during Bank A write phase
                                for (int c = 0; c < 8; c++) begin
                                    psum_A_we[c] = (k >= (9 + c) && (k - (9 + c)) < 256);
                                end
                            end
                        end
                        @(negedge clk_i); array_en = 0; psum_systolic_en = 0; psum_skew_en = 0; psum_A_we = '0; psum_B_we = '0;
                    end

                    // 4. Drain Output
                    for (int m = 0; m < 256 + 3; m++) begin
                        @(negedge clk_i); if (m < 256) psum_A_addr = (PSUM_ADDR_WIDTH)'(m);
                        @(posedge clk_i); #1;
                        if (m >= 2 && m < 258) begin
                            int py = ty * 16 + ((m - 2) / 16);
                            int px = tx * 16 + ((m - 2) % 16);
                            for (int c = 0; c < 8; c++) begin
                                int ch = cout_b * 8 + c;
                                if (ch < Cout_val) begin
                                    logic signed [7:0] zp_val = $signed(cfg_flat[ch][29:22]);
                                    logic signed [7:0] v = (out_act[c] < zp_val) ? zp_val : out_act[c];
                                    if (dst_sel == 1) fmap_buf_A[py][px][ch] = v;
                                    else              fmap_buf_B[py][px][ch] = v;
                                end
                            end
                        end
                    end

                    done_blks++;
                    $display("  [%-16s] %s %3d%% (Block %2d/%2d) | Cycle: %8d",
                             layer_label, get_progress_bar(done_blks, total_blks),
                             (done_blks * 100) / total_blks, done_blks, total_blks, global_cycle);
                end
            end
        end
    endtask

    // =========================================================================
    // 1x1 Half-Array Double-Buffered Engine
    // =========================================================================
    task automatic execute_conv1x1(
        input string layer_label,
        input int src_sel, input int dst_sel,
        input int cur_h, input int cur_w,
        input int Cin_val, input int Cout_val,
        input logic signed [7:0] w_flat[],
        input logic signed [31:0] b_flat[],
        input logic [31:0] cfg_flat[]
    );
        int total_cin_passes = (Cin_val + 3) / 4;
        int cout_blks        = (Cout_val + 7) / 8;
        int num_ty           = cur_h / 16;
        int num_tx           = cur_w / 16;
        int total_blks       = num_ty * num_tx * cout_blks;
        int done_blks        = 0;
        logic swap_val, hold_bias;
        bit init_bank_b;
        logic signed [7:0] w_slice[8][8];
        logic signed [7:0] next_w_slice[8][8];

        for (int ty = 0; ty < num_ty; ty++) begin
            for (int tx = 0; tx < num_tx; tx++) begin
                for (int cout_b = 0; cout_b < cout_blks; cout_b++) begin
                    init_bank_b = (total_cin_passes % 2 == 1);

                    // Preload Pass 0 (4 Channels)
                    for (int r = 0; r < 8; r++) begin
                        for (int c = 0; c < 8; c++) begin
                            int c_in  = r;
                            int c_out = cout_b * 8 + c;
                            w_slice[r][c] = (r < 4 && c_in < Cin_val && c_out < Cout_val) ? w_flat[c_in * Cout_val + c_out] : 8'sd0;
                        end
                    end

                    for (int m = 0; m < 256; m++) begin
                        @(negedge clk_i);
                        for (int b = 0; b < 4; b++) begin
                            ext_act_sram_we[b]    = 1'b1;
                            ext_act_sram_addr[b]  = (ACT_ADDR_WIDTH)'(m);
                            ext_act_sram_wdata[b] = (src_sel == 1) ? fmap_buf_A[ty * 16 + (m / 16)][tx * 16 + (m % 16)][b] :
                                                                     fmap_buf_B[ty * 16 + (m / 16)][tx * 16 + (m % 16)][b];
                        end
                        for (int b = 4; b < 8; b++) ext_act_sram_we[b] = 1'b0;

                        if (m < 8) begin
                            int ch = cout_b * 8 + m;
                            if (!init_bank_b) begin
                                psum_A_addr = '0; psum_A_wdata = (ch < Cout_val) ? b_flat[ch] : 32'sd0;
                                psum_A_we = (8'b1 << m); psum_B_we = 8'h00;
                            end else begin
                                psum_B_addr = '0; psum_B_wdata = (ch < Cout_val) ? b_flat[ch] : 32'sd0;
                                psum_B_we = (8'b1 << m); psum_A_we = 8'h00;
                            end
                            quant_shift_en = 1'b1;
                            quant_shift_in = (cout_b * 8 + (7 - m) < Cout_val) ? cfg_flat[cout_b * 8 + (7 - m)][QUANT_CFG_WIDTH-1:0] : '0;
                        end else begin
                            psum_A_we = 8'h00; psum_B_we = 8'h00; quant_shift_en = 1'b0;
                        end

                        if (m < 8) begin
                            weight_shift_en = {WEIGHT_SPLIT{1'b1}};
                            for (int r = 0; r < 8; r++) weight_shift_in[r] = w_slice[r][7 - m];
                            swap_weights = 1'b0;
                        end else if (m == 8) begin
                            weight_shift_en = '0; swap_weights = 1'b1;
                        end else begin
                            weight_shift_en = '0; swap_weights = 1'b0;
                        end
                    end
                    @(negedge clk_i); ext_act_sram_we = '0; psum_A_we = '0; psum_B_we = '0; quant_shift_en = '0; weight_shift_en = '0; swap_weights = '0;

                    // Compute Passes
                    for (int p = 0; p < total_cin_passes; p++) begin
                        int next_p         = p + 1;
                        int pass_len       = 256 + 16;
                        int cur_bank_base  = (p % 2 == 0) ? 0 : 4;
                        int next_bank_base = (p % 2 == 0) ? 4 : 0;
                        swap_val  = (total_cin_passes % 2 == 0) ? ((p % 2 == 0) ? 1'b0 : 1'b1) : ((p % 2 == 0) ? 1'b1 : 1'b0);
                        hold_bias = (p == 0);

                        if (next_p < total_cin_passes) begin
                            for (int r = 0; r < 8; r++) begin
                                for (int c = 0; c < 8; c++) begin
                                    int c_in  = next_p * 4 + r;
                                    int c_out = cout_b * 8 + c;
                                    next_w_slice[r][c] = (r < 4 && c_in < Cin_val && c_out < Cout_val) ? w_flat[c_in * Cout_val + c_out] : 8'sd0;
                                end
                            end
                        end

                        for (int k = 0; k < pass_len; k++) begin
                            @(negedge clk_i);

                            if (k == 0) begin
                                array_en          = 1;
                                psum_systolic_en  = 1;
                                psum_skew_en      = 1;
                                compute_bank_swap = swap_val;
                                for (int r = 0; r < 4; r++) crossbar_sel[r] = 4'(cur_bank_base + r);
                                for (int r = 4; r < 8; r++) crossbar_sel[r] = 4'b1000;
                            end

                            for (int r = 0; r < 4; r++) begin
                                int b_cur = cur_bank_base + r;
                                ext_act_sram_we[b_cur] = 1'b0;
                                ext_act_sram_addr[b_cur] = (k >= r && (k - r) < 256) ? (ACT_ADDR_WIDTH)'(k - r) : '0;
                            end

                            if (next_p < total_cin_passes && k < 256) begin
                                for (int b = 0; b < 4; b++) begin
                                    int b_nxt  = next_bank_base + b;
                                    int ch_nxt = next_p * 4 + b;
                                    ext_act_sram_we[b_nxt]    = 1'b1;
                                    ext_act_sram_addr[b_nxt]  = (ACT_ADDR_WIDTH)'(k);
                                    ext_act_sram_wdata[b_nxt] = (src_sel == 1) ? fmap_buf_A[ty * 16 + (k / 16)][tx * 16 + (k % 16)][ch_nxt] :
                                                                                 fmap_buf_B[ty * 16 + (k / 16)][tx * 16 + (k % 16)][ch_nxt];
                                end
                            end else begin
                                for (int b = 0; b < 4; b++) ext_act_sram_we[next_bank_base + b] = 1'b0;
                            end

                            if (next_p < total_cin_passes && k >= 32 && k < 40) begin
                                weight_shift_en = {WEIGHT_SPLIT{1'b1}};
                                for (int r = 0; r < 8; r++) weight_shift_in[r] = next_w_slice[r][7 - (k - 32)];
                                swap_weights    = 1'b0;
                            end else if (next_p < total_cin_passes && k == pass_len - 1) begin
                                weight_shift_en = '0;
                                swap_weights    = 1'b1;
                            end else begin
                                weight_shift_en = '0;
                                swap_weights    = 1'b0;
                            end

                            if (!swap_val) begin
                                psum_A_addr = hold_bias ? '0 : ((k < 256) ? (PSUM_ADDR_WIDTH)'(k) : '0);
                                psum_B_addr = (k >= 9 && (k - 9) < 256) ? (PSUM_ADDR_WIDTH)'(k - 9) : '0;
                                psum_A_we   = '0;
                                for (int c = 0; c < 8; c++) begin
                                    psum_B_we[c] = (k >= (9 + c) && (k - (9 + c)) < 256);
                                end
                            end else begin
                                psum_B_addr = hold_bias ? '0 : ((k < 256) ? (PSUM_ADDR_WIDTH)'(k) : '0);
                                psum_A_addr = (k >= 9 && (k - 9) < 256) ? (PSUM_ADDR_WIDTH)'(k - 9) : '0;
                                psum_B_we   = '0;
                                for (int c = 0; c < 8; c++) begin
                                    psum_A_we[c] = (k >= (9 + c) && (k - (9 + c)) < 256);
                                end
                            end
                        end
                    end
                    @(negedge clk_i); array_en = 0; psum_systolic_en = 0; psum_skew_en = 0; psum_A_we = '0; psum_B_we = '0; ext_act_sram_we = '0; swap_weights = '0;

                    // Drain Output
                    for (int m = 0; m < 256 + 3; m++) begin
                        @(negedge clk_i); if (m < 256) psum_A_addr = (PSUM_ADDR_WIDTH)'(m);
                        @(posedge clk_i); #1;
                        if (m >= 2 && m < 258) begin
                            int py = ty * 16 + ((m - 2) / 16);
                            int px = tx * 16 + ((m - 2) % 16);
                            for (int c = 0; c < 8; c++) begin
                                int ch = cout_b * 8 + c;
                                if (ch < Cout_val) begin
                                    logic signed [7:0] zp_val = $signed(cfg_flat[ch][29:22]);
                                    logic signed [7:0] v = (out_act[c] < zp_val) ? zp_val : out_act[c];
                                    if (dst_sel == 1) fmap_buf_A[py][px][ch] = v;
                                    else              fmap_buf_B[py][px][ch] = v;
                                end
                            end
                        end
                    end

                    done_blks++;
                    if ((done_blks % 4) == 0 || done_blks == total_blks) begin
                        $display("  [%-16s] %s %3d%% (Block %2d/%2d) | Cycle: %8d",
                                 layer_label, get_progress_bar(done_blks, total_blks),
                                 (done_blks * 100) / total_blks, done_blks, total_blks, global_cycle);
                    end
                end
            end
        end
    endtask

    // =========================================================================
    // Main Orchestrator
    // =========================================================================
    initial begin
        longint net_start, l_start;
        logic signed [7:0] in_zp, zp_l1, zp_l2, zp_l3, zp_l4;
        string mem_dir;
        int fd;

        $display("=====================================================================================");
        $display("   NPU 5-LAYER WHOLE-NETWORK REGRESSION (64x64 -> Stride-2 -> 32x32 -> SiLU)         ");
        $display("=====================================================================================");

        // Resolve memory file path using standardized 2-step resolver
        resolve_mem_dir("wholenet_in.mem", mem_dir);
        $display("[INFO] Resolved memory directory: '%s'", mem_dir);

        check_file_exists({mem_dir, "wholenet_in.mem"});
        check_file_exists({mem_dir, "wholenet_l1_w.mem"});    check_file_exists({mem_dir, "wholenet_l1_b.mem"});   check_file_exists({mem_dir, "wholenet_l1_cfg.mem"}); check_file_exists({mem_dir, "wholenet_l1_gold.mem"});
        check_file_exists({mem_dir, "wholenet_l2_w.mem"});    check_file_exists({mem_dir, "wholenet_l2_b.mem"});   check_file_exists({mem_dir, "wholenet_l2_cfg.mem"}); check_file_exists({mem_dir, "wholenet_l2_gold.mem"});
        check_file_exists({mem_dir, "wholenet_l3_w.mem"});    check_file_exists({mem_dir, "wholenet_l3_b.mem"});   check_file_exists({mem_dir, "wholenet_l3_cfg.mem"}); check_file_exists({mem_dir, "wholenet_l3_gold.mem"});
        check_file_exists({mem_dir, "wholenet_l4_w.mem"});    check_file_exists({mem_dir, "wholenet_l4_b.mem"});   check_file_exists({mem_dir, "wholenet_l4_cfg.mem"}); check_file_exists({mem_dir, "wholenet_l4_gold.mem"});
        check_file_exists({mem_dir, "wholenet_l5_w.mem"});    check_file_exists({mem_dir, "wholenet_l5_b.mem"});   check_file_exists({mem_dir, "wholenet_l5_cfg.mem"}); check_file_exists({mem_dir, "wholenet_l5_gold.mem"});
        check_file_exists({mem_dir, "wholenet_l5_lut.mem"});

        $readmemh({mem_dir, "wholenet_in.mem"},      fmap_in);
        $readmemh({mem_dir, "wholenet_l1_w.mem"},    w1_flat);  $readmemh({mem_dir, "wholenet_l1_b.mem"},  b1_flat);  $readmemh({mem_dir, "wholenet_l1_cfg.mem"},  cfg1); $readmemh({mem_dir, "wholenet_l1_gold.mem"}, gold_l1);
        $readmemh({mem_dir, "wholenet_l2_w.mem"},    w2_flat);  $readmemh({mem_dir, "wholenet_l2_b.mem"},  b2_flat);  $readmemh({mem_dir, "wholenet_l2_cfg.mem"},  cfg2); $readmemh({mem_dir, "wholenet_l2_gold.mem"}, gold_l2);
        $readmemh({mem_dir, "wholenet_l3_w.mem"},    w3_flat);  $readmemh({mem_dir, "wholenet_l3_b.mem"},  b3_flat);  $readmemh({mem_dir, "wholenet_l3_cfg.mem"},  cfg3); $readmemh({mem_dir, "wholenet_l3_gold.mem"}, gold_l3);
        $readmemh({mem_dir, "wholenet_l4_w.mem"},    w4_flat);  $readmemh({mem_dir, "wholenet_l4_b.mem"},  b4_flat);  $readmemh({mem_dir, "wholenet_l4_cfg.mem"},  cfg4); $readmemh({mem_dir, "wholenet_l4_gold.mem"}, gold_l4);
        $readmemh({mem_dir, "wholenet_l5_w.mem"},    w5_flat);  $readmemh({mem_dir, "wholenet_l5_b.mem"},  b5_flat);  $readmemh({mem_dir, "wholenet_l5_cfg.mem"},  cfg5); $readmemh({mem_dir, "wholenet_l5_gold.mem"}, gold_l5);
        $readmemh({mem_dir, "wholenet_l5_lut.mem"},  lut_silu);

        begin
            int nz_in = 0, nz_l1_w = 0, nz_l2_w = 0, nz_l3_w = 0, nz_l4_w = 0, nz_l5_w = 0, nz_silu = 0;
            for (int i = 0; i < $size(fmap_in); i++) if (fmap_in[i] !== 8'sd0) nz_in++;
            for (int i = 0; i < $size(w1_flat); i++) if (w1_flat[i] !== 8'sd0) nz_l1_w++;
            for (int i = 0; i < $size(w2_flat); i++) if (w2_flat[i] !== 8'sd0) nz_l2_w++;
            for (int i = 0; i < $size(w3_flat); i++) if (w3_flat[i] !== 8'sd0) nz_l3_w++;
            for (int i = 0; i < $size(w4_flat); i++) if (w4_flat[i] !== 8'sd0) nz_l4_w++;
            for (int i = 0; i < $size(w5_flat); i++) if (w5_flat[i] !== 8'sd0) nz_l5_w++;
            for (int i = 0; i < $size(lut_silu); i++) if (lut_silu[i] !== 8'sd0) nz_silu++;

            $display("[INFO] Loaded test vectors: fmap_in=%0d nz, L1_W=%0d nz, L2_W=%0d nz, L3_W=%0d nz, L4_W=%0d nz, L5_W=%0d nz, SiLU=%0d nz",
                     nz_in, nz_l1_w, nz_l2_w, nz_l3_w, nz_l4_w, nz_l5_w, nz_silu);

            assert_vector_nonzero("fmap_in", nz_in, 10);
            assert_vector_nonzero("w1_flat", nz_l1_w, 10);
            assert_vector_nonzero("w2_flat", nz_l2_w, 10);
            assert_vector_nonzero("w3_flat", nz_l3_w, 10);
            assert_vector_nonzero("w4_flat", nz_l4_w, 10);
            assert_vector_nonzero("w5_flat", nz_l5_w, 10);
            assert_vector_nonzero("lut_silu", nz_silu, 10);
        end

        zp_l1 = $signed(cfg1[0][29:22]);
        zp_l2 = $signed(cfg2[0][29:22]);
        zp_l3 = $signed(cfg3[0][29:22]);
        zp_l4 = $signed(cfg4[0][29:22]);
        in_zp = 8'sd0;

        clk_i = 0; rst_n = 0; array_en = 0; psum_systolic_en = 0; psum_lut_en = 0; crossbar_sel = '0;
        weight_shift_in = '0; weight_shift_en = '0; swap_weights = 0; quant_shift_in = '0; quant_shift_en = 0;
        stochastic_round_en = 0; psum_skew_en = 0; compute_bank_swap = 0;
        psum_A_addr = '0; psum_A_we = '0; psum_A_wdata = '0; psum_A_read_bank_sel = '0;
        psum_B_addr = '0; psum_B_we = '0; psum_B_wdata = '0; psum_B_read_bank_sel = '0;
        ext_act_sram_we = '0; ext_act_sram_addr = '0; ext_act_sram_wdata = '0;

        #200; rst_n = 1; #100;
        net_start = global_cycle;

        // Layer 1: 3x3 Conv (16 -> 24), In -> Buffer A (64x64)
        $display("\n>>> Launching Layer 1: 3x3 Conv (16 -> 24, 64x64, ReLU)");
        l_start = global_cycle;
        profs[0].macs = longint'(H_IN) * longint'(W_IN) * longint'(C0) * longint'(C1) * 9;
        execute_conv3x3("Layer 1 (3x3)", 0, 1, H_IN, W_IN, C0, C1, w1_flat, b1_flat, cfg1, in_zp, 1'b0);
        profs[0].total_cycles = global_cycle - l_start;
        evaluate_layer(0, "Layer 1 (3x3 ReLU)", H_IN, W_IN, C1, 1, gold_l1);

        // Layer 2: 1x1 Conv (24 -> 24), Buffer A -> Buffer B (64x64)
        $display("\n>>> Launching Layer 2: 1x1 Conv (24 -> 24, 64x64, ReLU) [Half-Array Double-Buffered]");
        l_start = global_cycle;
        profs[1].macs = longint'(H_IN) * longint'(W_IN) * longint'(C1) * longint'(C2);
        execute_conv1x1("Layer 2 (1x1)", 1, 2, H_IN, W_IN, C1, C2, w2_flat, b2_flat, cfg2);
        profs[1].total_cycles = global_cycle - l_start;
        evaluate_layer(1, "Layer 2 (1x1 ReLU)", H_IN, W_IN, C2, 2, gold_l2);

        // Layer 3: 3x3 STRIDE-2 Conv (24 -> 24), Buffer B (64x64) -> Buffer A (32x32)
        $display("\n>>> Launching Layer 3: 3x3 Conv (24 -> 24, STRIDE 2: 64x64 -> 32x32, ReLU)");
        l_start = global_cycle;
        profs[2].macs = longint'(H_OUT) * longint'(W_OUT) * longint'(C2) * longint'(C3) * 9;
        execute_conv3x3_stride2("Layer 3 (3x3 S2)", 2, 1, C2, C3, w3_flat, b3_flat, cfg3, zp_l2);
        profs[2].total_cycles = global_cycle - l_start;
        evaluate_layer(2, "Layer 3 (3x3 S2)", H_OUT, W_OUT, C3, 1, gold_l3);

        // Layer 4: 1x1 Conv (24 -> 16), Buffer A -> Buffer B (32x32)
        $display("\n>>> Launching Layer 4: 1x1 Conv (24 -> 16, 32x32, ReLU) [Half-Array Double-Buffered]");
        l_start = global_cycle;
        profs[3].macs = longint'(H_OUT) * longint'(W_OUT) * longint'(C3) * longint'(C4);
        execute_conv1x1("Layer 4 (1x1)", 1, 2, H_OUT, W_OUT, C3, C4, w4_flat, b4_flat, cfg4);
        profs[3].total_cycles = global_cycle - l_start;
        evaluate_layer(3, "Layer 4 (1x1 ReLU)", H_OUT, W_OUT, C4, 2, gold_l4);

        // Layer 5: 3x3 Conv (16 -> 16), Buffer B -> Buffer A (32x32), SiLU via Bank B LUT
        $display("\n>>> Launching Layer 5: 3x3 Conv (16 -> 16, 32x32, SiLU LUT)");
        l_start = global_cycle;
        profs[4].macs = longint'(H_OUT) * longint'(W_OUT) * longint'(C4) * longint'(C5) * 9;
        execute_conv3x3("Layer 5 (3x3)", 2, 1, H_OUT, W_OUT, C4, C5, w5_flat, b5_flat, cfg5, zp_l4, 1'b1);
        profs[4].total_cycles = global_cycle - l_start;
        evaluate_layer(4, "Layer 5 (3x3 SiLU)", H_OUT, W_OUT, C5, 1, gold_l5);

        // Summary Reports
        $display("\n=======================================================================================================================");
        $display("   WHOLE-NETWORK ERROR DRIFT PROPAGATION REPORT                                                                       ");
        $display("=======================================================================================================================");
        $display("   Layer Name         | Elements | Exact Match | +/-1 LSB Envelope | +/-5 LSB Safe Gate | Max Drift | Gate Status");
        $display("  --------------------+----------+-------------+-------------------+--------------------+-----------+------------------");
        for (int i = 0; i < 5; i++) begin
            int el = (i == 0 || i == 1) ? (H_IN * W_IN * 24) : 
                     (i == 2)           ? (H_OUT * W_OUT * 24) : (H_OUT * W_OUT * 16);
            $display("   %-18s | %8d | %5.2f%%     | %5.2f%%           | %5.2f%%            | %4d LSB   | %s",
                     profs[i].name, el,
                     (real'(profs[i].exact_cnt) / el) * 100.0,
                     (real'(profs[i].tol1_cnt)  / el) * 100.0,
                     (real'(profs[i].tol5_cnt)  / el) * 100.0,
                     profs[i].max_drift,
                     (profs[i].outlier_cnt == 0) ? "PASS [100%]" : "FAIL [OUTLIER]");
        end
        $display("=======================================================================================================================\n");

        $display("=======================================================================================================================");
        $display("   WHOLE-NETWORK HARDWARE EFFICIENCY & THROUGHPUT REPORT                                                              ");
        $display("=======================================================================================================================");
        $display("   Layer Execution    | Total MACs   | Ideal Cycles | Actual Cycles | E2E System Efficiency | Fraction of Net");
        $display("  --------------------+--------------+--------------+---------------+-----------------------+----------------");
        for (int i = 0; i < 5; i++) begin
            real eff = ((real'(profs[i].macs) / 64.0) / real'(profs[i].total_cycles)) * 100.0;
            real pct = (real'(profs[i].total_cycles) / real'(global_cycle - net_start)) * 100.0;
            $display("   %-18s | %10d   | %10d   | %11d   | %5.2f%% of peak       | %5.1f%%",
                     profs[i].name, profs[i].macs, profs[i].macs / 64, profs[i].total_cycles, eff, pct);
        end
        $display("  --------------------+--------------+--------------+---------------+-----------------------+----------------");
        begin
            longint total_net_macs = profs[0].macs + profs[1].macs + profs[2].macs + profs[3].macs + profs[4].macs;
            longint total_net_cyc  = global_cycle - net_start;
            real total_eff = ((real'(total_net_macs) / 64.0) / real'(total_net_cyc)) * 100.0;
            $display("   TOTAL WHOLE-NET    : %10d   | %10d   | %11d   | %5.2f%% of peak       | 100.0%%",
                     total_net_macs, total_net_macs / 64, total_net_cyc, total_eff);
        end
        $display("=======================================================================================================================\n");

        #200; $finish;
    end
endmodule