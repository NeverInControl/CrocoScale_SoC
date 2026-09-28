`timescale 1ns / 1ps

module SOC_DEBUG_CTRL_BEL (
    // =========================================================================
    // Manager & SoC Facing Pins (Slot Debug & Control)
    // =========================================================================
    (* FABulous, EXTERNAL *) input  wire [7:0] DEBUG_OUT,
    (* FABulous, EXTERNAL *) output reg  [7:0] DEBUG_IN,
    (* FABulous, EXTERNAL *) output reg        USR_IRQ,
    (* FABulous, EXTERNAL *) input  wire       SLOT_SOFT_RST_N,

    // =========================================================================
    // Fabric Facing Pins (Switch Matrix Routing)
    // =========================================================================
    output reg  [7:0] FAB_DEBUG_OUT,
    input  wire [7:0] FAB_DEBUG_IN,
    input  wire       FAB_USR_IRQ,
    output reg        FAB_SLOT_SOFT_RST_N,

    // =========================================================================
    // Global User Clock (Dedicated Fabric Net)
    // =========================================================================
    (* FABulous, EXTERNAL, SHARED_PORT *) input wire UserCLK
);

    // -------------------------------------------------------------------------
    // Outbound Launch Pipeline Registers (Fabric -> Manager/SoC: +1 Clock Cycle)
    // -------------------------------------------------------------------------
    always @(posedge UserCLK) begin
        DEBUG_IN <= FAB_DEBUG_IN;
        USR_IRQ  <= FAB_USR_IRQ;
    end

    // -------------------------------------------------------------------------
    // Inbound Capture Pipeline Registers (Manager -> Fabric: +1 Clock Cycle)
    // -------------------------------------------------------------------------
    always @(posedge UserCLK) begin
        FAB_DEBUG_OUT       <= DEBUG_OUT;
        FAB_SLOT_SOFT_RST_N <= SLOT_SOFT_RST_N;
    end

endmodule
