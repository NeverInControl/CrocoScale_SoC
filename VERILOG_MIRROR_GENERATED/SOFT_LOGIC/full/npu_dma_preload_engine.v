module npu_dma_preload_engine (
	clk_i,
	rst_n,
	start_i,
	bias_base_i,
	quant_base_i,
	req_valid_o,
	req_addr_o,
	req_len_o,
	req_ready_i,
	rdata_i,
	rvalid_i,
	rlast_i,
	rready_o,
	bias_wdata_o,
	bias_channel_o,
	bias_we_o,
	quant_shift_in_o,
	quant_shift_en_o,
	done_o
);
	parameter signed [31:0] PSUM_WIDTH = 32;
	parameter signed [31:0] AXI_ADDR_WIDTH = 32;
	parameter signed [31:0] AXI_DATA_WIDTH = 32;
	input wire clk_i;
	input wire rst_n;
	input wire start_i;
	input wire [AXI_ADDR_WIDTH - 1:0] bias_base_i;
	input wire [AXI_ADDR_WIDTH - 1:0] quant_base_i;
	output reg req_valid_o;
	output reg [AXI_ADDR_WIDTH - 1:0] req_addr_o;
	output reg [7:0] req_len_o;
	input wire req_ready_i;
	input wire [AXI_DATA_WIDTH - 1:0] rdata_i;
	input wire rvalid_i;
	input wire rlast_i;
	output reg rready_o;
	output reg signed [PSUM_WIDTH - 1:0] bias_wdata_o;
	output reg [2:0] bias_channel_o;
	output reg bias_we_o;
	output reg [29:0] quant_shift_in_o;
	output reg quant_shift_en_o;
	output reg done_o;
	reg [2:0] state;
	reg [2:0] beat_cnt;
	reg [2:0] shift_cnt;
	reg [29:0] cfg_buf [0:7];
	always @(posedge clk_i or negedge rst_n)
		if (!rst_n) begin
			state <= 3'd0;
			req_valid_o <= 1'b0;
			req_addr_o <= 1'sb0;
			req_len_o <= 1'sb0;
			rready_o <= 1'b0;
			bias_wdata_o <= 1'sb0;
			bias_channel_o <= 1'sb0;
			bias_we_o <= 1'b0;
			quant_shift_in_o <= 1'sb0;
			quant_shift_en_o <= 1'b0;
			done_o <= 1'b0;
			beat_cnt <= 1'sb0;
			shift_cnt <= 1'sb0;
			begin : sv2v_autoblock_1
				reg signed [31:0] i;
				for (i = 0; i < 8; i = i + 1)
					cfg_buf[i] <= 1'sb0;
			end
		end
		else begin
			bias_we_o <= 1'b0;
			quant_shift_en_o <= 1'b0;
			done_o <= 1'b0;
			case (state)
				3'd0: begin
					req_valid_o <= 1'b0;
					rready_o <= 1'b0;
					if (start_i) begin
						req_addr_o <= bias_base_i;
						req_len_o <= 8'd7;
						req_valid_o <= 1'b1;
						state <= 3'd1;
					end
				end
				3'd1:
					if (req_valid_o && req_ready_i) begin
						req_valid_o <= 1'b0;
						rready_o <= 1'b1;
						beat_cnt <= 1'sb0;
						state <= 3'd2;
					end
				3'd2:
					if (rvalid_i && rready_o) begin
						bias_wdata_o <= $signed(rdata_i);
						bias_channel_o <= beat_cnt;
						bias_we_o <= 1'b1;
						if (rlast_i || (beat_cnt == 3'd7)) begin
							rready_o <= 1'b0;
							req_addr_o <= quant_base_i;
							req_len_o <= 8'd7;
							req_valid_o <= 1'b1;
							state <= 3'd3;
						end
						else
							beat_cnt <= beat_cnt + 1'b1;
					end
				3'd3:
					if (req_valid_o && req_ready_i) begin
						req_valid_o <= 1'b0;
						rready_o <= 1'b1;
						beat_cnt <= 1'sb0;
						state <= 3'd4;
					end
				3'd4:
					if (rvalid_i && rready_o) begin
						cfg_buf[beat_cnt] <= rdata_i[29:0];
						if (rlast_i || (beat_cnt == 3'd7)) begin
							rready_o <= 1'b0;
							shift_cnt <= 3'd7;
							state <= 3'd5;
						end
						else
							beat_cnt <= beat_cnt + 1'b1;
					end
				3'd5: begin
					quant_shift_in_o <= cfg_buf[shift_cnt];
					quant_shift_en_o <= 1'b1;
					if (shift_cnt == 3'd0)
						state <= 3'd6;
					else
						shift_cnt <= shift_cnt - 1'b1;
				end
				3'd6: begin
					done_o <= 1'b1;
					state <= 3'd0;
				end
				default: state <= 3'd0;
			endcase
		end
endmodule
