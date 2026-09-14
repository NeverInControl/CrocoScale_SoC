module npu_soft_dma (
	clk_i,
	rst_n,
	m_axi_awaddr,
	m_axi_awlen,
	m_axi_awsize,
	m_axi_awburst,
	m_axi_awvalid,
	m_axi_awready,
	m_axi_wdata,
	m_axi_wstrb,
	m_axi_wlast,
	m_axi_wvalid,
	m_axi_wready,
	m_axi_bresp,
	m_axi_bvalid,
	m_axi_bready,
	m_axi_araddr,
	m_axi_arlen,
	m_axi_arsize,
	m_axi_arburst,
	m_axi_arvalid,
	m_axi_arready,
	m_axi_rdata,
	m_axi_rresp,
	m_axi_rlast,
	m_axi_rvalid,
	m_axi_rready,
	act_base_i,
	weight_base_i,
	out_base_i,
	bias_base_i,
	start_bias_i,
	bias_done_o,
	start_act_i,
	act_done_o,
	start_weight_i,
	weight_pass_idx_i,
	weight_done_o,
	weight_shift_in_o,
	weight_shift_en_o,
	start_drain_i,
	drain_done_o,
	drain_psum_addr_o,
	npu_out_act_i,
	drain_pixel_cnt_o,
	bias_psum_A_addr_o,
	bias_psum_A_we_o,
	bias_psum_A_wdata_o,
	bias_psum_B_addr_o,
	bias_psum_B_we_o,
	bias_psum_B_wdata_o,
	ext_act_sram_we_o,
	ext_act_sram_addr_o,
	ext_act_sram_wdata_o
);
	parameter signed [31:0] ARRAY_HEIGHT = 8;
	parameter signed [31:0] ARRAY_WIDTH = 8;
	parameter signed [31:0] TILE_SIZE = 16;
	parameter signed [31:0] ACT_HALO_PAD = 2;
	parameter signed [31:0] ACTIVATION_WIDTH = 8;
	parameter signed [31:0] WEIGHT_WIDTH = 8;
	parameter signed [31:0] PSUM_WIDTH = 32;
	parameter signed [31:0] AXI_ADDR_WIDTH = 32;
	parameter signed [31:0] AXI_DATA_WIDTH = 32;
	parameter signed [31:0] WEIGHT_SPLIT = 2;
	localparam signed [31:0] PSUM_WORDS = TILE_SIZE * TILE_SIZE;
	localparam signed [31:0] ACT_WORDS = (TILE_SIZE * TILE_SIZE) * ACT_HALO_PAD;
	localparam signed [31:0] PSUM_ADDR_WIDTH = $clog2(PSUM_WORDS);
	localparam signed [31:0] ACT_ADDR_WIDTH = $clog2(ACT_WORDS);
	localparam signed [31:0] NUM_ACT_BANKS = ARRAY_HEIGHT;
	input wire clk_i;
	input wire rst_n;
	output reg [AXI_ADDR_WIDTH - 1:0] m_axi_awaddr;
	output reg [7:0] m_axi_awlen;
	output reg [2:0] m_axi_awsize;
	output reg [1:0] m_axi_awburst;
	output reg m_axi_awvalid;
	input wire m_axi_awready;
	output reg [AXI_DATA_WIDTH - 1:0] m_axi_wdata;
	output reg [(AXI_DATA_WIDTH / 8) - 1:0] m_axi_wstrb;
	output reg m_axi_wlast;
	output reg m_axi_wvalid;
	input wire m_axi_wready;
	input wire [1:0] m_axi_bresp;
	input wire m_axi_bvalid;
	output reg m_axi_bready;
	output reg [AXI_ADDR_WIDTH - 1:0] m_axi_araddr;
	output reg [7:0] m_axi_arlen;
	output reg [2:0] m_axi_arsize;
	output reg [1:0] m_axi_arburst;
	output reg m_axi_arvalid;
	input wire m_axi_arready;
	input wire [AXI_DATA_WIDTH - 1:0] m_axi_rdata;
	input wire [1:0] m_axi_rresp;
	input wire m_axi_rlast;
	input wire m_axi_rvalid;
	output reg m_axi_rready;
	input wire [31:0] act_base_i;
	input wire [31:0] weight_base_i;
	input wire [31:0] out_base_i;
	input wire [31:0] bias_base_i;
	input wire start_bias_i;
	output reg bias_done_o;
	input wire start_act_i;
	output reg act_done_o;
	input wire start_weight_i;
	input wire [3:0] weight_pass_idx_i;
	output reg weight_done_o;
	output wire signed [(ARRAY_HEIGHT * WEIGHT_WIDTH) - 1:0] weight_shift_in_o;
	output wire [WEIGHT_SPLIT - 1:0] weight_shift_en_o;
	input wire start_drain_i;
	output reg drain_done_o;
	output reg [PSUM_ADDR_WIDTH - 1:0] drain_psum_addr_o;
	input wire signed [(ARRAY_WIDTH * ACTIVATION_WIDTH) - 1:0] npu_out_act_i;
	output wire [8:0] drain_pixel_cnt_o;
	output reg [PSUM_ADDR_WIDTH - 1:0] bias_psum_A_addr_o;
	output reg [ARRAY_WIDTH - 1:0] bias_psum_A_we_o;
	output reg signed [PSUM_WIDTH - 1:0] bias_psum_A_wdata_o;
	output reg [PSUM_ADDR_WIDTH - 1:0] bias_psum_B_addr_o;
	output reg [ARRAY_WIDTH - 1:0] bias_psum_B_we_o;
	output reg signed [PSUM_WIDTH - 1:0] bias_psum_B_wdata_o;
	output reg [NUM_ACT_BANKS - 1:0] ext_act_sram_we_o;
	output reg [(NUM_ACT_BANKS * ACT_ADDR_WIDTH) - 1:0] ext_act_sram_addr_o;
	output reg signed [(NUM_ACT_BANKS * ACTIVATION_WIDTH) - 1:0] ext_act_sram_wdata_o;
	reg [3:0] state;
	reg [2:0] bias_beat;
	reg [9:0] act_words_transferred;
	reg [8:0] act_pixel_cnt;
	reg act_word_phase;
	reg [31:0] act_sample_low;
	reg [4:0] w_beat;
	wire weight_beat_valid = ((state == 4'd6) && m_axi_rvalid) && m_axi_rready;
	assign weight_shift_en_o[0] = weight_beat_valid && ~w_beat[0];
	assign weight_shift_en_o[1] = weight_beat_valid && w_beat[0];
	assign weight_shift_in_o[0+:WEIGHT_WIDTH] = $signed(m_axi_rdata[7:0]);
	assign weight_shift_in_o[WEIGHT_WIDTH+:WEIGHT_WIDTH] = $signed(m_axi_rdata[15:8]);
	assign weight_shift_in_o[2 * WEIGHT_WIDTH+:WEIGHT_WIDTH] = $signed(m_axi_rdata[23:16]);
	assign weight_shift_in_o[3 * WEIGHT_WIDTH+:WEIGHT_WIDTH] = $signed(m_axi_rdata[31:24]);
	assign weight_shift_in_o[4 * WEIGHT_WIDTH+:WEIGHT_WIDTH] = $signed(m_axi_rdata[7:0]);
	assign weight_shift_in_o[5 * WEIGHT_WIDTH+:WEIGHT_WIDTH] = $signed(m_axi_rdata[15:8]);
	assign weight_shift_in_o[6 * WEIGHT_WIDTH+:WEIGHT_WIDTH] = $signed(m_axi_rdata[23:16]);
	assign weight_shift_in_o[7 * WEIGHT_WIDTH+:WEIGHT_WIDTH] = $signed(m_axi_rdata[31:24]);
	reg [5:0] drain_burst_idx;
	wire [8:0] burst_base_p = {drain_burst_idx, 3'b000};
	reg [4:0] drain_w_beat;
	reg signed [(ARRAY_WIDTH * ACTIVATION_WIDTH) - 1:0] drain_pixel_lat;
	assign drain_pixel_cnt_o = burst_base_p + (drain_w_beat >> 1);
	function automatic [ACT_ADDR_WIDTH - 1:0] sv2v_cast_41508;
		input reg [ACT_ADDR_WIDTH - 1:0] inp;
		sv2v_cast_41508 = inp;
	endfunction
	function automatic [PSUM_ADDR_WIDTH - 1:0] sv2v_cast_EDE54;
		input reg [PSUM_ADDR_WIDTH - 1:0] inp;
		sv2v_cast_EDE54 = inp;
	endfunction
	always @(posedge clk_i or negedge rst_n)
		if (!rst_n) begin
			state <= 4'd0;
			bias_done_o <= 1'b0;
			bias_beat <= 1'sb0;
			bias_psum_A_addr_o <= 1'sb0;
			bias_psum_A_we_o <= 1'sb0;
			bias_psum_A_wdata_o <= 1'sb0;
			bias_psum_B_addr_o <= 1'sb0;
			bias_psum_B_we_o <= 1'sb0;
			bias_psum_B_wdata_o <= 1'sb0;
			act_done_o <= 1'b0;
			weight_done_o <= 1'b0;
			drain_done_o <= 1'b0;
			drain_psum_addr_o <= 1'sb0;
			act_words_transferred <= 1'sb0;
			act_pixel_cnt <= 1'sb0;
			act_word_phase <= 1'b0;
			act_sample_low <= 1'sb0;
			w_beat <= 1'sb0;
			drain_burst_idx <= 1'sb0;
			drain_w_beat <= 1'sb0;
			drain_pixel_lat <= 1'sb0;
			m_axi_awaddr <= 1'sb0;
			m_axi_awlen <= 1'sb0;
			m_axi_awsize <= 3'b010;
			m_axi_awburst <= 2'b01;
			m_axi_awvalid <= 1'b0;
			m_axi_wdata <= 1'sb0;
			m_axi_wstrb <= 4'h0;
			m_axi_wlast <= 1'b0;
			m_axi_wvalid <= 1'b0;
			m_axi_bready <= 1'b0;
			m_axi_araddr <= 1'sb0;
			m_axi_arlen <= 1'sb0;
			m_axi_arsize <= 3'b010;
			m_axi_arburst <= 2'b01;
			m_axi_arvalid <= 1'b0;
			m_axi_rready <= 1'b0;
			ext_act_sram_we_o <= 1'sb0;
			ext_act_sram_addr_o <= 1'sb0;
			ext_act_sram_wdata_o <= 1'sb0;
		end
		else begin
			bias_done_o <= 1'b0;
			bias_psum_A_we_o <= 1'sb0;
			bias_psum_B_we_o <= 1'sb0;
			act_done_o <= 1'b0;
			weight_done_o <= 1'b0;
			drain_done_o <= 1'b0;
			ext_act_sram_we_o <= 1'sb0;
			case (state)
				4'd0: begin
					m_axi_awvalid <= 1'b0;
					m_axi_wvalid <= 1'b0;
					m_axi_arvalid <= 1'b0;
					m_axi_bready <= 1'b0;
					m_axi_rready <= 1'b0;
					if (start_bias_i) begin
						bias_beat <= 1'sb0;
						state <= 4'd1;
					end
					else if (start_act_i) begin
						act_words_transferred <= 1'sb0;
						act_pixel_cnt <= 1'sb0;
						act_word_phase <= 1'b0;
						state <= 4'd3;
					end
					else if (start_weight_i) begin
						w_beat <= 1'sb0;
						state <= 4'd5;
					end
					else if (start_drain_i) begin
						drain_burst_idx <= 1'sb0;
						state <= 4'd7;
					end
				end
				4'd1: begin
					m_axi_araddr <= bias_base_i;
					m_axi_arlen <= 8'd7;
					m_axi_arsize <= 3'b010;
					m_axi_arburst <= 2'b01;
					m_axi_arvalid <= 1'b1;
					m_axi_rready <= 1'b1;
					state <= 4'd2;
				end
				4'd2: begin
					if (m_axi_arvalid && m_axi_arready)
						m_axi_arvalid <= 1'b0;
					if (m_axi_rvalid && m_axi_rready) begin
						bias_psum_A_addr_o <= 1'sb0;
						bias_psum_A_we_o <= 8'b00000001 << bias_beat;
						bias_psum_A_wdata_o <= m_axi_rdata;
						bias_psum_B_addr_o <= 1'sb0;
						bias_psum_B_we_o <= 8'b00000001 << bias_beat;
						bias_psum_B_wdata_o <= m_axi_rdata;
						bias_beat <= bias_beat + 1'b1;
						if (m_axi_rlast) begin
							m_axi_rready <= 1'b0;
							bias_done_o <= 1'b1;
							state <= 4'd0;
						end
					end
				end
				4'd3: begin
					m_axi_araddr <= act_base_i + {20'b00000000000000000000, act_words_transferred, 2'b00};
					m_axi_arsize <= 3'b010;
					m_axi_arburst <= 2'b01;
					if ((10'd648 - act_words_transferred) >= 10'd16)
						m_axi_arlen <= 8'd15;
					else
						m_axi_arlen <= 8'd7;
					m_axi_arvalid <= 1'b1;
					m_axi_rready <= 1'b1;
					state <= 4'd4;
				end
				4'd4: begin
					if (m_axi_arvalid && m_axi_arready)
						m_axi_arvalid <= 1'b0;
					if (m_axi_rvalid && m_axi_rready) begin
						act_words_transferred <= act_words_transferred + 1'b1;
						if (!act_word_phase) begin
							act_sample_low <= m_axi_rdata;
							act_word_phase <= 1'b1;
						end
						else begin
							act_word_phase <= 1'b0;
							begin : sv2v_autoblock_1
								reg signed [31:0] b;
								for (b = 0; b < NUM_ACT_BANKS; b = b + 1)
									ext_act_sram_addr_o[b * ACT_ADDR_WIDTH+:ACT_ADDR_WIDTH] <= sv2v_cast_41508(act_pixel_cnt);
							end
							ext_act_sram_wdata_o[0+:ACTIVATION_WIDTH] <= $signed(act_sample_low[7:0]);
							ext_act_sram_wdata_o[ACTIVATION_WIDTH+:ACTIVATION_WIDTH] <= $signed(act_sample_low[15:8]);
							ext_act_sram_wdata_o[2 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH] <= $signed(act_sample_low[23:16]);
							ext_act_sram_wdata_o[3 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH] <= $signed(act_sample_low[31:24]);
							ext_act_sram_wdata_o[4 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH] <= $signed(m_axi_rdata[7:0]);
							ext_act_sram_wdata_o[5 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH] <= $signed(m_axi_rdata[15:8]);
							ext_act_sram_wdata_o[6 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH] <= $signed(m_axi_rdata[23:16]);
							ext_act_sram_wdata_o[7 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH] <= $signed(m_axi_rdata[31:24]);
							ext_act_sram_we_o <= 8'hff;
							act_pixel_cnt <= act_pixel_cnt + 1'b1;
						end
						if (m_axi_rlast) begin
							if ((act_words_transferred + 1'b1) == 10'd648) begin
								m_axi_rready <= 1'b0;
								state <= 4'd14;
							end
							else
								state <= 4'd3;
						end
					end
				end
				4'd5: begin
					m_axi_araddr <= weight_base_i + {20'b00000000000000000000, weight_pass_idx_i, 6'b000000};
					m_axi_arlen <= 8'd15;
					m_axi_arsize <= 3'b010;
					m_axi_arburst <= 2'b01;
					m_axi_arvalid <= 1'b1;
					m_axi_rready <= 1'b1;
					state <= 4'd6;
				end
				4'd6: begin
					if (m_axi_arvalid && m_axi_arready)
						m_axi_arvalid <= 1'b0;
					if (m_axi_rvalid && m_axi_rready) begin
						w_beat <= w_beat + 1'b1;
						if (m_axi_rlast) begin
							m_axi_rready <= 1'b0;
							weight_done_o <= 1'b1;
							state <= 4'd0;
						end
					end
				end
				4'd7: begin
					m_axi_awaddr <= out_base_i + {21'b000000000000000000000, drain_burst_idx, 6'b000000};
					m_axi_awlen <= 8'd15;
					m_axi_awsize <= 3'b010;
					m_axi_awburst <= 2'b01;
					m_axi_awvalid <= 1'b1;
					drain_w_beat <= 1'sb0;
					drain_psum_addr_o <= sv2v_cast_EDE54(burst_base_p + 3'd0);
					state <= 4'd8;
				end
				4'd8: begin
					if (m_axi_awvalid && m_axi_awready)
						m_axi_awvalid <= 1'b0;
					state <= 4'd9;
				end
				4'd9: begin
					if (m_axi_awvalid && m_axi_awready)
						m_axi_awvalid <= 1'b0;
					drain_psum_addr_o <= sv2v_cast_EDE54(burst_base_p + 3'd1);
					state <= 4'd10;
				end
				4'd10: begin
					if (m_axi_awvalid && m_axi_awready)
						m_axi_awvalid <= 1'b0;
					state <= 4'd11;
				end
				4'd11: begin
					if (m_axi_awvalid && m_axi_awready)
						m_axi_awvalid <= 1'b0;
					drain_psum_addr_o <= sv2v_cast_EDE54(burst_base_p + 3'd2);
					drain_pixel_lat <= npu_out_act_i;
					m_axi_wdata <= {npu_out_act_i[3 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH], npu_out_act_i[2 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH], npu_out_act_i[ACTIVATION_WIDTH+:ACTIVATION_WIDTH], npu_out_act_i[0+:ACTIVATION_WIDTH]};
					m_axi_wstrb <= 4'hf;
					m_axi_wvalid <= 1'b1;
					m_axi_wlast <= 1'b0;
					state <= 4'd12;
				end
				4'd12: begin
					if (m_axi_awvalid && m_axi_awready)
						m_axi_awvalid <= 1'b0;
					if (m_axi_wvalid && m_axi_wready) begin
						drain_w_beat <= drain_w_beat + 1'b1;
						if (drain_w_beat[0] == 1'b0) begin
							m_axi_wdata <= {drain_pixel_lat[7 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH], drain_pixel_lat[6 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH], drain_pixel_lat[5 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH], drain_pixel_lat[4 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH]};
							if (drain_w_beat == 5'd14)
								m_axi_wlast <= 1'b1;
						end
						else if (drain_w_beat == 5'd15) begin
							m_axi_wvalid <= 1'b0;
							m_axi_wlast <= 1'b0;
							m_axi_bready <= 1'b1;
							state <= 4'd13;
						end
						else begin
							m_axi_wdata <= {npu_out_act_i[3 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH], npu_out_act_i[2 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH], npu_out_act_i[ACTIVATION_WIDTH+:ACTIVATION_WIDTH], npu_out_act_i[0+:ACTIVATION_WIDTH]};
							drain_pixel_lat <= npu_out_act_i;
							if (drain_w_beat <= 5'd9)
								drain_psum_addr_o <= sv2v_cast_EDE54((burst_base_p + ((drain_w_beat + 1'b1) >> 1)) + 3'd2);
						end
					end
				end
				4'd13:
					if (m_axi_bvalid && m_axi_bready) begin
						m_axi_bready <= 1'b0;
						if (drain_burst_idx == 6'd31) begin
							drain_done_o <= 1'b1;
							state <= 4'd0;
						end
						else begin
							drain_burst_idx <= drain_burst_idx + 1'b1;
							state <= 4'd7;
						end
					end
				4'd14: begin
					act_done_o <= 1'b1;
					state <= 4'd0;
				end
				default: state <= 4'd0;
			endcase
		end
endmodule
