`timescale 1ns / 1ps

/* ===============================================================================================
 * npu_soft_controller.sv
 *
 * eFPGA NPU Soft-Logic Controller - Top-Level Integrated Wrapper
 *
 * Integrates:
 * 1. npu_soft_regs:      AXI4-Lite MMIO register file for CPU host orchestration.
 * 2. npu_soft_dma:       AXI4 Master burst DMA engine for tensor preloading and draining.
 * 3. npu_soft_sequencer: Central cycle-accurate FSM coordinating systolic matrix operations.
 *
 * Directly connects to the dedicated hardware ports of npu_wrapper.
 * =============================================================================================== */

module npu_minimal_controller #(
    parameter int ARRAY_HEIGHT     = 8,
    parameter int ARRAY_WIDTH      = 8,
    parameter int TILE_SIZE        = 16,
    parameter int ACT_HALO_PAD     = 2,
    parameter int ACTIVATION_WIDTH = 8,
    parameter int WEIGHT_WIDTH     = 8,
    parameter int PSUM_WIDTH       = 32,
    parameter int SCALE_WIDTH      = 16,
    parameter int WEIGHT_SPLIT     = 2,
    parameter int AXI_ADDR_WIDTH   = 32,
    parameter int AXI_DATA_WIDTH   = 32,

    localparam int PSUM_WORDS      = TILE_SIZE * TILE_SIZE, // 256
    localparam int ACT_WORDS       = (TILE_SIZE * TILE_SIZE) * ACT_HALO_PAD, // 512
    localparam int PSUM_ADDR_WIDTH = $clog2(PSUM_WORDS), // 8
    localparam int ACT_ADDR_WIDTH  = $clog2(ACT_WORDS),  // 9
    localparam int NUM_ACT_BANKS   = ARRAY_HEIGHT,       // 8
    localparam int XBAR_SEL_WIDTH  = 4,
    localparam int QUANT_CFG_WIDTH = 30,
    localparam int BANK_SEL_WIDTH  = $clog2(ARRAY_WIDTH) // 3
)(
    input  wire                                                          clk_i,
    input  wire                                                          rst_n,

    // =========================================================================
    // 1. AXI4-Lite Slave Interface (Host CPU MMIO)
    // =========================================================================
    input  wire [AXI_ADDR_WIDTH-1:0]                                     s_axil_awaddr,
    input  wire [2:0]                                                    s_axil_awprot,
    input  wire                                                          s_axil_awvalid,
    output logic                                                         s_axil_awready,

    input  wire [AXI_DATA_WIDTH-1:0]                                     s_axil_wdata,
    input  wire [(AXI_DATA_WIDTH/8)-1:0]                                 s_axil_wstrb,
    input  wire                                                          s_axil_wvalid,
    output logic                                                         s_axil_wready,

    output logic [1:0]                                                   s_axil_bresp,
    output logic                                                         s_axil_bvalid,
    input  wire                                                          s_axil_bready,

    input  wire [AXI_ADDR_WIDTH-1:0]                                     s_axil_araddr,
    input  wire [2:0]                                                    s_axil_arprot,
    input  wire                                                          s_axil_arvalid,
    output logic                                                         s_axil_arready,

    output logic [AXI_DATA_WIDTH-1:0]                                     s_axil_rdata,
    output logic [1:0]                                                   s_axil_rresp,
    output logic                                                         s_axil_rvalid,
    input  wire                                                          s_axil_rready,

    // =========================================================================
    // 2. AXI4 Master Interface (System RAM DMA Access)
    // =========================================================================
    output logic       [AXI_ADDR_WIDTH-1:0]                              m_axi_awaddr,
    output logic       [7:0]                                             m_axi_awlen,
    output logic       [2:0]                                             m_axi_awsize,
    output logic       [1:0]                                             m_axi_awburst,
    output logic                                                         m_axi_awvalid,
    input  wire                                                          m_axi_awready,

    output logic       [AXI_DATA_WIDTH-1:0]                              m_axi_wdata,
    output logic       [(AXI_DATA_WIDTH/8)-1:0]                          m_axi_wstrb,
    output logic                                                         m_axi_wlast,
    output logic                                                         m_axi_wvalid,
    input  wire                                                          m_axi_wready,

    input  wire        [1:0]                                             m_axi_bresp,
    input  wire                                                          m_axi_bvalid,
    output logic                                                         m_axi_bready,

    output logic       [AXI_ADDR_WIDTH-1:0]                              m_axi_araddr,
    output logic       [7:0]                                             m_axi_arlen,
    output logic       [2:0]                                             m_axi_arsize,
    output logic       [1:0]                                             m_axi_arburst,
    output logic                                                         m_axi_arvalid,
    input  wire                                                          m_axi_arready,

    input  wire        [AXI_DATA_WIDTH-1:0]                              m_axi_rdata,
    input  wire        [1:0]                                             m_axi_rresp,
    input  wire                                                          m_axi_rlast,
    input  wire                                                          m_axi_rvalid,
    output logic                                                         m_axi_rready,

    // =========================================================================
    // 3. NPU Complex Dedicated Interface (Direct to npu_wrapper)
    // =========================================================================
    output logic                                                         npu_array_en,
    output logic                                                         npu_psum_systolic_en,
    output logic                                                         npu_psum_lut_en,
    output logic                                                         npu_psum_skew_en,
    output logic                                                         npu_compute_bank_swap,
    output logic       [ARRAY_HEIGHT-1:0][XBAR_SEL_WIDTH-1:0]            npu_crossbar_sel,

    output logic signed [ARRAY_HEIGHT-1:0][WEIGHT_WIDTH-1:0]             npu_weight_shift_in,
    output logic       [WEIGHT_SPLIT-1:0]                                npu_weight_shift_en,
    output logic                                                         npu_swap_weights,

    output logic       [QUANT_CFG_WIDTH-1:0]                             npu_quant_shift_in,
    output logic                                                         npu_quant_shift_en,
    output logic                                                         npu_stochastic_round_en,

    output logic       [PSUM_ADDR_WIDTH-1:0]                             npu_psum_A_addr,
    output logic       [ARRAY_WIDTH-1:0]                                 npu_psum_A_we,
    output logic signed [PSUM_WIDTH-1:0]                                 npu_psum_A_wdata,
    output logic       [BANK_SEL_WIDTH-1:0]                              npu_psum_A_read_bank_sel,
    input  wire signed [PSUM_WIDTH-1:0]                                  npu_psum_A_rdata,

    output logic       [PSUM_ADDR_WIDTH-1:0]                             npu_psum_B_addr,
    output logic       [ARRAY_WIDTH-1:0]                                 npu_psum_B_we,
    output logic signed [PSUM_WIDTH-1:0]                                 npu_psum_B_wdata,
    output logic       [BANK_SEL_WIDTH-1:0]                              npu_psum_B_read_bank_sel,
    input  wire signed [PSUM_WIDTH-1:0]                                  npu_psum_B_rdata,

    output logic       [NUM_ACT_BANKS-1:0]                               npu_ext_act_sram_we,
    output logic       [NUM_ACT_BANKS-1:0][ACT_ADDR_WIDTH-1:0]           npu_ext_act_sram_addr,
    output logic signed [NUM_ACT_BANKS-1:0][ACTIVATION_WIDTH-1:0]        npu_ext_act_sram_wdata,
    input  wire signed [NUM_ACT_BANKS-1:0][ACTIVATION_WIDTH-1:0]         npu_act_sram_rdata,

    input  wire signed [ARRAY_WIDTH-1:0][ACTIVATION_WIDTH-1:0]           npu_out_act,

    // 4-bit Interrupt Line to CPU
    output logic       [3:0]                                             efpga_usr_irq_o
);

    // =========================================================================
    // Internal Interconnect Wires
    // =========================================================================
    // CSR -> Sequencer / DMA
    wire        start_pulse;
    wire        soft_reset;
    wire [31:0] act_base;
    wire [31:0] weight_base;
    wire [31:0] out_base;
    wire [31:0] bias_base;
    wire [31:0] reg_quant_param;
    wire [31:0] reg_config;

    // Sequencer <-> CSR
    wire        busy_sig;
    wire        done_pulse;

    // Sequencer <-> DMA
    wire        start_bias;
    wire        bias_done;
    wire        start_act;
    wire        act_done;
    wire        start_weight;
    wire [3:0]  weight_pass_idx;
    wire        weight_done;

    wire        start_drain;
    wire        drain_done;
    wire [PSUM_ADDR_WIDTH-1:0] drain_psum_addr;
    wire [8:0]  dma_drain_pixel_cnt;

    // DMA Dedicated Memory Wires
    wire [PSUM_ADDR_WIDTH-1:0] dma_bias_psum_A_addr;
    wire [ARRAY_WIDTH-1:0]     dma_bias_psum_A_we;
    wire signed [PSUM_WIDTH-1:0] dma_bias_psum_A_wdata;
    wire [PSUM_ADDR_WIDTH-1:0] dma_bias_psum_B_addr;
    wire [ARRAY_WIDTH-1:0]     dma_bias_psum_B_we;
    wire signed [PSUM_WIDTH-1:0] dma_bias_psum_B_wdata;

    wire [NUM_ACT_BANKS-1:0]                     dma_ext_act_sram_we;
    wire [NUM_ACT_BANKS-1:0][ACT_ADDR_WIDTH-1:0] dma_ext_act_sram_addr;
    wire signed [NUM_ACT_BANKS-1:0][ACTIVATION_WIDTH-1:0] dma_ext_act_sram_wdata;

    // Sequencer Dedicated Memory Wires
    wire [PSUM_ADDR_WIDTH-1:0] seq_psum_A_addr;
    wire [ARRAY_WIDTH-1:0]     seq_psum_A_we;
    wire signed [PSUM_WIDTH-1:0] seq_psum_A_wdata;

    wire [PSUM_ADDR_WIDTH-1:0] seq_psum_B_addr;
    wire [ARRAY_WIDTH-1:0]     seq_psum_B_we;
    wire signed [PSUM_WIDTH-1:0] seq_psum_B_wdata;

    wire [NUM_ACT_BANKS-1:0][ACT_ADDR_WIDTH-1:0] seq_act_sram_addr;

    // Monitoring Wires for Testbench Inspection
    wire [3:0] seq_state_code;
    wire [3:0] seq_pass_idx;
    wire [1:0] seq_ky;
    wire [1:0] seq_kx;
    wire [8:0] seq_comp_k;

    // Hierarchical Aliases for Verification Compatibility
    wire [3:0] state_reg     = seq_state_code;
    wire [3:0] pass_idx      = seq_pass_idx;
    wire [1:0] ky            = seq_ky;
    wire [1:0] kx            = seq_kx;
    wire [8:0] comp_k        = seq_comp_k;
    wire [8:0] out_pixel_cnt = dma_drain_pixel_cnt;

    // Static read bank selects
    assign npu_psum_A_read_bank_sel = '0;
    assign npu_psum_B_read_bank_sel = '0;

    // =========================================================================
    // Memory Port Multiplexing
    // =========================================================================
    // Activation SRAM: DMA writes during Act Fetch; Sequencer reads during Compute
    assign npu_ext_act_sram_we    = dma_ext_act_sram_we;
    assign npu_ext_act_sram_wdata = dma_ext_act_sram_wdata;
    assign npu_ext_act_sram_addr  = (|dma_ext_act_sram_we) ? dma_ext_act_sram_addr : seq_act_sram_addr;

    // PSUM Bank A: Addressed by DMA during Bias Preload / Output Drain; by Sequencer during Compute
    assign npu_psum_A_addr  = (|dma_bias_psum_A_we) ? dma_bias_psum_A_addr :
                              (seq_state_code == 4'd10) ? drain_psum_addr : seq_psum_A_addr;
    assign npu_psum_A_we    = (|dma_bias_psum_A_we) ? dma_bias_psum_A_we : seq_psum_A_we;
    assign npu_psum_A_wdata = (|dma_bias_psum_A_we) ? dma_bias_psum_A_wdata : seq_psum_A_wdata;

    // PSUM Bank B: Addressed by DMA during Bias Preload; by Sequencer during Compute
    assign npu_psum_B_addr  = (|dma_bias_psum_B_we) ? dma_bias_psum_B_addr : seq_psum_B_addr;
    assign npu_psum_B_we    = (|dma_bias_psum_B_we) ? dma_bias_psum_B_we : seq_psum_B_we;
    assign npu_psum_B_wdata = (|dma_bias_psum_B_we) ? dma_bias_psum_B_wdata : seq_psum_B_wdata;

    // =========================================================================
    // Module 1: AXI4-Lite Slave Register File
    // =========================================================================
    npu_minimal_regs #(
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH)
    ) regs_inst (
        .clk_i            (clk_i),
        .rst_n            (rst_n),
        .s_axil_awaddr    (s_axil_awaddr),
        .s_axil_awprot    (s_axil_awprot),
        .s_axil_awvalid   (s_axil_awvalid),
        .s_axil_awready   (s_axil_awready),
        .s_axil_wdata     (s_axil_wdata),
        .s_axil_wstrb     (s_axil_wstrb),
        .s_axil_wvalid    (s_axil_wvalid),
        .s_axil_wready    (s_axil_wready),
        .s_axil_bresp     (s_axil_bresp),
        .s_axil_bvalid    (s_axil_bvalid),
        .s_axil_bready    (s_axil_bready),
        .s_axil_araddr    (s_axil_araddr),
        .s_axil_arprot    (s_axil_arprot),
        .s_axil_arvalid   (s_axil_arvalid),
        .s_axil_arready   (s_axil_arready),
        .s_axil_rdata     (s_axil_rdata),
        .s_axil_rresp     (s_axil_rresp),
        .s_axil_rvalid    (s_axil_rvalid),
        .s_axil_rready    (s_axil_rready),
        .start_pulse_o    (start_pulse),
        .soft_reset_o     (soft_reset),
        .act_base_o       (act_base),
        .weight_base_o    (weight_base),
        .out_base_o       (out_base),
        .bias_base_o      (bias_base),
        .quant_param_o    (reg_quant_param),
        .config_o         (reg_config),
        .usr_irq_o        (efpga_usr_irq_o),
        .fsm_busy_i       (busy_sig),
        .fsm_done_i       (done_pulse),
        .irq_pulse_i      (done_pulse)
    );

    // =========================================================================
    // Module 2: AXI4 Master DMA Engine
    // =========================================================================
    npu_minimal_dma #(
        .ARRAY_HEIGHT    (ARRAY_HEIGHT),
        .ARRAY_WIDTH     (ARRAY_WIDTH),
        .TILE_SIZE       (TILE_SIZE),
        .ACT_HALO_PAD    (ACT_HALO_PAD),
        .ACTIVATION_WIDTH(ACTIVATION_WIDTH),
        .WEIGHT_WIDTH    (WEIGHT_WIDTH),
        .PSUM_WIDTH      (PSUM_WIDTH),
        .AXI_ADDR_WIDTH  (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH  (AXI_DATA_WIDTH),
        .WEIGHT_SPLIT    (WEIGHT_SPLIT)
    ) dma_inst (
        .clk_i               (clk_i),
        .rst_n               (rst_n),
        .m_axi_awaddr        (m_axi_awaddr),
        .m_axi_awlen         (m_axi_awlen),
        .m_axi_awsize        (m_axi_awsize),
        .m_axi_awburst       (m_axi_awburst),
        .m_axi_awvalid       (m_axi_awvalid),
        .m_axi_awready       (m_axi_awready),
        .m_axi_wdata         (m_axi_wdata),
        .m_axi_wstrb         (m_axi_wstrb),
        .m_axi_wlast         (m_axi_wlast),
        .m_axi_wvalid        (m_axi_wvalid),
        .m_axi_wready        (m_axi_wready),
        .m_axi_bresp         (m_axi_bresp),
        .m_axi_bvalid        (m_axi_bvalid),
        .m_axi_bready        (m_axi_bready),
        .m_axi_araddr        (m_axi_araddr),
        .m_axi_arlen         (m_axi_arlen),
        .m_axi_arsize        (m_axi_arsize),
        .m_axi_arburst       (m_axi_arburst),
        .m_axi_arvalid       (m_axi_arvalid),
        .m_axi_arready       (m_axi_arready),
        .m_axi_rdata         (m_axi_rdata),
        .m_axi_rresp         (m_axi_rresp),
        .m_axi_rlast         (m_axi_rlast),
        .m_axi_rvalid        (m_axi_rvalid),
        .m_axi_rready        (m_axi_rready),
        .act_base_i          (act_base),
        .weight_base_i       (weight_base),
        .out_base_i          (out_base),
        .bias_base_i         (bias_base),
        .start_bias_i        (start_bias),
        .bias_done_o         (bias_done),
        .start_act_i         (start_act),
        .act_done_o          (act_done),
        .start_weight_i      (start_weight),
        .weight_pass_idx_i   (weight_pass_idx),
        .weight_done_o       (weight_done),
        .weight_shift_in_o   (npu_weight_shift_in),
        .weight_shift_en_o   (npu_weight_shift_en),
        .start_drain_i       (start_drain),
        .drain_done_o        (drain_done),
        .drain_psum_addr_o   (drain_psum_addr),
        .npu_out_act_i       (npu_out_act),
        .drain_pixel_cnt_o   (dma_drain_pixel_cnt),
        .bias_psum_A_addr_o  (dma_bias_psum_A_addr),
        .bias_psum_A_we_o    (dma_bias_psum_A_we),
        .bias_psum_A_wdata_o (dma_bias_psum_A_wdata),
        .bias_psum_B_addr_o  (dma_bias_psum_B_addr),
        .bias_psum_B_we_o    (dma_bias_psum_B_we),
        .bias_psum_B_wdata_o (dma_bias_psum_B_wdata),
        .ext_act_sram_we_o   (dma_ext_act_sram_we),
        .ext_act_sram_addr_o (dma_ext_act_sram_addr),
        .ext_act_sram_wdata_o(dma_ext_act_sram_wdata)
    );

    // =========================================================================
    // Module 3: Central Orchestration FSM & Address Generator
    // =========================================================================
    npu_minimal_sequencer #(
        .ARRAY_HEIGHT    (ARRAY_HEIGHT),
        .ARRAY_WIDTH     (ARRAY_WIDTH),
        .TILE_SIZE       (TILE_SIZE),
        .ACT_HALO_PAD    (ACT_HALO_PAD),
        .ACTIVATION_WIDTH(ACTIVATION_WIDTH),
        .WEIGHT_WIDTH    (WEIGHT_WIDTH),
        .PSUM_WIDTH      (PSUM_WIDTH),
        .SCALE_WIDTH     (SCALE_WIDTH),
        .WEIGHT_SPLIT    (WEIGHT_SPLIT)
    ) seq_inst (
        .clk_i                    (clk_i),
        .rst_n                    (rst_n),
        .start_pulse_i            (start_pulse),
        .soft_reset_i             (soft_reset),
        .reg_quant_param_i        (reg_quant_param),
        .reg_config_i             (reg_config),
        .busy_o                   (busy_sig),
        .done_pulse_o             (done_pulse),
        .start_bias_o             (start_bias),
        .bias_done_i              (bias_done),
        .start_act_o              (start_act),
        .act_done_i               (act_done),
        .start_weight_o           (start_weight),
        .weight_pass_idx_o        (weight_pass_idx),
        .weight_done_i            (weight_done),
        .start_drain_o            (start_drain),
        .drain_done_i             (drain_done),
        .npu_array_en_o           (npu_array_en),
        .npu_psum_systolic_en_o   (npu_psum_systolic_en),
        .npu_psum_lut_en_o        (npu_psum_lut_en),
        .npu_psum_skew_en_o       (npu_psum_skew_en),
        .npu_compute_bank_swap_o  (npu_compute_bank_swap),
        .npu_crossbar_sel_o       (npu_crossbar_sel),
        .npu_swap_weights_o       (npu_swap_weights),
        .npu_quant_shift_in_o     (npu_quant_shift_in),
        .npu_quant_shift_en_o     (npu_quant_shift_en),
        .npu_stochastic_round_en_o(npu_stochastic_round_en),
        .seq_psum_A_addr_o        (seq_psum_A_addr),
        .seq_psum_A_we_o          (seq_psum_A_we),
        .seq_psum_A_wdata_o       (seq_psum_A_wdata),
        .seq_psum_B_addr_o        (seq_psum_B_addr),
        .seq_psum_B_we_o          (seq_psum_B_we),
        .seq_psum_B_wdata_o       (seq_psum_B_wdata),
        .seq_act_sram_addr_o      (seq_act_sram_addr),
        .state_code_o             (seq_state_code),
        .pass_idx_o               (seq_pass_idx),
        .ky_o                     (seq_ky),
        .kx_o                     (seq_kx),
        .comp_k_o                 (seq_comp_k)
    );

endmodule
