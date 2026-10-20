module psum_requant_container (
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
	act_out
);
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
	input wire [PSUM_ADDR_WIDTH - 1:0] bank_A_addr;
	input wire bank_A_we;
	input wire signed [PSUM_WIDTH - 1:0] bank_A_wdata;
	output wire signed [PSUM_WIDTH - 1:0] bank_A_rdata;
	input wire [PSUM_ADDR_WIDTH - 1:0] bank_B_addr;
	input wire bank_B_we;
	input wire signed [PSUM_WIDTH - 1:0] bank_B_wdata;
	output wire signed [PSUM_WIDTH - 1:0] bank_B_rdata;
	input wire [QUANT_CFG_WIDTH - 1:0] quant_cfg;
	output wire signed [ACTIVATION_WIDTH - 1:0] act_out;
	sram_bank #(
		.DATA_WIDTH(PSUM_WIDTH),
		.DEPTH(PSUM_WORDS)
	) bank_A_sram(
		.clk_i(clk_i),
		.we(bank_A_we),
		.addr(bank_A_addr),
		.wdata(bank_A_wdata),
		.rdata(bank_A_rdata)
	);
	wire signed [ACTIVATION_WIDTH - 1:0] quant_direct_act;
	wire signed [SCALE_WIDTH - 1:0] lane_scale_m0 = quant_cfg[SCALE_WIDTH - 1:0];
	wire [SHIFT_WIDTH - 1:0] lane_shift_n = quant_cfg[(SCALE_WIDTH + SHIFT_WIDTH) - 1:SCALE_WIDTH];
	wire signed [ACTIVATION_WIDTH - 1:0] lane_zero_point = quant_cfg[QUANT_CFG_WIDTH - 1:SCALE_WIDTH + SHIFT_WIDTH];
	npu_requantizer_lane #(
		.PSUM_WIDTH(PSUM_WIDTH),
		.SCALE_WIDTH(SCALE_WIDTH),
		.ACTIVATION_WIDTH(ACTIVATION_WIDTH)
	) lane_inst(
		.clk_i(clk_i),
		.rst_n(rst_n),
		.psum_in(bank_A_rdata),
		.scale_m0(lane_scale_m0),
		.shift_n(lane_shift_n),
		.zero_point(lane_zero_point),
		.act_out(quant_direct_act)
	);
	function automatic [PSUM_ADDR_WIDTH - 1:0] sv2v_cast_EDE54;
		input reg [PSUM_ADDR_WIDTH - 1:0] inp;
		sv2v_cast_EDE54 = inp;
	endfunction
	wire [PSUM_ADDR_WIDTH - 1:0] internal_bank_B_addr = (psum_lut_en ? sv2v_cast_EDE54($unsigned(quant_direct_act)) : bank_B_addr);
	wire internal_bank_B_we = (psum_lut_en ? 1'b0 : bank_B_we);
	sram_bank #(
		.DATA_WIDTH(PSUM_WIDTH),
		.DEPTH(PSUM_WORDS)
	) bank_B_sram(
		.clk_i(clk_i),
		.we(internal_bank_B_we),
		.addr(internal_bank_B_addr),
		.wdata(bank_B_wdata),
		.rdata(bank_B_rdata)
	);
	assign act_out = (psum_lut_en ? bank_B_rdata[ACTIVATION_WIDTH - 1:0] : quant_direct_act);
endmodule
