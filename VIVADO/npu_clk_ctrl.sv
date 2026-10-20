`timescale 1ns / 1ps

/* ===============================================================================================
 * NPU Clock Routing Controller (Vivado Emulation Override)
 * Target: Xilinx Artix-7 (Digilent Nexys Video)
 * Bypasses the ASIC physical clock ladder and drives all NPU banks from the global clock tree.
 * =============================================================================================== */

module npu_clk_ctrl #(
    parameter int NUM_ACT_BANKS     = 8,
    parameter int USE_LADDER_CLOCKS = 0
)(
    input  wire                     clk_i,
    input  wire [NUM_ACT_BANKS-1:0] act_clk_i,
    input  wire                     act_forwarded_core_clk,
    output wire [NUM_ACT_BANKS-1:0] effective_act_clk,
    output wire                     npu_clk_core
);

    assign effective_act_clk = {NUM_ACT_BANKS{clk_i}};
    assign npu_clk_core      = clk_i;

endmodule

