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
	crossbar_sel_o,
	act_sram_we_o,
	act_sram_addr_o,
	dma_channel_to_load_o,
	dma_bank_ptr_o
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
	output reg [(ARRAY_HEIGHT * 4) - 1:0] crossbar_sel_o;
	output wire [5:0] act_sram_we_o;
	output wire [53:0] act_sram_addr_o;
	output wire [6:0] dma_channel_to_load_o;
	output wire [35:0] dma_bank_ptr_o;
	localparam [2:0] SEQ_IDLE = 3'd0;
	localparam [2:0] SEQ_PRELOAD = 3'd1;
	localparam [2:0] SEQ_COMPUTE = 3'd2;
	localparam signed [31:0] K_TOTAL = CIN * 9;
	reg [5:0] dma_bank_ptr [0:5];
	reg [6:0] dma_channel_reg;
	assign dma_channel_to_load_o = dma_channel_reg;
	genvar _gv_gb_1;
	generate
		for (_gv_gb_1 = 0; _gv_gb_1 < 6; _gv_gb_1 = _gv_gb_1 + 1) begin : gen_bank_ptr
			localparam gb = _gv_gb_1;
			assign dma_bank_ptr_o[gb * 6+:6] = dma_bank_ptr[gb];
		end
	endgenerate
	function automatic [2:0] sv2v_cast_3;
		input reg [2:0] inp;
		sv2v_cast_3 = inp;
	endfunction
	function automatic [1:0] sv2v_cast_2;
		input reg [1:0] inp;
		sv2v_cast_2 = inp;
	endfunction
	function automatic [11:0] calc_sram_loc;
		input [6:0] cin_idx;
		input [4:0] ly;
		input [4:0] lx;
		reg h;
		reg [3:0] x_off;
		reg [2:0] ly_div;
		reg [1:0] ly_mod;
		reg [2:0] bank;
		reg [8:0] addr;
		begin
			h = lx >= 5'd9;
			x_off = (h ? lx[3:0] - 4'd9 : lx[3:0]);
			ly_div = sv2v_cast_3(ly / 3);
			ly_mod = sv2v_cast_2(ly % 3);
			bank = {1'b0, ly_mod, h};
			addr = ({cin_idx[2:0], 6'b000000} + (ly_div * 4'd9)) + {5'b00000, x_off};
			calc_sram_loc = {bank, addr};
		end
	endfunction
	reg [ARRAY_HEIGHT - 1:0] row_active;
	reg [(ARRAY_HEIGHT * 3) - 1:0] row_target_bank;
	reg [(ARRAY_HEIGHT * 9) - 1:0] row_target_addr;
	function automatic signed [4:0] sv2v_cast_5_signed;
		input reg signed [4:0] inp;
		sv2v_cast_5_signed = inp;
	endfunction
	function automatic signed [6:0] sv2v_cast_7_signed;
		input reg signed [6:0] inp;
		sv2v_cast_7_signed = inp;
	endfunction
	function automatic signed [31:0] sv2v_cast_32_signed;
		input reg signed [31:0] inp;
		sv2v_cast_32_signed = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		begin : sv2v_autoblock_1
			reg signed [31:0] r;
			for (r = 0; r < ARRAY_HEIGHT; r = r + 1)
				begin : sv2v_autoblock_2
					reg signed [31:0] m_p;
					reg signed [31:0] g_idx;
					m_p = sv2v_cast_32_signed(k_cnt_i) - r;
					g_idx = (sv2v_cast_32_signed(pass_cnt_i) * 8) + r;
					if ((((state_i == SEQ_COMPUTE) && (m_p >= 0)) && (m_p < 256)) && (g_idx < K_TOTAL)) begin : sv2v_autoblock_3
						reg signed [31:0] cin_curr;
						reg signed [31:0] tap_curr;
						reg signed [31:0] ky_curr;
						reg signed [31:0] kx_curr;
						reg signed [31:0] out_y;
						reg signed [31:0] out_x;
						reg [4:0] target_ly;
						reg [4:0] target_lx;
						reg [11:0] loc;
						cin_curr = g_idx / 9;
						tap_curr = g_idx % 9;
						ky_curr = tap_curr / 3;
						kx_curr = tap_curr % 3;
						out_y = m_p / 16;
						out_x = m_p % 16;
						target_ly = sv2v_cast_5_signed(out_y + ky_curr);
						target_lx = sv2v_cast_5_signed(out_x + kx_curr);
						loc = calc_sram_loc(sv2v_cast_7_signed(cin_curr), target_ly, target_lx);
						row_active[r] = 1'b1;
						row_target_bank[r * 3+:3] = loc[11:9];
						row_target_addr[r * 9+:9] = loc[8:0];
						crossbar_sel_o[r * 4+:4] = {1'b0, loc[11:9]};
					end
					else begin
						row_active[r] = 1'b0;
						row_target_bank[r * 3+:3] = 3'd0;
						row_target_addr[r * 9+:9] = 9'd0;
						crossbar_sel_o[r * 4+:4] = 4'b1000;
					end
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
		begin : sv2v_autoblock_4
			reg signed [31:0] b;
			for (b = 0; b < 6; b = b + 1)
				begin
					bank_read_used[b] = 1'b0;
					bank_read_addr[b * 9+:9] = 9'd0;
					begin : sv2v_autoblock_5
						reg signed [31:0] r;
						for (r = 0; r < ARRAY_HEIGHT; r = r + 1)
							if (row_active[r] && (row_target_bank[r * 3+:3] == sv2v_cast_3_signed(b))) begin
								bank_read_used[b] = 1'b1;
								bank_read_addr[b * 9+:9] = row_target_addr[r * 9+:9];
							end
					end
				end
		end
	end
	genvar _gv_gb_2;
	generate
		for (_gv_gb_2 = 0; _gv_gb_2 < 6; _gv_gb_2 = _gv_gb_2 + 1) begin : gen_bank_mem
			localparam gb = _gv_gb_2;
			assign act_sram_we_o[gb] = (state_i == SEQ_PRELOAD ? 1'b1 : ((((state_i == SEQ_COMPUTE) && !bank_read_used[gb]) && (dma_channel_reg > 7'd0)) && (dma_bank_ptr[gb] < 6'd54) ? 1'b1 : 1'b0));
			assign act_sram_addr_o[gb * 9+:9] = (state_i == SEQ_PRELOAD ? {3'b000, preload_cnt_i[5:0]} : ((state_i == SEQ_COMPUTE) && bank_read_used[gb] ? bank_read_addr[gb * 9+:9] : ((((state_i == SEQ_COMPUTE) && !bank_read_used[gb]) && (dma_channel_reg > 7'd0)) && (dma_bank_ptr[gb] < 6'd54) ? {dma_channel_reg[2:0], 6'b000000} + {3'b000, dma_bank_ptr[gb]} : 9'd0)));
		end
	endgenerate
	function automatic [6:0] get_dma_channel;
		input [7:0] p;
		reg [0:1] _sv2v_jump;
		begin
			_sv2v_jump = 2'b00;
			begin : sv2v_autoblock_6
				reg signed [31:0] ch;
				begin : sv2v_autoblock_7
					reg signed [31:0] _sv2v_value_on_break;
					for (ch = 1; ch < CIN; ch = ch + 1)
						if (_sv2v_jump < 2'b10) begin
							_sv2v_jump = 2'b00;
							if ((((9 * ch) / 8) - 1) == sv2v_cast_32_signed(p)) begin
								get_dma_channel = sv2v_cast_7_signed(ch);
								_sv2v_jump = 2'b11;
							end
							_sv2v_value_on_break = ch;
						end
					if (!(_sv2v_jump < 2'b10))
						ch = _sv2v_value_on_break;
					if (_sv2v_jump != 2'b11)
						_sv2v_jump = 2'b00;
				end
			end
			if (_sv2v_jump == 2'b00) begin
				get_dma_channel = 7'd0;
				_sv2v_jump = 2'b11;
			end
		end
	endfunction
	always @(posedge clk_i or negedge rst_n)
		if (!rst_n) begin
			dma_channel_reg <= 7'd0;
			begin : sv2v_autoblock_8
				reg signed [31:0] b;
				for (b = 0; b < 6; b = b + 1)
					dma_bank_ptr[b] <= 1'sb0;
			end
		end
		else if (state_i == SEQ_IDLE) begin
			dma_channel_reg <= 7'd0;
			begin : sv2v_autoblock_9
				reg signed [31:0] b;
				for (b = 0; b < 6; b = b + 1)
					dma_bank_ptr[b] <= 1'sb0;
			end
		end
		else if ((state_i == SEQ_PRELOAD) && (preload_cnt_i == 8'd53)) begin
			dma_channel_reg <= get_dma_channel(8'd0);
			begin : sv2v_autoblock_10
				reg signed [31:0] b;
				for (b = 0; b < 6; b = b + 1)
					dma_bank_ptr[b] <= 1'sb0;
			end
		end
		else if (state_i == SEQ_COMPUTE) begin
			begin : sv2v_autoblock_11
				reg signed [31:0] b;
				for (b = 0; b < 6; b = b + 1)
					if ((!bank_read_used[b] && (dma_channel_reg > 7'd0)) && (dma_bank_ptr[b] < 6'd54))
						dma_bank_ptr[b] <= dma_bank_ptr[b] + 1'b1;
			end
			if (k_cnt_i == (pass_len_i - 1'b1)) begin
				if ((pass_cnt_i + 1'b1) < total_passes_i) begin
					dma_channel_reg <= get_dma_channel(pass_cnt_i + 1'b1);
					begin : sv2v_autoblock_12
						reg signed [31:0] b;
						for (b = 0; b < 6; b = b + 1)
							dma_bank_ptr[b] <= 1'sb0;
					end
				end
				else
					dma_channel_reg <= 7'd0;
			end
		end
	initial _sv2v_0 = 0;
endmodule
