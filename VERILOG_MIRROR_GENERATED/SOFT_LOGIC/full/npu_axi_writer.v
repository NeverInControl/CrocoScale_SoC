module npu_axi_writer (
	clk_i,
	rst_n,
	start_i,
	lut_en_i,
	pool_en_i,
	out_base_i,
	drain_psum_addr_o,
	npu_out_act_i,
	awaddr_o,
	awlen_o,
	awsize_o,
	awburst_o,
	awvalid_o,
	awready_i,
	wdata_o,
	wstrb_o,
	wlast_o,
	wvalid_o,
	wready_i,
	bresp_i,
	bvalid_i,
	bready_o,
	done_o
);
	reg _sv2v_0;
	parameter signed [31:0] ARRAY_WIDTH = 8;
	parameter signed [31:0] ACTIVATION_WIDTH = 8;
	input wire clk_i;
	input wire rst_n;
	input wire start_i;
	input wire lut_en_i;
	input wire pool_en_i;
	input wire [31:0] out_base_i;
	output reg [7:0] drain_psum_addr_o;
	input wire signed [(ARRAY_WIDTH * ACTIVATION_WIDTH) - 1:0] npu_out_act_i;
	output wire [31:0] awaddr_o;
	output wire [7:0] awlen_o;
	output wire [2:0] awsize_o;
	output wire [1:0] awburst_o;
	output reg awvalid_o;
	input wire awready_i;
	output reg [31:0] wdata_o;
	output wire [3:0] wstrb_o;
	output reg wlast_o;
	output reg wvalid_o;
	input wire wready_i;
	input wire [1:0] bresp_i;
	input wire bvalid_i;
	output reg bready_o;
	output reg done_o;
	reg [3:0] state;
	reg [5:0] drain_burst_idx;
	reg [4:0] drain_w_beat;
	reg [4:0] stream_cnt;
	reg signed [(ARRAY_WIDTH * ACTIVATION_WIDTH) - 1:0] max_accum;
	reg [31:0] lat_upper;
	wire axi_w_stall = wvalid_o && !wready_i;
	wire [5:0] next_req_idx = {1'b0, stream_cnt} + (lut_en_i ? 6'd5 : 6'd4);
	function automatic signed [ACTIVATION_WIDTH - 1:0] signed_max;
		input reg signed [ACTIVATION_WIDTH - 1:0] a;
		input reg signed [ACTIVATION_WIDTH - 1:0] b;
		signed_max = ($signed(a) > $signed(b) ? a : b);
	endfunction
	reg signed [(ARRAY_WIDTH * ACTIVATION_WIDTH) - 1:0] next_max;
	always @(*) begin
		if (_sv2v_0)
			;
		begin : sv2v_autoblock_1
			reg signed [31:0] c;
			for (c = 0; c < ARRAY_WIDTH; c = c + 1)
				next_max[c * ACTIVATION_WIDTH+:ACTIVATION_WIDTH] = signed_max(max_accum[c * ACTIVATION_WIDTH+:ACTIVATION_WIDTH], npu_out_act_i[c * ACTIVATION_WIDTH+:ACTIVATION_WIDTH]);
		end
	end
	wire [7:0] burst_base_p = {drain_burst_idx[4:0], 3'b000};
	assign awaddr_o = out_base_i + {19'd0, drain_burst_idx, 6'b000000};
	assign awlen_o = 8'd15;
	assign awsize_o = 3'b010;
	assign awburst_o = 2'b01;
	assign wstrb_o = 4'hf;
	function automatic [7:0] sv2v_cast_8;
		input reg [7:0] inp;
		sv2v_cast_8 = inp;
	endfunction
	always @(posedge clk_i)
		if (!rst_n) begin
			state <= 4'd0;
			drain_burst_idx <= 1'sb0;
			drain_w_beat <= 1'sb0;
			drain_psum_addr_o <= 1'sb0;
			stream_cnt <= 1'sb0;
			max_accum <= 1'sb0;
			lat_upper <= 1'sb0;
			done_o <= 1'b0;
			awvalid_o <= 1'b0;
			wdata_o <= 1'sb0;
			wlast_o <= 1'b0;
			wvalid_o <= 1'b0;
			bready_o <= 1'b0;
		end
		else begin
			done_o <= 1'b0;
			if (awvalid_o && awready_i)
				awvalid_o <= 1'b0;
			case (state)
				4'd0: begin
					awvalid_o <= 1'b0;
					wvalid_o <= 1'b0;
					bready_o <= 1'b0;
					if (start_i) begin
						drain_burst_idx <= 1'sb0;
						state <= 4'd1;
					end
				end
				4'd1: begin
					awvalid_o <= 1'b1;
					drain_w_beat <= 1'sb0;
					if (awvalid_o && awready_i) begin
						awvalid_o <= 1'b0;
						if (pool_en_i) begin
							stream_cnt <= 5'd0;
							drain_psum_addr_o <= {drain_burst_idx[2:0], 5'h00};
						end
						else
							drain_psum_addr_o <= {burst_base_p[7:3], 3'b000};
						state <= 4'd2;
					end
				end
				4'd2: begin
					if (pool_en_i)
						drain_psum_addr_o <= {drain_burst_idx[2:0], 5'h01};
					state <= 4'd3;
				end
				4'd3: begin
					if (pool_en_i)
						drain_psum_addr_o <= {drain_burst_idx[2:0], 5'h10};
					else
						drain_psum_addr_o <= {burst_base_p[7:3], 3'b001};
					state <= 4'd4;
				end
				4'd4:
					if (pool_en_i) begin
						drain_psum_addr_o <= {drain_burst_idx[2:0], 5'h11};
						if (!lut_en_i)
							state <= 4'd11;
						else
							state <= 4'd5;
					end
					else
						state <= 4'd5;
				4'd5:
					if (pool_en_i) begin
						drain_psum_addr_o <= {drain_burst_idx[2:0], 5'h02};
						state <= 4'd11;
					end
					else begin
						drain_psum_addr_o <= {burst_base_p[7:3], 3'b010};
						state <= 4'd6;
					end
				4'd6: begin
					lat_upper <= {npu_out_act_i[7 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH], npu_out_act_i[6 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH], npu_out_act_i[5 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH], npu_out_act_i[4 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH]};
					wdata_o <= {npu_out_act_i[3 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH], npu_out_act_i[2 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH], npu_out_act_i[ACTIVATION_WIDTH+:ACTIVATION_WIDTH], npu_out_act_i[0+:ACTIVATION_WIDTH]};
					wvalid_o <= 1'b1;
					wlast_o <= 1'b0;
					drain_w_beat <= 1'sb0;
					state <= 4'd7;
				end
				4'd7:
					if (wready_i && wvalid_o) begin
						if (drain_w_beat == 5'd15) begin
							wvalid_o <= 1'b0;
							wlast_o <= 1'b0;
							bready_o <= 1'b1;
							state <= 4'd8;
						end
						else begin
							drain_w_beat <= drain_w_beat + 1'b1;
							if (drain_w_beat[0] == 1'b0) begin
								wdata_o <= lat_upper;
								if (drain_w_beat == 5'd14)
									wlast_o <= 1'b1;
								if (drain_w_beat <= 5'd8)
									drain_psum_addr_o <= burst_base_p + sv2v_cast_8((drain_w_beat >> 1) + 3);
							end
							else begin
								lat_upper <= {npu_out_act_i[7 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH], npu_out_act_i[6 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH], npu_out_act_i[5 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH], npu_out_act_i[4 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH]};
								wdata_o <= {npu_out_act_i[3 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH], npu_out_act_i[2 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH], npu_out_act_i[ACTIVATION_WIDTH+:ACTIVATION_WIDTH], npu_out_act_i[0+:ACTIVATION_WIDTH]};
							end
						end
					end
				4'd11:
					if (!axi_w_stall) begin
						stream_cnt <= stream_cnt + 1'b1;
						if (next_req_idx < 6'd32)
							drain_psum_addr_o <= {drain_burst_idx[2:0], next_req_idx[1], next_req_idx[4:2], next_req_idx[0]};
						case (stream_cnt[1:0])
							2'd0: begin
								max_accum <= npu_out_act_i;
								if (stream_cnt > 5'd0) begin
									wdata_o <= lat_upper;
									wvalid_o <= 1'b1;
									drain_w_beat <= drain_w_beat + 1'b1;
								end
							end
							2'd1: begin
								max_accum <= next_max;
								wvalid_o <= 1'b0;
							end
							2'd2: max_accum <= next_max;
							2'd3: begin
								wdata_o <= {next_max[3 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH], next_max[2 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH], next_max[ACTIVATION_WIDTH+:ACTIVATION_WIDTH], next_max[0+:ACTIVATION_WIDTH]};
								lat_upper <= {next_max[7 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH], next_max[6 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH], next_max[5 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH], next_max[4 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH]};
								wvalid_o <= 1'b1;
								drain_w_beat <= drain_w_beat + 1'b1;
								if (stream_cnt == 5'd31)
									state <= 4'd12;
							end
						endcase
					end
				4'd12:
					if (wvalid_o && wready_i) begin
						if (wlast_o) begin
							wvalid_o <= 1'b0;
							wlast_o <= 1'b0;
							bready_o <= 1'b1;
							state <= 4'd8;
						end
						else begin
							wdata_o <= lat_upper;
							wvalid_o <= 1'b1;
							wlast_o <= 1'b1;
							drain_w_beat <= drain_w_beat + 1'b1;
						end
					end
				4'd8:
					if (bvalid_i && bready_o) begin
						bready_o <= 1'b0;
						if (drain_burst_idx == (pool_en_i ? 6'd7 : 6'd31))
							state <= 4'd9;
						else begin
							drain_burst_idx <= drain_burst_idx + 1'b1;
							state <= 4'd1;
						end
					end
				4'd9: begin
					done_o <= 1'b1;
					state <= 4'd10;
				end
				4'd10:
					if (!start_i)
						state <= 4'd0;
				default: state <= 4'd0;
			endcase
		end
	initial _sv2v_0 = 0;
endmodule
