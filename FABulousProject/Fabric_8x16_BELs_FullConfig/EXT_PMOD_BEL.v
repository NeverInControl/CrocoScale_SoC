`timescale 1ns / 1ps

module EXT_PMOD_BEL #(
    parameter integer NoConfigBits = 13
)(
    // =========================================================================
    // External Padring Facing Pins (PMOD Interface)
    // =========================================================================
    (* FABulous, EXTERNAL *) input  wire [7:0] PMOD_IO_I,
    (* FABulous, EXTERNAL *) output wire [7:0] PMOD_IO_O,
    (* FABulous, EXTERNAL *) output wire [7:0] PMOD_IO_OE_O,

    // =========================================================================
    // Fabric Facing Pins (Switch Matrix Routing)
    // =========================================================================
    output wire [7:0] FAB_PMOD_I,
    input  wire [7:0] FAB_PMOD_O,
    input  wire [7:0] FAB_PMOD_OE,

    // =========================================================================
    // Global User Clock (Dedicated Fabric Net)
    // =========================================================================
    (* FABulous, EXTERNAL, SHARED_PORT *) input wire UserCLK,

    // =========================================================================
    // Static Configuration Bits
    // =========================================================================
    (* FABulous, GLOBAL *) input wire [NoConfigBits-1:0] ConfigBits
);

    // -------------------------------------------------------------------------
    // Bit 0:    BYPASS_IN_REG  -> Combinatorial pad -> fabric bypass
    // Bit 1:    BYPASS_OUT_REG -> Combinatorial fabric -> pad bypass
    // Bit 2:    TIE_OFF_OE     -> Select static OE vector vs dynamic fabric OE
    // Bits 10:3 STATIC_OE[7:0] -> 8-bit static pad direction (1=output, 0=input)
    // Bit 11:   OPEN_DRAIN_EN  -> Open-drain mode (drives 0 to GND, 1 to High-Z)
    // Bit 12:   LOOPBACK_EN    -> Internal BIST loopback (FAB_O -> FAB_I)
    // -------------------------------------------------------------------------
    wire       BYPASS_IN_REG  = ConfigBits[0];
    wire       BYPASS_OUT_REG = ConfigBits[1];
    wire       TIE_OFF_OE     = ConfigBits[2];
    wire [7:0] STATIC_OE      = ConfigBits[10:3];
    wire       OPEN_DRAIN_EN  = ConfigBits[11];
    wire       LOOPBACK_EN    = ConfigBits[12];

    reg  [7:0] reg_pmod_o;
    reg  [7:0] reg_pmod_oe;
    reg  [7:0] reg_fab_i;

    wire [7:0] effective_fab_o  = FAB_PMOD_O;
    wire [7:0] effective_fab_oe = TIE_OFF_OE ? STATIC_OE : FAB_PMOD_OE;

    always @(posedge UserCLK) begin
        reg_pmod_o  <= effective_fab_o;
        reg_pmod_oe <= effective_fab_oe;
        reg_fab_i   <= LOOPBACK_EN ? effective_fab_o : PMOD_IO_I;
    end

    wire [7:0] active_out = BYPASS_OUT_REG ? effective_fab_o  : reg_pmod_o;
    wire [7:0] active_oe  = BYPASS_OUT_REG ? effective_fab_oe : reg_pmod_oe;

    assign PMOD_IO_O    = OPEN_DRAIN_EN ? 8'b0 : active_out;
    assign PMOD_IO_OE_O = OPEN_DRAIN_EN ? (active_oe & ~active_out) : active_oe;

    assign FAB_PMOD_I   = BYPASS_IN_REG ? (LOOPBACK_EN ? effective_fab_o : PMOD_IO_I) : reg_fab_i;

endmodule
