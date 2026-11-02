`timescale 1ns / 1ps

/* ===============================================================================================
 * Target Configuration Package — Unified Compiler-Directive Flow
 *
 * Compiler Directives:
 * - Default (no defines) / TARGET_ASIC : TARGET_USE_LADDER_CLOCKS = 1
 * - TARGET_VIVADO                      : TARGET_USE_LADDER_CLOCKS = 0
 * =============================================================================================== */

package target_config_pkg;
`ifdef TARGET_VIVADO
    localparam int TARGET_USE_LADDER_CLOCKS = 0;
`else
    localparam int TARGET_USE_LADDER_CLOCKS = 1;
`endif
endpackage

