// =============================================================================
// File: SOFT_LOGIC/flex/npu_flex_addr.sv
// Module: npu_flex_addr
// Project: CrocoScale SoC — Direct-Bank 8-SRAM (4x2) 3x3 & 1x1 Address & Crossbar Driver
//
// Description:
//   Generates dual-mode (3x3 im2col and 1x1 pointwise) activation SRAM read
//   addresses and 8x8 crossbar selections across all 8 activation SRAM banks:
//   - 3x3 Mode (mode_1x1_i == 0): 4x2 bank grid (bank = {target_ly[1:0], target_lx >= 9}),
//     computing each bank's read address from a shared per-half base_page[h]
//     plus a 4-input LUT offset (9*borrow_g - 3*ky_b - 9*cin_inc).
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
    input  wire [7:0][8:0] dma_addr_i,
    output logic [7:0]     bank_read_used_o,

    // Outputs to Systolic Array & Activation SRAMs
    output logic [3:0]                   tap_0_o,
    output logic [ARRAY_HEIGHT-1:0][3:0] crossbar_sel_o,
    output logic [7:0][8:0]              act_sram_addr_o
);

    localparam logic [2:0] SEQ_IDLE    = 3'd0;
    localparam logic [2:0] SEQ_COMPUTE = 3'd2;

    wire unused_ok = &{1'b0, pass_cnt_i};

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

    // Shared upper-bit decrementer and hoisted channel bounds checks
    wire [3:0]  k_lo       = k_cnt_i[3:0];
    wire [4:0]  k_hi5      = k_cnt_i[8:4];
    wire [4:0]  k_hi5_m1   = k_hi5 - 5'd1;

    wire [10:0] cin_0_p1   = cin_0 + {8'd0, mode_1x1_i, 1'b0, ~mode_1x1_i};
    wire        cin0_ok    = ({cin_0[10:2], cin_0[1:0] | {2{mode_1x1_i}}} < cfg_cin_i);
    wire        cin1_ok    = (cin_0_p1 < cfg_cin_i);

    wire        wrap_odd    = (k_lo < 4'd7);
    wire [3:0]  oy_even     = k_hi5[3:0];
    wire [3:0]  oy_odd      = wrap_odd ? k_hi5_m1[3:0] : k_hi5[3:0];
    wire        valid_even  = (state_i == SEQ_COMPUTE) && !k_hi5[4];
    wire        valid_odd   = (state_i == SEQ_COMPUTE) && (wrap_odd ? !k_hi5_m1[4] : !k_hi5[4]);

    // -------------------------------------------------------------------------
    // Per-Row Crossbar Selection (Only 3-bit bank ID needed per row)
    // -------------------------------------------------------------------------
    // Precompute 4-bit k_lo threshold comparators (k_lo >= 7..15; k_lo >= 16 is 0)
    wire [16:7] k_ge;
    for (genvar gt = 7; gt <= 15; gt++) begin : gen_k_ge
        assign k_ge[gt] = (k_lo >= 4'(gt));
    end
    assign k_ge[16] = 1'b0;

    logic [2:0]                   ky_used_even;
    logic [2:0]                   ky_used_odd;
    logic [3:0][7:0]              row_m_p;

    always_comb begin
        ky_used_even = 3'b000;
        ky_used_odd  = 3'b000;
        for (int r = 0; r < ARRAY_HEIGHT; r++) begin
            logic       borrow_r;
            logic [4:0] tap_sum;
            logic       tap_wrap;
            logic [3:0] tap_curr;
            logic [3:0] tap_data;
            logic [1:0] ky_curr, kx_curr;
            logic [1:0] oy_r_lo;
            logic [1:0] ly_mod4;
            logic       h;
            logic [2:0] bank_3x3;
            logic [2:0] bank_1x1;
            logic       cin_3x3_ok;
            logic       cin_1x1_ok;
            logic       active_3x3;
            logic       active_1x1;
            logic       row_act;
            logic [2:0] row_bnk;

            borrow_r  = (k_lo < 4'(r));

            if (r < 4) begin
                row_m_p[r] = {borrow_r ? oy_odd : oy_even, (k_lo - 4'(r))};
            end

            tap_sum    = {1'b0, tap_0} + 5'(r);
            tap_wrap   = (tap_sum >= 5'd9);
            tap_curr   = tap_wrap ? 4'(tap_sum - 5'd9) : tap_sum[3:0];

            tap_data   = get_tap_data(tap_curr);
            ky_curr    = tap_data[3:2];
            kx_curr    = tap_data[1:0];

            // Since borrow_r == (h && wrap_odd), row r's out_y[1:0] is h ? oy_odd[1:0] : oy_even[1:0].
            h          = borrow_r || ((kx_curr == 2'd0) ? k_ge[9 + r] :
                                      (kx_curr == 2'd1) ? k_ge[8 + r] : k_ge[7 + r]);
            oy_r_lo    = h ? oy_odd[1:0] : oy_even[1:0];
            ly_mod4    = oy_r_lo + ky_curr;
            bank_3x3   = {ly_mod4, h};
            bank_1x1   = {cin_0[2], 2'(r)};

            cin_3x3_ok = tap_wrap ? cin1_ok : cin0_ok;
            cin_1x1_ok = cin0_ok || (2'(r) < cfg_cin_i[1:0]);

            if (cin_3x3_ok) begin
                if (h) begin
                    ky_used_odd[ky_curr]  = 1'b1;
                end else begin
                    ky_used_even[ky_curr] = 1'b1;
                end
            end

            active_3x3 = (h ? valid_odd : valid_even) && cin_3x3_ok;
            active_1x1 = (r < 4) && (borrow_r ? valid_odd : valid_even) && cin_1x1_ok;

            row_act           = mode_1x1_i ? active_1x1 : active_3x3;
            row_bnk           = (mode_1x1_i && (r < 4)) ? bank_1x1 : bank_3x3;
            crossbar_sel_o[r] = row_act ? {1'b0, row_bnk} : 4'b1000;
        end
    end

    // -------------------------------------------------------------------------
    // Direct Per-Bank Read Address Generation (No 8x8 9-bit Address Crossbar)
    // -------------------------------------------------------------------------
    // Identity: 9*borrow_y - 3*ky_b == 3*oy[1:0] - 3*g_idx_b - 3*borrow_y.
    // Moving 3*oy[1:0] into the shared per-half base_h leaves delta_b as a
    // function of only 2 bits (borrow_y, cin_inc) per bank (1 bit for g_idx=3).
    function automatic [5:0] calc_oy_base(input [3:0] oy);
        calc_oy_base = {oy[3:2], 3'b000} + {4'd0, oy[3:2]} + {4'd0, oy[1:0]} + {3'd0, oy[1:0], 1'b0};
    endfunction

    wire [4:0] ox_rel_even = 5'(k_lo) + 5'(tap_0);
    wire [4:0] ox_rel_odd  = ox_rel_even + {!wrap_odd, 4'b0111};

    wire [5:0] base_even   = calc_oy_base(oy_even) + {1'b0, ox_rel_even};
    wire [5:0] base_odd    = calc_oy_base(oy_odd)  + {1'b0, ox_rel_odd};

    wire [2:0] ge_even     = {(ox_rel_even >= 5'd15), (ox_rel_even >= 5'd12), (ox_rel_even >= 5'd9)};
    wire [2:0] ge_odd      = {(ox_rel_odd  >= 5'd15), (ox_rel_odd  >= 5'd12), (ox_rel_odd  >= 5'd9)};

    assign tap_0_o = tap_0;

    logic [7:0]      bank_read_used;
    logic [7:0][8:0] bank_read_addr;

    always_comb begin
        for (int b = 0; b < 8; b++) begin
            logic [1:0] g_idx_b;
            logic       h_b;
            logic [1:0] oy_lo_b;
            logic [5:0] base_b;
            logic [2:0] ge_b;
            logic [2:0] ky_used_b;
            logic [1:0] ky_b;
            logic       used_3x3;
            logic       borrow_y;
            logic       cin_inc;
            logic [5:0] delta_b;
            logic [2:0] cin_slot;
            logic [5:0] page_addr;

            g_idx_b   = 2'(b >> 1);
            h_b       = b[0];
            oy_lo_b   = h_b ? oy_odd[1:0] : oy_even[1:0];
            base_b    = h_b ? base_odd    : base_even;
            ge_b      = h_b ? ge_odd      : ge_even;
            ky_used_b = h_b ? ky_used_odd : ky_used_even;

            ky_b      = g_idx_b - oy_lo_b;
            borrow_y  = (g_idx_b < oy_lo_b);
            cin_inc   = (ky_b == 2'd0) ? ge_b[0] :
                        (ky_b == 2'd1) ? ge_b[1] : ge_b[2];
            used_3x3  = (h_b ? valid_odd : valid_even) &&
                        ((ky_b == 2'd0) ? ky_used_b[0] :
                         (ky_b == 2'd1) ? ky_used_b[1] :
                         (ky_b == 2'd2) ? ky_used_b[2] : 1'b0);

            bank_read_used[b] = mode_1x1_i ? ((state_i == SEQ_COMPUTE) && (b[2] == cin_0[2]))
                                           : used_3x3;

            case ({borrow_y, cin_inc})
                2'b00: delta_b = 6'(64 - 3 * (b >> 1));
                2'b01: delta_b = 6'(64 - 3 * (b >> 1) - 9);
                2'b10: delta_b = 6'(64 - 3 * (b >> 1) - 3);
                2'b11: delta_b = 6'(64 - 3 * (b >> 1) - 12);
            endcase

            page_addr = base_b + delta_b;
            cin_slot  = cin_inc ? cin_0_p1[2:0] : cin_0[2:0];

            bank_read_addr[b] = mode_1x1_i ? {1'b0, row_m_p[b[1:0]]} : {cin_slot, page_addr};
        end
    end

    assign bank_read_used_o = bank_read_used;

    // Arbitrate SRAM ports between Systolic compute read and AXI DMA / Preload write
    for (genvar gb = 0; gb < 8; gb++) begin : gen_bank_mem
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
                cin_0 <= (!mode_1x1_i && (tap_0 == 4'd0)) ? cin_0 : cin_0_p1;
            end
        end
    end

endmodule
