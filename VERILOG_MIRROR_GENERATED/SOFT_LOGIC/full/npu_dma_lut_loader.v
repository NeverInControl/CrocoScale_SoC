module npu_dma_lut_loader (
	clk_i,
	rst_n,
	start_i,
	lut_base_i,
	req_valid_o,
	req_addr_o,
	req_len_o,
	req_ready_i,
	rdata_i,
	rvalid_i,
	rlast_i,
	rready_o,
	psum_B_addr_o,
	psum_B_wdata_o,
	psum_B_we_o,
	done_o
);
	parameter signed [31:0] AXI_ADDR_WIDTH = 32;
	parameter signed [31:0] AXI_DATA_WIDTH = 32;
	input wire clk_i;
	input wire rst_n;
	input wire start_i;
	input wire [AXI_ADDR_WIDTH - 1:0] lut_base_i;
	output reg req_valid_o;
	output reg [AXI_ADDR_WIDTH - 1:0] req_addr_o;
	output reg [7:0] req_len_o;
	input wire req_ready_i;
	input wire [AXI_DATA_WIDTH - 1:0] rdata_i;
	input wire rvalid_i;
	input wire rlast_i;
	output reg rready_o;
	output reg [7:0] psum_B_addr_o;
	output reg [31:0] psum_B_wdata_o;
	output reg [7:0] psum_B_we_o;
	output reg done_o;
	reg [2:0] state;
	reg [1:0] burst_idx;
	reg [3:0] beat_cnt;
	reg [7:0] word_idx;
	reg [31:0] lat_word;
	always @(posedge clk_i or negedge rst_n)
		if (!rst_n) begin
			state <= 3'd0;
			burst_idx <= 1'sb0;
			beat_cnt <= 1'sb0;
			word_idx <= 1'sb0;
			lat_word <= 1'sb0;
			req_valid_o <= 1'b0;
			req_addr_o <= 1'sb0;
			req_len_o <= 1'sb0;
			rready_o <= 1'b0;
			psum_B_addr_o <= 1'sb0;
			psum_B_wdata_o <= 1'sb0;
			psum_B_we_o <= 8'h00;
			done_o <= 1'b0;
		end
		else begin
			psum_B_we_o <= 8'h00;
			done_o <= 1'b0;
			case (state)
				3'd0: begin
					req_valid_o <= 1'b0;
					rready_o <= 1'b0;
					if (start_i) begin
						burst_idx <= 1'sb0;
						word_idx <= 1'sb0;
						beat_cnt <= 1'sb0;
						req_addr_o <= lut_base_i;
						req_len_o <= 8'd15;
						req_valid_o <= 1'b1;
						state <= 3'd1;
					end
				end
				3'd1:
					if (req_valid_o && req_ready_i) begin
						req_valid_o <= 1'b0;
						rready_o <= 1'b1;
						state <= 3'd2;
					end
				3'd2:
					if (rvalid_i && rready_o) begin
						lat_word <= rdata_i;
						rready_o <= 1'b0;
						state <= 3'd3;
					end
				3'd3: begin
					psum_B_addr_o <= {word_idx[5:0], 2'b00};
					psum_B_wdata_o <= {24'd0, lat_word[7:0]};
					psum_B_we_o <= 8'hff;
					state <= 3'd4;
				end
				3'd4: begin
					psum_B_addr_o <= {word_idx[5:0], 2'b01};
					psum_B_wdata_o <= {24'd0, lat_word[15:8]};
					psum_B_we_o <= 8'hff;
					state <= 3'd5;
				end
				3'd5: begin
					psum_B_addr_o <= {word_idx[5:0], 2'b10};
					psum_B_wdata_o <= {24'd0, lat_word[23:16]};
					psum_B_we_o <= 8'hff;
					state <= 3'd6;
				end
				3'd6: begin
					psum_B_addr_o <= {word_idx[5:0], 2'b11};
					psum_B_wdata_o <= {24'd0, lat_word[31:24]};
					psum_B_we_o <= 8'hff;
					word_idx <= word_idx + 1'b1;
					if (beat_cnt == 4'd15) begin
						if (burst_idx == 2'd3)
							state <= 3'd7;
						else begin
							burst_idx <= burst_idx + 1'b1;
							req_addr_o <= lut_base_i + {24'd0, burst_idx + 2'd1, 6'b000000};
							req_len_o <= 8'd15;
							req_valid_o <= 1'b1;
							beat_cnt <= 1'sb0;
							state <= 3'd1;
						end
					end
					else begin
						beat_cnt <= beat_cnt + 1'b1;
						rready_o <= 1'b1;
						state <= 3'd2;
					end
				end
				3'd7: begin
					done_o <= 1'b1;
					state <= 3'd0;
				end
				default: state <= 3'd0;
			endcase
		end
endmodule
