`timescale 1ns / 1ps

/* ===============================================================================================
 * File: SOFT_LOGIC/npu_dma_weight_fetcher.sv
 * Module: npu_dma_weight_fetcher
 * Project: CrocoScale SoC — Dual-Mode Systolic Weight Fetch DMA Engine
 *
 * Description:
 *   Fetches weight slices from system AXI memory during active compute via npu_axi_read_master:
 *   - 3x3 Mode: 16 beats (64 bytes = 8x8 INT8 weights)
 *   - 1x1 Mode: 8 beats (32 bytes = 4x8 INT8 weights, rows 4..7 zero-padded)
 *   Unpacks and streams weights directly into the systolic array shadow registers.
 * =============================================================================================== */

module npu_dma_weight_fetcher #(
    parameter int ARRAY_HEIGHT   = 8,
    parameter int WEIGHT_WIDTH   = 8,
    parameter int AXI_ADDR_WIDTH = 32,
    parameter int AXI_DATA_WIDTH = 32
) (
    input  wire                                              clk_i,
    input  wire                                              rst_n,
    input  wire                                              start_i,
    input  wire                                              mode_1x1_i,
    input  wire [7:0]                                        fetch_pass_idx_i,
    input  wire [AXI_ADDR_WIDTH-1:0]                         weight_base_i,

    // Command Interface to npu_axi_read_master
    output logic                                             req_valid_o,
    output logic [AXI_ADDR_WIDTH-1:0]                        req_addr_o,
    output logic [7:0]                                       req_len_o,
    input  wire                                              req_ready_i,

    // Data Response Stream from npu_axi_read_master
    input  wire [AXI_DATA_WIDTH-1:0]                         rdata_i,
    input  wire                                              rvalid_i,
    input  wire                                              rlast_i,
    output logic                                             rready_o,

    // Hardware Outputs to Systolic Array Shadow Registers
    output logic signed [ARRAY_HEIGHT-1:0][WEIGHT_WIDTH-1:0] weight_shift_in_o,
    output logic [1:0]                                       weight_shift_en_o,
    output logic                                             done_o
);

    typedef enum logic [1:0] {
        IDLE    = 2'd0,
        REQ_AR  = 2'd1,
        READ_R  = 2'd2,
        DONE    = 2'd3
    } state_t;

    state_t state;
    logic [4:0] beat_cnt;
    logic [31:0] lat_lower_rows;

    wire beat_valid = (state == READ_R) && (rvalid_i && rready_o);

    // Dynamic shift enable and data multiplexing
    always_comb begin
        if (mode_1x1_i) begin
            // 1x1 Mode: 1 beat = 1 column of 4 active weights (rows 4..7 are zero)
            weight_shift_en_o[0] = beat_valid;
            weight_shift_en_o[1] = beat_valid;
            weight_shift_in_o[0] = $signed(rdata_i[7:0]);
            weight_shift_in_o[1] = $signed(rdata_i[15:8]);
            weight_shift_in_o[2] = $signed(rdata_i[23:16]);
            weight_shift_in_o[3] = $signed(rdata_i[31:24]);
            weight_shift_in_o[4] = 8'sd0;
            weight_shift_in_o[5] = 8'sd0;
            weight_shift_in_o[6] = 8'sd0;
            weight_shift_in_o[7] = 8'sd0;
        end else begin
            // 3x3 Mode: 2 beats = 1 column of 8 weights (Beat 0: rows 0..3, Beat 1: rows 4..7)
            weight_shift_en_o[0] = beat_valid && beat_cnt[0];
            weight_shift_en_o[1] = beat_valid && beat_cnt[0];
            weight_shift_in_o[0] = $signed(lat_lower_rows[7:0]);
            weight_shift_in_o[1] = $signed(lat_lower_rows[15:8]);
            weight_shift_in_o[2] = $signed(lat_lower_rows[23:16]);
            weight_shift_in_o[3] = $signed(lat_lower_rows[31:24]);
            weight_shift_in_o[4] = $signed(rdata_i[7:0]);
            weight_shift_in_o[5] = $signed(rdata_i[15:8]);
            weight_shift_in_o[6] = $signed(rdata_i[23:16]);
            weight_shift_in_o[7] = $signed(rdata_i[31:24]);
        end
    end

    always_ff @(posedge clk_i or negedge rst_n) begin
        if (!rst_n) begin
            state          <= IDLE;
            req_valid_o    <= 1'b0;
            req_addr_o     <= '0;
            req_len_o      <= '0;
            rready_o       <= 1'b0;
            done_o         <= 1'b0;
            beat_cnt       <= '0;
            lat_lower_rows <= '0;
        end else begin
            done_o <= 1'b0;

            case (state)
                IDLE: begin
                    req_valid_o <= 1'b0;
                    rready_o    <= 1'b0;
                    if (start_i) begin
                        if (mode_1x1_i) begin
                            req_addr_o <= weight_base_i + {19'd0, fetch_pass_idx_i, 5'b00000}; // pass * 32
                            req_len_o  <= 8'd7;                                                 // 8 beats
                        end else begin
                            req_addr_o <= weight_base_i + {18'd0, fetch_pass_idx_i, 6'b000000}; // pass * 64
                            req_len_o  <= 8'd15;                                                // 16 beats
                        end
                        req_valid_o <= 1'b1;
                        beat_cnt    <= '0;
                        state       <= REQ_AR;
                    end
                end

                REQ_AR: begin
                    if (req_valid_o && req_ready_i) begin
                        req_valid_o <= 1'b0;
                        rready_o    <= 1'b1;
                        state       <= READ_R;
                    end
                end

                READ_R: begin
                    if (rvalid_i && rready_o) begin
                        if (!mode_1x1_i && !beat_cnt[0]) begin
                            lat_lower_rows <= rdata_i;
                        end

                        if (rlast_i || (mode_1x1_i ? (beat_cnt == 5'd7) : (beat_cnt == 5'd15))) begin
                            rready_o <= 1'b0;
                            state    <= DONE;
                        end else begin
                            beat_cnt <= beat_cnt + 1'b1;
                        end
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
