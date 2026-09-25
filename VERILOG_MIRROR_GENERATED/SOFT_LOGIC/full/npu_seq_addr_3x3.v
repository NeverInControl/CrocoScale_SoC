module npu_seq_addr_3x3 (
	clk_i,
	rst_n,
	state_i,
	preload_phase_i,
	preload_cnt_i,
	pass_cnt_i,
	k_cnt_i,
	pass_len_i,
	total_passes_i,
	dma_we_i,
	dma_addr_i,
	bank_read_used_o,
	crossbar_sel_o,
	act_sram_we_o,
	act_sram_addr_o
);
	reg _sv2v_0;
	parameter signed [31:0] ARRAY_HEIGHT = 8;
	parameter signed [31:0] CIN = 128;
	input wire clk_i;
	input wire rst_n;
	input wire [2:0] state_i;
	input wire preload_phase_i;
	input wire [7:0] preload_cnt_i;
	input wire [7:0] pass_cnt_i;
	input wire [8:0] k_cnt_i;
	input wire [8:0] pass_len_i;
	input wire [7:0] total_passes_i;
	input wire [5:0] dma_we_i;
	input wire [53:0] dma_addr_i;
	output wire [5:0] bank_read_used_o;
	output reg [(ARRAY_HEIGHT * 4) - 1:0] crossbar_sel_o;
	output wire [5:0] act_sram_we_o;
	output wire [53:0] act_sram_addr_o;
	localparam [2:0] SEQ_IDLE = 3'd0;
	localparam [2:0] SEQ_PRELOAD = 3'd1;
	localparam [2:0] SEQ_COMPUTE = 3'd2;
	localparam signed [31:0] K_TOTAL = CIN * 9;
	function automatic [7:0] get_ly_data;
		input [4:0] ly;
		case (ly)
			5'd0: get_ly_data = 8'h00;
			5'd1: get_ly_data = 8'h40;
			5'd2: get_ly_data = 8'h80;
			5'd3: get_ly_data = 8'h09;
			5'd4: get_ly_data = 8'h49;
			5'd5: get_ly_data = 8'h89;
			5'd6: get_ly_data = 8'h12;
			5'd7: get_ly_data = 8'h52;
			5'd8: get_ly_data = 8'h92;
			5'd9: get_ly_data = 8'h1b;
			5'd10: get_ly_data = 8'h5b;
			5'd11: get_ly_data = 8'h9b;
			5'd12: get_ly_data = 8'h24;
			5'd13: get_ly_data = 8'h64;
			5'd14: get_ly_data = 8'ha4;
			5'd15: get_ly_data = 8'h2d;
			5'd16: get_ly_data = 8'h6d;
			5'd17: get_ly_data = 8'had;
			default: get_ly_data = 8'd0;
		endcase
	endfunction
	function automatic [3:0] get_tap_data;
		input [3:0] tap;
		case (tap)
			4'd0: get_tap_data = 4'h0;
			4'd1: get_tap_data = 4'h1;
			4'd2: get_tap_data = 4'h2;
			4'd3: get_tap_data = 4'h4;
			4'd4: get_tap_data = 4'h5;
			4'd5: get_tap_data = 4'h6;
			4'd6: get_tap_data = 4'h8;
			4'd7: get_tap_data = 4'h9;
			4'd8: get_tap_data = 4'ha;
			default: get_tap_data = 4'd0;
		endcase
	endfunction
	reg [6:0] cin_0;
	reg [3:0] tap_0;
	reg [ARRAY_HEIGHT - 1:0] row_active;
	reg [(ARRAY_HEIGHT * 3) - 1:0] row_target_bank;
	reg [(ARRAY_HEIGHT * 9) - 1:0] row_target_addr;
	function automatic signed [8:0] sv2v_cast_9_signed;
		input reg signed [8:0] inp;
		sv2v_cast_9_signed = inp;
	endfunction
	function automatic signed [10:0] sv2v_cast_11_signed;
		input reg signed [10:0] inp;
		sv2v_cast_11_signed = inp;
	endfunction
	function automatic signed [4:0] sv2v_cast_5_signed;
		input reg signed [4:0] inp;
		sv2v_cast_5_signed = inp;
	endfunction
	function automatic [3:0] sv2v_cast_4;
		input reg [3:0] inp;
		sv2v_cast_4 = inp;
	endfunction
	function automatic [4:0] sv2v_cast_5;
		input reg [4:0] inp;
		sv2v_cast_5 = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		begin : sv2v_autoblock_1
			reg signed [31:0] r;
			for (r = 0; r < ARRAY_HEIGHT; r = r + 1)
				begin : sv2v_autoblock_2
					reg [8:0] m_p;
					reg m_p_valid;
					reg [10:0] g_idx;
					reg [4:0] tap_sum;
					reg [3:0] tap_curr;
					reg [6:0] cin_curr;
					reg [3:0] tap_data;
					reg [1:0] ky_curr;
					reg [1:0] kx_curr;
					reg [3:0] out_y;
					reg [3:0] out_x;
					reg [4:0] target_ly;
					reg [4:0] target_lx;
					reg h;
					reg [3:0] x_off;
					reg [7:0] ly_data;
					reg [1:0] ly_mod;
					reg [5:0] ly_mul9;
					reg [2:0] bank;
					reg [5:0] page_addr;
					m_p = k_cnt_i - sv2v_cast_9_signed(r);
					m_p_valid = (k_cnt_i >= sv2v_cast_9_signed(r)) && !m_p[8];
					g_idx = {pass_cnt_i, 3'b000} + sv2v_cast_11_signed(r);
					tap_sum = {1'b0, tap_0} + sv2v_cast_5_signed(r);
					tap_curr = (tap_sum >= 5'd9 ? sv2v_cast_4(tap_sum - 5'd9) : tap_sum[3:0]);
					cin_curr = (tap_sum >= 5'd9 ? cin_0 + 7'd1 : cin_0);
					tap_data = get_tap_data(tap_curr);
					ky_curr = tap_data[3:2];
					kx_curr = tap_data[1:0];
					out_y = m_p[7:4];
					out_x = m_p[3:0];
					target_ly = sv2v_cast_5({1'b0, out_y} + {3'b000, ky_curr});
					target_lx = sv2v_cast_5({1'b0, out_x} + {3'b000, kx_curr});
					h = target_lx >= 5'd9;
					x_off = (h ? target_lx[3:0] - 4'd9 : target_lx[3:0]);
					ly_data = get_ly_data(target_ly);
					ly_mod = ly_data[7:6];
					ly_mul9 = ly_data[5:0];
					bank = {ly_mod, h};
					page_addr = ly_mul9 + {2'b00, x_off};
					row_active[r] = ((state_i == SEQ_COMPUTE) && m_p_valid) && (g_idx < sv2v_cast_11_signed(K_TOTAL));
					row_target_bank[r * 3+:3] = bank;
					row_target_addr[r * 9+:9] = {cin_curr[2:0], page_addr};
					crossbar_sel_o[r * 4+:4] = (row_active[r] ? {1'b0, bank} : 4'b1000);
				end
		end
	end
	reg [5:0] bank_read_used;
	reg [53:0] bank_read_addr;
	function automatic signed [2:0] sv2v_cast_3_signed;
		input reg signed [2:0] inp;
		sv2v_cast_3_signed = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		begin : sv2v_autoblock_3
			reg signed [31:0] b;
			for (b = 0; b < 6; b = b + 1)
				begin : sv2v_autoblock_4
					reg [ARRAY_HEIGHT - 1:0] match;
					reg [8:0] addr_accum;
					begin : sv2v_autoblock_5
						reg signed [31:0] r;
						for (r = 0; r < ARRAY_HEIGHT; r = r + 1)
							match[r] = row_active[r] && (row_target_bank[r * 3+:3] == sv2v_cast_3_signed(b));
					end
					bank_read_used[b] = |match;
					addr_accum = 9'd0;
					begin : sv2v_autoblock_6
						reg signed [31:0] r;
						for (r = 0; r < ARRAY_HEIGHT; r = r + 1)
							addr_accum = addr_accum | (match[r] ? row_target_addr[r * 9+:9] : 9'd0);
					end
					bank_read_addr[b * 9+:9] = addr_accum;
				end
		end
	end
	assign bank_read_used_o = bank_read_used;
	genvar _gv_gb_1;
	generate
		for (_gv_gb_1 = 0; _gv_gb_1 < 6; _gv_gb_1 = _gv_gb_1 + 1) begin : gen_bank_mem
			localparam gb = _gv_gb_1;
			assign act_sram_we_o[gb] = (state_i == SEQ_PRELOAD ? 1'b1 : dma_we_i[gb]);
			assign act_sram_addr_o[gb * 9+:9] = (state_i == SEQ_PRELOAD ? {3'b000, preload_cnt_i[5:0]} : ((state_i == SEQ_COMPUTE) && bank_read_used[gb] ? bank_read_addr[gb * 9+:9] : dma_addr_i[gb * 9+:9]));
		end
	endgenerate
	always @(posedge clk_i)
		if (!rst_n) begin
			cin_0 <= 7'd0;
			tap_0 <= 4'd0;
		end
		else if ((state_i == SEQ_IDLE) || ((state_i == SEQ_PRELOAD) && (preload_cnt_i == 8'd53))) begin
			cin_0 <= 7'd0;
			tap_0 <= 4'd0;
		end
		else if (state_i == SEQ_COMPUTE) begin
			if (k_cnt_i == (pass_len_i - 1'b1)) begin
				if ((pass_cnt_i + 1'b1) < total_passes_i) begin
					tap_0 <= (tap_0 == 4'd0 ? 4'd8 : tap_0 - 4'd1);
					cin_0 <= (tap_0 == 4'd0 ? cin_0 : cin_0 + 7'd1);
				end
			end
		end
	initial _sv2v_0 = 0;
endmodule
