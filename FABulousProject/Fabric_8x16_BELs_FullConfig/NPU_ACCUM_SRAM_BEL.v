`timescale 1ns / 1ps

module NPU_ACCUM_SRAM_BEL #(
    parameter integer NoConfigBits = 8
)(
    // =========================================================================
    // NPU Facing Pins (External Macro Boundary - Used for Bank A and Bank B)
    // =========================================================================
    (* FABulous, EXTERNAL *) output reg  [7:0]  NPU_ADDR,
    (* FABulous, EXTERNAL *) output reg  [7:0]  NPU_WE,
    (* FABulous, EXTERNAL *) output reg  [31:0] NPU_WDATA,
    (* FABulous, EXTERNAL *) output reg  [2:0]  NPU_READ_BANK_SEL,
    (* FABulous, EXTERNAL *) input  wire [31:0] NPU_RDATA,

    // =========================================================================
    // Fabric Facing Pins (Switch Matrix Routing)
    // =========================================================================
    input  wire [7:0]  FAB_ADDR,
    input  wire [7:0]  FAB_WE,
    input  wire [31:0] FAB_WDATA,
    input  wire [2:0]  FAB_READ_BANK_SEL,
    output reg  [31:0] FAB_RDATA,

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
    // Bits 7:0: WRITE_LOCK[7:0] -> Per-lane write lock (1 = clamps WE[i] to 0)
    // -------------------------------------------------------------------------
    wire [7:0] WRITE_LOCK = ConfigBits[7:0];
    wire [7:0] active_we  = FAB_WE & ~WRITE_LOCK;

    // -------------------------------------------------------------------------
    // Outbound Launch Pipeline Registers (Fabric -> NPU: +1 Clock Cycle)
    // -------------------------------------------------------------------------
    always @(posedge UserCLK) begin
        NPU_ADDR          <= FAB_ADDR;
        NPU_WE            <= active_we;
        NPU_WDATA         <= FAB_WDATA;
        NPU_READ_BANK_SEL <= FAB_READ_BANK_SEL;
    end

    // -------------------------------------------------------------------------
    // Inbound Capture Pipeline Registers (NPU -> Fabric: +1 Clock Cycle)
    // -------------------------------------------------------------------------
    always @(posedge UserCLK) begin
        FAB_RDATA <= NPU_RDATA;
    end

endmodule
