`timescale 1ns / 1ps

module NPU_CTRL_CFG_BEL (
    // =========================================================================
    // NPU / ASIC Facing Pins (External Macro Boundary)
    // =========================================================================
    (* FABulous, EXTERNAL *) output reg  [29:0] NPU_QUANT_SHIFT_IN,
    (* FABulous, EXTERNAL *) output reg         NPU_QUANT_SHIFT_EN,
    (* FABulous, EXTERNAL *) output reg         NPU_ARRAY_EN,
    (* FABulous, EXTERNAL *) output reg         NPU_PSUM_SYSTOLIC_EN,
    (* FABulous, EXTERNAL *) output reg         NPU_PSUM_LUT_EN,
    (* FABulous, EXTERNAL *) output reg         NPU_SWAP_WEIGHTS,
    (* FABulous, EXTERNAL *) output reg         NPU_PSUM_SKEW_EN,
    (* FABulous, EXTERNAL *) output reg         NPU_COMPUTE_BANK_SWAP,

    // =========================================================================
    // Fabric Facing Pins (Switch Matrix Routing)
    // =========================================================================
    input  wire [29:0] FAB_QUANT_SHIFT_IN,
    input  wire        FAB_QUANT_SHIFT_EN,
    input  wire        FAB_ARRAY_EN,
    input  wire        FAB_PSUM_SYSTOLIC_EN,
    input  wire        FAB_PSUM_LUT_EN,
    input  wire        FAB_SWAP_WEIGHTS,
    input  wire        FAB_PSUM_SKEW_EN,
    input  wire        FAB_COMPUTE_BANK_SWAP,

    // =========================================================================
    // Global User Clock (Dedicated Fabric Net)
    // =========================================================================
    (* FABulous, EXTERNAL, SHARED_PORT *) input wire UserCLK
);

    // -------------------------------------------------------------------------
    // Outbound Launch Pipeline Registers (Fabric -> NPU: +1 Clock Cycle)
    // -------------------------------------------------------------------------
    always @(posedge UserCLK) begin
        NPU_QUANT_SHIFT_IN    <= FAB_QUANT_SHIFT_IN;
        NPU_QUANT_SHIFT_EN    <= FAB_QUANT_SHIFT_EN;
        NPU_ARRAY_EN          <= FAB_ARRAY_EN;
        NPU_PSUM_SYSTOLIC_EN  <= FAB_PSUM_SYSTOLIC_EN;
        NPU_PSUM_LUT_EN       <= FAB_PSUM_LUT_EN;
        NPU_SWAP_WEIGHTS      <= FAB_SWAP_WEIGHTS;
        NPU_PSUM_SKEW_EN      <= FAB_PSUM_SKEW_EN;
        NPU_COMPUTE_BANK_SWAP <= FAB_COMPUTE_BANK_SWAP;
    end

endmodule
