module npu_top (
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
	reg _sv2v_0;
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
	output reg [NUM_PSUM_BANKS - 1:0] psum_sram_we;
	output reg [(NUM_PSUM_BANKS * PSUM_ADDR_WIDTH) - 1:0] psum_sram_addr;
	output reg signed [(NUM_PSUM_BANKS * PSUM_WIDTH) - 1:0] psum_sram_wdata;
	output wire signed [(ARRAY_WIDTH * ACTIVATION_WIDTH) - 1:0] out_act;
	reg [(ARRAY_HEIGHT * XBAR_SEL_WIDTH) - 1:0] crossbar_sel_pipe;
	always @(posedge clk_i or negedge rst_n)
		if (!rst_n) begin : sv2v_autoblock_1
			reg signed [31:0] r;
			for (r = 0; r < ARRAY_HEIGHT; r = r + 1)
				crossbar_sel_pipe[r * XBAR_SEL_WIDTH+:XBAR_SEL_WIDTH] <= {1'b1, {XBAR_SEL_WIDTH - 1 {1'b0}}};
		end
		else
			crossbar_sel_pipe <= crossbar_sel;
	wire signed [(ARRAY_HEIGHT * ACTIVATION_WIDTH) - 1:0] xbar_out;
	npu_crossbar #(
		.ARRAY_HEIGHT(ARRAY_HEIGHT),
		.ACTIVATION_WIDTH(ACTIVATION_WIDTH)
	) xbar_inst(
		.in_data(act_sram_rdata),
		.crossbar_sel(crossbar_sel_pipe),
		.out_data(xbar_out)
	);
	reg signed [(ARRAY_WIDTH * PSUM_WIDTH) - 1:0] array_psum_in;
	wire signed [(ARRAY_WIDTH * PSUM_WIDTH) - 1:0] array_psum_out;
	systolic_array #(
		.ARRAY_HEIGHT(ARRAY_HEIGHT),
		.ARRAY_WIDTH(ARRAY_WIDTH),
		.ACTIVATION_WIDTH(ACTIVATION_WIDTH),
		.WEIGHT_WIDTH(WEIGHT_WIDTH),
		.PSUM_WIDTH(PSUM_WIDTH),
		.WEIGHT_SPLIT(WEIGHT_SPLIT)
	) array_inst(
		.clk_i(clk_i),
		.rst_n(rst_n),
		.array_en(array_en),
		.act_in(xbar_out),
		.psum_in(array_psum_in),
		.psum_out(array_psum_out),
		.weight_shift_in(weight_shift_in),
		.weight_shift_en(weight_shift_en),
		.swap_weights(swap_weights)
	);
	wire [PSUM_ADDR_WIDTH - 1:0] psum_A_addr_col [0:ARRAY_WIDTH - 1];
	wire [PSUM_ADDR_WIDTH - 1:0] psum_B_addr_col [0:ARRAY_WIDTH - 1];
	wire bank_swap_col [0:ARRAY_WIDTH - 1];
	reg [PSUM_ADDR_WIDTH - 1:0] pipe_A_addr [1:ARRAY_WIDTH - 1];
	reg [PSUM_ADDR_WIDTH - 1:0] pipe_B_addr [1:ARRAY_WIDTH - 1];
	reg pipe_bank_swap [1:ARRAY_WIDTH - 1];
	assign psum_A_addr_col[0] = psum_A_addr;
	assign psum_B_addr_col[0] = psum_B_addr;
	assign bank_swap_col[0] = compute_bank_swap;
	always @(posedge clk_i or negedge rst_n)
		if (!rst_n) begin : sv2v_autoblock_2
			reg signed [31:0] col;
			for (col = 1; col < ARRAY_WIDTH; col = col + 1)
				begin
					pipe_A_addr[col] <= 1'sb0;
					pipe_B_addr[col] <= 1'sb0;
					pipe_bank_swap[col] <= 1'b0;
				end
		end
		else begin
			pipe_A_addr[1] <= psum_A_addr_col[0];
			pipe_B_addr[1] <= psum_B_addr_col[0];
			pipe_bank_swap[1] <= bank_swap_col[0];
			begin : sv2v_autoblock_3
				reg signed [31:0] col;
				for (col = 2; col < ARRAY_WIDTH; col = col + 1)
					begin
						pipe_A_addr[col] <= psum_A_addr_col[col - 1];
						pipe_B_addr[col] <= psum_B_addr_col[col - 1];
						pipe_bank_swap[col] <= bank_swap_col[col - 1];
					end
			end
		end
	genvar _gv_col_1;
	generate
		for (_gv_col_1 = 1; _gv_col_1 < ARRAY_WIDTH; _gv_col_1 = _gv_col_1 + 1) begin : gen_col_skew_mux
			localparam col = _gv_col_1;
			assign psum_A_addr_col[col] = (psum_skew_en ? pipe_A_addr[col] : psum_A_addr);
			assign psum_B_addr_col[col] = (psum_skew_en ? pipe_B_addr[col] : psum_B_addr);
			assign bank_swap_col[col] = (psum_skew_en ? pipe_bank_swap[col] : compute_bank_swap);
		end
	endgenerate
	wire signed [(ARRAY_WIDTH * ACTIVATION_WIDTH) - 1:0] quant_direct_act;
	always @(*) begin : blk_mem_routing
		reg signed [31:0] b_a;
		reg signed [31:0] b_b;
		if (_sv2v_0)
			;
		begin : sv2v_autoblock_4
			reg signed [31:0] i;
			for (i = 0; i < ARRAY_WIDTH; i = i + 1)
				begin
					b_a = i;
					b_b = i + ARRAY_WIDTH;
					array_psum_in[i * PSUM_WIDTH+:PSUM_WIDTH] = (!bank_swap_col[i] ? psum_sram_rdata[b_a * PSUM_WIDTH+:PSUM_WIDTH] : psum_sram_rdata[b_b * PSUM_WIDTH+:PSUM_WIDTH]);
					if (psum_systolic_en) begin
						if (!bank_swap_col[i]) begin
							psum_sram_addr[b_a * PSUM_ADDR_WIDTH+:PSUM_ADDR_WIDTH] = psum_A_addr_col[i];
							psum_sram_we[b_a] = psum_A_we[i];
							psum_sram_wdata[b_a * PSUM_WIDTH+:PSUM_WIDTH] = psum_A_wdata;
							psum_sram_addr[b_b * PSUM_ADDR_WIDTH+:PSUM_ADDR_WIDTH] = psum_B_addr_col[i];
							psum_sram_we[b_b] = psum_B_we[i];
							psum_sram_wdata[b_b * PSUM_WIDTH+:PSUM_WIDTH] = array_psum_out[i * PSUM_WIDTH+:PSUM_WIDTH];
						end
						else begin
							psum_sram_addr[b_b * PSUM_ADDR_WIDTH+:PSUM_ADDR_WIDTH] = psum_B_addr_col[i];
							psum_sram_we[b_b] = psum_B_we[i];
							psum_sram_wdata[b_b * PSUM_WIDTH+:PSUM_WIDTH] = psum_B_wdata;
							psum_sram_addr[b_a * PSUM_ADDR_WIDTH+:PSUM_ADDR_WIDTH] = psum_A_addr_col[i];
							psum_sram_we[b_a] = psum_A_we[i];
							psum_sram_wdata[b_a * PSUM_WIDTH+:PSUM_WIDTH] = array_psum_out[i * PSUM_WIDTH+:PSUM_WIDTH];
						end
					end
					else if (psum_lut_en) begin
						psum_sram_addr[b_a * PSUM_ADDR_WIDTH+:PSUM_ADDR_WIDTH] = psum_A_addr_col[i];
						psum_sram_we[b_a] = psum_A_we[i];
						psum_sram_wdata[b_a * PSUM_WIDTH+:PSUM_WIDTH] = psum_A_wdata;
						psum_sram_addr[b_b * PSUM_ADDR_WIDTH+:PSUM_ADDR_WIDTH] = $unsigned(quant_direct_act[i * ACTIVATION_WIDTH+:ACTIVATION_WIDTH]);
						psum_sram_we[b_b] = 1'b0;
						psum_sram_wdata[b_b * PSUM_WIDTH+:PSUM_WIDTH] = psum_B_wdata;
					end
					else begin
						psum_sram_addr[b_a * PSUM_ADDR_WIDTH+:PSUM_ADDR_WIDTH] = psum_A_addr_col[i];
						psum_sram_we[b_a] = psum_A_we[i];
						psum_sram_wdata[b_a * PSUM_WIDTH+:PSUM_WIDTH] = psum_A_wdata;
						psum_sram_addr[b_b * PSUM_ADDR_WIDTH+:PSUM_ADDR_WIDTH] = psum_B_addr_col[i];
						psum_sram_we[b_b] = psum_B_we[i];
						psum_sram_wdata[b_b * PSUM_WIDTH+:PSUM_WIDTH] = psum_B_wdata;
					end
				end
		end
	end
	wire signed [(ARRAY_WIDTH * PSUM_WIDTH) - 1:0] drain_psum_data;
	genvar _gv_ch_1;
	generate
		for (_gv_ch_1 = 0; _gv_ch_1 < ARRAY_WIDTH; _gv_ch_1 = _gv_ch_1 + 1) begin : gen_requant_source
			localparam ch = _gv_ch_1;
			assign drain_psum_data[ch * PSUM_WIDTH+:PSUM_WIDTH] = psum_sram_rdata[ch * PSUM_WIDTH+:PSUM_WIDTH];
		end
	endgenerate
	npu_requantizer #(
		.CHANNELS(ARRAY_WIDTH),
		.PSUM_WIDTH(PSUM_WIDTH),
		.SCALE_WIDTH(SCALE_WIDTH),
		.ACTIVATION_WIDTH(ACTIVATION_WIDTH),
		.ENABLE_LFSR(ENABLE_LFSR)
	) requant_inst(
		.clk_i(clk_i),
		.rst_n(rst_n),
		.psum_in(drain_psum_data),
		.quant_shift_in(quant_shift_in),
		.quant_shift_en(quant_shift_en),
		.stochastic_round_en(stochastic_round_en),
		.lfsr_data_out(lfsr_data_out),
		.act_out(quant_direct_act)
	);
	localparam signed [31:0] BANK_SEL_W = $clog2(2 * ARRAY_WIDTH);
	function automatic [BANK_SEL_W - 1:0] sv2v_cast_76F34;
		input reg [BANK_SEL_W - 1:0] inp;
		sv2v_cast_76F34 = inp;
	endfunction
	assign psum_A_rdata = psum_sram_rdata[sv2v_cast_76F34(psum_A_read_bank_sel) * PSUM_WIDTH+:PSUM_WIDTH];
	function automatic signed [BANK_SEL_W - 1:0] sv2v_cast_76F34_signed;
		input reg signed [BANK_SEL_W - 1:0] inp;
		sv2v_cast_76F34_signed = inp;
	endfunction
	assign psum_B_rdata = psum_sram_rdata[(sv2v_cast_76F34(psum_B_read_bank_sel) + sv2v_cast_76F34_signed(ARRAY_WIDTH)) * PSUM_WIDTH+:PSUM_WIDTH];
	generate
		for (_gv_ch_1 = 0; _gv_ch_1 < ARRAY_WIDTH; _gv_ch_1 = _gv_ch_1 + 1) begin : gen_act_out
			localparam ch = _gv_ch_1;
			assign out_act[ch * ACTIVATION_WIDTH+:ACTIVATION_WIDTH] = (psum_lut_en ? psum_sram_rdata[((ch + ARRAY_WIDTH) * PSUM_WIDTH) + (ACTIVATION_WIDTH - 1)-:ACTIVATION_WIDTH] : quant_direct_act[ch * ACTIVATION_WIDTH+:ACTIVATION_WIDTH]);
		end
	endgenerate
	initial _sv2v_0 = 0;
endmodule
