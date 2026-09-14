module tb_npu_im2col_benchmark;
	reg _sv2v_0;
	parameter signed [31:0] ARRAY_HEIGHT = 8;
	parameter signed [31:0] ARRAY_WIDTH = 8;
	parameter signed [31:0] TILE_SIZE = 16;
	parameter signed [31:0] ACT_HALO_PAD = 2;
	parameter signed [31:0] ACTIVATION_WIDTH = 8;
	parameter signed [31:0] WEIGHT_WIDTH = 8;
	parameter signed [31:0] PSUM_WIDTH = 32;
	parameter signed [31:0] SCALE_WIDTH = 16;
	parameter [0:0] ENABLE_LFSR = 0;
	parameter signed [31:0] WEIGHT_SPLIT = 2;
	localparam signed [31:0] PSUM_WORDS = TILE_SIZE * TILE_SIZE;
	localparam signed [31:0] ACT_WORDS = (TILE_SIZE * TILE_SIZE) * ACT_HALO_PAD;
	localparam signed [31:0] PSUM_ADDR_WIDTH = $clog2(PSUM_WORDS);
	localparam signed [31:0] ACT_ADDR_WIDTH = $clog2(ACT_WORDS);
	localparam signed [31:0] NUM_ACT_BANKS = ARRAY_HEIGHT;
	localparam signed [31:0] NUM_PSUM_BANKS = ARRAY_WIDTH * 2;
	localparam signed [31:0] XBAR_SEL_WIDTH = $clog2(ARRAY_HEIGHT) + 1;
	localparam signed [31:0] BANK_SEL_WIDTH = $clog2(ARRAY_WIDTH);
	localparam signed [31:0] PROD_WIDTH = PSUM_WIDTH + SCALE_WIDTH;
	localparam signed [31:0] SHIFT_WIDTH = $clog2(PROD_WIDTH);
	localparam signed [31:0] QUANT_CFG_WIDTH = (SCALE_WIDTH + SHIFT_WIDTH) + ACTIVATION_WIDTH;
	localparam signed [31:0] CONV_H = 48;
	localparam signed [31:0] CONV_W = 48;
	localparam signed [31:0] Cin = 128;
	localparam signed [31:0] Cout = 32;
	reg clk_i;
	reg rst_n;
	reg array_en;
	reg psum_systolic_en;
	reg psum_lut_en;
	reg [(ARRAY_HEIGHT * XBAR_SEL_WIDTH) - 1:0] crossbar_sel;
	reg signed [(ARRAY_HEIGHT * WEIGHT_WIDTH) - 1:0] weight_shift_in;
	reg [WEIGHT_SPLIT - 1:0] weight_shift_en;
	reg swap_weights;
	reg [QUANT_CFG_WIDTH - 1:0] quant_shift_in;
	reg quant_shift_en;
	reg stochastic_round_en;
	wire [SCALE_WIDTH - 1:0] lfsr_data_out;
	reg psum_skew_en;
	reg compute_bank_swap;
	reg [PSUM_ADDR_WIDTH - 1:0] psum_A_addr;
	reg [PSUM_ADDR_WIDTH - 1:0] psum_B_addr;
	reg [ARRAY_WIDTH - 1:0] psum_A_we;
	reg [ARRAY_WIDTH - 1:0] psum_B_we;
	reg signed [PSUM_WIDTH - 1:0] psum_A_wdata;
	reg signed [PSUM_WIDTH - 1:0] psum_B_wdata;
	reg [BANK_SEL_WIDTH - 1:0] psum_A_read_bank_sel;
	reg [BANK_SEL_WIDTH - 1:0] psum_B_read_bank_sel;
	wire signed [PSUM_WIDTH - 1:0] psum_A_rdata;
	wire signed [PSUM_WIDTH - 1:0] psum_B_rdata;
	reg [NUM_ACT_BANKS - 1:0] ext_act_sram_we;
	reg [(NUM_ACT_BANKS * ACT_ADDR_WIDTH) - 1:0] ext_act_sram_addr;
	reg signed [(NUM_ACT_BANKS * ACTIVATION_WIDTH) - 1:0] ext_act_sram_wdata;
	wire signed [(NUM_ACT_BANKS * ACTIVATION_WIDTH) - 1:0] act_sram_rdata;
	wire signed [(ARRAY_WIDTH * ACTIVATION_WIDTH) - 1:0] out_act;
	reg signed [ACTIVATION_WIDTH - 1:0] fmap_in [0:((CONV_H * CONV_W) * Cin) - 1];
	reg signed [ACTIVATION_WIDTH - 1:0] gold_l1 [0:((CONV_H * CONV_W) * Cout) - 1];
	reg signed [WEIGHT_WIDTH - 1:0] w1_flat [0:36863];
	reg signed [31:0] b1_flat [0:31];
	reg [31:0] p1_cfg [0:31];
	reg signed [ACTIVATION_WIDTH - 1:0] actual_quant_l1 [0:47][0:47][0:31];
	reg signed [31:0] actual_psum_l1 [0:47][0:47][0:31];
	reg signed [31:0] golden_psum_l1 [0:47][0:47][0:31];
	reg signed [63:0] global_cycle = 0;
	reg signed [63:0] compute_active_cycles = 0;
	reg signed [63:0] init_preload_cycles = 0;
	reg signed [63:0] drain_quant_cycles = 0;
	reg signed [63:0] e2e_start_cycle = 0;
	reg signed [63:0] e2e_total_cycles = 0;
	reg signed [63:0] raw_drain_cycles = 0;
	reg signed [63:0] raw_drain_start = 0;
	always #(5) begin
		clk_i = ~clk_i;
		if (clk_i) begin
			global_cycle = global_cycle + 1;
			if (array_en)
				compute_active_cycles = compute_active_cycles + 1;
		end
	end
	npu_wrapper #(
		.ARRAY_HEIGHT(ARRAY_HEIGHT),
		.ARRAY_WIDTH(ARRAY_WIDTH),
		.TILE_SIZE(TILE_SIZE),
		.ACT_HALO_PAD(ACT_HALO_PAD),
		.ACTIVATION_WIDTH(ACTIVATION_WIDTH),
		.WEIGHT_WIDTH(WEIGHT_WIDTH),
		.PSUM_WIDTH(PSUM_WIDTH),
		.SCALE_WIDTH(SCALE_WIDTH),
		.ENABLE_LFSR(ENABLE_LFSR),
		.WEIGHT_SPLIT(WEIGHT_SPLIT)
	) dut(
		.clk_i(clk_i),
		.rst_n(rst_n),
		.array_en(array_en),
		.psum_systolic_en(psum_systolic_en),
		.psum_lut_en(psum_lut_en),
		.crossbar_sel(crossbar_sel),
		.weight_shift_in(weight_shift_in),
		.weight_shift_en(weight_shift_en),
		.swap_weights(swap_weights),
		.quant_shift_in(quant_shift_in),
		.quant_shift_en(quant_shift_en),
		.stochastic_round_en(stochastic_round_en),
		.lfsr_data_out(lfsr_data_out),
		.psum_skew_en(psum_skew_en),
		.compute_bank_swap(compute_bank_swap),
		.psum_A_addr(psum_A_addr),
		.psum_A_we(psum_A_we),
		.psum_A_wdata(psum_A_wdata),
		.psum_A_read_bank_sel(psum_A_read_bank_sel),
		.psum_A_rdata(psum_A_rdata),
		.psum_B_addr(psum_B_addr),
		.psum_B_we(psum_B_we),
		.psum_B_wdata(psum_B_wdata),
		.psum_B_read_bank_sel(psum_B_read_bank_sel),
		.psum_B_rdata(psum_B_rdata),
		.ext_act_sram_we(ext_act_sram_we),
		.ext_act_sram_addr(ext_act_sram_addr),
		.ext_act_sram_wdata(ext_act_sram_wdata),
		.act_sram_rdata(act_sram_rdata),
		.out_act(out_act)
	);
	reg signed [31:0] row_target_bank [0:7];
	reg row_access_en [0:7];
	reg signed [31:0] total_bank_conflicts = 0;
	reg signed [31:0] total_rw_conflicts = 0;
	reg signed [31:0] printed_rw_conflicts = 0;
	localparam signed [31:0] MAX_WARNINGS = 16;
	always @(posedge clk_i)
		if (rst_n && array_en) begin : sv2v_autoblock_1
			reg signed [31:0] b;
			for (b = 0; b < 8; b = b + 1)
				if (ext_act_sram_we[b] != 1'b0) begin : sv2v_autoblock_2
					reg signed [31:0] r;
					for (r = 0; r < 8; r = r + 1)
						if (row_access_en[r] && (row_target_bank[r] == b)) begin
							if (printed_rw_conflicts < MAX_WARNINGS) begin
								$display("[HAZARD R/W CONFLICT] Cycle %0d: Bank %0d Simultaneous Write & Read by Row %0d!", global_cycle, b, r);
								printed_rw_conflicts = printed_rw_conflicts + 1;
							end
							total_rw_conflicts = total_rw_conflicts + 1;
						end
				end
		end
	task automatic check_file_exists;
		input string filename;
		reg signed [31:0] fd;
		begin
			fd = $fopen(filename, "r");
			if (fd == 0) begin
				$display("\n=====================================================================================");
				$display(" [FATAL ERROR] Required memory file '%s' was NOT found!", filename);
				$display(" Run 'python3 gen_npu_im2col_benchmark.py' and ensure output files are in xsim path.");
				$display("=====================================================================================\n");
				$display("Fatal [%0t] /mnt/c/Users/Niels/Documents/nct/MyProjects/CrocoScale_SoC/TEST/NPU/TestBenches/tb_npu_im2col_benchmark.sv:185:13 - tb_npu_im2col_benchmark.check_file_exists.<unnamed_block>\n msg: ", $time, "Aborting simulation due to missing test vector files.");
				$finish(1);
			end
			$fclose(fd);
		end
	endtask
	task automatic get_sram_loc;
		input reg signed [31:0] cin_idx;
		input reg signed [31:0] ly;
		input reg signed [31:0] lx;
		output reg signed [31:0] bank;
		output reg signed [31:0] addr;
		reg signed [31:0] h;
		reg signed [31:0] x_off;
		begin
			h = (lx >= 9 ? 1 : 0);
			x_off = (lx >= 9 ? lx - 9 : lx);
			bank = ((ly % 3) * 2) + h;
			addr = (((cin_idx % 8) * 64) + ((ly / 3) * 9)) + x_off;
		end
	endtask
	function automatic signed [7:0] get_fmap_val;
		input reg signed [31:0] c_idx;
		input reg signed [31:0] b_idx;
		input reg signed [31:0] i_idx;
		input reg signed [31:0] ty_idx;
		input reg signed [31:0] tx_idx;
		reg signed [31:0] ly_val;
		reg signed [31:0] lx_val;
		reg signed [31:0] gy_val;
		reg signed [31:0] gx_val;
		begin
			ly_val = (b_idx / 2) + ((i_idx / 9) * 3);
			lx_val = ((b_idx % 2) == 1 ? 9 : 0) + (i_idx % 9);
			gy_val = ((ty_idx * 16) + ly_val) - 1;
			gx_val = ((tx_idx * 16) + lx_val) - 1;
			if (((((gy_val >= 0) && (gy_val < CONV_H)) && (gx_val >= 0)) && (gx_val < CONV_W)) && (c_idx < Cin))
				get_fmap_val = fmap_in[(((gy_val * CONV_W) * Cin) + (gx_val * Cin)) + c_idx];
			else
				get_fmap_val = 8'sd0;
		end
	endfunction
	task automatic prepare_weights;
		input reg signed [31:0] p;
		input reg signed [31:0] cout_b;
		output reg signed [511:0] w_mat;
		reg signed [31:0] r;
		reg signed [31:0] c;
		reg signed [31:0] g_idx;
		reg signed [31:0] cin_curr;
		reg signed [31:0] tap_curr;
		reg signed [31:0] ky_curr;
		reg signed [31:0] kx_curr;
		reg signed [31:0] ch_out;
		for (r = 0; r < 8; r = r + 1)
			begin
				g_idx = (p * 8) + r;
				if (g_idx < 1152) begin
					cin_curr = g_idx / 9;
					tap_curr = g_idx % 9;
					ky_curr = tap_curr / 3;
					kx_curr = tap_curr % 3;
					for (c = 0; c < 8; c = c + 1)
						begin
							ch_out = (cout_b * 8) + c;
							if (ch_out < Cout)
								w_mat[(((7 - r) * 8) + (7 - c)) * 8+:8] = w1_flat[(((((ky_curr * 3) * Cin) * Cout) + ((kx_curr * Cin) * Cout)) + (cin_curr * Cout)) + ch_out];
							else
								w_mat[(((7 - r) * 8) + (7 - c)) * 8+:8] = 8'sd0;
						end
				end
				else
					for (c = 0; c < 8; c = c + 1)
						w_mat[(((7 - r) * 8) + (7 - c)) * 8+:8] = 8'sd0;
			end
	endtask
	function automatic signed [31:0] sv2v_cast_32_signed;
		input reg signed [31:0] inp;
		sv2v_cast_32_signed = inp;
	endfunction
	task automatic compute_golden_psum_l1;
		reg signed [31:0] y;
		reg signed [31:0] x;
		reg signed [31:0] cout_idx;
		reg signed [31:0] cin_idx;
		reg signed [31:0] ky;
		reg signed [31:0] kx;
		reg signed [31:0] in_y;
		reg signed [31:0] in_x;
		reg signed [31:0] psum_val;
		reg signed [7:0] in_pix;
		reg signed [7:0] w_val;
		for (y = 0; y < CONV_H; y = y + 1)
			for (x = 0; x < CONV_W; x = x + 1)
				for (cout_idx = 0; cout_idx < Cout; cout_idx = cout_idx + 1)
					begin
						psum_val = b1_flat[cout_idx];
						for (cin_idx = 0; cin_idx < Cin; cin_idx = cin_idx + 1)
							for (ky = 0; ky < 3; ky = ky + 1)
								for (kx = 0; kx < 3; kx = kx + 1)
									begin
										in_y = (y + ky) - 1;
										in_x = (x + kx) - 1;
										if ((((in_y >= 0) && (in_y < CONV_H)) && (in_x >= 0)) && (in_x < CONV_W))
											in_pix = fmap_in[(((in_y * CONV_W) * Cin) + (in_x * Cin)) + cin_idx];
										else
											in_pix = 8'sd0;
										w_val = w1_flat[(((((ky * 3) * Cin) * Cout) + ((kx * Cin) * Cout)) + (cin_idx * Cout)) + cout_idx];
										psum_val = psum_val + (sv2v_cast_32_signed(in_pix) * sv2v_cast_32_signed(w_val));
									end
						golden_psum_l1[y][x][cout_idx] = psum_val;
					end
	endtask
	task automatic inspect_full_layer_diagnostics;
		reg signed [31:0] total_elements;
		reg signed [31:0] psum_exact;
		reg signed [31:0] psum_errs;
		reg signed [31:0] quant_exact;
		reg signed [31:0] quant_exact_errs;
		reg signed [31:0] quant_tol_ok;
		reg signed [31:0] quant_tol_errs;
		reg signed [31:0] print_cnt;
		reg signed [31:0] y;
		reg signed [31:0] x;
		reg signed [31:0] c;
		reg signed [31:0] flat;
		reg signed [31:0] exp_psum;
		reg signed [31:0] act_psum;
		reg signed [31:0] diff_psum;
		reg signed [7:0] exp_quant;
		reg signed [7:0] act_quant;
		reg signed [31:0] diff_quant;
		reg signed [31:0] abs_diff_quant;
		begin
			total_elements = (CONV_H * CONV_W) * Cout;
			psum_exact = 0;
			psum_errs = 0;
			quant_exact = 0;
			quant_exact_errs = 0;
			quant_tol_ok = 0;
			quant_tol_errs = 0;
			print_cnt = 0;
			for (y = 0; y < CONV_H; y = y + 1)
				for (x = 0; x < CONV_W; x = x + 1)
					for (c = 0; c < Cout; c = c + 1)
						begin
							flat = (((y * CONV_W) * Cout) + (x * Cout)) + c;
							exp_psum = golden_psum_l1[y][x][c];
							act_psum = actual_psum_l1[y][x][c];
							diff_psum = act_psum - exp_psum;
							exp_quant = gold_l1[flat];
							act_quant = actual_quant_l1[y][x][c];
							diff_quant = sv2v_cast_32_signed(act_quant) - sv2v_cast_32_signed(exp_quant);
							abs_diff_quant = (diff_quant < 0 ? -diff_quant : diff_quant);
							if (act_psum === exp_psum)
								psum_exact = psum_exact + 1;
							else
								psum_errs = psum_errs + 1;
							if (act_quant === exp_quant)
								quant_exact = quant_exact + 1;
							else
								quant_exact_errs = quant_exact_errs + 1;
							if (abs_diff_quant <= 1)
								quant_tol_ok = quant_tol_ok + 1;
							else
								quant_tol_errs = quant_tol_errs + 1;
						end
			if ((psum_errs > 0) || (quant_tol_errs > 0)) begin
				$display("\n=========================================================================================================");
				$display(" >>> [BENCHMARK LAYER DIAGNOSTIC: HARD MISMATCH DUMP (|Delta Q| > 1 or PSUM Err)] <<<");
				$display("=========================================================================================================");
				$display("   Coord (Y, X, Ch)  | Exp PSUM (INT32) | Act PSUM (INT32) | Delta PSUM | Exp Q(INT8) | Act Q(INT8) | Status");
				$display("  -------------------+------------------+------------------+------------+-------------+-------------+--------------------");
				for (y = 0; y < CONV_H; y = y + 1)
					for (x = 0; x < CONV_W; x = x + 1)
						for (c = 0; c < Cout; c = c + 1)
							begin
								flat = (((y * CONV_W) * Cout) + (x * Cout)) + c;
								exp_psum = golden_psum_l1[y][x][c];
								act_psum = actual_psum_l1[y][x][c];
								diff_psum = act_psum - exp_psum;
								exp_quant = gold_l1[flat];
								act_quant = actual_quant_l1[y][x][c];
								diff_quant = sv2v_cast_32_signed(act_quant) - sv2v_cast_32_signed(exp_quant);
								abs_diff_quant = (diff_quant < 0 ? -diff_quant : diff_quant);
								if ((act_psum !== exp_psum) || (abs_diff_quant > 1)) begin
									if (print_cnt < 16) begin
										$display("   [%2d, %2d, Ch%2d]    | %16d | %16d | %10d | %11d | %11d | HARD MISMATCH", y, x, c, exp_psum, act_psum, diff_psum, exp_quant, act_quant);
										print_cnt = print_cnt + 1;
									end
								end
							end
				$display("=========================================================================================================\n");
			end
			$display("\n=====================================================================================");
			$display("   VERIFICATION & BIT-EXACTNESS REPORT                                               ");
			$display("=====================================================================================");
			$display("  STAGE 1A: INT8 Output (+/-1 LSB Tol)     : %0d / %0d (%5.2f%%) %s", quant_tol_ok, total_elements, (real'(quant_tol_ok) / total_elements) * 100.0, (quant_tol_errs == 0 ? "[PASS]" : "[FAIL]"));
			$display("  STAGE 1B: INT8 Output (Exact Bit-Match) : %0d / %0d (%5.2f%%) [DEBUG]", quant_exact, total_elements, (real'(quant_exact) / total_elements) * 100.0);
			$display("  STAGE 2 : Raw INT32 PSUM (Exact Match)  : %0d / %0d (%5.2f%%) %s", psum_exact, total_elements, (real'(psum_exact) / total_elements) * 100.0, (psum_errs == 0 ? "[PASS]" : "[FAIL]"));
			$display("-------------------------------------------------------------------------------------");
			if ((psum_errs == 0) && (quant_tol_errs == 0))
				$display("  >>> BENCHMARK PASSED (100%% PSUM EXACT & 100%% INT8 WITHIN +/-1 LSB TOLERANCE) <<<");
			else
				$display("  >>> BENCHMARK VERIFICATION FAILED (Hard Errors Detected) <<<");
			$display("=====================================================================================");
		end
	endtask
	function automatic signed [63:0] sv2v_cast_64_signed;
		input reg signed [63:0] inp;
		sv2v_cast_64_signed = inp;
	endfunction
	task automatic print_performance_report;
		reg signed [63:0] total_macs;
		reg signed [63:0] ideal_compute_cycles;
		real compute_eff;
		real e2e_eff;
		real compute_pct;
		real preload_pct;
		real drain_pct;
		begin
			total_macs = (((sv2v_cast_64_signed(CONV_H) * sv2v_cast_64_signed(CONV_W)) * sv2v_cast_64_signed(Cin)) * sv2v_cast_64_signed(Cout)) * 9;
			ideal_compute_cycles = total_macs / 64;
			compute_eff = (real'(ideal_compute_cycles) / real'(compute_active_cycles)) * 100.0;
			e2e_eff = (real'(ideal_compute_cycles) / real'(e2e_total_cycles)) * 100.0;
			compute_pct = (real'(compute_active_cycles) / real'(e2e_total_cycles)) * 100.0;
			preload_pct = (real'(init_preload_cycles) / real'(e2e_total_cycles)) * 100.0;
			drain_pct = (real'(drain_quant_cycles) / real'(e2e_total_cycles)) * 100.0;
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
		end
	endtask
	function automatic string get_progress_bar;
		input reg signed [31:0] current;
		input reg signed [31:0] total;
		string bar;
		reg signed [31:0] filled;
		begin
			bar = "[";
			filled = (current * 20) / total;
			begin : sv2v_autoblock_3
				reg signed [31:0] i;
				for (i = 0; i < 20; i = i + 1)
					if (i < filled)
						bar = {bar, "="};
					else if (i == filled)
						bar = {bar, ">"};
					else
						bar = {bar, " "};
			end
			bar = {bar, "]"};
			get_progress_bar = bar;
		end
	endfunction
	function automatic signed [ACT_ADDR_WIDTH - 1:0] sv2v_cast_41508_signed;
		input reg signed [ACT_ADDR_WIDTH - 1:0] inp;
		sv2v_cast_41508_signed = inp;
	endfunction
	function automatic signed [3:0] sv2v_cast_4_signed;
		input reg signed [3:0] inp;
		sv2v_cast_4_signed = inp;
	endfunction
	function automatic [ACT_ADDR_WIDTH - 1:0] sv2v_cast_41508;
		input reg [ACT_ADDR_WIDTH - 1:0] inp;
		sv2v_cast_41508 = inp;
	endfunction
	function automatic signed [PSUM_ADDR_WIDTH - 1:0] sv2v_cast_EDE54_signed;
		input reg signed [PSUM_ADDR_WIDTH - 1:0] inp;
		sv2v_cast_EDE54_signed = inp;
	endfunction
	function automatic signed [2:0] sv2v_cast_3_signed;
		input reg signed [2:0] inp;
		sv2v_cast_3_signed = inp;
	endfunction
	initial begin : sv2v_autoblock_4
		reg signed [31:0] num_ty;
		reg signed [31:0] num_tx;
		reg signed [31:0] cout_blks;
		reg signed [31:0] k_total;
		reg signed [31:0] total_passes;
		reg signed [31:0] total_blocks;
		reg signed [31:0] completed_blocks;
		reg signed [31:0] ty;
		reg signed [31:0] tx;
		reg signed [31:0] cout_b;
		reg signed [31:0] p_idx;
		reg signed [31:0] r;
		reg signed [31:0] c;
		reg signed [31:0] b;
		reg signed [31:0] k;
		reg signed [31:0] m;
		reg signed [31:0] m_p;
		reg signed [31:0] pass_len;
		reg signed [31:0] g_idx;
		reg signed [31:0] cin_curr;
		reg signed [31:0] tap_curr;
		reg signed [31:0] ky_curr;
		reg signed [31:0] kx_curr;
		reg signed [31:0] target_ly;
		reg signed [31:0] target_lx;
		reg signed [31:0] target_bank;
		reg signed [31:0] target_addr;
		reg signed [31:0] out_y;
		reg signed [31:0] out_x;
		reg signed [31:0] py;
		reg signed [31:0] px;
		reg signed [31:0] d_idx;
		reg signed [63:0] phase_start;
		reg swap_val;
		reg hold_bias_addr;
		reg init_bank_b;
		reg signed [511:0] w_slice;
		reg signed [511:0] next_w_slice;
		reg signed [31:0] dma_channel_to_load;
		reg signed [31:0] dma_bank_ptr [0:5];
		reg bank_read_used [0:5];
		reg signed [31:0] target_bank_arr [0:7];
		reg signed [31:0] target_addr_arr [0:7];
		reg row_active_arr [0:7];
		reg signed [31:0] dma_schedule [0:143];
		string mem_dir;
		reg signed [31:0] fd;
		num_ty = 3;
		num_tx = 3;
		cout_blks = 4;
		k_total = 1152;
		total_passes = (k_total + 7) / 8;
		total_blocks = (num_ty * num_tx) * cout_blks;
		completed_blocks = 0;
		begin : sv2v_autoblock_5
			reg signed [31:0] p;
			for (p = 0; p < total_passes; p = p + 1)
				dma_schedule[p] = -1;
		end
		begin : sv2v_autoblock_6
			reg signed [31:0] ch_idx;
			for (ch_idx = 1; ch_idx < Cin; ch_idx = ch_idx + 1)
				begin : sv2v_autoblock_7
					reg signed [31:0] p_needed;
					p_needed = (9 * ch_idx) / 8;
					dma_schedule[p_needed - 1] = ch_idx;
				end
		end
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
		if (!$value$plusargs("MEM_DIR=%s", mem_dir)) begin
			fd = $fopen("bench_im2col_act.mem", "r");
			if (fd != 0) begin
				$fclose(fd);
				mem_dir = "./";
			end
			else begin
				fd = $fopen("../GoldenReference/bench_im2col_act.mem", "r");
				if (fd != 0) begin
					$fclose(fd);
					mem_dir = "../GoldenReference/";
				end
				else begin
					fd = $fopen("TEST/NPU/GoldenReference/bench_im2col_act.mem", "r");
					if (fd != 0) begin
						$fclose(fd);
						mem_dir = "TEST/NPU/GoldenReference/";
					end
					else
						mem_dir = "./";
				end
			end
		end
		if (((mem_dir.len() > 0) && (mem_dir[mem_dir.len() - 1] != "/")) && (mem_dir[mem_dir.len() - 1] != "\\"))
			mem_dir = {mem_dir, "/"};
		check_file_exists({mem_dir, "bench_im2col_act.mem"});
		check_file_exists({mem_dir, "bench_im2col_w.mem"});
		check_file_exists({mem_dir, "bench_im2col_b.mem"});
		check_file_exists({mem_dir, "bench_im2col_cfg.mem"});
		check_file_exists({mem_dir, "bench_im2col_out_quant.mem"});
		$readmemh({mem_dir, "bench_im2col_act.mem"}, fmap_in);
		$readmemh({mem_dir, "bench_im2col_w.mem"}, w1_flat);
		$readmemh({mem_dir, "bench_im2col_b.mem"}, b1_flat);
		$readmemh({mem_dir, "bench_im2col_cfg.mem"}, p1_cfg);
		$readmemh({mem_dir, "bench_im2col_out_quant.mem"}, gold_l1);
		compute_golden_psum_l1;
		clk_i = 0;
		rst_n = 0;
		array_en = 0;
		psum_systolic_en = 0;
		psum_lut_en = 0;
		crossbar_sel = 1'sb0;
		weight_shift_in = 1'sb0;
		weight_shift_en = 1'sb0;
		swap_weights = 0;
		quant_shift_in = 1'sb0;
		quant_shift_en = 0;
		stochastic_round_en = 0;
		psum_skew_en = 0;
		compute_bank_swap = 0;
		psum_A_addr = 1'sb0;
		psum_A_we = 1'sb0;
		psum_A_wdata = 1'sb0;
		psum_A_read_bank_sel = 1'sb0;
		psum_B_addr = 1'sb0;
		psum_B_we = 1'sb0;
		psum_B_wdata = 1'sb0;
		psum_B_read_bank_sel = 1'sb0;
		ext_act_sram_we = 1'sb0;
		ext_act_sram_addr = 1'sb0;
		ext_act_sram_wdata = 1'sb0;
		#(200)
			;
		rst_n = 1;
		#(100)
			;
		e2e_start_cycle = global_cycle;
		for (ty = 0; ty < num_ty; ty = ty + 1)
			for (tx = 0; tx < num_tx; tx = tx + 1)
				for (cout_b = 0; cout_b < cout_blks; cout_b = cout_b + 1)
					begin
						init_bank_b = (total_passes % 2) == 1;
						phase_start = global_cycle;
						prepare_weights(0, cout_b, w_slice);
						@(negedge clk_i)
							;
						psum_systolic_en = 0;
						psum_lut_en = 0;
						psum_skew_en = 0;
						begin : sv2v_autoblock_8
							reg signed [31:0] step;
							for (step = 0; step < 54; step = step + 1)
								begin
									for (b = 0; b < 6; b = b + 1)
										begin
											ext_act_sram_we[b] = 1'b1;
											ext_act_sram_addr[b * ACT_ADDR_WIDTH+:ACT_ADDR_WIDTH] = sv2v_cast_41508_signed(step);
											ext_act_sram_wdata[b * ACTIVATION_WIDTH+:ACTIVATION_WIDTH] = get_fmap_val(0, b, step, ty, tx);
										end
									ext_act_sram_we[6] = 1'b0;
									ext_act_sram_we[7] = 1'b0;
									if (step < 8) begin : sv2v_autoblock_9
										reg signed [31:0] ch;
										reg signed [31:0] q_ch;
										reg signed [31:0] b_val;
										ch = (cout_b * 8) + step;
										q_ch = (cout_b * 8) + (7 - step);
										b_val = (ch < Cout ? b1_flat[ch] : 32'sd0);
										if (!init_bank_b) begin
											psum_A_addr = 1'sb0;
											psum_A_wdata = b_val;
											psum_A_we = 8'b00000001 << step;
											psum_B_we = 8'h00;
										end
										else begin
											psum_B_addr = 1'sb0;
											psum_B_wdata = b_val;
											psum_B_we = 8'b00000001 << step;
											psum_A_we = 8'h00;
										end
										quant_shift_en = 1'b1;
										quant_shift_in = (q_ch < Cout ? p1_cfg[q_ch][QUANT_CFG_WIDTH - 1:0] : {QUANT_CFG_WIDTH {1'sb0}});
									end
									else begin
										psum_A_we = 8'h00;
										psum_B_we = 8'h00;
										quant_shift_en = 1'b0;
										quant_shift_in = 1'sb0;
									end
									if (step < 8) begin
										weight_shift_en = {WEIGHT_SPLIT {1'b1}};
										for (r = 0; r < 8; r = r + 1)
											weight_shift_in[r * WEIGHT_WIDTH+:WEIGHT_WIDTH] = w_slice[(((7 - r) * 8) + (0 + step)) * 8+:8];
										swap_weights = 1'b0;
									end
									else if (step == 8) begin
										weight_shift_en = 1'sb0;
										swap_weights = 1'b1;
									end
									else begin
										weight_shift_en = 1'sb0;
										swap_weights = 1'b0;
									end
									@(negedge clk_i)
										;
								end
						end
						ext_act_sram_we = 1'sb0;
						psum_A_we = 1'sb0;
						psum_B_we = 1'sb0;
						quant_shift_en = 1'sb0;
						weight_shift_en = 1'sb0;
						swap_weights = 1'sb0;
						init_preload_cycles = init_preload_cycles + (global_cycle - phase_start);
						for (p_idx = 0; p_idx < total_passes; p_idx = p_idx + 1)
							begin : sv2v_autoblock_10
								reg signed [31:0] next_p;
								next_p = p_idx + 1;
								pass_len = (p_idx == (total_passes - 1) ? (256 + ARRAY_HEIGHT) + ARRAY_WIDTH : 265);
								dma_channel_to_load = dma_schedule[p_idx];
								for (b = 0; b < 6; b = b + 1)
									dma_bank_ptr[b] = 0;
								if (next_p < total_passes)
									prepare_weights(next_p, cout_b, next_w_slice);
								swap_val = ((total_passes % 2) == 0 ? ((p_idx % 2) == 0 ? 1'b0 : 1'b1) : ((p_idx % 2) == 0 ? 1'b1 : 1'b0));
								hold_bias_addr = p_idx == 0;
								for (k = 0; k < pass_len; k = k + 1)
									begin
										@(negedge clk_i)
											;
										if (k == 0) begin
											array_en = 1;
											psum_systolic_en = 1;
											psum_lut_en = 0;
											psum_skew_en = 1;
											compute_bank_swap = swap_val;
										end
										for (b = 0; b < 6; b = b + 1)
											bank_read_used[b] = 1'b0;
										for (r = 0; r < ARRAY_HEIGHT; r = r + 1)
											begin
												g_idx = (p_idx * 8) + r;
												m_p = k - r;
												if (((m_p >= 0) && (m_p < 256)) && (g_idx < k_total)) begin
													cin_curr = g_idx / 9;
													tap_curr = g_idx % 9;
													ky_curr = tap_curr / 3;
													kx_curr = tap_curr % 3;
													out_y = m_p / 16;
													out_x = m_p % 16;
													target_ly = out_y + ky_curr;
													target_lx = out_x + kx_curr;
													get_sram_loc(cin_curr, target_ly, target_lx, target_bank, target_addr);
													target_bank_arr[r] = target_bank;
													target_addr_arr[r] = target_addr;
													row_active_arr[r] = 1'b1;
													row_access_en[r] = 1'b1;
													row_target_bank[r] = target_bank;
													crossbar_sel[r * XBAR_SEL_WIDTH+:XBAR_SEL_WIDTH] = sv2v_cast_4_signed(target_bank);
													if (target_bank < 6)
														bank_read_used[target_bank] = 1'b1;
												end
												else begin
													target_bank_arr[r] = -1;
													target_addr_arr[r] = 1'sb0;
													row_active_arr[r] = 1'b0;
													row_access_en[r] = 1'b0;
													crossbar_sel[r * XBAR_SEL_WIDTH+:XBAR_SEL_WIDTH] = 4'b1000;
												end
											end
										for (b = 0; b < 6; b = b + 1)
											if (bank_read_used[b]) begin
												ext_act_sram_we[b] = 1'b0;
												for (r = 0; r < ARRAY_HEIGHT; r = r + 1)
													if (row_active_arr[r] && (target_bank_arr[r] == b))
														ext_act_sram_addr[b * ACT_ADDR_WIDTH+:ACT_ADDR_WIDTH] = sv2v_cast_41508(target_addr_arr[r]);
											end
											else if ((dma_channel_to_load >= 0) && (dma_bank_ptr[b] < 54)) begin
												ext_act_sram_we[b] = 1'b1;
												ext_act_sram_addr[b * ACT_ADDR_WIDTH+:ACT_ADDR_WIDTH] = sv2v_cast_41508(((dma_channel_to_load % 8) * 64) + dma_bank_ptr[b]);
												ext_act_sram_wdata[b * ACTIVATION_WIDTH+:ACTIVATION_WIDTH] = get_fmap_val(dma_channel_to_load, b, dma_bank_ptr[b], ty, tx);
												dma_bank_ptr[b] = dma_bank_ptr[b] + 1;
											end
											else begin
												ext_act_sram_we[b] = 1'b0;
												ext_act_sram_addr[b * ACT_ADDR_WIDTH+:ACT_ADDR_WIDTH] = 1'sb0;
											end
										ext_act_sram_we[6] = 1'b0;
										ext_act_sram_we[7] = 1'b0;
										if (((next_p < total_passes) && (k >= 32)) && (k < 40)) begin
											weight_shift_en = {WEIGHT_SPLIT {1'b1}};
											for (r = 0; r < 8; r = r + 1)
												weight_shift_in[r * WEIGHT_WIDTH+:WEIGHT_WIDTH] = next_w_slice[(((7 - r) * 8) + (k - 32)) * 8+:8];
											swap_weights = 1'b0;
										end
										else if ((next_p < total_passes) && (k == (pass_len - 1))) begin
											weight_shift_en = 1'sb0;
											swap_weights = 1'b1;
										end
										else begin
											weight_shift_en = 1'sb0;
											swap_weights = 1'b0;
										end
										if (!swap_val) begin
											psum_A_addr = (hold_bias_addr ? {PSUM_ADDR_WIDTH {1'sb0}} : (k < 256 ? sv2v_cast_EDE54_signed(k) : {PSUM_ADDR_WIDTH {1'sb0}}));
											psum_B_addr = ((k >= 9) && ((k - 9) < 256) ? sv2v_cast_EDE54_signed(k - 9) : {PSUM_ADDR_WIDTH {1'sb0}});
											for (c = 0; c < ARRAY_WIDTH; c = c + 1)
												begin
													psum_B_we[c] = ((k >= (9 + c)) && ((k - (9 + c)) < 256) ? 1'b1 : 1'b0);
													psum_A_we[c] = ((p_idx > 0) && (k < c) ? 1'b1 : 1'b0);
												end
										end
										else begin
											psum_B_addr = (hold_bias_addr ? {PSUM_ADDR_WIDTH {1'sb0}} : (k < 256 ? sv2v_cast_EDE54_signed(k) : {PSUM_ADDR_WIDTH {1'sb0}}));
											psum_A_addr = ((k >= 9) && ((k - 9) < 256) ? sv2v_cast_EDE54_signed(k - 9) : {PSUM_ADDR_WIDTH {1'sb0}});
											for (c = 0; c < ARRAY_WIDTH; c = c + 1)
												begin
													psum_A_we[c] = ((k >= (9 + c)) && ((k - (9 + c)) < 256) ? 1'b1 : 1'b0);
													psum_B_we[c] = ((p_idx > 0) && (k < c) ? 1'b1 : 1'b0);
												end
										end
									end
							end
						@(negedge clk_i)
							;
						array_en = 0;
						psum_systolic_en = 0;
						psum_skew_en = 0;
						psum_A_we = 1'sb0;
						psum_B_we = 1'sb0;
						ext_act_sram_we = 1'sb0;
						swap_weights = 1'sb0;
						for (r = 0; r < 8; r = r + 1)
							row_access_en[r] = 1'b0;
						phase_start = global_cycle;
						psum_systolic_en = 0;
						psum_lut_en = 0;
						psum_skew_en = 0;
						psum_A_we = 1'sb0;
						psum_B_we = 1'sb0;
						for (m = 0; m < 259; m = m + 1)
							begin
								@(negedge clk_i)
									;
								if (m < 256)
									psum_A_addr = sv2v_cast_EDE54_signed(m);
								@(posedge clk_i)
									;
								#(1)
									;
								d_idx = m - 2;
								if ((d_idx >= 0) && (d_idx < 256)) begin
									py = (ty * 16) + (d_idx / 16);
									px = (tx * 16) + (d_idx % 16);
									if ((py < CONV_H) && (px < CONV_W)) begin
										for (c = 0; c < 8; c = c + 1)
											if (((cout_b * 8) + c) < Cout)
												actual_quant_l1[py][px][(cout_b * 8) + c] = out_act[c * ACTIVATION_WIDTH+:ACTIVATION_WIDTH];
									end
								end
							end
						drain_quant_cycles = drain_quant_cycles + (global_cycle - phase_start);
						raw_drain_start = global_cycle;
						for (c = 0; c < 8; c = c + 1)
							begin
								psum_A_read_bank_sel = sv2v_cast_3_signed(c);
								for (m = 0; m < 256; m = m + 1)
									begin
										@(negedge clk_i)
											;
										psum_A_addr = sv2v_cast_EDE54_signed(m);
										@(posedge clk_i)
											;
										#(1)
											;
										py = (ty * 16) + (m / 16);
										px = (tx * 16) + (m % 16);
										if ((py < CONV_H) && (px < CONV_W)) begin
											if (((cout_b * 8) + c) < Cout)
												actual_psum_l1[py][px][(cout_b * 8) + c] = psum_A_rdata;
										end
									end
							end
						raw_drain_cycles = raw_drain_cycles + (global_cycle - raw_drain_start);
						completed_blocks = completed_blocks + 1;
						$display(" %s %3d%% | Finished Block %2d/%2d [Tile (%0d,%0d), Cout Blk %0d/4] | Cycle: %8d", get_progress_bar(completed_blocks, total_blocks), (completed_blocks * 100) / total_blocks, completed_blocks, total_blocks, ty, tx, cout_b + 1, global_cycle);
					end
		e2e_total_cycles = (global_cycle - e2e_start_cycle) - raw_drain_cycles;
		$display("\n=====================================================================================");
		$display("   HARDWARE BANK HAZARD MONITOR REPORT");
		$display("=====================================================================================");
		$display(" Total Single-Port Address Collisions Detected : %0d", total_bank_conflicts);
		$display(" Total Simultaneous Read/Write Hazards Detected : %0d", total_rw_conflicts);
		$display("=====================================================================================");
		inspect_full_layer_diagnostics;
		print_performance_report;
		#(200)
			;
		$finish;
	end
	initial _sv2v_0 = 0;
endmodule
