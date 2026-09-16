// =============================================================================
// File: SOFT_LOGIC/full/npu_full_sequencer.sv
// Module: npu_full_sequencer
// Project: CrocoScale SoC — Full Dual-Mode eFPGA Soft Sequencer
//
// Description:
//   Top-level hierarchical sequencer instantiating fine-grained submodules for:
//   - Central FSM & counters (npu_seq_fsm)
//   - Weight pre-shift and swap pulses (npu_seq_weight_swap)
//   - PSUM ping-pong accumulation, LUT enable, and drain (npu_seq_psum_sched)
//   - 3x3 im2col address generation (npu_seq_addr_3x3)
//   - 1x1 half-array ping-pong address generation (npu_seq_addr_1x1)
//   - Memory & crossbar mode multiplexing (npu_seq_arbiter)
// =============================================================================

`timescale 1ns / 1ps

module npu_full_sequencer #(
    parameter int ARRAY_HEIGHT = 8,
    parameter int ARRAY_WIDTH  = 8,
    parameter int TILE_SIZE    = 16,
    parameter int ACT_HALO_PAD = 1,
    parameter int CIN          = 128,
    parameter int COUT         = 32
) (
    input  wire                                  clk_i,
    input  wire                                  rst_n,
    input  wire                                  start_i,
    input  wire                                  mode_1x1_i,
    input  wire                                  lut_en_i,
    input  wire                                  lut_load_done_i,
    input  wire                                  drain_done_i,
    input  wire [7:0]                            total_passes_i,

    output logic                                 busy_o,
    output logic                                 done_o,

    output logic [7:0]                           current_pass_o,
    output logic [8:0]                           cycle_in_pass_o,

    // Array mode controls
    output logic                                 array_en_o,
    output logic                                 psum_systolic_en_o,
    output logic                                 psum_lut_en_o,
    output logic                                 psum_skew_en_o,
    output logic                                 compute_bank_swap_o,

    // Crossbar selection per systolic row
    output logic [ARRAY_HEIGHT-1:0][3:0]         crossbar_sel_o,

    // Activation SRAM memory interfaces (8 banks)
    output logic [ARRAY_HEIGHT-1:0][8:0]         act_sram_addr_o,
    output logic [ARRAY_HEIGHT-1:0]              act_sram_we_o,

    // Systolic weight pre-shift & swap timing
    output logic [1:0]                           weight_shift_en_o,
    output logic                                 swap_weights_o,
    output logic [2:0]                           weight_shift_step_o,

    // PSUM Bank A/B memory interfaces
    output logic [7:0]                           psum_A_addr_o,
    output logic [ARRAY_WIDTH-1:0]               psum_A_we_o,
    output logic [7:0]                           psum_B_addr_o,
    output logic [ARRAY_WIDTH-1:0]               psum_B_we_o,

    // Preload & background DMA synchronization
    output logic                                 preload_phase_o,
    output logic [7:0]                           preload_step_o,
    output logic signed [7:0]                    dma_channel_to_load_o,
    output logic [5:0][5:0]                      dma_bank_ptr_o,

    // Activation LUT preloading synchronization
    output logic                                 start_lut_load_o,
    output logic                                 lut_phase_o,

    // Drain synchronization
    output logic                                 drain_phase_o,
    output logic [8:0]                           drain_step_o
);

    localparam logic [2:0] SEQ_COMPUTE = 3'd2;

    // Internal inter-module signals
    wire [2:0]  state;
    wire [7:0]  pass_cnt;
    wire [8:0]  k_cnt;
    wire [8:0]  pass_len;
    wire        preload_phase;
    wire [7:0]  preload_cnt;
    wire        drain_phase;
    wire [8:0]  drain_cnt;
    wire        swap_val;

    wire [ARRAY_HEIGHT-1:0][3:0] crossbar_sel_3x3;
    wire [5:0]                   act_sram_we_3x3;
    wire [5:0][8:0]              act_sram_addr_3x3;
    wire [6:0]                   dma_ch_3x3;

    wire [ARRAY_HEIGHT-1:0][3:0] crossbar_sel_1x1;
    wire [7:0]                   act_sram_we_1x1;
    wire [7:0][8:0]              act_sram_addr_1x1;

    assign current_pass_o        = pass_cnt;
    assign cycle_in_pass_o       = k_cnt;
    assign preload_phase_o       = preload_phase;
    assign preload_step_o        = preload_cnt;
    assign drain_phase_o         = drain_phase;
    assign drain_step_o          = drain_cnt;
    assign dma_channel_to_load_o = mode_1x1_i ? -8'sd1 : ((state == SEQ_COMPUTE) ? 8'(dma_ch_3x3) : -8'sd1);

    assign array_en_o            = (state == SEQ_COMPUTE);
    assign psum_systolic_en_o    = (state == SEQ_COMPUTE);
    assign psum_skew_en_o        = (state == SEQ_COMPUTE);
    assign compute_bank_swap_o   = (state == SEQ_COMPUTE) ? swap_val : 1'b0;

    // 1. Central FSM & Progression Counters
    npu_seq_fsm #(
        .ARRAY_HEIGHT(ARRAY_HEIGHT),
        .ARRAY_WIDTH (ARRAY_WIDTH)
    ) fsm_inst (
        .clk_i           (clk_i),
        .rst_n           (rst_n),
        .start_i         (start_i),
        .mode_1x1_i      (mode_1x1_i),
        .lut_en_i        (lut_en_i),
        .lut_load_done_i (lut_load_done_i),
        .drain_done_i    (drain_done_i),
        .total_passes_i  (total_passes_i),
        .state_o         (state),
        .busy_o          (busy_o),
        .done_o          (done_o),
        .pass_cnt_o      (pass_cnt),
        .k_cnt_o         (k_cnt),
        .pass_len_o      (pass_len),
        .preload_phase_o (preload_phase),
        .preload_cnt_o   (preload_cnt),
        .start_lut_load_o(start_lut_load_o),
        .lut_phase_o     (lut_phase_o),
        .drain_phase_o   (drain_phase),
        .drain_cnt_o     (drain_cnt)
    );

    // 2. Weight Pre-Shift & Swap Engine
    npu_seq_weight_swap weight_swap_inst (
        .preload_phase_i    (preload_phase),
        .preload_cnt_i      (preload_cnt),
        .state_i            (state),
        .pass_cnt_i         (pass_cnt),
        .k_cnt_i            (k_cnt),
        .pass_len_i         (pass_len),
        .total_passes_i     (total_passes_i),
        .weight_shift_en_o  (weight_shift_en_o),
        .swap_weights_o     (swap_weights_o),
        .weight_shift_step_o(weight_shift_step_o)
    );

    // 3. PSUM Ping-Pong Accumulation & Drain Scheduler
    npu_seq_psum_sched #(
        .ARRAY_WIDTH(ARRAY_WIDTH)
    ) psum_sched_inst (
        .state_i        (state),
        .preload_phase_i(preload_phase),
        .preload_cnt_i  (preload_cnt),
        .pass_cnt_i     (pass_cnt),
        .k_cnt_i        (k_cnt),
        .drain_phase_i  (drain_phase),
        .drain_cnt_i    (drain_cnt),
        .total_passes_i (total_passes_i),
        .lut_en_i       (lut_en_i),
        .swap_val_o     (swap_val),
        .psum_lut_en_o  (psum_lut_en_o),
        .psum_A_addr_o  (psum_A_addr_o),
        .psum_A_we_o    (psum_A_we_o),
        .psum_B_addr_o  (psum_B_addr_o),
        .psum_B_we_o    (psum_B_we_o)
    );

    // 4. 3x3 im2col Address Generator
    npu_seq_addr_3x3 #(
        .ARRAY_HEIGHT(ARRAY_HEIGHT),
        .CIN         (CIN)
    ) addr_3x3_inst (
        .clk_i                (clk_i),
        .rst_n                (rst_n),
        .state_i              (state),
        .preload_phase_i      (preload_phase),
        .preload_cnt_i        (preload_cnt),
        .pass_cnt_i           (pass_cnt),
        .k_cnt_i              (k_cnt),
        .pass_len_i           (pass_len),
        .total_passes_i       (total_passes_i),
        .crossbar_sel_o       (crossbar_sel_3x3),
        .act_sram_we_o        (act_sram_we_3x3),
        .act_sram_addr_o      (act_sram_addr_3x3),
        .dma_channel_to_load_o(dma_ch_3x3),
        .dma_bank_ptr_o       (dma_bank_ptr_o)
    );

    // 5. 1x1 Half-Array Double-Buffered Address Generator
    npu_seq_addr_1x1 #(
        .ARRAY_HEIGHT(ARRAY_HEIGHT)
    ) addr_1x1_inst (
        .state_i        (state),
        .preload_phase_i(preload_phase),
        .preload_cnt_i  (preload_cnt),
        .pass_cnt_i     (pass_cnt),
        .k_cnt_i        (k_cnt),
        .total_passes_i (total_passes_i),
        .crossbar_sel_o (crossbar_sel_1x1),
        .act_sram_we_o  (act_sram_we_1x1),
        .act_sram_addr_o(act_sram_addr_1x1)
    );

    // 6. Memory & Crossbar Mode Arbiter
    npu_seq_arbiter #(
        .ARRAY_HEIGHT(ARRAY_HEIGHT)
    ) arbiter_inst (
        .mode_1x1_i         (mode_1x1_i),
        .crossbar_sel_3x3_i (crossbar_sel_3x3),
        .act_sram_we_3x3_i  (act_sram_we_3x3),
        .act_sram_addr_3x3_i(act_sram_addr_3x3),
        .crossbar_sel_1x1_i (crossbar_sel_1x1),
        .act_sram_we_1x1_i  (act_sram_we_1x1),
        .act_sram_addr_1x1_i(act_sram_addr_1x1),
        .crossbar_sel_o     (crossbar_sel_o),
        .act_sram_we_o      (act_sram_we_o),
        .act_sram_addr_o    (act_sram_addr_o)
    );

endmodule
