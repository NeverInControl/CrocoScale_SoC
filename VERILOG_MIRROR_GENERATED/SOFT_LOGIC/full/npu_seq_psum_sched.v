module npu_seq_psum_sched (
	state_i,
	preload_phase_i,
	preload_cnt_i,
	pass_cnt_i,
	k_cnt_i,
	drain_phase_i,
	drain_cnt_i,
	total_passes_i,
	lut_en_i,
	swap_val_o,
	psum_lut_en_o,
	psum_A_addr_o,
	psum_A_we_o,
	psum_B_addr_o,
	psum_B_we_o
);
	parameter signed [31:0] ARRAY_WIDTH = 8;
	input wire [2:0] state_i;
	input wire preload_phase_i;
	input wire [7:0] preload_cnt_i;
	input wire [7:0] pass_cnt_i;
	input wire [8:0] k_cnt_i;
	input wire drain_phase_i;
	input wire [8:0] drain_cnt_i;
	input wire [7:0] total_passes_i;
	input wire lut_en_i;
	output wire swap_val_o;
	output wire psum_lut_en_o;
	output wire [7:0] psum_A_addr_o;
	output wire [ARRAY_WIDTH - 1:0] psum_A_we_o;
	output wire [7:0] psum_B_addr_o;
	output wire [ARRAY_WIDTH - 1:0] psum_B_we_o;
	localparam [2:0] SEQ_PRELOAD = 3'd1;
	localparam [2:0] SEQ_COMPUTE = 3'd2;
	localparam [2:0] SEQ_LUT_LOAD = 3'd3;
	localparam [2:0] SEQ_DRAIN = 3'd4;
	wire swap_val = ((total_passes_i % 2) == 0 ? (pass_cnt_i[0] ? 1'b1 : 1'b0) : (pass_cnt_i[0] ? 1'b0 : 1'b1));
	wire hold_bias_addr = pass_cnt_i == 8'd0;
	assign swap_val_o = swap_val;
	assign psum_lut_en_o = (state_i == SEQ_DRAIN) && lut_en_i;
	function automatic [7:0] sv2v_cast_8;
		input reg [7:0] inp;
		sv2v_cast_8 = inp;
	endfunction
	assign psum_A_addr_o = (state_i == SEQ_DRAIN ? (drain_cnt_i < 9'd256 ? drain_cnt_i[7:0] : 8'h00) : (state_i == SEQ_COMPUTE ? (!swap_val ? (hold_bias_addr ? 8'h00 : (k_cnt_i < 9'd256 ? k_cnt_i[7:0] : 8'h00)) : ((k_cnt_i >= 9'd9) && ((k_cnt_i - 9'd9) < 9'd256) ? sv2v_cast_8(k_cnt_i - 9'd9) : 8'h00)) : 8'h00));
	assign psum_B_addr_o = (state_i == SEQ_COMPUTE ? (swap_val ? (hold_bias_addr ? 8'h00 : (k_cnt_i < 9'd256 ? k_cnt_i[7:0] : 8'h00)) : ((k_cnt_i >= 9'd9) && ((k_cnt_i - 9'd9) < 9'd256) ? sv2v_cast_8(k_cnt_i - 9'd9) : 8'h00)) : 8'h00);
	genvar _gv_gc_1;
	function automatic signed [7:0] sv2v_cast_8_signed;
		input reg signed [7:0] inp;
		sv2v_cast_8_signed = inp;
	endfunction
	function automatic signed [8:0] sv2v_cast_9_signed;
		input reg signed [8:0] inp;
		sv2v_cast_9_signed = inp;
	endfunction
	generate
		for (_gv_gc_1 = 0; _gv_gc_1 < ARRAY_WIDTH; _gv_gc_1 = _gv_gc_1 + 1) begin : gen_psum_we
			localparam gc = _gv_gc_1;
			assign psum_A_we_o[gc] = (((state_i == SEQ_PRELOAD) && !swap_val) && (preload_cnt_i == sv2v_cast_8_signed(gc)) ? 1'b1 : ((((state_i == SEQ_COMPUTE) && !swap_val) && (pass_cnt_i > 8'd0)) && (k_cnt_i < sv2v_cast_9_signed(gc)) ? 1'b1 : (((state_i == SEQ_COMPUTE) && swap_val) && ((k_cnt_i >= sv2v_cast_9_signed(9 + gc)) && ((k_cnt_i - sv2v_cast_9_signed(9 + gc)) < 9'd256)) ? 1'b1 : 1'b0)));
			assign psum_B_we_o[gc] = (((state_i == SEQ_PRELOAD) && swap_val) && (preload_cnt_i == sv2v_cast_8_signed(gc)) ? 1'b1 : ((((state_i == SEQ_COMPUTE) && swap_val) && (pass_cnt_i > 8'd0)) && (k_cnt_i < sv2v_cast_9_signed(gc)) ? 1'b1 : (((state_i == SEQ_COMPUTE) && !swap_val) && ((k_cnt_i >= sv2v_cast_9_signed(9 + gc)) && ((k_cnt_i - sv2v_cast_9_signed(9 + gc)) < 9'd256)) ? 1'b1 : 1'b0)));
		end
	endgenerate
endmodule
