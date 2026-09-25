module npu_requantizer (
	clk_i,
	rst_n,
	psum_in,
	quant_shift_in,
	quant_shift_en,
	stochastic_round_en,
	lfsr_data_out,
	act_out
);
	parameter signed [31:0] CHANNELS = 8;
	parameter signed [31:0] PSUM_WIDTH = 32;
	parameter signed [31:0] SCALE_WIDTH = 16;
	parameter signed [31:0] ACTIVATION_WIDTH = 8;
	parameter [0:0] ENABLE_LFSR = 0;
	localparam signed [31:0] PROD_WIDTH = PSUM_WIDTH + SCALE_WIDTH;
	localparam signed [31:0] SHIFT_WIDTH = $clog2(PROD_WIDTH);
	localparam signed [31:0] CFG_WIDTH = (SCALE_WIDTH + SHIFT_WIDTH) + ACTIVATION_WIDTH;
	input wire clk_i;
	input wire rst_n;
	input wire signed [(CHANNELS * PSUM_WIDTH) - 1:0] psum_in;
	input wire [CFG_WIDTH - 1:0] quant_shift_in;
	input wire quant_shift_en;
	input wire stochastic_round_en;
	output wire [SCALE_WIDTH - 1:0] lfsr_data_out;
	output wire signed [(CHANNELS * ACTIVATION_WIDTH) - 1:0] act_out;
	reg [CFG_WIDTH - 1:0] quant_cfg_chain [0:CHANNELS - 1];
	always @(posedge clk_i or negedge rst_n)
		if (!rst_n) begin : sv2v_autoblock_1
			reg signed [31:0] i;
			for (i = 0; i < CHANNELS; i = i + 1)
				quant_cfg_chain[i] <= 1'sb0;
		end
		else if (quant_shift_en) begin
			quant_cfg_chain[0] <= quant_shift_in;
			begin : sv2v_autoblock_2
				reg signed [31:0] i;
				for (i = 1; i < CHANNELS; i = i + 1)
					quant_cfg_chain[i] <= quant_cfg_chain[i - 1];
			end
		end
	localparam signed [31:0] LFSR_WIDTH = SCALE_WIDTH;
	wire [LFSR_WIDTH - 1:0] internal_lfsr_bus;
	generate
		if (ENABLE_LFSR) begin : gen_lfsr_core
			npu_prng #(.LFSR_WIDTH(LFSR_WIDTH)) prng_inst(
				.clk_i(clk_i),
				.rst_n(rst_n),
				.rand_out(internal_lfsr_bus)
			);
			assign lfsr_data_out = internal_lfsr_bus;
		end
		else begin : gen_no_lfsr
			assign internal_lfsr_bus = 1'sb0;
			assign lfsr_data_out = 1'sb0;
		end
	endgenerate
	genvar _gv_c_1;
	generate
		for (_gv_c_1 = 0; _gv_c_1 < CHANNELS; _gv_c_1 = _gv_c_1 + 1) begin : gen_requant_lanes
			localparam c = _gv_c_1;
			localparam signed [31:0] ROT_STEP = (LFSR_WIDTH >= CHANNELS ? LFSR_WIDTH / CHANNELS : 1);
			localparam signed [31:0] ROT_AMT = (c * ROT_STEP) % LFSR_WIDTH;
			wire [LFSR_WIDTH - 1:0] rotated_noise;
			if (ENABLE_LFSR && (ROT_AMT > 0)) begin : gen_rot_noise
				assign rotated_noise = {internal_lfsr_bus[(LFSR_WIDTH - 1) - ROT_AMT:0], internal_lfsr_bus[LFSR_WIDTH - 1:LFSR_WIDTH - ROT_AMT]};
			end
			else if (ENABLE_LFSR) begin : gen_direct_noise
				assign rotated_noise = internal_lfsr_bus;
			end
			else begin : gen_zero_noise
				assign rotated_noise = 1'sb0;
			end
			wire signed [SCALE_WIDTH - 1:0] lane_m0 = quant_cfg_chain[c][SCALE_WIDTH - 1:0];
			wire [SHIFT_WIDTH - 1:0] lane_shift = quant_cfg_chain[c][(SCALE_WIDTH + SHIFT_WIDTH) - 1:SCALE_WIDTH];
			wire signed [ACTIVATION_WIDTH - 1:0] lane_zp = quant_cfg_chain[c][CFG_WIDTH - 1:SCALE_WIDTH + SHIFT_WIDTH];
			npu_requantizer_lane #(
				.PSUM_WIDTH(PSUM_WIDTH),
				.SCALE_WIDTH(SCALE_WIDTH),
				.ACTIVATION_WIDTH(ACTIVATION_WIDTH)
			) lane_inst(
				.clk_i(clk_i),
				.rst_n(rst_n),
				.psum_in(psum_in[c * PSUM_WIDTH+:PSUM_WIDTH]),
				.scale_m0(lane_m0),
				.shift_n(lane_shift),
				.zero_point(lane_zp),
				.stochastic_round_en((ENABLE_LFSR ? stochastic_round_en : 1'b0)),
				.noise_in(rotated_noise),
				.act_out(act_out[c * ACTIVATION_WIDTH+:ACTIVATION_WIDTH])
			);
		end
	endgenerate
endmodule
