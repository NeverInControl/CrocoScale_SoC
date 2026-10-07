`timescale 1ns / 1ps

(* FABulous, BelMap,
    FORCE_ZERO_XBAR   = 0,
    STATIC_XBAR_EN    = 1,
    STATIC_XBAR_VAL   = 2,
    STATIC_XBAR_VAL_1 = 3,
    STATIC_XBAR_VAL_2 = 4,
    WRITE_LOCK        = 5
*)
module NPU_SLICE_DATA_SRAM_BEL #(
    parameter integer NoConfigBits = 6
)(
    // =========================================================================
    // NPU / ASIC Facing Pins (External Macro Boundary - East Edge Slice)
    // =========================================================================
    (* FABulous, EXTERNAL *) output reg  [8:0] NPU_ACT_ADDR,
    (* FABulous, EXTERNAL *) output reg  [7:0] NPU_ACT_WDATA,
    (* FABulous, EXTERNAL *) input  wire [7:0] NPU_ACT_RDATA,
    (* FABulous, EXTERNAL *) output reg        NPU_ACT_WE,
    (* FABulous, EXTERNAL *) output reg  [7:0] NPU_WEIGHT_IN,
    (* FABulous, EXTERNAL *) output reg        NPU_WEIGHT_SHIFT_EN,
    (* FABulous, EXTERNAL *) output reg  [3:0] NPU_XBAR_SEL,
    (* FABulous, EXTERNAL *) input  wire [7:0] NPU_OUT_ACT,

    // =========================================================================
    // Fabric Facing Pins (Switch Matrix Routing)
    // =========================================================================
    input  wire [8:0] FAB_ACT_ADDR,
    input  wire [7:0] FAB_ACT_WDATA,
    output reg  [7:0] FAB_ACT_RDATA,
    input  wire       FAB_ACT_WE,
    input  wire [7:0] FAB_WEIGHT_IN,
    input  wire       FAB_WEIGHT_SHIFT_EN,
    input  wire [3:0] FAB_XBAR_SEL,
    output reg  [7:0] FAB_OUT_ACT,

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
    // Bit 0:   FORCE_ZERO_XBAR     -> Clamps [3] to 1'b1 (crossbar MSB=1 forces zero)
    //                                 0 = dynamic FAB_XBAR_SEL[3]
    // Bit 1:   STATIC_XBAR_EN      -> Clamps [2:0] to STATIC_XBAR_VAL[2:0]
    //                                 0 = dynamic FAB_XBAR_SEL[2:0]
    // Bits 4:2: STATIC_XBAR_VAL[2:0] -> Static 3-bit crossbar select value
    // Bit 5:   WRITE_LOCK          -> Clamps NPU_ACT_WE to 1'b0 (SRAM write protect)
    //                                 0 = dynamic FAB_ACT_WE
    // -------------------------------------------------------------------------
    wire       FORCE_ZERO_XBAR = ConfigBits[0];
    wire       STATIC_XBAR_EN  = ConfigBits[1];
    wire [2:0] STATIC_XBAR_VAL = ConfigBits[4:2];
    wire       WRITE_LOCK      = ConfigBits[5];

    wire [3:0] active_xbar_sel;
    assign active_xbar_sel[3]   = FORCE_ZERO_XBAR ? 1'b1            : FAB_XBAR_SEL[3];
    assign active_xbar_sel[2:0] = STATIC_XBAR_EN  ? STATIC_XBAR_VAL : FAB_XBAR_SEL[2:0];

    wire active_act_we = WRITE_LOCK ? 1'b0 : FAB_ACT_WE;

    // -------------------------------------------------------------------------
    // Outbound Launch Pipeline Registers (Fabric -> NPU: +1 Clock Cycle)
    // -------------------------------------------------------------------------
    always @(posedge UserCLK) begin
        NPU_ACT_ADDR        <= FAB_ACT_ADDR;
        NPU_ACT_WDATA       <= FAB_ACT_WDATA;
        NPU_ACT_WE          <= active_act_we;
        NPU_WEIGHT_IN       <= FAB_WEIGHT_IN;
        NPU_WEIGHT_SHIFT_EN <= FAB_WEIGHT_SHIFT_EN;
        NPU_XBAR_SEL        <= active_xbar_sel;
    end

    // -------------------------------------------------------------------------
    // Inbound Capture Pipeline Registers (NPU -> Fabric: +1 Clock Cycle)
    // -------------------------------------------------------------------------
    always @(posedge UserCLK) begin
        FAB_ACT_RDATA <= NPU_ACT_RDATA;
        FAB_OUT_ACT   <= NPU_OUT_ACT;
    end

endmodule
