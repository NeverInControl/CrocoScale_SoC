module npu_seq_preload (
	clk_i,
	rst_n,
	state_i,
	preload_cnt_i,
	pass_cnt_i,
	k_cnt_i,
	pass_len_i,
	total_passes_i,
	bank_read_used_i,
	dma_channel_to_load_o,
	dma_bank_ptr_o,
	dma_we_o,
	dma_addr_o
);
	parameter signed [31:0] CIN = 128;
	input wire clk_i;
	input wire rst_n;
	input wire [2:0] state_i;
	input wire [7:0] preload_cnt_i;
	input wire [7:0] pass_cnt_i;
	input wire [8:0] k_cnt_i;
	input wire [8:0] pass_len_i;
	input wire [7:0] total_passes_i;
	input wire [5:0] bank_read_used_i;
	output wire [6:0] dma_channel_to_load_o;
	output wire [35:0] dma_bank_ptr_o;
	output wire [5:0] dma_we_o;
	output wire [53:0] dma_addr_o;
	localparam [2:0] SEQ_IDLE = 3'd0;
	localparam [2:0] SEQ_PRELOAD = 3'd1;
	localparam [2:0] SEQ_COMPUTE = 3'd2;
	reg [5:0] dma_bank_ptr [0:5];
	reg [6:0] dma_channel_reg;
	reg [3:0] dma_mod9_cnt;
	reg [6:0] dma_next_ch;
	assign dma_channel_to_load_o = dma_channel_reg;
	genvar _gv_gb_1;
	generate
		for (_gv_gb_1 = 0; _gv_gb_1 < 6; _gv_gb_1 = _gv_gb_1 + 1) begin : gen_bank_ptr
			localparam gb = _gv_gb_1;
			assign dma_bank_ptr_o[gb * 6+:6] = dma_bank_ptr[gb];
		end
	endgenerate
	wire dma_channel_active = dma_channel_reg > 7'd0;
	genvar _gv_gb_2;
	generate
		for (_gv_gb_2 = 0; _gv_gb_2 < 6; _gv_gb_2 = _gv_gb_2 + 1) begin : gen_bank_dma
			localparam gb = _gv_gb_2;
			wire dma_write_active = (((state_i == SEQ_COMPUTE) && !bank_read_used_i[gb]) && dma_channel_active) && (dma_bank_ptr[gb] < 6'd54);
			assign dma_we_o[gb] = dma_write_active;
			assign dma_addr_o[gb * 9+:9] = (dma_write_active ? {dma_channel_reg[2:0], dma_bank_ptr[gb]} : 9'd0);
		end
	endgenerate
	function automatic signed [7:0] sv2v_cast_8_signed;
		input reg signed [7:0] inp;
		sv2v_cast_8_signed = inp;
	endfunction
	always @(posedge clk_i)
		if (!rst_n) begin
			dma_channel_reg <= 7'd0;
			dma_mod9_cnt <= 4'd0;
			dma_next_ch <= 7'd0;
			begin : sv2v_autoblock_1
				reg signed [31:0] b;
				for (b = 0; b < 6; b = b + 1)
					dma_bank_ptr[b] <= 1'sb0;
			end
		end
		else if (state_i == SEQ_IDLE) begin
			dma_channel_reg <= 7'd0;
			dma_mod9_cnt <= 4'd0;
			dma_next_ch <= 7'd0;
			begin : sv2v_autoblock_2
				reg signed [31:0] b;
				for (b = 0; b < 6; b = b + 1)
					dma_bank_ptr[b] <= 1'sb0;
			end
		end
		else if ((state_i == SEQ_PRELOAD) && (preload_cnt_i == 8'd53)) begin
			dma_channel_reg <= 7'd1;
			dma_mod9_cnt <= 4'd1;
			dma_next_ch <= 7'd1;
			begin : sv2v_autoblock_3
				reg signed [31:0] b;
				for (b = 0; b < 6; b = b + 1)
					dma_bank_ptr[b] <= 1'sb0;
			end
		end
		else if (state_i == SEQ_COMPUTE) begin
			begin : sv2v_autoblock_4
				reg signed [31:0] b;
				for (b = 0; b < 6; b = b + 1)
					if ((!bank_read_used_i[b] && (dma_channel_reg > 7'd0)) && (dma_bank_ptr[b] < 6'd54))
						dma_bank_ptr[b] <= dma_bank_ptr[b] + 1'b1;
			end
			if (k_cnt_i == (pass_len_i - 1'b1)) begin
				if ((pass_cnt_i + 1'b1) < total_passes_i) begin : sv2v_autoblock_5
					reg [3:0] next_mod;
					reg [6:0] next_ch_val;
					next_mod = (dma_mod9_cnt == 4'd8 ? 4'd0 : dma_mod9_cnt + 4'd1);
					next_ch_val = (dma_mod9_cnt == 4'd8 ? dma_next_ch : dma_next_ch + 7'd1);
					dma_mod9_cnt <= next_mod;
					dma_next_ch <= next_ch_val;
					if ((next_mod == 4'd8) || ({1'b0, next_ch_val} >= sv2v_cast_8_signed(CIN)))
						dma_channel_reg <= 7'd0;
					else
						dma_channel_reg <= next_ch_val;
					begin : sv2v_autoblock_6
						reg signed [31:0] b;
						for (b = 0; b < 6; b = b + 1)
							dma_bank_ptr[b] <= 1'sb0;
					end
				end
				else
					dma_channel_reg <= 7'd0;
			end
		end
endmodule
