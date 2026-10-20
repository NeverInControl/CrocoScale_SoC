`timescale 1ns / 1ps

/* ===============================================================================================
 * IHP SG13CMOS5L Latch-Based Clock Gating Cell Behavioral / Blackbox Model
 * Process: IHP 130nm CMOS5L (sg13cmos5l_stdcell)
 * Cell: sg13cmos5l_lgcp_1
 * =============================================================================================== */

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

