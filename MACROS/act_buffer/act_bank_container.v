`timescale 1ns / 1ps

/* ===============================================================================================
 * Activation Bank Container Hard Macro Blackbox Model
 * Drop-in replacement for RTL act_bank_container.sv
 * =============================================================================================== */

module act_bank_container #(
    parameter integer ACTIVATION_WIDTH = 8,
    parameter integer ACT_WORDS        = 512,
    parameter integer WEIGHT_WIDTH     = 8,
    parameter integer XBAR_SEL_WIDTH   = 4,
    parameter integer ACT_ADDR_WIDTH   = 9
)(
    // West Interface (facing Slice 2 / eFPGA Fabric)
    input  wire                                           clk_i,
    input  wire                                           act_we,
    input  wire        [ACT_ADDR_WIDTH-1:0]               act_addr,
    input  wire signed [ACTIVATION_WIDTH-1:0]             act_wdata,
    output wire signed [ACTIVATION_WIDTH-1:0]             act_rdata_west,

    input  wire signed [WEIGHT_WIDTH-1:0]                 weight_in_west,
    input  wire                                           weight_shift_en_west,
    input  wire        [XBAR_SEL_WIDTH-1:0]               xbar_sel_west,
    output wire signed [ACTIVATION_WIDTH-1:0]             out_act_west,

    // East Interface (facing Slice 4 / Compute Core)
    output wire                                           clk_o,
    output wire signed [ACTIVATION_WIDTH-1:0]             act_rdata_east,
    output wire signed [WEIGHT_WIDTH-1:0]                 weight_in_east,
    output wire                                           weight_shift_en_east,
    output wire        [XBAR_SEL_WIDTH-1:0]               xbar_sel_east,
    input  wire signed [ACTIVATION_WIDTH-1:0]             out_act_east
);

    assign act_rdata_west       = {ACTIVATION_WIDTH{1'b0}};
    assign act_rdata_east       = {ACTIVATION_WIDTH{1'b0}};
    assign clk_o                = clk_i;
    assign weight_in_east       = weight_in_west;
    assign weight_shift_en_east = weight_shift_en_west;
    assign xbar_sel_east        = xbar_sel_west;
    assign out_act_west         = out_act_east;

endmodule

