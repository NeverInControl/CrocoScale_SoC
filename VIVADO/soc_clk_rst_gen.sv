`timescale 1ns / 1ps

/* ===============================================================================================
 * SoC Clock & Reset Synchronizer (Vivado Emulation Override)
 * Target: Xilinx Artix-7 (Digilent Nexys Video)
 * Divides 100 MHz board oscillator down to 10 MHz via BUFG and synchronizes active-low reset.
 * =============================================================================================== */

module soc_clk_rst_gen (
    input  logic clk_i,
    input  logic rstn_i,
    output logic sys_clk_o,
    output logic sys_rstn_o,
    output logic sys_rst_o
);

    logic [2:0] clk_div = 3'd0;
    logic       clk_10mhz_unbuf = 1'b0;

    always_ff @(posedge clk_i) begin
        if (clk_div == 3'd4) begin
            clk_div         <= 3'd0;
            clk_10mhz_unbuf <= ~clk_10mhz_unbuf;
        end else begin
            clk_div         <= clk_div + 3'd1;
        end
    end

    BUFG clk_bufg (
        .I (clk_10mhz_unbuf),
        .O (sys_clk_o)
    );

    (* ASYNC_REG = "TRUE" *) logic rst_sync_0, rst_sync_1;

    always_ff @(posedge sys_clk_o or negedge rstn_i) begin
        if (!rstn_i) begin
            rst_sync_0 <= 1'b0;
            rst_sync_1 <= 1'b0;
        end else begin
            rst_sync_0 <= 1'b1;
            rst_sync_1 <= rst_sync_0;
        end
    end

    assign sys_rstn_o = rst_sync_1;
    assign sys_rst_o  = ~rst_sync_1;

endmodule

