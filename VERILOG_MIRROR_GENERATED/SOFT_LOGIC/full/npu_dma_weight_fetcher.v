module npu_dma_weight_fetcher (
	clk_i,
	rst_n,
	start_i,
	mode_1x1_i,
	fetch_pass_idx_i,
	weight_base_i,
	req_valid_o,
	req_addr_o,
	req_len_o,
	req_ready_i,
	rdata_i,
	rvalid_i,
	rlast_i,
	rready_o,
	weight_shift_in_o,
	weight_shift_en_o,
	done_o
);
	reg _sv2v_0;
	parameter signed [31:0] ARRAY_HEIGHT = 8;
	parameter signed [31:0] WEIGHT_WIDTH = 8;
	parameter signed [31:0] AXI_ADDR_WIDTH = 32;
	parameter signed [31:0] AXI_DATA_WIDTH = 32;
	input wire clk_i;
	input wire rst_n;
	input wire start_i;
	input wire mode_1x1_i;
	input wire [7:0] fetch_pass_idx_i;
	input wire [AXI_ADDR_WIDTH - 1:0] weight_base_i;
	output reg req_valid_o;
	output reg [AXI_ADDR_WIDTH - 1:0] req_addr_o;
	output reg [7:0] req_len_o;
	input wire req_ready_i;
	input wire [AXI_DATA_WIDTH - 1:0] rdata_i;
	input wire rvalid_i;
	input wire rlast_i;
	output reg rready_o;
	output reg signed [(ARRAY_HEIGHT * WEIGHT_WIDTH) - 1:0] weight_shift_in_o;
	output reg [1:0] weight_shift_en_o;
	output reg done_o;
	reg [1:0] state;
	reg [4:0] beat_cnt;
	reg [31:0] lat_lower_rows;
	wire beat_valid = (state == 2'd2) && (rvalid_i && rready_o);
	always @(*) begin
		if (_sv2v_0)
			;
		if (mode_1x1_i) begin
			weight_shift_en_o[0] = beat_valid;
			weight_shift_en_o[1] = beat_valid;
			weight_shift_in_o[0+:WEIGHT_WIDTH] = $signed(rdata_i[7:0]);
			weight_shift_in_o[WEIGHT_WIDTH+:WEIGHT_WIDTH] = $signed(rdata_i[15:8]);
			weight_shift_in_o[2 * WEIGHT_WIDTH+:WEIGHT_WIDTH] = $signed(rdata_i[23:16]);
			weight_shift_in_o[3 * WEIGHT_WIDTH+:WEIGHT_WIDTH] = $signed(rdata_i[31:24]);
			weight_shift_in_o[4 * WEIGHT_WIDTH+:WEIGHT_WIDTH] = 8'sd0;
			weight_shift_in_o[5 * WEIGHT_WIDTH+:WEIGHT_WIDTH] = 8'sd0;
			weight_shift_in_o[6 * WEIGHT_WIDTH+:WEIGHT_WIDTH] = 8'sd0;
			weight_shift_in_o[7 * WEIGHT_WIDTH+:WEIGHT_WIDTH] = 8'sd0;
		end
		else begin
			weight_shift_en_o[0] = beat_valid && beat_cnt[0];
			weight_shift_en_o[1] = beat_valid && beat_cnt[0];
			weight_shift_in_o[0+:WEIGHT_WIDTH] = $signed(lat_lower_rows[7:0]);
			weight_shift_in_o[WEIGHT_WIDTH+:WEIGHT_WIDTH] = $signed(lat_lower_rows[15:8]);
			weight_shift_in_o[2 * WEIGHT_WIDTH+:WEIGHT_WIDTH] = $signed(lat_lower_rows[23:16]);
			weight_shift_in_o[3 * WEIGHT_WIDTH+:WEIGHT_WIDTH] = $signed(lat_lower_rows[31:24]);
			weight_shift_in_o[4 * WEIGHT_WIDTH+:WEIGHT_WIDTH] = $signed(rdata_i[7:0]);
			weight_shift_in_o[5 * WEIGHT_WIDTH+:WEIGHT_WIDTH] = $signed(rdata_i[15:8]);
			weight_shift_in_o[6 * WEIGHT_WIDTH+:WEIGHT_WIDTH] = $signed(rdata_i[23:16]);
			weight_shift_in_o[7 * WEIGHT_WIDTH+:WEIGHT_WIDTH] = $signed(rdata_i[31:24]);
		end
	end
	always @(posedge clk_i or negedge rst_n)
		if (!rst_n) begin
			state <= 2'd0;
			req_valid_o <= 1'b0;
			req_addr_o <= 1'sb0;
			req_len_o <= 1'sb0;
			rready_o <= 1'b0;
			done_o <= 1'b0;
			beat_cnt <= 1'sb0;
			lat_lower_rows <= 1'sb0;
		end
		else begin
			done_o <= 1'b0;
			case (state)
				2'd0: begin
					req_valid_o <= 1'b0;
					rready_o <= 1'b0;
					if (start_i) begin
						if (mode_1x1_i) begin
							req_addr_o <= weight_base_i + {19'd0, fetch_pass_idx_i, 5'b00000};
							req_len_o <= 8'd7;
						end
						else begin
							req_addr_o <= weight_base_i + {18'd0, fetch_pass_idx_i, 6'b000000};
							req_len_o <= 8'd15;
						end
						req_valid_o <= 1'b1;
						beat_cnt <= 1'sb0;
						state <= 2'd1;
					end
				end
				2'd1:
					if (req_valid_o && req_ready_i) begin
						req_valid_o <= 1'b0;
						rready_o <= 1'b1;
						state <= 2'd2;
					end
				2'd2:
					if (rvalid_i && rready_o) begin
						if (!mode_1x1_i && !beat_cnt[0])
							lat_lower_rows <= rdata_i;
						if (rlast_i || (mode_1x1_i ? beat_cnt == 5'd7 : beat_cnt == 5'd15)) begin
							rready_o <= 1'b0;
							state <= 2'd3;
						end
						else
							beat_cnt <= beat_cnt + 1'b1;
					end
				2'd3: begin
					done_o <= 1'b1;
					state <= 2'd0;
				end
				default: state <= 2'd0;
			endcase
		end
	initial _sv2v_0 = 0;
endmodule
