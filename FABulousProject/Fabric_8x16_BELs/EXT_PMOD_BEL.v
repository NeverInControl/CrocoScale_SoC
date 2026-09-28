`timescale 1ns / 1ps

module EXT_PMOD_BEL (
    // =========================================================================
    // External Padring Facing Pins (PMOD Interface)
    // =========================================================================
    (* FABulous, EXTERNAL *) input  wire [7:0] PMOD_IO_I,
    (* FABulous, EXTERNAL *) output reg  [7:0] PMOD_IO_O,
    (* FABulous, EXTERNAL *) output reg  [7:0] PMOD_IO_OE_O,

    // =========================================================================
    // Fabric Facing Pins (Switch Matrix Routing)
    // =========================================================================
    output reg  [7:0] FAB_PMOD_I,
    input  wire [7:0] FAB_PMOD_O,
    input  wire [7:0] FAB_PMOD_OE,

    // =========================================================================
    // Global User Clock (Dedicated Fabric Net)
    // =========================================================================
    (* FABulous, EXTERNAL, SHARED_PORT *) input wire UserCLK
);

    // -------------------------------------------------------------------------
    // Outbound Launch Pipeline Registers (Fabric -> Pads: +1 Clock Cycle)
    // -------------------------------------------------------------------------
    always @(posedge UserCLK) begin
        PMOD_IO_O    <= FAB_PMOD_O;
        PMOD_IO_OE_O <= FAB_PMOD_OE;
    end

    // -------------------------------------------------------------------------
    // Inbound Capture Pipeline Registers (Pads -> Fabric: +1 Clock Cycle)
    // -------------------------------------------------------------------------
    always @(posedge UserCLK) begin
        FAB_PMOD_I <= PMOD_IO_I;
    end

endmodule
