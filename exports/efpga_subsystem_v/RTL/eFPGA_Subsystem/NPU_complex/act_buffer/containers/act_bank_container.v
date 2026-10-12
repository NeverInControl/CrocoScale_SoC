module act_bank_container (
	clk_i,
	act_we,
	act_addr,
	act_wdata,
	act_rdata_west,
	weight_in_west,
	weight_shift_en_west,
	xbar_sel_west,
	out_act_west,
	clk_o,
	act_rdata_east,
	weight_in_east,
	weight_shift_en_east,
	xbar_sel_east,
	out_act_east
);
	parameter signed [31:0] ACTIVATION_WIDTH = 8;
	parameter signed [31:0] ACT_WORDS = 512;
	parameter signed [31:0] WEIGHT_WIDTH = 8;
	parameter signed [31:0] XBAR_SEL_WIDTH = 4;
	localparam signed [31:0] ACT_ADDR_WIDTH = $clog2(ACT_WORDS);
	input wire clk_i;
	input wire act_we;
	input wire [ACT_ADDR_WIDTH - 1:0] act_addr;
	input wire signed [ACTIVATION_WIDTH - 1:0] act_wdata;
	output wire signed [ACTIVATION_WIDTH - 1:0] act_rdata_west;
	input wire signed [WEIGHT_WIDTH - 1:0] weight_in_west;
	input wire weight_shift_en_west;
	input wire [XBAR_SEL_WIDTH - 1:0] xbar_sel_west;
	output wire signed [ACTIVATION_WIDTH - 1:0] out_act_west;
	output wire clk_o;
	output wire signed [ACTIVATION_WIDTH - 1:0] act_rdata_east;
	output wire signed [WEIGHT_WIDTH - 1:0] weight_in_east;
	output wire weight_shift_en_east;
	output wire [XBAR_SEL_WIDTH - 1:0] xbar_sel_east;
	input wire signed [ACTIVATION_WIDTH - 1:0] out_act_east;
	wire signed [ACTIVATION_WIDTH - 1:0] sram_rdata;
	sram_bank #(
		.DATA_WIDTH(ACTIVATION_WIDTH),
		.DEPTH(ACT_WORDS)
	) act_sram_inst(
		.clk_i(clk_i),
		.we(act_we),
		.addr(act_addr),
		.wdata(act_wdata),
		.rdata(sram_rdata)
	);
	assign act_rdata_west = sram_rdata;
	assign act_rdata_east = sram_rdata;
	assign clk_o = clk_i;
	assign weight_in_east = weight_in_west;
	assign weight_shift_en_east = weight_shift_en_west;
	assign xbar_sel_east = xbar_sel_west;
	assign out_act_west = out_act_east;
endmodule
