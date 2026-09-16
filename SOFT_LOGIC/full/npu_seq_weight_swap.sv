// =============================================================================
// File: SOFT_LOGIC/npu_seq_weight_swap.sv
// Module: npu_seq_weight_swap
// Project: CrocoScale SoC — Unified Sequencer Weight Pre-Shift and Swap Engine
//
// Description:
//   Controls systolic shadow weight register pre-shift timing (k = 32..39)
//   and the single-cycle instantaneous weight swap pulse at the pass boundary.
// =============================================================================

`timescale 1ns / 1ps

module npu_seq_weight_swap (
    input  wire       preload_phase_i,
    input  wire [7:0] preload_cnt_i,
    input  wire [2:0] state_i,
    input  wire [7:0] pass_cnt_i,
    input  wire [8:0] k_cnt_i,
    input  wire [8:0] pass_len_i,
    input  wire [7:0] total_passes_i,

    output logic [1:0] weight_shift_en_o,
    output logic       swap_weights_o,
    output logic [2:0] weight_shift_step_o
);

    localparam logic [2:0] SEQ_COMPUTE = 3'd2;

    always_comb begin
        weight_shift_en_o   = 2'b00;
        swap_weights_o      = 1'b0;
        weight_shift_step_o = 3'd0;

        if (preload_phase_i) begin
            if (preload_cnt_i < 8'd8) begin
                weight_shift_en_o   = 2'b11;
                weight_shift_step_o = preload_cnt_i[2:0];
            end else if (preload_cnt_i == 8'd8) begin
                swap_weights_o      = 1'b1;
            end
        end else if (state_i == SEQ_COMPUTE) begin
            if ((pass_cnt_i + 1'b1 < total_passes_i) && (k_cnt_i >= 9'd32) && (k_cnt_i < 9'd40)) begin
                weight_shift_en_o   = 2'b11;
                weight_shift_step_o = 3'(k_cnt_i - 9'd32);
            end else if ((pass_cnt_i + 1'b1 < total_passes_i) && (k_cnt_i == pass_len_i - 1'b1)) begin
                swap_weights_o      = 1'b1;
            end
        end
    end

endmodule

