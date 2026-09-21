// =============================================================================
// File: SOFT_LOGIC/full/npu_seq_preload.sv
// Module: npu_seq_preload
// Project: CrocoScale SoC — Unified Sequencer Background DMA Preload Tracker
//
// Description:
//   Tracks activation input channel index (dma_channel_reg) and per-bank byte
//   pointers (dma_bank_ptr[0..5]) for background AXI streaming into idle SRAM banks
//   during 3x3 im2col systolic computation.
// =============================================================================

`timescale 1ns / 1ps

module npu_seq_preload #(
    parameter int CIN = 128
) (
    input  wire        clk_i,
    input  wire        rst_n,
    input  wire [2:0]  state_i,
    input  wire [7:0]  preload_cnt_i,
    input  wire [7:0]  pass_cnt_i,
    input  wire [8:0]  k_cnt_i,
    input  wire [8:0]  pass_len_i,
    input  wire [7:0]  total_passes_i,
    input  wire [5:0]  bank_read_used_i,

    output logic [6:0]      dma_channel_to_load_o,
    output logic [5:0][5:0] dma_bank_ptr_o,
    output logic [5:0]      dma_we_o,
    output logic [5:0][8:0] dma_addr_o
);

    localparam logic [2:0] SEQ_IDLE    = 3'd0;
    localparam logic [2:0] SEQ_PRELOAD = 3'd1;
    localparam logic [2:0] SEQ_COMPUTE = 3'd2;

    logic [5:0] dma_bank_ptr [6];
    logic [6:0] dma_channel_reg;
    logic [3:0] dma_mod9_cnt;
    logic [6:0] dma_next_ch;

    assign dma_channel_to_load_o = dma_channel_reg;
    for (genvar gb = 0; gb < 6; gb++) begin : gen_bank_ptr
        assign dma_bank_ptr_o[gb] = dma_bank_ptr[gb];
    end

    wire dma_channel_active = (dma_channel_reg > 7'd0);
    for (genvar gb = 0; gb < 6; gb++) begin : gen_bank_dma
        wire dma_write_active = (state_i == SEQ_COMPUTE && !bank_read_used_i[gb] && dma_channel_active && (dma_bank_ptr[gb] < 6'd54));
        assign dma_we_o[gb]   = dma_write_active;
        assign dma_addr_o[gb] = dma_write_active ? {dma_channel_reg[2:0], dma_bank_ptr[gb]} : 9'd0;
    end

    always_ff @(posedge clk_i or negedge rst_n) begin
        if (!rst_n) begin
            dma_channel_reg <= 7'd0;
            dma_mod9_cnt    <= 4'd0;
            dma_next_ch     <= 7'd0;
            for (int b = 0; b < 6; b++) dma_bank_ptr[b] <= '0;
        end else begin
            if (state_i == SEQ_IDLE) begin
                dma_channel_reg <= 7'd0;
                dma_mod9_cnt    <= 4'd0;
                dma_next_ch     <= 7'd0;
                for (int b = 0; b < 6; b++) dma_bank_ptr[b] <= '0;
            end else if (state_i == SEQ_PRELOAD && preload_cnt_i == 8'd53) begin
                dma_channel_reg <= 7'd1;
                dma_mod9_cnt    <= 4'd1;
                dma_next_ch     <= 7'd1;
                for (int b = 0; b < 6; b++) dma_bank_ptr[b] <= '0;
            end else if (state_i == SEQ_COMPUTE) begin
                for (int b = 0; b < 6; b++) begin
                    if (!bank_read_used_i[b] && dma_channel_reg > 7'd0 && dma_bank_ptr[b] < 6'd54) begin
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

                        for (int b = 0; b < 6; b++) dma_bank_ptr[b] <= '0;
                    end else begin
                        dma_channel_reg <= 7'd0;
                    end
                end
            end
        end
    end

endmodule

