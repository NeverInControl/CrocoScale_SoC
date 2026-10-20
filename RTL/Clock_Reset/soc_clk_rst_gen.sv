`timescale 1ns / 1ps

/* ===============================================================================================
 * SoC Clock & Reset Synchronizer (Default / Simulation / ASIC)
 *
 * Routes external system clock directly and provides a 2-stage async-assert, sync-deassert
 * reset synchronizer. Target-specific Vivado filelists swap this module for
 * VIVADO/soc_clk_rst_gen.sv (which adds the 100 MHz -> 10 MHz divider and BUFG).
 * =============================================================================================== */

module soc_clk_rst_gen (
    input  logic clk_i,
    input  logic rstn_i,
    output logic sys_clk_o,
    output logic sys_rstn_o,
    output logic sys_rst_o
);

    assign sys_clk_o = clk_i;

    logic rst_sync_0, rst_sync_1;

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

