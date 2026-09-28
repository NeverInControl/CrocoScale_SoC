`timescale 1ns / 1ps

module SOC_DEBUG_CTRL_BEL #(
    parameter integer NoConfigBits = 4
)(
    // =========================================================================
    // Manager & SoC Facing Pins (Slot Debug & Control)
    // =========================================================================
    (* FABulous, EXTERNAL *) input  wire [7:0] DEBUG_OUT,
    (* FABulous, EXTERNAL *) output reg  [7:0] DEBUG_IN,
    (* FABulous, EXTERNAL *) output wire       USR_IRQ,
    (* FABulous, EXTERNAL *) input  wire       SLOT_SOFT_RST_N,

    // =========================================================================
    // Fabric Facing Pins (Switch Matrix Routing)
    // =========================================================================
    output reg  [7:0] FAB_DEBUG_OUT,
    input  wire [7:0] FAB_DEBUG_IN,
    input  wire       FAB_USR_IRQ,
    output wire       FAB_SLOT_SOFT_RST_N,

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
    // Bit 0: INV_RESET  -> Inverts soft reset polarity on ASIC side
    // Bit 1: INV_IRQ    -> Inverts user IRQ polarity on ASIC side
    // Bit 2: BYPASS_RST -> Register disable / bypass on reset (async delivery)
    // Bit 3: BYPASS_IRQ -> Register disable / bypass on interrupt (async delivery)
    // -------------------------------------------------------------------------
    wire INV_RESET  = ConfigBits[0];
    wire INV_IRQ    = ConfigBits[1];
    wire BYPASS_RST = ConfigBits[2];
    wire BYPASS_IRQ = ConfigBits[3];

    reg       reg_usr_irq;
    reg       reg_soft_rst_n;

    // ASIC-side polarity inversion
    wire raw_asic_rst_n = INV_RESET ? ~SLOT_SOFT_RST_N : SLOT_SOFT_RST_N;
    wire raw_fab_irq    = INV_IRQ   ? ~FAB_USR_IRQ     : FAB_USR_IRQ;

    // -------------------------------------------------------------------------
    // Outbound Launch Pipeline Registers (Fabric -> Manager/SoC: +1 Clock Cycle)
    // -------------------------------------------------------------------------
    always @(posedge UserCLK) begin
        DEBUG_IN    <= FAB_DEBUG_IN;
        reg_usr_irq <= raw_fab_irq;
    end

    // -------------------------------------------------------------------------
    // Inbound Capture Pipeline Registers (Manager -> Fabric: +1 Clock Cycle)
    // -------------------------------------------------------------------------
    always @(posedge UserCLK) begin
        FAB_DEBUG_OUT  <= DEBUG_OUT;
        reg_soft_rst_n <= raw_asic_rst_n;
    end

    // Direct / Bypassable Reset and IRQ lines
    assign USR_IRQ             = BYPASS_IRQ ? raw_fab_irq    : reg_usr_irq;
    assign FAB_SLOT_SOFT_RST_N = BYPASS_RST ? raw_asic_rst_n : reg_soft_rst_n;

endmodule
