`timescale 1ns / 1ps

/* ===============================================================================================
 * File: SOFT_LOGIC/full/npu_full_controller.sv
 * Module: npu_full_controller
 * Project: CrocoScale SoC — Top-Level Dual-Mode (3x3 & 1x1) eFPGA Controller
 *
 * Description:
 *   Full synthesizable eFPGA soft-logic controller integrating:
 *   - AXI4-Lite CSR register file (npu_full_regs) with contiguous memory pointers
 *   - Modular dual-mode sequencer (npu_full_sequencer)
 *   - Modular AXI4 burst DMA with shared read master (npu_full_dma)
 *
 *   Configuration Register (REG_CONFIG at 0x08):
 *     Bit 0:     AUTO_DRAIN_OUT
 *     Bit 4:     MODE_1x1 (0 = Conv 3x3 im2col, 1 = Conv 1x1 half-array)
 *     Bit 5:     LUT_EN (0 = linear requant drain, 1 = Bank B non-linear LUT activation)
 *     Bits 15:8: TOTAL_PASSES (if 0, defaults to parameter TOTAL_PASSES)
 * =============================================================================================== */

module npu_full_controller #(
    parameter int ARRAY_HEIGHT     = 8,
    parameter int ARRAY_WIDTH      = 8,
    parameter int TILE_SIZE        = 16,
    parameter int ACT_HALO_PAD     = 1,
    parameter int ACTIVATION_WIDTH = 8,
    parameter int WEIGHT_WIDTH     = 8,
    parameter int PSUM_WIDTH       = 32,
    parameter int SCALE_WIDTH      = 16,
    parameter int WEIGHT_SPLIT     = 2,
    parameter int AXI_ADDR_WIDTH   = 32,
    parameter int AXI_DATA_WIDTH   = 32,
    parameter int TOTAL_PASSES     = 144,
    parameter int CIN              = 128,
    parameter int COUT             = 32
) (
    input  wire                                                          clk_i,
    input  wire                                                          rst_n,

    // CPU Control: AXI4-Lite Slave Interface
    input  wire        [AXI_ADDR_WIDTH-1:0]                              s_axil_awaddr,
    input  wire        [2:0]                                             s_axil_awprot,
    input  wire                                                          s_axil_awvalid,
    output wire                                                          s_axil_awready,

    input  wire        [AXI_DATA_WIDTH-1:0]                              s_axil_wdata,
    input  wire        [(AXI_DATA_WIDTH/8)-1:0]                          s_axil_wstrb,
    input  wire                                                          s_axil_wvalid,
    output wire                                                          s_axil_wready,

    output wire        [1:0]                                             s_axil_bresp,
    output wire                                                          s_axil_bvalid,
    input  wire                                                          s_axil_bready,

    input  wire        [AXI_ADDR_WIDTH-1:0]                              s_axil_araddr,
    input  wire        [2:0]                                             s_axil_arprot,
    input  wire                                                          s_axil_arvalid,
    output wire                                                          s_axil_arready,

    output wire        [AXI_DATA_WIDTH-1:0]                              s_axil_rdata,
    output wire        [1:0]                                             s_axil_rresp,
    output wire                                                          s_axil_rvalid,
    input  wire                                                          s_axil_rready,

    // Memory Dataflow: AXI4 Full Master Interface
    output wire        [AXI_ADDR_WIDTH-1:0]                              m_axi_awaddr,
    output wire        [7:0]                                             m_axi_awlen,
    output wire        [2:0]                                             m_axi_awsize,
    output wire        [1:0]                                             m_axi_awburst,
    output wire                                                          m_axi_awvalid,
    input  wire                                                          m_axi_awready,

    output wire        [AXI_DATA_WIDTH-1:0]                              m_axi_wdata,
    output wire        [(AXI_DATA_WIDTH/8)-1:0]                          m_axi_wstrb,
    output wire                                                          m_axi_wlast,
    output wire                                                          m_axi_wvalid,
    input  wire                                                          m_axi_wready,

    input  wire        [1:0]                                             m_axi_bresp,
    input  wire                                                          m_axi_bvalid,
    output wire                                                          m_axi_bready,

    output wire        [AXI_ADDR_WIDTH-1:0]                              m_axi_araddr,
    output wire        [7:0]                                             m_axi_arlen,
    output wire        [2:0]                                             m_axi_arsize,
    output wire        [1:0]                                             m_axi_arburst,
    output wire                                                          m_axi_arvalid,
    input  wire                                                          m_axi_arready,

    input  wire        [AXI_DATA_WIDTH-1:0]                              m_axi_rdata,
    input  wire        [1:0]                                             m_axi_rresp,
    input  wire                                                          m_axi_rlast,
    input  wire                                                          m_axi_rvalid,
    output wire                                                          m_axi_rready,

    // Dedicated Hardware Ports to NPU Complex
    output wire                                                          npu_array_en,
    output wire                                                          npu_psum_systolic_en,
    output wire                                                          npu_psum_lut_en,
    output wire                                                          npu_psum_skew_en,
    output wire                                                          npu_compute_bank_swap,
    output wire        [ARRAY_HEIGHT-1:0][3:0]                           npu_crossbar_sel,

    output wire signed [ARRAY_HEIGHT-1:0][WEIGHT_WIDTH-1:0]              npu_weight_shift_in,
    output wire        [WEIGHT_SPLIT-1:0]                                npu_weight_shift_en,
    output wire                                                          npu_swap_weights,

    output wire        [29:0]                                            npu_quant_shift_in,
    output wire                                                          npu_quant_shift_en,
    output wire                                                          npu_stochastic_round_en,

    output wire        [7:0]                                             npu_psum_A_addr,
    output wire        [ARRAY_WIDTH-1:0]                                 npu_psum_A_we,
    output wire signed [PSUM_WIDTH-1:0]                                  npu_psum_A_wdata,
    output wire        [2:0]                                             npu_psum_A_read_bank_sel,
    input  wire signed [PSUM_WIDTH-1:0]                                  npu_psum_A_rdata,

    output wire        [7:0]                                             npu_psum_B_addr,
    output wire        [ARRAY_WIDTH-1:0]                                 npu_psum_B_we,
    output wire signed [PSUM_WIDTH-1:0]                                  npu_psum_B_wdata,
    output wire        [2:0]                                             npu_psum_B_read_bank_sel,
    input  wire signed [PSUM_WIDTH-1:0]                                  npu_psum_B_rdata,

    output wire        [ARRAY_HEIGHT-1:0]                                npu_ext_act_sram_we,
    output wire        [ARRAY_HEIGHT-1:0][8:0]                           npu_ext_act_sram_addr,

    input  wire signed [ARRAY_WIDTH-1:0][ACTIVATION_WIDTH-1:0]           npu_out_act,
    output wire        [3:0]                                             efpga_usr_irq_o
);

    // CSR Wires
    wire [31:0] act_base;
    wire [31:0] weight_base;
    wire [31:0] out_base;
    wire [31:0] bias_base;
    wire [31:0] quant_base;
    wire [31:0] lut_base;
    wire [31:0] config_reg;
    wire        start_pulse;
    wire        start_drain_pulse;
    wire        soft_reset;

    wire auto_drain = config_reg[0];
    wire mode_1x1   = config_reg[4];
    wire lut_en     = config_reg[5];
    wire pool_en    = config_reg[6];
    wire [7:0] total_passes = (config_reg[15:8] != 8'd0) ? config_reg[15:8] : 8'(TOTAL_PASSES);

    // Sequencer Wires
    wire        seq_busy;
    wire        seq_done;
    wire [7:0]  current_pass;
    wire [8:0]  cycle_in_pass;
    wire [ARRAY_HEIGHT-1:0][8:0] seq_act_sram_addr;
    wire [ARRAY_HEIGHT-1:0]      seq_act_sram_we;
    wire [1:0]  seq_weight_shift_en;
    wire        seq_swap_weights;
    wire [2:0]  seq_weight_shift_step;
    wire [7:0]  seq_psum_A_addr;
    wire [ARRAY_WIDTH-1:0] seq_psum_A_we;
    wire [7:0]  seq_psum_B_addr;
    wire [ARRAY_WIDTH-1:0] seq_psum_B_we;
    wire        preload_phase;
    wire [7:0]  preload_step;
    wire signed [7:0] dma_channel_to_load;
    wire [5:0][5:0]   dma_bank_ptr;
    wire        seq_start_lut_load;
    wire        seq_lut_phase;
    wire        drain_phase;
    wire [8:0]  drain_step;

    // DMA Wires
    wire        dma_preload_done;
    wire        dma_weight_fetch_done;
    wire        dma_lut_load_done;
    wire        dma_drain_done;
    wire [7:0]  dma_drain_psum_addr;
    wire signed [ARRAY_HEIGHT-1:0][WEIGHT_WIDTH-1:0] dma_weight_shift_in;
    wire [1:0]  dma_weight_shift_en;
    wire signed [PSUM_WIDTH-1:0] dma_bias_wdata;
    wire [2:0]  dma_bias_channel;
    wire        dma_bias_we;
    wire [7:0]  dma_lut_psum_B_addr;
    wire [31:0] dma_lut_psum_B_wdata;
    wire [7:0]  dma_lut_psum_B_we;

    assign npu_psum_A_read_bank_sel = 3'd0;
    assign npu_psum_B_read_bank_sel = 3'd0;
    assign npu_stochastic_round_en  = 1'b0;

    assign npu_ext_act_sram_we   = seq_act_sram_we;
    assign npu_ext_act_sram_addr = seq_act_sram_addr;

    wire bias_target_bank_b = total_passes[0]; // Odd total passes compute starting from Bank B
    logic [7:0] dma_bias_we_vec;
    always_comb begin
        for (int c = 0; c < 8; c++) begin
            dma_bias_we_vec[c] = dma_bias_we && (dma_bias_channel == 3'(c));
        end
    end

    // Multiplexing for PSUM Bank A & Bank B
    assign npu_psum_A_addr  = drain_phase ? dma_drain_psum_addr :
                             (preload_phase ? 8'h00 : seq_psum_A_addr);
    assign npu_psum_A_we    = preload_phase ? (!bias_target_bank_b ? dma_bias_we_vec : 8'h00) :
                             seq_psum_A_we;
    assign npu_psum_A_wdata = dma_bias_wdata;

    assign npu_psum_B_addr  = seq_lut_phase ? dma_lut_psum_B_addr  :
                             (preload_phase ? 8'h00 : seq_psum_B_addr);
    assign npu_psum_B_we    = seq_lut_phase ? dma_lut_psum_B_we    :
                             (preload_phase ? (bias_target_bank_b ? dma_bias_we_vec : 8'h00) : seq_psum_B_we);
    assign npu_psum_B_wdata = seq_lut_phase ? dma_lut_psum_B_wdata : dma_bias_wdata;

    assign npu_weight_shift_en = dma_weight_shift_en;
    assign npu_swap_weights    = (preload_phase && (preload_step == (mode_1x1 ? 8'd255 : 8'd53))) ? 1'b1 :
                                 (preload_phase ? 1'b0 : seq_swap_weights);
    assign npu_weight_shift_in = dma_weight_shift_in;

    // Trigger DMA weight fetch:
    // - Pass 0: at completion of bias & quant parameter preload
    // - Next passes: during systolic compute when cycle reaches 24
    wire start_weight_fetch = (preload_phase && dma_preload_done) ||
                              ((cycle_in_pass == 9'd24) && (current_pass + 1'b1 < total_passes));
    wire [7:0] next_pass    = preload_phase ? 8'd0 : (current_pass + 1'b1);

    // 1. AXI-Lite Register File with Contiguous Base Pointers
    npu_full_regs #(
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH)
    ) regs_inst (
        .clk_i         (clk_i),
        .rst_n         (rst_n),
        .s_axil_awaddr (s_axil_awaddr),
        .s_axil_awprot (s_axil_awprot),
        .s_axil_awvalid(s_axil_awvalid),
        .s_axil_awready(s_axil_awready),
        .s_axil_wdata  (s_axil_wdata),
        .s_axil_wstrb  (s_axil_wstrb),
        .s_axil_wvalid (s_axil_wvalid),
        .s_axil_wready (s_axil_wready),
        .s_axil_bresp  (s_axil_bresp),
        .s_axil_bvalid (s_axil_bvalid),
        .s_axil_bready (s_axil_bready),
        .s_axil_araddr (s_axil_araddr),
        .s_axil_arprot (s_axil_arprot),
        .s_axil_arvalid(s_axil_arvalid),
        .s_axil_arready(s_axil_arready),
        .s_axil_rdata  (s_axil_rdata),
        .s_axil_rresp  (s_axil_rresp),
        .s_axil_rvalid (s_axil_rvalid),
        .s_axil_rready       (s_axil_rready),
        .start_pulse_o       (start_pulse),
        .start_drain_pulse_o (start_drain_pulse),
        .soft_reset_o        (soft_reset),
        .config_o            (config_reg),
        .act_base_o          (act_base),
        .weight_base_o       (weight_base),
        .out_base_o          (out_base),
        .bias_base_o         (bias_base),
        .quant_base_o        (quant_base),
        .lut_base_o          (lut_base),
        .usr_irq_o           (efpga_usr_irq_o),
        .fsm_busy_i          (seq_busy),
        .fsm_done_i          (seq_done),
        .irq_pulse_i         (seq_done)
    );

    // 2. Modular Dual-Mode Sequencer
    npu_full_sequencer #(
        .ARRAY_HEIGHT(ARRAY_HEIGHT),
        .ARRAY_WIDTH (ARRAY_WIDTH),
        .TILE_SIZE   (TILE_SIZE),
        .ACT_HALO_PAD(ACT_HALO_PAD),
        .CIN         (CIN),
        .COUT        (COUT)
    ) sequencer_inst (
        .clk_i                (clk_i),
        .rst_n                (rst_n && !soft_reset),
        .start_i              (start_pulse),
        .start_drain_i        (start_drain_pulse),
        .auto_drain_i         (auto_drain),
        .mode_1x1_i           (mode_1x1),
        .lut_en_i             (lut_en),
        .lut_load_done_i      (dma_lut_load_done),
        .drain_done_i         (dma_drain_done),
        .total_passes_i       (total_passes),
        .busy_o               (seq_busy),
        .done_o               (seq_done),
        .current_pass_o       (current_pass),
        .cycle_in_pass_o      (cycle_in_pass),
        .array_en_o           (npu_array_en),
        .psum_systolic_en_o   (npu_psum_systolic_en),
        .psum_lut_en_o        (npu_psum_lut_en),
        .psum_skew_en_o       (npu_psum_skew_en),
        .compute_bank_swap_o  (npu_compute_bank_swap),
        .crossbar_sel_o       (npu_crossbar_sel),
        .act_sram_addr_o      (seq_act_sram_addr),
        .act_sram_we_o        (seq_act_sram_we),
        .weight_shift_en_o    (seq_weight_shift_en),
        .swap_weights_o       (seq_swap_weights),
        .weight_shift_step_o  (seq_weight_shift_step),
        .psum_A_addr_o        (seq_psum_A_addr),
        .psum_A_we_o          (seq_psum_A_we),
        .psum_B_addr_o        (seq_psum_B_addr),
        .psum_B_we_o          (seq_psum_B_we),
        .preload_phase_o      (preload_phase),
        .preload_step_o       (preload_step),
        .dma_channel_to_load_o(dma_channel_to_load),
        .dma_bank_ptr_o       (dma_bank_ptr),
        .start_lut_load_o     (seq_start_lut_load),
        .lut_phase_o          (seq_lut_phase),
        .drain_phase_o        (drain_phase),
        .drain_step_o         (drain_step)
    );

    // 3. Modular Dual-Mode AXI4 Master DMA with Shared Read Master
    npu_full_dma #(
        .ARRAY_HEIGHT    (ARRAY_HEIGHT),
        .ARRAY_WIDTH     (ARRAY_WIDTH),
        .ACTIVATION_WIDTH(ACTIVATION_WIDTH),
        .WEIGHT_WIDTH    (WEIGHT_WIDTH),
        .PSUM_WIDTH      (PSUM_WIDTH),
        .AXI_ADDR_WIDTH  (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH  (AXI_DATA_WIDTH)
    ) dma_inst (
        .clk_i               (clk_i),
        .rst_n               (rst_n && !soft_reset),
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
        .quant_base_i        (quant_base),
        .lut_base_i          (lut_base),
        .mode_1x1_i          (mode_1x1),
        .lut_en_i            (lut_en),
        .pool_en_i           (pool_en),

        .start_preload_i     (start_pulse),
        .preload_done_o      (dma_preload_done),

        .start_weight_fetch_i(start_weight_fetch),
        .fetch_pass_idx_i    (next_pass),
        .weight_fetch_done_o (dma_weight_fetch_done),

        .start_lut_load_i    (seq_start_lut_load),
        .lut_load_done_o     (dma_lut_load_done),

        .start_drain_i       (drain_phase),
        .drain_done_o        (dma_drain_done),
        .drain_psum_addr_o   (dma_drain_psum_addr),
        .npu_out_act_i       (npu_out_act),

        .weight_shift_in_o   (dma_weight_shift_in),
        .weight_shift_en_o   (dma_weight_shift_en),
        .bias_wdata_o        (dma_bias_wdata),
        .bias_channel_o      (dma_bias_channel),
        .bias_we_o           (dma_bias_we),
        .quant_shift_in_o    (npu_quant_shift_in),
        .quant_shift_en_o    (npu_quant_shift_en),

        .psum_B_addr_o       (dma_lut_psum_B_addr),
        .psum_B_wdata_o      (dma_lut_psum_B_wdata),
        .psum_B_we_o         (dma_lut_psum_B_we)
    );

endmodule
