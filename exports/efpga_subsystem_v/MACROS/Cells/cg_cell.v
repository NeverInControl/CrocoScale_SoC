module cg_cell (
	clk_i,
	enable_i,
	clk_o
);
	input wire clk_i;
	input wire enable_i;
	output wire clk_o;
	sg13cmos5l_lgcp_1 u_icg(
		.CLK(clk_i),
		.GATE(enable_i),
		.GCLK(clk_o)
	);
endmodule
