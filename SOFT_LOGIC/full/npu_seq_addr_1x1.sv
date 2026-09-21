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

    wire has_next_pass = (pass_cnt_i + 1'b1 < total_passes_i);
    wire ping = pass_cnt_i[0];

    always_comb begin
        // Default crossbar routing
        for (int r = 0; r < 4; r++) begin
            crossbar_sel_o[r] = (state_i == SEQ_COMPUTE) ? {1'b0, ping, 2'(r)} : 4'b1000;
        end
        for (int r = 4; r < 8; r++) begin
            crossbar_sel_o[r] = 4'b1000;
        end

        // SRAM Banks 0..3 and 4..7
        for (int r = 0; r < 4; r++) begin
            logic [8:0] m_p;
            logic m_p_valid;
            logic [8:0] compute_addr;
            logic write_active;

            m_p          = k_cnt_i - 9'(r);
            m_p_valid    = (k_cnt_i >= 9'(r)) && !m_p[8];
            compute_addr = m_p_valid ? m_p : 9'd0;
            write_active = has_next_pass && !k_cnt_i[8];

            if (state_i == SEQ_PRELOAD) begin
                act_sram_we_o[r]     = 1'b1;
                act_sram_addr_o[r]   = {1'b0, preload_cnt_i};
                act_sram_we_o[r+4]   = 1'b0;
                act_sram_addr_o[r+4] = 9'd0;
            end else if (state_i == SEQ_COMPUTE) begin
                if (!ping) begin
                    // Bank r is compute read, Bank r+4 is preload write
                    act_sram_we_o[r]     = 1'b0;
                    act_sram_addr_o[r]   = compute_addr;
                    act_sram_we_o[r+4]   = write_active;
                    act_sram_addr_o[r+4] = {1'b0, k_cnt_i[7:0]};
                end else begin
                    // Bank r+4 is compute read, Bank r is preload write
                    act_sram_we_o[r]     = write_active;
                    act_sram_addr_o[r]   = {1'b0, k_cnt_i[7:0]};
                    act_sram_we_o[r+4]   = 1'b0;
                    act_sram_addr_o[r+4] = compute_addr;
                end
            end else begin
                act_sram_we_o[r]     = 1'b0;
                act_sram_addr_o[r]   = 9'd0;
                act_sram_we_o[r+4]   = 1'b0;
                act_sram_addr_o[r+4] = 9'd0;
            end
        end
    end

endmodule
