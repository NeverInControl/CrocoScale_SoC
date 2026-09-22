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
	wire has_next_pass = (pass_cnt_i + 1'b1) < total_passes_i;
	wire ping = pass_cnt_i[0];
	function automatic signed [1:0] sv2v_cast_2_signed;
		input reg signed [1:0] inp;
		sv2v_cast_2_signed = inp;
	endfunction
	function automatic signed [8:0] sv2v_cast_9_signed;
		input reg signed [8:0] inp;
		sv2v_cast_9_signed = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		begin : sv2v_autoblock_1
			reg signed [31:0] r;
			for (r = 0; r < 4; r = r + 1)
				crossbar_sel_o[r * 4+:4] = (state_i == SEQ_COMPUTE ? {1'b0, ping, sv2v_cast_2_signed(r)} : 4'b1000);
		end
		begin : sv2v_autoblock_2
			reg signed [31:0] r;
			for (r = 4; r < 8; r = r + 1)
				crossbar_sel_o[r * 4+:4] = 4'b1000;
		end
		begin : sv2v_autoblock_3
			reg signed [31:0] r;
			for (r = 0; r < 4; r = r + 1)
				begin : sv2v_autoblock_4
					reg [8:0] m_p;
					reg m_p_valid;
					reg [8:0] compute_addr;
					reg write_active;
					m_p = k_cnt_i - sv2v_cast_9_signed(r);
					m_p_valid = (k_cnt_i >= sv2v_cast_9_signed(r)) && !m_p[8];
					compute_addr = (m_p_valid ? m_p : 9'd0);
					write_active = has_next_pass && !k_cnt_i[8];
					if (state_i == SEQ_PRELOAD) begin
						act_sram_we_o[r] = 1'b1;
						act_sram_addr_o[r * 9+:9] = {1'b0, preload_cnt_i};
						act_sram_we_o[r + 4] = 1'b0;
						act_sram_addr_o[(r + 4) * 9+:9] = 9'd0;
					end
					else if (state_i == SEQ_COMPUTE) begin
						if (!ping) begin
							act_sram_we_o[r] = 1'b0;
							act_sram_addr_o[r * 9+:9] = compute_addr;
							act_sram_we_o[r + 4] = write_active;
							act_sram_addr_o[(r + 4) * 9+:9] = {1'b0, k_cnt_i[7:0]};
						end
						else begin
							act_sram_we_o[r] = write_active;
							act_sram_addr_o[r * 9+:9] = {1'b0, k_cnt_i[7:0]};
							act_sram_we_o[r + 4] = 1'b0;
							act_sram_addr_o[(r + 4) * 9+:9] = compute_addr;
						end
					end
					else begin
						act_sram_we_o[r] = 1'b0;
						act_sram_addr_o[r * 9+:9] = 9'd0;
						act_sram_we_o[r + 4] = 1'b0;
						act_sram_addr_o[(r + 4) * 9+:9] = 9'd0;
					end
				end
		end
	end
	initial _sv2v_0 = 0;
endmodule
