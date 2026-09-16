module npu_minimal_sequencer (
	clk_i,
	rst_n,
	start_pulse_i,
	soft_reset_i,
	reg_quant_param_i,
	reg_config_i,
	busy_o,
	done_pulse_o,
	start_bias_o,
	bias_done_i,
	start_act_o,
	act_done_i,
	start_weight_o,
	weight_pass_idx_o,
	weight_done_i,
	start_drain_o,
	drain_done_i,
	npu_array_en_o,
	npu_psum_systolic_en_o,
	npu_psum_lut_en_o,
	npu_psum_skew_en_o,
	npu_compute_bank_swap_o,
	npu_crossbar_sel_o,
	npu_swap_weights_o,
	npu_quant_shift_in_o,
	npu_quant_shift_en_o,
	npu_stochastic_round_en_o,
	seq_psum_A_addr_o,
	seq_psum_A_we_o,
	seq_psum_A_wdata_o,
	seq_psum_B_addr_o,
	seq_psum_B_we_o,
	seq_psum_B_wdata_o,
	seq_act_sram_addr_o,
	state_code_o,
	pass_idx_o,
	ky_o,
	kx_o,
	comp_k_o
);
	reg _sv2v_0;
	parameter signed [31:0] ARRAY_HEIGHT = 8;
	parameter signed [31:0] ARRAY_WIDTH = 8;
	parameter signed [31:0] TILE_SIZE = 16;
	parameter signed [31:0] ACT_HALO_PAD = 2;
	parameter signed [31:0] ACTIVATION_WIDTH = 8;
	parameter signed [31:0] WEIGHT_WIDTH = 8;
	parameter signed [31:0] PSUM_WIDTH = 32;
	parameter signed [31:0] SCALE_WIDTH = 16;
	parameter signed [31:0] WEIGHT_SPLIT = 2;
	localparam signed [31:0] PSUM_WORDS = TILE_SIZE * TILE_SIZE;
	localparam signed [31:0] ACT_WORDS = (TILE_SIZE * TILE_SIZE) * ACT_HALO_PAD;
	localparam signed [31:0] PSUM_ADDR_WIDTH = $clog2(PSUM_WORDS);
	localparam signed [31:0] ACT_ADDR_WIDTH = $clog2(ACT_WORDS);
	localparam signed [31:0] NUM_ACT_BANKS = ARRAY_HEIGHT;
	localparam signed [31:0] XBAR_SEL_WIDTH = 4;
	localparam signed [31:0] QUANT_CFG_WIDTH = 30;
	input wire clk_i;
	input wire rst_n;
	input wire start_pulse_i;
	input wire soft_reset_i;
	input wire [31:0] reg_quant_param_i;
	input wire [31:0] reg_config_i;
	output reg busy_o;
	output reg done_pulse_o;
	output reg start_bias_o;
	input wire bias_done_i;
	output reg start_act_o;
	input wire act_done_i;
	output reg start_weight_o;
	output wire [3:0] weight_pass_idx_o;
	input wire weight_done_i;
	output reg start_drain_o;
	input wire drain_done_i;
	output reg npu_array_en_o;
	output reg npu_psum_systolic_en_o;
	output reg npu_psum_lut_en_o;
	output reg npu_psum_skew_en_o;
	output reg npu_compute_bank_swap_o;
	output wire [(ARRAY_HEIGHT * XBAR_SEL_WIDTH) - 1:0] npu_crossbar_sel_o;
	output reg npu_swap_weights_o;
	output reg [29:0] npu_quant_shift_in_o;
	output reg npu_quant_shift_en_o;
	output reg npu_stochastic_round_en_o;
	output reg [PSUM_ADDR_WIDTH - 1:0] seq_psum_A_addr_o;
	output reg [ARRAY_WIDTH - 1:0] seq_psum_A_we_o;
	output reg signed [PSUM_WIDTH - 1:0] seq_psum_A_wdata_o;
	output reg [PSUM_ADDR_WIDTH - 1:0] seq_psum_B_addr_o;
	output reg [ARRAY_WIDTH - 1:0] seq_psum_B_we_o;
	output reg signed [PSUM_WIDTH - 1:0] seq_psum_B_wdata_o;
	output reg [(NUM_ACT_BANKS * ACT_ADDR_WIDTH) - 1:0] seq_act_sram_addr_o;
	output reg [3:0] state_code_o;
	output wire [3:0] pass_idx_o;
	output wire [1:0] ky_o;
	output wire [1:0] kx_o;
	output wire [8:0] comp_k_o;
	reg [3:0] state;
	reg [3:0] quant_step;
	reg [3:0] pass_idx;
	reg [8:0] comp_k;
	wire [1:0] ky = (((pass_idx == 4'd0) || (pass_idx == 4'd1)) || (pass_idx == 4'd2) ? 2'd0 : (((pass_idx == 4'd3) || (pass_idx == 4'd4)) || (pass_idx == 4'd5) ? 2'd1 : 2'd2));
	wire [1:0] kx = (((pass_idx == 4'd0) || (pass_idx == 4'd3)) || (pass_idx == 4'd6) ? 2'd0 : (((pass_idx == 4'd1) || (pass_idx == 4'd4)) || (pass_idx == 4'd7) ? 2'd1 : 2'd2));
	wire swap_val = pass_idx[0] == 1'b0;
	wire hold_zero = pass_idx == 4'd0;
	assign pass_idx_o = pass_idx;
	assign ky_o = ky;
	assign kx_o = kx;
	assign comp_k_o = comp_k;
	assign weight_pass_idx_o = pass_idx;
	always @(*) begin
		if (_sv2v_0)
			;
		case (state)
			4'd0: state_code_o = 4'd0;
			4'd1: state_code_o = 4'd2;
			4'd2: state_code_o = 4'd3;
			4'd3: state_code_o = 4'd4;
			4'd4: state_code_o = 4'd6;
			4'd5: state_code_o = 4'd7;
			4'd6: state_code_o = 4'd8;
			4'd7: state_code_o = 4'd10;
			default: state_code_o = 4'd0;
		endcase
	end
	genvar _gv_gr_1;
	function automatic signed [3:0] sv2v_cast_4_signed;
		input reg signed [3:0] inp;
		sv2v_cast_4_signed = inp;
	endfunction
	generate
		for (_gv_gr_1 = 0; _gv_gr_1 < ARRAY_HEIGHT; _gv_gr_1 = _gv_gr_1 + 1) begin : gen_xbar_id
			localparam gr = _gv_gr_1;
			assign npu_crossbar_sel_o[gr * XBAR_SEL_WIDTH+:XBAR_SEL_WIDTH] = sv2v_cast_4_signed(gr);
		end
	endgenerate
	function automatic [ACT_ADDR_WIDTH - 1:0] sv2v_cast_41508;
		input reg [ACT_ADDR_WIDTH - 1:0] inp;
		sv2v_cast_41508 = inp;
	endfunction
	function automatic [PSUM_ADDR_WIDTH - 1:0] sv2v_cast_EDE54;
		input reg [PSUM_ADDR_WIDTH - 1:0] inp;
		sv2v_cast_EDE54 = inp;
	endfunction
	always @(posedge clk_i or negedge rst_n)
		if (!rst_n) begin
			state <= 4'd0;
			busy_o <= 1'b0;
			done_pulse_o <= 1'b0;
			start_bias_o <= 1'b0;
			start_act_o <= 1'b0;
			start_weight_o <= 1'b0;
			start_drain_o <= 1'b0;
			quant_step <= 1'sb0;
			pass_idx <= 1'sb0;
			comp_k <= 1'sb0;
			npu_array_en_o <= 1'b0;
			npu_psum_systolic_en_o <= 1'b0;
			npu_psum_lut_en_o <= 1'b0;
			npu_psum_skew_en_o <= 1'b0;
			npu_compute_bank_swap_o <= 1'b0;
			npu_swap_weights_o <= 1'b0;
			npu_quant_shift_in_o <= 1'sb0;
			npu_quant_shift_en_o <= 1'b0;
			npu_stochastic_round_en_o <= 1'b0;
			seq_psum_A_addr_o <= 1'sb0;
			seq_psum_A_we_o <= 1'sb0;
			seq_psum_A_wdata_o <= 1'sb0;
			seq_psum_B_addr_o <= 1'sb0;
			seq_psum_B_we_o <= 1'sb0;
			seq_psum_B_wdata_o <= 1'sb0;
			seq_act_sram_addr_o <= 1'sb0;
		end
		else if (soft_reset_i) begin
			state <= 4'd0;
			busy_o <= 1'b0;
			done_pulse_o <= 1'b0;
			start_bias_o <= 1'b0;
			start_act_o <= 1'b0;
			start_weight_o <= 1'b0;
			start_drain_o <= 1'b0;
			quant_step <= 1'sb0;
			pass_idx <= 1'sb0;
			comp_k <= 1'sb0;
			npu_array_en_o <= 1'b0;
			npu_psum_systolic_en_o <= 1'b0;
			npu_psum_lut_en_o <= 1'b0;
			npu_psum_skew_en_o <= 1'b0;
			npu_compute_bank_swap_o <= 1'b0;
			npu_swap_weights_o <= 1'b0;
			npu_quant_shift_in_o <= 1'sb0;
			npu_quant_shift_en_o <= 1'b0;
			npu_stochastic_round_en_o <= 1'b0;
			seq_psum_A_addr_o <= 1'sb0;
			seq_psum_A_we_o <= 1'sb0;
			seq_psum_A_wdata_o <= 1'sb0;
			seq_psum_B_addr_o <= 1'sb0;
			seq_psum_B_we_o <= 1'sb0;
			seq_psum_B_wdata_o <= 1'sb0;
			seq_act_sram_addr_o <= 1'sb0;
		end
		else begin
			done_pulse_o <= 1'b0;
			start_bias_o <= 1'b0;
			start_act_o <= 1'b0;
			start_weight_o <= 1'b0;
			start_drain_o <= 1'b0;
			npu_swap_weights_o <= 1'b0;
			case (state)
				4'd0: begin
					busy_o <= 1'b0;
					npu_array_en_o <= 1'b0;
					npu_psum_systolic_en_o <= 1'b0;
					npu_psum_skew_en_o <= 1'b0;
					seq_psum_A_we_o <= 1'sb0;
					seq_psum_B_we_o <= 1'sb0;
					if (start_pulse_i) begin
						busy_o <= 1'b1;
						quant_step <= 1'sb0;
						state <= 4'd1;
					end
				end
				4'd1:
					if (quant_step < 4'd8) begin
						npu_quant_shift_en_o <= 1'b1;
						npu_quant_shift_in_o <= reg_quant_param_i[29:0];
						quant_step <= quant_step + 1'b1;
					end
					else begin
						npu_quant_shift_en_o <= 1'b0;
						start_bias_o <= 1'b1;
						state <= 4'd2;
					end
				4'd2:
					if (bias_done_i) begin
						start_act_o <= 1'b1;
						state <= 4'd3;
					end
				4'd3:
					if (act_done_i) begin
						pass_idx <= 1'sb0;
						start_weight_o <= 1'b1;
						state <= 4'd4;
					end
				4'd4:
					if (weight_done_i) begin
						npu_swap_weights_o <= 1'b1;
						state <= 4'd5;
					end
				4'd5: begin
					npu_swap_weights_o <= 1'b0;
					comp_k <= 1'sb0;
					state <= 4'd6;
				end
				4'd6: begin
					npu_array_en_o <= 1'b1;
					npu_psum_systolic_en_o <= 1'b1;
					npu_psum_lut_en_o <= 1'b0;
					npu_psum_skew_en_o <= 1'b1;
					npu_compute_bank_swap_o <= swap_val;
					begin : sv2v_autoblock_1
						reg signed [31:0] r;
						for (r = 0; r < ARRAY_HEIGHT; r = r + 1)
							if ((comp_k >= r) && ((comp_k - r) < 256))
								seq_act_sram_addr_o[r * ACT_ADDR_WIDTH+:ACT_ADDR_WIDTH] <= sv2v_cast_41508(((((comp_k - r) >> 4) + ky) * 18) + (((comp_k - r) & 9'd15) + kx));
							else
								seq_act_sram_addr_o[r * ACT_ADDR_WIDTH+:ACT_ADDR_WIDTH] <= 1'sb0;
					end
					if (!swap_val) begin
						seq_psum_A_addr_o <= (hold_zero ? 8'd0 : (comp_k < 256 ? sv2v_cast_EDE54(comp_k) : 8'd0));
						seq_psum_B_addr_o <= ((comp_k >= 9) && ((comp_k - 9) < 256) ? sv2v_cast_EDE54(comp_k - 9) : 8'd0);
						seq_psum_A_we_o <= 8'h00;
						begin : sv2v_autoblock_2
							reg signed [31:0] c;
							for (c = 0; c < ARRAY_WIDTH; c = c + 1)
								seq_psum_B_we_o[c] <= (comp_k >= (9 + c)) && ((comp_k - (9 + c)) < 256);
						end
					end
					else begin
						seq_psum_B_addr_o <= (hold_zero ? 8'd0 : (comp_k < 256 ? sv2v_cast_EDE54(comp_k) : 8'd0));
						seq_psum_A_addr_o <= ((comp_k >= 9) && ((comp_k - 9) < 256) ? sv2v_cast_EDE54(comp_k - 9) : 8'd0);
						seq_psum_B_we_o <= 8'h00;
						begin : sv2v_autoblock_3
							reg signed [31:0] c;
							for (c = 0; c < ARRAY_WIDTH; c = c + 1)
								seq_psum_A_we_o[c] <= (comp_k >= (9 + c)) && ((comp_k - (9 + c)) < 256);
						end
					end
					if (comp_k < 9'd272)
						comp_k <= comp_k + 1'b1;
					else begin
						npu_array_en_o <= 1'b0;
						npu_psum_systolic_en_o <= 1'b0;
						npu_psum_skew_en_o <= 1'b0;
						seq_psum_A_we_o <= 8'h00;
						seq_psum_B_we_o <= 8'h00;
						if (pass_idx < 4'd8) begin
							pass_idx <= pass_idx + 1'b1;
							start_weight_o <= 1'b1;
							state <= 4'd4;
						end
						else if (reg_config_i[0]) begin
							start_drain_o <= 1'b1;
							state <= 4'd7;
						end
						else begin
							done_pulse_o <= 1'b1;
							state <= 4'd0;
						end
					end
				end
				4'd7:
					if (drain_done_i) begin
						done_pulse_o <= 1'b1;
						state <= 4'd0;
					end
				default: state <= 4'd0;
			endcase
		end
	initial _sv2v_0 = 0;
endmodule
