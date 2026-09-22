module npu_seq_weights (
	preload_phase_i,
	preload_cnt_i,
	state_i,
	pass_cnt_i,
	k_cnt_i,
	pass_len_i,
	total_passes_i,
	weight_shift_en_o,
	swap_weights_o,
	weight_shift_step_o
);
	reg _sv2v_0;
	input wire preload_phase_i;
	input wire [7:0] preload_cnt_i;
	input wire [2:0] state_i;
	input wire [7:0] pass_cnt_i;
	input wire [8:0] k_cnt_i;
	input wire [8:0] pass_len_i;
	input wire [7:0] total_passes_i;
	output reg [1:0] weight_shift_en_o;
	output reg swap_weights_o;
	output reg [2:0] weight_shift_step_o;
	localparam [2:0] SEQ_COMPUTE = 3'd2;
	function automatic [2:0] sv2v_cast_3;
		input reg [2:0] inp;
		sv2v_cast_3 = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		weight_shift_en_o = 2'b00;
		swap_weights_o = 1'b0;
		weight_shift_step_o = 3'd0;
		if (preload_phase_i) begin
			if (preload_cnt_i < 8'd8) begin
				weight_shift_en_o = 2'b11;
				weight_shift_step_o = preload_cnt_i[2:0];
			end
			else if (preload_cnt_i == 8'd8)
				swap_weights_o = 1'b1;
		end
		else if (state_i == SEQ_COMPUTE) begin
			if ((((pass_cnt_i + 1'b1) < total_passes_i) && (k_cnt_i >= 9'd32)) && (k_cnt_i < 9'd40)) begin
				weight_shift_en_o = 2'b11;
				weight_shift_step_o = sv2v_cast_3(k_cnt_i - 9'd32);
			end
			else if (((pass_cnt_i + 1'b1) < total_passes_i) && (k_cnt_i == (pass_len_i - 1'b1)))
				swap_weights_o = 1'b1;
		end
	end
	initial _sv2v_0 = 0;
endmodule
