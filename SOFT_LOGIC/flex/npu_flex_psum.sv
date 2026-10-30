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
    input  wire                        [4:0]  shared_end_x_i,
    input  wire                        [3:0]  shared_row_lt_h_i,
    output logic                       [1:0]  s1_ty_hi_o,
    input  wire                               first_pass_i,
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

    wire unused_ok = &{1'b0, pass_cnt_i[10:1], total_passes_i, drain_cnt_i[10]};

    // Alternating ping-pong flag ensuring final pass (pass_cnt_i == 0) always lands in Bank A
    wire swap_val       = ~pass_cnt_i[0];
    wire hold_bias_addr = first_pass_i;

    assign swap_val_o    = swap_val;
    assign psum_lut_en_o = (state_i == SEQ_DRAIN) && lut_en_i;

    always_comb begin
        psum_A_wdata_o = bias_wdata_i;
        psum_B_wdata_o = $signed({bias_wdata_i[31:8], lut_wdata_i});
    end

    // Skewed drain address generator:
    //   Unpooled (pool_en_i = 0, pool_s1_en_i = 0): {s_rel[1:0], r_sub[1:0], tx[3:0]}
    //   2x2 Stride-2 MaxPool (pool_en_i = 1):       {s_rel[0], r_sub[1:0], dy, px[2:0], dx}
    //   2x2 Stride-1 MaxPool (pool_s1_en_i = 1):    {ty_s1[3:0], tx_s1[3:0]} over 1024 cycles
    wire [7:0] d_idx      = drain_cnt_i[7:0];
    wire [9:0] d10        = drain_cnt_i[9:0];
    wire [3:0] base_ty    = {d10[9:8], d10[3:2]};
    wire [3:0] base_tx    = d10[7:4];
    wire [3:0] base_ty_p1 = base_ty + 4'd1;
    wire [3:0] base_tx_p1 = base_tx + 4'd1;
    assign s1_ty_hi_o     = base_ty_p1[3:2];
    wire       can_inc_y  = (base_ty != 4'd15) && shared_row_lt_h_i[base_ty_p1[1:0]];
    wire       can_inc_x  = (base_tx != 4'd15) && (shared_end_x_i[4] || (base_tx_p1 < shared_end_x_i[3:0]));
    wire [3:0] ty_s1      = (d10[1] && can_inc_y) ? base_ty_p1 : base_ty;
    wire [3:0] tx_s1      = (d10[0] && can_inc_x) ? base_tx_p1 : base_tx;

    wire [7:0] drain_addr = pool_s1_en_i ? {ty_s1, tx_s1} :
                            pool_en_i    ? {d_idx[7], d_idx[3:2], d_idx[1], d_idx[6:4], d_idx[0]} :
                                           {d_idx[7:6], d_idx[1:0], d_idx[5:2]};

    // Shared compute read/write PSUM addresses and 9-cycle skew subtractor
    wire [8:0] k_m9       = k_cnt_i - 9'd9;
    wire       k_m9_hi_m1 = (k_m9[8:3] == 6'd0) || (k_m9[8] && (|k_m9[7:3]));
    wire [7:0] rd_addr    = (hold_bias_addr || k_cnt_i[8]) ? 8'h00 : k_cnt_i[7:0];
    wire [7:0] wr_addr    = k_m9[8] ? 8'h00 : k_m9[7:0];

    assign psum_A_addr_o = (state_i == SEQ_DRAIN)   ? drain_addr :
                           (state_i == SEQ_COMPUTE) ? (swap_val ? wr_addr : rd_addr) : 8'h00;

    assign psum_B_addr_o = (state_i == SEQ_LUT_LOAD) ? d_idx :
                           (state_i == SEQ_COMPUTE)  ? (swap_val ? rd_addr : wr_addr) : 8'h00;

    wire clr_en_base = (state_i == SEQ_COMPUTE) && !hold_bias_addr && !prev_pass_drained_i && (k_cnt_i[8:3] == 6'd0);

    // Write enables across ARRAY_WIDTH columns
    for (genvar gc = 0; gc < ARRAY_WIDTH; gc++) begin : gen_psum_we
        wire borrow_gc = (k_m9[2:0] < 3'(gc));
        wire wr_in_win = (state_i == SEQ_COMPUTE) && !(borrow_gc ? k_m9_hi_m1 : k_m9[8]);
        wire clr_in_win = clr_en_base && (k_cnt_i[2:0] < 3'(gc));

        assign psum_A_we_o[gc] = (state_i == SEQ_PRELOAD && !swap_val) ? bias_we_i[gc] :
                                 (!swap_val ? clr_in_win : wr_in_win);

        assign psum_B_we_o[gc] = (state_i == SEQ_LUT_LOAD)            ? lut_we_i :
                                 (state_i == SEQ_PRELOAD && swap_val) ? bias_we_i[gc] :
                                 (swap_val ? clr_in_win : wr_in_win);
    end

endmodule
