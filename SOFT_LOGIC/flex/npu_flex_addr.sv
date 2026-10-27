// =============================================================================
// File: SOFT_LOGIC/flex/npu_flex_addr.sv
// Module: npu_flex_addr
// Project: CrocoScale SoC — Direct-Bank 8-SRAM (4x2) 3x3 & 1x1 Address & Crossbar Driver
//
// Description:
//   Generates dual-mode (3x3 im2col and 1x1 pointwise) activation SRAM read
//   addresses and 8x8 crossbar selections across all 8 activation SRAM banks:
//   - 3x3 Mode (mode_1x1_i == 0): 4x2 bank grid (bank = {target_ly[1:0], target_lx >= 9}),
//     computing each bank's read address directly from its fixed bank coordinates
//     (G = bank[2:1], H = bank[0]) and the shared scanline wrap state without an
//     8x8 9-bit address crossbar.
//   - 1x1 Mode (mode_1x1_i == 1): Half-array ping-pong double buffering across
//     Banks 0..3 (even passes) and Banks 4..7 (odd passes) using only 2 crossbar
//     configurations while the opposite 4 banks are filled by AXI.
// =============================================================================

`timescale 1ns / 1ps

module npu_flex_addr #(
    parameter int ARRAY_HEIGHT = 8
) (
    input  wire        clk_i,
    input  wire        rst_n,
    input  wire        mode_1x1_i,
    input  wire [2:0]  state_i,
    input  wire [10:0] pass_cnt_i,
    input  wire [8:0]  k_cnt_i,
    input  wire [10:0] cfg_cin_i,
    input  wire        preload_done_i,
    input  wire        pass_advance_i,

    // Background DMA / Preload Write Interface (all 8 banks)
    input  wire [7:0]      dma_we_i,
    input  wire [7:0][8:0] dma_addr_i,
    output logic [7:0]     bank_read_used_o,

    // Outputs to Systolic Array & Activation SRAMs
    output logic [ARRAY_HEIGHT-1:0][3:0] crossbar_sel_o,
    output logic [7:0]                   act_sram_we_o,
    output logic [7:0][8:0]              act_sram_addr_o
);

    localparam logic [2:0] SEQ_IDLE    = 3'd0;
    localparam logic [2:0] SEQ_COMPUTE = 3'd2;

    // Compact decode of kernel tap (0..8) -> {ky[1:0], kx[1:0]}
    function automatic [3:0] get_tap_data(input [3:0] tap);
        case (tap)
            4'd0: return {2'd0, 2'd0};
            4'd1: return {2'd0, 2'd1};
            4'd2: return {2'd0, 2'd2};
            4'd3: return {2'd1, 2'd0};
            4'd4: return {2'd1, 2'd1};
            4'd5: return {2'd1, 2'd2};
            4'd6: return {2'd2, 2'd0};
            4'd7: return {2'd2, 2'd1};
            4'd8: return {2'd2, 2'd2};
            default: return 4'd0;
        endcase
    endfunction

    logic [10:0] cin_0;
    logic [3:0]  tap_0;

    // -------------------------------------------------------------------------
    // Per-Row Crossbar Selection (Only 3-bit bank ID needed per row)
    // -------------------------------------------------------------------------
    logic [ARRAY_HEIGHT-1:0]      row_active;
    logic [ARRAY_HEIGHT-1:0][2:0] row_target_bank;
    logic [ARRAY_HEIGHT-1:0][7:0] row_m_p;
    logic [ARRAY_HEIGHT-1:0]      row_m_p_valid;

    always_comb begin
        for (int r = 0; r < ARRAY_HEIGHT; r++) begin
            logic [8:0]  m_p;
            logic        m_p_valid;
            logic [4:0]  tap_sum;
            logic        tap_wrap;
            logic [3:0]  tap_curr;
            logic [11:0] cin_r;
            logic [11:0] cin_1x1;
            logic [3:0]  tap_data;
            logic [1:0]  ky_curr, kx_curr;
            logic [1:0]  ly_mod4;
            logic [4:0]  target_lx;
            logic        h;
            logic [2:0]  bank_3x3;
            logic [2:0]  bank_1x1;
            logic        active_3x3;
            logic        active_1x1;

            m_p              = k_cnt_i - 9'(r);
            m_p_valid        = (k_cnt_i >= 9'(r)) && !m_p[8];
            row_m_p[r]       = m_p[7:0];
            row_m_p_valid[r] = m_p_valid;

            tap_sum   = {1'b0, tap_0} + 5'(r);
            tap_wrap  = (tap_sum >= 5'd9);
            tap_curr  = tap_wrap ? 4'(tap_sum - 5'd9) : tap_sum[3:0];
            cin_r     = {1'b0, cin_0} + {11'd0, tap_wrap};
            cin_1x1   = {1'b0, pass_cnt_i[8:0], 2'(r)};

            tap_data  = get_tap_data(tap_curr);
            ky_curr   = tap_data[3:2];
            kx_curr   = tap_data[1:0];

            // In 4x2 banking, bank[2:1] is simply (out_y[1:0] + ky_curr) mod 4
            ly_mod4   = m_p[5:4] + ky_curr;
            target_lx = 5'({1'b0, m_p[3:0]} + {3'b000, kx_curr});
            h         = (target_lx >= 5'd9);
            bank_3x3  = {ly_mod4, h};
            bank_1x1  = {pass_cnt_i[0], 2'(r)};

            active_3x3 = (state_i == SEQ_COMPUTE) && m_p_valid && (cin_r < {1'b0, cfg_cin_i});
            active_1x1 = (state_i == SEQ_COMPUTE) && (r < 4) && m_p_valid && (cin_1x1 < {1'b0, cfg_cin_i});

            row_active[r]      = mode_1x1_i ? active_1x1 : active_3x3;
            row_target_bank[r] = mode_1x1_i ? bank_1x1   : bank_3x3;
            crossbar_sel_o[r]  = row_active[r] ? {1'b0, row_target_bank[r]} : 4'b1000;
        end
    end

    // -------------------------------------------------------------------------
    // Direct Per-Bank Read Address Generation (No 8x8 9-bit Address Crossbar)
    // -------------------------------------------------------------------------
    logic [3:0] k_lo, k_hi;
    logic       wrap_odd;
    logic [3:0] oy_even, oy_odd;
    logic [5:0] ox_rel_even, ox_rel_odd;

    assign k_lo        = k_cnt_i[3:0];
    assign k_hi        = k_cnt_i[7:4];
    assign wrap_odd    = (k_lo < 4'd7);
    assign oy_even     = k_hi;
    assign oy_odd      = wrap_odd ? (k_hi - 4'd1) : k_hi;
    assign ox_rel_even = 6'(k_lo) + 6'(tap_0);
    assign ox_rel_odd  = (wrap_odd ? (6'(k_lo) + 6'd7) : (6'(k_lo) - 6'd9)) + 6'(tap_0);

    logic [7:0]      bank_read_used;
    logic [7:0][8:0] bank_read_addr;

    always_comb begin
        for (int b = 0; b < 8; b++) begin
            logic [ARRAY_HEIGHT-1:0] match;
            logic [1:0] g_idx_b;
            logic       h_b;
            logic [3:0] oy_b;
            logic [5:0] ox_rel_b;
            logic [1:0] ky_b;
            logic [2:0] ly_div4;
            logic [5:0] ly_mul9;
            logic [5:0] ky_mul3;
            logic [5:0] rel_x;
            logic       cin_inc;
            logic [3:0] x_off;
            logic [2:0] cin_slot;
            logic [5:0] page_addr;
            logic [1:0] r_1x1;
            logic [8:0] addr_1x1;

            for (int r = 0; r < ARRAY_HEIGHT; r++) begin
                match[r] = row_active[r] && (row_target_bank[r] == 3'(b));
            end
            bank_read_used[b] = mode_1x1_i ? ((state_i == SEQ_COMPUTE) && (b[2] == pass_cnt_i[0]))
                                           : (|match);

            g_idx_b  = 2'(b >> 1);
            h_b      = b[0];
            oy_b     = h_b ? oy_odd : oy_even;
            ox_rel_b = h_b ? ox_rel_odd : ox_rel_even;

            ky_b     = g_idx_b - oy_b[1:0];
            ly_div4  = {1'b0, oy_b[3:2]} + {2'b00, (g_idx_b < oy_b[1:0])};
            ly_mul9  = {ly_div4, 3'b000} + {3'b000, ly_div4};

            ky_mul3  = (ky_b == 2'd0) ? 6'd0 :
                       (ky_b == 2'd1) ? 6'd3 : 6'd6;
            rel_x    = ox_rel_b - ky_mul3;
            cin_inc  = (rel_x[4:0] >= 5'd9);
            x_off    = cin_inc ? 4'(rel_x[4:0] - 5'd9) : rel_x[3:0];
            cin_slot = cin_0[2:0] + {2'b00, cin_inc};

            page_addr = ly_mul9 + {2'b00, x_off};
            r_1x1     = b[1:0];
            addr_1x1  = row_m_p_valid[r_1x1] ? {1'b0, row_m_p[r_1x1]} : 9'd0;

            bank_read_addr[b] = mode_1x1_i ? addr_1x1 : {cin_slot, page_addr};
        end
    end

    assign bank_read_used_o = bank_read_used;

    // Arbitrate SRAM ports between Systolic compute read and AXI DMA / Preload write
    for (genvar gb = 0; gb < 8; gb++) begin : gen_bank_mem
        assign act_sram_we_o[gb]   = dma_we_i[gb];
        assign act_sram_addr_o[gb] = bank_read_used[gb] ? bank_read_addr[gb] : dma_addr_i[gb];
    end

    // Pass and tap progression across the 9-iteration cycle
    always_ff @(posedge clk_i) begin
        if (!rst_n) begin
            cin_0 <= 11'd0;
            tap_0 <= 4'd0;
        end else begin
            if (state_i == SEQ_IDLE || preload_done_i) begin
                cin_0 <= 11'd0;
                tap_0 <= 4'd0;
            end else if (pass_advance_i) begin
                tap_0 <= (tap_0 == 4'd0) ? 4'd8 : (tap_0 - 4'd1);
                cin_0 <= (tap_0 == 4'd0) ? cin_0 : (cin_0 + 11'd1);
            end
        end
    end

endmodule

