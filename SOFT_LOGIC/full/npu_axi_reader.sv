`timescale 1ns / 1ps

/* ===============================================================================================
 * File: SOFT_LOGIC/full/npu_axi_reader.sv
 * Module: npu_axi_reader
 * Project: CrocoScale SoC — Unified AXI4 Read DMA Master
 *
 * Description:
 *   Single unified AXI4 burst read engine serving all three read consumers in mutually
 *   exclusive phases:
 *   1. Activation Function LUT Preload (256 bytes to PSUM SRAM Bank B)
 *   2. Bias & Quantization Parameter Preload (streamed directly on AXI beats, zero buffering)
 *   3. Dual-Mode Systolic Weight Fetch (1x1: 8 beats, 3x3: 16 beats into shadow registers)
 *
 *   Eliminates duplicate AXI masters, duplicate address registers, and the 240-FF cfg_buf.
 * =============================================================================================== */

module npu_axi_reader #(
    parameter int ARRAY_HEIGHT     = 8,
    parameter int WEIGHT_WIDTH     = 8,
    parameter int PSUM_WIDTH       = 32,
    parameter int AXI_ADDR_WIDTH   = 32,
    parameter int AXI_DATA_WIDTH   = 32
) (
    input  wire                                              clk_i,
    input  wire                                              rst_n,

    // Base Addresses & Mode
    input  wire [AXI_ADDR_WIDTH-1:0]                         lut_base_i,
    input  wire [AXI_ADDR_WIDTH-1:0]                         bias_base_i,
    input  wire [AXI_ADDR_WIDTH-1:0]                         quant_base_i,
    input  wire [AXI_ADDR_WIDTH-1:0]                         weight_base_i,
    input  wire                                              mode_1x1_i,

    // Control Triggers & Handshakes
    input  wire                                              start_lut_load_i,
    output logic                                             lut_load_done_o,

    input  wire                                              start_preload_i,
    output logic                                             preload_done_o,

    input  wire                                              start_weight_fetch_i,
    input  wire [7:0]                                        fetch_pass_idx_i,
    output logic                                             weight_fetch_done_o,

    // AXI4 Master AR Channel
    output logic [AXI_ADDR_WIDTH-1:0]                        m_axi_araddr,
    output logic [7:0]                                       m_axi_arlen,
    output wire  [2:0]                                       m_axi_arsize,
    output wire  [1:0]                                       m_axi_arburst,
    output logic                                             m_axi_arvalid,
    input  wire                                              m_axi_arready,

    // AXI4 Master R Channel
    input  wire [AXI_DATA_WIDTH-1:0]                         m_axi_rdata,
    input  wire [1:0]                                        m_axi_rresp,
    input  wire                                              m_axi_rlast,
    input  wire                                              m_axi_rvalid,
    output logic                                             m_axi_rready,

    // Hardware Outputs to Systolic Array (Weights)
    output logic signed [ARRAY_HEIGHT-1:0][WEIGHT_WIDTH-1:0] weight_shift_in_o,
    output logic [1:0]                                       weight_shift_en_o,

    // Hardware Outputs to PSUM Accumulation SRAMs (Biases)
    output logic signed [PSUM_WIDTH-1:0]                     bias_wdata_o,
    output logic [2:0]                                       bias_channel_o,
    output logic                                             bias_we_o,

    // Hardware Outputs to Requantizer Configuration Chain
    output logic [29:0]                                      quant_shift_in_o,
    output logic                                             quant_shift_en_o,

    // Hardware Interface to PSUM SRAM Bank B (Activation LUT Preload)
    output logic [7:0]                                       psum_B_addr_o,
    output logic [31:0]                                      psum_B_wdata_o,
    output logic [7:0]                                       psum_B_we_o
);

    assign m_axi_arsize  = 3'b010; // 4 bytes (32-bit transfers)
    assign m_axi_arburst = 2'b01;  // INCR

    typedef enum logic [3:0] {
        IDLE             = 4'd0,
        // LUT load phases
        LUT_AR           = 4'd1,
        LUT_R_WORD       = 4'd2,
        LUT_W_B0         = 4'd3,
        LUT_W_B1         = 4'd4,
        LUT_W_B2         = 4'd5,
        LUT_W_B3         = 4'd6,
        // Preload phases
        PRELOAD_BIAS_AR     = 4'd7,
        PRELOAD_BIAS_R      = 4'd8,
        PRELOAD_QUANT_AR    = 4'd9,
        PRELOAD_QUANT_R     = 4'd10,
        // Weight fetch phases
        WEIGHT_AR           = 4'd11,
        WEIGHT_R            = 4'd12
    } state_t;

    state_t state;

    logic [4:0]  beat_cnt;
    logic [1:0]  burst_idx;
    logic [5:0]  word_idx;
    logic [31:0] lat_word;

    // Weight streaming multiplexing
    wire weight_beat_valid = (state == WEIGHT_R) && (m_axi_rvalid && m_axi_rready);

    always_comb begin
        if (mode_1x1_i) begin
            weight_shift_en_o[0] = weight_beat_valid;
            weight_shift_en_o[1] = weight_beat_valid;
            weight_shift_in_o[0] = $signed(m_axi_rdata[7:0]);
            weight_shift_in_o[1] = $signed(m_axi_rdata[15:8]);
            weight_shift_in_o[2] = $signed(m_axi_rdata[23:16]);
            weight_shift_in_o[3] = $signed(m_axi_rdata[31:24]);
            weight_shift_in_o[4] = 8'sd0;
            weight_shift_in_o[5] = 8'sd0;
            weight_shift_in_o[6] = 8'sd0;
            weight_shift_in_o[7] = 8'sd0;
        end else begin
            weight_shift_en_o[0] = weight_beat_valid && beat_cnt[0];
            weight_shift_en_o[1] = weight_beat_valid && beat_cnt[0];
            weight_shift_in_o[0] = $signed(lat_word[7:0]);
            weight_shift_in_o[1] = $signed(lat_word[15:8]);
            weight_shift_in_o[2] = $signed(lat_word[23:16]);
            weight_shift_in_o[3] = $signed(lat_word[31:24]);
            weight_shift_in_o[4] = $signed(m_axi_rdata[7:0]);
            weight_shift_in_o[5] = $signed(m_axi_rdata[15:8]);
            weight_shift_in_o[6] = $signed(m_axi_rdata[23:16]);
            weight_shift_in_o[7] = $signed(m_axi_rdata[31:24]);
        end
    end

    // Direct combinational streaming for Bias, Quantization parameters, and LUT Preload
    assign bias_wdata_o     = $signed(m_axi_rdata);
    assign bias_channel_o   = beat_cnt[2:0];
    assign bias_we_o        = (state == PRELOAD_BIAS_R) && (m_axi_rvalid && m_axi_rready);

    assign quant_shift_in_o = m_axi_rdata[29:0];
    assign quant_shift_en_o = (state == PRELOAD_QUANT_R) && (m_axi_rvalid && m_axi_rready);

    always_comb begin
        case (state)
            LUT_W_B0: begin
                psum_B_addr_o  = {word_idx, 2'b00};
                psum_B_wdata_o = {24'd0, lat_word[7:0]};
                psum_B_we_o    = 8'hFF;
            end
            LUT_W_B1: begin
                psum_B_addr_o  = {word_idx, 2'b01};
                psum_B_wdata_o = {24'd0, lat_word[15:8]};
                psum_B_we_o    = 8'hFF;
            end
            LUT_W_B2: begin
                psum_B_addr_o  = {word_idx, 2'b10};
                psum_B_wdata_o = {24'd0, lat_word[23:16]};
                psum_B_we_o    = 8'hFF;
            end
            LUT_W_B3: begin
                psum_B_addr_o  = {word_idx, 2'b11};
                psum_B_wdata_o = {24'd0, lat_word[31:24]};
                psum_B_we_o    = 8'hFF;
            end
            default: begin
                psum_B_addr_o  = '0;
                psum_B_wdata_o = '0;
                psum_B_we_o    = 8'h00;
            end
        endcase
    end

    always_ff @(posedge clk_i or negedge rst_n) begin
        if (!rst_n) begin
            state               <= IDLE;
            m_axi_araddr        <= '0;
            m_axi_arlen         <= '0;
            m_axi_arvalid       <= 1'b0;
            m_axi_rready        <= 1'b0;
            lut_load_done_o     <= 1'b0;
            preload_done_o      <= 1'b0;
            weight_fetch_done_o <= 1'b0;
            beat_cnt            <= '0;
            burst_idx           <= '0;
            word_idx            <= '0;
            lat_word            <= '0;
        end else begin
            // Default single-cycle strobes
            lut_load_done_o     <= 1'b0;
            preload_done_o      <= 1'b0;
            weight_fetch_done_o <= 1'b0;

            case (state)
                IDLE: begin
                    m_axi_arvalid <= 1'b0;
                    m_axi_rready  <= 1'b0;
                    beat_cnt      <= '0;

                    if (start_lut_load_i) begin
                        burst_idx     <= 2'd0;
                        word_idx      <= 6'd0;
                        m_axi_araddr  <= lut_base_i;
                        m_axi_arlen   <= 8'd15; // 16 beats = 64 bytes
                        m_axi_arvalid <= 1'b1;
                        state         <= LUT_AR;
                    end else if (start_preload_i) begin
                        m_axi_araddr  <= bias_base_i;
                        m_axi_arlen   <= 8'd7;  // 8 beats = 8 channel biases
                        m_axi_arvalid <= 1'b1;
                        state         <= PRELOAD_BIAS_AR;
                    end else if (start_weight_fetch_i) begin
                        if (mode_1x1_i) begin
                            m_axi_araddr <= weight_base_i + {19'd0, fetch_pass_idx_i, 5'b00000}; // pass * 32
                            m_axi_arlen  <= 8'd7;                                                 // 8 beats
                        end else begin
                            m_axi_araddr <= weight_base_i + {18'd0, fetch_pass_idx_i, 6'b000000}; // pass * 64
                            m_axi_arlen  <= 8'd15;                                                // 16 beats
                        end
                        m_axi_arvalid <= 1'b1;
                        state         <= WEIGHT_AR;
                    end
                end

                // -----------------------------------------------------------------
                // Activation LUT Preload Engine
                // -----------------------------------------------------------------
                LUT_AR: begin
                    if (m_axi_arvalid && m_axi_arready) begin
                        m_axi_arvalid <= 1'b0;
                        m_axi_rready  <= 1'b1;
                        state         <= LUT_R_WORD;
                    end
                end

                LUT_R_WORD: begin
                    if (m_axi_rvalid && m_axi_rready) begin
                        lat_word     <= m_axi_rdata;
                        m_axi_rready <= 1'b0; // Pause AXI stream while unpacking 4 bytes to Bank B
                        state        <= LUT_W_B0;
                    end
                end

                LUT_W_B0: begin
                    state <= LUT_W_B1;
                end

                LUT_W_B1: begin
                    state <= LUT_W_B2;
                end

                LUT_W_B2: begin
                    state <= LUT_W_B3;
                end

                LUT_W_B3: begin
                    word_idx <= word_idx + 1'b1;

                    if (beat_cnt == 5'd15) begin
                        if (burst_idx == 2'd3) begin
                            lut_load_done_o <= 1'b1;
                            state           <= IDLE;
                        end else begin
                            burst_idx     <= burst_idx + 1'b1;
                            m_axi_araddr  <= lut_base_i + {24'd0, (burst_idx + 2'd1), 6'b000000};
                            m_axi_arlen   <= 8'd15;
                            m_axi_arvalid <= 1'b1;
                            beat_cnt      <= '0;
                            state         <= LUT_AR;
                        end
                    end else begin
                        beat_cnt     <= beat_cnt + 1'b1;
                        m_axi_rready <= 1'b1;
                        state        <= LUT_R_WORD;
                    end
                end

                // -----------------------------------------------------------------
                // Bias & Quantization Preload Engine (Direct On-The-Fly Streaming)
                // -----------------------------------------------------------------
                PRELOAD_BIAS_AR: begin
                    if (m_axi_arvalid && m_axi_arready) begin
                        m_axi_arvalid <= 1'b0;
                        m_axi_rready  <= 1'b1;
                        beat_cnt      <= '0;
                        state         <= PRELOAD_BIAS_R;
                    end
                end

                PRELOAD_BIAS_R: begin
                    if (m_axi_rvalid && m_axi_rready) begin
                        if (m_axi_rlast || beat_cnt == 5'd7) begin
                            m_axi_rready  <= 1'b0;
                            m_axi_araddr  <= quant_base_i;
                            m_axi_arlen   <= 8'd7; // 8 beats = 8 requant words
                            m_axi_arvalid <= 1'b1;
                            beat_cnt      <= '0;
                            state         <= PRELOAD_QUANT_AR;
                        end else begin
                            beat_cnt <= beat_cnt + 1'b1;
                        end
                    end
                end

                PRELOAD_QUANT_AR: begin
                    if (m_axi_arvalid && m_axi_arready) begin
                        m_axi_arvalid <= 1'b0;
                        m_axi_rready  <= 1'b1;
                        beat_cnt      <= '0;
                        state         <= PRELOAD_QUANT_R;
                    end
                end

                PRELOAD_QUANT_R: begin
                    if (m_axi_rvalid && m_axi_rready) begin
                        if (m_axi_rlast || beat_cnt == 5'd7) begin
                            m_axi_rready   <= 1'b0;
                            preload_done_o <= 1'b1;
                            state          <= IDLE;
                        end else begin
                            beat_cnt <= beat_cnt + 1'b1;
                        end
                    end
                end

                // -----------------------------------------------------------------
                // Dual-Mode Systolic Weight Fetch Engine
                // -----------------------------------------------------------------
                WEIGHT_AR: begin
                    if (m_axi_arvalid && m_axi_arready) begin
                        m_axi_arvalid <= 1'b0;
                        m_axi_rready  <= 1'b1;
                        beat_cnt      <= '0;
                        state         <= WEIGHT_R;
                    end
                end

                WEIGHT_R: begin
                    if (m_axi_rvalid && m_axi_rready) begin
                        if (!mode_1x1_i && !beat_cnt[0]) begin
                            lat_word <= m_axi_rdata;
                        end

                        if (m_axi_rlast || (mode_1x1_i ? (beat_cnt == 5'd7) : (beat_cnt == 5'd15))) begin
                            m_axi_rready        <= 1'b0;
                            weight_fetch_done_o <= 1'b1;
                            state               <= IDLE;
                        end else begin
                            beat_cnt <= beat_cnt + 1'b1;
                        end
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule

