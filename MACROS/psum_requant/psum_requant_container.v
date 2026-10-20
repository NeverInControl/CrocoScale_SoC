`timescale 1ns / 1ps

/* ===============================================================================================
 * Partial Sum Requantizer Container Hard Macro Blackbox Model
 * Drop-in replacement for RTL psum_requant_container.sv
 * =============================================================================================== */

(* blackbox *)
module psum_requant_container #(
    parameter integer PSUM_WIDTH       = 32,
    parameter integer PSUM_WORDS       = 256,
    parameter integer SCALE_WIDTH      = 16,
    parameter integer ACTIVATION_WIDTH = 8,
    parameter integer PSUM_ADDR_WIDTH  = 8,
    parameter integer PROD_WIDTH       = 48,
    parameter integer SHIFT_WIDTH      = 6,
    parameter integer QUANT_CFG_WIDTH  = 30
)(
    input  wire                                               clk_i,
    input  wire                                               rst_n,

    // Execution Mode Controls
    input  wire                                               psum_lut_en,

    // Bank A Interface (West Pins facing Slice 4)
    input  wire        [PSUM_ADDR_WIDTH-1:0]                  bank_A_addr,
    input  wire                                               bank_A_we,
    input  wire signed [PSUM_WIDTH-1:0]                       bank_A_wdata,
    output wire signed [PSUM_WIDTH-1:0]                       bank_A_rdata,

    // Bank B Interface (West Pins facing Slice 4)
    input  wire        [PSUM_ADDR_WIDTH-1:0]                  bank_B_addr,
    input  wire                                               bank_B_we,
    input  wire signed [PSUM_WIDTH-1:0]                       bank_B_wdata,
    output wire signed [PSUM_WIDTH-1:0]                       bank_B_rdata,

    // Requantizer Configuration (West Pins from Slice 4 Shift Chain)
    input  wire        [QUANT_CFG_WIDTH-1:0]                  quant_cfg,

    // Final Quantized Streaming Output (West Pin to Slice 4 / Drain Bus)
    output wire signed [ACTIVATION_WIDTH-1:0]                 act_out
);

    assign bank_A_rdata = {PSUM_WIDTH{1'b0}};
    assign bank_B_rdata = {PSUM_WIDTH{1'b0}};
    assign act_out      = {ACTIVATION_WIDTH{1'b0}};

endmodule

