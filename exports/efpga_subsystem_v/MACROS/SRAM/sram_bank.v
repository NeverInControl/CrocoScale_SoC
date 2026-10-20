module sram_bank (
	clk_i,
	we,
	addr,
	wdata,
	rdata
);
	parameter signed [31:0] DATA_WIDTH = 8;
	parameter signed [31:0] DEPTH = 512;
	parameter signed [31:0] ADDR_WIDTH = $clog2(DEPTH);
	input wire clk_i;
	input wire we;
	input wire [ADDR_WIDTH - 1:0] addr;
	input wire signed [DATA_WIDTH - 1:0] wdata;
	output wire signed [DATA_WIDTH - 1:0] rdata;
	wire A_MEN = 1'b1;
	wire A_WEN = we;
	wire A_REN = ~we;
	wire A_DLY = 1'b1;
	generate
		if ((DEPTH == 512) && (DATA_WIDTH == 8)) begin : gen_ihp_512x8
			RM_IHPSG13_1P_512x8_c3_bm_bist u_sram_512x8(
				.A_CLK(clk_i),
				.A_MEN(A_MEN),
				.A_WEN(A_WEN),
				.A_REN(A_REN),
				.A_ADDR(addr[8:0]),
				.A_DIN(wdata[7:0]),
				.A_DLY(A_DLY),
				.A_DOUT(rdata[7:0]),
				.A_BM(8'hff),
				.A_BIST_CLK(1'b0),
				.A_BIST_EN(1'b0),
				.A_BIST_MEN(1'b0),
				.A_BIST_WEN(1'b0),
				.A_BIST_REN(1'b0),
				.A_BIST_ADDR(9'd0),
				.A_BIST_DIN(8'd0),
				.A_BIST_BM(8'd0)
			);
		end
		else if ((DEPTH == 256) && (DATA_WIDTH == 32)) begin : gen_ihp_256x32
			RM_IHPSG13_1P_256x32_c2_bm_bist u_sram_256x32(
				.A_CLK(clk_i),
				.A_MEN(A_MEN),
				.A_WEN(A_WEN),
				.A_REN(A_REN),
				.A_ADDR(addr[7:0]),
				.A_DIN(wdata[31:0]),
				.A_DLY(A_DLY),
				.A_DOUT(rdata[31:0]),
				.A_BM(32'hffffffff),
				.A_BIST_CLK(1'b0),
				.A_BIST_EN(1'b0),
				.A_BIST_MEN(1'b0),
				.A_BIST_WEN(1'b0),
				.A_BIST_REN(1'b0),
				.A_BIST_ADDR(8'd0),
				.A_BIST_DIN(32'd0),
				.A_BIST_BM(32'd0)
			);
		end
		else begin : gen_unsupported_config
			assign rdata = {DATA_WIDTH {1'b0}};
		end
	endgenerate
endmodule
