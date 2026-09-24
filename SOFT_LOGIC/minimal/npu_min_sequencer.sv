`timescale 1ns / 1ps

/* ===============================================================================================
 * File: SOFT_LOGIC/minimal/npu_min_sequencer.sv
 * Module: npu_min_sequencer
 * Project: CrocoScale SoC -- eFPGA Minimal NPU Sequencer
 *
 * Description:
 *   Central orchestration FSM for the minimal NPU soft controller:
 *   - Shifts quantization parameters (8 cycles)
 *   - Bias preload coordination
 *   - Activation preload coordination
 *   - Weight preload & systolic compute passes (1 pass for 1x1, 9 passes for 3x3)
 *   - Ping-pong PSUM accumulation across passes
 *   - Output drain coordination
 *   Zero non-linear LUT logic. Fully synchronous reset for single-LUT DFF mapping.
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

    localparam int TOTAL_PASSES    = (KERNEL_SIZE == 1) ? 1 : 9,
    localparam int PSUM_ADDR_WIDTH = 8,
    localparam int ACT_ADDR_WIDTH  = 9,
    localparam int NUM_ACT_BANKS   = ARRAY_HEIGHT,
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
    output logic                                                         npu_psum_skew_en_o,
    output logic                                                         npu_compute_bank_swap_o,
    output wire        [ARRAY_HEIGHT-1:0][XBAR_SEL_WIDTH-1:0]            npu_crossbar_sel_o,
    output logic                                                         npu_swap_weights_o,

    output logic       [QUANT_CFG_WIDTH-1:0]                             npu_quant_shift_in_o,
    output logic                                                         npu_quant_shift_en_o,
    output wire                                                          npu_stochastic_round_en_o,

    // PSUM A and B Sequencing Ports
    output logic       [PSUM_ADDR_WIDTH-1:0]                             seq_psum_A_addr_o,
    output logic       [ARRAY_WIDTH-1:0]                                 seq_psum_A_we_o,
    output logic       [PSUM_ADDR_WIDTH-1:0]                             seq_psum_B_addr_o,
    output logic       [ARRAY_WIDTH-1:0]                                 seq_psum_B_we_o,

    // Activation SRAM Read Addressing during Systolic Stepping
    output wire        [NUM_ACT_BANKS-1:0][ACT_ADDR_WIDTH-1:0]           seq_act_sram_addr_o,

    // Diagnostic Outputs
    output logic       [3:0]                                             state_code_o,
    output logic       [3:0]                                             pass_idx_o,
    output wire        [1:0]                                             ky_o,
    output wire        [1:0]                                             kx_o,
    output logic       [8:0]                                             comp_k_o
);

    typedef enum logic [2:0] {
        SEQ_IDLE       = 3'd0,
        SEQ_LOAD_QUANT = 3'd1,
        SEQ_DMA_BIAS   = 3'd2,
        SEQ_DMA_ACT    = 3'd3,
        SEQ_DMA_WEIGHT = 3'd4,
        SEQ_SWAP_PAUSE = 3'd5,
        SEQ_COMPUTE    = 3'd6,
        SEQ_DMA_DRAIN  = 3'd7
    } seq_state_t;

    seq_state_t state;

    logic [2:0] quant_step;
    logic [3:0] pass_idx;
    logic [8:0] comp_k;

    assign pass_idx_o        = pass_idx;
    assign comp_k_o          = comp_k;
    assign weight_pass_idx_o = pass_idx;
    assign npu_stochastic_round_en_o = 1'b0;

    // Kernel spatial offsets (tied off in minimal controller)
    assign ky_o = '0;
    assign kx_o = '0;

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

    // Straight-through crossbar
    generate
        for (genvar r = 0; r < ARRAY_HEIGHT; r++) begin : gen_xbar
            assign npu_crossbar_sel_o[r] = (XBAR_SEL_WIDTH)'(r);
        end
    endgenerate

    // Address Generator
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

    wire swap_val  = (pass_idx[0] == 1'b0);
    wire hold_zero = (pass_idx == 4'd0);

    logic [PSUM_ADDR_WIDTH-1:0] psum_rd_addr;
    logic [PSUM_ADDR_WIDTH-1:0] psum_wr_addr;
    logic [ARRAY_WIDTH-1:0]     psum_wr_we;

    wire col0_active = (state == SEQ_COMPUTE) && (comp_k >= 9'd8 && comp_k < 9'd264);
    assign psum_rd_addr = (hold_zero || comp_k[8]) ? 8'd0 : comp_k[7:0];

    assign seq_psum_A_addr_o = (state == SEQ_COMPUTE) ? (swap_val ? psum_wr_addr : psum_rd_addr) : 8'd0;
    assign seq_psum_B_addr_o = (state == SEQ_COMPUTE) ? (swap_val ? psum_rd_addr : psum_wr_addr) : 8'd0;
    assign seq_psum_A_we_o   = (state == SEQ_COMPUTE && swap_val)  ? psum_wr_we : 8'd0;
    assign seq_psum_B_we_o   = (state == SEQ_COMPUTE && !swap_val) ? psum_wr_we : 8'd0;

    always_ff @(posedge clk_i) begin
        if (!rst_n || soft_reset_i) begin
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
            psum_wr_we              <= '0;
            psum_wr_addr            <= '0;
            npu_array_en_o          <= 1'b0;
            npu_psum_systolic_en_o  <= 1'b0;
            npu_psum_skew_en_o      <= 1'b0;
            npu_compute_bank_swap_o <= 1'b0;
            npu_swap_weights_o      <= 1'b0;
            npu_quant_shift_in_o    <= '0;
            npu_quant_shift_en_o    <= 1'b0;
        end else begin
            done_pulse_o       <= 1'b0;
            start_bias_o       <= 1'b0;
            start_act_o        <= 1'b0;
            start_weight_o     <= 1'b0;
            start_drain_o      <= 1'b0;
            npu_swap_weights_o <= 1'b0;

            if (state == SEQ_COMPUTE) begin
                psum_wr_we <= {psum_wr_we[6:0], col0_active};
                if (psum_wr_we[0]) begin
                    psum_wr_addr <= psum_wr_addr + 1'b1;
                end else begin
                    psum_wr_addr <= '0;
                end
            end else begin
                psum_wr_we   <= '0;
                psum_wr_addr <= '0;
            end

            case (state)
                SEQ_IDLE: begin
                    busy_o                 <= 1'b0;
                    npu_array_en_o         <= 1'b0;
                    npu_psum_systolic_en_o <= 1'b0;
                    npu_psum_skew_en_o     <= 1'b0;

                    if (start_pulse_i) begin
                        busy_o               <= 1'b1;
                        npu_quant_shift_in_o <= reg_quant_param_i[29:0];
                        npu_quant_shift_en_o <= 1'b1;
                        quant_step           <= '0;
                        state                <= SEQ_LOAD_QUANT;
                    end
                end

                SEQ_LOAD_QUANT: begin
                    quant_step <= quant_step + 1'b1;
                    if (quant_step != 3'd7) begin
                        npu_quant_shift_en_o <= 1'b1;
                    end else begin
                        npu_quant_shift_en_o <= 1'b0;
                        start_bias_o         <= 1'b1;
                        state                <= SEQ_DMA_BIAS;
                    end
                end

                SEQ_DMA_BIAS: begin
                    if (bias_done_i) begin
                        start_act_o <= 1'b1;
                        state       <= SEQ_DMA_ACT;
                    end
                end

                SEQ_DMA_ACT: begin
                    if (act_done_i) begin
                        pass_idx       <= '0;
                        start_weight_o <= 1'b1;
                        state          <= SEQ_DMA_WEIGHT;
                    end
                end

                SEQ_DMA_WEIGHT: begin
                    if (weight_done_i) begin
                        npu_swap_weights_o <= 1'b1;
                        state              <= SEQ_SWAP_PAUSE;
                    end
                end

                SEQ_SWAP_PAUSE: begin
                    npu_swap_weights_o <= 1'b0;
                    comp_k             <= '0;
                    state              <= SEQ_COMPUTE;
                end

                SEQ_COMPUTE: begin
                    npu_array_en_o          <= 1'b1;
                    npu_psum_systolic_en_o  <= 1'b1;
                    npu_psum_skew_en_o      <= 1'b1;
                    npu_compute_bank_swap_o <= swap_val;

                    if (!(comp_k[8] && comp_k[4])) begin
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
