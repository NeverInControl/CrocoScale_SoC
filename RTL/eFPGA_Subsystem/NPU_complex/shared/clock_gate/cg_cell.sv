`timescale 1ns / 1ps

/* ===============================================================================================
 * Behavioral Integrated Clock Gating (ICG) Cell
 *
 * Glitch-free negative-edge latch and AND gate for RTL simulation and generic synthesis.
 * Target-specific filelists swap this module for:
 * - MACROS/Cells/cg_cell.sv (IHP 130nm CMOS5L sg13cmos5l_lgcp_1)
 * - VIVADO/cg_cell.sv       (Xilinx Artix-7 BUFGCE)
 * =============================================================================================== */

module cg_cell (
    input  wire clk_i,
    input  wire enable_i,
    output wire clk_o
);

    reg en_latch;

    always @(clk_i or enable_i) begin
        if (!clk_i) begin
            en_latch <= enable_i;
        end
    end

    assign clk_o = clk_i & en_latch;

endmodule

