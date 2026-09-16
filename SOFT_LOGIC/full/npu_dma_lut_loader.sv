`timescale 1ns / 1ps

/* ===============================================================================================
 * File: SOFT_LOGIC/npu_dma_lut_loader.sv
 * Module: npu_dma_lut_loader
 * Project: CrocoScale SoC — Dedicated Activation Function LUT Preload DMA
 *
 * Description:
 *   Fetches 256 bytes (64 32-bit words) of arbitrary non-linear activation
 *   function lookup table entries from system AXI memory across 4 bursts of 16 beats
 *   using npu_axi_read_master. Populates all 8 columns of PSUM Bank B (addresses 0..255)
 *   for parallel non-linear activation lookup during the drain sweep.
 * =============================================================================================== */

module npu_dma_lut_loader #(
    parameter int AXI_ADDR_WIDTH = 32,
    parameter int AXI_DATA_WIDTH = 32
) (
    input  wire                       clk_i,
    input  wire                       rst_n,
    input  wire                       start_i,
    input  wire [AXI_ADDR_WIDTH-1:0]  lut_base_i,

    // Command Interface to npu_axi_read_master
    output logic                      req_valid_o,
    output logic [AXI_ADDR_WIDTH-1:0] req_addr_o,
    output logic [7:0]                req_len_o,
    input  wire                       req_ready_i,

    // Data Response Stream from npu_axi_read_master
    input  wire [AXI_DATA_WIDTH-1:0]  rdata_i,
    input  wire                       rvalid_i,
    input  wire                       rlast_i,
    output logic                      rready_o,

    // Hardware Interface to PSUM SRAM Bank B
    output logic [7:0]                psum_B_addr_o,
    output logic [31:0]               psum_B_wdata_o,
    output logic [7:0]                psum_B_we_o,
    output logic                      done_o
);

    typedef enum logic [2:0] {
        IDLE      = 3'd0,
        REQ_AR    = 3'd1,
        READ_WORD = 3'd2,
        WRITE_B0  = 3'd3,
        WRITE_B1  = 3'd4,
        WRITE_B2  = 3'd5,
        WRITE_B3  = 3'd6,
        DONE      = 3'd7
    } state_t;

    state_t state;

    logic [1:0]  burst_idx; // 0 to 3 (4 bursts of 16 beats = 64 words = 256 bytes)
    logic [3:0]  beat_cnt;  // 0 to 15
    logic [7:0]  word_idx;  // 0 to 63
    logic [31:0] lat_word;

    always_ff @(posedge clk_i or negedge rst_n) begin
        if (!rst_n) begin
            state          <= IDLE;
            burst_idx      <= '0;
            beat_cnt       <= '0;
            word_idx       <= '0;
            lat_word       <= '0;
            req_valid_o    <= 1'b0;
            req_addr_o     <= '0;
            req_len_o      <= '0;
            rready_o       <= 1'b0;
            psum_B_addr_o  <= '0;
            psum_B_wdata_o <= '0;
            psum_B_we_o    <= 8'h00;
            done_o         <= 1'b0;
        end else begin
            psum_B_we_o <= 8'h00;
            done_o      <= 1'b0;

            case (state)
                IDLE: begin
                    req_valid_o <= 1'b0;
                    rready_o    <= 1'b0;
                    if (start_i) begin
                        burst_idx   <= '0;
                        word_idx    <= '0;
                        beat_cnt    <= '0;
                        req_addr_o  <= lut_base_i;
                        req_len_o   <= 8'd15; // 16 beats = 64 bytes
                        req_valid_o <= 1'b1;
                        state       <= REQ_AR;
                    end
                end

                REQ_AR: begin
                    if (req_valid_o && req_ready_i) begin
                        req_valid_o <= 1'b0;
                        rready_o    <= 1'b1;
                        state       <= READ_WORD;
                    end
                end

                READ_WORD: begin
                    if (rvalid_i && rready_o) begin
                        lat_word <= rdata_i;
                        rready_o <= 1'b0; // Pause AXI while writing 4 bytes to Bank B
                        state    <= WRITE_B0;
                    end
                end

                WRITE_B0: begin
                    psum_B_addr_o  <= {word_idx[5:0], 2'b00};
                    psum_B_wdata_o <= {24'd0, lat_word[7:0]};
                    psum_B_we_o    <= 8'hFF;
                    state          <= WRITE_B1;
                end

                WRITE_B1: begin
                    psum_B_addr_o  <= {word_idx[5:0], 2'b01};
                    psum_B_wdata_o <= {24'd0, lat_word[15:8]};
                    psum_B_we_o    <= 8'hFF;
                    state          <= WRITE_B2;
                end

                WRITE_B2: begin
                    psum_B_addr_o  <= {word_idx[5:0], 2'b10};
                    psum_B_wdata_o <= {24'd0, lat_word[23:16]};
                    psum_B_we_o    <= 8'hFF;
                    state          <= WRITE_B3;
                end

                WRITE_B3: begin
                    psum_B_addr_o  <= {word_idx[5:0], 2'b11};
                    psum_B_wdata_o <= {24'd0, lat_word[31:24]};
                    psum_B_we_o    <= 8'hFF;

                    word_idx <= word_idx + 1'b1;

                    if (beat_cnt == 4'd15) begin
                        if (burst_idx == 2'd3) begin
                            state <= DONE;
                        end else begin
                            burst_idx   <= burst_idx + 1'b1;
                            req_addr_o  <= lut_base_i + {24'd0, (burst_idx + 2'd1), 6'b000000};
                            req_len_o   <= 8'd15;
                            req_valid_o <= 1'b1;
                            beat_cnt    <= '0;
                            state       <= REQ_AR;
                        end
                    end else begin
                        beat_cnt <= beat_cnt + 1'b1;
                        rready_o <= 1'b1;
                        state    <= READ_WORD;
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
