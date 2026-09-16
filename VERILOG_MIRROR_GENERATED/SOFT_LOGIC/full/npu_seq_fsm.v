module npu_seq_fsm (
	clk_i,
	rst_n,
	start_i,
	mode_1x1_i,
	lut_en_i,
	lut_load_done_i,
	drain_done_i,
	total_passes_i,
	state_o,
	busy_o,
	done_o,
	pass_cnt_o,
	k_cnt_o,
	pass_len_o,
	preload_phase_o,
	preload_cnt_o,
	start_lut_load_o,
	lut_phase_o,
	drain_phase_o,
	drain_cnt_o
);
	parameter signed [31:0] ARRAY_HEIGHT = 8;
	parameter signed [31:0] ARRAY_WIDTH = 8;
	input wire clk_i;
	input wire rst_n;
	input wire start_i;
	input wire mode_1x1_i;
	input wire lut_en_i;
	input wire lut_load_done_i;
	input wire drain_done_i;
	input wire [7:0] total_passes_i;
	output wire [2:0] state_o;
	output reg busy_o;
	output reg done_o;
	output wire [7:0] pass_cnt_o;
	output wire [8:0] k_cnt_o;
	output wire [8:0] pass_len_o;
	output wire preload_phase_o;
	output wire [7:0] preload_cnt_o;
	output reg start_lut_load_o;
	output wire lut_phase_o;
	output wire drain_phase_o;
	output wire [8:0] drain_cnt_o;
	reg [2:0] state_reg;
	reg [7:0] preload_cnt;
	reg [7:0] pass_cnt;
	reg [8:0] k_cnt;
	reg [8:0] drain_cnt;
	wire [8:0] cur_pass_len = (mode_1x1_i ? 9'd272 : (pass_cnt == (total_passes_i - 1'b1) ? 9'd272 : 9'd265));
	wire [7:0] preload_limit = (mode_1x1_i ? 8'd255 : 8'd53);
	assign state_o = state_reg;
	assign pass_cnt_o = pass_cnt;
	assign k_cnt_o = k_cnt;
	assign pass_len_o = cur_pass_len;
	assign preload_phase_o = state_reg == 3'd1;
	assign preload_cnt_o = preload_cnt;
	assign lut_phase_o = state_reg == 3'd3;
	assign drain_phase_o = state_reg == 3'd4;
	assign drain_cnt_o = drain_cnt;
	always @(posedge clk_i or negedge rst_n)
		if (!rst_n) begin
			state_reg <= 3'd0;
			busy_o <= 1'b0;
			done_o <= 1'b0;
			start_lut_load_o <= 1'b0;
			preload_cnt <= 1'sb0;
			pass_cnt <= 1'sb0;
			k_cnt <= 1'sb0;
			drain_cnt <= 1'sb0;
		end
		else begin
			done_o <= 1'b0;
			start_lut_load_o <= 1'b0;
			case (state_reg)
				3'd0: begin
					busy_o <= 1'b0;
					if (start_i) begin
						busy_o <= 1'b1;
						preload_cnt <= 1'sb0;
						state_reg <= 3'd1;
					end
				end
				3'd1:
					if (preload_cnt == preload_limit) begin
						pass_cnt <= 1'sb0;
						k_cnt <= 1'sb0;
						state_reg <= 3'd2;
					end
					else
						preload_cnt <= preload_cnt + 1'b1;
				3'd2:
					if (k_cnt == (cur_pass_len - 1'b1)) begin
						k_cnt <= 1'sb0;
						if (pass_cnt == (total_passes_i - 1'b1)) begin
							if (lut_en_i) begin
								start_lut_load_o <= 1'b1;
								state_reg <= 3'd3;
							end
							else begin
								drain_cnt <= 1'sb0;
								state_reg <= 3'd4;
							end
						end
						else
							pass_cnt <= pass_cnt + 1'b1;
					end
					else
						k_cnt <= k_cnt + 1'b1;
				3'd3:
					if (lut_load_done_i) begin
						drain_cnt <= 1'sb0;
						state_reg <= 3'd4;
					end
				3'd4:
					if (drain_done_i) begin
						done_o <= 1'b1;
						busy_o <= 1'b0;
						state_reg <= 3'd5;
					end
					else
						drain_cnt <= drain_cnt + 1'b1;
				3'd5: state_reg <= 3'd0;
				default: state_reg <= 3'd0;
			endcase
		end
endmodule
