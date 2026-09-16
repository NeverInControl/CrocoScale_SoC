// =============================================================================
// File: SOFT_LOGIC/npu_seq_addr_1x1.sv
// Module: npu_seq_addr_1x1
// Project: CrocoScale SoC — 1x1 Half-Array Double-Buffered Address Scheduler
//
// Description:
//   Schedules memory addresses and crossbar routing for 1x1 convolution using
//   half-array double-buffering (Banks 0..3 vs Banks 4..7 ping-pong).
// =============================================================================

`timescale 1ns / 1ps

module npu_seq_addr_1x1 #(
    parameter int ARRAY_HEIGHT = 8
) (
    input  wire [2:0]  state_i,
    input  wire        preload_phase_i,
    input  wire [7:0]  preload_cnt_i,
    input  wire [7:0]  pass_cnt_i,
    input  wire [8:0]  k_cnt_i,
    input  wire [7:0]  total_passes_i,

    output logic [ARRAY_HEIGHT-1:0][3:0] crossbar_sel_o,
    output logic [7:0]                   act_sram_we_o,
    output logic [7:0][8:0]              act_sram_addr_o
);

    localparam logic [2:0] SEQ_PRELOAD = 3'd1;
    localparam logic [2:0] SEQ_COMPUTE = 3'd2;

    wire [2:0] cur_bank_base  = pass_cnt_i[0] ? 3'd4 : 3'd0;
    wire [2:0] next_bank_base = pass_cnt_i[0] ? 3'd0 : 3'd4;
    wire       has_next_pass  = (pass_cnt_i + 1'b1 < total_passes_i);

    always_comb begin
        for (int r = 0; r < ARRAY_HEIGHT; r++) crossbar_sel_o[r] = 4'b1000;
        act_sram_we_o = 8'h00;
        for (int b = 0; b < 8; b++) act_sram_addr_o[b] = 9'd0;

        if (state_i == SEQ_PRELOAD) begin
            // Preload Pass 0 into Banks 0..3 (256 cycles)
            for (int b = 0; b < 4; b++) begin
                act_sram_we_o[b]   = 1'b1;
                act_sram_addr_o[b] = {1'b0, preload_cnt_i};
            end
            for (int b = 4; b < 8; b++) begin
                act_sram_we_o[b]   = 1'b0;
                act_sram_addr_o[b] = 9'd0;
            end
            for (int r = 0; r < ARRAY_HEIGHT; r++) begin
                crossbar_sel_o[r]  = 4'b1000;
            end
        end else if (state_i == SEQ_COMPUTE) begin
            int b_cur;
            int b_nxt;

            // 1. Compute reading from active half
            for (int r = 0; r < 4; r++) begin
                b_cur = cur_bank_base + r;
                crossbar_sel_o[r] = {1'b0, 3'(b_cur)};
                act_sram_we_o[b_cur] = 1'b0;
                if (k_cnt_i >= 9'(r) && (k_cnt_i - 9'(r)) < 9'd256) begin
                    act_sram_addr_o[b_cur] = 9'(k_cnt_i - 9'(r));
                end else begin
                    act_sram_addr_o[b_cur] = 9'd0;
                end
            end

            // Rows 4..7 are grounded
            for (int r = 4; r < 8; r++) begin
                crossbar_sel_o[r] = 4'b1000;
            end

            // 2. Preload writing to alternate half
            if (has_next_pass && k_cnt_i < 9'd256) begin
                for (int b = 0; b < 4; b++) begin
                    b_nxt = next_bank_base + b;
                    act_sram_we_o[b_nxt]   = 1'b1;
                    act_sram_addr_o[b_nxt] = {1'b0, k_cnt_i[7:0]};
                end
            end else begin
                for (int b = 0; b < 4; b++) begin
                    b_nxt = next_bank_base + b;
                    act_sram_we_o[b_nxt]   = 1'b0;
                    act_sram_addr_o[b_nxt] = 9'd0;
                end
            end
        end
    end

endmodule
