`timescale 1ns / 1ps

/* ===============================================================================================
 * npu_soft_sequencer.sv
 *
 * eFPGA NPU Soft-Logic Controller - Central Orchestration FSM & Address Generator
 *
 * Manages the entire lifecycle of a 3x3 halo convolution tile (18x18x8 -> 16x16x8):
 * 1. Quantization parameter shift-in (8 cycles)
 * 2. Bias preloading via DMA into PSUM Bank A/B Address 0 (8 cycles)
 * 3. Activation tensor loading into on-chip SRAM via DMA (648 words)
 * 4. 9-pass kernel iteration (ky in [0..2], kx in [0..2]):
 *    - Weight fetch & shift into PE shadow chain
 *    - Systolic array computation (273 cycles)
 *    - Ping-pong PSUM accumulation with Pass 0 reading bias from Address 0
 * 5. Multi-channel output drain to AXI RAM via DMA
 * =============================================================================================== */

module npu_minimal_sequencer #(
    parameter int ARRAY_HEIGHT     = 8,
    parameter int ARRAY_WIDTH      = 8,
    parameter int TILE_SIZE        = 16,
    parameter int ACT_HALO_PAD     = 2,
    parameter int ACTIVATION_WIDTH = 8,
    parameter int WEIGHT_WIDTH     = 8,
    parameter int PSUM_WIDTH       = 32,
    parameter int SCALE_WIDTH      = 16,
    parameter int WEIGHT_SPLIT     = 2,

    localparam int PSUM_WORDS      = TILE_SIZE * TILE_SIZE, // 256
    localparam int ACT_WORDS       = (TILE_SIZE * TILE_SIZE) * ACT_HALO_PAD, // 512
    localparam int PSUM_ADDR_WIDTH = $clog2(PSUM_WORDS), // 8
    localparam int ACT_ADDR_WIDTH  = $clog2(ACT_WORDS),  // 9
    localparam int NUM_ACT_BANKS   = ARRAY_HEIGHT,       // 8
    localparam int XBAR_SEL_WIDTH  = 4,
    localparam int QUANT_CFG_WIDTH = 30
)(
    input  wire                                                          clk_i,
    input  wire                                                          rst_n,

    // Control and Configuration from CSR
    input  wire                                                          start_pulse_i,
    input  wire                                                          soft_reset_i,
    input  wire        [31:0]                                            reg_quant_param_i,
    input  wire        [31:0]                                            reg_config_i,
    output logic                                                         busy_o,
    output logic                                                         done_pulse_o,

    // DMA Coordination Interface
    output logic                                                         start_bias_o,
    input  wire                                                          bias_done_i,

    output logic                                                         start_act_o,
    input  wire                                                          act_done_i,

    output logic                                                         start_weight_o,
    output logic       [3:0]                                             weight_pass_idx_o,
    input  wire                                                          weight_done_i,

    output logic                                                         start_drain_o,
    input  wire                                                          drain_done_i,

    // NPU Complex Dedicated Control
    output logic                                                         npu_array_en_o,
    output logic                                                         npu_psum_systolic_en_o,
    output logic                                                         npu_psum_lut_en_o,
    output logic                                                         npu_psum_skew_en_o,
    output logic                                                         npu_compute_bank_swap_o,
    output logic       [ARRAY_HEIGHT-1:0][XBAR_SEL_WIDTH-1:0]            npu_crossbar_sel_o,
    output logic                                                         npu_swap_weights_o,

    output logic       [QUANT_CFG_WIDTH-1:0]                             npu_quant_shift_in_o,
    output logic                                                         npu_quant_shift_en_o,
    output logic                                                         npu_stochastic_round_en_o,

    // PSUM A and B Sequencing Ports
    output logic       [PSUM_ADDR_WIDTH-1:0]                             seq_psum_A_addr_o,
    output logic       [ARRAY_WIDTH-1:0]                                 seq_psum_A_we_o,
    output logic signed [PSUM_WIDTH-1:0]                                 seq_psum_A_wdata_o,

    output logic       [PSUM_ADDR_WIDTH-1:0]                             seq_psum_B_addr_o,
    output logic       [ARRAY_WIDTH-1:0]                                 seq_psum_B_we_o,
    output logic signed [PSUM_WIDTH-1:0]                                 seq_psum_B_wdata_o,

    // Activation SRAM Read Addressing during Systolic Stepping
    output logic       [NUM_ACT_BANKS-1:0][ACT_ADDR_WIDTH-1:0]           seq_act_sram_addr_o,

    // Diagnostic / Monitoring Outputs for Testbench
    output logic       [3:0]                                             state_code_o,
    output logic       [3:0]                                             pass_idx_o,
    output logic       [1:0]                                             ky_o,
    output logic       [1:0]                                             kx_o,
    output logic       [8:0]                                             comp_k_o
);

    typedef enum logic [3:0] {
        SEQ_IDLE          = 4'd0,
        SEQ_LOAD_QUANT    = 4'd1,
        SEQ_DMA_BIAS      = 4'd2,
        SEQ_DMA_ACT       = 4'd3,
        SEQ_DMA_WEIGHT    = 4'd4,
        SEQ_SWAP_PAUSE    = 4'd5,
        SEQ_COMPUTE       = 4'd6,
        SEQ_DMA_DRAIN     = 4'd7
    } seq_state_t;

    seq_state_t state;

    // Sub-counters and iteration trackers
    logic [3:0] quant_step;
    logic [3:0] pass_idx;
    logic [8:0] comp_k;

    // Current 3x3 kernel spatial coordinates
    wire [1:0] ky = (pass_idx == 4'd0 || pass_idx == 4'd1 || pass_idx == 4'd2) ? 2'd0 :
                    (pass_idx == 4'd3 || pass_idx == 4'd4 || pass_idx == 4'd5) ? 2'd1 : 2'd2;

    wire [1:0] kx = (pass_idx == 4'd0 || pass_idx == 4'd3 || pass_idx == 4'd6) ? 2'd0 :
                    (pass_idx == 4'd1 || pass_idx == 4'd4 || pass_idx == 4'd7) ? 2'd1 : 2'd2;

    // Ping-pong bank assignment: odd number of total passes (9 passes)
    // Pass 0 -> swap_val=1 (reads B Addr 0 for preloaded bias, accumulates & stores into A)
    // Pass 1 -> swap_val=0 (reads A, stores into B)
    // Final Pass 8 -> swap_val=1 (reads B, final result rests in Bank A)
    wire swap_val  = (pass_idx[0] == 1'b0);
    wire hold_zero = (pass_idx == 4'd0);

    // Monitoring wires
    assign pass_idx_o = pass_idx;
    assign ky_o       = ky;
    assign kx_o       = kx;
    assign comp_k_o   = comp_k;
    assign weight_pass_idx_o = pass_idx;

    // Friendly state code mapping for testbench display
    always_comb begin
        case (state)
            SEQ_IDLE:          state_code_o = 4'd0;
            SEQ_LOAD_QUANT:    state_code_o = 4'd2;
            SEQ_DMA_BIAS:      state_code_o = 4'd3;
            SEQ_DMA_ACT:       state_code_o = 4'd4;
            SEQ_DMA_WEIGHT:    state_code_o = 4'd6;
            SEQ_SWAP_PAUSE:    state_code_o = 4'd7;
            SEQ_COMPUTE:       state_code_o = 4'd8;
            SEQ_DMA_DRAIN:     state_code_o = 4'd10;
            default:           state_code_o = 4'd0;
        endcase
    end

    // Default Crossbar Routing: Identity mapping (Bank r -> Row r)
    generate
        genvar gr;
        for (gr = 0; gr < ARRAY_HEIGHT; gr++) begin : gen_xbar_id
            assign npu_crossbar_sel_o[gr] = 4'(gr);
        end
    endgenerate

    always_ff @(posedge clk_i or negedge rst_n) begin
        if (!rst_n) begin
            state                   <= SEQ_IDLE;
            busy_o                  <= 1'b0;
            done_pulse_o            <= 1'b0;
            start_bias_o            <= 1'b0;
            start_act_o             <= 1'b0;
            start_weight_o          <= 1'b0;
            start_drain_o           <= 1'b0;
            quant_step              <= '0;
            pass_idx                <= '0;
            comp_k                  <= '0;

            npu_array_en_o          <= 1'b0;
            npu_psum_systolic_en_o  <= 1'b0;
            npu_psum_lut_en_o       <= 1'b0;
            npu_psum_skew_en_o      <= 1'b0;
            npu_compute_bank_swap_o <= 1'b0;
            npu_swap_weights_o      <= 1'b0;
            npu_quant_shift_in_o    <= '0;
            npu_quant_shift_en_o    <= 1'b0;
            npu_stochastic_round_en_o <= 1'b0;

            seq_psum_A_addr_o       <= '0;
            seq_psum_A_we_o         <= '0;
            seq_psum_A_wdata_o      <= '0;
            seq_psum_B_addr_o       <= '0;
            seq_psum_B_we_o         <= '0;
            seq_psum_B_wdata_o      <= '0;
            seq_act_sram_addr_o     <= '0;
        end else if (soft_reset_i) begin
            state                   <= SEQ_IDLE;
            busy_o                  <= 1'b0;
            done_pulse_o            <= 1'b0;
            start_bias_o            <= 1'b0;
            start_act_o             <= 1'b0;
            start_weight_o          <= 1'b0;
            start_drain_o           <= 1'b0;
            quant_step              <= '0;
            pass_idx                <= '0;
            comp_k                  <= '0;

            npu_array_en_o          <= 1'b0;
            npu_psum_systolic_en_o  <= 1'b0;
            npu_psum_lut_en_o       <= 1'b0;
            npu_psum_skew_en_o      <= 1'b0;
            npu_compute_bank_swap_o <= 1'b0;
            npu_swap_weights_o      <= 1'b0;
            npu_quant_shift_in_o    <= '0;
            npu_quant_shift_en_o    <= 1'b0;
            npu_stochastic_round_en_o <= 1'b0;

            seq_psum_A_addr_o       <= '0;
            seq_psum_A_we_o         <= '0;
            seq_psum_A_wdata_o      <= '0;
            seq_psum_B_addr_o       <= '0;
            seq_psum_B_we_o         <= '0;
            seq_psum_B_wdata_o      <= '0;
            seq_act_sram_addr_o     <= '0;
        end else begin
            // Single-cycle pulse clears
            done_pulse_o       <= 1'b0;
            start_bias_o       <= 1'b0;
            start_act_o        <= 1'b0;
            start_weight_o     <= 1'b0;
            start_drain_o      <= 1'b0;
            npu_swap_weights_o <= 1'b0;

            case (state)
                SEQ_IDLE: begin
                    busy_o                 <= 1'b0;
                    npu_array_en_o         <= 1'b0;
                    npu_psum_systolic_en_o <= 1'b0;
                    npu_psum_skew_en_o     <= 1'b0;
                    seq_psum_A_we_o        <= '0;
                    seq_psum_B_we_o        <= '0;

                    if (start_pulse_i) begin
                        busy_o     <= 1'b1;
                        quant_step <= '0;
                        state      <= SEQ_LOAD_QUANT;
                    end
                end

                // =============================================================
                // Shift Quantization Parameters into NPU Requantizers
                // =============================================================
                SEQ_LOAD_QUANT: begin
                    if (quant_step < 4'd8) begin
                        npu_quant_shift_en_o <= 1'b1;
                        npu_quant_shift_in_o <= reg_quant_param_i[29:0];
                        quant_step           <= quant_step + 1'b1;
                    end else begin
                        npu_quant_shift_en_o <= 1'b0;
                        start_bias_o         <= 1'b1;
                        state                <= SEQ_DMA_BIAS;
                    end
                end

                // =============================================================
                // Wait for DMA to Preload Channel Biases into Address 0
                // =============================================================
                SEQ_DMA_BIAS: begin
                    if (bias_done_i) begin
                        start_act_o <= 1'b1;
                        state       <= SEQ_DMA_ACT;
                    end
                end

                // =============================================================
                // Wait for Activation DMA to fill SRAM banks
                // =============================================================
                SEQ_DMA_ACT: begin
                    if (act_done_i) begin
                        pass_idx       <= '0;
                        start_weight_o <= 1'b1;
                        state          <= SEQ_DMA_WEIGHT;
                    end
                end

                // =============================================================
                // Wait for Weight DMA to stream weights directly into shadow regs
                // =============================================================
                SEQ_DMA_WEIGHT: begin
                    if (weight_done_i) begin
                        npu_swap_weights_o <= 1'b1;
                        state              <= SEQ_SWAP_PAUSE;
                    end
                end

                // =============================================================
                // Dead Cycle for Shadow Weight Swap Propagation
                // =============================================================
                SEQ_SWAP_PAUSE: begin
                    npu_swap_weights_o <= 1'b0;
                    comp_k             <= '0;
                    state              <= SEQ_COMPUTE;
                end

                // =============================================================
                // Systolic Array Stepping and Accumulation
                // =============================================================
                SEQ_COMPUTE: begin
                    npu_array_en_o          <= 1'b1;
                    npu_psum_systolic_en_o  <= 1'b1;
                    npu_psum_lut_en_o       <= 1'b0;
                    npu_psum_skew_en_o      <= 1'b1;
                    npu_compute_bank_swap_o <= swap_val;

                    // Activation SRAM Address Skew Generation
                    for (int r = 0; r < ARRAY_HEIGHT; r++) begin
                        if ((comp_k >= r) && ((comp_k - r) < 256)) begin
                            seq_act_sram_addr_o[r] <= (ACT_ADDR_WIDTH)'(((((comp_k - r) >> 4) + ky) * 18) + (((comp_k - r) & 9'd15) + kx));
                        end else begin
                            seq_act_sram_addr_o[r] <= '0;
                        end
                    end

                    // Ping-Pong PSUM SRAM Address Generation & Write Enables
                    if (!swap_val) begin
                        // Pass 1, 3, 5, 7: Read Bank A, Write Bank B
                        seq_psum_A_addr_o <= (hold_zero) ? 8'd0 : ((comp_k < 256) ? (PSUM_ADDR_WIDTH)'(comp_k) : 8'd0);
                        seq_psum_B_addr_o <= (comp_k >= 9 && (comp_k - 9) < 256) ? (PSUM_ADDR_WIDTH)'(comp_k - 9) : 8'd0;
                        seq_psum_A_we_o   <= 8'h00;
                        for (int c = 0; c < ARRAY_WIDTH; c++) begin
                            seq_psum_B_we_o[c] <= (comp_k >= (9 + c) && (comp_k - (9 + c)) < 256);
                        end
                    end else begin
                        // Pass 0, 2, 4, 6, 8: Read Bank B, Write Bank A
                        seq_psum_B_addr_o <= (hold_zero) ? 8'd0 : ((comp_k < 256) ? (PSUM_ADDR_WIDTH)'(comp_k) : 8'd0);
                        seq_psum_A_addr_o <= (comp_k >= 9 && (comp_k - 9) < 256) ? (PSUM_ADDR_WIDTH)'(comp_k - 9) : 8'd0;
                        seq_psum_B_we_o   <= 8'h00;
                        for (int c = 0; c < ARRAY_WIDTH; c++) begin
                            seq_psum_A_we_o[c] <= (comp_k >= (9 + c) && (comp_k - (9 + c)) < 256);
                        end
                    end

                    // Compute Phase Stepping: 256 + 8 + 8 = 272 steps
                    if (comp_k < 9'd272) begin
                        comp_k <= comp_k + 1'b1;
                    end else begin
                        npu_array_en_o         <= 1'b0;
                        npu_psum_systolic_en_o <= 1'b0;
                        npu_psum_skew_en_o     <= 1'b0;
                        seq_psum_A_we_o        <= 8'h00;
                        seq_psum_B_we_o        <= 8'h00;

                        if (pass_idx < 4'd8) begin
                            pass_idx       <= pass_idx + 1'b1;
                            start_weight_o <= 1'b1;
                            state          <= SEQ_DMA_WEIGHT;
                        end else begin
                            // All 9 kernel passes completed
                            if (reg_config_i[0]) begin // AUTO_DRAIN_OUT
                                start_drain_o <= 1'b1;
                                state         <= SEQ_DMA_DRAIN;
                            end else begin
                                done_pulse_o <= 1'b1;
                                state        <= SEQ_IDLE;
                            end
                        end
                    end
                end

                // =============================================================
                // Wait for Output Drain DMA to write back to AXI RAM
                // =============================================================
                SEQ_DMA_DRAIN: begin
                    if (drain_done_i) begin
                        done_pulse_o <= 1'b1;
                        state        <= SEQ_IDLE;
                    end
                end

                default: state <= SEQ_IDLE;
            endcase
        end
    end

endmodule
