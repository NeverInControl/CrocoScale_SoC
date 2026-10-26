// =============================================================================
// File: SOFT_LOGIC/flex/npu_flex_axi_reader.sv
// Module: npu_flex_axi_reader
// Project: CrocoScale SoC — 8-Bank (4x2) AXI4 Read Engine & Staging Controller
//
// Description:
//   Fetches biases, quantizer configurations, systolic weights, non-linear LUT
//   tables, and untiled [C][ceil(H/4)][W][4] 4-row vertical activation strips
//   over the AXI4 Read Master interface.
//
//   Features:
//   - Arbitrary CNN feature map dimensions (img_h_i x img_w_i x cfg_cin_i),
//     including non-multiples of 16 and non-multiples of 4.
//   - Dynamic outer-border and out-of-bounds zero padding injection (top,
//     bottom, left, right, and partial-tile boundaries), eliminating zero
//     padding storage in RAM.
//   - Direct per-bank byte-lane routing into 8 independent circular staging
//     FIFOs with zero-latency SRAM bypass when a target bank is not being
//     read by the systolic array.
//   - Zero-FF weight streaming exploiting the 8-bit split weight shift enables
//     (rows 0..3 on beats 0..7, rows 4..7 on beats 8..15).
// =============================================================================

`timescale 1ns / 1ps

module npu_flex_axi_reader #(
    parameter int ARRAY_HEIGHT     = 8,
    parameter int ARRAY_WIDTH      = 8,
    parameter int ACTIVATION_WIDTH = 8,
    parameter int WEIGHT_WIDTH     = 8,
    parameter int PSUM_WIDTH       = 32,
    parameter int AXI_ADDR_WIDTH   = 32,
    parameter int AXI_DATA_WIDTH   = 32,
    parameter int FIFO_DEPTH       = 4
) (
    input  wire                                          clk_i,
    input  wire                                          rst_n,

    // Sequencer Synchronization Interface
    input  wire                                          start_i,
    input  wire                                          start_drain_i,
    input  wire                                          mode_1x1_i,
    input  wire                                          lut_en_i,
    input  wire [2:0]                                    state_i,
    input  wire [7:0]                                    pass_cnt_i,
    input  wire [8:0]                                    k_cnt_i,
    input  wire [7:0]                                    total_passes_i,
    input  wire                                          preload_done_i,
    input  wire                                          pass_advance_i,
    input  wire                                          enter_lut_load_i,
    input  wire [8:0]                                    drain_cnt_i,
    input  wire [7:0]                                    bank_read_used_i,

    output logic                                         dma_pass_ready_o,
    output logic [7:0]                                   dma_channel_to_load_o,
    output logic [7:0][5:0]                              dma_bank_ptr_o,

    // Memory Base Addresses & Arbitrary Layer/Tile Geometry
    input  wire [AXI_ADDR_WIDTH-1:0]                     act_base_i,
    input  wire [AXI_ADDR_WIDTH-1:0]                     weight_base_i,
    input  wire [AXI_ADDR_WIDTH-1:0]                     bias_base_i,
    input  wire [AXI_ADDR_WIDTH-1:0]                     quant_base_i,
    input  wire [AXI_ADDR_WIDTH-1:0]                     lut_base_i,
    input  wire [3:0]                                    tile_y_i,
    input  wire [3:0]                                    tile_x_i,
    input  wire [7:0]                                    img_h_i,
    input  wire [7:0]                                    img_w_i,
    input  wire [7:0]                                    cfg_cin_i,

    // AXI4 Read Master Interface
    output logic [AXI_ADDR_WIDTH-1:0]                    m_axi_araddr,
    output logic [7:0]                                   m_axi_arlen,
    output logic                                         m_axi_arvalid,
    input  wire                                          m_axi_arready,
    input  wire  [AXI_DATA_WIDTH-1:0]                    m_axi_rdata,
    input  wire  [1:0]                                   m_axi_rresp,
    input  wire                                          m_axi_rlast,
    input  wire                                          m_axi_rvalid,
    output logic                                         m_axi_rready,

    // NPU Activation SRAM Write Interface (8 Banks)
    output logic [7:0]                                   dma_act_we_o,
    output logic [7:0][8:0]                              dma_act_addr_o,
    output logic [7:0][ACTIVATION_WIDTH-1:0]             dma_act_wdata_o,

    // NPU Weight, Bias, Quant & LUT Streaming Outputs
    output logic signed [ARRAY_HEIGHT-1:0][WEIGHT_WIDTH-1:0] weight_shift_in_o,
    output logic [ARRAY_HEIGHT-1:0]                      weight_shift_en_o,
    output logic [29:0]                                  quant_shift_in_o,
    output logic                                         quant_shift_en_o,
    output logic signed [PSUM_WIDTH-1:0]                 bias_wdata_o,
    output logic [ARRAY_WIDTH-1:0]                       bias_we_o,
    output logic [7:0]                                   lut_wdata_o,
    output logic                                         lut_we_o
);

    localparam logic [2:0] SEQ_IDLE     = 3'd0;
    localparam logic [2:0] SEQ_PRELOAD  = 3'd1;
    localparam logic [2:0] SEQ_COMPUTE  = 3'd2;
    localparam logic [2:0] SEQ_LUT_LOAD = 3'd3;

    localparam int PTR_W = (FIFO_DEPTH <= 2) ? 1 : $clog2(FIFO_DEPTH);
    localparam int CNT_W = $clog2(FIFO_DEPTH + 1);

    typedef enum logic [3:0] {
        RD_IDLE      = 4'd0,
        RD_BIAS_AR   = 4'd1,
        RD_BIAS_R    = 4'd2,
        RD_QUANT_AR  = 4'd3,
        RD_QUANT_R   = 4'd4,
        RD_ACT_AR    = 4'd5,
        RD_ACT_R     = 4'd6,
        RD_WEIGHT_AR = 4'd7,
        RD_WEIGHT_R  = 4'd8,
        RD_WAIT_FIFO = 4'd9,
        RD_PASS_DONE = 4'd10,
        RD_LUT_AR    = 4'd11,
        RD_LUT_R     = 4'd12
    } rd_state_t;

    rd_state_t rd_state;

    // -------------------------------------------------------------------------
    // Power-of-Two Strip Stride Address Pitches & Boundary Windows
    // -------------------------------------------------------------------------
    wire        has_left_pad    = !mode_1x1_i && (tile_x_i == 4'd0);
    wire [3:0]  w_shift         = (img_w_i <= 8'd16)  ? 4'd4 :
                                  (img_w_i <= 8'd32)  ? 4'd5 :
                                  (img_w_i <= 8'd64)  ? 4'd6 :
                                  (img_w_i <= 8'd128) ? 4'd7 : 4'd8;
    wire [6:0]  num_strips_y    = 7'(({1'b0, img_h_i} + 9'd3) >> 2);
    wire [31:0] strip_stride    = 32'd4 << w_shift;
    wire [14:0] ch_words        = 15'(num_strips_y) << w_shift;
    wire [31:0] ch_stride       = {15'd0, ch_words, 2'b00};
    wire [11:0] ty_words        = 12'(tile_y_i) << w_shift;
    wire [31:0] ty_bytes        = {16'd0, ty_words, 4'b0000};
    wire [31:0] gx_start_3x3    = (tile_x_i == 4'd0) ? 32'd0 : {22'd0, tile_x_i - 4'd1, 6'b111100};
    wire [31:0] gx_start_1x1    = {22'd0, tile_x_i, 6'b000000};
    wire [31:0] init_strip_addr = act_base_i + ty_bytes +
                                  (mode_1x1_i ? gx_start_1x1 : (gx_start_3x3 - strip_stride));

    // Horizontal valid beat limit for arbitrary img_w_i
    wire [8:0]  tile_x0         = {1'b0, tile_x_i, 4'b0000};
    wire [8:0]  max_gx_p1       = {1'b0, img_w_i} + {8'd0, !mode_1x1_i};
    wire [4:0]  max_beats       = mode_1x1_i ? 5'd16 : 5'd18;
    wire [4:0]  end_beat_x      = (tile_x0 >= max_gx_p1) ? 5'd0 :
                                  (((max_gx_p1 - tile_x0) >= {4'd0, max_beats}) ? max_beats : 5'(max_gx_p1 - tile_x0));
    wire [4:0]  valid_axi_beats = (end_beat_x > {4'd0, has_left_pad}) ?
                                  (end_beat_x - {4'd0, has_left_pad}) : 5'd0;
    wire [7:0]  strip_arlen     = {3'd0, valid_axi_beats - 5'd1};

    // Vertical valid strip flags for arbitrary img_h_i across s = 0..5
    wire [8:0]  tile_y0         = {1'b0, tile_y_i, 4'b0000};
    logic [5:0] strip_is_zero;

    always_comb begin
        strip_is_zero[0] = (valid_axi_beats == 5'd0) || (tile_y_i == 4'd0) ||
                           ((tile_y0 - 9'd1) >= {1'b0, img_h_i});
        for (int s = 1; s < 6; s++) begin
            logic [8:0] s_gy0;
            s_gy0 = tile_y0 + {4'd0, 3'(s - 1), 2'b00};
            strip_is_zero[s] = (valid_axi_beats == 5'd0) || (s_gy0 >= {1'b0, img_h_i});
        end
    end

    logic [31:0] weight_curr_addr;
    logic [31:0] ch_base_addr;
    logic [31:0] strip_addr;

    logic [2:0]  cur_strip;
    logic [4:0]  beat_idx;
    logic [1:0]  c_sub_1x1;
    logic [1:0]  byte_sub_1x1;

    logic [7:0]  dma_channel_reg;
    logic [3:0]  dma_mod9_cnt;
    logic [7:0]  dma_next_ch;
    logic        has_act_to_load;

    wire [3:0]   next_mod_w    = (dma_mod9_cnt == 4'd8) ? 4'd0 : (dma_mod9_cnt + 4'd1);
    wire [7:0]   next_ch_val_w = (dma_mod9_cnt == 4'd7) ? dma_next_ch : (dma_next_ch + 8'd1);

    assign dma_channel_to_load_o = dma_channel_reg;

    // -------------------------------------------------------------------------
    // Dynamic Border Zero Detection & Strip Byte-Lane Routing
    // -------------------------------------------------------------------------
    wire        is_zero_strip  = strip_is_zero[cur_strip];
    wire        is_zero_x      = (beat_idx == 5'd0 && has_left_pad) || (beat_idx >= end_beat_x);
    wire        is_zero_beat   = is_zero_strip || is_zero_x;

    // Sub-strip row bounds for non-multiple-of-4 img_h_i
    wire [8:0]  cur_strip_gy0  = tile_y0 + {4'd0, cur_strip - 3'd1, 2'b00};
    wire [3:0]  row_in_bounds;
    assign row_in_bounds[0]    = (cur_strip == 3'd0) || ((cur_strip_gy0 + 9'd3) < {1'b0, img_h_i});
    assign row_in_bounds[1]    = (cur_strip_gy0 + 9'd0) < {1'b0, img_h_i};
    assign row_in_bounds[2]    = (cur_strip_gy0 + 9'd1) < {1'b0, img_h_i};
    assign row_in_bounds[3]    = (cur_strip_gy0 + 9'd2) < {1'b0, img_h_i};

    // In [C][ceil(H/4)][W][4]:
    //   word[31:24] -> gy%4 == 3 -> ly%4 == 0 in 3x3 (G=0: B0, B1) / ly%4 == 3 in 1x1
    //   word[7:0]   -> gy%4 == 0 -> ly%4 == 1 in 3x3 (G=1: B2, B3) / ly%4 == 0 in 1x1
    //   word[15:8]  -> gy%4 == 1 -> ly%4 == 2 in 3x3 (G=2: B4, B5) / ly%4 == 1 in 1x1
    //   word[23:16] -> gy%4 == 2 -> ly%4 == 3 in 3x3 (G=3: B6, B7) / ly%4 == 2 in 1x1
    wire [7:0] lane_byte [4];
    assign lane_byte[0] = (!is_zero_beat && row_in_bounds[0]) ? m_axi_rdata[31:24] : 8'd0;
    assign lane_byte[1] = (!is_zero_beat && row_in_bounds[1]) ? m_axi_rdata[7:0]   : 8'd0;
    assign lane_byte[2] = (!is_zero_beat && row_in_bounds[2]) ? m_axi_rdata[15:8]  : 8'd0;
    assign lane_byte[3] = (!is_zero_beat && row_in_bounds[3]) ? m_axi_rdata[23:16] : 8'd0;

    wire [3:0] lane_mask;
    assign lane_mask[0] = (cur_strip != 3'd5);
    assign lane_mask[1] = (cur_strip != 3'd0);
    assign lane_mask[2] = (cur_strip != 3'd0) && (cur_strip != 3'd5);
    assign lane_mask[3] = (cur_strip != 3'd0) && (cur_strip != 3'd5);

    wire half_sel = (beat_idx >= 5'd9);

    // 1x1 Half-Array Ping-Pong Unpacking Signals
    wire       preload_pong_1x1 = (state_i == SEQ_PRELOAD) ? 1'b0 : ~pass_cnt_i[0];
    wire [1:0] s_rel_1x1        = 2'(cur_strip - 3'd1);
    wire [8:0] addr_1x1_w       = {1'b0, s_rel_1x1, byte_sub_1x1, beat_idx[3:0]};
    logic [7:0] wdata_1x1;

    always_comb begin
        case (byte_sub_1x1)
            2'd0: wdata_1x1 = lane_byte[1];
            2'd1: wdata_1x1 = lane_byte[2];
            2'd2: wdata_1x1 = lane_byte[3];
            2'd3: wdata_1x1 = lane_byte[0];
        endcase
    end

    // -------------------------------------------------------------------------
    // Per-Bank Circular Staging FIFOs & Zero-Latency SRAM Bypass
    // -------------------------------------------------------------------------
    logic [7:0]       fifo_mem [8][FIFO_DEPTH];
    logic [PTR_W-1:0] wr_ptr   [8];
    logic [PTR_W-1:0] rd_ptr   [8];
    logic [CNT_W-1:0] fifo_cnt [8];
    logic [5:0]       dma_bank_ptr [8];

    logic [7:0] bank_targeted;
    logic [7:0] bank_can_accept;
    logic [7:0] bank_fifo_empty;

    for (genvar gb = 0; gb < 8; gb++) begin : gen_bank_status
        localparam int G_IDX = gb / 2;
        localparam bit H_BIT = gb[0];

        assign dma_bank_ptr_o[gb]  = dma_bank_ptr[gb];
        assign bank_targeted[gb]   = !mode_1x1_i && (rd_state == RD_ACT_R) && lane_mask[G_IDX] && (H_BIT == half_sel);
        assign bank_can_accept[gb] = !bank_targeted[gb] || !bank_read_used_i[gb] || (fifo_cnt[gb] < CNT_W'(FIFO_DEPTH));
        assign bank_fifo_empty[gb] = (fifo_cnt[gb] == '0);
    end

    wire can_accept_strip_beat = &bank_can_accept;
    wire fifo_all_empty        = &bank_fifo_empty;
    wire word_avail_act        = (rd_state == RD_ACT_R) && (is_zero_beat || m_axi_rvalid);
    wire beat_fire             = word_avail_act && (mode_1x1_i ? (byte_sub_1x1 == 2'd3) : can_accept_strip_beat);

    wire active_sram_phase = (state_i == SEQ_PRELOAD) || (state_i == SEQ_COMPUTE);

    for (genvar gb = 0; gb < 8; gb++) begin : gen_bank_datapath
        localparam int G_IDX = gb / 2;

        wire push_b   = beat_fire && bank_targeted[gb];
        wire pop_b    = active_sram_phase && !bank_read_used_i[gb] && (!bank_fifo_empty[gb] || push_b);
        wire we_1x1_b = mode_1x1_i && word_avail_act && (preload_pong_1x1 == gb[2]) && (c_sub_1x1 == gb[1:0]);

        assign dma_act_we_o[gb]    = mode_1x1_i ? we_1x1_b   : pop_b;
        assign dma_act_addr_o[gb]  = mode_1x1_i ? addr_1x1_w : {dma_channel_reg[2:0], dma_bank_ptr[gb]};
        assign dma_act_wdata_o[gb] = mode_1x1_i ? wdata_1x1  : (bank_fifo_empty[gb] ? lane_byte[G_IDX] : fifo_mem[gb][rd_ptr[gb]]);

        always_ff @(posedge clk_i) begin
            if (!rst_n || state_i == SEQ_IDLE) begin
                wr_ptr[gb]       <= '0;
                rd_ptr[gb]       <= '0;
                fifo_cnt[gb]     <= '0;
                dma_bank_ptr[gb] <= '0;
            end else if (preload_done_i || pass_advance_i) begin
                wr_ptr[gb]       <= '0;
                rd_ptr[gb]       <= '0;
                fifo_cnt[gb]     <= '0;
                dma_bank_ptr[gb] <= '0;
            end else begin
                if (pop_b) begin
                    dma_bank_ptr[gb] <= dma_bank_ptr[gb] + 1'b1;
                end

                if (push_b && pop_b && bank_fifo_empty[gb]) begin
                    // Direct bypass to SRAM: FIFO remains empty
                end else if (push_b && pop_b) begin
                    fifo_mem[gb][wr_ptr[gb]] <= lane_byte[G_IDX];
                    wr_ptr[gb]               <= (wr_ptr[gb] == PTR_W'(FIFO_DEPTH - 1)) ? '0 : (wr_ptr[gb] + 1'b1);
                    rd_ptr[gb]               <= (rd_ptr[gb] == PTR_W'(FIFO_DEPTH - 1)) ? '0 : (rd_ptr[gb] + 1'b1);
                end else if (push_b) begin
                    fifo_mem[gb][wr_ptr[gb]] <= lane_byte[G_IDX];
                    wr_ptr[gb]               <= (wr_ptr[gb] == PTR_W'(FIFO_DEPTH - 1)) ? '0 : (wr_ptr[gb] + 1'b1);
                    fifo_cnt[gb]             <= fifo_cnt[gb] + 1'b1;
                end else if (pop_b) begin
                    rd_ptr[gb]               <= (rd_ptr[gb] == PTR_W'(FIFO_DEPTH - 1)) ? '0 : (rd_ptr[gb] + 1'b1);
                    fifo_cnt[gb]             <= fifo_cnt[gb] - 1'b1;
                end
            end
        end
    end

    // -------------------------------------------------------------------------
    // Weight, Bias, Quant & LUT Streaming Combinational Outputs
    // -------------------------------------------------------------------------
    wire can_shift_weight = (state_i == SEQ_PRELOAD) || (k_cnt_i >= 9'd15) || (!beat_idx[3] && k_cnt_i >= 9'd11);

    assign weight_shift_in_o = {m_axi_rdata, m_axi_rdata};
    assign weight_shift_en_o = (rd_state == RD_WEIGHT_R && m_axi_rvalid && can_shift_weight) ?
                               (beat_idx[3] ? 8'hF0 : 8'h0F) : 8'h00;

    assign quant_shift_in_o  = m_axi_rdata[29:0];
    assign quant_shift_en_o  = (rd_state == RD_QUANT_R) && m_axi_rvalid;

    assign bias_wdata_o      = $signed(m_axi_rdata);
    always_comb begin
        for (int c = 0; c < ARRAY_WIDTH; c++) begin
            bias_we_o[c] = (rd_state == RD_BIAS_R) && m_axi_rvalid && (beat_idx[2:0] == 3'(c));
        end
    end

    always_comb begin
        case (drain_cnt_i[1:0])
            2'd0: lut_wdata_o = m_axi_rdata[7:0];
            2'd1: lut_wdata_o = m_axi_rdata[15:8];
            2'd2: lut_wdata_o = m_axi_rdata[23:16];
            2'd3: lut_wdata_o = m_axi_rdata[31:24];
        endcase
    end
    assign lut_we_o = (rd_state == RD_LUT_R) && m_axi_rvalid;

    // -------------------------------------------------------------------------
    // AXI4 Read Master Channel Signals
    // -------------------------------------------------------------------------
    always_comb begin
        m_axi_arvalid = 1'b0;
        m_axi_araddr  = 32'd0;
        m_axi_arlen   = 8'd0;
        m_axi_rready  = 1'b0;

        case (rd_state)
            RD_BIAS_AR: begin
                m_axi_arvalid = 1'b1;
                m_axi_araddr  = bias_base_i;
                m_axi_arlen   = 8'd7;
            end
            RD_BIAS_R: begin
                m_axi_rready  = 1'b1;
            end
            RD_QUANT_AR: begin
                m_axi_arvalid = 1'b1;
                m_axi_araddr  = quant_base_i;
                m_axi_arlen   = 8'd7;
            end
            RD_QUANT_R: begin
                m_axi_rready  = 1'b1;
            end
            RD_ACT_AR: begin
                m_axi_arvalid = 1'b1;
                m_axi_araddr  = strip_addr;
                m_axi_arlen   = strip_arlen;
            end
            RD_ACT_R: begin
                m_axi_rready  = !is_zero_beat && (mode_1x1_i ? (byte_sub_1x1 == 2'd3) : can_accept_strip_beat);
            end
            RD_WEIGHT_AR: begin
                m_axi_arvalid = 1'b1;
                m_axi_araddr  = weight_curr_addr;
                m_axi_arlen   = mode_1x1_i ? 8'd7 : 8'd15;
            end
            RD_WEIGHT_R: begin
                m_axi_rready  = can_shift_weight;
            end
            RD_LUT_AR: begin
                m_axi_arvalid = 1'b1;
                m_axi_araddr  = lut_base_i;
                m_axi_arlen   = 8'd63;
            end
            RD_LUT_R: begin
                m_axi_rready  = (drain_cnt_i[1:0] == 2'd3);
            end
            default: ;
        endcase
    end

    assign dma_pass_ready_o = (rd_state == RD_PASS_DONE) ||
                              (rd_state == RD_WAIT_FIFO && fifo_all_empty);

    // -------------------------------------------------------------------------
    // AXI4 Read State Machine Progression
    // -------------------------------------------------------------------------
    wire [2:0] init_cur_strip   = mode_1x1_i ? 3'd1 : 3'd0;
    wire [2:0] last_strip_idx   = mode_1x1_i ? 3'd4 : 3'd5;
    wire [4:0] last_beat_idx    = mode_1x1_i ? 5'd15 : 5'd17;
    wire       first_strip_zero = mode_1x1_i ? strip_is_zero[1] : strip_is_zero[0];

    always_ff @(posedge clk_i) begin
        if (!rst_n) begin
            rd_state         <= RD_IDLE;
            weight_curr_addr <= 32'd0;
            ch_base_addr     <= 32'd0;
            strip_addr       <= 32'd0;
            cur_strip        <= 3'd0;
            beat_idx         <= 5'd0;
            c_sub_1x1        <= 2'd0;
            byte_sub_1x1     <= 2'd0;
            dma_channel_reg  <= 8'd0;
            dma_mod9_cnt     <= 4'd0;
            dma_next_ch      <= 8'd0;
            has_act_to_load  <= 1'b0;
        end else begin
            if (state_i == SEQ_IDLE) begin
                if (start_i) begin
                    weight_curr_addr <= weight_base_i;
                    ch_base_addr     <= init_strip_addr;
                    strip_addr       <= init_strip_addr;
                    cur_strip        <= init_cur_strip;
                    beat_idx         <= 5'd0;
                    c_sub_1x1        <= 2'd0;
                    byte_sub_1x1     <= 2'd0;
                    dma_channel_reg  <= 8'd0;
                    dma_mod9_cnt     <= 4'd0;
                    dma_next_ch      <= 8'd0;
                    has_act_to_load  <= 1'b1;
                    rd_state         <= RD_BIAS_AR;
                end else if (start_drain_i && lut_en_i) begin
                    rd_state         <= RD_LUT_AR;
                end else begin
                    rd_state         <= RD_IDLE;
                end
            end else if (enter_lut_load_i) begin
                rd_state <= RD_LUT_AR;
            end else if (preload_done_i) begin
                // Transition from SEQ_PRELOAD to SEQ_COMPUTE (Pass 0)
                cur_strip    <= init_cur_strip;
                beat_idx     <= 5'd0;
                c_sub_1x1    <= 2'd0;
                byte_sub_1x1 <= 2'd0;
                if (total_passes_i > 8'd1) begin
                    dma_mod9_cnt <= 4'd1;
                    dma_next_ch  <= 8'd1;
                    if ((mode_1x1_i ? 8'd4 : 8'd1) < cfg_cin_i) begin
                        dma_channel_reg <= mode_1x1_i ? 8'd4 : 8'd1;
                        has_act_to_load <= 1'b1;
                        ch_base_addr    <= ch_base_addr + ch_stride;
                        strip_addr      <= ch_base_addr + ch_stride;
                        rd_state        <= first_strip_zero ? RD_ACT_R : RD_ACT_AR;
                    end else begin
                        dma_channel_reg <= 8'd0;
                        has_act_to_load <= 1'b0;
                        rd_state        <= RD_WEIGHT_AR;
                    end
                end else begin
                    dma_channel_reg <= 8'd0;
                    has_act_to_load <= 1'b0;
                    rd_state        <= RD_PASS_DONE;
                end
            end else if (pass_advance_i) begin
                // Transition from Pass p to Pass p + 1 in SEQ_COMPUTE
                cur_strip    <= init_cur_strip;
                beat_idx     <= 5'd0;
                c_sub_1x1    <= 2'd0;
                byte_sub_1x1 <= 2'd0;
                if ((pass_cnt_i + 8'd2) < total_passes_i) begin
                    logic [7:0] next_ch_1x1;
                    next_ch_1x1  = {pass_cnt_i[5:0] + 6'd2, 2'b00};
                    dma_mod9_cnt <= next_mod_w;
                    dma_next_ch  <= next_ch_val_w;

                    if (mode_1x1_i ? (next_ch_1x1 >= cfg_cin_i) : (next_mod_w == 4'd8 || next_ch_val_w >= cfg_cin_i)) begin
                        dma_channel_reg <= 8'd0;
                        has_act_to_load <= 1'b0;
                        rd_state        <= RD_WEIGHT_AR;
                    end else begin
                        dma_channel_reg <= mode_1x1_i ? next_ch_1x1 : next_ch_val_w;
                        has_act_to_load <= 1'b1;
                        ch_base_addr    <= ch_base_addr + ch_stride;
                        strip_addr      <= ch_base_addr + ch_stride;
                        rd_state        <= first_strip_zero ? RD_ACT_R : RD_ACT_AR;
                    end
                end else begin
                    // Entering final pass: no further background fetches needed
                    dma_channel_reg <= 8'd0;
                    has_act_to_load <= 1'b0;
                    rd_state        <= RD_PASS_DONE;
                end
            end else begin
                case (rd_state)
                    RD_BIAS_AR: begin
                        if (m_axi_arready) begin
                            beat_idx <= 5'd0;
                            rd_state <= RD_BIAS_R;
                        end
                    end

                    RD_BIAS_R: begin
                        if (m_axi_rvalid) begin
                            if (beat_idx == 5'd7) begin
                                beat_idx <= 5'd0;
                                rd_state <= RD_QUANT_AR;
                            end else begin
                                beat_idx <= beat_idx + 5'd1;
                            end
                        end
                    end

                    RD_QUANT_AR: begin
                        if (m_axi_arready) begin
                            beat_idx <= 5'd0;
                            rd_state <= RD_QUANT_R;
                        end
                    end

                    RD_QUANT_R: begin
                        if (m_axi_rvalid) begin
                            if (beat_idx == 5'd7) begin
                                cur_strip    <= init_cur_strip;
                                beat_idx     <= 5'd0;
                                c_sub_1x1    <= 2'd0;
                                byte_sub_1x1 <= 2'd0;
                                rd_state     <= first_strip_zero ? RD_ACT_R : RD_ACT_AR;
                            end else begin
                                beat_idx <= beat_idx + 5'd1;
                            end
                        end
                    end

                    RD_ACT_AR: begin
                        if (m_axi_arready) begin
                            beat_idx     <= 5'd0;
                            byte_sub_1x1 <= 2'd0;
                            rd_state     <= RD_ACT_R;
                        end
                    end

                    RD_ACT_R: begin
                        if (mode_1x1_i && word_avail_act) begin
                            byte_sub_1x1 <= byte_sub_1x1 + 2'd1;
                        end
                        if (beat_fire) begin
                            if (beat_idx == last_beat_idx) begin
                                beat_idx <= 5'd0;
                                if (cur_strip == last_strip_idx) begin
                                    if (!mode_1x1_i || (c_sub_1x1 == 2'd3) || ((dma_channel_reg + 8'd1) >= cfg_cin_i)) begin
                                        rd_state <= RD_WEIGHT_AR;
                                    end else begin
                                        c_sub_1x1       <= c_sub_1x1 + 2'd1;
                                        dma_channel_reg <= dma_channel_reg + 8'd1;
                                        ch_base_addr    <= ch_base_addr + ch_stride;
                                        strip_addr      <= ch_base_addr + ch_stride;
                                        cur_strip       <= 3'd1;
                                        rd_state        <= first_strip_zero ? RD_ACT_R : RD_ACT_AR;
                                    end
                                end else begin
                                    strip_addr <= strip_addr + strip_stride;
                                    cur_strip  <= cur_strip + 3'd1;
                                    rd_state   <= strip_is_zero[cur_strip + 3'd1] ? RD_ACT_R : RD_ACT_AR;
                                end
                            end else begin
                                beat_idx <= beat_idx + 5'd1;
                            end
                        end
                    end

                    RD_WEIGHT_AR: begin
                        if (m_axi_arready) begin
                            beat_idx <= 5'd0;
                            rd_state <= RD_WEIGHT_R;
                        end
                    end

                    RD_WEIGHT_R: begin
                        if (m_axi_rvalid && can_shift_weight) begin
                            if (beat_idx == (mode_1x1_i ? 5'd7 : 5'd15)) begin
                                beat_idx         <= 5'd0;
                                weight_curr_addr <= weight_curr_addr + (mode_1x1_i ? 32'd32 : 32'd64);
                                rd_state         <= fifo_all_empty ? RD_PASS_DONE : RD_WAIT_FIFO;
                            end else begin
                                beat_idx <= beat_idx + 5'd1;
                            end
                        end
                    end

                    RD_WAIT_FIFO: begin
                        if (fifo_all_empty) begin
                            rd_state <= RD_PASS_DONE;
                        end
                    end

                    RD_PASS_DONE: begin
                        // Hold until preload_done_i or pass_advance_i
                    end

                    RD_LUT_AR: begin
                        if (m_axi_arready) begin
                            rd_state <= RD_LUT_R;
                        end
                    end

                    RD_LUT_R: begin
                        if (m_axi_rvalid && drain_cnt_i == 9'd255) begin
                            rd_state <= RD_IDLE;
                        end
                    end

                    default: rd_state <= RD_IDLE;
                endcase
            end
        end
    end

endmodule
