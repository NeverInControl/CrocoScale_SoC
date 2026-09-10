`timescale 1ns / 1ps

/* ===============================================================================================
 * NPU Core Hard Macro Blackbox Model
 * Architecture: 8x8 INT8 Systolic Array, Requantizer, Crossbar & Memory Routing
 * =============================================================================================== */

module npu_core_macro #(
    parameter int ARRAY_HEIGHT     = 8,
    parameter int ARRAY_WIDTH      = 8,
    parameter int TILE_SIZE        = 16,
    parameter int ACT_HALO_PAD     = 2,
    parameter int ACTIVATION_WIDTH = 8,
    parameter int WEIGHT_WIDTH     = 8,
    parameter int PSUM_WIDTH       = 32,
    parameter int SCALE_WIDTH      = 16,
    parameter bit ENABLE_LFSR      = 0,
    parameter int WEIGHT_SPLIT     = 2,

    localparam int PSUM_WORDS       = TILE_SIZE * TILE_SIZE,
    localparam int ACT_WORDS        = (TILE_SIZE * TILE_SIZE) * ACT_HALO_PAD,
    localparam int PSUM_ADDR_WIDTH  = $clog2(PSUM_WORDS),
    localparam int ACT_ADDR_WIDTH   = $clog2(ACT_WORDS),
    localparam int NUM_ACT_BANKS    = ARRAY_HEIGHT,
    localparam int NUM_PSUM_BANKS   = ARRAY_WIDTH * 2,
    localparam int XBAR_SEL_WIDTH   = $clog2(ARRAY_HEIGHT) + 1,
    localparam int PROD_WIDTH       = PSUM_WIDTH + SCALE_WIDTH,
    localparam int SHIFT_WIDTH      = $clog2(PROD_WIDTH),
    localparam int QUANT_CFG_WIDTH  = SCALE_WIDTH + SHIFT_WIDTH + ACTIVATION_WIDTH
)(
    input  wire                                                          clk_i,
    input  wire                                                          rst_n,

    input  wire                                                          array_en,
    input  wire                                                          psum_systolic_en,
    input  wire                                                          psum_lut_en,

    input  wire        [ARRAY_HEIGHT-1:0][XBAR_SEL_WIDTH-1:0]            crossbar_sel,

    input  wire signed [ARRAY_HEIGHT-1:0][WEIGHT_WIDTH-1:0]              weight_shift_in,
    input  wire        [WEIGHT_SPLIT-1:0]                                weight_shift_en,
    input  wire                                                          swap_weights,

    input  wire        [QUANT_CFG_WIDTH-1:0]                             quant_shift_in,
    input  wire                                                          quant_shift_en,
    input  wire                                                          stochastic_round_en,
    output wire        [SCALE_WIDTH-1:0]                                 lfsr_data_out,

    input  wire                                                          psum_skew_en,
    input  wire                                                          compute_bank_swap,

    input  wire        [PSUM_ADDR_WIDTH-1:0]                             psum_A_addr,
    input  wire        [ARRAY_WIDTH-1:0]                                 psum_A_we,
    input  wire signed [PSUM_WIDTH-1:0]                                  psum_A_wdata,
    input  wire        [$clog2(ARRAY_WIDTH)-1:0]                         psum_A_read_bank_sel,
    output wire signed [PSUM_WIDTH-1:0]                                  psum_A_rdata,

    input  wire        [PSUM_ADDR_WIDTH-1:0]                             psum_B_addr,
    input  wire        [ARRAY_WIDTH-1:0]                                 psum_B_we,
    input  wire signed [PSUM_WIDTH-1:0]                                  psum_B_wdata,
    input  wire        [$clog2(ARRAY_WIDTH)-1:0]                         psum_B_read_bank_sel,
    output wire signed [PSUM_WIDTH-1:0]                                  psum_B_rdata,

    input  wire signed [NUM_ACT_BANKS-1:0][ACTIVATION_WIDTH-1:0]         act_sram_rdata,

    input  wire signed [NUM_PSUM_BANKS-1:0][PSUM_WIDTH-1:0]             psum_sram_rdata,
    output logic       [NUM_PSUM_BANKS-1:0]                              psum_sram_we,
    output logic       [NUM_PSUM_BANKS-1:0][PSUM_ADDR_WIDTH-1:0]         psum_sram_addr,
    output logic signed [NUM_PSUM_BANKS-1:0][PSUM_WIDTH-1:0]            psum_sram_wdata,

    output wire signed [ARRAY_WIDTH-1:0][ACTIVATION_WIDTH-1:0]           out_act
);

    /* Stub connections for simulation and macro elaboration */
    assign lfsr_data_out   = '0;
    assign psum_A_rdata    = '0;
    assign psum_B_rdata    = '0;
    assign psum_sram_we    = '0;
    assign psum_sram_addr  = '0;
    assign psum_sram_wdata = '0;
    assign out_act         = '0;

endmodule

