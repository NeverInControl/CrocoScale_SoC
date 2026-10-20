module npu_clk_ctrl (
	clk_i,
	act_clk_i,
	act_forwarded_core_clk,
	effective_act_clk,
	npu_clk_core
);
	parameter signed [31:0] NUM_ACT_BANKS = 8;
	parameter signed [31:0] USE_LADDER_CLOCKS = 1;
	input wire clk_i;
	input wire [NUM_ACT_BANKS - 1:0] act_clk_i;
	input wire act_forwarded_core_clk;
	output wire [NUM_ACT_BANKS - 1:0] effective_act_clk;
	output wire npu_clk_core;
	assign effective_act_clk = (USE_LADDER_CLOCKS != 0 ? act_clk_i : {NUM_ACT_BANKS {clk_i}});
	assign npu_clk_core = (USE_LADDER_CLOCKS != 0 ? act_forwarded_core_clk : clk_i);
endmodule
