`timescale 1ns / 1ps

/* ===============================================================================================
 * SoC Clock & Reset Synchronizer (Vivado Emulation Override)
 * Target: Xilinx Virtex UltraScale+ (AMD VCU118 Evaluation Kit)
 * Synthesizes an exact 10.000 MHz system clock from the 125 MHz board clock via MMCME4_BASE
 * (125 MHz * 8 / 100 = 10.000 MHz), inverts the active-high pushbutton reset, and synchronizes
 * reset deassertion once the MMCM is locked.
 * =============================================================================================== */

module soc_clk_rst_gen (
    input  logic clk_i,
    input  logic rstn_i,
    output logic sys_clk_o,
    output logic sys_rstn_o,
    output logic sys_rst_o
);

    logic clk_10mhz_unbuf;
    logic clkfb_unbuf;
    logic clkfb_buf;
    logic mmcm_locked;
    logic rstn_async;

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

    // VCU118 pushbuttons are active-high when pressed; invert and hold in reset until MMCM locks
    assign rstn_async = (~rstn_i) & mmcm_locked;

    (* ASYNC_REG = "TRUE" *) logic rst_sync_0, rst_sync_1;

    always_ff @(posedge sys_clk_o or negedge rstn_async) begin
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

