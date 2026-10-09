`timescale 1ns / 1ps

module npu_requantizer #(
    parameter int CHANNELS         = 8,
    parameter int PSUM_WIDTH       = 32,
    parameter int SCALE_WIDTH      = 16,
    parameter int ACTIVATION_WIDTH = 8,

    localparam int PROD_WIDTH      = PSUM_WIDTH + SCALE_WIDTH,                    // 48 bits
    localparam int SHIFT_WIDTH     = $clog2(PROD_WIDTH),                          // 6 bits (0..63)
    localparam int CFG_WIDTH       = SCALE_WIDTH + SHIFT_WIDTH + ACTIVATION_WIDTH // 16 + 6 + 8 = 30 bits
)(
    input  wire                                                      clk_i,
    input  wire                                                      rst_n,

    // Vectorized Accumulator Inputs
    input  wire signed [CHANNELS-1:0][PSUM_WIDTH-1:0]               psum_in,

    // Exact-Width Configuration Shift Interface (30 bits per channel)
    input  wire        [CFG_WIDTH-1:0]                               quant_shift_in,
    input  wire                                                      quant_shift_en,

    // Vectorized Quantized Outputs
    output wire signed [CHANNELS-1:0][ACTIVATION_WIDTH-1:0]          act_out
);

    // -------------------------------------------------------------------------
    // 1. Exact Configuration Shift Chain (30 bits per channel)
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
    // 2. Requantizer Lanes (Unpack Exact Bitfields: [15:0], [21:16], [29:22])
    // -------------------------------------------------------------------------
    genvar c;
    generate
        for (c = 0; c < CHANNELS; c++) begin : gen_requant_lanes
            wire signed [SCALE_WIDTH-1:0]      lane_m0    = quant_cfg_chain[c][SCALE_WIDTH-1 : 0];                          // [15:0]
            wire        [SHIFT_WIDTH-1:0]      lane_shift = quant_cfg_chain[c][SCALE_WIDTH+SHIFT_WIDTH-1 : SCALE_WIDTH];  // [21:16]
            wire signed [ACTIVATION_WIDTH-1:0] lane_zp    = quant_cfg_chain[c][CFG_WIDTH-1 : SCALE_WIDTH+SHIFT_WIDTH];    // [29:22]

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
                .act_out            (act_out[c])
            );
        end
    endgenerate

endmodule