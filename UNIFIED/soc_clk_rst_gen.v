`timescale 1ns / 1ps

/* ===============================================================================================
 * Unified SoC Clock & Reset Synchronizer (Pure IEEE 1364-2001 Verilog)
 *
 * Compiler Directives:
 * - TARGET_VIVADO : Synthesizes a 10.000 MHz system clock from the 125 MHz board clock via
 *                   MMCME4_BASE + BUFG, inverts active-high pushbutton reset, and synchronizes
 *                   reset deassertion once the MMCM is locked.
 * - Default       : Routes external system clock directly and provides a 2-stage async-assert,
 *                   sync-deassert reset synchronizer (for Simulation and ASIC).
 * =============================================================================================== */

`ifdef TARGET_VIVADO

module soc_clk_rst_gen (
    input  wire clk_i,
    input  wire rstn_i,
    output wire sys_clk_o,
    output wire sys_rstn_o,
    output wire sys_rst_o
);

    wire clk_10mhz_unbuf;
    wire clkfb_unbuf;
    wire clkfb_buf;
    wire mmcm_locked;
    wire rstn_async;

    MMCME4_BASE #(
        .BANDWIDTH          ("OPTIMIZED"),
        .CLKFBOUT_MULT_F    (8.000),
        .CLKFBOUT_PHASE     (0.000),
        .CLKIN1_PERIOD      (8.000),
        .CLKOUT0_DIVIDE_F   (100.000),
        .CLKOUT0_DUTY_CYCLE (0.500),
        .CLKOUT0_PHASE      (0.000),
        .DIVCLK_DIVIDE      (1),
        .REF_JITTER1        (0.010),
        .STARTUP_WAIT       ("FALSE")
    ) u_mmcm_10mhz (
        .CLKOUT0  (clk_10mhz_unbuf),
        .CLKOUT0B (),
        .CLKOUT1  (),
        .CLKOUT1B (),
        .CLKOUT2  (),
        .CLKOUT2B (),
        .CLKOUT3  (),
        .CLKOUT3B (),
        .CLKOUT4  (),
        .CLKOUT5  (),
        .CLKOUT6  (),
        .CLKFBOUT (clkfb_unbuf),
        .CLKFBOUTB(),
        .LOCKED   (mmcm_locked),
        .CLKIN1   (clk_i),
        .PWRDWN   (1'b0),
        .RST      (1'b0),
        .CLKFBIN  (clkfb_buf)
    );

    BUFG u_clkfb_bufg (
        .I (clkfb_unbuf),
        .O (clkfb_buf)
    );

    BUFG u_sysclk_bufg (
        .I (clk_10mhz_unbuf),
        .O (sys_clk_o)
    );

    assign rstn_async = (~rstn_i) & mmcm_locked;

    (* ASYNC_REG = "TRUE" *) reg rst_sync_0, rst_sync_1;

    always @(posedge sys_clk_o or negedge rstn_async) begin
        if (!rstn_async) begin
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

`else

module soc_clk_rst_gen (
    input  wire clk_i,
    input  wire rstn_i,
    output wire sys_clk_o,
    output wire sys_rstn_o,
    output wire sys_rst_o
);

    assign sys_clk_o = clk_i;

    reg rst_sync_0, rst_sync_1;

    always @(posedge sys_clk_o or negedge rstn_i) begin
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

`endif

