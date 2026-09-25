module pe (
	clk_i,
	rst_n,
	array_en,
	act_in,
	psum_in,
	act_out,
	psum_out,
	weight_shift_in,
	weight_shift_out,
	weight_shift_en,
	swap_weights
);
	parameter signed [31:0] ACTIVATION_WIDTH = 8;
	parameter signed [31:0] WEIGHT_WIDTH = 8;
	parameter signed [31:0] PSUM_WIDTH = 32;
	input wire clk_i;
	input wire rst_n;
	input wire array_en;
	input wire signed [ACTIVATION_WIDTH - 1:0] act_in;
	input wire signed [PSUM_WIDTH - 1:0] psum_in;
	output reg signed [ACTIVATION_WIDTH - 1:0] act_out;
	output reg signed [PSUM_WIDTH - 1:0] psum_out;
	input wire signed [WEIGHT_WIDTH - 1:0] weight_shift_in;
	output wire signed [WEIGHT_WIDTH - 1:0] weight_shift_out;
	input wire weight_shift_en;
	input wire swap_weights;
	reg signed [WEIGHT_WIDTH - 1:0] shadow_weight;
	reg signed [WEIGHT_WIDTH - 1:0] active_weight;
	always @(posedge clk_i or negedge rst_n)
		if (!rst_n)
			shadow_weight <= 1'sb0;
		else if (weight_shift_en)
			shadow_weight <= weight_shift_in;
	assign weight_shift_out = shadow_weight;
	always @(posedge clk_i or negedge rst_n)
		if (!rst_n) begin
			active_weight <= 1'sb0;
			act_out <= 1'sb0;
			psum_out <= 1'sb0;
		end
		else begin
			if (swap_weights)
				active_weight <= shadow_weight;
			if (array_en) begin
				act_out <= act_in;
				psum_out <= psum_in + (act_in * active_weight);
			end
		end
endmodule
