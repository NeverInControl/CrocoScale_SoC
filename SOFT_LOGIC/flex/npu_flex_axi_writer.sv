// =============================================================================
// File: SOFT_LOGIC/flex/npu_flex_axi_writer.sv
// Module: npu_flex_axi_writer
// Project: CrocoScale SoC — 8-Bank (4x2) Skewed Drain & AXI4 Burst Write Engine
//
// Description:
//   Two-phase high-throughput drain and writeback engine that outputs
//   requantized activations in the continuous untiled [C_out][ceil(H_out/4)][W_out][4]
//   tensor format. Shares the top-level barrel shifter, 23-bit channel word
//   address register/adder, and sub-strip row bounds comparators with the
//   AXI4 Read Engine.
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
    input  wire  [1:0]                                   s1_ty_hi_i,
    input  wire  [4:0]                                   shared_beats_m1_i,
    input  wire                                          shared_beats_zero_i,
    input  wire  [22:0]                                  shared_ch_plus_shifted_i,
    input  wire  [3:0]                                   shared_row_lt_h_i,
    output logic [6:0]                                   wb_cur_strip_y_o,
    output logic                                         wb_use_strip_y_o,
    output logic                                         wb_ch_init_o,
    output logic                                         wb_ch_adv_o,
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

    wire unused_ok = &{1'b0, m_axi_bresp, out_base_i[24:0]};

    function automatic logic signed [7:0] signed_max8(
        input logic signed [7:0] a,
        input logic signed [7:0] b
    );
        signed_max8 = ($signed(a) > $signed(b)) ? a : b;
    endfunction

    localparam logic [1:0] WB_IDLE   = 2'd0;
    localparam logic [1:0] WB_STREAM = 2'd1;
    localparam logic [1:0] WB_WAIT_B = 2'd2;
    localparam logic [1:0] WB_DONE   = 2'd3;

    logic [1:0] wb_state;
    logic       aw_pending;
    logic [1:0] rd_wait;

    // =========================================================================
    // Phase 1: Skewed Drain & Optional 2x2 MaxPool into 8 Activation SRAM Banks
    // =========================================================================
    wire [10:0] pipe_lat      = lut_en_i ? 11'd6 : 11'd5;
    wire [10:0] base_t        = drain_cnt_i - pipe_lat;
    wire        p1_last_cycle = (drain_cnt_i[10:8] == {pool_s1_en_i, 1'b0, ~pool_s1_en_i}) &&
                                (drain_cnt_i[7:0] == 8'd13);
    wire        any_pool      = pool_en_i || pool_s1_en_i;
    wire        in_p1         = (wb_state == WB_IDLE);
    wire        in_p1_window  = (state_i == SEQ_DRAIN) && in_p1;

    logic [3:0][1:0][7:0] unp_act;
    logic [1:0][7:0]      pipe0;
    logic [1:0][7:0]      pipe1;
    logic [1:0][7:0]      pipe2;
    logic [1:0][7:0]      pool_out;

    for (genvar gh = 0; gh < 2; gh++) begin : gen_half_pool
        always_ff @(posedge clk_i) begin
            if (!rst_n) begin
                pipe0[gh] <= 8'd0;
                pipe1[gh] <= 8'd0;
                pipe2[gh] <= 8'd0;
            end else begin
                pipe0[gh] <= unp_act[0][gh];
                pipe1[gh] <= signed_max8($signed(pipe0[gh]), $signed(unp_act[1][gh]));
                pipe2[gh] <= signed_max8($signed(pipe1[gh]), $signed(unp_act[2][gh]));
            end
        end

        wire take_pipe2 = any_pool && ($signed(pipe2[gh]) > $signed(unp_act[3][gh]));
        assign pool_out[gh] = take_pipe2 ? pipe2[gh] : unp_act[3][gh];
    end

    // Shared 9-bit quotients (idx[10:2] = (base_t - ch) >> 2) via single 8-bit decrementer
    // Upper 8 bits [8:1] of (q0 - 1) and (q0 - 2) are always either q0[8:1] or (q0[8:1] - 1).
    wire [8:0] q0       = base_t[10:2];
    wire [7:0] q0_hi_m1 = q0[8:1] - 8'd1;

    wire       hi0_ok   = pool_s1_en_i ? !q0[8]       : (q0[8:6]       == 3'b000);
    wire       hi1_ok   = pool_s1_en_i ? !q0_hi_m1[7] : (q0_hi_m1[7:5] == 3'b000);

    // Shared pooled Phase-1 & Phase-2 SRAM addresses (identical across all 4 groups)
    logic [2:0] wb_cout;
    logic [1:0] wb_s_rel;
    logic [4:0] rd_tx;

    wire [1:0] pool_sel_c     = base_t[1:0] + 2'd1;
    wire       pool_borrow    = (base_t[1:0] != 2'd3);
    wire       pool_even_hi   = pool_borrow && !q0[0];
    wire       pool_odd_hi    = pool_borrow || !q0[0];
    wire [6:0] pool_hi_even   = pool_even_hi ? q0_hi_m1[6:0] : q0[7:1];
    wire [6:0] pool_hi_odd    = pool_odd_hi  ? q0_hi_m1[6:0] : q0[7:1];
    wire       pool_even_ok   = pool_even_hi ? hi1_ok : hi0_ok;
    wire       pool_odd_ok    = pool_odd_hi  ? hi1_ok : hi0_ok;
    wire [1:0] pool_idx_even  = {pool_hi_even[0],  (q0[0] ^ pool_borrow)};
    wire [1:0] pool_idx_odd   = {pool_hi_odd[0],  ~(q0[0] ^ pool_borrow)};

    wire [1:0] sh_c           = in_p1 ? pool_sel_c : wb_cout[1:0];
    wire [5:0] pool_sx_even   = pool_en_i ? {1'b0, pool_hi_even[4], 1'b0, pool_hi_even[3:1]} : pool_hi_even[6:1];
    wire [5:0] pool_sx_odd    = pool_en_i ? {1'b0, pool_hi_odd[4],  1'b0, pool_hi_odd[3:1]}  : pool_hi_odd[6:1];
    wire [5:0] sh_sx_even     = in_p1 ? pool_sx_even : {wb_s_rel[1:0], rd_tx[3:0]};
    wire [5:0] sh_sx_odd      = in_p1 ? pool_sx_odd  : {wb_s_rel[1:0], rd_tx[3:0]};

    wire [8:0] shared_addr_even = {1'b0, sh_sx_even[5:4], sh_c, sh_sx_even[3:0]};
    wire [8:0] shared_addr_odd  = {1'b0, sh_sx_odd[5:4],  sh_c, sh_sx_odd[3:0]};
    wire       unpooled_p1      = in_p1 && !any_pool;

    for (genvar gg = 0; gg < 4; gg++) begin : gen_sram_transpose
        wire       unp_borrow   = (base_t[1:0] < 2'(gg));
        wire       unp_even_hi  = unp_borrow && !q0[0];
        wire       unp_odd_hi   = unp_borrow || !q0[0];
        wire [5:0] unp_q_even   = {unp_even_hi ? q0_hi_m1[4:0] : q0[5:1],  (q0[0] ^ unp_borrow)};
        wire [5:0] unp_q_odd    = {unp_odd_hi  ? q0_hi_m1[4:0] : q0[5:1], ~(q0[0] ^ unp_borrow)};
        wire       unp_even_ok  = unp_even_hi ? hi1_ok : hi0_ok;
        wire       unp_odd_ok   = unp_odd_hi  ? hi1_ok : hi0_ok;
        wire [1:0] unp_sel_c    = base_t[1:0] - 2'(gg);

        assign unp_act[gg][0] = $signed(out_act_i[{1'b0, unp_sel_c}]);
        assign unp_act[gg][1] = $signed(out_act_i[{1'b1, unp_sel_c}]);

        assign drain_act_we_o[2*gg]     = in_p1_window && (any_pool ? (pool_even_ok && (pool_idx_even == 2'(gg))) : unp_even_ok);
        assign drain_act_we_o[2*gg + 1] = in_p1_window && (any_pool ? (pool_odd_ok  && (pool_idx_odd  == 2'(gg))) : unp_odd_ok);

        assign drain_act_addr_o[2*gg]     = unpooled_p1 ? {1'b0, unp_q_even[5:4], unp_sel_c, unp_q_even[3:0]} : shared_addr_even;
        assign drain_act_addr_o[2*gg + 1] = unpooled_p1 ? {1'b0, unp_q_odd[5:4],  unp_sel_c, unp_q_odd[3:0]}  : shared_addr_odd;

        assign drain_act_wdata_o[2*gg]     = (any_pool || (gg == 3)) ? pool_out[0] : unp_act[gg][0];
        assign drain_act_wdata_o[2*gg + 1] = (any_pool || (gg == 3)) ? pool_out[1] : unp_act[gg][1];
    end

    // =========================================================================
    // Phase 2: Contiguous AXI4 Burst Writeback to [C_out][ceil(H_out/4)][W_out][4]
    // =========================================================================
    wire [1:0]  max_s_rel      = pool_en_i ? 2'd1 : 2'd3;
    wire [7:0]  wb_awlen       = {3'd0, shared_beats_m1_i};

    wire [1:0]  next_s_rel     = wb_s_rel + 2'd1;
    wire [1:0]  eff_s_rel      = (in_p1 && !drain_cnt_i[10] && pool_s1_en_i) ? s1_ty_hi_i :
                                 ((wb_state == WB_WAIT_B) ? next_s_rel : wb_s_rel);
    wire [6:0]  cur_strip_y    = pool_en_i ? {1'b0, tile_y_i, eff_s_rel[0]} : {tile_y_i, eff_s_rel};
    wire        next_strip_ok  = (wb_s_rel != max_s_rel) && shared_row_lt_h_i[0];
    wire        first_strip_ok = !shared_beats_zero_i && shared_row_lt_h_i[0];

    assign wb_cur_strip_y_o = cur_strip_y;
    assign wb_use_strip_y_o = (wb_state != WB_WAIT_B);
    assign wb_ch_init_o     = (state_i == SEQ_DRAIN) && in_p1 && p1_last_cycle;
    assign wb_ch_adv_o      = (state_i == SEQ_DRAIN) && (wb_state == WB_WAIT_B) && m_axi_bvalid && m_axi_bready &&
                              !next_strip_ok && (wb_cout < 3'd7);

    wire [7:0] raw_b0 = wb_cout[2] ? act_sram_rdata_i[1] : act_sram_rdata_i[0];
    wire [7:0] raw_b1 = wb_cout[2] ? act_sram_rdata_i[3] : act_sram_rdata_i[2];
    wire [7:0] raw_b2 = wb_cout[2] ? act_sram_rdata_i[5] : act_sram_rdata_i[4];
    wire [7:0] raw_b3 = wb_cout[2] ? act_sram_rdata_i[7] : act_sram_rdata_i[6];

    wire [7:0] masked_b0 = shared_row_lt_h_i[0] ? raw_b0 : 8'd0;
    wire [7:0] masked_b1 = shared_row_lt_h_i[1] ? raw_b1 : 8'd0;
    wire [7:0] masked_b2 = shared_row_lt_h_i[2] ? raw_b2 : 8'd0;
    wire [7:0] masked_b3 = shared_row_lt_h_i[3] ? raw_b3 : 8'd0;
    wire [31:0] sram_packed_word = {masked_b3, masked_b2, masked_b1, masked_b0};

    // AXI4 Write Master Combinational Outputs
    assign m_axi_awaddr  = {out_base_i[31:25], shared_ch_plus_shifted_i, 2'b00};
    assign m_axi_awlen   = wb_awlen;
    assign m_axi_awvalid = aw_pending;

    assign m_axi_wdata   = sram_packed_word;
    assign m_axi_wstrb   = 4'b1111;
    assign m_axi_wlast   = (rd_tx == shared_beats_m1_i);
    assign m_axi_wvalid  = (wb_state == WB_STREAM) && (rd_wait == 2'd3);

    assign m_axi_bready  = (wb_state == WB_WAIT_B) && !aw_pending;
    assign writer_done_o = (wb_state == WB_DONE);

    always_ff @(posedge clk_i) begin
        if (!rst_n || state_i != SEQ_DRAIN) begin
            wb_state   <= WB_IDLE;
            wb_cout    <= 3'd0;
            wb_s_rel   <= 2'd0;
            aw_pending <= 1'b0;
            rd_tx      <= 5'd0;
            rd_wait    <= 2'd0;
        end else begin
            if (m_axi_awvalid && m_axi_awready) begin
                aw_pending <= 1'b0;
            end

            case (wb_state)
                WB_IDLE: begin
                    if (p1_last_cycle) begin
                        wb_cout  <= 3'd0;
                        wb_s_rel <= 2'd0;
                        rd_tx    <= 5'd0;
                        rd_wait  <= 2'd0;
                        if (first_strip_ok) begin
                            aw_pending <= 1'b1;
                            wb_state   <= WB_STREAM;
                        end else begin
                            wb_state   <= WB_DONE;
                        end
                    end
                end

                WB_STREAM: begin
                    if (rd_wait < 2'd3) begin
                        rd_wait <= rd_wait + 2'd1;
                    end else if (m_axi_wready) begin
                        rd_wait <= 2'd0;
                        if (m_axi_wlast) begin
                            wb_state <= WB_WAIT_B;
                        end else begin
                            rd_tx <= rd_tx + 5'd1;
                        end
                    end
                end

                WB_WAIT_B: begin
                    if (m_axi_bvalid && m_axi_bready) begin
                        rd_tx   <= 5'd0;
                        rd_wait <= 2'd0;
                        if (next_strip_ok) begin
                            wb_s_rel   <= next_s_rel;
                            aw_pending <= 1'b1;
                            wb_state   <= WB_STREAM;
                        end else if (wb_cout < 3'd7) begin
                            wb_cout    <= wb_cout + 3'd1;
                            wb_s_rel   <= 2'd0;
                            aw_pending <= 1'b1;
                            wb_state   <= WB_STREAM;
                        end else begin
                            wb_state   <= WB_DONE;
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
