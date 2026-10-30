// =============================================================================
// File: SOFT_LOGIC/flex/npu_flex_axi_reader.sv
// Module: npu_flex_axi_reader
// Project: CrocoScale SoC — 8-Bank (4x2) AXI4 Read Engine & Staging Controller
//
// Description:
//   Fetches biases, quantizer configurations, systolic weights, non-linear LUT
//   tables, and untiled [C][ceil(H/4)][W][4] 4-row vertical activation strips
//   over the AXI4 Read Master interface.
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
    input  wire [10:0]                                   pass_cnt_i,
    input  wire [8:0]                                    k_cnt_i,
    input  wire [10:0]                                   total_passes_i,
    input  wire                                          preload_done_i,
    input  wire                                          pass_advance_i,
    input  wire                                          enter_lut_load_i,
    input  wire [10:0]                                   drain_cnt_i,
    input  wire [3:0]                                    tap_0_i,
    input  wire [7:0]                                    bank_read_used_i,

    output logic                                         dma_pass_ready_o,

    // Memory Base Addresses & Arbitrary Layer/Tile Geometry
    input  wire [AXI_ADDR_WIDTH-1:0]                     act_base_i,
    input  wire [AXI_ADDR_WIDTH-1:0]                     weight_base_i,
    input  wire [AXI_ADDR_WIDTH-1:0]                     bias_base_i,
    input  wire [AXI_ADDR_WIDTH-1:0]                     quant_base_i,
    input  wire [AXI_ADDR_WIDTH-1:0]                     lut_base_i,
    input  wire [4:0]                                    tile_y_i,
    input  wire [4:0]                                    tile_x_i,
    input  wire [10:0]                                   cfg_cin_i,

    // Shared Geometry Shifter, Channel Address & Row Bounds Interface
    input  wire [4:0]                                    shared_end_x_i,
    input  wire [4:0]                                    shared_beats_m1_i,
    input  wire                                          shared_beats_zero_i,
    input  wire [22:0]                                   shared_ch_plus_shifted_i,
    input  wire [3:0]                                    shared_row_lt_h_i,
    output logic [6:0]                                   rd_cur_strip_y_o,
    output logic                                         rd_use_strip_y_o,
    output logic                                         rd_ch_init_o,
    output logic                                         rd_ch_adv_o,

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

    localparam logic [3:0] RD_IDLE      = 4'd0;
    localparam logic [3:0] RD_BIAS_AR   = 4'd1;
    localparam logic [3:0] RD_BIAS_R    = 4'd2;
    localparam logic [3:0] RD_QUANT_AR  = 4'd3;
    localparam logic [3:0] RD_QUANT_R   = 4'd4;
    localparam logic [3:0] RD_ACT_AR    = 4'd5;
    localparam logic [3:0] RD_ACT_R     = 4'd6;
    localparam logic [3:0] RD_WEIGHT_AR = 4'd7;
    localparam logic [3:0] RD_WEIGHT_R  = 4'd8;
    localparam logic [3:0] RD_PASS_DONE = 4'd10;
    localparam logic [3:0] RD_LUT_AR    = 4'd11;
    localparam logic [3:0] RD_LUT_R     = 4'd12;

    wire unused_ok = &{1'b0, total_passes_i, m_axi_rresp, m_axi_rlast, act_base_i[24:0], weight_base_i[31:25], weight_base_i[1:0],
                       bias_base_i[31:25], bias_base_i[1:0], quant_base_i[31:25], quant_base_i[1:0], lut_base_i[31:25], lut_base_i[1:0]};

    logic [3:0]  rd_state;
    logic [19:0] weight_word_addr;

    logic [2:0]  cur_strip;
    logic [4:0]  beat_idx;
    logic [1:0]  byte_sub_1x1;

    logic [10:0] dma_ch;

    // -------------------------------------------------------------------------
    // Shared Strip Geometry & Boundary Windows
    // -------------------------------------------------------------------------
    wire        has_left_pad    = !mode_1x1_i && (tile_x_i == 5'd0);
    wire [6:0]  cur_strip_y     = {tile_y_i, 2'b00} + {4'd0, cur_strip} - 7'd1;

    assign rd_cur_strip_y_o = cur_strip_y;
    assign rd_use_strip_y_o = (rd_state == RD_ACT_AR);
    assign rd_ch_init_o     = (state_i == SEQ_IDLE) && start_i;

    // Horizontal & vertical valid strip bounds using shared sequencer comparators
    wire [4:0]  end_beat_x      = shared_end_x_i;
    wire [7:0]  strip_arlen     = {3'd0, shared_beats_m1_i};

    wire        strip_y_valid   = (cur_strip == 3'd0) ? ((tile_y_i != 5'd0) && shared_row_lt_h_i[3])
                                                      : shared_row_lt_h_i[0];
    wire        is_zero_strip   = shared_beats_zero_i || !strip_y_valid;

    wire        skip_act_3x3    = !mode_1x1_i && (tap_0_i == 4'd3);
    wire        start_next_pass = preload_done_i || pass_advance_i;
    wire        has_next_pass   = (|pass_cnt_i[10:1]) || (preload_done_i && pass_cnt_i[0]);
    wire [10:0] dma_ch_p1       = dma_ch + 11'd1;
    wire        cand_ch_lt_cin  = (dma_ch_p1 < cfg_cin_i);

    // -------------------------------------------------------------------------
    // Dynamic Border Zero Detection & Strip Byte-Lane Routing
    // -------------------------------------------------------------------------
    wire        is_zero_x       = (beat_idx == 5'd0 && has_left_pad) || (beat_idx >= end_beat_x);
    wire        is_zero_beat    = is_zero_strip || is_zero_x;

    wire [3:0][7:0] lane_byte;
    assign lane_byte[0] = (!is_zero_beat && shared_row_lt_h_i[3]) ? m_axi_rdata[31:24] : 8'd0;
    assign lane_byte[1] = (!is_zero_beat && shared_row_lt_h_i[0]) ? m_axi_rdata[7:0]   : 8'd0;
    assign lane_byte[2] = (!is_zero_beat && shared_row_lt_h_i[1]) ? m_axi_rdata[15:8]  : 8'd0;
    assign lane_byte[3] = (!is_zero_beat && shared_row_lt_h_i[2]) ? m_axi_rdata[23:16] : 8'd0;

    wire [3:0] lane_mask;
    assign lane_mask[0] = (cur_strip != 3'd5);
    assign lane_mask[1] = (cur_strip != 3'd0);
    assign lane_mask[2] = (cur_strip != 3'd0) && (cur_strip != 3'd5);
    assign lane_mask[3] = (cur_strip != 3'd0) && (cur_strip != 3'd5);

    wire half_sel = (beat_idx >= 5'd9);

    // 1x1 Half-Array Ping-Pong Unpacking Signals
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
    // Direct Per-Beat In-Place Bank Write & Algebraic SRAM Bank Pointers
    // -------------------------------------------------------------------------
    wire [3:0] x_off      = half_sel ? 4'(beat_idx - 5'd9) : beat_idx[3:0];
    wire [5:0] strip_mul9 = {cur_strip, 3'b000} + {3'b000, cur_strip};
    wire [5:0] ptr_g0     = strip_mul9 + {2'b00, x_off};
    wire [5:0] ptr_g123   = ptr_g0 - 6'd9;

    logic [3:0] lane_done;
    logic [3:0] need_lane;
    logic [3:0] bank_free;
    logic [3:0] lane_ready;

    for (genvar g = 0; g < 4; g++) begin : gen_lane_status
        wire [2:0] target_b = {2'(g), half_sel};
        assign need_lane[g]  = lane_mask[g] && !lane_done[g];
        assign bank_free[g]  = !bank_read_used_i[target_b];
        assign lane_ready[g] = !need_lane[g] || bank_free[g];
    end

    wire can_accept_strip_beat = &lane_ready;
    wire word_avail_act        = (rd_state == RD_ACT_R) && (is_zero_beat || m_axi_rvalid);
    wire beat_fire             = word_avail_act && (mode_1x1_i ? (byte_sub_1x1 == 2'd3) : can_accept_strip_beat);

    always_ff @(posedge clk_i) begin
        if (!rst_n || state_i == SEQ_IDLE || preload_done_i || pass_advance_i || rd_state != RD_ACT_R || mode_1x1_i || beat_fire) begin
            lane_done <= 4'b0000;
        end else if (word_avail_act) begin
            for (int g = 0; g < 4; g++) begin
                if (need_lane[g] && bank_free[g]) begin
                    lane_done[g] <= 1'b1;
                end
            end
        end
    end

    wire [8:0] dma_addr_g0   = mode_1x1_i ? addr_1x1_w : {dma_ch[2:0], ptr_g0};
    wire [8:0] dma_addr_g123 = mode_1x1_i ? addr_1x1_w : {dma_ch[2:0], ptr_g123};

    for (genvar gb = 0; gb < 8; gb++) begin : gen_bank_datapath
        localparam int G_IDX = gb / 2;
        localparam bit H_BIT = gb[0];

        wire we_3x3_b = !mode_1x1_i && word_avail_act && (H_BIT == half_sel) && need_lane[G_IDX] && !bank_read_used_i[gb];
        wire we_1x1_b = mode_1x1_i && word_avail_act && (dma_ch[2:0] == 3'(gb));

        assign dma_act_we_o[gb]    = mode_1x1_i   ? we_1x1_b    : we_3x3_b;
        assign dma_act_addr_o[gb]  = (G_IDX == 0) ? dma_addr_g0 : dma_addr_g123;
        assign dma_act_wdata_o[gb] = mode_1x1_i   ? wdata_1x1   : lane_byte[G_IDX];
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
    logic [22:0] ar_word_addr;

    assign m_axi_arvalid = rd_state[0] && !((rd_state[3:1] == 3'd2) && is_zero_strip);

    always_comb begin
        if (rd_state[3]) begin
            ar_word_addr = lut_base_i[24:2];
            m_axi_arlen  = 8'd63;
        end else begin
            case (rd_state[2:1])
                2'd0: begin
                    ar_word_addr = bias_base_i[24:2];
                    m_axi_arlen  = 8'd7;
                end
                2'd1: begin
                    ar_word_addr = quant_base_i[24:2];
                    m_axi_arlen  = 8'd7;
                end
                2'd2: begin
                    ar_word_addr = shared_ch_plus_shifted_i;
                    m_axi_arlen  = strip_arlen;
                end
                2'd3: begin
                    ar_word_addr = {weight_word_addr, weight_base_i[4:2]};
                    m_axi_arlen  = mode_1x1_i ? 8'd7 : 8'd15;
                end
            endcase
        end

        case (rd_state)
            RD_BIAS_R,
            RD_QUANT_R:  m_axi_rready = 1'b1;
            RD_ACT_R:    m_axi_rready = !is_zero_beat && (mode_1x1_i ? (byte_sub_1x1 == 2'd3) : can_accept_strip_beat);
            RD_WEIGHT_R: m_axi_rready = can_shift_weight;
            RD_LUT_R:    m_axi_rready = (drain_cnt_i[1:0] == 2'd3);
            default:     m_axi_rready = 1'b0;
        endcase
    end

    assign m_axi_araddr = {act_base_i[31:25], ar_word_addr, 2'b00};

    assign dma_pass_ready_o = (rd_state == RD_PASS_DONE);

    // -------------------------------------------------------------------------
    // AXI4 Read State Machine Progression & Shared Channel Stride Advance
    // -------------------------------------------------------------------------
    wire [2:0]  init_cur_strip = mode_1x1_i ? 3'd1 : 3'd0;
    wire [2:0]  last_strip_idx = mode_1x1_i ? 3'd4 : 3'd5;
    wire [4:0]  last_beat_idx  = mode_1x1_i ? 5'd15 : 5'd17;

    wire adv_on_pass    = start_next_pass && has_next_pass && !skip_act_3x3 && cand_ch_lt_cin;
    wire adv_on_1x1_sub = !start_next_pass && (rd_state == RD_ACT_R) &&
                          beat_fire && (beat_idx == last_beat_idx) && (cur_strip == last_strip_idx) &&
                          mode_1x1_i && (dma_ch[1:0] != 2'd3) && cand_ch_lt_cin;

    assign rd_ch_adv_o  = (state_i != SEQ_IDLE) && !enter_lut_load_i &&
                          (adv_on_pass || adv_on_1x1_sub);

    always_ff @(posedge clk_i) begin
        if (!rst_n) begin
            rd_state         <= RD_IDLE;
            weight_word_addr <= 20'd0;
            cur_strip        <= 3'd0;
            beat_idx         <= 5'd0;
            byte_sub_1x1     <= 2'd0;
            dma_ch           <= 11'd0;
        end else begin
            if (state_i == SEQ_IDLE) begin
                if (start_i) begin
                    weight_word_addr <= weight_base_i[24:5];
                    cur_strip        <= init_cur_strip;
                    beat_idx         <= 5'd0;
                    byte_sub_1x1     <= 2'd0;
                    dma_ch           <= 11'd0;
                    rd_state         <= RD_BIAS_AR;
                end else if (start_drain_i && lut_en_i) begin
                    rd_state         <= RD_LUT_AR;
                end else begin
                    rd_state         <= RD_IDLE;
                end
            end else if (enter_lut_load_i) begin
                rd_state <= RD_LUT_AR;
            end else if (start_next_pass) begin
                cur_strip    <= init_cur_strip;
                beat_idx     <= 5'd0;
                byte_sub_1x1 <= 2'd0;
                if (has_next_pass) begin
                    if (!skip_act_3x3) begin
                        dma_ch <= dma_ch_p1;
                    end
                    rd_state <= (skip_act_3x3 || !cand_ch_lt_cin) ? RD_WEIGHT_AR : RD_ACT_AR;
                end else begin
                    rd_state <= RD_PASS_DONE;
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
                                byte_sub_1x1 <= 2'd0;
                                rd_state     <= RD_ACT_AR;
                            end else begin
                                beat_idx <= beat_idx + 5'd1;
                            end
                        end
                    end

                    RD_ACT_AR: begin
                        if (is_zero_strip || m_axi_arready) begin
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
                                    if (!mode_1x1_i || (dma_ch[1:0] == 2'd3) || !cand_ch_lt_cin) begin
                                        rd_state <= RD_WEIGHT_AR;
                                    end else begin
                                        dma_ch    <= dma_ch_p1;
                                        cur_strip <= 3'd1;
                                        rd_state  <= RD_ACT_AR;
                                    end
                                end else begin
                                    cur_strip <= cur_strip + 3'd1;
                                    rd_state  <= RD_ACT_AR;
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
                                weight_word_addr <= weight_word_addr + (mode_1x1_i ? 20'd1 : 20'd2);
                                rd_state         <= RD_PASS_DONE;
                            end else begin
                                beat_idx <= beat_idx + 5'd1;
                            end
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
                        if (m_axi_rvalid && drain_cnt_i == 11'd255) begin
                            rd_state <= RD_IDLE;
                        end
                    end

                    default: rd_state <= RD_IDLE;
                endcase
            end
        end
    end

endmodule
