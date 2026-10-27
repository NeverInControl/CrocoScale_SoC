// =============================================================================
// File: SOFT_LOGIC/flex/npu_flex_fsm.sv
// Module: npu_flex_fsm
// Project: CrocoScale SoC — 8-Bank (4x2) 3x3 Soft-Logic Central FSM
//
// Description:
//   Controls the execution states (IDLE, PRELOAD, COMPUTE, LUT_LOAD, DRAIN,
//   DONE) and progression counters for the 8-bank (4x2) 3x3 convolution
//   soft-logic controller. Synchronizes pass transitions with the AXI4 read
//   engine (dma_pass_ready_i) to tolerate arbitrary multi-master AXI stalls.
// =============================================================================

`timescale 1ns / 1ps

module npu_flex_fsm #(
    parameter int ARRAY_HEIGHT = 8,
    parameter int ARRAY_WIDTH  = 8
) (
    input  wire        clk_i,
    input  wire        rst_n,
    input  wire        start_i,
    input  wire        start_drain_i,
    input  wire        auto_drain_i,
    input  wire        lut_en_i,
    input  wire        pool_s1_en_i,
    input  wire [10:0] total_passes_i,
    input  wire        dma_pass_ready_i,
    input  wire        lut_we_i,
    input  wire        writer_done_i,

    output logic [2:0]  state_o,
    output logic        busy_o,
    output logic        done_o,

    output logic [10:0] pass_cnt_o,
    output logic [8:0]  k_cnt_o,

    output logic        preload_phase_o,
    output logic        lut_phase_o,
    output logic        drain_phase_o,
    output logic [10:0] drain_cnt_o,

    output logic       preload_done_o,
    output logic       pass_advance_o,
    output logic       enter_lut_load_o,
    output logic       prev_pass_drained_o,
    output logic       swap_weights_o
);

    typedef enum logic [2:0] {
        SEQ_IDLE     = 3'd0,
        SEQ_PRELOAD  = 3'd1,
        SEQ_COMPUTE  = 3'd2,
        SEQ_LUT_LOAD = 3'd3,
        SEQ_DRAIN    = 3'd4,
        SEQ_DONE     = 3'd5
    } seq_state_t;

    localparam logic [10:0] LUT_LIMIT = 11'd255;

    seq_state_t state_reg;

    logic [10:0] pass_cnt;
    logic [8:0]  k_cnt;
    logic [10:0] drain_cnt;
    logic        prev_pass_drained;

    wire [10:0] drain_limit = pool_s1_en_i ? 11'd1038 : 11'd270;

    wire is_final_pass  = (pass_cnt == total_passes_i - 1'b1);
    wire preload_done   = (state_reg == SEQ_PRELOAD) && dma_pass_ready_i;
    wire pass_advance   = (state_reg == SEQ_COMPUTE) && !is_final_pass && dma_pass_ready_i &&
                          ((k_cnt == 9'd264) || (k_cnt >= 9'd271));
    wire enter_lut_load = (state_reg == SEQ_COMPUTE) && is_final_pass && (k_cnt == 9'd271) &&
                          auto_drain_i && lut_en_i;

    assign state_o             = state_reg;
    assign pass_cnt_o          = pass_cnt;
    assign k_cnt_o             = k_cnt;
    assign preload_phase_o     = (state_reg == SEQ_PRELOAD);
    assign lut_phase_o         = (state_reg == SEQ_LUT_LOAD);
    assign drain_phase_o       = (state_reg == SEQ_DRAIN);
    assign drain_cnt_o         = drain_cnt;
    assign preload_done_o      = preload_done;
    assign pass_advance_o      = pass_advance;
    assign enter_lut_load_o    = enter_lut_load;
    assign prev_pass_drained_o = prev_pass_drained;
    assign swap_weights_o      = preload_done || pass_advance;

    always_ff @(posedge clk_i) begin
        if (!rst_n) begin
            state_reg         <= SEQ_IDLE;
            busy_o            <= 1'b0;
            done_o            <= 1'b0;
            pass_cnt          <= '0;
            k_cnt             <= '0;
            drain_cnt         <= '0;
            prev_pass_drained <= 1'b0;
        end else begin
            done_o <= 1'b0;

            case (state_reg)
                SEQ_IDLE: begin
                    busy_o <= 1'b0;
                    if (start_i) begin
                        busy_o            <= 1'b1;
                        pass_cnt          <= '0;
                        k_cnt             <= '0;
                        prev_pass_drained <= 1'b0;
                        state_reg         <= SEQ_PRELOAD;
                    end else if (start_drain_i) begin
                        busy_o    <= 1'b1;
                        drain_cnt <= '0;
                        state_reg <= lut_en_i ? SEQ_LUT_LOAD : SEQ_DRAIN;
                    end
                end

                SEQ_PRELOAD: begin
                    if (preload_done) begin
                        pass_cnt          <= '0;
                        k_cnt             <= '0;
                        prev_pass_drained <= 1'b0;
                        state_reg         <= SEQ_COMPUTE;
                    end
                end

                SEQ_COMPUTE: begin
                    if (is_final_pass) begin
                        if (k_cnt == 9'd271) begin
                            k_cnt <= '0;
                            if (auto_drain_i) begin
                                drain_cnt <= '0;
                                state_reg <= lut_en_i ? SEQ_LUT_LOAD : SEQ_DRAIN;
                            end else begin
                                done_o    <= 1'b1;
                                busy_o    <= 1'b0;
                                state_reg <= SEQ_DONE;
                            end
                        end else begin
                            k_cnt <= k_cnt + 1'b1;
                        end
                    end else if (pass_advance) begin
                        k_cnt             <= '0;
                        pass_cnt          <= pass_cnt + 1'b1;
                        prev_pass_drained <= (k_cnt >= 9'd271);
                    end else if (k_cnt < 9'd272) begin
                        k_cnt <= k_cnt + 1'b1;
                    end
                end

                SEQ_LUT_LOAD: begin
                    if (lut_we_i) begin
                        if (drain_cnt == LUT_LIMIT) begin
                            drain_cnt <= '0;
                            state_reg <= SEQ_DRAIN;
                        end else begin
                            drain_cnt <= drain_cnt + 1'b1;
                        end
                    end
                end

                SEQ_DRAIN: begin
                    if (drain_cnt < drain_limit) begin
                        drain_cnt <= drain_cnt + 1'b1;
                    end
                    if (writer_done_i) begin
                        done_o    <= 1'b1;
                        busy_o    <= 1'b0;
                        state_reg <= SEQ_DONE;
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
