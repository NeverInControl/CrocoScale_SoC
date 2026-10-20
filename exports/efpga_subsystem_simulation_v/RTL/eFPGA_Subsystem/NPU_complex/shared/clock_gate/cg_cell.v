module cg_cell (
	clk_i,
	enable_i,
	clk_o
);
	input wire clk_i;
	input wire enable_i;
	output wire clk_o;
	reg en_latch;
	always @(clk_i or enable_i)
		if (!clk_i)
			en_latch <= enable_i;
	assign clk_o = clk_i & en_latch;
endmodule
