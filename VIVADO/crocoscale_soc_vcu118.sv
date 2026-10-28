`timescale 1ns / 1ps

/* ===============================================================================================
 * CrocoScale SoC Top-Level Board Wrapper (Xilinx Virtex UltraScale+ VCU118)
 * Converts differential 125 MHz board oscillator (clk_p_i / clk_n_i) via IBUFDS into a
 * single-ended clock for the platform-agnostic crocoscale_soc top module.
 * =============================================================================================== */

module crocoscale_soc_vcu118 #(
    parameter int          NUM_SLOTS    = 1,
    parameter int          MEM_SIZE     = 128*1024,
    parameter logic [31:0] HW_VERSION   = 32'hFAB00001,
    parameter int          AXI_ID_WIDTH = 8
)(
    input  logic       clk_p_i,
    input  logic       clk_n_i,
    input  logic       rstn_i,
    output logic [7:0] gpio_o,
    output logic       uart0_txd_o,
    input  logic       uart0_rxd_i,
    inout  wire  [7:0] ja,
    inout  wire  [7:0] jb
);

    logic clk_board;

    IBUFDS u_clk_ibufds (
        .I  (clk_p_i),
        .IB (clk_n_i),
        .O  (clk_board)
    );

    crocoscale_soc #(
        .NUM_SLOTS    (NUM_SLOTS),
        .MEM_SIZE     (MEM_SIZE),
        .HW_VERSION   (HW_VERSION),
        .AXI_ID_WIDTH (AXI_ID_WIDTH)
    ) u_crocoscale_soc (
        .clk_i       (clk_board),
        .rstn_i      (rstn_i),
        .gpio_o      (gpio_o),
        .uart0_txd_o (uart0_txd_o),
        .uart0_rxd_i (uart0_rxd_i),
        .ja          (ja),
        .jb          (jb)
    );

endmodule

