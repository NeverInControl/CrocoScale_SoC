`timescale 1ns / 1ps

/* ===============================================================================================
 * IHP SG13G2 Latch-Based Clock Gating Cell Simulation Model
 * Process: IHP 130nm CMOS5L / SG13G2
 * Cell: sg13g2_lgcp_1
 * =============================================================================================== */

module sg13g2_lgcp_1 (
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

