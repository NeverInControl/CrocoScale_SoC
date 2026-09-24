module npu_min_dma (
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
	bias_psum_we_o,
	bias_psum_wdata_o,
	ext_act_sram_we_o,
	ext_act_sram_addr_o,
	ext_act_sram_wdata_o
);
	parameter signed [31:0] KERNEL_SIZE = 3;
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
	localparam signed [31:0] TOTAL_PIXELS = (KERNEL_SIZE == 1 ? 256 : 324);
	localparam signed [31:0] NUM_ACT_BANKS = ARRAY_HEIGHT;
	localparam signed [31:0] ACT_ADDR_WIDTH = 9;
	localparam signed [31:0] PSUM_ADDR_WIDTH = 8;
	input wire clk_i;
	input wire rst_n;
	output wire [AXI_ADDR_WIDTH - 1:0] m_axi_awaddr;
	output reg [7:0] m_axi_awlen;
	output wire [2:0] m_axi_awsize;
	output wire [1:0] m_axi_awburst;
	output reg m_axi_awvalid;
	input wire m_axi_awready;
	output reg [AXI_DATA_WIDTH - 1:0] m_axi_wdata;
	output wire [(AXI_DATA_WIDTH / 8) - 1:0] m_axi_wstrb;
	output reg m_axi_wlast;
	output reg m_axi_wvalid;
	input wire m_axi_wready;
	input wire [1:0] m_axi_bresp;
	input wire m_axi_bvalid;
	output reg m_axi_bready;
	output wire [AXI_ADDR_WIDTH - 1:0] m_axi_araddr;
	output reg [7:0] m_axi_arlen;
	output wire [2:0] m_axi_arsize;
	output wire [1:0] m_axi_arburst;
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
	output reg [7:0] drain_psum_addr_o;
	input wire signed [(ARRAY_WIDTH * ACTIVATION_WIDTH) - 1:0] npu_out_act_i;
	output wire [8:0] drain_pixel_cnt_o;
	output wire [ARRAY_WIDTH - 1:0] bias_psum_we_o;
	output wire signed [PSUM_WIDTH - 1:0] bias_psum_wdata_o;
	output wire [NUM_ACT_BANKS - 1:0] ext_act_sram_we_o;
	output wire [8:0] ext_act_sram_addr_o;
	output wire signed [(NUM_ACT_BANKS * ACTIVATION_WIDTH) - 1:0] ext_act_sram_wdata_o;
	assign m_axi_awsize = 3'b010;
	assign m_axi_awburst = 2'b01;
	assign m_axi_wstrb = 4'hf;
	assign m_axi_arsize = 3'b010;
	assign m_axi_arburst = 2'b01;
	reg [3:0] state;
	reg [AXI_ADDR_WIDTH - 1:0] axi_addr_reg;
	assign m_axi_araddr = axi_addr_reg;
	assign m_axi_awaddr = axi_addr_reg;
	reg [2:0] bias_beat;
	assign bias_psum_wdata_o = m_axi_rdata;
	assign bias_psum_we_o = (((state == 4'd2) && m_axi_rvalid) && m_axi_rready ? 8'b00000001 << bias_beat : 8'b00000000);
	reg [8:0] act_pixel_cnt;
	reg act_word_phase;
	reg [31:0] act_sample_low;
	assign ext_act_sram_addr_o = act_pixel_cnt;
	assign ext_act_sram_we_o = ((((state == 4'd4) && m_axi_rvalid) && m_axi_rready) && act_word_phase ? 8'hff : 8'h00);
	assign ext_act_sram_wdata_o[0+:ACTIVATION_WIDTH] = $signed(act_sample_low[7:0]);
	assign ext_act_sram_wdata_o[ACTIVATION_WIDTH+:ACTIVATION_WIDTH] = $signed(act_sample_low[15:8]);
	assign ext_act_sram_wdata_o[2 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH] = $signed(act_sample_low[23:16]);
	assign ext_act_sram_wdata_o[3 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH] = $signed(act_sample_low[31:24]);
	assign ext_act_sram_wdata_o[4 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH] = $signed(m_axi_rdata[7:0]);
	assign ext_act_sram_wdata_o[5 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH] = $signed(m_axi_rdata[15:8]);
	assign ext_act_sram_wdata_o[6 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH] = $signed(m_axi_rdata[23:16]);
	assign ext_act_sram_wdata_o[7 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH] = $signed(m_axi_rdata[31:24]);
	reg w_phase;
	wire weight_beat_valid = ((state == 4'd6) && m_axi_rvalid) && m_axi_rready;
	assign weight_shift_en_o[0] = weight_beat_valid && ~w_phase;
	assign weight_shift_en_o[1] = weight_beat_valid && w_phase;
	assign weight_shift_in_o[0+:WEIGHT_WIDTH] = $signed(m_axi_rdata[7:0]);
	assign weight_shift_in_o[WEIGHT_WIDTH+:WEIGHT_WIDTH] = $signed(m_axi_rdata[15:8]);
	assign weight_shift_in_o[2 * WEIGHT_WIDTH+:WEIGHT_WIDTH] = $signed(m_axi_rdata[23:16]);
	assign weight_shift_in_o[3 * WEIGHT_WIDTH+:WEIGHT_WIDTH] = $signed(m_axi_rdata[31:24]);
	assign weight_shift_in_o[4 * WEIGHT_WIDTH+:WEIGHT_WIDTH] = $signed(m_axi_rdata[7:0]);
	assign weight_shift_in_o[5 * WEIGHT_WIDTH+:WEIGHT_WIDTH] = $signed(m_axi_rdata[15:8]);
	assign weight_shift_in_o[6 * WEIGHT_WIDTH+:WEIGHT_WIDTH] = $signed(m_axi_rdata[23:16]);
	assign weight_shift_in_o[7 * WEIGHT_WIDTH+:WEIGHT_WIDTH] = $signed(m_axi_rdata[31:24]);
	reg [4:0] drain_burst_idx;
	reg [3:0] drain_w_beat;
	reg [2:0] drain_pipe_cnt;
	reg [31:0] drain_high_sample;
	assign drain_pixel_cnt_o = {1'b0, drain_burst_idx, drain_w_beat[3:1]};
	function automatic signed [8:0] sv2v_cast_9_signed;
		input reg signed [8:0] inp;
		sv2v_cast_9_signed = inp;
	endfunction
	always @(posedge clk_i)
		if (!rst_n) begin
			state <= 4'd0;
			bias_done_o <= 1'b0;
			bias_beat <= 1'sb0;
			act_done_o <= 1'b0;
			weight_done_o <= 1'b0;
			drain_done_o <= 1'b0;
			drain_psum_addr_o <= 1'sb0;
			act_pixel_cnt <= 1'sb0;
			act_word_phase <= 1'b0;
			act_sample_low <= 1'sb0;
			w_phase <= 1'b0;
			drain_burst_idx <= 1'sb0;
			drain_w_beat <= 1'sb0;
			drain_pipe_cnt <= 1'sb0;
			drain_high_sample <= 1'sb0;
			axi_addr_reg <= 1'sb0;
			m_axi_awlen <= 1'sb0;
			m_axi_awvalid <= 1'b0;
			m_axi_wdata <= 1'sb0;
			m_axi_wlast <= 1'b0;
			m_axi_wvalid <= 1'b0;
			m_axi_bready <= 1'b0;
			m_axi_arlen <= 1'sb0;
			m_axi_arvalid <= 1'b0;
			m_axi_rready <= 1'b0;
		end
		else begin
			bias_done_o <= 1'b0;
			act_done_o <= 1'b0;
			weight_done_o <= 1'b0;
			drain_done_o <= 1'b0;
			if (m_axi_awvalid && m_axi_awready)
				m_axi_awvalid <= 1'b0;
			if (m_axi_arvalid && m_axi_arready)
				m_axi_arvalid <= 1'b0;
			case (state)
				4'd0: begin
					m_axi_awvalid <= 1'b0;
					m_axi_wvalid <= 1'b0;
					m_axi_arvalid <= 1'b0;
					m_axi_bready <= 1'b0;
					m_axi_rready <= 1'b0;
					if (start_bias_i) begin
						bias_beat <= 1'sb0;
						axi_addr_reg <= bias_base_i;
						state <= 4'd1;
					end
					else if (start_act_i) begin
						act_pixel_cnt <= 1'sb0;
						act_word_phase <= 1'b0;
						axi_addr_reg <= act_base_i;
						state <= 4'd3;
					end
					else if (start_weight_i) begin
						w_phase <= 1'b0;
						axi_addr_reg <= weight_base_i + {22'b0000000000000000000000, weight_pass_idx_i, 6'b000000};
						state <= 4'd5;
					end
					else if (start_drain_i) begin
						drain_burst_idx <= 1'sb0;
						axi_addr_reg <= out_base_i;
						state <= 4'd7;
					end
				end
				4'd1: begin
					m_axi_arlen <= 8'd7;
					m_axi_arvalid <= 1'b1;
					m_axi_rready <= 1'b1;
					state <= 4'd2;
				end
				4'd2:
					if (m_axi_rvalid && m_axi_rready) begin
						bias_beat <= bias_beat + 1'b1;
						if (m_axi_rlast) begin
							m_axi_rready <= 1'b0;
							bias_done_o <= 1'b1;
							state <= 4'd0;
						end
					end
				4'd3: begin
					if (KERNEL_SIZE == 1)
						m_axi_arlen <= 8'd15;
					else
						m_axi_arlen <= (act_pixel_cnt[8] && act_pixel_cnt[6] ? 8'd7 : 8'd15);
					m_axi_arvalid <= 1'b1;
					m_axi_rready <= 1'b1;
					state <= 4'd4;
				end
				4'd4:
					if (m_axi_rvalid && m_axi_rready) begin
						act_word_phase <= ~act_word_phase;
						if (!act_word_phase)
							act_sample_low <= m_axi_rdata;
						else
							act_pixel_cnt <= act_pixel_cnt + 1'b1;
						if (m_axi_rlast) begin
							if (act_pixel_cnt == (sv2v_cast_9_signed(TOTAL_PIXELS) - 1'b1)) begin
								m_axi_rready <= 1'b0;
								act_done_o <= 1'b1;
								state <= 4'd0;
							end
							else begin
								axi_addr_reg <= axi_addr_reg + 32'd64;
								state <= 4'd3;
							end
						end
					end
				4'd5: begin
					m_axi_arlen <= 8'd15;
					m_axi_arvalid <= 1'b1;
					m_axi_rready <= 1'b1;
					state <= 4'd6;
				end
				4'd6:
					if (m_axi_rvalid && m_axi_rready) begin
						w_phase <= ~w_phase;
						if (m_axi_rlast) begin
							m_axi_rready <= 1'b0;
							weight_done_o <= 1'b1;
							state <= 4'd0;
						end
					end
				4'd7: begin
					m_axi_awlen <= 8'd15;
					m_axi_awvalid <= 1'b1;
					drain_w_beat <= 1'sb0;
					drain_pipe_cnt <= 1'sb0;
					drain_psum_addr_o <= {drain_burst_idx, 3'b000};
					state <= 4'd8;
				end
				4'd8: begin
					drain_pipe_cnt <= drain_pipe_cnt + 1'b1;
					if (drain_pipe_cnt == 3'd1)
						drain_psum_addr_o <= {drain_burst_idx, 3'b001};
					if (drain_pipe_cnt == 3'd3)
						drain_psum_addr_o <= {drain_burst_idx, 3'b010};
					if (drain_pipe_cnt == 3'd5)
						drain_psum_addr_o <= {drain_burst_idx, 3'b011};
					if (drain_pipe_cnt == 3'd6) begin
						m_axi_wdata <= {npu_out_act_i[3 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH], npu_out_act_i[2 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH], npu_out_act_i[ACTIVATION_WIDTH+:ACTIVATION_WIDTH], npu_out_act_i[0+:ACTIVATION_WIDTH]};
						drain_high_sample <= {npu_out_act_i[7 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH], npu_out_act_i[6 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH], npu_out_act_i[5 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH], npu_out_act_i[4 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH]};
						m_axi_wvalid <= 1'b1;
						m_axi_wlast <= 1'b0;
						state <= 4'd9;
					end
				end
				4'd9:
					if (m_axi_wvalid && m_axi_wready) begin
						drain_w_beat <= drain_w_beat + 1'b1;
						if (drain_w_beat[0] == 1'b0) begin
							m_axi_wdata <= drain_high_sample;
							if (!drain_w_beat[3])
								drain_psum_addr_o <= {drain_burst_idx, 1'b1, drain_w_beat[2:1]};
							if (&drain_w_beat[3:1])
								m_axi_wlast <= 1'b1;
						end
						else if (&drain_w_beat[3:1]) begin
							m_axi_wvalid <= 1'b0;
							m_axi_wlast <= 1'b0;
							m_axi_bready <= 1'b1;
							state <= 4'd10;
						end
						else begin
							m_axi_wdata <= {npu_out_act_i[3 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH], npu_out_act_i[2 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH], npu_out_act_i[ACTIVATION_WIDTH+:ACTIVATION_WIDTH], npu_out_act_i[0+:ACTIVATION_WIDTH]};
							drain_high_sample <= {npu_out_act_i[7 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH], npu_out_act_i[6 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH], npu_out_act_i[5 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH], npu_out_act_i[4 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH]};
						end
					end
				4'd10:
					if (m_axi_bvalid && m_axi_bready) begin
						m_axi_bready <= 1'b0;
						if (&drain_burst_idx) begin
							drain_done_o <= 1'b1;
							state <= 4'd0;
						end
						else begin
							drain_burst_idx <= drain_burst_idx + 1'b1;
							axi_addr_reg <= axi_addr_reg + 32'd64;
							state <= 4'd7;
						end
					end
				default: state <= 4'd0;
			endcase
		end
endmodule
