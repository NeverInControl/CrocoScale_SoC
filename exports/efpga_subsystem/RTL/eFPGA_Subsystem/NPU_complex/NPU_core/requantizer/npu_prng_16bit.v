module npu_prng (
	clk_i,
	rst_n,
	rand_out
);
	parameter signed [31:0] LFSR_WIDTH = 16;
	parameter [LFSR_WIDTH - 1:0] RESET_SEED = 1'sb0;
	parameter [LFSR_WIDTH - 1:0] POLY = 1'sb0;
	input wire clk_i;
	input wire rst_n;
	output wire [LFSR_WIDTH - 1:0] rand_out;
	function automatic [LFSR_WIDTH - 1:0] get_default_poly;
		input reg _sv2v_unused;
		case (LFSR_WIDTH)
			8: get_default_poly = 8'hb8;
			16: get_default_poly = 16'hb400;
			24: get_default_poly = 24'he10000;
			32: get_default_poly = 32'h80000057;
			default: get_default_poly = 16'hb400;
		endcase
	endfunction
	function automatic [LFSR_WIDTH - 1:0] get_default_seed;
		input reg _sv2v_unused;
		case (LFSR_WIDTH)
			8: get_default_seed = 8'hac;
			16: get_default_seed = 16'hace1;
			24: get_default_seed = 24'hace100;
			32: get_default_seed = 32'hace12345;
			default: get_default_seed = (LFSR_WIDTH >= 16 ? 16'hace1 : 8'hac);
		endcase
	endfunction
	localparam [LFSR_WIDTH - 1:0] ACTIVE_POLY = (POLY != {LFSR_WIDTH {1'sb0}} ? POLY : get_default_poly(0));
	localparam [LFSR_WIDTH - 1:0] DEFAULT_SEED = (RESET_SEED != {LFSR_WIDTH {1'sb0}} ? RESET_SEED : get_default_seed(0));
	reg [LFSR_WIDTH - 1:0] lfsr;
	always @(posedge clk_i or negedge rst_n)
		if (!rst_n)
			lfsr <= (DEFAULT_SEED != {LFSR_WIDTH {1'sb0}} ? DEFAULT_SEED : {LFSR_WIDTH {1'sb1}});
		else
			lfsr <= {lfsr[LFSR_WIDTH - 2:0], 1'b0} ^ (lfsr[LFSR_WIDTH - 1] ? ACTIVE_POLY : {LFSR_WIDTH {1'sb0}});
	assign rand_out = lfsr;
endmodule
