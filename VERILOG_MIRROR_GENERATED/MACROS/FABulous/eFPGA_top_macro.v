`timescale 1ns / 1ps

/* ===============================================================================================
 * FABulous eFPGA Fabric Hard Macro Blackbox Model
 * =============================================================================================== */

module eFPGA_top_macro #(
    parameter include_eFPGA     = 1,
    parameter NumberOfRows      = 10,
    parameter NumberOfCols      = 12,
    parameter FrameBitsPerRow   = 32,
    parameter MaxFramesPerCol   = 20,
    parameter desync_flag       = 20,
    parameter FrameSelectWidth  = 5,
    parameter RowSelectWidth    = 5
) (
    /* AXI-Lite Slave Interface */
    input  [9:0]   AXIL_S_SOC_ARADDR,
    output [0:0]   AXIL_S_SOC_ARREADY,
    input  [0:0]   AXIL_S_SOC_ARVALID,
    input  [9:0]   AXIL_S_SOC_AWADDR,
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
    output [7:0]   AXI_M_SOC_ARLEN,
    input  [0:0]   AXI_M_SOC_ARREADY,
    output [2:0]   AXI_M_SOC_ARSIZE,
    output [0:0]   AXI_M_SOC_ARVALID,
    output [31:0]  AXI_M_SOC_AWADDR,
    output [1:0]   AXI_M_SOC_AWBURST,
    output [7:0]   AXI_M_SOC_AWLEN,
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

    /* Dedicated NPU Hard Interface Ports */
    output [71:0]  NPU_ACT_ADDR,
    input  [63:0]  NPU_ACT_RDATA,
    output [63:0]  NPU_ACT_WDATA,
    output [7:0]   NPU_ACT_WE,
    output [63:0]  NPU_WEIGHT_IN,

    output [15:0]  NPU_ADDR,
    input  [63:0]  NPU_RDATA,
    output [5:0]   NPU_READ_BANK_SEL,
    output [63:0]  NPU_WDATA,
    output [15:0]  NPU_WE,

    /* RAM_IO Passthrough Wires */
    output [15:0]  RAM_A_O,
    output [7:0]   RAM_C_O,
    output [31:0]  RAM_D_O,
    input  [31:0]  RAM_D_I,
    output [7:0]   Config_accessC,

    /* General Purpose UIO */
    input  [119:0] UIO_TOP_UIN,
    output [119:0] UIO_TOP_UOUT,
    input  [199:0] UIO_BOT_UIN,
    output [199:0] UIO_BOT_UOUT,

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
    assign AXIL_S_SOC_ARREADY = 1'b0;
    assign AXIL_S_SOC_AWREADY = 1'b0;
    assign AXIL_S_SOC_BRESP   = 2'b00;
    assign AXIL_S_SOC_BVALID  = 1'b0;
    assign AXIL_S_SOC_RDATA   = 32'h0;
    assign AXIL_S_SOC_RRESP   = 2'b00;
    assign AXIL_S_SOC_RVALID  = 1'b0;
    assign AXIL_S_SOC_WREADY  = 1'b0;

    assign AXI_M_SOC_ARADDR   = 32'h0;
    assign AXI_M_SOC_ARBURST  = 2'b00;
    assign AXI_M_SOC_ARLEN    = 8'h0;
    assign AXI_M_SOC_ARSIZE   = 3'b000;
    assign AXI_M_SOC_ARVALID  = 1'b0;
    assign AXI_M_SOC_AWADDR   = 32'h0;
    assign AXI_M_SOC_AWBURST  = 2'b00;
    assign AXI_M_SOC_AWLEN    = 8'h0;
    assign AXI_M_SOC_AWSIZE   = 3'b000;
    assign AXI_M_SOC_AWVALID  = 1'b0;
    assign AXI_M_SOC_BREADY   = 1'b0;
    assign AXI_M_SOC_RREADY   = 1'b0;
    assign AXI_M_SOC_WDATA    = 32'h0;
    assign AXI_M_SOC_WLAST    = 1'b0;
    assign AXI_M_SOC_WSTRB    = 4'h0;
    assign AXI_M_SOC_WVALID   = 1'b0;

    assign NPU_ACT_ADDR       = 72'h0;
    assign NPU_ACT_WDATA      = 64'h0;
    assign NPU_ACT_WE         = 8'h0;
    assign NPU_WEIGHT_IN      = 64'h0;
    assign NPU_ADDR           = 16'h0;
    assign NPU_READ_BANK_SEL  = 6'h0;
    assign NPU_WDATA          = 64'h0;
    assign NPU_WE             = 16'h0;

    assign RAM_A_O            = 16'h0;
    assign RAM_C_O            = 8'h0;
    assign RAM_D_O            = 32'h0;
    assign Config_accessC     = 8'h0;

    assign UIO_TOP_UOUT       = 120'h0;
    assign UIO_BOT_UOUT       = 200'h0;

    assign ComActive          = 1'b0;
    assign ReceiveLED         = 1'b0;

endmodule

