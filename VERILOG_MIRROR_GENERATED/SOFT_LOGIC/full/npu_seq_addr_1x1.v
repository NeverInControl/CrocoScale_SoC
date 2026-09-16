module npu_seq_addr_1x1 (
	state_i,
	preload_phase_i,
	preload_cnt_i,
	pass_cnt_i,
	k_cnt_i,
	total_passes_i,
	crossbar_sel_o,
	act_sram_we_o,
	act_sram_addr_o
);
	reg _sv2v_0;
	parameter signed [31:0] ARRAY_HEIGHT = 8;
	input wire [2:0] state_i;
	input wire preload_phase_i;
	input wire [7:0] preload_cnt_i;
	input wire [7:0] pass_cnt_i;
	input wire [8:0] k_cnt_i;
	input wire [7:0] total_passes_i;
	output reg [(ARRAY_HEIGHT * 4) - 1:0] crossbar_sel_o;
	output reg [7:0] act_sram_we_o;
	output reg [71:0] act_sram_addr_o;
	localparam [2:0] SEQ_PRELOAD = 3'd1;
	localparam [2:0] SEQ_COMPUTE = 3'd2;
	wire [2:0] cur_bank_base = (pass_cnt_i[0] ? 3'd4 : 3'd0);
	wire [2:0] next_bank_base = (pass_cnt_i[0] ? 3'd0 : 3'd4);
	wire has_next_pass = (pass_cnt_i + 1'b1) < total_passes_i;
	function automatic signed [2:0] sv2v_cast_3_signed;
		input reg signed [2:0] inp;
		sv2v_cast_3_signed = inp;
	endfunction
	function automatic signed [8:0] sv2v_cast_9_signed;
		input reg signed [8:0] inp;
		sv2v_cast_9_signed = inp;
	endfunction
	function automatic [8:0] sv2v_cast_9;
		input reg [8:0] inp;
		sv2v_cast_9 = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		begin : sv2v_autoblock_1
			reg signed [31:0] r;
			for (r = 0; r < ARRAY_HEIGHT; r = r + 1)
				crossbar_sel_o[r * 4+:4] = 4'b1000;
		end
		act_sram_we_o = 8'h00;
		begin : sv2v_autoblock_2
			reg signed [31:0] b;
			for (b = 0; b < 8; b = b + 1)
				act_sram_addr_o[b * 9+:9] = 9'd0;
		end
		if (state_i == SEQ_PRELOAD) begin
			begin : sv2v_autoblock_3
				reg signed [31:0] b;
				for (b = 0; b < 4; b = b + 1)
					begin
						act_sram_we_o[b] = 1'b1;
						act_sram_addr_o[b * 9+:9] = {1'b0, preload_cnt_i};
					end
			end
			begin : sv2v_autoblock_4
				reg signed [31:0] b;
				for (b = 4; b < 8; b = b + 1)
					begin
						act_sram_we_o[b] = 1'b0;
						act_sram_addr_o[b * 9+:9] = 9'd0;
					end
			end
			begin : sv2v_autoblock_5
				reg signed [31:0] r;
				for (r = 0; r < ARRAY_HEIGHT; r = r + 1)
					crossbar_sel_o[r * 4+:4] = 4'b1000;
			end
		end
		else if (state_i == SEQ_COMPUTE) begin : sv2v_autoblock_6
			reg signed [31:0] b_cur;
			reg signed [31:0] b_nxt;
			begin : sv2v_autoblock_7
				reg signed [31:0] r;
				for (r = 0; r < 4; r = r + 1)
					begin
						b_cur = cur_bank_base + r;
						crossbar_sel_o[r * 4+:4] = {1'b0, sv2v_cast_3_signed(b_cur)};
						act_sram_we_o[b_cur] = 1'b0;
						if ((k_cnt_i >= sv2v_cast_9_signed(r)) && ((k_cnt_i - sv2v_cast_9_signed(r)) < 9'd256))
							act_sram_addr_o[b_cur * 9+:9] = sv2v_cast_9(k_cnt_i - sv2v_cast_9_signed(r));
						else
							act_sram_addr_o[b_cur * 9+:9] = 9'd0;
					end
			end
			begin : sv2v_autoblock_8
				reg signed [31:0] r;
				for (r = 4; r < 8; r = r + 1)
					crossbar_sel_o[r * 4+:4] = 4'b1000;
			end
			if (has_next_pass && (k_cnt_i < 9'd256)) begin : sv2v_autoblock_9
				reg signed [31:0] b;
				for (b = 0; b < 4; b = b + 1)
					begin
						b_nxt = next_bank_base + b;
						act_sram_we_o[b_nxt] = 1'b1;
						act_sram_addr_o[b_nxt * 9+:9] = {1'b0, k_cnt_i[7:0]};
					end
			end
			else begin : sv2v_autoblock_10
				reg signed [31:0] b;
				for (b = 0; b < 4; b = b + 1)
					begin
						b_nxt = next_bank_base + b;
						act_sram_we_o[b_nxt] = 1'b0;
						act_sram_addr_o[b_nxt * 9+:9] = 9'd0;
					end
			end
		end
	end
	initial _sv2v_0 = 0;
endmodule
