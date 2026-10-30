// =============================================================================
// File: SOFT_LOGIC/flex/npu_flex_sequencer.sv
// Module: npu_flex_sequencer
// Project: CrocoScale SoC — 8-Bank (4x2) Dual-Mode (3x3 & 1x1) Soft-Logic Controller
//
// Description:
//   Top-level 8-bank (4x2) dual-mode (3x3 & 1x1) convolution soft-logic controller
//   integrating:
//   - AXI4-Lite Slave CSR register file (npu_flex_axil_csr)
//   - Central FSM & progression counters (npu_flex_fsm)
//   - Direct per-bank 8-SRAM 3x3 & 1x1 address & crossbar driver (npu_flex_addr)
//   - AXI4 Read Master burst engine & in-place staging (npu_flex_axi_reader)
//   - PSUM ping-pong accumulation, LUT load & drain scheduler (npu_flex_psum)
//   - Skewed drain, optional 2x2 MaxPool & AXI4 burst writer (npu_flex_axi_writer)
//   - Shared time-multiplexed geometry barrel shifter, 23-bit channel address
//     register/adder, and sub-strip row bounds comparators between Read & Write.
// =============================================================================

`timescale 1ns / 1ps

module npu_flex_sequencer #(
    parameter int ARRAY_HEIGHT     = 8,
    parameter int ARRAY_WIDTH      = 8,
    parameter int TILE_SIZE        = 16,
    parameter int ACT_HALO_PAD     = 2,
    parameter int ACTIVATION_WIDTH = 8,
    parameter int WEIGHT_WIDTH     = 8,
    parameter int PSUM_WIDTH       = 32,
    parameter int AXIL_ADDR_WIDTH  = 10,
    parameter int AXI_ADDR_WIDTH   = 32,
    parameter int AXI_DATA_WIDTH   = 32,
    parameter int TOTAL_PASSES     = 144,
    parameter int CIN              = 128,
    parameter int COUT             = 32,
    parameter int DEFAULT_H        = 32,
    parameter int DEFAULT_W        = 32,
    parameter int FIFO_DEPTH       = 4
) (
    input  wire                                          clk_i,
    input  wire                                          rst_n,

    // AXI4-Lite Slave Interface (CPU Control via Boundary BEL)
    input  wire  [AXIL_ADDR_WIDTH-1:0]                   s_axil_awaddr,
    input  wire  [2:0]                                   s_axil_awprot,
    input  wire                                          s_axil_awvalid,
    output logic                                         s_axil_awready,

    input  wire  [AXI_DATA_WIDTH-1:0]                    s_axil_wdata,
    input  wire  [(AXI_DATA_WIDTH/8)-1:0]                s_axil_wstrb,
    input  wire                                          s_axil_wvalid,
    output logic                                         s_axil_wready,

    output logic [1:0]                                   s_axil_bresp,
    output logic                                         s_axil_bvalid,
    input  wire                                          s_axil_bready,

    input  wire  [AXIL_ADDR_WIDTH-1:0]                   s_axil_araddr,
    input  wire  [2:0]                                   s_axil_arprot,
    input  wire                                          s_axil_arvalid,
    output logic                                         s_axil_arready,

    output logic [AXI_DATA_WIDTH-1:0]                    s_axil_rdata,
    output logic [1:0]                                   s_axil_rresp,
    output logic                                         s_axil_rvalid,
    input  wire                                          s_axil_rready,

    // AXI4 Read & Write Master Interface (to System RAM via Boundary BEL)
    output logic [AXI_ADDR_WIDTH-1:0]                    m_axi_awaddr,
    output logic [7:0]                                   m_axi_awlen,
    output logic                                         m_axi_awvalid,
    input  wire                                          m_axi_awready,
    output logic [AXI_DATA_WIDTH-1:0]                    m_axi_wdata,
    output logic [(AXI_DATA_WIDTH/8)-1:0]                m_axi_wstrb,
    output logic                                         m_axi_wlast,
    output logic                                         m_axi_wvalid,
    input  wire                                          m_axi_wready,
    input  wire  [1:0]                                   m_axi_bresp,
    input  wire                                          m_axi_bvalid,
    output logic                                         m_axi_bready,

    output logic [AXI_ADDR_WIDTH-1:0]                    m_axi_araddr,
    output logic [7:0]                                   m_axi_arlen,
    output logic                                         m_axi_arvalid,
    input  wire                                          m_axi_arready,
    input  wire  [AXI_DATA_WIDTH-1:0]                    m_axi_rdata,
    input  wire  [1:0]                                   m_axi_rresp,
    input  wire                                          m_axi_rlast,
    input  wire                                          m_axi_rvalid,
    output logic                                         m_axi_rready,

    // User Interrupt Output (to efpga_manager)
    output logic [3:0]                                   usr_irq_o,

    // Status & Progression Outputs
    output logic                                         busy_o,
    output logic                                         done_o,
    output logic [10:0]                                  current_pass_o,
    output logic [8:0]                                   cycle_in_pass_o,

    // Array Mode Controls
    output logic                                         array_en_o,
    output logic                                         psum_systolic_en_o,
    output logic                                         psum_skew_en_o,
    output logic                                         psum_lut_en_o,
    output logic                                         compute_bank_swap_o,

    // Crossbar Selection per Systolic Row
    output logic [ARRAY_HEIGHT-1:0][3:0]                 crossbar_sel_o,

    // Activation SRAM Memory Interfaces & Requantized Output Input
    output logic [ARRAY_HEIGHT-1:0][8:0]                 act_sram_addr_o,
    output logic [ARRAY_HEIGHT-1:0]                      act_sram_we_o,
    output logic [ARRAY_HEIGHT-1:0][ACTIVATION_WIDTH-1:0] act_sram_wdata_o,
    input  wire  [ARRAY_HEIGHT-1:0][ACTIVATION_WIDTH-1:0] act_sram_rdata_i,
    input  wire  [ARRAY_WIDTH-1:0][ACTIVATION_WIDTH-1:0]  out_act_i,

    // Systolic Weight Pre-Shift, Swap & Quant Config Timing
    output logic signed [ARRAY_HEIGHT-1:0][WEIGHT_WIDTH-1:0] weight_shift_in_o,
    output logic [ARRAY_HEIGHT-1:0]                      weight_shift_en_o,
    output logic                                         swap_weights_o,
    output logic [29:0]                                  quant_shift_in_o,
    output logic                                         quant_shift_en_o,

    // PSUM Bank A/B Memory Interfaces
    output logic [7:0]                                   psum_A_addr_o,
    output logic [ARRAY_WIDTH-1:0]                       psum_A_we_o,
    output logic signed [PSUM_WIDTH-1:0]                 psum_A_wdata_o,
    output logic [7:0]                                   psum_B_addr_o,
    output logic [ARRAY_WIDTH-1:0]                       psum_B_we_o,
    output logic signed [PSUM_WIDTH-1:0]                 psum_B_wdata_o,

    // Phase & Drain Synchronization
    output logic                                         preload_phase_o,
    output logic signed [11:0]                           dma_channel_to_load_o,
    output logic [7:0][5:0]                              dma_bank_ptr_o,
    output logic                                         lut_phase_o,
    output logic                                         drain_phase_o,
    output logic [10:0]                                  drain_step_o
);

    localparam logic [2:0] SEQ_COMPUTE = 3'd2;
    localparam logic [2:0] SEQ_DRAIN   = 3'd4;

    // Decoded CSR Signals
    wire        start_pulse;
    wire        start_drain_pulse;
    wire        soft_reset;
    wire        auto_drain;
    wire        mode_1x1;
    wire        lut_en;
    wire        pool_en;
    wire        pool_s1_en;
    wire [10:0] csr_total_passes;
    wire [4:0]  tile_x;
    wire [4:0]  tile_y;
    wire [8:0]  img_w;
    wire [8:0]  img_h;
    wire [10:0] cfg_cin;
    wire [31:0] act_base;
    wire [31:0] weight_base;
    wire [31:0] out_base;
    wire [31:0] bias_base;
    wire [31:0] quant_base;
    wire [31:0] lut_base;

    wire [10:0] total_passes = (csr_total_passes != 11'd0) ? csr_total_passes : 11'(TOTAL_PASSES);
    wire        sys_rst_n    = rst_n && !soft_reset;

    wire [2:0]                    state;
    wire                          fsm_busy;
    wire                          fsm_done;
    wire [10:0]                   pass_cnt;
    wire [8:0]                    k_cnt;
    wire [10:0]                   drain_cnt;
    wire [3:0]                    tap_0;
    wire                          preload_done;
    wire                          pass_advance;
    wire                          enter_lut_load;
    wire                          first_pass;
    wire                          prev_pass_drained;
    wire                          swap_val;
    wire                          writer_done;

    wire                          dma_pass_ready;
    wire [7:0]                    bank_read_used;
    wire [7:0]                    dma_we;
    wire [7:0][8:0]               dma_addr;
    wire [7:0][7:0]               dma_wdata;

    wire [7:0][8:0]               comp_act_addr;
    wire [7:0]                    drain_act_we;
    wire [7:0][8:0]               drain_act_addr;
    wire [7:0][7:0]               drain_act_wdata;

    wire signed [PSUM_WIDTH-1:0]  bias_wdata;
    wire [ARRAY_WIDTH-1:0]        bias_we;
    wire [7:0]                    lut_wdata;
    wire                          lut_we;

    // -------------------------------------------------------------------------
    // Shared Read/Write Geometry Shifter, 23-Bit Channel Address & Row Bounds
    // -------------------------------------------------------------------------
    wire        is_drain         = (state == SEQ_DRAIN);
    wire        drain_pool       = is_drain && pool_en;
    wire        pad_x            = !is_drain && !mode_1x1;
    wire [8:0]  h_eff            = drain_pool ? {1'b0, img_h[8:1]} : img_h;
    wire [8:0]  w_eff            = drain_pool ? {1'b0, img_w[8:1]} : img_w;
    wire [8:0]  w_m1             = w_eff - 9'd1;
    wire [2:0]  w_shift_m4       = w_m1[8] ? 3'd5 :
                                   w_m1[7] ? 3'd4 :
                                   w_m1[6] ? 3'd3 :
                                   w_m1[5] ? 3'd2 :
                                   w_m1[4] ? 3'd1 : 3'd0;
    wire        h_rem_nz         = (h_eff[1:0] != 2'd0);
    wire [7:0]  num_strips_y_eff = {1'b0, h_eff[8:2]} + {7'd0, h_rem_nz};

    wire [6:0]  rd_cur_strip_y;
    wire        rd_use_strip_y;
    wire        rd_ch_init;
    wire        rd_ch_adv;

    wire [1:0]  s1_ty_hi;
    wire [6:0]  wb_cur_strip_y;
    wire        wb_use_strip_y;
    wire        wb_ch_init;
    wire        wb_ch_adv;

    wire [6:0]  cur_strip_y_eff  = is_drain ? wb_cur_strip_y : rd_cur_strip_y;
    wire        use_strip_y_eff  = is_drain ? wb_use_strip_y : rd_use_strip_y;
    wire [7:0]  shift_in_eff     = use_strip_y_eff ? {1'b0, cur_strip_y_eff} : num_strips_y_eff;
    wire [12:0] shifted_words_hi = 13'(shift_in_eff) << w_shift_m4;

    // Shared horizontal tile offset and valid beat clamp via 5-bit tile subtractor
    wire        has_left_pad     = pad_x && (tile_x == 5'd0);
    wire [5:0]  tx_diff_hi       = {1'b0, img_w[8:4]} - {1'b0, tile_x};
    wire [4:0]  max_beats_eff    = drain_pool ? 5'd8 : (pad_x ? 5'd18 : 5'd16);
    wire [5:0]  rem_unpooled     = {1'b0, tx_diff_hi[0], img_w[3:0]} + {5'd0, pad_x};
    wire [5:0]  rem_x            = drain_pool ? {1'b0, tx_diff_hi[0], 1'b0, img_w[3:1]} : rem_unpooled;
    wire [4:0]  shared_end_x     = tx_diff_hi[5] ? 5'd0 :
                                   ((|tx_diff_hi[4:1] || (rem_x >= {1'b0, max_beats_eff})) ? max_beats_eff : rem_x[4:0]);
    wire [5:0]  shared_arlen_sub = {1'b0, shared_end_x} + {5'b11111, ~has_left_pad};
    wire [4:0]  shared_beats_m1  = shared_arlen_sub[4:0];
    wire        shared_beats_zero= shared_arlen_sub[5];

    // Single shared 23-bit word address adder for init, channel stride, and strip offset
    logic [22:0] shared_ch_addr;
    wire         ch_init                = rd_ch_init || wb_ch_init;
    wire         ch_adv                 = rd_ch_adv  || wb_ch_adv;
    wire  [22:0] init_base_word         = is_drain ? out_base[24:2] : act_base[24:2];
    wire  [9:0]  tile_x0_eff            = drain_pool ? {2'b00, tile_x, 3'b000} : {1'b0, tile_x, 4'b0000};
    wire  [9:0]  init_tx_word           = has_left_pad ? 10'd0 :
                                          (pad_x ? {1'b0, tile_x - 5'd1, 4'b1111} : tile_x0_eff);
    wire  [22:0] ch_add_op_a            = ch_init ? init_base_word        : shared_ch_addr;
    wire  [22:0] ch_add_op_b            = ch_init ? {13'd0, init_tx_word} : {6'd0, shifted_words_hi, 4'b0000};
    wire  [22:0] shared_ch_plus_shifted = ch_add_op_a + ch_add_op_b;

    always_ff @(posedge clk_i) begin
        if (!sys_rst_n) begin
            shared_ch_addr <= 23'd0;
        end else if (ch_init || ch_adv) begin
            shared_ch_addr <= shared_ch_plus_shifted;
        end
    end

    wire       gy_lt_hi = (cur_strip_y_eff < h_eff[8:2]);
    wire       gy_eq_hi = (cur_strip_y_eff == h_eff[8:2]);
    wire [3:0] shared_row_lt_h;
    assign shared_row_lt_h[0] = gy_lt_hi || (gy_eq_hi && h_rem_nz);
    assign shared_row_lt_h[1] = gy_lt_hi || (gy_eq_hi && h_eff[1]);
    assign shared_row_lt_h[2] = gy_lt_hi || (gy_eq_hi && (h_eff[1:0] == 2'd3));
    assign shared_row_lt_h[3] = gy_lt_hi;

    assign busy_o                = 1'b0;
    assign done_o                = 1'b0;
    assign current_pass_o        = '0;
    assign cycle_in_pass_o       = '0;
    assign preload_phase_o       = 1'b0;
    assign lut_phase_o           = 1'b0;
    assign drain_phase_o         = 1'b0;
    assign drain_step_o          = '0;
    assign dma_channel_to_load_o = -12'sd1;
    assign dma_bank_ptr_o        = '0;

    assign array_en_o            = (state == SEQ_COMPUTE);
    assign psum_systolic_en_o    = (state == SEQ_COMPUTE);
    assign psum_skew_en_o        = (state == SEQ_COMPUTE) || (state == SEQ_DRAIN);
    assign compute_bank_swap_o   = (state == SEQ_COMPUTE) ? swap_val : 1'b0;

    assign act_sram_we_o         = (state == SEQ_DRAIN) ? drain_act_we    : dma_we;
    assign act_sram_addr_o       = (state == SEQ_DRAIN) ? drain_act_addr  : comp_act_addr;
    assign act_sram_wdata_o      = (state == SEQ_DRAIN) ? drain_act_wdata : dma_wdata;

    // 1. AXI4-Lite Control & Status Register File
    npu_flex_axil_csr #(
        .AXI_ADDR_WIDTH(AXIL_ADDR_WIDTH),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .DEFAULT_H     (DEFAULT_H),
        .DEFAULT_W     (DEFAULT_W),
        .DEFAULT_CIN   (CIN)
    ) csr_inst (
        .clk_i              (clk_i),
        .rst_n              (rst_n),
        .s_axil_awaddr      (s_axil_awaddr),
        .s_axil_awprot      (s_axil_awprot),
        .s_axil_awvalid     (s_axil_awvalid),
        .s_axil_awready     (s_axil_awready),
        .s_axil_wdata       (s_axil_wdata),
        .s_axil_wstrb       (s_axil_wstrb),
        .s_axil_wvalid      (s_axil_wvalid),
        .s_axil_wready      (s_axil_wready),
        .s_axil_bresp       (s_axil_bresp),
        .s_axil_bvalid      (s_axil_bvalid),
        .s_axil_bready      (s_axil_bready),
        .s_axil_araddr      (s_axil_araddr),
        .s_axil_arprot      (s_axil_arprot),
        .s_axil_arvalid     (s_axil_arvalid),
        .s_axil_arready     (s_axil_arready),
        .s_axil_rdata       (s_axil_rdata),
        .s_axil_rresp       (s_axil_rresp),
        .s_axil_rvalid      (s_axil_rvalid),
        .s_axil_rready      (s_axil_rready),
        .start_pulse_o      (start_pulse),
        .start_drain_pulse_o(start_drain_pulse),
        .soft_reset_o       (soft_reset),
        .auto_drain_o       (auto_drain),
        .mode_1x1_o         (mode_1x1),
        .lut_en_o           (lut_en),
        .pool_en_o          (pool_en),
        .pool_s1_en_o       (pool_s1_en),
        .total_passes_o     (csr_total_passes),
        .tile_x_o           (tile_x),
        .tile_y_o           (tile_y),
        .img_w_o            (img_w),
        .img_h_o            (img_h),
        .cfg_cin_o          (cfg_cin),
        .act_base_o         (act_base),
        .weight_base_o      (weight_base),
        .out_base_o         (out_base),
        .bias_base_o        (bias_base),
        .quant_base_o       (quant_base),
        .lut_base_o         (lut_base),
        .usr_irq_o          (usr_irq_o),
        .fsm_busy_i         (fsm_busy),
        .fsm_done_i         (fsm_done)
    );

    // 2. Central FSM & Progression Counters
    npu_flex_fsm #(
        .ARRAY_HEIGHT(ARRAY_HEIGHT),
        .ARRAY_WIDTH (ARRAY_WIDTH)
    ) fsm_inst (
        .clk_i              (clk_i),
        .rst_n              (sys_rst_n),
        .start_i            (start_pulse),
        .start_drain_i      (start_drain_pulse),
        .auto_drain_i       (auto_drain),
        .lut_en_i           (lut_en),
        .pool_s1_en_i       (pool_s1_en),
        .total_passes_i     (total_passes),
        .dma_pass_ready_i   (dma_pass_ready),
        .lut_we_i           (lut_we),
        .writer_done_i      (writer_done),
        .state_o            (state),
        .busy_o             (fsm_busy),
        .done_o             (fsm_done),
        .pass_cnt_o         (pass_cnt),
        .k_cnt_o            (k_cnt),
        .preload_phase_o    (),
        .lut_phase_o        (),
        .drain_phase_o      (),
        .drain_cnt_o        (drain_cnt),
        .preload_done_o     (preload_done),
        .pass_advance_o     (pass_advance),
        .enter_lut_load_o   (enter_lut_load),
        .first_pass_o       (first_pass),
        .prev_pass_drained_o(prev_pass_drained),
        .swap_weights_o     (swap_weights_o)
    );

    // 3. AXI4 Read Engine & 8-Bank Staging Controller
    npu_flex_axi_reader #(
        .ARRAY_HEIGHT    (ARRAY_HEIGHT),
        .ARRAY_WIDTH     (ARRAY_WIDTH),
        .ACTIVATION_WIDTH(ACTIVATION_WIDTH),
        .WEIGHT_WIDTH    (WEIGHT_WIDTH),
        .PSUM_WIDTH      (PSUM_WIDTH),
        .AXI_ADDR_WIDTH  (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH  (AXI_DATA_WIDTH),
        .FIFO_DEPTH      (FIFO_DEPTH)
    ) axi_reader_inst (
        .clk_i                  (clk_i),
        .rst_n                  (sys_rst_n),
        .start_i                (start_pulse),
        .start_drain_i          (start_drain_pulse),
        .mode_1x1_i             (mode_1x1),
        .lut_en_i               (lut_en),
        .state_i                (state),
        .pass_cnt_i             (pass_cnt),
        .k_cnt_i                (k_cnt),
        .total_passes_i         (total_passes),
        .preload_done_i         (preload_done),
        .pass_advance_i         (pass_advance),
        .enter_lut_load_i       (enter_lut_load),
        .drain_cnt_i            (drain_cnt),
        .tap_0_i                (tap_0),
        .bank_read_used_i       (bank_read_used),
        .dma_pass_ready_o       (dma_pass_ready),
        .act_base_i             (act_base),
        .weight_base_i          (weight_base),
        .bias_base_i            (bias_base),
        .quant_base_i           (quant_base),
        .lut_base_i             (lut_base),
        .tile_y_i               (tile_y),
        .tile_x_i               (tile_x),
        .cfg_cin_i              (cfg_cin),
        .shared_end_x_i         (shared_end_x),
        .shared_beats_m1_i      (shared_beats_m1),
        .shared_beats_zero_i    (shared_beats_zero),
        .shared_ch_plus_shifted_i(shared_ch_plus_shifted),
        .shared_row_lt_h_i      (shared_row_lt_h),
        .rd_cur_strip_y_o       (rd_cur_strip_y),
        .rd_use_strip_y_o       (rd_use_strip_y),
        .rd_ch_init_o           (rd_ch_init),
        .rd_ch_adv_o            (rd_ch_adv),
        .m_axi_araddr           (m_axi_araddr),
        .m_axi_arlen            (m_axi_arlen),
        .m_axi_arvalid          (m_axi_arvalid),
        .m_axi_arready          (m_axi_arready),
        .m_axi_rdata            (m_axi_rdata),
        .m_axi_rresp            (m_axi_rresp),
        .m_axi_rlast            (m_axi_rlast),
        .m_axi_rvalid           (m_axi_rvalid),
        .m_axi_rready           (m_axi_rready),
        .dma_act_we_o           (dma_we),
        .dma_act_addr_o         (dma_addr),
        .dma_act_wdata_o        (dma_wdata),
        .weight_shift_in_o      (weight_shift_in_o),
        .weight_shift_en_o      (weight_shift_en_o),
        .quant_shift_in_o       (quant_shift_in_o),
        .quant_shift_en_o       (quant_shift_en_o),
        .bias_wdata_o           (bias_wdata),
        .bias_we_o              (bias_we),
        .lut_wdata_o            (lut_wdata),
        .lut_we_o               (lut_we)
    );

    // 4. PSUM Ping-Pong Accumulation & Drain Scheduler
    npu_flex_psum #(
        .ARRAY_WIDTH(ARRAY_WIDTH),
        .PSUM_WIDTH (PSUM_WIDTH)
    ) psum_inst (
        .state_i            (state),
        .pass_cnt_i         (pass_cnt),
        .k_cnt_i            (k_cnt),
        .drain_cnt_i        (drain_cnt),
        .total_passes_i     (total_passes),
        .lut_en_i           (lut_en),
        .pool_en_i          (pool_en),
        .pool_s1_en_i       (pool_s1_en),
        .shared_end_x_i     (shared_end_x),
        .shared_row_lt_h_i  (shared_row_lt_h),
        .s1_ty_hi_o         (s1_ty_hi),
        .first_pass_i       (first_pass),
        .prev_pass_drained_i(prev_pass_drained),
        .bias_wdata_i       (bias_wdata),
        .bias_we_i          (bias_we),
        .lut_wdata_i        (lut_wdata),
        .lut_we_i           (lut_we),
        .swap_val_o         (swap_val),
        .psum_lut_en_o      (psum_lut_en_o),
        .psum_A_addr_o      (psum_A_addr_o),
        .psum_A_we_o        (psum_A_we_o),
        .psum_A_wdata_o     (psum_A_wdata_o),
        .psum_B_addr_o      (psum_B_addr_o),
        .psum_B_we_o        (psum_B_we_o),
        .psum_B_wdata_o     (psum_B_wdata_o)
    );

    // 5. Direct-Bank 8-SRAM (4x2) 3x3 & 1x1 Address Generator & Crossbar Driver
    npu_flex_addr #(
        .ARRAY_HEIGHT(ARRAY_HEIGHT)
    ) addr_inst (
        .clk_i           (clk_i),
        .rst_n           (sys_rst_n),
        .mode_1x1_i      (mode_1x1),
        .state_i         (state),
        .pass_cnt_i      (pass_cnt),
        .k_cnt_i         (k_cnt),
        .cfg_cin_i       (cfg_cin),
        .preload_done_i  (preload_done),
        .pass_advance_i  (pass_advance),
        .dma_addr_i      (dma_addr),
        .bank_read_used_o(bank_read_used),
        .tap_0_o         (tap_0),
        .crossbar_sel_o  (crossbar_sel_o),
        .act_sram_addr_o (comp_act_addr)
    );

    // 6. Skewed Drain, Optional 2x2 MaxPool & AXI4 Burst Write Engine
    npu_flex_axi_writer #(
        .ARRAY_HEIGHT    (ARRAY_HEIGHT),
        .ARRAY_WIDTH     (ARRAY_WIDTH),
        .ACTIVATION_WIDTH(ACTIVATION_WIDTH),
        .AXI_ADDR_WIDTH  (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH  (AXI_DATA_WIDTH)
    ) axi_writer_inst (
        .clk_i                   (clk_i),
        .rst_n                   (sys_rst_n),
        .state_i                 (state),
        .drain_cnt_i             (drain_cnt),
        .lut_en_i                (lut_en),
        .pool_en_i               (pool_en),
        .pool_s1_en_i            (pool_s1_en),
        .out_base_i              (out_base),
        .tile_y_i                (tile_y),
        .s1_ty_hi_i              (s1_ty_hi),
        .shared_beats_m1_i       (shared_beats_m1),
        .shared_beats_zero_i     (shared_beats_zero),
        .shared_ch_plus_shifted_i(shared_ch_plus_shifted),
        .shared_row_lt_h_i       (shared_row_lt_h),
        .wb_cur_strip_y_o        (wb_cur_strip_y),
        .wb_use_strip_y_o        (wb_use_strip_y),
        .wb_ch_init_o            (wb_ch_init),
        .wb_ch_adv_o             (wb_ch_adv),
        .writer_done_o           (writer_done),
        .out_act_i               (out_act_i),
        .act_sram_rdata_i        (act_sram_rdata_i),
        .drain_act_we_o          (drain_act_we),
        .drain_act_addr_o        (drain_act_addr),
        .drain_act_wdata_o       (drain_act_wdata),
        .m_axi_awaddr            (m_axi_awaddr),
        .m_axi_awlen             (m_axi_awlen),
        .m_axi_awvalid           (m_axi_awvalid),
        .m_axi_awready           (m_axi_awready),
        .m_axi_wdata             (m_axi_wdata),
        .m_axi_wstrb             (m_axi_wstrb),
        .m_axi_wlast             (m_axi_wlast),
        .m_axi_wvalid            (m_axi_wvalid),
        .m_axi_wready            (m_axi_wready),
        .m_axi_bresp             (m_axi_bresp),
        .m_axi_bvalid            (m_axi_bvalid),
        .m_axi_bready            (m_axi_bready)
    );

endmodule
