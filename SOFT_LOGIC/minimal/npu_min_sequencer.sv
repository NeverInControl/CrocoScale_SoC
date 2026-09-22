`timescale 1ns / 1ps

/* ===============================================================================================
 * File: SOFT_LOGIC/minimal/npu_min_sequencer.sv
 * Module: npu_min_sequencer
 * Project: CrocoScale SoC -- eFPGA Minimal NPU Sequencer
 *
 * Description:
 *   Central orchestration FSM for the minimal NPU soft controller:
 *   - Quantization parameter shift-in (8 cycles)
 *   - Bias preload coordination (Address 0 of PSUM SRAMs)
 *   - Activation preload coordination
 *   - Weight preload & systolic compute passes:
 *       KERNEL_SIZE == 1: 1 pass (16x16 tile, Cin=8, Cout=8, no halo)
 *       KERNEL_SIZE == 3: 9 passes (18x18 halo tile, Cin=8, Cout=8)
 *   - Ping-pong PSUM accumulation across passes
 *   - Output drain coordination
 *   Uses fully synchronous reset for single-LUT DFF mapping.
 * =============================================================================================== */

module npu_min_sequencer #(
    parameter int KERNEL_SIZE      = 3,
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
    localparam int ACT_WORDS       = (KERNEL_SIZE == 1) ? 256 : (TILE_SIZE * TILE_SIZE) * ACT_HALO_PAD,
    localparam int TOTAL_PASSES    = (KERNEL_SIZE == 1) ? 1 : 9,
    localparam int PSUM_ADDR_WIDTH = $clog2(PSUM_WORDS), // 8
    localparam int ACT_ADDR_WIDTH  = 9,
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

    logic [3:0] quant_step;
    logic [3:0] pass_idx;
    logic [8:0] comp_k;

    // Kernel spatial coordinates (0 for 1x1, calculated for 3x3)
    wire [1:0] ky = (KERNEL_SIZE == 1) ? 2'd0 :
                    (pass_idx == 4'd0 || pass_idx == 4'd1 || pass_idx == 4'd2) ? 2'd0 :
                    (pass_idx == 4'd3 || pass_idx == 4'd4 || pass_idx == 4'd5) ? 2'd1 : 2'd2;

    wire [1:0] kx = (KERNEL_SIZE == 1) ? 2'd0 :
                    (pass_idx == 4'd0 || pass_idx == 4'd3 || pass_idx == 4'd6) ? 2'd0 :
                    (pass_idx == 4'd1 || pass_idx == 4'd4 || pass_idx == 4'd7) ? 2'd1 : 2'd2;

    assign pass_idx_o        = pass_idx;
    assign ky_o              = ky;
    assign kx_o              = kx;
    assign comp_k_o          = comp_k;
    assign weight_pass_idx_o = pass_idx;

    // Friendly state code mapping for testbench display
    always_comb begin
        case (state)
            SEQ_IDLE:       state_code_o = 4'd0;
            SEQ_LOAD_QUANT: state_code_o = 4'd2;
            SEQ_DMA_BIAS:   state_code_o = 4'd3;
            SEQ_DMA_ACT:    state_code_o = 4'd4;
            SEQ_DMA_WEIGHT: state_code_o = 4'd6;
            SEQ_SWAP_PAUSE: state_code_o = 4'd7;
            SEQ_COMPUTE:    state_code_o = 4'd8;
            SEQ_DMA_DRAIN:  state_code_o = 4'd10;
            default:        state_code_o = 4'd0;
        endcase
    end

    // Hardcoded straight-through crossbar
    generate
        for (genvar r = 0; r < ARRAY_HEIGHT; r++) begin : gen_xbar
            assign npu_crossbar_sel_o[r] = (XBAR_SEL_WIDTH)'(r);
        end
    endgenerate

    // Modular Address Generator
    npu_min_addr_gen #(
        .KERNEL_SIZE   (KERNEL_SIZE),
        .ARRAY_HEIGHT  (ARRAY_HEIGHT),
        .ACT_ADDR_WIDTH(ACT_ADDR_WIDTH)
    ) addr_gen_inst (
        .clk_i         (clk_i),
        .rst_n         (rst_n),
        .pass_idx_i    (pass_idx),
        .comp_k_i      (comp_k),
        .act_sram_addr_o(seq_act_sram_addr_o)
    );

    // Ping-pong and accumulation control
    // Pass 0 (or even passes) -> swap_val=1 (reads Bank B Addr 0 for bias, writes Bank A)
    // Pass 1 (or odd passes)  -> swap_val=0 (reads Bank A, writes Bank B)
    // For 1x1: 1 pass total (Pass 0) -> ends in Bank A
    // For 3x3: 9 passes total (Pass 0..8) -> ends in Bank A
    wire swap_val  = (pass_idx[0] == 1'b0);
    wire hold_zero = (pass_idx == 4'd0);

    // Synchronous Reset FSM
    always_ff @(posedge clk_i) begin
        if (!rst_n || soft_reset_i) begin
            state                     <= SEQ_IDLE;
            busy_o                    <= 1'b0;
            done_pulse_o              <= 1'b0;
            start_bias_o              <= 1'b0;
            start_act_o               <= 1'b0;
            start_weight_o            <= 1'b0;
            start_drain_o             <= 1'b0;
            quant_step                <= '0;
            pass_idx                  <= '0;
            comp_k                    <= '0;
            npu_array_en_o            <= 1'b0;
            npu_psum_systolic_en_o    <= 1'b0;
            npu_psum_lut_en_o         <= 1'b0;
            npu_psum_skew_en_o        <= 1'b0;
            npu_compute_bank_swap_o   <= 1'b0;
            npu_swap_weights_o        <= 1'b0;
            npu_quant_shift_in_o      <= '0;
            npu_quant_shift_en_o      <= 1'b0;
            npu_stochastic_round_en_o <= 1'b0;
            seq_psum_A_addr_o         <= '0;
            seq_psum_A_we_o           <= '0;
            seq_psum_A_wdata_o        <= '0;
            seq_psum_B_addr_o         <= '0;
            seq_psum_B_we_o           <= '0;
            seq_psum_B_wdata_o        <= '0;
        end else begin
            // Single-cycle clear of pulse outputs
            done_pulse_o              <= 1'b0;
            start_bias_o              <= 1'b0;
            start_act_o               <= 1'b0;
            start_weight_o            <= 1'b0;
            start_drain_o             <= 1'b0;
            npu_swap_weights_o        <= 1'b0;
            seq_psum_A_we_o           <= '0;
            seq_psum_B_we_o           <= '0;

            case (state)
                SEQ_IDLE: begin
                    busy_o                 <= 1'b0;
                    npu_array_en_o         <= 1'b0;
                    npu_psum_systolic_en_o <= 1'b0;
                    npu_psum_skew_en_o     <= 1'b0;
                    quant_step             <= '0;
                    pass_idx               <= '0;
                    comp_k                 <= '0;

                    if (start_pulse_i) begin
                        busy_o               <= 1'b1;
                        npu_quant_shift_in_o <= reg_quant_param_i[29:0];
                        npu_quant_shift_en_o <= 1'b1;
                        quant_step           <= '0;
                        state                <= SEQ_LOAD_QUANT;
                    end
                end

                // Shift Quantization Configuration (8 cycles)
                SEQ_LOAD_QUANT: begin
                    quant_step <= quant_step + 1'b1;
                    if (quant_step < 4'd7) begin
                        npu_quant_shift_en_o <= 1'b1;
                    end else begin
                        npu_quant_shift_en_o <= 1'b0;
                        start_bias_o         <= 1'b1;
                        state                <= SEQ_DMA_BIAS;
                    end
                end

                // Preload Channel Biases into Address 0
                SEQ_DMA_BIAS: begin
                    if (bias_done_i) begin
                        start_act_o <= 1'b1;
                        state       <= SEQ_DMA_ACT;
                    end
                end

                // Preload Activation Tensor into SRAM
                SEQ_DMA_ACT: begin
                    if (act_done_i) begin
                        pass_idx       <= '0;
                        start_weight_o <= 1'b1;
                        state          <= SEQ_DMA_WEIGHT;
                    end
                end

                // Stream Weights into PE Shadow Registers
                SEQ_DMA_WEIGHT: begin
                    if (weight_done_i) begin
                        npu_swap_weights_o <= 1'b1;
                        state              <= SEQ_SWAP_PAUSE;
                    end
                end

                // Wavefront Swap Dead-Cycle
                SEQ_SWAP_PAUSE: begin
                    npu_swap_weights_o <= 1'b0;
                    comp_k             <= '0;
                    state              <= SEQ_COMPUTE;
                end

                // Systolic Array Stepping and Accumulation
                SEQ_COMPUTE: begin
                    npu_array_en_o          <= 1'b1;
                    npu_psum_systolic_en_o  <= 1'b1;
                    npu_psum_lut_en_o       <= 1'b0;
                    npu_psum_skew_en_o      <= 1'b1;
                    npu_compute_bank_swap_o <= swap_val;

                    // Ping-Pong PSUM SRAM Address Generation & Write Enables
                    if (!swap_val) begin
                        // Odd passes (Pass 1, 3, 5, 7): Read Bank A, Write Bank B
                        seq_psum_A_addr_o <= (hold_zero) ? 8'd0 : ((comp_k < 9'd256) ? (PSUM_ADDR_WIDTH)'(comp_k) : 8'd0);
                        seq_psum_B_addr_o <= (comp_k >= 9'd9 && (comp_k - 9'd9) < 9'd256) ? (PSUM_ADDR_WIDTH)'(comp_k - 9'd9) : 8'd0;
                        seq_psum_A_we_o   <= 8'h00;
                        for (int c = 0; c < ARRAY_WIDTH; c++) begin
                            seq_psum_B_we_o[c] <= (comp_k >= (9'd9 + c) && (comp_k - (9'd9 + c)) < 9'd256);
                        end
                    end else begin
                        // Even passes (Pass 0, 2, 4, 6, 8): Read Bank B, Write Bank A
                        seq_psum_B_addr_o <= (hold_zero) ? 8'd0 : ((comp_k < 9'd256) ? (PSUM_ADDR_WIDTH)'(comp_k) : 8'd0);
                        seq_psum_A_addr_o <= (comp_k >= 9'd9 && (comp_k - 9'd9) < 9'd256) ? (PSUM_ADDR_WIDTH)'(comp_k - 9'd9) : 8'd0;
                        seq_psum_B_we_o   <= 8'h00;
                        for (int c = 0; c < ARRAY_WIDTH; c++) begin
                            seq_psum_A_we_o[c] <= (comp_k >= (9'd9 + c) && (comp_k - (9'd9 + c)) < 9'd256);
                        end
                    end

                    // Step Counter
                    if (comp_k < (9'd255 + 9'd17)) begin
                        comp_k <= comp_k + 1'b1;
                    end else begin
                        npu_array_en_o         <= 1'b0;
                        npu_psum_systolic_en_o <= 1'b0;
                        npu_psum_skew_en_o     <= 1'b0;

                        if (pass_idx + 1'b1 < 4'(TOTAL_PASSES)) begin
                            pass_idx       <= pass_idx + 1'b1;
                            start_weight_o <= 1'b1;
                            state          <= SEQ_DMA_WEIGHT;
                        end else begin
                            if (reg_config_i[0]) begin
                                start_drain_o <= 1'b1;
                                state         <= SEQ_DMA_DRAIN;
                            end else begin
                                done_pulse_o <= 1'b1;
                                busy_o       <= 1'b0;
                                state        <= SEQ_IDLE;
                            end
                        end
                    end
                end

                // Drain Final Results from PSUM SRAM to System RAM
                SEQ_DMA_DRAIN: begin
                    if (drain_done_i) begin
                        done_pulse_o <= 1'b1;
                        busy_o       <= 1'b0;
                        state        <= SEQ_IDLE;
                    end
                end

                default: state <= SEQ_IDLE;
            endcase
        end
    end

endmodule
