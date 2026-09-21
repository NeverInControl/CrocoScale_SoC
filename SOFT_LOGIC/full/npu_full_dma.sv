`timescale 1ns / 1ps

/* ===============================================================================================
 * File: SOFT_LOGIC/full/npu_full_dma.sv
 * Module: npu_full_dma
 * Project: CrocoScale SoC — Full Dual-Mode AXI4 Master DMA Engine
 *
 * Description:
 *   Top-level lean AXI4 Master DMA engine. Integrates:
 *   - npu_dma_reader: Unified burst read engine (weights, biases, quant parameters, LUT)
 *   - npu_dma_drainer: Dedicated high-throughput burst write engine (linear, Mish, MaxPool)
 * =============================================================================================== */

module npu_full_dma #(
    parameter int ARRAY_HEIGHT     = 8,
    parameter int ARRAY_WIDTH      = 8,
    parameter int ACTIVATION_WIDTH = 8,
    parameter int WEIGHT_WIDTH     = 8,
    parameter int PSUM_WIDTH       = 32,
    parameter int AXI_ADDR_WIDTH   = 32,
    parameter int AXI_DATA_WIDTH   = 32
) (
    input  wire                                                          clk_i,
    input  wire                                                          rst_n,

    // AXI4 Master Write Address Channel (AW)
    output wire        [AXI_ADDR_WIDTH-1:0]                              m_axi_awaddr,
    output wire        [7:0]                                             m_axi_awlen,
    output wire        [2:0]                                             m_axi_awsize,
    output wire        [1:0]                                             m_axi_awburst,
    output wire                                                          m_axi_awvalid,
    input  wire                                                          m_axi_awready,

    // AXI4 Master Write Data Channel (W)
    output wire        [AXI_DATA_WIDTH-1:0]                              m_axi_wdata,
    output wire        [(AXI_DATA_WIDTH/8)-1:0]                          m_axi_wstrb,
    output wire                                                          m_axi_wlast,
    output wire                                                          m_axi_wvalid,
    input  wire                                                          m_axi_wready,

    // AXI4 Master Write Response Channel (B)
    input  wire        [1:0]                                             m_axi_bresp,
    input  wire                                                          m_axi_bvalid,
    output wire                                                          m_axi_bready,

    // AXI4 Master Read Address Channel (AR)
    output wire        [AXI_ADDR_WIDTH-1:0]                              m_axi_araddr,
    output wire        [7:0]                                             m_axi_arlen,
    output wire        [2:0]                                             m_axi_arsize,
    output wire        [1:0]                                             m_axi_arburst,
    output wire                                                          m_axi_arvalid,
    input  wire                                                          m_axi_arready,

    // AXI4 Master Read Data Channel (R)
    input  wire        [AXI_DATA_WIDTH-1:0]                              m_axi_rdata,
    input  wire        [1:0]                                             m_axi_rresp,
    input  wire                                                          m_axi_rlast,
    input  wire                                                          m_axi_rvalid,
    output wire                                                          m_axi_rready,

    // Base Addresses & Mode
    input  wire        [31:0]                                            act_base_i,
    input  wire        [31:0]                                            weight_base_i,
    input  wire        [31:0]                                            out_base_i,
    input  wire        [31:0]                                            bias_base_i,
    input  wire        [31:0]                                            quant_base_i,
    input  wire        [31:0]                                            lut_base_i,
    input  wire                                                          mode_1x1_i,
    input  wire                                                          lut_en_i,
    input  wire                                                          pool_en_i,

    // Sequencer Synchronization
    input  wire                                                          start_preload_i,
    output wire                                                          preload_done_o,

    input  wire                                                          start_weight_fetch_i,
    input  wire        [7:0]                                             fetch_pass_idx_i,
    output wire                                                          weight_fetch_done_o,

    input  wire                                                          start_lut_load_i,
    output wire                                                          lut_load_done_o,

    input  wire                                                          start_drain_i,
    output wire                                                          drain_done_o,
    output wire        [7:0]                                             drain_psum_addr_o,
    input  wire signed [ARRAY_WIDTH-1:0][ACTIVATION_WIDTH-1:0]           npu_out_act_i,

    // Hardware Outputs to NPU Core
    output wire signed [ARRAY_HEIGHT-1:0][WEIGHT_WIDTH-1:0]              weight_shift_in_o,
    output wire        [1:0]                                             weight_shift_en_o,
    output wire signed [PSUM_WIDTH-1:0]                                  bias_wdata_o,
    output wire        [2:0]                                             bias_channel_o,
    output wire                                                          bias_we_o,
    output wire        [29:0]                                            quant_shift_in_o,
    output wire                                                          quant_shift_en_o,

    // Hardware Interface to PSUM SRAM Bank B (for LUT table preload)
    output wire        [7:0]                                             psum_B_addr_o,
    output wire        [31:0]                                            psum_B_wdata_o,
    output wire        [7:0]                                             psum_B_we_o
);

    // 1. Unified AXI4 Read DMA Engine
    npu_dma_reader #(
        .ARRAY_HEIGHT  (ARRAY_HEIGHT),
        .WEIGHT_WIDTH  (WEIGHT_WIDTH),
        .PSUM_WIDTH    (PSUM_WIDTH),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH)
    ) dma_reader_inst (
        .clk_i              (clk_i),
        .rst_n              (rst_n),
        .lut_base_i         (lut_base_i),
        .bias_base_i        (bias_base_i),
        .quant_base_i       (quant_base_i),
        .weight_base_i      (weight_base_i),
        .mode_1x1_i         (mode_1x1_i),
        .start_lut_load_i   (start_lut_load_i),
        .lut_load_done_o    (lut_load_done_o),
        .start_preload_i    (start_preload_i),
        .preload_done_o     (preload_done_o),
        .start_weight_fetch_i(start_weight_fetch_i),
        .fetch_pass_idx_i   (fetch_pass_idx_i),
        .weight_fetch_done_o(weight_fetch_done_o),
        .m_axi_araddr       (m_axi_araddr),
        .m_axi_arlen        (m_axi_arlen),
        .m_axi_arsize       (m_axi_arsize),
        .m_axi_arburst      (m_axi_arburst),
        .m_axi_arvalid      (m_axi_arvalid),
        .m_axi_arready      (m_axi_arready),
        .m_axi_rdata        (m_axi_rdata),
        .m_axi_rresp        (m_axi_rresp),
        .m_axi_rlast        (m_axi_rlast),
        .m_axi_rvalid       (m_axi_rvalid),
        .m_axi_rready       (m_axi_rready),
        .weight_shift_in_o  (weight_shift_in_o),
        .weight_shift_en_o  (weight_shift_en_o),
        .bias_wdata_o       (bias_wdata_o),
        .bias_channel_o     (bias_channel_o),
        .bias_we_o          (bias_we_o),
        .quant_shift_in_o   (quant_shift_in_o),
        .quant_shift_en_o   (quant_shift_en_o),
        .psum_B_addr_o      (psum_B_addr_o),
        .psum_B_wdata_o     (psum_B_wdata_o),
        .psum_B_we_o        (psum_B_we_o)
    );

    // 2. High-Throughput Output Drain Engine (AXI Write Master)
    npu_dma_drainer #(
        .ARRAY_WIDTH     (ARRAY_WIDTH),
        .ACTIVATION_WIDTH(ACTIVATION_WIDTH)
    ) drainer_inst (
        .clk_i            (clk_i),
        .rst_n            (rst_n),
        .start_i          (start_drain_i),
        .out_base_i       (out_base_i),
        .lut_en_i         (lut_en_i),
        .pool_en_i        (pool_en_i),
        .done_o           (drain_done_o),
        .awaddr_o         (m_axi_awaddr),
        .awlen_o          (m_axi_awlen),
        .awsize_o         (m_axi_awsize),
        .awburst_o        (m_axi_awburst),
        .awvalid_o        (m_axi_awvalid),
        .awready_i        (m_axi_awready),
        .wdata_o          (m_axi_wdata),
        .wstrb_o          (m_axi_wstrb),
        .wlast_o          (m_axi_wlast),
        .wvalid_o         (m_axi_wvalid),
        .wready_i         (m_axi_wready),
        .bresp_i          (m_axi_bresp),
        .bvalid_i         (m_axi_bvalid),
        .bready_o         (m_axi_bready),
        .drain_psum_addr_o(drain_psum_addr_o),
        .npu_out_act_i    (npu_out_act_i)
    );

endmodule
