module npu_axi_reader (
	clk_i,
	rst_n,
	lut_base_i,
	bias_base_i,
	quant_base_i,
	weight_base_i,
	mode_1x1_i,
	start_lut_load_i,
	lut_load_done_o,
	start_preload_i,
	preload_done_o,
	start_weight_fetch_i,
	fetch_pass_idx_i,
	weight_fetch_done_o,
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
	weight_shift_in_o,
	weight_shift_en_o,
	bias_wdata_o,
	bias_channel_o,
	bias_we_o,
	quant_shift_in_o,
	quant_shift_en_o,
	psum_B_addr_o,
	psum_B_wdata_o,
	psum_B_we_o
);
	reg _sv2v_0;
	parameter signed [31:0] ARRAY_HEIGHT = 8;
	parameter signed [31:0] WEIGHT_WIDTH = 8;
	parameter signed [31:0] PSUM_WIDTH = 32;
	parameter signed [31:0] AXI_ADDR_WIDTH = 32;
	parameter signed [31:0] AXI_DATA_WIDTH = 32;
	input wire clk_i;
	input wire rst_n;
	input wire [AXI_ADDR_WIDTH - 1:0] lut_base_i;
	input wire [AXI_ADDR_WIDTH - 1:0] bias_base_i;
	input wire [AXI_ADDR_WIDTH - 1:0] quant_base_i;
	input wire [AXI_ADDR_WIDTH - 1:0] weight_base_i;
	input wire mode_1x1_i;
	input wire start_lut_load_i;
	output reg lut_load_done_o;
	input wire start_preload_i;
	output reg preload_done_o;
	input wire start_weight_fetch_i;
	input wire [7:0] fetch_pass_idx_i;
	output reg weight_fetch_done_o;
	output reg [AXI_ADDR_WIDTH - 1:0] m_axi_araddr;
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
	output reg signed [(ARRAY_HEIGHT * WEIGHT_WIDTH) - 1:0] weight_shift_in_o;
	output reg [1:0] weight_shift_en_o;
	output wire signed [PSUM_WIDTH - 1:0] bias_wdata_o;
	output wire [2:0] bias_channel_o;
	output wire bias_we_o;
	output wire [29:0] quant_shift_in_o;
	output wire quant_shift_en_o;
	output reg [7:0] psum_B_addr_o;
	output reg [31:0] psum_B_wdata_o;
	output reg [7:0] psum_B_we_o;
	assign m_axi_arsize = 3'b010;
	assign m_axi_arburst = 2'b01;
	reg [3:0] state;
	reg [4:0] beat_cnt;
	reg [1:0] burst_idx;
	reg [5:0] word_idx;
	reg [31:0] lat_word;
	wire weight_beat_valid = (state == 4'd12) && (m_axi_rvalid && m_axi_rready);
	always @(*) begin
		if (_sv2v_0)
			;
		if (mode_1x1_i) begin
			weight_shift_en_o[0] = weight_beat_valid;
			weight_shift_en_o[1] = weight_beat_valid;
			weight_shift_in_o[0+:WEIGHT_WIDTH] = $signed(m_axi_rdata[7:0]);
			weight_shift_in_o[WEIGHT_WIDTH+:WEIGHT_WIDTH] = $signed(m_axi_rdata[15:8]);
			weight_shift_in_o[2 * WEIGHT_WIDTH+:WEIGHT_WIDTH] = $signed(m_axi_rdata[23:16]);
			weight_shift_in_o[3 * WEIGHT_WIDTH+:WEIGHT_WIDTH] = $signed(m_axi_rdata[31:24]);
			weight_shift_in_o[4 * WEIGHT_WIDTH+:WEIGHT_WIDTH] = 8'sd0;
			weight_shift_in_o[5 * WEIGHT_WIDTH+:WEIGHT_WIDTH] = 8'sd0;
			weight_shift_in_o[6 * WEIGHT_WIDTH+:WEIGHT_WIDTH] = 8'sd0;
			weight_shift_in_o[7 * WEIGHT_WIDTH+:WEIGHT_WIDTH] = 8'sd0;
		end
		else begin
			weight_shift_en_o[0] = weight_beat_valid && beat_cnt[0];
			weight_shift_en_o[1] = weight_beat_valid && beat_cnt[0];
			weight_shift_in_o[0+:WEIGHT_WIDTH] = $signed(lat_word[7:0]);
			weight_shift_in_o[WEIGHT_WIDTH+:WEIGHT_WIDTH] = $signed(lat_word[15:8]);
			weight_shift_in_o[2 * WEIGHT_WIDTH+:WEIGHT_WIDTH] = $signed(lat_word[23:16]);
			weight_shift_in_o[3 * WEIGHT_WIDTH+:WEIGHT_WIDTH] = $signed(lat_word[31:24]);
			weight_shift_in_o[4 * WEIGHT_WIDTH+:WEIGHT_WIDTH] = $signed(m_axi_rdata[7:0]);
			weight_shift_in_o[5 * WEIGHT_WIDTH+:WEIGHT_WIDTH] = $signed(m_axi_rdata[15:8]);
			weight_shift_in_o[6 * WEIGHT_WIDTH+:WEIGHT_WIDTH] = $signed(m_axi_rdata[23:16]);
			weight_shift_in_o[7 * WEIGHT_WIDTH+:WEIGHT_WIDTH] = $signed(m_axi_rdata[31:24]);
		end
	end
	assign bias_wdata_o = $signed(m_axi_rdata);
	assign bias_channel_o = beat_cnt[2:0];
	assign bias_we_o = (state == 4'd8) && (m_axi_rvalid && m_axi_rready);
	assign quant_shift_in_o = m_axi_rdata[29:0];
	assign quant_shift_en_o = (state == 4'd10) && (m_axi_rvalid && m_axi_rready);
	always @(*) begin
		if (_sv2v_0)
			;
		case (state)
			4'd3: begin
				psum_B_addr_o = {word_idx, 2'b00};
				psum_B_wdata_o = {24'd0, lat_word[7:0]};
				psum_B_we_o = 8'hff;
			end
			4'd4: begin
				psum_B_addr_o = {word_idx, 2'b01};
				psum_B_wdata_o = {24'd0, lat_word[15:8]};
				psum_B_we_o = 8'hff;
			end
			4'd5: begin
				psum_B_addr_o = {word_idx, 2'b10};
				psum_B_wdata_o = {24'd0, lat_word[23:16]};
				psum_B_we_o = 8'hff;
			end
			4'd6: begin
				psum_B_addr_o = {word_idx, 2'b11};
				psum_B_wdata_o = {24'd0, lat_word[31:24]};
				psum_B_we_o = 8'hff;
			end
			default: begin
				psum_B_addr_o = 1'sb0;
				psum_B_wdata_o = 1'sb0;
				psum_B_we_o = 8'h00;
			end
		endcase
	end
	always @(posedge clk_i)
		if (!rst_n) begin
			state <= 4'd0;
			m_axi_araddr <= 1'sb0;
			m_axi_arlen <= 1'sb0;
			m_axi_arvalid <= 1'b0;
			m_axi_rready <= 1'b0;
			lut_load_done_o <= 1'b0;
			preload_done_o <= 1'b0;
			weight_fetch_done_o <= 1'b0;
			beat_cnt <= 1'sb0;
			burst_idx <= 1'sb0;
			word_idx <= 1'sb0;
			lat_word <= 1'sb0;
		end
		else begin
			lut_load_done_o <= 1'b0;
			preload_done_o <= 1'b0;
			weight_fetch_done_o <= 1'b0;
			case (state)
				4'd0: begin
					m_axi_arvalid <= 1'b0;
					m_axi_rready <= 1'b0;
					beat_cnt <= 1'sb0;
					if (start_lut_load_i) begin
						burst_idx <= 2'd0;
						word_idx <= 6'd0;
						m_axi_araddr <= lut_base_i;
						m_axi_arlen <= 8'd15;
						m_axi_arvalid <= 1'b1;
						state <= 4'd1;
					end
					else if (start_preload_i) begin
						m_axi_araddr <= bias_base_i;
						m_axi_arlen <= 8'd7;
						m_axi_arvalid <= 1'b1;
						state <= 4'd7;
					end
					else if (start_weight_fetch_i) begin
						if (mode_1x1_i) begin
							m_axi_araddr <= weight_base_i + {19'd0, fetch_pass_idx_i, 5'b00000};
							m_axi_arlen <= 8'd7;
						end
						else begin
							m_axi_araddr <= weight_base_i + {18'd0, fetch_pass_idx_i, 6'b000000};
							m_axi_arlen <= 8'd15;
						end
						m_axi_arvalid <= 1'b1;
						state <= 4'd11;
					end
				end
				4'd1:
					if (m_axi_arvalid && m_axi_arready) begin
						m_axi_arvalid <= 1'b0;
						m_axi_rready <= 1'b1;
						state <= 4'd2;
					end
				4'd2:
					if (m_axi_rvalid && m_axi_rready) begin
						lat_word <= m_axi_rdata;
						m_axi_rready <= 1'b0;
						state <= 4'd3;
					end
				4'd3: state <= 4'd4;
				4'd4: state <= 4'd5;
				4'd5: state <= 4'd6;
				4'd6: begin
					word_idx <= word_idx + 1'b1;
					if (beat_cnt == 5'd15) begin
						if (burst_idx == 2'd3) begin
							lut_load_done_o <= 1'b1;
							state <= 4'd0;
						end
						else begin
							burst_idx <= burst_idx + 1'b1;
							m_axi_araddr <= lut_base_i + {24'd0, burst_idx + 2'd1, 6'b000000};
							m_axi_arlen <= 8'd15;
							m_axi_arvalid <= 1'b1;
							beat_cnt <= 1'sb0;
							state <= 4'd1;
						end
					end
					else begin
						beat_cnt <= beat_cnt + 1'b1;
						m_axi_rready <= 1'b1;
						state <= 4'd2;
					end
				end
				4'd7:
					if (m_axi_arvalid && m_axi_arready) begin
						m_axi_arvalid <= 1'b0;
						m_axi_rready <= 1'b1;
						beat_cnt <= 1'sb0;
						state <= 4'd8;
					end
				4'd8:
					if (m_axi_rvalid && m_axi_rready) begin
						if (m_axi_rlast || (beat_cnt == 5'd7)) begin
							m_axi_rready <= 1'b0;
							m_axi_araddr <= quant_base_i;
							m_axi_arlen <= 8'd7;
							m_axi_arvalid <= 1'b1;
							beat_cnt <= 1'sb0;
							state <= 4'd9;
						end
						else
							beat_cnt <= beat_cnt + 1'b1;
					end
				4'd9:
					if (m_axi_arvalid && m_axi_arready) begin
						m_axi_arvalid <= 1'b0;
						m_axi_rready <= 1'b1;
						beat_cnt <= 1'sb0;
						state <= 4'd10;
					end
				4'd10:
					if (m_axi_rvalid && m_axi_rready) begin
						if (m_axi_rlast || (beat_cnt == 5'd7)) begin
							m_axi_rready <= 1'b0;
							preload_done_o <= 1'b1;
							state <= 4'd0;
						end
						else
							beat_cnt <= beat_cnt + 1'b1;
					end
				4'd11:
					if (m_axi_arvalid && m_axi_arready) begin
						m_axi_arvalid <= 1'b0;
						m_axi_rready <= 1'b1;
						beat_cnt <= 1'sb0;
						state <= 4'd12;
					end
				4'd12:
					if (m_axi_rvalid && m_axi_rready) begin
						if (!mode_1x1_i && !beat_cnt[0])
							lat_word <= m_axi_rdata;
						if (m_axi_rlast || (mode_1x1_i ? beat_cnt == 5'd7 : beat_cnt == 5'd15)) begin
							m_axi_rready <= 1'b0;
							weight_fetch_done_o <= 1'b1;
							state <= 4'd0;
						end
						else
							beat_cnt <= beat_cnt + 1'b1;
					end
				default: state <= 4'd0;
			endcase
		end
	initial _sv2v_0 = 0;
endmodule
