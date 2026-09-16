// =============================================================================
// File: SOFT_LOGIC/npu_seq_fsm.sv
// Module: npu_seq_fsm
// Project: CrocoScale SoC — Unified Dual-Mode Soft Sequencer Central FSM
//
// Description:
//   Controls the high-level execution states (IDLE, PRELOAD, COMPUTE, LUT_LOAD,
//   DRAIN, DONE) and progression counters for both 3x3 im2col and 1x1 half-array
//   modes with optional non-linear activation function lookup table support.
// =============================================================================

`timescale 1ns / 1ps

module npu_seq_fsm #(
    parameter int ARRAY_HEIGHT = 8,
    parameter int ARRAY_WIDTH  = 8
) (
    input  wire        clk_i,
    input  wire        rst_n,
    input  wire        start_i,
    input  wire        mode_1x1_i,
    input  wire        lut_en_i,
    input  wire        lut_load_done_i,
    input  wire        drain_done_i,
    input  wire [7:0]  total_passes_i,

    output logic [2:0] state_o,
    output logic       busy_o,
    output logic       done_o,

    output logic [7:0] pass_cnt_o,
    output logic [8:0] k_cnt_o,
    output logic [8:0] pass_len_o,

    output logic       preload_phase_o,
    output logic [7:0] preload_cnt_o,

    output logic       start_lut_load_o,
    output logic       lut_phase_o,

    output logic       drain_phase_o,
    output logic [8:0] drain_cnt_o
);

    typedef enum logic [2:0] {
        SEQ_IDLE     = 3'd0,
        SEQ_PRELOAD  = 3'd1,
        SEQ_COMPUTE  = 3'd2,
        SEQ_LUT_LOAD = 3'd3,
        SEQ_DRAIN    = 3'd4,
        SEQ_DONE     = 3'd5
    } seq_state_t;

    seq_state_t state_reg;

    logic [7:0] preload_cnt;
    logic [7:0] pass_cnt;
    logic [8:0] k_cnt;
    logic [8:0] drain_cnt;

    // Pass length logic:
    // 3x3: regular pass = 265 (256 + 9), final pass = 272 (256 + 16)
    // 1x1: all passes = 272 (256 + 16)
    wire [8:0] cur_pass_len = mode_1x1_i ? 9'd272 :
                              ((pass_cnt == total_passes_i - 1'b1) ? 9'd272 : 9'd265);

    // Preload duration: 54 cycles for 3x3, 256 cycles for 1x1
    wire [7:0] preload_limit = mode_1x1_i ? 8'd255 : 8'd53;


    assign state_o          = state_reg;
    assign pass_cnt_o       = pass_cnt;
    assign k_cnt_o          = k_cnt;
    assign pass_len_o       = cur_pass_len;
    assign preload_phase_o  = (state_reg == SEQ_PRELOAD);
    assign preload_cnt_o    = preload_cnt;
    assign lut_phase_o      = (state_reg == SEQ_LUT_LOAD);
    assign drain_phase_o    = (state_reg == SEQ_DRAIN);
    assign drain_cnt_o      = drain_cnt;

    always_ff @(posedge clk_i or negedge rst_n) begin
        if (!rst_n) begin
            state_reg        <= SEQ_IDLE;
            busy_o           <= 1'b0;
            done_o           <= 1'b0;
            start_lut_load_o <= 1'b0;
            preload_cnt      <= '0;
            pass_cnt         <= '0;
            k_cnt            <= '0;
            drain_cnt        <= '0;
        end else begin
            done_o           <= 1'b0;
            start_lut_load_o <= 1'b0;

            case (state_reg)
                SEQ_IDLE: begin
                    busy_o <= 1'b0;
                    if (start_i) begin
                        busy_o      <= 1'b1;
                        preload_cnt <= '0;
                        state_reg   <= SEQ_PRELOAD;
                    end
                end

                SEQ_PRELOAD: begin
                    if (preload_cnt == preload_limit) begin
                        pass_cnt  <= '0;
                        k_cnt     <= '0;
                        state_reg <= SEQ_COMPUTE;
                    end else begin
                        preload_cnt <= preload_cnt + 1'b1;
                    end
                end

                SEQ_COMPUTE: begin
                    if (k_cnt == cur_pass_len - 1'b1) begin
                        k_cnt <= '0;
                        if (pass_cnt == total_passes_i - 1'b1) begin
                            if (lut_en_i) begin
                                start_lut_load_o <= 1'b1;
                                state_reg        <= SEQ_LUT_LOAD;
                            end else begin
                                drain_cnt <= '0;
                                state_reg <= SEQ_DRAIN;
                            end
                        end else begin
                            pass_cnt <= pass_cnt + 1'b1;
                        end
                    end else begin
                        k_cnt <= k_cnt + 1'b1;
                    end
                end

                SEQ_LUT_LOAD: begin
                    if (lut_load_done_i) begin
                        drain_cnt <= '0;
                        state_reg <= SEQ_DRAIN;
                    end
                end

                SEQ_DRAIN: begin
                    if (drain_done_i) begin
                        done_o    <= 1'b1;
                        busy_o    <= 1'b0;
                        state_reg <= SEQ_DONE;
                    end else begin
                        drain_cnt <= drain_cnt + 1'b1;
                    end
                end

                SEQ_DONE: begin
                    state_reg <= SEQ_IDLE;
                end

                default: state_reg <= SEQ_IDLE;
            endcase
        end
    end

endmodule
