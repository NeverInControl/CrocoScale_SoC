// =============================================================================
// File: SOFT_LOGIC/npu_seq_arbiter.sv
// Module: npu_seq_arbiter
// Project: CrocoScale SoC — Unified Sequencer Memory & Crossbar Arbiter
//
// Description:
//   Multiplexes memory write enables, memory addresses, and systolic crossbar
//   selections between 3x3 im2col mode and 1x1 half-array mode.
// =============================================================================

`timescale 1ns / 1ps

module npu_seq_arbiter #(
    parameter int ARRAY_HEIGHT = 8
) (
    input  wire                                 mode_1x1_i,

    input  wire [ARRAY_HEIGHT-1:0][3:0]         crossbar_sel_3x3_i,
    input  wire [5:0]                           act_sram_we_3x3_i,
    input  wire [5:0][8:0]                      act_sram_addr_3x3_i,

    input  wire [ARRAY_HEIGHT-1:0][3:0]         crossbar_sel_1x1_i,
    input  wire [7:0]                           act_sram_we_1x1_i,
    input  wire [7:0][8:0]                      act_sram_addr_1x1_i,

    output logic [ARRAY_HEIGHT-1:0][3:0]        crossbar_sel_o,
    output logic [7:0]                          act_sram_we_o,
    output logic [7:0][8:0]                     act_sram_addr_o
);

    always_comb begin
        if (mode_1x1_i) begin
            crossbar_sel_o  = crossbar_sel_1x1_i;
            act_sram_we_o   = act_sram_we_1x1_i;
            act_sram_addr_o = act_sram_addr_1x1_i;
        end else begin
            crossbar_sel_o  = crossbar_sel_3x3_i;
            act_sram_we_o   = {2'b00, act_sram_we_3x3_i};
            act_sram_addr_o = {9'd0, 9'd0, act_sram_addr_3x3_i};
        end
    end

endmodule

