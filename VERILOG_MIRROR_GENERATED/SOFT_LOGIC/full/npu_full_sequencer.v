module npu_full_sequencer (
	clk_i,
	rst_n,
	start_i,
	start_drain_i,
	auto_drain_i,
	mode_1x1_i,
	lut_en_i,
	lut_load_done_i,
	drain_done_i,
	total_passes_i,
	busy_o,
	done_o,
	current_pass_o,
	cycle_in_pass_o,
	array_en_o,
	psum_systolic_en_o,
	psum_lut_en_o,
	psum_skew_en_o,
	compute_bank_swap_o,
	crossbar_sel_o,
	act_sram_addr_o,
	act_sram_we_o,
	weight_shift_en_o,
	swap_weights_o,
	weight_shift_step_o,
	psum_A_addr_o,
	psum_A_we_o,
	psum_B_addr_o,
	psum_B_we_o,
	preload_phase_o,
	preload_step_o,
	dma_channel_to_load_o,
	dma_bank_ptr_o,
	start_lut_load_o,
	lut_phase_o,
	drain_phase_o,
	drain_step_o
);
	parameter signed [31:0] ARRAY_HEIGHT = 8;
	parameter signed [31:0] ARRAY_WIDTH = 8;
	parameter signed [31:0] TILE_SIZE = 16;
	parameter signed [31:0] ACT_HALO_PAD = 1;
	parameter signed [31:0] CIN = 128;
	parameter signed [31:0] COUT = 32;
	input wire clk_i;
	input wire rst_n;
	input wire start_i;
	input wire start_drain_i;
	input wire auto_drain_i;
	input wire mode_1x1_i;
	input wire lut_en_i;
	input wire lut_load_done_i;
	input wire drain_done_i;
	input wire [7:0] total_passes_i;
	output wire busy_o;
	output wire done_o;
	output wire [7:0] current_pass_o;
	output wire [8:0] cycle_in_pass_o;
	output wire array_en_o;
	output wire psum_systolic_en_o;
	output wire psum_lut_en_o;
	output wire psum_skew_en_o;
	output wire compute_bank_swap_o;
	output wire [(ARRAY_HEIGHT * 4) - 1:0] crossbar_sel_o;
	output wire [(ARRAY_HEIGHT * 9) - 1:0] act_sram_addr_o;
	output wire [ARRAY_HEIGHT - 1:0] act_sram_we_o;
	output wire [1:0] weight_shift_en_o;
	output wire swap_weights_o;
	output wire [2:0] weight_shift_step_o;
	output wire [7:0] psum_A_addr_o;
	output wire [ARRAY_WIDTH - 1:0] psum_A_we_o;
	output wire [7:0] psum_B_addr_o;
	output wire [ARRAY_WIDTH - 1:0] psum_B_we_o;
	output wire preload_phase_o;
	output wire [7:0] preload_step_o;
	output wire signed [7:0] dma_channel_to_load_o;
	output wire [35:0] dma_bank_ptr_o;
	output wire start_lut_load_o;
	output wire lut_phase_o;
	output wire drain_phase_o;
	output wire [8:0] drain_step_o;
	localparam [2:0] SEQ_COMPUTE = 3'd2;
	wire [2:0] state;
	wire [7:0] pass_cnt;
	wire [8:0] k_cnt;
	wire [8:0] pass_len;
	wire preload_phase;
	wire [7:0] preload_cnt;
	wire drain_phase;
	wire [8:0] drain_cnt;
	wire swap_val;
	wire [(ARRAY_HEIGHT * 4) - 1:0] crossbar_sel_3x3;
	wire [5:0] act_sram_we_3x3;
	wire [53:0] act_sram_addr_3x3;
	wire [5:0] bank_read_used_3x3;
	wire [6:0] dma_ch_3x3;
	wire [5:0] dma_we_3x3;
	wire [53:0] dma_addr_3x3;
	wire [(ARRAY_HEIGHT * 4) - 1:0] crossbar_sel_1x1;
	wire [7:0] act_sram_we_1x1;
	wire [71:0] act_sram_addr_1x1;
	assign current_pass_o = pass_cnt;
	assign cycle_in_pass_o = k_cnt;
	assign preload_phase_o = preload_phase;
	assign preload_step_o = preload_cnt;
	assign drain_phase_o = drain_phase;
	assign drain_step_o = drain_cnt;
	function automatic [7:0] sv2v_cast_8;
		input reg [7:0] inp;
		sv2v_cast_8 = inp;
	endfunction
	assign dma_channel_to_load_o = (mode_1x1_i ? -8'sd1 : (state == SEQ_COMPUTE ? sv2v_cast_8(dma_ch_3x3) : -8'sd1));
	assign array_en_o = state == SEQ_COMPUTE;
	assign psum_systolic_en_o = state == SEQ_COMPUTE;
	assign psum_skew_en_o = state == SEQ_COMPUTE;
	assign compute_bank_swap_o = (state == SEQ_COMPUTE ? swap_val : 1'b0);
	npu_seq_fsm #(
		.ARRAY_HEIGHT(ARRAY_HEIGHT),
		.ARRAY_WIDTH(ARRAY_WIDTH)
	) fsm_inst(
		.clk_i(clk_i),
		.rst_n(rst_n),
		.start_i(start_i),
		.start_drain_i(start_drain_i),
		.auto_drain_i(auto_drain_i),
		.mode_1x1_i(mode_1x1_i),
		.lut_en_i(lut_en_i),
		.lut_load_done_i(lut_load_done_i),
		.drain_done_i(drain_done_i),
		.total_passes_i(total_passes_i),
		.state_o(state),
		.busy_o(busy_o),
		.done_o(done_o),
		.pass_cnt_o(pass_cnt),
		.k_cnt_o(k_cnt),
		.pass_len_o(pass_len),
		.preload_phase_o(preload_phase),
		.preload_cnt_o(preload_cnt),
		.start_lut_load_o(start_lut_load_o),
		.lut_phase_o(lut_phase_o),
		.drain_phase_o(drain_phase),
		.drain_cnt_o(drain_cnt)
	);
	npu_seq_weights weights_inst(
		.preload_phase_i(preload_phase),
		.preload_cnt_i(preload_cnt),
		.state_i(state),
		.pass_cnt_i(pass_cnt),
		.k_cnt_i(k_cnt),
		.pass_len_i(pass_len),
		.total_passes_i(total_passes_i),
		.weight_shift_en_o(weight_shift_en_o),
		.swap_weights_o(swap_weights_o),
		.weight_shift_step_o(weight_shift_step_o)
	);
	npu_seq_psum #(.ARRAY_WIDTH(ARRAY_WIDTH)) psum_inst(
		.state_i(state),
		.preload_phase_i(preload_phase),
		.preload_cnt_i(preload_cnt),
		.pass_cnt_i(pass_cnt),
		.k_cnt_i(k_cnt),
		.drain_phase_i(drain_phase),
		.drain_cnt_i(drain_cnt),
		.total_passes_i(total_passes_i),
		.lut_en_i(lut_en_i),
		.swap_val_o(swap_val),
		.psum_lut_en_o(psum_lut_en_o),
		.psum_A_addr_o(psum_A_addr_o),
		.psum_A_we_o(psum_A_we_o),
		.psum_B_addr_o(psum_B_addr_o),
		.psum_B_we_o(psum_B_we_o)
	);
	npu_seq_preload #(.CIN(CIN)) preload_inst(
		.clk_i(clk_i),
		.rst_n(rst_n),
		.state_i(state),
		.preload_cnt_i(preload_cnt),
		.pass_cnt_i(pass_cnt),
		.k_cnt_i(k_cnt),
		.pass_len_i(pass_len),
		.total_passes_i(total_passes_i),
		.bank_read_used_i(bank_read_used_3x3),
		.dma_channel_to_load_o(dma_ch_3x3),
		.dma_bank_ptr_o(dma_bank_ptr_o),
		.dma_we_o(dma_we_3x3),
		.dma_addr_o(dma_addr_3x3)
	);
	npu_seq_addr_3x3 #(
		.ARRAY_HEIGHT(ARRAY_HEIGHT),
		.CIN(CIN)
	) addr_3x3_inst(
		.clk_i(clk_i),
		.rst_n(rst_n),
		.state_i(state),
		.preload_phase_i(preload_phase),
		.preload_cnt_i(preload_cnt),
		.pass_cnt_i(pass_cnt),
		.k_cnt_i(k_cnt),
		.pass_len_i(pass_len),
		.total_passes_i(total_passes_i),
		.dma_we_i(dma_we_3x3),
		.dma_addr_i(dma_addr_3x3),
		.bank_read_used_o(bank_read_used_3x3),
		.crossbar_sel_o(crossbar_sel_3x3),
		.act_sram_we_o(act_sram_we_3x3),
		.act_sram_addr_o(act_sram_addr_3x3)
	);
	npu_seq_addr_1x1 #(.ARRAY_HEIGHT(ARRAY_HEIGHT)) addr_1x1_inst(
		.state_i(state),
		.preload_phase_i(preload_phase),
		.preload_cnt_i(preload_cnt),
		.pass_cnt_i(pass_cnt),
		.k_cnt_i(k_cnt),
		.total_passes_i(total_passes_i),
		.crossbar_sel_o(crossbar_sel_1x1),
		.act_sram_we_o(act_sram_we_1x1),
		.act_sram_addr_o(act_sram_addr_1x1)
	);
	npu_seq_arbiter #(.ARRAY_HEIGHT(ARRAY_HEIGHT)) arbiter_inst(
		.mode_1x1_i(mode_1x1_i),
		.crossbar_sel_3x3_i(crossbar_sel_3x3),
		.act_sram_we_3x3_i(act_sram_we_3x3),
		.act_sram_addr_3x3_i(act_sram_addr_3x3),
		.crossbar_sel_1x1_i(crossbar_sel_1x1),
		.act_sram_we_1x1_i(act_sram_we_1x1),
		.act_sram_addr_1x1_i(act_sram_addr_1x1),
		.crossbar_sel_o(crossbar_sel_o),
		.act_sram_we_o(act_sram_we_o),
		.act_sram_addr_o(act_sram_addr_o)
	);
endmodule
