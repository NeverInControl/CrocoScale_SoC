`timescale 1ns / 1ps

module NPU_ACT_ROW_BEL (
    // =========================================================================
    // NPU / ASIC FACING PINS (Connect to one Act SRAM bank + one row weight input)
    // =========================================================================
    (* FABulous, EXTERNAL *) output wire       NPU_ACT_WE,
    (* FABulous, EXTERNAL *) output wire [8:0] NPU_ACT_ADDR,
    (* FABulous, EXTERNAL *) output wire [7:0] NPU_ACT_WDATA,
    (* FABulous, EXTERNAL *) input  wire [7:0] NPU_ACT_RDATA,
    (* FABulous, EXTERNAL *) output wire [7:0] NPU_WEIGHT_IN,

    // =========================================================================
    // FABRIC FACING PINS (Routed by FABulous Switch Matrices)
    // =========================================================================
    input  wire       FAB_ACT_WE,
    input  wire [8:0] FAB_ACT_ADDR,
    input  wire [7:0] FAB_ACT_WDATA,
    output wire [7:0] FAB_ACT_RDATA,
    input  wire [7:0] FAB_WEIGHT_IN
);

    // Fabric -> NPU Pass-Through
    assign NPU_ACT_WE    = FAB_ACT_WE;
    assign NPU_ACT_ADDR  = FAB_ACT_ADDR;
    assign NPU_ACT_WDATA = FAB_ACT_WDATA;
    assign NPU_WEIGHT_IN = FAB_WEIGHT_IN;

    // NPU -> Fabric Pass-Through
    assign FAB_ACT_RDATA = NPU_ACT_RDATA;

endmodule
