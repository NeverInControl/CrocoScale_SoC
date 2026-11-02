`timescale 1ns / 1ps

/* ===============================================================================================
 * Unified Partial Sum Requantizer Container (Pure IEEE 1364-2001 Verilog)
 *
 * Compiler Directives:
 * - TARGET_ASIC_CONTAINERS : Hardened Tier-1 Macro Blackbox Model (for Tier-2 Subsystem Synthesis)
 * - Default                : Synthesizable RTL Container instantiating sram_bank & npu_requantizer_lane
 * =============================================================================================== */

`ifdef TARGET_ASIC_CONTAINERS

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
    input  wire                               clk_i,
    input  wire                               rst_n,
    input  wire                               psum_lut_en,

    input  wire        [PSUM_ADDR_WIDTH-1:0]  bank_A_addr,
    input  wire                               bank_A_we,
    input  wire signed [PSUM_WIDTH-1:0]       bank_A_wdata,
    output wire signed [PSUM_WIDTH-1:0]       bank_A_rdata,

    input  wire        [PSUM_ADDR_WIDTH-1:0]  bank_B_addr,
    input  wire                               bank_B_we,
    input  wire signed [PSUM_WIDTH-1:0]       bank_B_wdata,
    output wire signed [PSUM_WIDTH-1:0]       bank_B_rdata,

    input  wire        [QUANT_CFG_WIDTH-1:0]  quant_cfg,
    output wire signed [ACTIVATION_WIDTH-1:0] act_out
);

    assign bank_A_rdata = {PSUM_WIDTH{1'b0}};
    assign bank_B_rdata = {PSUM_WIDTH{1'b0}};
    assign act_out      = {ACTIVATION_WIDTH{1'b0}};

endmodule

`else

module psum_requant_container #(
    parameter integer PSUM_WIDTH       = 32,
    parameter integer PSUM_WORDS       = 256,
    parameter integer SCALE_WIDTH      = 16,
    parameter integer ACTIVATION_WIDTH = 8,
    parameter integer PSUM_ADDR_WIDTH  = $clog2(PSUM_WORDS),
    parameter integer PROD_WIDTH       = PSUM_WIDTH + SCALE_WIDTH,
    parameter integer SHIFT_WIDTH      = $clog2(PROD_WIDTH),
    parameter integer QUANT_CFG_WIDTH  = (SCALE_WIDTH + SHIFT_WIDTH) + ACTIVATION_WIDTH
)(
    input  wire                               clk_i,
    input  wire                               rst_n,
    input  wire                               psum_lut_en,

    input  wire        [PSUM_ADDR_WIDTH-1:0]  bank_A_addr,
    input  wire                               bank_A_we,
    input  wire signed [PSUM_WIDTH-1:0]       bank_A_wdata,
    output wire signed [PSUM_WIDTH-1:0]       bank_A_rdata,

    input  wire        [PSUM_ADDR_WIDTH-1:0]  bank_B_addr,
    input  wire                               bank_B_we,
    input  wire signed [PSUM_WIDTH-1:0]       bank_B_wdata,
    output wire signed [PSUM_WIDTH-1:0]       bank_B_rdata,

    input  wire        [QUANT_CFG_WIDTH-1:0]  quant_cfg,
    output wire signed [ACTIVATION_WIDTH-1:0] act_out
);

    sram_bank #(
        .DATA_WIDTH(PSUM_WIDTH),
        .DEPTH     (PSUM_WORDS)
    ) bank_A_sram (
        .clk_i(clk_i),
        .we   (bank_A_we),
        .addr (bank_A_addr),
        .wdata(bank_A_wdata),
        .rdata(bank_A_rdata)
    );

    wire signed [ACTIVATION_WIDTH-1:0] quant_direct_act;
    wire signed [SCALE_WIDTH-1:0]      lane_scale_m0   = quant_cfg[SCALE_WIDTH-1:0];
    wire        [SHIFT_WIDTH-1:0]      lane_shift_n    = quant_cfg[(SCALE_WIDTH + SHIFT_WIDTH)-1:SCALE_WIDTH];
    wire signed [ACTIVATION_WIDTH-1:0] lane_zero_point = quant_cfg[QUANT_CFG_WIDTH-1:SCALE_WIDTH + SHIFT_WIDTH];

    npu_requantizer_lane #(
        .PSUM_WIDTH      (PSUM_WIDTH),
        .SCALE_WIDTH     (SCALE_WIDTH),
        .ACTIVATION_WIDTH(ACTIVATION_WIDTH)
    ) lane_inst (
        .clk_i     (clk_i),
        .rst_n     (rst_n),
        .psum_in   (bank_A_rdata),
        .scale_m0  (lane_scale_m0),
        .shift_n   (lane_shift_n),
        .zero_point(lane_zero_point),
        .act_out   (quant_direct_act)
    );

    wire [PSUM_ADDR_WIDTH-1:0] internal_bank_B_addr = psum_lut_en ? {{(PSUM_ADDR_WIDTH-ACTIVATION_WIDTH){1'b0}}, quant_direct_act} : bank_B_addr;
    wire                       internal_bank_B_we   = psum_lut_en ? 1'b0 : bank_B_we;

    sram_bank #(
        .DATA_WIDTH(PSUM_WIDTH),
        .DEPTH     (PSUM_WORDS)
    ) bank_B_sram (
        .clk_i(clk_i),
        .we   (internal_bank_B_we),
        .addr (internal_bank_B_addr),
        .wdata(bank_B_wdata),
        .rdata(bank_B_rdata)
    );

    assign act_out = psum_lut_en ? bank_B_rdata[ACTIVATION_WIDTH-1:0] : quant_direct_act;

endmodule

`endif

