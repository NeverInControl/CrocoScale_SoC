`timescale 1ns / 1ps

module npu_wrapper #(
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
    localparam int BANK_SEL_WIDTH   = $clog2(ARRAY_WIDTH),
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
    input  wire        [BANK_SEL_WIDTH-1:0]                              psum_A_read_bank_sel,
    output wire signed [PSUM_WIDTH-1:0]                                  psum_A_rdata,

    input  wire        [PSUM_ADDR_WIDTH-1:0]                             psum_B_addr,
    input  wire        [ARRAY_WIDTH-1:0]                                 psum_B_we,
    input  wire signed [PSUM_WIDTH-1:0]                                  psum_B_wdata,
    input  wire        [BANK_SEL_WIDTH-1:0]                              psum_B_read_bank_sel,
    output wire signed [PSUM_WIDTH-1:0]                                  psum_B_rdata,

    input  wire        [NUM_ACT_BANKS-1:0]                               ext_act_sram_we,
    input  wire        [NUM_ACT_BANKS-1:0][ACT_ADDR_WIDTH-1:0]           ext_act_sram_addr,
    input  wire signed [NUM_ACT_BANKS-1:0][ACTIVATION_WIDTH-1:0]         ext_act_sram_wdata,
    output wire signed [NUM_ACT_BANKS-1:0][ACTIVATION_WIDTH-1:0]         act_sram_rdata,

    output wire signed [ARRAY_WIDTH-1:0][ACTIVATION_WIDTH-1:0]           out_act
);

    wire        [NUM_PSUM_BANKS-1:0]                      npu_psum_we;
    wire        [NUM_PSUM_BANKS-1:0][PSUM_ADDR_WIDTH-1:0] npu_psum_addr;
    wire signed [NUM_PSUM_BANKS-1:0][PSUM_WIDTH-1:0]      npu_psum_wdata;
    wire signed [NUM_PSUM_BANKS-1:0][PSUM_WIDTH-1:0]      psum_sram_rdata;

`ifdef ASIC_MACROS
    npu_core_macro npu_logic_core (
        .clk_i              (clk_i),
        .rst_n              (rst_n),
        .array_en           (array_en),
        .psum_systolic_en   (psum_systolic_en),
        .psum_lut_en        (psum_lut_en),
        .crossbar_sel       (crossbar_sel),
        .weight_shift_in    (weight_shift_in),
        .weight_shift_en    (weight_shift_en),
        .swap_weights       (swap_weights),
        .quant_shift_in     (quant_shift_in),
        .quant_shift_en     (quant_shift_en),
        .stochastic_round_en(stochastic_round_en),
        .lfsr_data_out      (lfsr_data_out),
        .psum_skew_en       (psum_skew_en),
        .compute_bank_swap  (compute_bank_swap),
        .psum_A_addr        (psum_A_addr),
        .psum_A_we          (psum_A_we),
        .psum_A_wdata       (psum_A_wdata),
        .psum_A_read_bank_sel(psum_A_read_bank_sel),
        .psum_A_rdata       (psum_A_rdata),
        .psum_B_addr        (psum_B_addr),
        .psum_B_we          (psum_B_we),
        .psum_B_wdata       (psum_B_wdata),
        .psum_B_read_bank_sel(psum_B_read_bank_sel),
        .psum_B_rdata       (psum_B_rdata),
        .act_sram_rdata     (act_sram_rdata),
        .psum_sram_rdata    (psum_sram_rdata),
        .psum_sram_we       (npu_psum_we),
        .psum_sram_addr     (npu_psum_addr),
        .psum_sram_wdata    (npu_psum_wdata),
        .out_act            (out_act)
    );
`else
    npu_top #(
        .ARRAY_HEIGHT    (ARRAY_HEIGHT),
        .ARRAY_WIDTH     (ARRAY_WIDTH),
        .TILE_SIZE       (TILE_SIZE),
        .ACT_HALO_PAD    (ACT_HALO_PAD),
        .ACTIVATION_WIDTH(ACTIVATION_WIDTH),
        .WEIGHT_WIDTH    (WEIGHT_WIDTH),
        .PSUM_WIDTH      (PSUM_WIDTH),
        .SCALE_WIDTH     (SCALE_WIDTH),
        .ENABLE_LFSR     (ENABLE_LFSR),
        .WEIGHT_SPLIT    (WEIGHT_SPLIT)
    ) npu_logic_core (
        .clk_i              (clk_i),
        .rst_n              (rst_n),
        .array_en           (array_en),
        .psum_systolic_en   (psum_systolic_en),
        .psum_lut_en        (psum_lut_en),
        .crossbar_sel       (crossbar_sel),
        .weight_shift_in    (weight_shift_in),
        .weight_shift_en    (weight_shift_en),
        .swap_weights       (swap_weights),
        .quant_shift_in     (quant_shift_in),
        .quant_shift_en     (quant_shift_en),
        .stochastic_round_en(stochastic_round_en),
        .lfsr_data_out      (lfsr_data_out),
        .psum_skew_en       (psum_skew_en),
        .compute_bank_swap  (compute_bank_swap),
        .psum_A_addr        (psum_A_addr),
        .psum_A_we          (psum_A_we),
        .psum_A_wdata       (psum_A_wdata),
        .psum_A_read_bank_sel(psum_A_read_bank_sel),
        .psum_A_rdata       (psum_A_rdata),
        .psum_B_addr        (psum_B_addr),
        .psum_B_we          (psum_B_we),
        .psum_B_wdata       (psum_B_wdata),
        .psum_B_read_bank_sel(psum_B_read_bank_sel),
        .psum_B_rdata       (psum_B_rdata),
        .act_sram_rdata     (act_sram_rdata),
        .psum_sram_rdata    (psum_sram_rdata),
        .psum_sram_we       (npu_psum_we),
        .psum_sram_addr     (npu_psum_addr),
        .psum_sram_wdata    (npu_psum_wdata),
        .out_act            (out_act)
    );
`endif

    genvar i;
    generate
        for (i = 0; i < NUM_ACT_BANKS; i++) begin : gen_act_srams
            sram_bank #(
                .DATA_WIDTH(ACTIVATION_WIDTH),
                .DEPTH     (ACT_WORDS)
            ) act_sram_inst (
                .clk_i(clk_i),
                .we   (ext_act_sram_we[i]),
                .addr (ext_act_sram_addr[i]),
                .wdata(ext_act_sram_wdata[i]),
                .rdata(act_sram_rdata[i])
            );
        end
    endgenerate

    generate
        for (i = 0; i < NUM_PSUM_BANKS; i++) begin : gen_psum_srams
            sram_bank #(
                .DATA_WIDTH(PSUM_WIDTH),
                .DEPTH     (PSUM_WORDS)
            ) psum_sram_inst (
                .clk_i(clk_i),
                .we   (npu_psum_we[i]),
                .addr (npu_psum_addr[i]),
                .wdata(npu_psum_wdata[i]),
                .rdata(psum_sram_rdata[i])
            );
        end
    endgenerate

endmodule