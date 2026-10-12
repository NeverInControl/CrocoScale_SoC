module npu_crossbar (
	in_data,
	crossbar_sel,
	out_data
);
	reg _sv2v_0;
	parameter signed [31:0] ARRAY_HEIGHT = 8;
	parameter signed [31:0] ACTIVATION_WIDTH = 8;
	localparam signed [31:0] BANK_SEL_BITS = $clog2(ARRAY_HEIGHT);
	localparam signed [31:0] SEL_WIDTH = BANK_SEL_BITS + 1;
	input wire signed [(ARRAY_HEIGHT * ACTIVATION_WIDTH) - 1:0] in_data;
	input wire [(ARRAY_HEIGHT * SEL_WIDTH) - 1:0] crossbar_sel;
	output reg signed [(ARRAY_HEIGHT * ACTIVATION_WIDTH) - 1:0] out_data;
	genvar _gv_r_1;
	generate
		for (_gv_r_1 = 0; _gv_r_1 < ARRAY_HEIGHT; _gv_r_1 = _gv_r_1 + 1) begin : gen_row_mux
			localparam r = _gv_r_1;
			always @(*) begin
				if (_sv2v_0)
					;
				if (crossbar_sel[(r * SEL_WIDTH) + (SEL_WIDTH - 1)])
					out_data[r * ACTIVATION_WIDTH+:ACTIVATION_WIDTH] = 1'sb0;
				else
					out_data[r * ACTIVATION_WIDTH+:ACTIVATION_WIDTH] = in_data[crossbar_sel[(r * SEL_WIDTH) + (BANK_SEL_BITS - 1)-:BANK_SEL_BITS] * ACTIVATION_WIDTH+:ACTIVATION_WIDTH];
			end
		end
	endgenerate
	initial _sv2v_0 = 0;
endmodule
