module npu_seq_arbiter (
	mode_1x1_i,
	crossbar_sel_3x3_i,
	act_sram_we_3x3_i,
	act_sram_addr_3x3_i,
	crossbar_sel_1x1_i,
	act_sram_we_1x1_i,
	act_sram_addr_1x1_i,
	crossbar_sel_o,
	act_sram_we_o,
	act_sram_addr_o
);
	reg _sv2v_0;
	parameter signed [31:0] ARRAY_HEIGHT = 8;
	input wire mode_1x1_i;
	input wire [(ARRAY_HEIGHT * 4) - 1:0] crossbar_sel_3x3_i;
	input wire [5:0] act_sram_we_3x3_i;
	input wire [53:0] act_sram_addr_3x3_i;
	input wire [(ARRAY_HEIGHT * 4) - 1:0] crossbar_sel_1x1_i;
	input wire [7:0] act_sram_we_1x1_i;
	input wire [71:0] act_sram_addr_1x1_i;
	output reg [(ARRAY_HEIGHT * 4) - 1:0] crossbar_sel_o;
	output reg [7:0] act_sram_we_o;
	output reg [71:0] act_sram_addr_o;
	always @(*) begin
		if (_sv2v_0)
			;
		if (mode_1x1_i) begin
			crossbar_sel_o = crossbar_sel_1x1_i;
			act_sram_we_o = act_sram_we_1x1_i;
			act_sram_addr_o = act_sram_addr_1x1_i;
		end
		else begin
			crossbar_sel_o = crossbar_sel_3x3_i;
			act_sram_we_o = {2'b00, act_sram_we_3x3_i};
			act_sram_addr_o = {18'h00000, act_sram_addr_3x3_i};
		end
	end
	initial _sv2v_0 = 0;
endmodule
