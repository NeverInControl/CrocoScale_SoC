`timescale 1ns / 1ps

/* ===============================================================================================
 * FABulous eFPGA Fabric Hard Macro Blackbox Model
 * Drop-in replacement for FABulous eFPGA_top.v
 * =============================================================================================== */

(* blackbox *)
module eFPGA_top #(
    parameter include_eFPGA     = 1,
    parameter NumberOfRows      = 18,
    parameter NumberOfCols      = 11,
    parameter FrameBitsPerRow   = 32,
    parameter MaxFramesPerCol   = 20,
    parameter desync_flag       = 20,
    parameter FrameSelectWidth  = 5,
    parameter RowSelectWidth    = 5
) (
    /* AXI-Lite Slave Interface */
    input  [9:0]   AXIL_S_SOC_ARADDR,
    input  [2:0]   AXIL_S_SOC_ARPROT,
    output [0:0]   AXIL_S_SOC_ARREADY,
    input  [0:0]   AXIL_S_SOC_ARVALID,
    input  [9:0]   AXIL_S_SOC_AWADDR,
    input  [2:0]   AXIL_S_SOC_AWPROT,
    output [0:0]   AXIL_S_SOC_AWREADY,
    input  [0:0]   AXIL_S_SOC_AWVALID,
    input  [0:0]   AXIL_S_SOC_BREADY,
    output [1:0]   AXIL_S_SOC_BRESP,
    output [0:0]   AXIL_S_SOC_BVALID,
    output [31:0]  AXIL_S_SOC_RDATA,
    input  [0:0]   AXIL_S_SOC_RREADY,
    output [1:0]   AXIL_S_SOC_RRESP,
    output [0:0]   AXIL_S_SOC_RVALID,
    input  [31:0]  AXIL_S_SOC_WDATA,
    output [0:0]   AXIL_S_SOC_WREADY,
    input  [3:0]   AXIL_S_SOC_WSTRB,
    input  [0:0]   AXIL_S_SOC_WVALID,

    /* AXI4 Master Interface */
    output [31:0]  AXI_M_SOC_ARADDR,
    output [1:0]   AXI_M_SOC_ARBURST,
    output [3:0]   AXI_M_SOC_ARCACHE,
    output [7:0]   AXI_M_SOC_ARLEN,
    output [0:0]   AXI_M_SOC_ARLOCK,
    input  [0:0]   AXI_M_SOC_ARREADY,
    output [2:0]   AXI_M_SOC_ARSIZE,
    output [0:0]   AXI_M_SOC_ARVALID,
    output [31:0]  AXI_M_SOC_AWADDR,
    output [1:0]   AXI_M_SOC_AWBURST,
    output [3:0]   AXI_M_SOC_AWCACHE,
    output [7:0]   AXI_M_SOC_AWLEN,
    output [0:0]   AXI_M_SOC_AWLOCK,
    input  [0:0]   AXI_M_SOC_AWREADY,
    output [2:0]   AXI_M_SOC_AWSIZE,
    output [0:0]   AXI_M_SOC_AWVALID,
    output [0:0]   AXI_M_SOC_BREADY,
    input  [1:0]   AXI_M_SOC_BRESP,
    input  [0:0]   AXI_M_SOC_BVALID,
    input  [31:0]  AXI_M_SOC_RDATA,
    input  [0:0]   AXI_M_SOC_RLAST,
    output [0:0]   AXI_M_SOC_RREADY,
    input  [1:0]   AXI_M_SOC_RRESP,
    input  [0:0]   AXI_M_SOC_RVALID,
    output [31:0]  AXI_M_SOC_WDATA,
    output [0:0]   AXI_M_SOC_WLAST,
    input  [0:0]   AXI_M_SOC_WREADY,
    output [3:0]   AXI_M_SOC_WSTRB,
    output [0:0]   AXI_M_SOC_WVALID,

    /* Debug & Slot Control */
    output [31:0]  DEBUG_IN,
    input  [31:0]  DEBUG_OUT,
    output [7:0]   FAB_USER_CLK,
    input  [3:0]   SLOT_SOFT_RST_N,
    output [3:0]   USR_IRQ,

    /* Dedicated NPU Complex Interconnect */
    output [71:0]  NPU_ACT_ADDR,
    input  [63:0]  NPU_ACT_RDATA,
    output [63:0]  NPU_ACT_WDATA,
    output [7:0]   NPU_ACT_WE,
    output [15:0]  NPU_ADDR,
    output [0:0]   NPU_ARRAY_EN,
    output [0:0]   NPU_COMPUTE_BANK_SWAP,
    input  [63:0]  NPU_OUT_ACT,
    output [0:0]   NPU_PSUM_LUT_EN,
    output [0:0]   NPU_PSUM_SKEW_EN,
    output [0:0]   NPU_PSUM_SYSTOLIC_EN,
    output [0:0]   NPU_QUANT_SHIFT_EN,
    output [29:0]  NPU_QUANT_SHIFT_IN,
    input  [63:0]  NPU_RDATA,
    output [5:0]   NPU_READ_BANK_SEL,
    output [0:0]   NPU_SWAP_WEIGHTS,
    output [63:0]  NPU_WDATA,
    output [15:0]  NPU_WE,
    output [63:0]  NPU_WEIGHT_IN,
    output [7:0]   NPU_WEIGHT_SHIFT_EN,
    output [31:0]  NPU_XBAR_SEL,

    /* External PMOD Padring */
    input  [7:0]   PMOD_IO_I,
    output [7:0]   PMOD_IO_O,
    output [7:0]   PMOD_IO_OE_O,

    /* Configuration & Clocking */
    input          CLK,
    input          resetn,
    input          SelfWriteStrobe,
    input  [31:0]  SelfWriteData,
    input          Rx,
    output         ComActive,
    output         ReceiveLED,
    input          s_clk,
    input          s_data
);

    /* Stub default assignments for macro elaboration */
    assign AXIL_S_SOC_ARREADY    = 1'b0;
    assign AXIL_S_SOC_AWREADY    = 1'b0;
    assign AXIL_S_SOC_BRESP      = 2'b00;
    assign AXIL_S_SOC_BVALID     = 1'b0;
    assign AXIL_S_SOC_RDATA      = 32'h0;
    assign AXIL_S_SOC_RRESP      = 2'b00;
    assign AXIL_S_SOC_RVALID     = 1'b0;
    assign AXIL_S_SOC_WREADY     = 1'b0;

    assign AXI_M_SOC_ARADDR      = 32'h0;
    assign AXI_M_SOC_ARBURST     = 2'b00;
    assign AXI_M_SOC_ARCACHE     = 4'h0;
    assign AXI_M_SOC_ARLEN       = 8'h0;
    assign AXI_M_SOC_ARLOCK      = 1'b0;
    assign AXI_M_SOC_ARSIZE      = 3'b000;
    assign AXI_M_SOC_ARVALID     = 1'b0;
    assign AXI_M_SOC_AWADDR      = 32'h0;
    assign AXI_M_SOC_AWBURST     = 2'b00;
    assign AXI_M_SOC_AWCACHE     = 4'h0;
    assign AXI_M_SOC_AWLEN       = 8'h0;
    assign AXI_M_SOC_AWLOCK      = 1'b0;
    assign AXI_M_SOC_AWSIZE      = 3'b000;
    assign AXI_M_SOC_AWVALID     = 1'b0;
    assign AXI_M_SOC_BREADY      = 1'b0;
    assign AXI_M_SOC_RREADY      = 1'b0;
    assign AXI_M_SOC_WDATA       = 32'h0;
    assign AXI_M_SOC_WLAST       = 1'b0;
    assign AXI_M_SOC_WSTRB       = 4'h0;
    assign AXI_M_SOC_WVALID      = 1'b0;

    assign DEBUG_IN              = 32'h0;
    assign FAB_USER_CLK          = {8{CLK}};
    assign USR_IRQ               = 4'h0;

    assign NPU_ACT_ADDR          = 72'h0;
    assign NPU_ACT_WDATA         = 64'h0;
    assign NPU_ACT_WE            = 8'h0;
    assign NPU_ADDR              = 16'h0;
    assign NPU_ARRAY_EN          = 1'b0;
    assign NPU_COMPUTE_BANK_SWAP = 1'b0;
    assign NPU_PSUM_LUT_EN       = 1'b0;
    assign NPU_PSUM_SKEW_EN      = 1'b0;
    assign NPU_PSUM_SYSTOLIC_EN  = 1'b0;
    assign NPU_QUANT_SHIFT_EN    = 1'b0;
    assign NPU_QUANT_SHIFT_IN    = 30'h0;
    assign NPU_READ_BANK_SEL     = 6'h0;
    assign NPU_SWAP_WEIGHTS      = 1'b0;
    assign NPU_WDATA             = 64'h0;
    assign NPU_WE                = 16'h0;
    assign NPU_WEIGHT_IN         = 64'h0;
    assign NPU_WEIGHT_SHIFT_EN   = 8'h0;
    assign NPU_XBAR_SEL          = 32'h0;

    assign PMOD_IO_O             = 8'h0;
    assign PMOD_IO_OE_O          = 8'h0;

    assign ComActive             = 1'b0;
    assign ReceiveLED            = 1'b0;

endmodule
