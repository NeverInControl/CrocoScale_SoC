module act_buffer_top (
	act_clk_i,
	ext_act_sram_we,
	ext_act_sram_addr,
	ext_act_sram_wdata,
	act_sram_rdata,
	weight_shift_in,
	weight_shift_en,
	crossbar_sel,
	out_act,
	npu_clk_core,
	clk_o,
	act_sram_rdata_east,
	weight_shift_in_east,
	weight_shift_en_east,
	crossbar_sel_east,
	out_act_east
);
	parameter signed [31:0] NUM_ACT_BANKS = 8;
	parameter signed [31:0] ACT_WORDS = 512;
	parameter signed [31:0] ACTIVATION_WIDTH = 8;
	parameter signed [31:0] WEIGHT_WIDTH = 8;
	parameter signed [31:0] XBAR_SEL_WIDTH = 4;
	localparam signed [31:0] ACT_ADDR_WIDTH = $clog2(ACT_WORDS);
	input wire [NUM_ACT_BANKS - 1:0] act_clk_i;
	input wire [NUM_ACT_BANKS - 1:0] ext_act_sram_we;
	input wire [(NUM_ACT_BANKS * ACT_ADDR_WIDTH) - 1:0] ext_act_sram_addr;
	input wire signed [(NUM_ACT_BANKS * ACTIVATION_WIDTH) - 1:0] ext_act_sram_wdata;
	output wire signed [(NUM_ACT_BANKS * ACTIVATION_WIDTH) - 1:0] act_sram_rdata;
	input wire signed [(NUM_ACT_BANKS * WEIGHT_WIDTH) - 1:0] weight_shift_in;
	input wire [NUM_ACT_BANKS - 1:0] weight_shift_en;
	input wire [(NUM_ACT_BANKS * XBAR_SEL_WIDTH) - 1:0] crossbar_sel;
	output wire signed [(NUM_ACT_BANKS * ACTIVATION_WIDTH) - 1:0] out_act;
	output wire npu_clk_core;
	output wire [NUM_ACT_BANKS - 1:0] clk_o;
	output wire signed [(NUM_ACT_BANKS * ACTIVATION_WIDTH) - 1:0] act_sram_rdata_east;
	output wire signed [(NUM_ACT_BANKS * WEIGHT_WIDTH) - 1:0] weight_shift_in_east;
	output wire [NUM_ACT_BANKS - 1:0] weight_shift_en_east;
	output wire [(NUM_ACT_BANKS * XBAR_SEL_WIDTH) - 1:0] crossbar_sel_east;
	input wire signed [(NUM_ACT_BANKS * ACTIVATION_WIDTH) - 1:0] out_act_east;
	assign npu_clk_core = clk_o[3];
	genvar _gv_i_1;
	generate
		for (_gv_i_1 = 0; _gv_i_1 < NUM_ACT_BANKS; _gv_i_1 = _gv_i_1 + 1) begin : gen_containers
			localparam i = _gv_i_1;
			act_bank_container #(
				.ACTIVATION_WIDTH(ACTIVATION_WIDTH),
				.ACT_WORDS(ACT_WORDS),
				.WEIGHT_WIDTH(WEIGHT_WIDTH),
				.XBAR_SEL_WIDTH(XBAR_SEL_WIDTH)
			) container_inst(
				.clk_i(act_clk_i[i]),
				.act_we(ext_act_sram_we[i]),
				.act_addr(ext_act_sram_addr[i * ACT_ADDR_WIDTH+:ACT_ADDR_WIDTH]),
				.act_wdata(ext_act_sram_wdata[i * ACTIVATION_WIDTH+:ACTIVATION_WIDTH]),
				.act_rdata_west(act_sram_rdata[i * ACTIVATION_WIDTH+:ACTIVATION_WIDTH]),
				.weight_in_west(weight_shift_in[i * WEIGHT_WIDTH+:WEIGHT_WIDTH]),
				.weight_shift_en_west(weight_shift_en[i]),
				.xbar_sel_west(crossbar_sel[i * XBAR_SEL_WIDTH+:XBAR_SEL_WIDTH]),
				.out_act_west(out_act[i * ACTIVATION_WIDTH+:ACTIVATION_WIDTH]),
				.clk_o(clk_o[i]),
				.act_rdata_east(act_sram_rdata_east[i * ACTIVATION_WIDTH+:ACTIVATION_WIDTH]),
				.weight_in_east(weight_shift_in_east[i * WEIGHT_WIDTH+:WEIGHT_WIDTH]),
				.weight_shift_en_east(weight_shift_en_east[i]),
				.xbar_sel_east(crossbar_sel_east[i * XBAR_SEL_WIDTH+:XBAR_SEL_WIDTH]),
				.out_act_east(out_act_east[i * ACTIVATION_WIDTH+:ACTIVATION_WIDTH])
			);
		end
	endgenerate
endmodule
