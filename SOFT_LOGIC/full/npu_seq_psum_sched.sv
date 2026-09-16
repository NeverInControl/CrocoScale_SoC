// =============================================================================
// File: SOFT_LOGIC/npu_seq_psum_sched.sv
// Module: npu_seq_psum_sched
// Project: CrocoScale SoC — Unified Sequencer PSUM Accumulation & Drain Scheduler
//
// Description:
//   Manages dual ping-pong PSUM SRAM banks (A and B). Schedules read addresses,
//   skew-compensated write enables, inter-pass trailing writes, and output drain.
//   Asserts psum_lut_en_o during the drain phase when non-linear LUT mode is enabled.
// =============================================================================

`timescale 1ns / 1ps

module npu_seq_psum_sched #(
    parameter int ARRAY_WIDTH = 8
) (
    input  wire [2:0] state_i,
    input  wire       preload_phase_i,
    input  wire [7:0] preload_cnt_i,
    input  wire [7:0] pass_cnt_i,
    input  wire [8:0] k_cnt_i,
    input  wire       drain_phase_i,
    input  wire [8:0] drain_cnt_i,
    input  wire [7:0] total_passes_i,
    input  wire       lut_en_i,

    output logic       swap_val_o,
    output logic       psum_lut_en_o,
    output logic [7:0] psum_A_addr_o,
    output logic [ARRAY_WIDTH-1:0] psum_A_we_o,
    output logic [7:0] psum_B_addr_o,
    output logic [ARRAY_WIDTH-1:0] psum_B_we_o
);

    localparam logic [2:0] SEQ_PRELOAD  = 3'd1;
    localparam logic [2:0] SEQ_COMPUTE  = 3'd2;
    localparam logic [2:0] SEQ_LUT_LOAD = 3'd3;
    localparam logic [2:0] SEQ_DRAIN    = 3'd4;

    // Alternating ping-pong flag
    wire swap_val = (total_passes_i % 2 == 0) ? (pass_cnt_i[0] ? 1'b1 : 1'b0)
                                              : (pass_cnt_i[0] ? 1'b0 : 1'b1);
    wire hold_bias_addr = (pass_cnt_i == 8'd0);

    assign swap_val_o    = swap_val;
    assign psum_lut_en_o = (state_i == SEQ_DRAIN) && lut_en_i;

    // Address routing for Bank A
    assign psum_A_addr_o = (state_i == SEQ_DRAIN) ? ((drain_cnt_i < 9'd256) ? drain_cnt_i[7:0] : 8'h00) :
                           (state_i == SEQ_COMPUTE) ? (!swap_val ? (hold_bias_addr ? 8'h00 : ((k_cnt_i < 9'd256) ? k_cnt_i[7:0] : 8'h00)) :
                                                                   ((k_cnt_i >= 9'd9 && (k_cnt_i - 9'd9) < 9'd256) ? 8'(k_cnt_i - 9'd9) : 8'h00)) : 8'h00;

    // Address routing for Bank B
    assign psum_B_addr_o = (state_i == SEQ_COMPUTE) ? (swap_val ? (hold_bias_addr ? 8'h00 : ((k_cnt_i < 9'd256) ? k_cnt_i[7:0] : 8'h00)) :
                                                                  ((k_cnt_i >= 9'd9 && (k_cnt_i - 9'd9) < 9'd256) ? 8'(k_cnt_i - 9'd9) : 8'h00)) : 8'h00;

    // Write enables across ARRAY_WIDTH columns
    for (genvar gc = 0; gc < ARRAY_WIDTH; gc++) begin : gen_psum_we
        assign psum_A_we_o[gc] = (state_i == SEQ_PRELOAD && !swap_val && preload_cnt_i == 8'(gc)) ? 1'b1 :
                                 (state_i == SEQ_COMPUTE && !swap_val && pass_cnt_i > 8'd0 && k_cnt_i < 9'(gc)) ? 1'b1 :
                                 (state_i == SEQ_COMPUTE && swap_val && (k_cnt_i >= 9'(9 + gc) && (k_cnt_i - 9'(9 + gc)) < 9'd256)) ? 1'b1 : 1'b0;

        assign psum_B_we_o[gc] = (state_i == SEQ_PRELOAD && swap_val && preload_cnt_i == 8'(gc)) ? 1'b1 :
                                 (state_i == SEQ_COMPUTE && swap_val && pass_cnt_i > 8'd0 && k_cnt_i < 9'(gc)) ? 1'b1 :
                                 (state_i == SEQ_COMPUTE && !swap_val && (k_cnt_i >= 9'(9 + gc) && (k_cnt_i - 9'(9 + gc)) < 9'd256)) ? 1'b1 : 1'b0;
    end

endmodule
