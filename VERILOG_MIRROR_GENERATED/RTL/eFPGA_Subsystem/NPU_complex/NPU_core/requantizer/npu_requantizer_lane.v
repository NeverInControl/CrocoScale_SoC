module npu_requantizer_lane (
	clk_i,
	rst_n,
	psum_in,
	scale_m0,
	shift_n,
	zero_point,
	stochastic_round_en,
	noise_in,
	act_out
);
	reg _sv2v_0;
	parameter signed [31:0] PSUM_WIDTH = 32;
	parameter signed [31:0] SCALE_WIDTH = 16;
	parameter signed [31:0] ACTIVATION_WIDTH = 8;
	input wire clk_i;
	input wire rst_n;
	input wire signed [PSUM_WIDTH - 1:0] psum_in;
	input wire signed [SCALE_WIDTH - 1:0] scale_m0;
	input wire [$clog2(PSUM_WIDTH + SCALE_WIDTH) - 1:0] shift_n;
	input wire signed [ACTIVATION_WIDTH - 1:0] zero_point;
	input wire stochastic_round_en;
	input wire [SCALE_WIDTH - 1:0] noise_in;
	output reg signed [ACTIVATION_WIDTH - 1:0] act_out;
	localparam signed [31:0] PROD_WIDTH = PSUM_WIDTH + SCALE_WIDTH;
	localparam signed [31:0] SHIFT_WIDTH = $clog2(PROD_WIDTH);
	localparam signed [PROD_WIDTH - 1:0] ONE = 1;
	localparam signed [PROD_WIDTH - 1:0] SIGNED_MAX = (ONE << (ACTIVATION_WIDTH - 1)) - 1;
	localparam signed [PROD_WIDTH - 1:0] SIGNED_MIN = -(ONE << (ACTIVATION_WIDTH - 1));
	reg signed [PROD_WIDTH - 1:0] stage1_prod;
	reg [SHIFT_WIDTH - 1:0] stage1_shift;
	reg signed [ACTIVATION_WIDTH - 1:0] stage1_zp;
	reg stage1_stochastic;
	reg [SCALE_WIDTH - 1:0] stage1_noise;
	always @(posedge clk_i or negedge rst_n)
		if (!rst_n) begin
			stage1_prod <= 1'sb0;
			stage1_shift <= 1'sb0;
			stage1_zp <= 1'sb0;
			stage1_stochastic <= 1'sb0;
			stage1_noise <= 1'sb0;
		end
		else begin
			stage1_prod <= psum_in * scale_m0;
			stage1_shift <= shift_n;
			stage1_zp <= zero_point;
			stage1_stochastic <= stochastic_round_en;
			stage1_noise <= noise_in;
		end
	reg signed [PROD_WIDTH - 1:0] round_offset;
	reg signed [PROD_WIDTH - 1:0] rounded_prod;
	reg signed [PROD_WIDTH - 1:0] shifted_val;
	reg signed [PROD_WIDTH - 1:0] offset_val;
	reg signed [ACTIVATION_WIDTH - 1:0] clamped_val;
	function automatic signed [PROD_WIDTH - 1:0] sv2v_cast_614BF_signed;
		input reg signed [PROD_WIDTH - 1:0] inp;
		sv2v_cast_614BF_signed = inp;
	endfunction
	wire [PROD_WIDTH - 1:0] noise_mask = (sv2v_cast_614BF_signed(1) << stage1_shift) - 1'b1;
	function automatic [PROD_WIDTH - 1:0] sv2v_cast_614BF;
		input reg [PROD_WIDTH - 1:0] inp;
		sv2v_cast_614BF = inp;
	endfunction
	wire [PROD_WIDTH - 1:0] dither_val = sv2v_cast_614BF(stage1_noise) & noise_mask;
	always @(*) begin
		if (_sv2v_0)
			;
		if (stage1_stochastic && (stage1_shift > 6'd0))
			round_offset = $signed(dither_val);
		else if (stage1_shift > 6'd0)
			round_offset = (ONE << (stage1_shift - 1'b1)) - (stage1_prod[PROD_WIDTH - 1] ? ONE : {PROD_WIDTH {1'sb0}});
		else
			round_offset = 1'sb0;
		rounded_prod = stage1_prod + round_offset;
		shifted_val = rounded_prod >>> stage1_shift;
		offset_val = shifted_val + sv2v_cast_614BF_signed($signed(stage1_zp));
		if (offset_val > SIGNED_MAX)
			clamped_val = SIGNED_MAX[ACTIVATION_WIDTH - 1:0];
		else if (offset_val < SIGNED_MIN)
			clamped_val = SIGNED_MIN[ACTIVATION_WIDTH - 1:0];
		else
			clamped_val = offset_val[ACTIVATION_WIDTH - 1:0];
	end
	always @(posedge clk_i or negedge rst_n)
		if (!rst_n)
			act_out <= 1'sb0;
		else
			act_out <= clamped_val;
	initial _sv2v_0 = 0;
endmodule
