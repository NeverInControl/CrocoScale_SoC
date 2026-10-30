// =============================================================================
// File: SOFT_LOGIC/flex/npu_flex_axi_writer.sv
// Module: npu_flex_axi_writer
// Project: CrocoScale SoC — 8-Bank (4x2) Skewed Drain & AXI4 Burst Write Engine
//
// Description:
//   Two-phase high-throughput drain and writeback engine that outputs
//   requantized activations in the continuous untiled [C_out][ceil(H_out/4)][W_out][4]
//   tensor format at 100% AXI4 burst utilization:
//
//   1. Phase 1 — Skewed Drain & Optional 2x2 MaxPool into Activation SRAMs
//      (drain_cnt_i = 0..269):
//      - Uses the hardened NPU column skew pipeline (psum_skew_en = 1) so that
//        at every clock cycle, the 4 lower channels (c = 0..3) and 4 upper
//        channels (c = 4..7) are staggered by 1 cycle per channel.
//      - Unpooled mode (pool_en_i = 0): r_sub = 0..3 steps every cycle, so
//        each Even Bank (2*g) and Odd Bank (2*g + 1) receives row r_sub = g
//        from channel c = (t - g) % 4 via a 4:1 byte mux with zero collisions.
//      - Inline 2x2 MaxPool mode (pool_en_i = 1): sub = 0..3 (the 4 corners of
//        each 2x2 pool window) steps every cycle while max_accum[0..7] tracks
//        the running signed maximum. Exactly one channel pair (c, c+4) finishes
//        its 2x2 window (sub == 3) on each cycle and writes into Bank Group
//        G = r_sub via the same 4:1 byte mux.
//
//   2. Phase 2 — Contiguous AXI4 Burst Writeback (drain_cnt_i == 270):
//      - Reads all 4 vertical rows (r_sub = 0..3) in parallel from Even Banks
//        {6, 4, 2, 0} (for cout = 0..3) or Odd Banks {7, 5, 3, 1} (for
//        cout = 4..7) and streams 16-beat (unpooled) or 8-beat (pooled) AXI4
//        write bursts at 1 word per clock cycle (100% W-channel utilization).
//      - Automatically truncates horizontal burst lengths and masks out-of-bounds
//        vertical strips/sub-strip rows for arbitrary (img_h_i, img_w_i).
// =============================================================================

`timescale 1ns / 1ps

module npu_flex_axi_writer #(
    parameter int ARRAY_HEIGHT     = 8,
    parameter int ARRAY_WIDTH      = 8,
    parameter int ACTIVATION_WIDTH = 8,
    parameter int AXI_ADDR_WIDTH   = 32,
    parameter int AXI_DATA_WIDTH   = 32
) (
    input  wire                                          clk_i,
    input  wire                                          rst_n,

    // Sequencer State & Configuration Inputs
    input  wire  [2:0]                                   state_i,
    input  wire  [10:0]                                  drain_cnt_i,
    input  wire                                          lut_en_i,
    input  wire                                          pool_en_i,
    input  wire                                          pool_s1_en_i,
    input  wire  [31:0]                                  out_base_i,
    input  wire  [4:0]                                   tile_y_i,
    input  wire  [4:0]                                   tile_x_i,
    input  wire  [8:0]                                   img_h_i,
    input  wire  [8:0]                                   img_w_i,
    output logic                                         writer_done_o,

    // NPU Requantized Output & Activation SRAM Interfaces
    input  wire  [ARRAY_WIDTH-1:0][ACTIVATION_WIDTH-1:0]  out_act_i,
    input  wire  [ARRAY_HEIGHT-1:0][ACTIVATION_WIDTH-1:0] act_sram_rdata_i,
    output logic [ARRAY_HEIGHT-1:0]                       drain_act_we_o,
    output logic [ARRAY_HEIGHT-1:0][8:0]                  drain_act_addr_o,
    output logic [ARRAY_HEIGHT-1:0][ACTIVATION_WIDTH-1:0] drain_act_wdata_o,

    // AXI4 Write Master Interface
    output logic [AXI_ADDR_WIDTH-1:0]                    m_axi_awaddr,
    output logic [7:0]                                   m_axi_awlen,
    output logic                                         m_axi_awvalid,
    input  wire                                          m_axi_awready,

    output logic [AXI_DATA_WIDTH-1:0]                    m_axi_wdata,
    output logic [(AXI_DATA_WIDTH/8)-1:0]                m_axi_wstrb,
    output logic                                         m_axi_wlast,
    output logic                                         m_axi_wvalid,
    input  wire                                          m_axi_wready,

    input  wire  [1:0]                                   m_axi_bresp,
    input  wire                                          m_axi_bvalid,
    output logic                                         m_axi_bready
);

    localparam logic [2:0] SEQ_DRAIN = 3'd4;

    wire unused_ok = &{1'b0, m_axi_bresp};

    function automatic logic signed [7:0] signed_max8(
        input logic signed [7:0] a,
        input logic signed [7:0] b
    );
        signed_max8 = ($signed(a) > $signed(b)) ? a : b;
    endfunction

    // =========================================================================
    // Phase 1: Skewed Drain & Optional 2x2 MaxPool into 8 Activation SRAM Banks
    // =========================================================================
    wire [10:0] pipe_lat       = lut_en_i ? 11'd6 : 11'd5;
    wire [10:0] base_t         = drain_cnt_i - pipe_lat;
    wire [10:0] drain_p1_limit = pool_s1_en_i ? 11'd1038 : 11'd270;
    wire        any_pool       = pool_en_i || pool_s1_en_i;

    logic [10:0]       full_idx   [ARRAY_WIDTH];
    logic              idx_valid  [ARRAY_WIDTH];
    logic signed [7:0] max_accum  [ARRAY_WIDTH];
    logic signed [7:0] pooled_val [ARRAY_WIDTH];

    for (genvar gc = 0; gc < ARRAY_WIDTH; gc++) begin : gen_ch_pool
        assign full_idx[gc]   = base_t - 11'(gc);
        assign idx_valid[gc]  = (state_i == SEQ_DRAIN) && (drain_cnt_i < drain_p1_limit) &&
                                (pool_s1_en_i ? !full_idx[gc][10] : (full_idx[gc][10:8] == 3'b000));
        assign pooled_val[gc] = (full_idx[gc][1:0] == 2'd0) ? $signed(out_act_i[gc])
                                                            : signed_max8(max_accum[gc], $signed(out_act_i[gc]));

        always_ff @(posedge clk_i) begin
            if (!rst_n) begin
                max_accum[gc] <= 8'sd0;
            end else if (idx_valid[gc]) begin
                max_accum[gc] <= pooled_val[gc];
            end
        end
    end

    logic [7:0]      p1_act_we;
    logic [7:0][8:0] p1_act_addr;
    logic [7:0][7:0] p1_act_wdata;

    for (genvar gg = 0; gg < 4; gg++) begin : gen_sram_transpose
        wire [1:0]  sel_c       = any_pool ? (base_t[1:0] + 2'd1) : (base_t[1:0] - 2'(gg));
        wire [2:0]  ch_even     = {1'b0, sel_c};
        wire [2:0]  ch_odd      = {1'b1, sel_c};

        wire [10:0] idx_even    = full_idx[ch_even];
        wire [10:0] idx_odd     = full_idx[ch_odd];
        wire        idx_even_ok = pool_s1_en_i ? !idx_even[10] : (idx_even[10:8] == 3'b000);
        wire        idx_odd_ok  = pool_s1_en_i ? !idx_odd[10]  : (idx_odd[10:8] == 3'b000);

        assign p1_act_we[2*gg] = (state_i == SEQ_DRAIN) && (drain_cnt_i < drain_p1_limit) &&
                                 idx_even_ok && (!any_pool || (idx_even[3:2] == 2'(gg)));

        assign p1_act_we[2*gg + 1] = (state_i == SEQ_DRAIN) && (drain_cnt_i < drain_p1_limit) &&
                                     idx_odd_ok && (!any_pool || (idx_odd[3:2] == 2'(gg)));

        assign p1_act_addr[2*gg] = pool_s1_en_i ? {1'b0,  idx_even[9:8], sel_c, idx_even[7:4]} :
                                   pool_en_i    ? {2'b00, idx_even[7],   sel_c, idx_even[6:4]} :
                                                  {1'b0,  idx_even[7:6], sel_c, idx_even[5:2]};

        assign p1_act_addr[2*gg + 1] = pool_s1_en_i ? {1'b0,  idx_odd[9:8], sel_c, idx_odd[7:4]} :
                                       pool_en_i    ? {2'b00, idx_odd[7],   sel_c, idx_odd[6:4]} :
                                                      {1'b0,  idx_odd[7:6], sel_c, idx_odd[5:2]};

        assign p1_act_wdata[2*gg]     = any_pool ? pooled_val[ch_even] : out_act_i[ch_even];
        assign p1_act_wdata[2*gg + 1] = any_pool ? pooled_val[ch_odd]  : out_act_i[ch_odd];
    end

    // =========================================================================
    // Phase 2: Contiguous AXI4 Burst Writeback to [C_out][ceil(H_out/4)][W_out][4]
    // =========================================================================
    typedef enum logic [2:0] {
        WB_IDLE        = 3'd0,
        WB_START_BURST = 3'd1,
        WB_STREAM      = 3'd2,
        WB_WAIT_B      = 3'd3,
        WB_DONE        = 3'd4
    } wb_state_t;

    wb_state_t wb_state;

    wire [8:0]  h_out            = pool_en_i ? {1'b0, img_h_i[8:1]} : img_h_i;
    wire [8:0]  w_out            = pool_en_i ? {1'b0, img_w_i[8:1]} : img_w_i;
    wire [3:0]  w_out_shift      = (w_out <= 9'd16)  ? 4'd4 :
                                   (w_out <= 9'd32)  ? 4'd5 :
                                   (w_out <= 9'd64)  ? 4'd6 :
                                   (w_out <= 9'd128) ? 4'd7 :
                                   (w_out <= 9'd256) ? 4'd8 : 4'd9;
    wire [9:0]  tile_x0_out      = pool_en_i ? {2'b00, tile_x_i, 3'b000} : {1'b0, tile_x_i, 4'b0000};
    wire [9:0]  tile_y0_out      = pool_en_i ? {2'b00, tile_y_i, 3'b000} : {1'b0, tile_y_i, 4'b0000};
    wire [4:0]  tile_w_max       = pool_en_i ? 5'd8 : 5'd16;
    wire [1:0]  max_s_rel        = pool_en_i ? 2'd1 : 2'd3;

    wire [9:0]  rem_w            = ({1'b0, w_out} > tile_x0_out) ? ({1'b0, w_out} - tile_x0_out) : 10'd0;
    wire [4:0]  valid_w_beats    = (rem_w >= {5'd0, tile_w_max}) ? tile_w_max : rem_w[4:0];
    wire [7:0]  wb_awlen         = {3'd0, valid_w_beats - 5'd1};

    wire [7:0]  num_strips_y_out = 8'(({1'b0, h_out} + 10'd3) >> 2);
    wire [31:0] strip_stride_out = 32'd4 << w_out_shift;
    wire [16:0] ch_words_out     = 17'(num_strips_y_out) << w_out_shift;
    wire [31:0] ch_stride_out    = {13'd0, ch_words_out, 2'b00};

    wire [6:0]  tile_strip_y0    = pool_en_i ? {1'b0, tile_y_i, 1'b0} : {tile_y_i, 2'b00};
    wire [15:0] ty_words_out     = 16'(tile_strip_y0) << w_out_shift;
    wire [31:0] ty_bytes_out     = {14'd0, ty_words_out, 2'b00};
    wire [31:0] tx_bytes_out     = {20'd0, tile_x0_out, 2'b00};
    wire [31:0] init_wb_addr     = out_base_i + ty_bytes_out + tx_bytes_out;

    logic [2:0]  wb_cout;
    logic [1:0]  wb_s_rel;
    logic [31:0] ch_wb_addr;
    logic [31:0] strip_wb_addr;

    logic        aw_pending;
    logic [4:0]  rd_tx;
    logic [4:0]  w_beat_cnt;
    logic [2:0]  rd_pipe_val;
    logic [2:0]  buf_used_cnt;

    logic [31:0] wb_fifo [4];
    logic [1:0]  fifo_wr_ptr;
    logic [1:0]  fifo_rd_ptr;
    logic [2:0]  fifo_cnt;

    logic [3:0] strip_valid_vec;
    always_comb begin
        for (int s = 0; s < 4; s++) begin
            logic [9:0] s_gy0;
            s_gy0 = tile_y0_out + {4'd0, 2'(s), 2'b00};
            strip_valid_vec[s] = (valid_w_beats != 5'd0) && (2'(s) <= max_s_rel) &&
                                 (s_gy0 < {1'b0, h_out});
        end
    end

    wire [9:0] cur_out_gy0 = tile_y0_out + {4'd0, wb_s_rel, 2'b00};
    wire [3:0] out_row_in_bounds;
    assign out_row_in_bounds[0] = (cur_out_gy0 + 10'd0) < {1'b0, h_out};
    assign out_row_in_bounds[1] = (cur_out_gy0 + 10'd1) < {1'b0, h_out};
    assign out_row_in_bounds[2] = (cur_out_gy0 + 10'd2) < {1'b0, h_out};
    assign out_row_in_bounds[3] = (cur_out_gy0 + 10'd3) < {1'b0, h_out};

    wire [7:0] raw_b0 = wb_cout[2] ? act_sram_rdata_i[1] : act_sram_rdata_i[0];
    wire [7:0] raw_b1 = wb_cout[2] ? act_sram_rdata_i[3] : act_sram_rdata_i[2];
    wire [7:0] raw_b2 = wb_cout[2] ? act_sram_rdata_i[5] : act_sram_rdata_i[4];
    wire [7:0] raw_b3 = wb_cout[2] ? act_sram_rdata_i[7] : act_sram_rdata_i[6];

    wire [7:0] masked_b0 = out_row_in_bounds[0] ? raw_b0 : 8'd0;
    wire [7:0] masked_b1 = out_row_in_bounds[1] ? raw_b1 : 8'd0;
    wire [7:0] masked_b2 = out_row_in_bounds[2] ? raw_b2 : 8'd0;
    wire [7:0] masked_b3 = out_row_in_bounds[3] ? raw_b3 : 8'd0;
    wire [31:0] sram_packed_word = {masked_b3, masked_b2, masked_b1, masked_b0};

    wire [8:0] wb_sram_raddr = pool_en_i ? {2'b00, wb_s_rel[0], wb_cout[1:0], rd_tx[2:0]}
                                         : {1'b0,  wb_s_rel[1:0], wb_cout[1:0], rd_tx[3:0]};

    wire w_pop     = (wb_state == WB_STREAM) && (fifo_cnt != 3'd0) && m_axi_wready;
    wire can_issue = (buf_used_cnt < 3'd4) || w_pop;
    wire rd_issue  = (wb_state == WB_STREAM) && (rd_tx < valid_w_beats) && can_issue;
    wire fifo_push = (wb_state == WB_STREAM) && rd_pipe_val[2];

    // Multiplex Activation SRAM Ports between Phase 1 (Write) and Phase 2 (Read)
    always_comb begin
        for (int b = 0; b < ARRAY_HEIGHT; b++) begin
            if (drain_cnt_i < drain_p1_limit) begin
                drain_act_we_o[b]    = p1_act_we[b];
                drain_act_addr_o[b]  = p1_act_addr[b];
                drain_act_wdata_o[b] = p1_act_wdata[b];
            end else begin
                drain_act_we_o[b]    = 1'b0;
                drain_act_addr_o[b]  = wb_sram_raddr;
                drain_act_wdata_o[b] = 8'd0;
            end
        end
    end

    // AXI4 Write Master Combinational Outputs
    assign m_axi_awaddr  = strip_wb_addr;
    assign m_axi_awlen   = wb_awlen;
    assign m_axi_awvalid = (wb_state == WB_STREAM) && aw_pending;

    assign m_axi_wdata   = wb_fifo[fifo_rd_ptr];
    assign m_axi_wstrb   = 4'b1111;
    assign m_axi_wlast   = (w_beat_cnt == (valid_w_beats - 5'd1));
    assign m_axi_wvalid  = (wb_state == WB_STREAM) && (fifo_cnt != 3'd0);

    assign m_axi_bready  = (wb_state == WB_WAIT_B);
    assign writer_done_o = (wb_state == WB_DONE);

    always_ff @(posedge clk_i) begin
        if (!rst_n || state_i != SEQ_DRAIN) begin
            wb_state      <= WB_IDLE;
            wb_cout       <= 3'd0;
            wb_s_rel      <= 2'd0;
            ch_wb_addr    <= 32'd0;
            strip_wb_addr <= 32'd0;
            aw_pending    <= 1'b0;
            rd_tx         <= 5'd0;
            w_beat_cnt    <= 5'd0;
            rd_pipe_val   <= 3'b000;
            buf_used_cnt  <= 3'd0;
            fifo_wr_ptr   <= 2'd0;
            fifo_rd_ptr   <= 2'd0;
            fifo_cnt      <= 3'd0;
        end else begin
            case (wb_state)
                WB_IDLE: begin
                    if (drain_cnt_i == (drain_p1_limit - 11'd1)) begin
                        wb_cout       <= 3'd0;
                        wb_s_rel      <= 2'd0;
                        ch_wb_addr    <= init_wb_addr;
                        strip_wb_addr <= init_wb_addr;
                        if (strip_valid_vec[0]) begin
                            wb_state <= WB_START_BURST;
                        end else begin
                            wb_state <= WB_DONE;
                        end
                    end
                end

                WB_START_BURST: begin
                    aw_pending   <= 1'b1;
                    rd_tx        <= 5'd0;
                    w_beat_cnt   <= 5'd0;
                    rd_pipe_val  <= 3'b000;
                    buf_used_cnt <= 3'd0;
                    fifo_wr_ptr  <= 2'd0;
                    fifo_rd_ptr  <= 2'd0;
                    fifo_cnt     <= 3'd0;
                    wb_state     <= WB_STREAM;
                end

                WB_STREAM: begin
                    if (m_axi_awvalid && m_axi_awready) begin
                        aw_pending <= 1'b0;
                    end

                    if (rd_issue) begin
                        rd_tx <= rd_tx + 5'd1;
                    end

                    rd_pipe_val <= {rd_pipe_val[1:0], rd_issue};

                    if (fifo_push) begin
                        wb_fifo[fifo_wr_ptr] <= sram_packed_word;
                        fifo_wr_ptr          <= fifo_wr_ptr + 2'd1;
                    end

                    if (w_pop) begin
                        fifo_rd_ptr <= fifo_rd_ptr + 2'd1;
                        w_beat_cnt  <= w_beat_cnt + 5'd1;
                    end

                    fifo_cnt     <= fifo_cnt + (fifo_push ? 3'd1 : 3'd0) - (w_pop ? 3'd1 : 3'd0);
                    buf_used_cnt <= buf_used_cnt + (rd_issue ? 3'd1 : 3'd0) - (w_pop ? 3'd1 : 3'd0);

                    if (w_pop && (w_beat_cnt == (valid_w_beats - 5'd1))) begin
                        wb_state <= WB_WAIT_B;
                    end
                end

                WB_WAIT_B: begin
                    if (m_axi_bvalid && m_axi_bready) begin
                        if ((wb_s_rel < max_s_rel) && strip_valid_vec[wb_s_rel + 2'd1]) begin
                            wb_s_rel      <= wb_s_rel + 2'd1;
                            strip_wb_addr <= strip_wb_addr + strip_stride_out;
                            wb_state      <= WB_START_BURST;
                        end else if (wb_cout < 3'd7) begin
                            wb_cout       <= wb_cout + 3'd1;
                            wb_s_rel      <= 2'd0;
                            ch_wb_addr    <= ch_wb_addr + ch_stride_out;
                            strip_wb_addr <= ch_wb_addr + ch_stride_out;
                            wb_state      <= WB_START_BURST;
                        end else begin
                            wb_state      <= WB_DONE;
                        end
                    end
                end

                WB_DONE: begin
                    wb_state <= WB_IDLE;
                end

                default: wb_state <= WB_IDLE;
            endcase
        end
    end

endmodule

