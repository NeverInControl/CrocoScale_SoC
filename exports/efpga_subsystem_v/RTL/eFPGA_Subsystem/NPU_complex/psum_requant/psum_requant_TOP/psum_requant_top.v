module psum_requant_top (
	clk_i,
	rst_n,
	psum_lut_en,
	bank_A_addr,
	bank_A_we,
	bank_A_wdata,
	bank_A_rdata,
	bank_B_addr,
	bank_B_we,
	bank_B_wdata,
	bank_B_rdata,
	quant_cfg,
	out_act
);
	parameter signed [31:0] ARRAY_WIDTH = 8;
	parameter signed [31:0] PSUM_WIDTH = 32;
	parameter signed [31:0] PSUM_WORDS = 256;
	parameter signed [31:0] SCALE_WIDTH = 16;
	parameter signed [31:0] ACTIVATION_WIDTH = 8;
	localparam signed [31:0] PSUM_ADDR_WIDTH = $clog2(PSUM_WORDS);
	localparam signed [31:0] PROD_WIDTH = PSUM_WIDTH + SCALE_WIDTH;
	localparam signed [31:0] SHIFT_WIDTH = $clog2(PROD_WIDTH);
	localparam signed [31:0] QUANT_CFG_WIDTH = (SCALE_WIDTH + SHIFT_WIDTH) + ACTIVATION_WIDTH;
	input wire clk_i;
	input wire rst_n;
	input wire psum_lut_en;
	input wire [(ARRAY_WIDTH * PSUM_ADDR_WIDTH) - 1:0] bank_A_addr;
	input wire [ARRAY_WIDTH - 1:0] bank_A_we;
	input wire signed [(ARRAY_WIDTH * PSUM_WIDTH) - 1:0] bank_A_wdata;
	output wire signed [(ARRAY_WIDTH * PSUM_WIDTH) - 1:0] bank_A_rdata;
	input wire [(ARRAY_WIDTH * PSUM_ADDR_WIDTH) - 1:0] bank_B_addr;
	input wire [ARRAY_WIDTH - 1:0] bank_B_we;
	input wire signed [(ARRAY_WIDTH * PSUM_WIDTH) - 1:0] bank_B_wdata;
	output wire signed [(ARRAY_WIDTH * PSUM_WIDTH) - 1:0] bank_B_rdata;
	input wire [(ARRAY_WIDTH * QUANT_CFG_WIDTH) - 1:0] quant_cfg;
	output wire signed [(ARRAY_WIDTH * ACTIVATION_WIDTH) - 1:0] out_act;
	genvar _gv_c_1;
	generate
		for (_gv_c_1 = 0; _gv_c_1 < ARRAY_WIDTH; _gv_c_1 = _gv_c_1 + 1) begin : gen_containers
			localparam c = _gv_c_1;
			psum_requant_container #(
				.PSUM_WIDTH(PSUM_WIDTH),
				.PSUM_WORDS(PSUM_WORDS),
				.SCALE_WIDTH(SCALE_WIDTH),
				.ACTIVATION_WIDTH(ACTIVATION_WIDTH)
			) container_inst(
				.clk_i(clk_i),
				.rst_n(rst_n),
				.psum_lut_en(psum_lut_en),
				.bank_A_addr(bank_A_addr[c * PSUM_ADDR_WIDTH+:PSUM_ADDR_WIDTH]),
				.bank_A_we(bank_A_we[c]),
				.bank_A_wdata(bank_A_wdata[c * PSUM_WIDTH+:PSUM_WIDTH]),
				.bank_A_rdata(bank_A_rdata[c * PSUM_WIDTH+:PSUM_WIDTH]),
				.bank_B_addr(bank_B_addr[c * PSUM_ADDR_WIDTH+:PSUM_ADDR_WIDTH]),
				.bank_B_we(bank_B_we[c]),
				.bank_B_wdata(bank_B_wdata[c * PSUM_WIDTH+:PSUM_WIDTH]),
				.bank_B_rdata(bank_B_rdata[c * PSUM_WIDTH+:PSUM_WIDTH]),
				.quant_cfg(quant_cfg[c * QUANT_CFG_WIDTH+:QUANT_CFG_WIDTH]),
				.act_out(out_act[c * ACTIVATION_WIDTH+:ACTIVATION_WIDTH])
			);
		end
	endgenerate
endmodule
