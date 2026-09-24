module npu_min_addr_gen (
	clk_i,
	rst_n,
	pass_idx_i,
	comp_k_i,
	act_sram_addr_o
);
	reg _sv2v_0;
	parameter signed [31:0] KERNEL_SIZE = 3;
	parameter signed [31:0] ARRAY_HEIGHT = 8;
	parameter signed [31:0] ACT_ADDR_WIDTH = 9;
	input wire clk_i;
	input wire rst_n;
	input wire [3:0] pass_idx_i;
	input wire [8:0] comp_k_i;
	output reg [(ARRAY_HEIGHT * ACT_ADDR_WIDTH) - 1:0] act_sram_addr_o;
	function automatic [ACT_ADDR_WIDTH - 1:0] sv2v_cast_41508;
		input reg [ACT_ADDR_WIDTH - 1:0] inp;
		sv2v_cast_41508 = inp;
	endfunction
	generate
		if (KERNEL_SIZE == 1) begin : gen_1x1
			always @(posedge clk_i)
				if (!rst_n)
					act_sram_addr_o <= 1'sb0;
				else begin
					act_sram_addr_o[0+:ACT_ADDR_WIDTH] <= (comp_k_i < 9'd256 ? sv2v_cast_41508(comp_k_i) : {ACT_ADDR_WIDTH * 1 {1'sb0}});
					begin : sv2v_autoblock_1
						reg signed [31:0] r;
						for (r = 1; r < ARRAY_HEIGHT; r = r + 1)
							act_sram_addr_o[r * ACT_ADDR_WIDTH+:ACT_ADDR_WIDTH] <= act_sram_addr_o[(r - 1) * ACT_ADDR_WIDTH+:ACT_ADDR_WIDTH];
					end
				end
		end
		else begin : gen_3x3
			reg [ACT_ADDR_WIDTH - 1:0] pass_start_addr;
			wire [ACT_ADDR_WIDTH - 1:0] next_row0_addr;
			reg [3:0] col_cnt_reg;
			always @(*) begin
				if (_sv2v_0)
					;
				case (pass_idx_i)
					4'd0: pass_start_addr = 9'd0;
					4'd1: pass_start_addr = 9'd1;
					4'd2: pass_start_addr = 9'd2;
					4'd3: pass_start_addr = 9'd18;
					4'd4: pass_start_addr = 9'd19;
					4'd5: pass_start_addr = 9'd20;
					4'd6: pass_start_addr = 9'd36;
					4'd7: pass_start_addr = 9'd37;
					4'd8: pass_start_addr = 9'd38;
					default: pass_start_addr = 9'd0;
				endcase
			end
			assign next_row0_addr = (comp_k_i == 9'd0 ? pass_start_addr : act_sram_addr_o[0+:ACT_ADDR_WIDTH] + {7'd0, &col_cnt_reg, 1'b1});
			always @(posedge clk_i)
				if (!rst_n) begin
					col_cnt_reg <= 1'sb0;
					act_sram_addr_o <= 1'sb0;
				end
				else begin
					if (comp_k_i == 9'd0)
						col_cnt_reg <= 4'd0;
					else if (comp_k_i < 9'd256)
						col_cnt_reg <= col_cnt_reg + 1'b1;
					act_sram_addr_o[0+:ACT_ADDR_WIDTH] <= (comp_k_i < 9'd256 ? next_row0_addr : {ACT_ADDR_WIDTH * 1 {1'sb0}});
					begin : sv2v_autoblock_2
						reg signed [31:0] r;
						for (r = 1; r < ARRAY_HEIGHT; r = r + 1)
							act_sram_addr_o[r * ACT_ADDR_WIDTH+:ACT_ADDR_WIDTH] <= act_sram_addr_o[(r - 1) * ACT_ADDR_WIDTH+:ACT_ADDR_WIDTH];
					end
				end
		end
	endgenerate
	initial _sv2v_0 = 0;
endmodule
