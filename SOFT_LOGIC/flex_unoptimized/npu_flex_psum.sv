// =============================================================================
// File: SOFT_LOGIC/flex/npu_flex_psum.sv
// Module: npu_flex_psum
// Project: CrocoScale SoC — 8-Bank (4x2) PSUM Accumulation & Drain Scheduler
//
// Description:
//   Manages dual ping-pong PSUM SRAM banks (A and B). Schedules AXI bias preload
//   writes during SEQ_PRELOAD, systolic read/write addresses, skew-compensated
//   column write enables, non-linear LUT table preload (SEQ_LUT_LOAD), and
//   256-pixel output drain (SEQ_DRAIN).
// =============================================================================

`timescale 1ns / 1ps

module npu_flex_psum #(
    parameter int ARRAY_WIDTH = 8,
    parameter int PSUM_WIDTH  = 32
) (
    input  wire                        [2:0]  state_i,
    input  wire                        [10:0] pass_cnt_i,
    input  wire                        [8:0]  k_cnt_i,
    input  wire                        [10:0] drain_cnt_i,
    input  wire                        [10:0] total_passes_i,
    input  wire                               lut_en_i,
    input  wire                               pool_en_i,
    input  wire                               pool_s1_en_i,
    input  wire                        [4:0]  tile_y_i,
    input  wire                        [4:0]  tile_x_i,
    input  wire                        [8:0]  img_h_i,
    input  wire                        [8:0]  img_w_i,
    input  wire                               prev_pass_drained_i,

    // AXI Reader Bias & LUT Write Inputs
    input  wire signed [PSUM_WIDTH-1:0]      bias_wdata_i,
    input  wire        [ARRAY_WIDTH-1:0]     bias_we_i,
    input  wire        [7:0]                 lut_wdata_i,
    input  wire                              lut_we_i,

    output logic                             swap_val_o,
    output logic                             psum_lut_en_o,
    output logic       [7:0]                 psum_A_addr_o,
    output logic       [ARRAY_WIDTH-1:0]     psum_A_we_o,
    output logic signed [PSUM_WIDTH-1:0]     psum_A_wdata_o,
    output logic       [7:0]                 psum_B_addr_o,
    output logic       [ARRAY_WIDTH-1:0]     psum_B_we_o,
    output logic signed [PSUM_WIDTH-1:0]     psum_B_wdata_o
);

    localparam logic [2:0] SEQ_PRELOAD  = 3'd1;
    localparam logic [2:0] SEQ_COMPUTE  = 3'd2;
    localparam logic [2:0] SEQ_LUT_LOAD = 3'd3;
    localparam logic [2:0] SEQ_DRAIN    = 3'd4;

    // Alternating ping-pong flag ensuring final pass always lands in Bank A
    wire swap_val       = (total_passes_i[0] == 1'b0) ? pass_cnt_i[0] : ~pass_cnt_i[0];
    wire hold_bias_addr = (pass_cnt_i == 11'd0);

    assign swap_val_o     = swap_val;
    assign psum_lut_en_o  = (state_i == SEQ_DRAIN) && lut_en_i;

    always_comb begin
        psum_A_wdata_o = bias_wdata_i;
        psum_B_wdata_o = (state_i == SEQ_LUT_LOAD) ? $signed({24'd0, lut_wdata_i}) : bias_wdata_i;
    end

    // Skewed drain address generator:
    //   Unpooled (pool_en_i = 0, pool_s1_en_i = 0): {s_rel[1:0], r_sub[1:0], tx[3:0]}
    //   2x2 Stride-2 MaxPool (pool_en_i = 1):       {s_rel[0], r_sub[1:0], dy, px[2:0], dx}
    //   2x2 Stride-1 MaxPool (pool_s1_en_i = 1):    {ty_s1[3:0], tx_s1[3:0]} over 1024 cycles
    wire [7:0] d_idx      = (drain_cnt_i < 11'd256)  ? drain_cnt_i[7:0] : 8'h00;
    wire [9:0] d10        = (drain_cnt_i < 11'd1024) ? drain_cnt_i[9:0] : 10'd0;
    wire [3:0] base_ty    = {d10[9:8], d10[3:2]};
    wire [3:0] base_tx    = d10[7:4];
    wire [9:0] gy_s1      = {1'b0, tile_y_i, base_ty};
    wire [9:0] gx_s1      = {1'b0, tile_x_i, base_tx};
    wire       can_inc_y  = (base_ty != 4'd15) && ((gy_s1 + 10'd1) < {1'b0, img_h_i});
    wire       can_inc_x  = (base_tx != 4'd15) && ((gx_s1 + 10'd1) < {1'b0, img_w_i});
    wire [3:0] ty_s1      = (d10[1] && can_inc_y) ? (base_ty + 4'd1) : base_ty;
    wire [3:0] tx_s1      = (d10[0] && can_inc_x) ? (base_tx + 4'd1) : base_tx;

    wire [7:0] drain_addr = pool_s1_en_i ? {ty_s1, tx_s1} :
                            pool_en_i    ? {d_idx[7], d_idx[3:2], d_idx[1], d_idx[6:4], d_idx[0]} :
                                           {d_idx[7:6], d_idx[1:0], d_idx[5:2]};

    // Address routing for Bank A
    assign psum_A_addr_o = (state_i == SEQ_DRAIN)   ? drain_addr :
                           (state_i == SEQ_COMPUTE) ? (!swap_val ? (hold_bias_addr ? 8'h00 : ((k_cnt_i < 9'd256) ? k_cnt_i[7:0] : 8'h00)) :
                                                                   ((k_cnt_i >= 9'd9 && (k_cnt_i - 9'd9) < 9'd256) ? 8'(k_cnt_i - 9'd9) : 8'h00)) : 8'h00;

    // Address routing for Bank B (includes LUT load address sweep 0..255)
    assign psum_B_addr_o = (state_i == SEQ_LUT_LOAD) ? drain_cnt_i[7:0] :
                           (state_i == SEQ_COMPUTE)  ? (swap_val ? (hold_bias_addr ? 8'h00 : ((k_cnt_i < 9'd256) ? k_cnt_i[7:0] : 8'h00)) :
                                                                   ((k_cnt_i >= 9'd9 && (k_cnt_i - 9'd9) < 9'd256) ? 8'(k_cnt_i - 9'd9) : 8'h00)) : 8'h00;

    // Write enables across ARRAY_WIDTH columns
    for (genvar gc = 0; gc < ARRAY_WIDTH; gc++) begin : gen_psum_we
        assign psum_A_we_o[gc] = (state_i == SEQ_PRELOAD && !swap_val) ? bias_we_i[gc] :
                                 (state_i == SEQ_COMPUTE && !swap_val && pass_cnt_i > 11'd0 && !prev_pass_drained_i && k_cnt_i < 9'(gc)) ? 1'b1 :
                                 (state_i == SEQ_COMPUTE && swap_val && (k_cnt_i >= 9'(9 + gc) && (k_cnt_i - 9'(9 + gc)) < 9'd256)) ? 1'b1 : 1'b0;

        assign psum_B_we_o[gc] = (state_i == SEQ_LUT_LOAD) ? lut_we_i :
                                 (state_i == SEQ_PRELOAD && swap_val) ? bias_we_i[gc] :
                                 (state_i == SEQ_COMPUTE && swap_val && pass_cnt_i > 11'd0 && !prev_pass_drained_i && k_cnt_i < 9'(gc)) ? 1'b1 :
                                 (state_i == SEQ_COMPUTE && !swap_val && (k_cnt_i >= 9'(9 + gc) && (k_cnt_i - 9'(9 + gc)) < 9'd256)) ? 1'b1 : 1'b0;
    end

endmodule

