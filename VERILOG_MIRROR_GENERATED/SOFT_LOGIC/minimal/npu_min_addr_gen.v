module npu_min_addr_gen (
	clk_i,
	rst_n,
	comp_active_i,
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
	input wire comp_active_i;
	input wire [3:0] pass_idx_i;
	input wire [8:0] comp_k_i;
	output wire [(ARRAY_HEIGHT * ACT_ADDR_WIDTH) - 1:0] act_sram_addr_o;
	wire [ACT_ADDR_WIDTH - 1:0] row0_addr;
	reg [((ARRAY_HEIGHT - 1) >= 1 ? ((ARRAY_HEIGHT - 1) * ACT_ADDR_WIDTH) + (ACT_ADDR_WIDTH - 1) : ((3 - ARRAY_HEIGHT) * ACT_ADDR_WIDTH) + (((ARRAY_HEIGHT - 1) * ACT_ADDR_WIDTH) - 1)):((ARRAY_HEIGHT - 1) >= 1 ? ACT_ADDR_WIDTH : (ARRAY_HEIGHT - 1) * ACT_ADDR_WIDTH)] shift_reg;
	function automatic [ACT_ADDR_WIDTH - 1:0] sv2v_cast_41508;
		input reg [ACT_ADDR_WIDTH - 1:0] inp;
		sv2v_cast_41508 = inp;
	endfunction
	generate
		if (KERNEL_SIZE == 1) begin : gen_1x1
			assign row0_addr = (comp_active_i && (comp_k_i < 9'd256) ? sv2v_cast_41508(comp_k_i) : {ACT_ADDR_WIDTH {1'sb0}});
		end
		else begin : gen_3x3
			reg [ACT_ADDR_WIDTH - 1:0] pass_start_addr;
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
			assign row0_addr = (comp_active_i && (comp_k_i < 9'd256) ? sv2v_cast_41508((pass_start_addr + comp_k_i) + {3'b000, comp_k_i[7:4], 1'b0}) : {ACT_ADDR_WIDTH {1'sb0}});
		end
	endgenerate
	assign act_sram_addr_o[0+:ACT_ADDR_WIDTH] = row0_addr;
	genvar _gv_r_1;
	generate
		for (_gv_r_1 = 1; _gv_r_1 < ARRAY_HEIGHT; _gv_r_1 = _gv_r_1 + 1) begin : gen_shift_out
			localparam r = _gv_r_1;
			assign act_sram_addr_o[r * ACT_ADDR_WIDTH+:ACT_ADDR_WIDTH] = shift_reg[((ARRAY_HEIGHT - 1) >= 1 ? r : 1 - (r - (ARRAY_HEIGHT - 1))) * ACT_ADDR_WIDTH+:ACT_ADDR_WIDTH];
		end
	endgenerate
	always @(posedge clk_i or negedge rst_n)
		if (!rst_n)
			shift_reg <= 1'sb0;
		else begin
			shift_reg[((ARRAY_HEIGHT - 1) >= 1 ? 1 : ARRAY_HEIGHT - 1) * ACT_ADDR_WIDTH+:ACT_ADDR_WIDTH] <= row0_addr;
			begin : sv2v_autoblock_1
				reg signed [31:0] r;
				for (r = 2; r < ARRAY_HEIGHT; r = r + 1)
					shift_reg[((ARRAY_HEIGHT - 1) >= 1 ? r : 1 - (r - (ARRAY_HEIGHT - 1))) * ACT_ADDR_WIDTH+:ACT_ADDR_WIDTH] <= shift_reg[((ARRAY_HEIGHT - 1) >= 1 ? r - 1 : 1 - ((r - 1) - (ARRAY_HEIGHT - 1))) * ACT_ADDR_WIDTH+:ACT_ADDR_WIDTH];
			end
		end
	initial _sv2v_0 = 0;
endmodule
