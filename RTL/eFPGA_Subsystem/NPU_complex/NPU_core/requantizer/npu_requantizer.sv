`timescale 1ns / 1ps

module npu_requantizer #(
    parameter int CHANNELS         = 8,
    parameter int PSUM_WIDTH       = 32,
    parameter int SCALE_WIDTH      = 16,
    parameter int ACTIVATION_WIDTH = 8,
    parameter bit ENABLE_LFSR      = 0,

    localparam int PROD_WIDTH      = PSUM_WIDTH + SCALE_WIDTH,                    // 64 bits
    localparam int SHIFT_WIDTH     = $clog2(PROD_WIDTH),                          // 6 bits (0..63)
    localparam int CFG_WIDTH       = SCALE_WIDTH + SHIFT_WIDTH + ACTIVATION_WIDTH // 32 + 6 + 8 = 46 bits
)(
    input  wire                                                      clk_i,
    input  wire                                                      rst_n,

    // Vectorized Accumulator Inputs
    input  wire signed [CHANNELS-1:0][PSUM_WIDTH-1:0]               psum_in,

    // Exact-Width Configuration Shift Interface (46 bits per channel)
    input  wire        [CFG_WIDTH-1:0]                               quant_shift_in,
    input  wire                                                      quant_shift_en,

    // Mode Control & LFSR Monitor
    input  wire                                                      stochastic_round_en,
    output wire        [SCALE_WIDTH-1:0]                             lfsr_data_out,

    // Vectorized Quantized Outputs
    output wire signed [CHANNELS-1:0][ACTIVATION_WIDTH-1:0]          act_out
);

    // -------------------------------------------------------------------------
    // 1. Exact 46-bit Configuration Shift Chain
    // -------------------------------------------------------------------------
    reg [CFG_WIDTH-1:0] quant_cfg_chain [0:CHANNELS-1];

    always_ff @(posedge clk_i or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < CHANNELS; i++) begin
                quant_cfg_chain[i] <= '0;
            end
        end else if (quant_shift_en) begin
            quant_cfg_chain[0] <= quant_shift_in;
            for (int i = 1; i < CHANNELS; i++) begin
                quant_cfg_chain[i] <= quant_cfg_chain[i-1];
            end
        end
    end

    // -------------------------------------------------------------------------
    // 2. LFSR Noise Generator
    // -------------------------------------------------------------------------
    localparam int LFSR_WIDTH = SCALE_WIDTH;
    wire [LFSR_WIDTH-1:0] internal_lfsr_bus;

    generate
        if (ENABLE_LFSR) begin : gen_lfsr_core
            npu_prng #(
                .LFSR_WIDTH(LFSR_WIDTH)
            ) prng_inst (
                .clk_i   (clk_i),
                .rst_n   (rst_n),
                .rand_out(internal_lfsr_bus)
            );
            assign lfsr_data_out = internal_lfsr_bus;
        end else begin : gen_no_lfsr
            assign internal_lfsr_bus = '0;
            assign lfsr_data_out     = '0;
        end
    endgenerate

    // -------------------------------------------------------------------------
    // 3. Requantizer Lanes (Unpack Exact 46-bit Bitfields: [31:0], [37:32], [45:38])
    // -------------------------------------------------------------------------
    genvar c;
    generate
        for (c = 0; c < CHANNELS; c++) begin : gen_requant_lanes
            localparam int ROT_STEP = (LFSR_WIDTH >= CHANNELS) ? (LFSR_WIDTH / CHANNELS) : 1;
            localparam int ROT_AMT  = (c * ROT_STEP) % LFSR_WIDTH;
            wire [LFSR_WIDTH-1:0] rotated_noise;

            if (ENABLE_LFSR && (ROT_AMT > 0)) begin : gen_rot_noise
                assign rotated_noise = {internal_lfsr_bus[LFSR_WIDTH-1-ROT_AMT:0], 
                                        internal_lfsr_bus[LFSR_WIDTH-1:LFSR_WIDTH-ROT_AMT]};
            end else if (ENABLE_LFSR) begin : gen_direct_noise
                assign rotated_noise = internal_lfsr_bus;
            end else begin : gen_zero_noise
                assign rotated_noise = '0;
            end

            wire signed [SCALE_WIDTH-1:0]      lane_m0    = quant_cfg_chain[c][SCALE_WIDTH-1 : 0];                          // [31:0]
            wire        [SHIFT_WIDTH-1:0]      lane_shift = quant_cfg_chain[c][SCALE_WIDTH+SHIFT_WIDTH-1 : SCALE_WIDTH];  // [37:32]
            wire signed [ACTIVATION_WIDTH-1:0] lane_zp    = quant_cfg_chain[c][CFG_WIDTH-1 : SCALE_WIDTH+SHIFT_WIDTH];    // [45:38]

            npu_requantizer_lane #(
                .PSUM_WIDTH      (PSUM_WIDTH),
                .SCALE_WIDTH     (SCALE_WIDTH),
                .ACTIVATION_WIDTH(ACTIVATION_WIDTH)
            ) lane_inst (
                .clk_i              (clk_i),
                .rst_n              (rst_n),
                .psum_in            (psum_in[c]),
                .scale_m0           (lane_m0),
                .shift_n            (lane_shift),
                .zero_point         (lane_zp),
                .stochastic_round_en(ENABLE_LFSR ? stochastic_round_en : 1'b0),
                .noise_in           (rotated_noise),
                .act_out            (act_out[c])
            );
        end
    endgenerate

endmodule