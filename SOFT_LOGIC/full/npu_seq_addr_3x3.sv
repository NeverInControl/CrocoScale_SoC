// =============================================================================
// File: SOFT_LOGIC/full/npu_seq_addr_3x3.sv
// Module: npu_seq_addr_3x3
// Project: CrocoScale SoC — 3x3 im2col Address Generator & Memory Arbiter
//
// Description:
//   Lean, optimized orthogonal address generator and memory arbiter for 3x3
//   convolution across 6 activation SRAM banks. Replaces unconstrained 32-bit
//   generic dividers with compact lookup functions and bit-slice math.
// =============================================================================

`timescale 1ns / 1ps

module npu_seq_addr_3x3 #(
    parameter int ARRAY_HEIGHT = 8,
    parameter int CIN          = 128
) (
    input  wire        clk_i,
    input  wire        rst_n,
    input  wire [2:0]  state_i,
    input  wire        preload_phase_i,
    input  wire [7:0]  preload_cnt_i,
    input  wire [7:0]  pass_cnt_i,
    input  wire [8:0]  k_cnt_i,
    input  wire [8:0]  pass_len_i,
    input  wire [7:0]  total_passes_i,

    output logic [ARRAY_HEIGHT-1:0][3:0] crossbar_sel_o,
    output logic [5:0]                   act_sram_we_o,
    output logic [5:0][8:0]              act_sram_addr_o,
    output logic [6:0]                   dma_channel_to_load_o,
    output logic [5:0][5:0]              dma_bank_ptr_o
);

    localparam logic [2:0] SEQ_IDLE    = 3'd0;
    localparam logic [2:0] SEQ_PRELOAD = 3'd1;
    localparam logic [2:0] SEQ_COMPUTE = 3'd2;
    localparam int K_TOTAL = CIN * 9;

    logic [5:0] dma_bank_ptr [6];
    logic [6:0] dma_channel_reg;

    assign dma_channel_to_load_o = dma_channel_reg;
    for (genvar gb = 0; gb < 6; gb++) begin : gen_bank_ptr
        assign dma_bank_ptr_o[gb] = dma_bank_ptr[gb];
    end

    // Compact decode of ly (0..17) -> {ly_mod[1:0], ly_mul9[5:0]}
    function automatic [7:0] get_ly_data(input [4:0] ly);
        case (ly)
            5'd0:  return {2'd0, 6'd0};
            5'd1:  return {2'd1, 6'd0};
            5'd2:  return {2'd2, 6'd0};
            5'd3:  return {2'd0, 6'd9};
            5'd4:  return {2'd1, 6'd9};
            5'd5:  return {2'd2, 6'd9};
            5'd6:  return {2'd0, 6'd18};
            5'd7:  return {2'd1, 6'd18};
            5'd8:  return {2'd2, 6'd18};
            5'd9:  return {2'd0, 6'd27};
            5'd10: return {2'd1, 6'd27};
            5'd11: return {2'd2, 6'd27};
            5'd12: return {2'd0, 6'd36};
            5'd13: return {2'd1, 6'd36};
            5'd14: return {2'd2, 6'd36};
            5'd15: return {2'd0, 6'd45};
            5'd16: return {2'd1, 6'd45};
            5'd17: return {2'd2, 6'd45};
            default: return 8'd0;
        endcase
    endfunction

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

    logic [6:0] cin_0;
    logic [3:0] tap_0;
    logic [3:0] dma_mod9_cnt;
    logic [6:0] dma_next_ch;

    // Compute address generation per systolic row
    logic [ARRAY_HEIGHT-1:0]      row_active;
    logic [ARRAY_HEIGHT-1:0][2:0] row_target_bank;
    logic [ARRAY_HEIGHT-1:0][8:0] row_target_addr;

    always_comb begin
        for (int r = 0; r < ARRAY_HEIGHT; r++) begin
            logic [8:0]  m_p;
            logic        m_p_valid;
            logic [10:0] g_idx;
            logic [4:0]  tap_sum;
            logic [3:0]  tap_curr;
            logic [6:0]  cin_curr;
            logic [3:0]  tap_data;
            logic [1:0]  ky_curr, kx_curr;
            logic [3:0]  out_y, out_x;
            logic [4:0]  target_ly, target_lx;
            logic        h;
            logic [3:0]  x_off;
            logic [7:0]  ly_data;
            logic [1:0]  ly_mod;
            logic [5:0]  ly_mul9;
            logic [2:0]  bank;
            logic [5:0]  page_addr;

            m_p       = k_cnt_i - 9'(r);
            m_p_valid = (k_cnt_i >= 9'(r)) && !m_p[8];
            g_idx     = {pass_cnt_i, 3'b000} + 11'(r);

            tap_sum   = {1'b0, tap_0} + 5'(r);
            tap_curr  = (tap_sum >= 5'd9) ? 4'(tap_sum - 5'd9) : tap_sum[3:0];
            cin_curr  = (tap_sum >= 5'd9) ? (cin_0 + 7'd1) : cin_0;

            tap_data = get_tap_data(tap_curr);
            ky_curr  = tap_data[3:2];
            kx_curr  = tap_data[1:0];

            out_y = m_p[7:4];
            out_x = m_p[3:0];

            target_ly = 5'({1'b0, out_y} + {3'b0, ky_curr});
            target_lx = 5'({1'b0, out_x} + {3'b0, kx_curr});

            h     = (target_lx >= 5'd9);
            x_off = h ? (target_lx[3:0] - 4'd9) : target_lx[3:0];

            ly_data = get_ly_data(target_ly);
            ly_mod  = ly_data[7:6];
            ly_mul9 = ly_data[5:0];

            bank      = {1'b0, ly_mod, h};
            page_addr = ly_mul9 + {2'b0, x_off};

            row_active[r]      = (state_i == SEQ_COMPUTE) && m_p_valid && (g_idx < K_TOTAL);
            row_target_bank[r] = bank;
            row_target_addr[r] = {cin_curr[2:0], page_addr};
            crossbar_sel_o[r]  = row_active[r] ? {1'b0, bank} : 4'b1000;
        end
    end

    // Detect which banks are actively being read this cycle
    logic [5:0] bank_read_used;
    logic [5:0][8:0] bank_read_addr;

    always_comb begin
        for (int b = 0; b < 6; b++) begin
            logic [ARRAY_HEIGHT-1:0] match;
            logic [8:0] addr_accum;

            for (int r = 0; r < ARRAY_HEIGHT; r++) begin
                match[r] = row_active[r] && (row_target_bank[r] == 3'(b));
            end
            bank_read_used[b] = |match;

            addr_accum = 9'd0;
            for (int r = 0; r < ARRAY_HEIGHT; r++) begin
                addr_accum = addr_accum | (match[r] ? row_target_addr[r] : 9'd0);
            end
            bank_read_addr[b] = addr_accum;
        end
    end

    wire dma_channel_active = (dma_channel_reg > 7'd0);
    for (genvar gb = 0; gb < 6; gb++) begin : gen_bank_mem
        wire dma_write_active = (state_i == SEQ_COMPUTE && !bank_read_used[gb] && dma_channel_active && (dma_bank_ptr[gb] < 6'd54));
        assign act_sram_we_o[gb] = (state_i == SEQ_PRELOAD) ? 1'b1 : dma_write_active;

        assign act_sram_addr_o[gb] = (state_i == SEQ_PRELOAD) ? {3'b000, preload_cnt_i[5:0]} :
                                     (state_i == SEQ_COMPUTE && bank_read_used[gb]) ? bank_read_addr[gb] :
                                     dma_write_active ? {dma_channel_reg[2:0], dma_bank_ptr[gb]} : 9'd0;
    end

    always_ff @(posedge clk_i or negedge rst_n) begin
        if (!rst_n) begin
            dma_channel_reg <= 7'd0;
            dma_mod9_cnt    <= 4'd0;
            dma_next_ch     <= 7'd0;
            cin_0           <= 7'd0;
            tap_0           <= 4'd0;
            for (int b = 0; b < 6; b++) dma_bank_ptr[b] <= '0;
        end else begin
            if (state_i == SEQ_IDLE) begin
                dma_channel_reg <= 7'd0;
                dma_mod9_cnt    <= 4'd0;
                dma_next_ch     <= 7'd0;
                cin_0           <= 7'd0;
                tap_0           <= 4'd0;
                for (int b = 0; b < 6; b++) dma_bank_ptr[b] <= '0;
            end else if (state_i == SEQ_PRELOAD && preload_cnt_i == 8'd53) begin
                dma_channel_reg <= 7'd1;
                dma_mod9_cnt    <= 4'd1;
                dma_next_ch     <= 7'd1;
                cin_0           <= 7'd0;
                tap_0           <= 4'd0;
                for (int b = 0; b < 6; b++) dma_bank_ptr[b] <= '0;
            end else if (state_i == SEQ_COMPUTE) begin
                for (int b = 0; b < 6; b++) begin
                    if (!bank_read_used[b] && dma_channel_reg > 7'd0 && dma_bank_ptr[b] < 6'd54) begin
                        dma_bank_ptr[b] <= dma_bank_ptr[b] + 1'b1;
                    end
                end

                if (k_cnt_i == pass_len_i - 1'b1) begin
                    if (pass_cnt_i + 1'b1 < total_passes_i) begin
                        logic [3:0] next_mod;
                        logic [6:0] next_ch_val;

                        next_mod    = (dma_mod9_cnt == 4'd8) ? 4'd0 : (dma_mod9_cnt + 4'd1);
                        next_ch_val = (dma_mod9_cnt == 4'd8) ? dma_next_ch : (dma_next_ch + 7'd1);

                        dma_mod9_cnt <= next_mod;
                        dma_next_ch  <= next_ch_val;
                        if (next_mod == 4'd8 || {1'b0, next_ch_val} >= 8'(CIN)) begin
                            dma_channel_reg <= 7'd0;
                        end else begin
                            dma_channel_reg <= next_ch_val;
                        end

                        tap_0 <= (tap_0 == 4'd0) ? 4'd8 : (tap_0 - 4'd1);
                        cin_0 <= (tap_0 == 4'd0) ? cin_0 : (cin_0 + 7'd1);

                        for (int b = 0; b < 6; b++) dma_bank_ptr[b] <= '0;
                    end else begin
                        dma_channel_reg <= 7'd0;
                    end
                end
            end
        end
    end

endmodule
