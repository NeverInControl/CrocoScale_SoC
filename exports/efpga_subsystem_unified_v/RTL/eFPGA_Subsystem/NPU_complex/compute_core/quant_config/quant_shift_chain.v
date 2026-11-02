module quant_shift_chain (
	clk_i,
	rst_n,
	quant_shift_in,
	quant_shift_en,
	quant_cfg_out
);
	parameter signed [31:0] ARRAY_WIDTH = 8;
	parameter signed [31:0] ACTIVATION_WIDTH = 8;
	parameter signed [31:0] PSUM_WIDTH = 32;
	parameter signed [31:0] SCALE_WIDTH = 16;
	localparam signed [31:0] PROD_WIDTH = PSUM_WIDTH + SCALE_WIDTH;
	localparam signed [31:0] SHIFT_WIDTH = $clog2(PROD_WIDTH);
	localparam signed [31:0] QUANT_CFG_WIDTH = (SCALE_WIDTH + SHIFT_WIDTH) + ACTIVATION_WIDTH;
	input wire clk_i;
	input wire rst_n;
	input wire [QUANT_CFG_WIDTH - 1:0] quant_shift_in;
	input wire quant_shift_en;
	output wire [(ARRAY_WIDTH * QUANT_CFG_WIDTH) - 1:0] quant_cfg_out;
	reg [QUANT_CFG_WIDTH - 1:0] quant_cfg_chain [0:ARRAY_WIDTH - 1];
	always @(posedge clk_i or negedge rst_n)
		if (!rst_n) begin : sv2v_autoblock_1
			reg signed [31:0] i;
			for (i = 0; i < ARRAY_WIDTH; i = i + 1)
				quant_cfg_chain[i] <= 1'sb0;
		end
		else if (quant_shift_en) begin
			quant_cfg_chain[0] <= quant_shift_in;
			begin : sv2v_autoblock_2
				reg signed [31:0] i;
				for (i = 1; i < ARRAY_WIDTH; i = i + 1)
					quant_cfg_chain[i] <= quant_cfg_chain[i - 1];
			end
		end
	genvar _gv_q_1;
	generate
		for (_gv_q_1 = 0; _gv_q_1 < ARRAY_WIDTH; _gv_q_1 = _gv_q_1 + 1) begin : gen_cfg_out
			localparam q = _gv_q_1;
			assign quant_cfg_out[q * QUANT_CFG_WIDTH+:QUANT_CFG_WIDTH] = quant_cfg_chain[q];
		end
	endgenerate
endmodule
