`timescale 1ns / 1ps

module NPU_PSUM_PORT_BEL (
    // =========================================================================
    // NPU / ASIC FACING PINS (Connect directly to NPU wrapper)
    // =========================================================================
    (* FABulous, EXTERNAL *) output wire [7:0]  NPU_ADDR,
    (* FABulous, EXTERNAL *) output wire [7:0]  NPU_WE,
    (* FABulous, EXTERNAL *) output wire [31:0] NPU_WDATA,
    (* FABulous, EXTERNAL *) output wire [2:0]  NPU_READ_BANK_SEL,
    (* FABulous, EXTERNAL *) input  wire [31:0] NPU_RDATA,

    // =========================================================================
    // FABRIC FACING PINS (Routed by FABulous Switch Matrices)
    // =========================================================================
    input  wire [7:0]  FAB_ADDR,
    input  wire [7:0]  FAB_WE,
    input  wire [31:0] FAB_WDATA,
    input  wire [2:0]  FAB_READ_BANK_SEL,
    output wire [31:0] FAB_RDATA
);

    // Fabric -> NPU Pass-Through
    assign NPU_ADDR          = FAB_ADDR;
    assign NPU_WE            = FAB_WE;
    assign NPU_WDATA         = FAB_WDATA;
    assign NPU_READ_BANK_SEL = FAB_READ_BANK_SEL;

    // NPU -> Fabric Pass-Through
    assign FAB_RDATA         = NPU_RDATA;

endmodule
