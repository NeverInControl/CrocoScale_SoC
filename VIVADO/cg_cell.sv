`timescale 1ns / 1ps

/* ===============================================================================================
 * Vivado Emulation Integrated Clock Gating (ICG) Wrapper
 * Target: Xilinx Artix-7 (Digilent Nexys Video)
 * Drop-in replacement for RTL cg_cell.sv using dedicated global clock buffer with enable (BUFGCE).
 * =============================================================================================== */

module cg_cell (
    input  wire clk_i,
    input  wire enable_i,
    output wire clk_o
);

    BUFGCE u_bufgce (
        .I  (clk_i),
        .CE (enable_i),
        .O  (clk_o)
    );

endmodule

