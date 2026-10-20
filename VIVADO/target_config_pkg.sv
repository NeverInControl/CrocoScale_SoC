`timescale 1ns / 1ps

/* ===============================================================================================
 * Target Configuration Package — Xilinx Vivado FPGA Emulation Flow
 * Disables FABulous tile ladder clocks so NPU clocks route on global FPGA clock networks.
 * =============================================================================================== */

package target_config_pkg;
    localparam int TARGET_USE_LADDER_CLOCKS = 0;
endpackage

