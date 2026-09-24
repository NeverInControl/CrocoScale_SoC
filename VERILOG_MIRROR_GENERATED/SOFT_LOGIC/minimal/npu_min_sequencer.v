module npu_min_sequencer (
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
	npu_psum_skew_en_o,
	npu_compute_bank_swap_o,
	npu_crossbar_sel_o,
	npu_swap_weights_o,
	npu_quant_shift_in_o,
	npu_quant_shift_en_o,
	npu_stochastic_round_en_o,
	seq_psum_A_addr_o,
	seq_psum_A_we_o,
	seq_psum_B_addr_o,
	seq_psum_B_we_o,
	seq_act_sram_addr_o,
	state_code_o,
	pass_idx_o,
	ky_o,
	kx_o,
	comp_k_o
);
	reg _sv2v_0;
	parameter signed [31:0] KERNEL_SIZE = 3;
	parameter signed [31:0] ARRAY_HEIGHT = 8;
	parameter signed [31:0] ARRAY_WIDTH = 8;
	parameter signed [31:0] TILE_SIZE = 16;
	parameter signed [31:0] ACT_HALO_PAD = 2;
	parameter signed [31:0] ACTIVATION_WIDTH = 8;
	parameter signed [31:0] WEIGHT_WIDTH = 8;
	parameter signed [31:0] PSUM_WIDTH = 32;
	parameter signed [31:0] SCALE_WIDTH = 16;
	parameter signed [31:0] WEIGHT_SPLIT = 2;
	localparam signed [31:0] TOTAL_PASSES = (KERNEL_SIZE == 1 ? 1 : 9);
	localparam signed [31:0] PSUM_ADDR_WIDTH = 8;
	localparam signed [31:0] ACT_ADDR_WIDTH = 9;
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
	output reg npu_psum_skew_en_o;
	output reg npu_compute_bank_swap_o;
	output wire [(ARRAY_HEIGHT * XBAR_SEL_WIDTH) - 1:0] npu_crossbar_sel_o;
	output reg npu_swap_weights_o;
	output reg [29:0] npu_quant_shift_in_o;
	output reg npu_quant_shift_en_o;
	output wire npu_stochastic_round_en_o;
	output wire [7:0] seq_psum_A_addr_o;
	output wire [ARRAY_WIDTH - 1:0] seq_psum_A_we_o;
	output wire [7:0] seq_psum_B_addr_o;
	output wire [ARRAY_WIDTH - 1:0] seq_psum_B_we_o;
	output wire [(NUM_ACT_BANKS * ACT_ADDR_WIDTH) - 1:0] seq_act_sram_addr_o;
	output reg [3:0] state_code_o;
	output wire [3:0] pass_idx_o;
	output wire [1:0] ky_o;
	output wire [1:0] kx_o;
	output wire [8:0] comp_k_o;
	reg [2:0] state;
	reg [2:0] quant_step;
	reg [3:0] pass_idx;
	reg [8:0] comp_k;
	assign pass_idx_o = pass_idx;
	assign comp_k_o = comp_k;
	assign weight_pass_idx_o = pass_idx;
	assign npu_stochastic_round_en_o = 1'b0;
	assign ky_o = 1'sb0;
	assign kx_o = 1'sb0;
	always @(*) begin
		if (_sv2v_0)
			;
		case (state)
			3'd0: state_code_o = 4'd0;
			3'd1: state_code_o = 4'd2;
			3'd2: state_code_o = 4'd3;
			3'd3: state_code_o = 4'd4;
			3'd4: state_code_o = 4'd6;
			3'd5: state_code_o = 4'd7;
			3'd6: state_code_o = 4'd8;
			3'd7: state_code_o = 4'd10;
			default: state_code_o = 4'd0;
		endcase
	end
	genvar _gv_r_1;
	function automatic signed [3:0] sv2v_cast_4_signed;
		input reg signed [3:0] inp;
		sv2v_cast_4_signed = inp;
	endfunction
	generate
		for (_gv_r_1 = 0; _gv_r_1 < ARRAY_HEIGHT; _gv_r_1 = _gv_r_1 + 1) begin : gen_xbar
			localparam r = _gv_r_1;
			assign npu_crossbar_sel_o[r * XBAR_SEL_WIDTH+:XBAR_SEL_WIDTH] = sv2v_cast_4_signed(r);
		end
	endgenerate
	npu_min_addr_gen #(
		.KERNEL_SIZE(KERNEL_SIZE),
		.ARRAY_HEIGHT(ARRAY_HEIGHT),
		.ACT_ADDR_WIDTH(ACT_ADDR_WIDTH)
	) addr_gen_inst(
		.clk_i(clk_i),
		.rst_n(rst_n),
		.pass_idx_i(pass_idx),
		.comp_k_i(comp_k),
		.act_sram_addr_o(seq_act_sram_addr_o)
	);
	wire swap_val = pass_idx[0] == 1'b0;
	wire hold_zero = pass_idx == 4'd0;
	wire [7:0] psum_rd_addr;
	reg [7:0] psum_wr_addr;
	reg [ARRAY_WIDTH - 1:0] psum_wr_we;
	wire col0_active = (state == 3'd6) && ((comp_k >= 9'd8) && (comp_k < 9'd264));
	assign psum_rd_addr = (hold_zero || comp_k[8] ? 8'd0 : comp_k[7:0]);
	assign seq_psum_A_addr_o = (state == 3'd6 ? (swap_val ? psum_wr_addr : psum_rd_addr) : 8'd0);
	assign seq_psum_B_addr_o = (state == 3'd6 ? (swap_val ? psum_rd_addr : psum_wr_addr) : 8'd0);
	assign seq_psum_A_we_o = ((state == 3'd6) && swap_val ? psum_wr_we : 8'd0);
	assign seq_psum_B_we_o = ((state == 3'd6) && !swap_val ? psum_wr_we : 8'd0);
	always @(posedge clk_i)
		if (!rst_n || soft_reset_i) begin
			state <= 3'd0;
			busy_o <= 1'b0;
			done_pulse_o <= 1'b0;
			start_bias_o <= 1'b0;
			start_act_o <= 1'b0;
			start_weight_o <= 1'b0;
			start_drain_o <= 1'b0;
			quant_step <= 1'sb0;
			pass_idx <= 1'sb0;
			comp_k <= 1'sb0;
			psum_wr_we <= 1'sb0;
			psum_wr_addr <= 1'sb0;
			npu_array_en_o <= 1'b0;
			npu_psum_systolic_en_o <= 1'b0;
			npu_psum_skew_en_o <= 1'b0;
			npu_compute_bank_swap_o <= 1'b0;
			npu_swap_weights_o <= 1'b0;
			npu_quant_shift_in_o <= 1'sb0;
			npu_quant_shift_en_o <= 1'b0;
		end
		else begin
			done_pulse_o <= 1'b0;
			start_bias_o <= 1'b0;
			start_act_o <= 1'b0;
			start_weight_o <= 1'b0;
			start_drain_o <= 1'b0;
			npu_swap_weights_o <= 1'b0;
			if (state == 3'd6) begin
				psum_wr_we <= {psum_wr_we[6:0], col0_active};
				if (psum_wr_we[0])
					psum_wr_addr <= psum_wr_addr + 1'b1;
				else
					psum_wr_addr <= 1'sb0;
			end
			else begin
				psum_wr_we <= 1'sb0;
				psum_wr_addr <= 1'sb0;
			end
			case (state)
				3'd0: begin
					busy_o <= 1'b0;
					npu_array_en_o <= 1'b0;
					npu_psum_systolic_en_o <= 1'b0;
					npu_psum_skew_en_o <= 1'b0;
					if (start_pulse_i) begin
						busy_o <= 1'b1;
						npu_quant_shift_in_o <= reg_quant_param_i[29:0];
						npu_quant_shift_en_o <= 1'b1;
						quant_step <= 1'sb0;
						state <= 3'd1;
					end
				end
				3'd1: begin
					quant_step <= quant_step + 1'b1;
					if (quant_step != 3'd7)
						npu_quant_shift_en_o <= 1'b1;
					else begin
						npu_quant_shift_en_o <= 1'b0;
						start_bias_o <= 1'b1;
						state <= 3'd2;
					end
				end
				3'd2:
					if (bias_done_i) begin
						start_act_o <= 1'b1;
						state <= 3'd3;
					end
				3'd3:
					if (act_done_i) begin
						pass_idx <= 1'sb0;
						start_weight_o <= 1'b1;
						state <= 3'd4;
					end
				3'd4:
					if (weight_done_i) begin
						npu_swap_weights_o <= 1'b1;
						state <= 3'd5;
					end
				3'd5: begin
					npu_swap_weights_o <= 1'b0;
					comp_k <= 1'sb0;
					state <= 3'd6;
				end
				3'd6: begin
					npu_array_en_o <= 1'b1;
					npu_psum_systolic_en_o <= 1'b1;
					npu_psum_skew_en_o <= 1'b1;
					npu_compute_bank_swap_o <= swap_val;
					if (!(comp_k[8] && comp_k[4]))
						comp_k <= comp_k + 1'b1;
					else begin
						npu_array_en_o <= 1'b0;
						npu_psum_systolic_en_o <= 1'b0;
						npu_psum_skew_en_o <= 1'b0;
						if ((pass_idx + 1'b1) < sv2v_cast_4_signed(TOTAL_PASSES)) begin
							pass_idx <= pass_idx + 1'b1;
							start_weight_o <= 1'b1;
							state <= 3'd4;
						end
						else if (reg_config_i[0]) begin
							start_drain_o <= 1'b1;
							state <= 3'd7;
						end
						else begin
							done_pulse_o <= 1'b1;
							busy_o <= 1'b0;
							state <= 3'd0;
						end
					end
				end
				3'd7:
					if (drain_done_i) begin
						done_pulse_o <= 1'b1;
						busy_o <= 1'b0;
						state <= 3'd0;
					end
				default: state <= 3'd0;
			endcase
		end
	initial _sv2v_0 = 0;
endmodule
