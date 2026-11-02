`timescale 1ns / 1ps

/* ===============================================================================================
 * Unified Integrated Clock Gating (ICG) Cell (Pure IEEE 1364-2001 Verilog)
 *
 * Compiler Directives:
 * - TARGET_ASIC   : IHP 130nm CMOS5L latch-based clock gate cell (sg13cmos5l_lgcp_1)
 * - TARGET_VIVADO : Xilinx dedicated global clock buffer with enable (BUFGCE)
 * - Default       : Behavioral negative-edge latch and AND gate for RTL simulation
 * =============================================================================================== */

`ifdef TARGET_ASIC

(* blackbox *)
module sg13cmos5l_lgcp_1 (
    input  wire CLK,
    input  wire GATE,
    output wire GCLK
);

    reg gate_latch;

    always @(CLK or GATE) begin
        if (!CLK) begin
            gate_latch <= GATE;
        end
    end

    assign GCLK = CLK & gate_latch;

endmodule

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

`elsif TARGET_VIVADO

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

`else

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

`endif

