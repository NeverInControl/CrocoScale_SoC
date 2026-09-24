`timescale 1ns / 1ps

/* ===============================================================================================
 * File: SOFT_LOGIC/minimal/npu_min_dma.sv
 * Module: npu_min_dma
 * Project: CrocoScale SoC -- eFPGA Minimal NPU DMA Engine
 *
 * Description:
 *   High-throughput burst DMA engine for the minimal NPU soft controller:
 *   - Channel bias preload (8 words -> address 0 of PSUM SRAMs)
 *   - Activation preload (512 words for 1x1, 648 words for 3x3 -> 8 activation SRAM banks)
 *   - Weight fetch (16 words per pass -> systolic shadow registers)
 *   - Output drain (512 words = 256 8-channel pixels from npu_out_act -> System RAM)
 *   Optimized for ultra-low LUT area:
 *   - Shared 32-bit AXI address register and base+offset stepper
 *   - Combinational SRAM write ports and PSUM bias preloader (eliminates 112 output DFFs)
 *   - Combinational write data multiplexer (eliminates 32 DFFs)
 *   - Unified pixel/word transfer tracker
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

    localparam int TOTAL_PIXELS    = (KERNEL_SIZE == 1) ? 256 : 324,
    localparam int NUM_ACT_BANKS   = ARRAY_HEIGHT,
    localparam int ACT_ADDR_WIDTH  = 9,
    localparam int PSUM_ADDR_WIDTH = 8
)(
    input  wire                                                          clk_i,
    input  wire                                                          rst_n,

    // AXI4 Master Write Address Channel
    output wire        [AXI_ADDR_WIDTH-1:0]                              m_axi_awaddr,
    output logic       [7:0]                                             m_axi_awlen,
    output wire        [2:0]                                             m_axi_awsize,
    output wire        [1:0]                                             m_axi_awburst,
    output logic                                                         m_axi_awvalid,
    input  wire                                                          m_axi_awready,

    // AXI4 Master Write Data Channel
    output logic       [AXI_DATA_WIDTH-1:0]                              m_axi_wdata,
    output wire        [(AXI_DATA_WIDTH/8)-1:0]                          m_axi_wstrb,
    output logic                                                         m_axi_wlast,
    output logic                                                         m_axi_wvalid,
    input  wire                                                          m_axi_wready,

    // AXI4 Master Write Response Channel
    input  wire        [1:0]                                             m_axi_bresp,
    input  wire                                                          m_axi_bvalid,
    output logic                                                         m_axi_bready,

    // AXI4 Master Read Address Channel
    output wire        [AXI_ADDR_WIDTH-1:0]                              m_axi_araddr,
    output logic       [7:0]                                             m_axi_arlen,
    output wire        [2:0]                                             m_axi_arsize,
    output wire        [1:0]                                             m_axi_arburst,
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
    output wire        [8:0]                                             drain_pixel_cnt_o,

    // Dedicated NPU PSUM SRAM Bias Preload Port
    output wire        [ARRAY_WIDTH-1:0]                                 bias_psum_we_o,
    output wire signed [PSUM_WIDTH-1:0]                                  bias_psum_wdata_o,

    // Dedicated NPU Activation SRAM Write Port
    output wire        [NUM_ACT_BANKS-1:0]                               ext_act_sram_we_o,
    output wire        [ACT_ADDR_WIDTH-1:0]                              ext_act_sram_addr_o,
    output wire signed [NUM_ACT_BANKS-1:0][ACTIVATION_WIDTH-1:0]         ext_act_sram_wdata_o
);

    assign m_axi_awsize  = 3'b010;
    assign m_axi_awburst = 2'b01;
    assign m_axi_wstrb   = 4'hF;
    assign m_axi_arsize  = 3'b010;
    assign m_axi_arburst = 2'b01;

    typedef enum logic [3:0] {
        DMA_IDLE       = 4'd0,
        DMA_BIAS_AR    = 4'd1,
        DMA_BIAS_R     = 4'd2,
        DMA_ACT_AR     = 4'd3,
        DMA_ACT_R      = 4'd4,
        DMA_WEIGHT_AR  = 4'd5,
        DMA_WEIGHT_R   = 4'd6,
        DMA_DRAIN_AW   = 4'd7,
        DMA_DRAIN_PRE  = 4'd8,
        DMA_DRAIN_W    = 4'd9,
        DMA_DRAIN_B    = 4'd10
    } dma_state_t;

    dma_state_t state;

    logic [AXI_ADDR_WIDTH-1:0] axi_addr_reg;
    assign m_axi_araddr = axi_addr_reg;
    assign m_axi_awaddr = axi_addr_reg;

    // Bias Preload Channel
    logic [2:0]  bias_beat;
    assign bias_psum_wdata_o = m_axi_rdata;
    assign bias_psum_we_o    = ((state == DMA_BIAS_R) && m_axi_rvalid && m_axi_rready) ? (8'b0000_0001 << bias_beat) : 8'b0;

    // Activation Preload Channel
    logic [8:0]  act_pixel_cnt;
    logic        act_word_phase;
    logic [31:0] act_sample_low;

    assign ext_act_sram_addr_o = act_pixel_cnt;
    assign ext_act_sram_we_o   = ((state == DMA_ACT_R) && m_axi_rvalid && m_axi_rready && act_word_phase) ? 8'hFF : 8'h00;

    assign ext_act_sram_wdata_o[0] = $signed(act_sample_low[7:0]);
    assign ext_act_sram_wdata_o[1] = $signed(act_sample_low[15:8]);
    assign ext_act_sram_wdata_o[2] = $signed(act_sample_low[23:16]);
    assign ext_act_sram_wdata_o[3] = $signed(act_sample_low[31:24]);
    assign ext_act_sram_wdata_o[4] = $signed(m_axi_rdata[7:0]);
    assign ext_act_sram_wdata_o[5] = $signed(m_axi_rdata[15:8]);
    assign ext_act_sram_wdata_o[6] = $signed(m_axi_rdata[23:16]);
    assign ext_act_sram_wdata_o[7] = $signed(m_axi_rdata[31:24]);

    // Weight Fetch Channel
    logic w_phase;
    wire weight_beat_valid = (state == DMA_WEIGHT_R) && m_axi_rvalid && m_axi_rready;

    assign weight_shift_en_o[0] = weight_beat_valid && (~w_phase);
    assign weight_shift_en_o[1] = weight_beat_valid && (w_phase);

    assign weight_shift_in_o[0] = $signed(m_axi_rdata[7:0]);
    assign weight_shift_in_o[1] = $signed(m_axi_rdata[15:8]);
    assign weight_shift_in_o[2] = $signed(m_axi_rdata[23:16]);
    assign weight_shift_in_o[3] = $signed(m_axi_rdata[31:24]);
    assign weight_shift_in_o[4] = $signed(m_axi_rdata[7:0]);
    assign weight_shift_in_o[5] = $signed(m_axi_rdata[15:8]);
    assign weight_shift_in_o[6] = $signed(m_axi_rdata[23:16]);
    assign weight_shift_in_o[7] = $signed(m_axi_rdata[31:24]);

    // Output Drain Channel
    logic [4:0]  drain_burst_idx;
    logic [3:0]  drain_w_beat;
    logic [2:0]  drain_pipe_cnt;
    logic [31:0] drain_high_sample;

    assign drain_pixel_cnt_o = {1'b0, drain_burst_idx, drain_w_beat[3:1]};

    always_ff @(posedge clk_i) begin
        if (!rst_n) begin
            state             <= DMA_IDLE;
            bias_done_o       <= 1'b0;
            bias_beat         <= '0;

            act_done_o        <= 1'b0;
            weight_done_o     <= 1'b0;
            drain_done_o      <= 1'b0;
            drain_psum_addr_o <= '0;

            act_pixel_cnt     <= '0;
            act_word_phase    <= 1'b0;
            act_sample_low    <= '0;

            w_phase           <= 1'b0;

            drain_burst_idx   <= '0;
            drain_w_beat      <= '0;
            drain_pipe_cnt    <= '0;
            drain_high_sample <= '0;

            axi_addr_reg      <= '0;
            m_axi_awlen       <= '0;
            m_axi_awvalid     <= 1'b0;
            m_axi_wdata       <= '0;
            m_axi_wlast       <= 1'b0;
            m_axi_wvalid      <= 1'b0;
            m_axi_bready      <= 1'b0;

            m_axi_arlen       <= '0;
            m_axi_arvalid     <= 1'b0;
            m_axi_rready      <= 1'b0;
        end else begin
            bias_done_o   <= 1'b0;
            act_done_o    <= 1'b0;
            weight_done_o <= 1'b0;
            drain_done_o  <= 1'b0;

            if (m_axi_awvalid && m_axi_awready) m_axi_awvalid <= 1'b0;
            if (m_axi_arvalid && m_axi_arready) m_axi_arvalid <= 1'b0;

            case (state)
                DMA_IDLE: begin
                    m_axi_awvalid <= 1'b0;
                    m_axi_wvalid  <= 1'b0;
                    m_axi_arvalid <= 1'b0;
                    m_axi_bready  <= 1'b0;
                    m_axi_rready  <= 1'b0;

                    if (start_bias_i) begin
                        bias_beat    <= '0;
                        axi_addr_reg <= bias_base_i;
                        state        <= DMA_BIAS_AR;
                    end else if (start_act_i) begin
                        act_pixel_cnt  <= '0;
                        act_word_phase <= 1'b0;
                        axi_addr_reg   <= act_base_i;
                        state          <= DMA_ACT_AR;
                    end else if (start_weight_i) begin
                        w_phase      <= 1'b0;
                        axi_addr_reg <= weight_base_i + {22'b0, weight_pass_idx_i, 6'b000000};
                        state        <= DMA_WEIGHT_AR;
                    end else if (start_drain_i) begin
                        drain_burst_idx <= '0;
                        axi_addr_reg    <= out_base_i;
                        state           <= DMA_DRAIN_AW;
                    end
                end

                DMA_BIAS_AR: begin
                    m_axi_arlen   <= 8'd7;
                    m_axi_arvalid <= 1'b1;
                    m_axi_rready  <= 1'b1;
                    state         <= DMA_BIAS_R;
                end

                DMA_BIAS_R: begin
                    if (m_axi_rvalid && m_axi_rready) begin
                        bias_beat <= bias_beat + 1'b1;
                        if (m_axi_rlast) begin
                            m_axi_rready <= 1'b0;
                            bias_done_o  <= 1'b1;
                            state        <= DMA_IDLE;
                        end
                    end
                end

                DMA_ACT_AR: begin
                    if (KERNEL_SIZE == 1) begin
                        m_axi_arlen <= 8'd15;
                    end else begin
                        m_axi_arlen <= (act_pixel_cnt[8] && act_pixel_cnt[6]) ? 8'd7 : 8'd15;
                    end
                    m_axi_arvalid <= 1'b1;
                    m_axi_rready  <= 1'b1;
                    state         <= DMA_ACT_R;
                end

                DMA_ACT_R: begin
                    if (m_axi_rvalid && m_axi_rready) begin
                        act_word_phase <= ~act_word_phase;

                        if (!act_word_phase) begin
                            act_sample_low <= m_axi_rdata;
                        end else begin
                            act_pixel_cnt <= act_pixel_cnt + 1'b1;
                        end

                        if (m_axi_rlast) begin
                            if (act_pixel_cnt == (9'(TOTAL_PIXELS) - 1'b1)) begin
                                m_axi_rready <= 1'b0;
                                act_done_o   <= 1'b1;
                                state        <= DMA_IDLE;
                            end else begin
                                axi_addr_reg <= axi_addr_reg + 32'd64;
                                state        <= DMA_ACT_AR;
                            end
                        end
                    end
                end

                DMA_WEIGHT_AR: begin
                    m_axi_arlen   <= 8'd15;
                    m_axi_arvalid <= 1'b1;
                    m_axi_rready  <= 1'b1;
                    state         <= DMA_WEIGHT_R;
                end

                DMA_WEIGHT_R: begin
                    if (m_axi_rvalid && m_axi_rready) begin
                        w_phase <= ~w_phase;

                        if (m_axi_rlast) begin
                            m_axi_rready  <= 1'b0;
                            weight_done_o <= 1'b1;
                            state         <= DMA_IDLE;
                        end
                    end
                end

                DMA_DRAIN_AW: begin
                    m_axi_awlen    <= 8'd15;
                    m_axi_awvalid  <= 1'b1;
                    drain_w_beat   <= '0;
                    drain_pipe_cnt <= '0;

                    drain_psum_addr_o <= {drain_burst_idx, 3'b000};
                    state             <= DMA_DRAIN_PRE;
                end

                DMA_DRAIN_PRE: begin
                    drain_pipe_cnt <= drain_pipe_cnt + 1'b1;
                    if (drain_pipe_cnt == 3'd1) drain_psum_addr_o <= {drain_burst_idx, 3'b001};
                    if (drain_pipe_cnt == 3'd3) drain_psum_addr_o <= {drain_burst_idx, 3'b010};
                    if (drain_pipe_cnt == 3'd5) drain_psum_addr_o <= {drain_burst_idx, 3'b011};
                    if (drain_pipe_cnt == 3'd6) begin
                        m_axi_wdata       <= {npu_out_act_i[3], npu_out_act_i[2], npu_out_act_i[1], npu_out_act_i[0]};
                        drain_high_sample <= {npu_out_act_i[7], npu_out_act_i[6], npu_out_act_i[5], npu_out_act_i[4]};
                        m_axi_wvalid      <= 1'b1;
                        m_axi_wlast       <= 1'b0;
                        state             <= DMA_DRAIN_W;
                    end
                end

                DMA_DRAIN_W: begin
                    if (m_axi_wvalid && m_axi_wready) begin
                        drain_w_beat <= drain_w_beat + 1'b1;

                        if (drain_w_beat[0] == 1'b0) begin
                            m_axi_wdata <= drain_high_sample;
                            if (!drain_w_beat[3]) begin
                                drain_psum_addr_o <= {drain_burst_idx, 1'b1, drain_w_beat[2:1]};
                            end
                            if (&drain_w_beat[3:1]) begin
                                m_axi_wlast <= 1'b1;
                            end
                        end else begin
                            if (&drain_w_beat[3:1]) begin
                                m_axi_wvalid <= 1'b0;
                                m_axi_wlast  <= 1'b0;
                                m_axi_bready <= 1'b1;
                                state        <= DMA_DRAIN_B;
                            end else begin
                                m_axi_wdata       <= {npu_out_act_i[3], npu_out_act_i[2], npu_out_act_i[1], npu_out_act_i[0]};
                                drain_high_sample <= {npu_out_act_i[7], npu_out_act_i[6], npu_out_act_i[5], npu_out_act_i[4]};
                            end
                        end
                    end
                end

                DMA_DRAIN_B: begin
                    if (m_axi_bvalid && m_axi_bready) begin
                        m_axi_bready <= 1'b0;
                        if (&drain_burst_idx) begin
                            drain_done_o <= 1'b1;
                            state        <= DMA_IDLE;
                        end else begin
                            drain_burst_idx <= drain_burst_idx + 1'b1;
                            axi_addr_reg    <= axi_addr_reg + 32'd64;
                            state           <= DMA_DRAIN_AW;
                        end
                    end
                end

                default: state <= DMA_IDLE;
            endcase
        end
    end

endmodule
