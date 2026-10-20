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
	output reg signed [DATA_WIDTH - 1:0] rdata;
	reg signed [DATA_WIDTH - 1:0] mem [0:DEPTH - 1];
	always @(posedge clk_i) begin
		if (we)
			mem[addr] <= wdata;
		rdata <= mem[addr];
	end
endmodule
