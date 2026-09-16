// =============================================================================
// File: SOFT_LOGIC/npu_seq_addr_3x3.sv
// Module: npu_seq_addr_3x3
// Project: CrocoScale SoC — 3x3 im2col Address Generator & Memory Arbiter
//
// Description:
//   Pure combinational orthogonal address and crossbar decoding for 3x3 convolution
//   across 6 activation SRAM banks. Tracks idle banks and manages background DMA
//   channel preloading.
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

    // Combinational function for orthogonal SRAM bank mapping
    function automatic [11:0] calc_sram_loc(
        input [6:0] cin_idx,
        input [4:0] ly,
        input [4:0] lx
    );
        logic h;
        logic [3:0] x_off;
        logic [2:0] ly_div;
        logic [1:0] ly_mod;
        logic [2:0] bank;
        logic [8:0] addr;

        h      = (lx >= 5'd9);
        x_off  = h ? (lx[3:0] - 4'd9) : lx[3:0];
        ly_div = 3'(ly / 3);
        ly_mod = 2'(ly % 3);

        bank = {1'b0, ly_mod, h};
        addr = {cin_idx[2:0], 6'b0} + (ly_div * 4'd9) + {5'b0, x_off};
        return {bank, addr};
    endfunction

    // Compute address generation per systolic row
    logic [ARRAY_HEIGHT-1:0]      row_active;
    logic [ARRAY_HEIGHT-1:0][2:0] row_target_bank;
    logic [ARRAY_HEIGHT-1:0][8:0] row_target_addr;

    always_comb begin
        for (int r = 0; r < ARRAY_HEIGHT; r++) begin
            int m_p;
            int g_idx;
            m_p   = int'(k_cnt_i) - r;
            g_idx = int'(pass_cnt_i) * 8 + r;

            if (state_i == SEQ_COMPUTE && m_p >= 0 && m_p < 256 && g_idx < K_TOTAL) begin
                int cin_curr, tap_curr, ky_curr, kx_curr, out_y, out_x;
                logic [4:0] target_ly, target_lx;
                logic [11:0] loc;

                cin_curr = g_idx / 9;
                tap_curr = g_idx % 9;
                ky_curr  = tap_curr / 3;
                kx_curr  = tap_curr % 3;
                out_y    = m_p / 16;
                out_x    = m_p % 16;

                target_ly = 5'(out_y + ky_curr);
                target_lx = 5'(out_x + kx_curr);

                loc = calc_sram_loc(7'(cin_curr), target_ly, target_lx);

                row_active[r]      = 1'b1;
                row_target_bank[r] = loc[11:9];
                row_target_addr[r] = loc[8:0];
                crossbar_sel_o[r]  = {1'b0, loc[11:9]};
            end else begin
                row_active[r]      = 1'b0;
                row_target_bank[r] = 3'd0;
                row_target_addr[r] = 9'd0;
                crossbar_sel_o[r]  = 4'b1000;
            end
        end
    end

    // Detect which banks are actively being read this cycle
    logic [5:0] bank_read_used;
    logic [5:0][8:0] bank_read_addr;

    always_comb begin
        for (int b = 0; b < 6; b++) begin
            bank_read_used[b] = 1'b0;
            bank_read_addr[b] = 9'd0;
            for (int r = 0; r < ARRAY_HEIGHT; r++) begin
                if (row_active[r] && (row_target_bank[r] == 3'(b))) begin
                    bank_read_used[b] = 1'b1;
                    bank_read_addr[b] = row_target_addr[r];
                end
            end
        end
    end

    // Arbitration: prioritize active compute reads; if bank is idle, allow background DMA write
    for (genvar gb = 0; gb < 6; gb++) begin : gen_bank_mem
        assign act_sram_we_o[gb] = (state_i == SEQ_PRELOAD) ? 1'b1 :
                                   (state_i == SEQ_COMPUTE && !bank_read_used[gb] && dma_channel_reg > 7'd0 && dma_bank_ptr[gb] < 6'd54) ? 1'b1 : 1'b0;

        assign act_sram_addr_o[gb] = (state_i == SEQ_PRELOAD) ? {3'b000, preload_cnt_i[5:0]} :
                                     (state_i == SEQ_COMPUTE && bank_read_used[gb]) ? bank_read_addr[gb] :
                                     (state_i == SEQ_COMPUTE && !bank_read_used[gb] && dma_channel_reg > 7'd0 && dma_bank_ptr[gb] < 6'd54) ? ({dma_channel_reg[2:0], 6'b0} + {3'b0, dma_bank_ptr[gb]}) : 9'd0;
    end

    // DMA channel schedule lookup
    function automatic logic [6:0] get_dma_channel(input [7:0] p);
        for (int ch = 1; ch < CIN; ch++) begin
            if (((9 * ch) / 8) - 1 == int'(p)) begin
                return 7'(ch);
            end
        end
        return 7'd0;
    endfunction

    // Advance DMA bank pointers on successful background writes
    always_ff @(posedge clk_i or negedge rst_n) begin
        if (!rst_n) begin
            dma_channel_reg <= 7'd0;
            for (int b = 0; b < 6; b++) dma_bank_ptr[b] <= '0;
        end else begin
            if (state_i == SEQ_IDLE) begin
                dma_channel_reg <= 7'd0;
                for (int b = 0; b < 6; b++) dma_bank_ptr[b] <= '0;
            end else if (state_i == SEQ_PRELOAD && preload_cnt_i == 8'd53) begin
                dma_channel_reg <= get_dma_channel(8'd0);
                for (int b = 0; b < 6; b++) dma_bank_ptr[b] <= '0;
            end else if (state_i == SEQ_COMPUTE) begin
                for (int b = 0; b < 6; b++) begin
                    if (!bank_read_used[b] && dma_channel_reg > 7'd0 && dma_bank_ptr[b] < 6'd54) begin
                        dma_bank_ptr[b] <= dma_bank_ptr[b] + 1'b1;
                    end
                end

                if (k_cnt_i == pass_len_i - 1'b1) begin
                    if (pass_cnt_i + 1'b1 < total_passes_i) begin
                        dma_channel_reg <= get_dma_channel(pass_cnt_i + 1'b1);
                        for (int b = 0; b < 6; b++) dma_bank_ptr[b] <= '0;
                    end else begin
                        dma_channel_reg <= 7'd0;
                    end
                end
            end
        end
    end

endmodule

