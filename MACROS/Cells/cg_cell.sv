`timescale 1ns / 1ps

/* ===============================================================================================
 * ASIC Integrated Clock Gating (ICG) Wrapper
 * Process: IHP 130nm CMOS5L (sg13cmos5l_stdcell)
 * Drop-in replacement for RTL cg_cell.sv when targeting ASIC physical synthesis.
 * =============================================================================================== */

module cg_cell (
    input  wire clk_i,
    input  wire enable_i,
    output wire clk_o
);

    sg13cmos5l_lgcp_1 u_icg (
        .CLK  (clk_i),
        .GATE (enable_i),
        .GCLK (clk_o)
    );

endmodule

