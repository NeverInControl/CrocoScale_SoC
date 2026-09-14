module npu_core_macro (
	clk_i,
	rst_n,
	array_en,
	psum_systolic_en,
	psum_lut_en,
	crossbar_sel,
	weight_shift_in,
	weight_shift_en,
	swap_weights,
	quant_shift_in,
	quant_shift_en,
	stochastic_round_en,
	lfsr_data_out,
	psum_skew_en,
	compute_bank_swap,
	psum_A_addr,
	psum_A_we,
	psum_A_wdata,
	psum_A_read_bank_sel,
	psum_A_rdata,
	psum_B_addr,
	psum_B_we,
	psum_B_wdata,
	psum_B_read_bank_sel,
	psum_B_rdata,
	act_sram_rdata,
	psum_sram_rdata,
	psum_sram_we,
	psum_sram_addr,
	psum_sram_wdata,
	out_act
);
	parameter signed [31:0] ARRAY_HEIGHT = 8;
	parameter signed [31:0] ARRAY_WIDTH = 8;
	parameter signed [31:0] TILE_SIZE = 16;
	parameter signed [31:0] ACT_HALO_PAD = 2;
	parameter signed [31:0] ACTIVATION_WIDTH = 8;
	parameter signed [31:0] WEIGHT_WIDTH = 8;
	parameter signed [31:0] PSUM_WIDTH = 32;
	parameter signed [31:0] SCALE_WIDTH = 16;
	parameter [0:0] ENABLE_LFSR = 0;
	parameter signed [31:0] WEIGHT_SPLIT = 2;
	localparam signed [31:0] PSUM_WORDS = TILE_SIZE * TILE_SIZE;
	localparam signed [31:0] ACT_WORDS = (TILE_SIZE * TILE_SIZE) * ACT_HALO_PAD;
	localparam signed [31:0] PSUM_ADDR_WIDTH = $clog2(PSUM_WORDS);
	localparam signed [31:0] ACT_ADDR_WIDTH = $clog2(ACT_WORDS);
	localparam signed [31:0] NUM_ACT_BANKS = ARRAY_HEIGHT;
	localparam signed [31:0] NUM_PSUM_BANKS = ARRAY_WIDTH * 2;
	localparam signed [31:0] XBAR_SEL_WIDTH = $clog2(ARRAY_HEIGHT) + 1;
	localparam signed [31:0] PROD_WIDTH = PSUM_WIDTH + SCALE_WIDTH;
	localparam signed [31:0] SHIFT_WIDTH = $clog2(PROD_WIDTH);
	localparam signed [31:0] QUANT_CFG_WIDTH = (SCALE_WIDTH + SHIFT_WIDTH) + ACTIVATION_WIDTH;
	input wire clk_i;
	input wire rst_n;
	input wire array_en;
	input wire psum_systolic_en;
	input wire psum_lut_en;
	input wire [(ARRAY_HEIGHT * XBAR_SEL_WIDTH) - 1:0] crossbar_sel;
	input wire signed [(ARRAY_HEIGHT * WEIGHT_WIDTH) - 1:0] weight_shift_in;
	input wire [WEIGHT_SPLIT - 1:0] weight_shift_en;
	input wire swap_weights;
	input wire [QUANT_CFG_WIDTH - 1:0] quant_shift_in;
	input wire quant_shift_en;
	input wire stochastic_round_en;
	output wire [SCALE_WIDTH - 1:0] lfsr_data_out;
	input wire psum_skew_en;
	input wire compute_bank_swap;
	input wire [PSUM_ADDR_WIDTH - 1:0] psum_A_addr;
	input wire [ARRAY_WIDTH - 1:0] psum_A_we;
	input wire signed [PSUM_WIDTH - 1:0] psum_A_wdata;
	input wire [$clog2(ARRAY_WIDTH) - 1:0] psum_A_read_bank_sel;
	output wire signed [PSUM_WIDTH - 1:0] psum_A_rdata;
	input wire [PSUM_ADDR_WIDTH - 1:0] psum_B_addr;
	input wire [ARRAY_WIDTH - 1:0] psum_B_we;
	input wire signed [PSUM_WIDTH - 1:0] psum_B_wdata;
	input wire [$clog2(ARRAY_WIDTH) - 1:0] psum_B_read_bank_sel;
	output wire signed [PSUM_WIDTH - 1:0] psum_B_rdata;
	input wire signed [(NUM_ACT_BANKS * ACTIVATION_WIDTH) - 1:0] act_sram_rdata;
	input wire signed [(NUM_PSUM_BANKS * PSUM_WIDTH) - 1:0] psum_sram_rdata;
	output wire [NUM_PSUM_BANKS - 1:0] psum_sram_we;
	output wire [(NUM_PSUM_BANKS * PSUM_ADDR_WIDTH) - 1:0] psum_sram_addr;
	output wire signed [(NUM_PSUM_BANKS * PSUM_WIDTH) - 1:0] psum_sram_wdata;
	output wire signed [(ARRAY_WIDTH * ACTIVATION_WIDTH) - 1:0] out_act;
	assign lfsr_data_out = 1'sb0;
	assign psum_A_rdata = 1'sb0;
	assign psum_B_rdata = 1'sb0;
	assign psum_sram_we = 1'sb0;
	assign psum_sram_addr = 1'sb0;
	assign psum_sram_wdata = 1'sb0;
	assign out_act = 1'sb0;
endmodule
