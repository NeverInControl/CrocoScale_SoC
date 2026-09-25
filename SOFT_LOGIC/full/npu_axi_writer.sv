`timescale 1ns / 1ps

/* ===============================================================================================
 * File: SOFT_LOGIC/full/npu_axi_writer.sv
 * Module: npu_axi_writer
 * Project: CrocoScale SoC — High-Throughput Output Activation AXI4 Write Master
 *
 * Description:
 *   Drains 2,048 INT8 output activations (512 32-bit words) from the NPU pipeline
 *   to external AXI system memory across 32 bursts of 16 beats.
 *   Supports an additional pipeline stage when non-linear LUT activation is enabled.
 * =============================================================================================== */

module npu_axi_writer #(
    parameter int ARRAY_WIDTH      = 8,
    parameter int ACTIVATION_WIDTH = 8
) (
    input  wire        clk_i,
    input  wire        rst_n,
    input  wire        start_i,
    input  wire        lut_en_i,
    input  wire        pool_en_i,
    input  wire [31:0] out_base_i,

    // PSUM SRAM Read Interface
    output logic [7:0] drain_psum_addr_o,
    input  wire signed [ARRAY_WIDTH-1:0][ACTIVATION_WIDTH-1:0] npu_out_act_i,

    // AXI Write Address Channel (AW)
    output logic [31:0] awaddr_o,
    output logic [7:0]  awlen_o,
    output logic [2:0]  awsize_o,
    output logic [1:0]  awburst_o,
    output logic        awvalid_o,
    input  wire         awready_i,

    // AXI Write Data Channel (W)
    output logic [31:0] wdata_o,
    output logic [3:0]  wstrb_o,
    output logic        wlast_o,
    output logic        wvalid_o,
    input  wire         wready_i,

    // AXI Write Response Channel (B)
    input  wire [1:0]   bresp_i,
    input  wire         bvalid_i,
    output logic        bready_o,

    output logic        done_o
);

    typedef enum logic [3:0] {
        IDLE           = 4'd0,
        SEND_AW        = 4'd1,
        PIPE_0         = 4'd2,
        PIPE_1         = 4'd3,
        PIPE_2         = 4'd4,
        PIPE_3         = 4'd5,
        PIPE_4         = 4'd6,
        WRITE_W        = 4'd7,
        WAIT_B         = 4'd8,
        DONE           = 4'd9,
        WAIT_START_LOW = 4'd10,
        POOL_STREAM    = 4'd11,
        POOL_FLUSH     = 4'd12
    } state_t;

    state_t state;

    logic [5:0] drain_burst_idx; // 0 to 31 (unpooled) or 0 to 7 (pooled)
    logic [4:0] drain_w_beat;    // 0 to 15

    // MaxPool / Unpooled Shared Holding Registers
    logic [4:0] stream_cnt;
    logic signed [ARRAY_WIDTH-1:0][ACTIVATION_WIDTH-1:0] max_accum;
    logic [31:0] lat_upper;

    wire axi_w_stall   = wvalid_o && !wready_i;
    wire [5:0] next_req_idx = {1'b0, stream_cnt} + (lut_en_i ? 6'd5 : 6'd4);

    function automatic logic signed [ACTIVATION_WIDTH-1:0] signed_max(
        input logic signed [ACTIVATION_WIDTH-1:0] a,
        input logic signed [ACTIVATION_WIDTH-1:0] b
    );
        return ($signed(a) > $signed(b)) ? a : b;
    endfunction

    logic signed [ARRAY_WIDTH-1:0][ACTIVATION_WIDTH-1:0] next_max;
    always_comb begin
        for (int c = 0; c < ARRAY_WIDTH; c++) begin
            next_max[c] = signed_max(max_accum[c], npu_out_act_i[c]);
        end
    end

    wire [7:0] burst_base_p = {drain_burst_idx[4:0], 3'b000}; // burst_idx * 8

    assign awaddr_o  = out_base_i + {19'd0, drain_burst_idx, 6'b000000}; // burst_idx * 64
    assign awlen_o   = 8'd15;  // 16 beats = 64 bytes = 8 pixels
    assign awsize_o  = 3'b010; // 4 bytes
    assign awburst_o = 2'b01;  // INCR
    assign wstrb_o   = 4'hF;

    always_ff @(posedge clk_i) begin
        if (!rst_n) begin
            state             <= IDLE;
            drain_burst_idx   <= '0;
            drain_w_beat      <= '0;
            drain_psum_addr_o <= '0;
            stream_cnt        <= '0;
            max_accum         <= '0;
            lat_upper         <= '0;
            done_o            <= 1'b0;

            awvalid_o         <= 1'b0;
            wdata_o           <= '0;
            wlast_o           <= 1'b0;
            wvalid_o          <= 1'b0;
            bready_o          <= 1'b0;
        end else begin
            done_o <= 1'b0;

            if (awvalid_o && awready_i) begin
                awvalid_o <= 1'b0;
            end

            case (state)
                IDLE: begin
                    awvalid_o <= 1'b0;
                    wvalid_o  <= 1'b0;
                    bready_o  <= 1'b0;
                    if (start_i) begin
                        drain_burst_idx <= '0;
                        state           <= SEND_AW;
                    end
                end

                SEND_AW: begin
                    awvalid_o    <= 1'b1;
                    drain_w_beat <= '0;

                    if (awvalid_o && awready_i) begin
                        awvalid_o <= 1'b0;
                        if (pool_en_i) begin
                            stream_cnt        <= 5'd0;
                            drain_psum_addr_o <= {drain_burst_idx[2:0], 1'b0, 3'd0, 1'b0};
                        end else begin
                            drain_psum_addr_o <= {burst_base_p[7:3], 3'b000};
                        end
                        state <= PIPE_0;
                    end
                end

                PIPE_0: begin
                    if (pool_en_i) begin
                        drain_psum_addr_o <= {drain_burst_idx[2:0], 1'b0, 3'd0, 1'b1};
                    end
                    state <= PIPE_1;
                end

                PIPE_1: begin
                    if (pool_en_i) begin
                        drain_psum_addr_o <= {drain_burst_idx[2:0], 1'b1, 3'd0, 1'b0};
                    end else begin
                        drain_psum_addr_o <= {burst_base_p[7:3], 3'b001};
                    end
                    state <= PIPE_2;
                end

                PIPE_2: begin
                    if (pool_en_i) begin
                        drain_psum_addr_o <= {drain_burst_idx[2:0], 1'b1, 3'd0, 1'b1};
                        if (!lut_en_i) begin
                            state <= POOL_STREAM;
                        end else begin
                            state <= PIPE_3;
                        end
                    end else begin
                        state <= PIPE_3;
                    end
                end

                PIPE_3: begin
                    if (pool_en_i) begin
                        drain_psum_addr_o <= {drain_burst_idx[2:0], 1'b0, 3'd1, 1'b0};
                        state             <= POOL_STREAM;
                    end else begin
                        drain_psum_addr_o <= {burst_base_p[7:3], 3'b010};
                        state             <= PIPE_4;
                    end
                end

                PIPE_4: begin
                    lat_upper    <= {npu_out_act_i[7], npu_out_act_i[6], npu_out_act_i[5], npu_out_act_i[4]};
                    wdata_o      <= {npu_out_act_i[3], npu_out_act_i[2], npu_out_act_i[1], npu_out_act_i[0]};
                    wvalid_o     <= 1'b1;
                    wlast_o      <= 1'b0;
                    drain_w_beat <= '0;
                    state        <= WRITE_W;
                end

                WRITE_W: begin
                    if (wready_i && wvalid_o) begin
                        if (drain_w_beat == 5'd15) begin
                            wvalid_o <= 1'b0;
                            wlast_o  <= 1'b0;
                            bready_o <= 1'b1;
                            state    <= WAIT_B;
                        end else begin
                            drain_w_beat <= drain_w_beat + 1'b1;

                            if (drain_w_beat[0] == 1'b0) begin
                                wdata_o <= lat_upper;
                                if (drain_w_beat == 5'd14) begin
                                    wlast_o <= 1'b1;
                                end
                                if (drain_w_beat <= 5'd8) begin
                                    drain_psum_addr_o <= burst_base_p + 8'(drain_w_beat[4:1]) + 8'd3;
                                end
                            end else begin
                                lat_upper <= {npu_out_act_i[7], npu_out_act_i[6], npu_out_act_i[5], npu_out_act_i[4]};
                                wdata_o   <= {npu_out_act_i[3], npu_out_act_i[2], npu_out_act_i[1], npu_out_act_i[0]};
                            end
                        end
                    end
                end

                POOL_STREAM: begin
                    if (!axi_w_stall) begin
                        stream_cnt <= stream_cnt + 1'b1;

                        if (next_req_idx < 6'd32) begin
                            drain_psum_addr_o <= {drain_burst_idx[2:0], next_req_idx[1], next_req_idx[4:2], next_req_idx[0]};
                        end

                        case (stream_cnt[1:0])
                            2'd0: begin
                                max_accum <= npu_out_act_i;
                                if (stream_cnt > 5'd0) begin
                                    wdata_o      <= lat_upper;
                                    wvalid_o     <= 1'b1;
                                    drain_w_beat <= drain_w_beat + 1'b1;
                                end
                            end

                            2'd1: begin
                                max_accum <= next_max;
                                wvalid_o  <= 1'b0;
                            end

                            2'd2: begin
                                max_accum <= next_max;
                            end

                            2'd3: begin
                                wdata_o      <= {next_max[3], next_max[2], next_max[1], next_max[0]};
                                lat_upper    <= {next_max[7], next_max[6], next_max[5], next_max[4]};
                                wvalid_o     <= 1'b1;
                                drain_w_beat <= drain_w_beat + 1'b1;
                                if (stream_cnt == 5'd31) begin
                                    state <= POOL_FLUSH;
                                end
                            end
                        endcase
                    end
                end

                POOL_FLUSH: begin
                    if (wvalid_o && wready_i) begin
                        if (wlast_o) begin
                            wvalid_o <= 1'b0;
                            wlast_o  <= 1'b0;
                            bready_o <= 1'b1;
                            state    <= WAIT_B;
                        end else begin
                            wdata_o      <= lat_upper;
                            wvalid_o     <= 1'b1;
                            wlast_o      <= 1'b1;
                            drain_w_beat <= drain_w_beat + 1'b1;
                        end
                    end
                end

                WAIT_B: begin
                    if (bvalid_i && bready_o) begin
                        bready_o <= 1'b0;
                        if (drain_burst_idx == (pool_en_i ? 6'd7 : 6'd31)) begin
                            state <= DONE;
                        end else begin
                            drain_burst_idx <= drain_burst_idx + 1'b1;
                            state           <= SEND_AW;
                        end
                    end
                end

                DONE: begin
                    done_o <= 1'b1;
                    state  <= WAIT_START_LOW;
                end

                WAIT_START_LOW: begin
                    if (!start_i) begin
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule

