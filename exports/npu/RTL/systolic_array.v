module systolic_array (
	clk_i,
	rst_n,
	array_en,
	act_in,
	psum_in,
	psum_out,
	weight_shift_in,
	weight_shift_en,
	swap_weights
);
	parameter signed [31:0] ARRAY_HEIGHT = 8;
	parameter signed [31:0] ARRAY_WIDTH = 8;
	parameter signed [31:0] ACTIVATION_WIDTH = 8;
	parameter signed [31:0] WEIGHT_WIDTH = 8;
	parameter signed [31:0] PSUM_WIDTH = 32;
	parameter signed [31:0] WEIGHT_SPLIT = 2;
	localparam signed [31:0] ROWS_PER_SPLIT = ARRAY_HEIGHT / WEIGHT_SPLIT;
	input wire clk_i;
	input wire rst_n;
	input wire array_en;
	input wire signed [(ARRAY_HEIGHT * ACTIVATION_WIDTH) - 1:0] act_in;
	input wire signed [(ARRAY_WIDTH * PSUM_WIDTH) - 1:0] psum_in;
	output wire signed [(ARRAY_WIDTH * PSUM_WIDTH) - 1:0] psum_out;
	input wire signed [(ARRAY_HEIGHT * WEIGHT_WIDTH) - 1:0] weight_shift_in;
	input wire [WEIGHT_SPLIT - 1:0] weight_shift_en;
	input wire swap_weights;
	wire signed [ACTIVATION_WIDTH - 1:0] act_wire [0:ARRAY_HEIGHT - 1][0:ARRAY_WIDTH + 0];
	wire signed [PSUM_WIDTH - 1:0] psum_wire [0:ARRAY_HEIGHT + 0][0:ARRAY_WIDTH - 1];
	wire signed [WEIGHT_WIDTH - 1:0] w_chain [0:ARRAY_HEIGHT - 1][0:ARRAY_WIDTH + 0];
	reg swap_chain [0:ARRAY_HEIGHT - 1][0:ARRAY_WIDTH - 1];
	always @(posedge clk_i or negedge rst_n)
		if (!rst_n) begin : sv2v_autoblock_1
			reg signed [31:0] r_idx;
			for (r_idx = 0; r_idx < ARRAY_HEIGHT; r_idx = r_idx + 1)
				begin : sv2v_autoblock_2
					reg signed [31:0] c_idx;
					for (c_idx = 0; c_idx < ARRAY_WIDTH; c_idx = c_idx + 1)
						swap_chain[r_idx][c_idx] <= 1'b0;
				end
		end
		else begin : sv2v_autoblock_3
			reg signed [31:0] r_idx;
			for (r_idx = 0; r_idx < ARRAY_HEIGHT; r_idx = r_idx + 1)
				begin : sv2v_autoblock_4
					reg signed [31:0] c_idx;
					for (c_idx = 0; c_idx < ARRAY_WIDTH; c_idx = c_idx + 1)
						if ((r_idx == 0) && (c_idx == 0))
							swap_chain[0][0] <= swap_weights;
						else if (c_idx == 0)
							swap_chain[r_idx][0] <= swap_chain[r_idx - 1][0];
						else
							swap_chain[r_idx][c_idx] <= swap_chain[r_idx][c_idx - 1];
				end
		end
	genvar _gv_r_1;
	genvar _gv_c_1;
	generate
		for (_gv_r_1 = 0; _gv_r_1 < ARRAY_HEIGHT; _gv_r_1 = _gv_r_1 + 1) begin : gen_row_io
			localparam r = _gv_r_1;
			assign act_wire[r][0] = act_in[r * ACTIVATION_WIDTH+:ACTIVATION_WIDTH];
			assign w_chain[r][0] = weight_shift_in[r * WEIGHT_WIDTH+:WEIGHT_WIDTH];
		end
		for (_gv_c_1 = 0; _gv_c_1 < ARRAY_WIDTH; _gv_c_1 = _gv_c_1 + 1) begin : gen_col_io
			localparam c = _gv_c_1;
			assign psum_wire[0][c] = psum_in[c * PSUM_WIDTH+:PSUM_WIDTH];
			assign psum_out[c * PSUM_WIDTH+:PSUM_WIDTH] = psum_wire[ARRAY_HEIGHT][c];
		end
		for (_gv_r_1 = 0; _gv_r_1 < ARRAY_HEIGHT; _gv_r_1 = _gv_r_1 + 1) begin : gen_row
			localparam r = _gv_r_1;
			localparam signed [31:0] BLOCK_IDX = r / ROWS_PER_SPLIT;
			for (_gv_c_1 = 0; _gv_c_1 < ARRAY_WIDTH; _gv_c_1 = _gv_c_1 + 1) begin : gen_col
				localparam c = _gv_c_1;
				pe #(
					.ACTIVATION_WIDTH(ACTIVATION_WIDTH),
					.WEIGHT_WIDTH(WEIGHT_WIDTH),
					.PSUM_WIDTH(PSUM_WIDTH)
				) pe_inst(
					.clk_i(clk_i),
					.rst_n(rst_n),
					.array_en(array_en),
					.act_in(act_wire[r][c]),
					.psum_in(psum_wire[r][c]),
					.act_out(act_wire[r][c + 1]),
					.psum_out(psum_wire[r + 1][c]),
					.weight_shift_in(w_chain[r][c]),
					.weight_shift_out(w_chain[r][c + 1]),
					.weight_shift_en(weight_shift_en[BLOCK_IDX]),
					.swap_weights(swap_chain[r][c])
				);
			end
		end
	endgenerate
endmodule
