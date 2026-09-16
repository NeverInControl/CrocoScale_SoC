`timescale 1ns / 1ps

/* ===============================================================================================
 * File: SOFT_LOGIC/npu_dma_preload_engine.sv
 * Module: npu_dma_preload_engine
 * Project: CrocoScale SoC — Combined Bias & Per-Channel Requantization Preload DMA
 *
 * Description:
 *   Dedicated preloader active during SEQ_PRELOAD. Automatically executes two 8-beat
 *   burst read requests via npu_axi_read_master:
 *   1. Fetches 8 channel biases from bias_base_i and streams directly to PSUM SRAMs.
 *   2. Fetches 8 per-channel requantization configuration words from quant_base_i,
 *      buffering and shifting them in reverse order (7 down to 0) into npu_requantizer
 *      so that lane[i] receives parameter cfg[i].
 * =============================================================================================== */

module npu_dma_preload_engine #(
    parameter int PSUM_WIDTH       = 32,
    parameter int AXI_ADDR_WIDTH   = 32,
    parameter int AXI_DATA_WIDTH   = 32
) (
    input  wire                                  clk_i,
    input  wire                                  rst_n,
    input  wire                                  start_i,
    input  wire [AXI_ADDR_WIDTH-1:0]             bias_base_i,
    input  wire [AXI_ADDR_WIDTH-1:0]             quant_base_i,

    // Command Interface to npu_axi_read_master
    output logic                                 req_valid_o,
    output logic [AXI_ADDR_WIDTH-1:0]            req_addr_o,
    output logic [7:0]                           req_len_o,
    input  wire                                  req_ready_i,

    // Data Response Stream from npu_axi_read_master
    input  wire [AXI_DATA_WIDTH-1:0]             rdata_i,
    input  wire                                  rvalid_i,
    input  wire                                  rlast_i,
    output logic                                 rready_o,

    // Hardware Outputs to PSUM Accumulation SRAMs
    output logic signed [PSUM_WIDTH-1:0]         bias_wdata_o,
    output logic [2:0]                           bias_channel_o,
    output logic                                 bias_we_o,

    // Hardware Outputs to Requantizer Configuration Chain
    output logic [29:0]                          quant_shift_in_o,
    output logic                                 quant_shift_en_o,
    output logic                                 done_o
);

    typedef enum logic [2:0] {
        IDLE        = 3'd0,
        REQ_BIAS    = 3'd1,
        READ_BIAS   = 3'd2,
        REQ_QUANT   = 3'd3,
        READ_QUANT  = 3'd4,
        SHIFT_QUANT = 3'd5,
        DONE        = 3'd6
    } state_t;

    state_t state;
    logic [2:0]  beat_cnt;
    logic [2:0]  shift_cnt;
    logic [29:0] cfg_buf [0:7];

    always_ff @(posedge clk_i or negedge rst_n) begin
        if (!rst_n) begin
            state            <= IDLE;
            req_valid_o      <= 1'b0;
            req_addr_o       <= '0;
            req_len_o        <= '0;
            rready_o         <= 1'b0;
            bias_wdata_o     <= '0;
            bias_channel_o   <= '0;
            bias_we_o        <= 1'b0;
            quant_shift_in_o <= '0;
            quant_shift_en_o <= 1'b0;
            done_o           <= 1'b0;
            beat_cnt         <= '0;
            shift_cnt        <= '0;
            for (int i = 0; i < 8; i++) cfg_buf[i] <= '0;
        end else begin
            bias_we_o        <= 1'b0;
            quant_shift_en_o <= 1'b0;
            done_o           <= 1'b0;

            case (state)
                IDLE: begin
                    req_valid_o <= 1'b0;
                    rready_o    <= 1'b0;
                    if (start_i) begin
                        req_addr_o  <= bias_base_i;
                        req_len_o   <= 8'd7; // 8 beats
                        req_valid_o <= 1'b1;
                        state       <= REQ_BIAS;
                    end
                end

                REQ_BIAS: begin
                    if (req_valid_o && req_ready_i) begin
                        req_valid_o <= 1'b0;
                        rready_o    <= 1'b1;
                        beat_cnt    <= '0;
                        state       <= READ_BIAS;
                    end
                end

                READ_BIAS: begin
                    if (rvalid_i && rready_o) begin
                        bias_wdata_o   <= $signed(rdata_i);
                        bias_channel_o <= beat_cnt;
                        bias_we_o      <= 1'b1;

                        if (rlast_i || beat_cnt == 3'd7) begin
                            rready_o    <= 1'b0;
                            req_addr_o  <= quant_base_i;
                            req_len_o   <= 8'd7; // 8 beats
                            req_valid_o <= 1'b1;
                            state       <= REQ_QUANT;
                        end else begin
                            beat_cnt <= beat_cnt + 1'b1;
                        end
                    end
                end

                REQ_QUANT: begin
                    if (req_valid_o && req_ready_i) begin
                        req_valid_o <= 1'b0;
                        rready_o    <= 1'b1;
                        beat_cnt    <= '0;
                        state       <= READ_QUANT;
                    end
                end

                READ_QUANT: begin
                    if (rvalid_i && rready_o) begin
                        cfg_buf[beat_cnt] <= rdata_i[29:0];

                        if (rlast_i || beat_cnt == 3'd7) begin
                            rready_o  <= 1'b0;
                            shift_cnt <= 3'd7;
                            state     <= SHIFT_QUANT;
                        end else begin
                            beat_cnt <= beat_cnt + 1'b1;
                        end
                    end
                end

                SHIFT_QUANT: begin
                    quant_shift_in_o <= cfg_buf[shift_cnt];
                    quant_shift_en_o <= 1'b1;

                    if (shift_cnt == 3'd0) begin
                        state <= DONE;
                    end else begin
                        shift_cnt <= shift_cnt - 1'b1;
                    end
                end

                DONE: begin
                    done_o <= 1'b1;
                    state  <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule

