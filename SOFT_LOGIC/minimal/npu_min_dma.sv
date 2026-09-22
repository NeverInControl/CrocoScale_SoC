`timescale 1ns / 1ps

/* ===============================================================================================
 * File: SOFT_LOGIC/minimal/npu_min_dma.sv
 * Module: npu_min_dma
 * Project: CrocoScale SoC -- eFPGA Minimal NPU DMA Engine
 *
 * Description:
 *   High-throughput AXI4 Master DMA engine for the minimal NPU soft controller:
 *   - Channel Bias Preload (8 words = 32-bit bias per channel -> PSUM Bank A/B Address 0)
 *   - Activation Preload:
 *       KERNEL_SIZE == 1: 512 words (256 8-channel pixels -> 8 SRAM banks)
 *       KERNEL_SIZE == 3: 648 words (324 8-channel pixels -> 8 SRAM banks)
 *   - Weight Fetch: 16 words per pass streamed into systolic PE shadow registers
 *   - Output Drain: 512 words (256 8-channel pixels from npu_out_act -> System RAM)
 *   Uses fully synchronous reset for optimal FPGA/eFPGA mapping (single-LUT DFFs).
 * =============================================================================================== */

module npu_min_dma #(
    parameter int KERNEL_SIZE      = 3,
    parameter int ARRAY_HEIGHT     = 8,
    parameter int ARRAY_WIDTH      = 8,
    parameter int TILE_SIZE        = 16,
    parameter int ACT_HALO_PAD     = 2,
    parameter int ACTIVATION_WIDTH = 8,
    parameter int WEIGHT_WIDTH     = 8,
    parameter int PSUM_WIDTH       = 32,
    parameter int AXI_ADDR_WIDTH   = 32,
    parameter int AXI_DATA_WIDTH   = 32,
    parameter int WEIGHT_SPLIT     = 2,

    localparam int PSUM_WORDS      = TILE_SIZE * TILE_SIZE, // 256
    localparam int ACT_WORDS       = (KERNEL_SIZE == 1) ? 256 : (TILE_SIZE * TILE_SIZE) * ACT_HALO_PAD,
    localparam int TOTAL_ACT_WORDS = (KERNEL_SIZE == 1) ? 512 : 648,
    localparam int PSUM_ADDR_WIDTH = $clog2(PSUM_WORDS), // 8
    localparam int ACT_ADDR_WIDTH  = 9,
    localparam int NUM_ACT_BANKS   = ARRAY_HEIGHT        // 8
)(
    input  wire                                                          clk_i,
    input  wire                                                          rst_n,

    // AXI4 Master Write Address Channel
    output logic       [AXI_ADDR_WIDTH-1:0]                              m_axi_awaddr,
    output logic       [7:0]                                             m_axi_awlen,
    output logic       [2:0]                                             m_axi_awsize,
    output logic       [1:0]                                             m_axi_awburst,
    output logic                                                         m_axi_awvalid,
    input  wire                                                          m_axi_awready,

    // AXI4 Master Write Data Channel
    output logic       [AXI_DATA_WIDTH-1:0]                              m_axi_wdata,
    output logic       [(AXI_DATA_WIDTH/8)-1:0]                          m_axi_wstrb,
    output logic                                                         m_axi_wlast,
    output logic                                                         m_axi_wvalid,
    input  wire                                                          m_axi_wready,

    // AXI4 Master Write Response Channel
    input  wire        [1:0]                                             m_axi_bresp,
    input  wire                                                          m_axi_bvalid,
    output logic                                                         m_axi_bready,

    // AXI4 Master Read Address Channel
    output logic       [AXI_ADDR_WIDTH-1:0]                              m_axi_araddr,
    output logic       [7:0]                                             m_axi_arlen,
    output logic       [2:0]                                             m_axi_arsize,
    output logic       [1:0]                                             m_axi_arburst,
    output logic                                                         m_axi_arvalid,
    input  wire                                                          m_axi_arready,

    // AXI4 Master Read Data Channel
    input  wire        [AXI_DATA_WIDTH-1:0]                              m_axi_rdata,
    input  wire        [1:0]                                             m_axi_rresp,
    input  wire                                                          m_axi_rlast,
    input  wire                                                          m_axi_rvalid,
    output logic                                                         m_axi_rready,

    // Base Addresses & Control Triggers
    input  wire        [31:0]                                            act_base_i,
    input  wire        [31:0]                                            weight_base_i,
    input  wire        [31:0]                                            out_base_i,
    input  wire        [31:0]                                            bias_base_i,

    // Bias Preload Channel
    input  wire                                                          start_bias_i,
    output logic                                                         bias_done_o,

    // Activation Fetch Channel
    input  wire                                                          start_act_i,
    output logic                                                         act_done_o,

    // Weight Fetch Channel
    input  wire                                                          start_weight_i,
    input  wire        [3:0]                                             weight_pass_idx_i,
    output logic                                                         weight_done_o,
    output wire signed [ARRAY_HEIGHT-1:0][WEIGHT_WIDTH-1:0]              weight_shift_in_o,
    output wire        [WEIGHT_SPLIT-1:0]                                weight_shift_en_o,

    // Output Drain Channel
    input  wire                                                          start_drain_i,
    output logic                                                         drain_done_o,
    output logic       [PSUM_ADDR_WIDTH-1:0]                             drain_psum_addr_o,
    input  wire signed [ARRAY_WIDTH-1:0][ACTIVATION_WIDTH-1:0]           npu_out_act_i,
    output logic       [8:0]                                             drain_pixel_cnt_o,

    // Dedicated NPU PSUM SRAM Bias Preload Write Interface
    output logic       [PSUM_ADDR_WIDTH-1:0]                             bias_psum_A_addr_o,
    output logic       [ARRAY_WIDTH-1:0]                                 bias_psum_A_we_o,
    output logic signed [PSUM_WIDTH-1:0]                                 bias_psum_A_wdata_o,
    output logic       [PSUM_ADDR_WIDTH-1:0]                             bias_psum_B_addr_o,
    output logic       [ARRAY_WIDTH-1:0]                                 bias_psum_B_we_o,
    output logic signed [PSUM_WIDTH-1:0]                                 bias_psum_B_wdata_o,

    // Dedicated NPU Activation SRAM Write Interface
    output logic       [NUM_ACT_BANKS-1:0]                               ext_act_sram_we_o,
    output logic       [NUM_ACT_BANKS-1:0][ACT_ADDR_WIDTH-1:0]           ext_act_sram_addr_o,
    output logic signed [NUM_ACT_BANKS-1:0][ACTIVATION_WIDTH-1:0]        ext_act_sram_wdata_o
);

    typedef enum logic [3:0] {
        DMA_IDLE          = 4'd0,
        DMA_BIAS_AR       = 4'd1,
        DMA_BIAS_R        = 4'd2,
        DMA_ACT_AR        = 4'd3,
        DMA_ACT_R         = 4'd4,
        DMA_WEIGHT_AR     = 4'd5,
        DMA_WEIGHT_R      = 4'd6,
        DMA_DRAIN_AW      = 4'd7,
        DMA_DRAIN_PIPE_0  = 4'd8,
        DMA_DRAIN_PIPE_1  = 4'd9,
        DMA_DRAIN_PIPE_2  = 4'd10,
        DMA_DRAIN_PIPE_3  = 4'd11,
        DMA_DRAIN_W       = 4'd12,
        DMA_DRAIN_B       = 4'd13,
        DMA_DONE_PULSE    = 4'd14
    } dma_state_t;

    dma_state_t state;

    // Counters and Registers
    logic [2:0]  bias_beat;
    logic [9:0]  act_words_transferred;
    logic [8:0]  act_pixel_cnt;
    logic        act_word_phase;
    logic [31:0] act_sample_low;

    logic [4:0]  w_beat;
    wire weight_beat_valid = (state == DMA_WEIGHT_R) && m_axi_rvalid && m_axi_rready;

    assign weight_shift_en_o[0] = weight_beat_valid && (~w_beat[0]);
    assign weight_shift_en_o[1] = weight_beat_valid && (w_beat[0]);

    assign weight_shift_in_o[0] = $signed(m_axi_rdata[7:0]);
    assign weight_shift_in_o[1] = $signed(m_axi_rdata[15:8]);
    assign weight_shift_in_o[2] = $signed(m_axi_rdata[23:16]);
    assign weight_shift_in_o[3] = $signed(m_axi_rdata[31:24]);
    assign weight_shift_in_o[4] = $signed(m_axi_rdata[7:0]);
    assign weight_shift_in_o[5] = $signed(m_axi_rdata[15:8]);
    assign weight_shift_in_o[6] = $signed(m_axi_rdata[23:16]);
    assign weight_shift_in_o[7] = $signed(m_axi_rdata[31:24]);

    logic [5:0]  drain_burst_idx;
    wire  [8:0]  burst_base_p = {drain_burst_idx, 3'b000};
    logic [4:0]  drain_w_beat;
    logic signed [ARRAY_WIDTH-1:0][ACTIVATION_WIDTH-1:0] drain_pixel_lat;

    assign drain_pixel_cnt_o = burst_base_p + (drain_w_beat >> 1);

    // Fully Synchronous Reset
    always_ff @(posedge clk_i) begin
        if (!rst_n) begin
            state                 <= DMA_IDLE;
            bias_done_o           <= 1'b0;
            bias_beat             <= '0;
            bias_psum_A_addr_o    <= '0;
            bias_psum_A_we_o      <= '0;
            bias_psum_A_wdata_o   <= '0;
            bias_psum_B_addr_o    <= '0;
            bias_psum_B_we_o      <= '0;
            bias_psum_B_wdata_o   <= '0;

            act_done_o            <= 1'b0;
            weight_done_o         <= 1'b0;
            drain_done_o          <= 1'b0;
            drain_psum_addr_o     <= '0;

            act_words_transferred <= '0;
            act_pixel_cnt         <= '0;
            act_word_phase        <= 1'b0;
            act_sample_low        <= '0;

            w_beat                <= '0;

            drain_burst_idx       <= '0;
            drain_w_beat          <= '0;
            drain_pixel_lat       <= '0;

            m_axi_awaddr          <= '0;
            m_axi_awlen           <= '0;
            m_axi_awsize          <= 3'b010;
            m_axi_awburst         <= 2'b01;
            m_axi_awvalid         <= 1'b0;
            m_axi_wdata           <= '0;
            m_axi_wstrb           <= 4'h0;
            m_axi_wlast           <= 1'b0;
            m_axi_wvalid          <= 1'b0;
            m_axi_bready          <= 1'b0;

            m_axi_araddr          <= '0;
            m_axi_arlen           <= '0;
            m_axi_arsize          <= 3'b010;
            m_axi_arburst         <= 2'b01;
            m_axi_arvalid         <= 1'b0;
            m_axi_rready          <= 1'b0;

            ext_act_sram_we_o     <= '0;
            ext_act_sram_addr_o   <= '0;
            ext_act_sram_wdata_o  <= '0;
        end else begin
            bias_done_o       <= 1'b0;
            bias_psum_A_we_o  <= '0;
            bias_psum_B_we_o  <= '0;
            act_done_o        <= 1'b0;
            weight_done_o     <= 1'b0;
            drain_done_o      <= 1'b0;
            ext_act_sram_we_o <= '0;

            case (state)
                DMA_IDLE: begin
                    m_axi_awvalid <= 1'b0;
                    m_axi_wvalid  <= 1'b0;
                    m_axi_arvalid <= 1'b0;
                    m_axi_bready  <= 1'b0;
                    m_axi_rready  <= 1'b0;

                    if (start_bias_i) begin
                        bias_beat <= '0;
                        state     <= DMA_BIAS_AR;
                    end else if (start_act_i) begin
                        act_words_transferred <= '0;
                        act_pixel_cnt         <= '0;
                        act_word_phase        <= 1'b0;
                        state                 <= DMA_ACT_AR;
                    end else if (start_weight_i) begin
                        w_beat <= '0;
                        state  <= DMA_WEIGHT_AR;
                    end else if (start_drain_i) begin
                        drain_burst_idx <= '0;
                        state           <= DMA_DRAIN_AW;
                    end
                end

                // Channel Bias Preload (8 words)
                DMA_BIAS_AR: begin
                    m_axi_araddr  <= bias_base_i;
                    m_axi_arlen   <= 8'd7;
                    m_axi_arsize  <= 3'b010;
                    m_axi_arburst <= 2'b01;
                    m_axi_arvalid <= 1'b1;
                    m_axi_rready  <= 1'b1;
                    state         <= DMA_BIAS_R;
                end

                DMA_BIAS_R: begin
                    if (m_axi_arvalid && m_axi_arready) begin
                        m_axi_arvalid <= 1'b0;
                    end

                    if (m_axi_rvalid && m_axi_rready) begin
                        bias_psum_A_addr_o  <= '0;
                        bias_psum_A_we_o    <= (8'b0000_0001 << bias_beat);
                        bias_psum_A_wdata_o <= m_axi_rdata;

                        bias_psum_B_addr_o  <= '0;
                        bias_psum_B_we_o    <= (8'b0000_0001 << bias_beat);
                        bias_psum_B_wdata_o <= m_axi_rdata;

                        bias_beat <= bias_beat + 1'b1;

                        if (m_axi_rlast) begin
                            m_axi_rready <= 1'b0;
                            bias_done_o  <= 1'b1;
                            state        <= DMA_IDLE;
                        end
                    end
                end

                // Activation Tensor Fetch (512 words for 1x1, 648 words for 3x3)
                DMA_ACT_AR: begin
                    m_axi_araddr  <= act_base_i + {20'b0, act_words_transferred, 2'b00};
                    m_axi_arsize  <= 3'b010;
                    m_axi_arburst <= 2'b01;
                    if ((10'(TOTAL_ACT_WORDS) - act_words_transferred) >= 10'd16) begin
                        m_axi_arlen <= 8'd15;
                    end else begin
                        m_axi_arlen <= 8'd7;
                    end
                    m_axi_arvalid <= 1'b1;
                    m_axi_rready  <= 1'b1;
                    state         <= DMA_ACT_R;
                end

                DMA_ACT_R: begin
                    if (m_axi_arvalid && m_axi_arready) begin
                        m_axi_arvalid <= 1'b0;
                    end

                    if (m_axi_rvalid && m_axi_rready) begin
                        act_words_transferred <= act_words_transferred + 1'b1;

                        if (!act_word_phase) begin
                            act_sample_low <= m_axi_rdata;
                            act_word_phase <= 1'b1;
                        end else begin
                            act_word_phase <= 1'b0;
                            for (int b = 0; b < NUM_ACT_BANKS; b++) begin
                                ext_act_sram_addr_o[b] <= (ACT_ADDR_WIDTH)'(act_pixel_cnt);
                            end
                            ext_act_sram_wdata_o[0] <= $signed(act_sample_low[7:0]);
                            ext_act_sram_wdata_o[1] <= $signed(act_sample_low[15:8]);
                            ext_act_sram_wdata_o[2] <= $signed(act_sample_low[23:16]);
                            ext_act_sram_wdata_o[3] <= $signed(act_sample_low[31:24]);
                            ext_act_sram_wdata_o[4] <= $signed(m_axi_rdata[7:0]);
                            ext_act_sram_wdata_o[5] <= $signed(m_axi_rdata[15:8]);
                            ext_act_sram_wdata_o[6] <= $signed(m_axi_rdata[23:16]);
                            ext_act_sram_wdata_o[7] <= $signed(m_axi_rdata[31:24]);
                            ext_act_sram_we_o       <= 8'hFF;
                            act_pixel_cnt           <= act_pixel_cnt + 1'b1;
                        end

                        if (m_axi_rlast) begin
                            if ((act_words_transferred + 1'b1) == 10'(TOTAL_ACT_WORDS)) begin
                                m_axi_rready <= 1'b0;
                                state        <= DMA_DONE_PULSE;
                            end else begin
                                state        <= DMA_ACT_AR;
                            end
                        end
                    end
                end

                // Weight Fetch (16 words = 64 weights per pass)
                DMA_WEIGHT_AR: begin
                    m_axi_araddr  <= weight_base_i + {20'b0, weight_pass_idx_i, 6'b000000};
                    m_axi_arlen   <= 8'd15;
                    m_axi_arsize  <= 3'b010;
                    m_axi_arburst <= 2'b01;
                    m_axi_arvalid <= 1'b1;
                    m_axi_rready  <= 1'b1;
                    state         <= DMA_WEIGHT_R;
                end

                DMA_WEIGHT_R: begin
                    if (m_axi_arvalid && m_axi_arready) begin
                        m_axi_arvalid <= 1'b0;
                    end

                    if (m_axi_rvalid && m_axi_rready) begin
                        w_beat <= w_beat + 1'b1;

                        if (m_axi_rlast) begin
                            m_axi_rready  <= 1'b0;
                            weight_done_o <= 1'b1;
                            state         <= DMA_IDLE;
                        end
                    end
                end

                // Output Drain Write (32 bursts x 16 beats = 512 words)
                DMA_DRAIN_AW: begin
                    m_axi_awaddr  <= out_base_i + {21'b0, drain_burst_idx, 6'b000000};
                    m_axi_awlen   <= 8'd15;
                    m_axi_awsize  <= 3'b010;
                    m_axi_awburst <= 2'b01;
                    m_axi_awvalid <= 1'b1;
                    drain_w_beat  <= '0;

                    drain_psum_addr_o <= (PSUM_ADDR_WIDTH)'(burst_base_p + 3'd0);
                    state             <= DMA_DRAIN_PIPE_0;
                end

                DMA_DRAIN_PIPE_0: begin
                    if (m_axi_awvalid && m_axi_awready) m_axi_awvalid <= 1'b0;
                    state <= DMA_DRAIN_PIPE_1;
                end

                DMA_DRAIN_PIPE_1: begin
                    if (m_axi_awvalid && m_axi_awready) m_axi_awvalid <= 1'b0;
                    drain_psum_addr_o <= (PSUM_ADDR_WIDTH)'(burst_base_p + 3'd1);
                    state             <= DMA_DRAIN_PIPE_2;
                end

                DMA_DRAIN_PIPE_2: begin
                    if (m_axi_awvalid && m_axi_awready) m_axi_awvalid <= 1'b0;
                    state <= DMA_DRAIN_PIPE_3;
                end

                DMA_DRAIN_PIPE_3: begin
                    if (m_axi_awvalid && m_axi_awready) m_axi_awvalid <= 1'b0;
                    drain_psum_addr_o <= (PSUM_ADDR_WIDTH)'(burst_base_p + 3'd2);
                    drain_pixel_lat   <= npu_out_act_i;
                    m_axi_wdata       <= {npu_out_act_i[3], npu_out_act_i[2], npu_out_act_i[1], npu_out_act_i[0]};
                    m_axi_wstrb       <= 4'hF;
                    m_axi_wvalid      <= 1'b1;
                    m_axi_wlast       <= 1'b0;
                    state             <= DMA_DRAIN_W;
                end

                DMA_DRAIN_W: begin
                    if (m_axi_awvalid && m_axi_awready) m_axi_awvalid <= 1'b0;

                    if (m_axi_wvalid && m_axi_wready) begin
                        drain_w_beat <= drain_w_beat + 1'b1;

                        if (drain_w_beat[0] == 1'b0) begin
                            m_axi_wdata <= {drain_pixel_lat[7], drain_pixel_lat[6], drain_pixel_lat[5], drain_pixel_lat[4]};
                            if (drain_w_beat == 5'd14) begin
                                m_axi_wlast <= 1'b1;
                            end
                        end else begin
                            if (drain_w_beat == 5'd15) begin
                                m_axi_wvalid <= 1'b0;
                                m_axi_wlast  <= 1'b0;
                                m_axi_bready <= 1'b1;
                                state        <= DMA_DRAIN_B;
                            end else begin
                                m_axi_wdata     <= {npu_out_act_i[3], npu_out_act_i[2], npu_out_act_i[1], npu_out_act_i[0]};
                                drain_pixel_lat <= npu_out_act_i;

                                if (drain_w_beat <= 5'd9) begin
                                    drain_psum_addr_o <= (PSUM_ADDR_WIDTH)'(burst_base_p + ((drain_w_beat + 1'b1) >> 1) + 3'd2);
                                end
                            end
                        end
                    end
                end

                DMA_DRAIN_B: begin
                    if (m_axi_bvalid && m_axi_bready) begin
                        m_axi_bready <= 1'b0;
                        if (drain_burst_idx == 6'd31) begin
                            drain_done_o <= 1'b1;
                            state        <= DMA_IDLE;
                        end else begin
                            drain_burst_idx <= drain_burst_idx + 1'b1;
                            state           <= DMA_DRAIN_AW;
                        end
                    end
                end

                DMA_DONE_PULSE: begin
                    act_done_o <= 1'b1;
                    state      <= DMA_IDLE;
                end

                default: state <= DMA_IDLE;
            endcase
        end
    end

endmodule

