`timescale 1ns / 1ps

(* FABulous, BelMap,
    TIE_OFF_AWLEN   = 0,
    TIE_OFF_AWSIZE  = 1,
    TIE_OFF_AWBURST = 2,
    TIE_OFF_AWLOCK  = 3,
    TIE_OFF_AWCACHE = 4,
    TIE_OFF_WSTRB   = 5,
    TIE_OFF_WLAST   = 6,
    TIE_OFF_ARLEN   = 7,
    TIE_OFF_ARSIZE  = 8,
    TIE_OFF_ARBURST = 9,
    TIE_OFF_ARLOCK  = 10,
    TIE_OFF_ARCACHE = 11
*)
module AXI_M_BEL #(
    parameter integer NoConfigBits = 12
)(
    // =========================================================================
    // SoC Facing Pins (Direct to Connector / Decoupler Skid Buffers)
    // =========================================================================
    (* FABulous, EXTERNAL *) output wire [31:0] SOC_AWADDR,
    (* FABulous, EXTERNAL *) output wire [7:0]  SOC_AWLEN,
    (* FABulous, EXTERNAL *) output wire [2:0]  SOC_AWSIZE,
    (* FABulous, EXTERNAL *) output wire [1:0]  SOC_AWBURST,
    (* FABulous, EXTERNAL *) output wire        SOC_AWLOCK,
    (* FABulous, EXTERNAL *) output wire [3:0]  SOC_AWCACHE,
    (* FABulous, EXTERNAL *) output wire        SOC_AWVALID,
    (* FABulous, EXTERNAL *) input  wire        SOC_AWREADY,

    (* FABulous, EXTERNAL *) output wire [31:0] SOC_WDATA,
    (* FABulous, EXTERNAL *) output wire [3:0]  SOC_WSTRB,
    (* FABulous, EXTERNAL *) output wire        SOC_WLAST,
    (* FABulous, EXTERNAL *) output wire        SOC_WVALID,
    (* FABulous, EXTERNAL *) input  wire        SOC_WREADY,

    (* FABulous, EXTERNAL *) input  wire [1:0]  SOC_BRESP,
    (* FABulous, EXTERNAL *) input  wire        SOC_BVALID,
    (* FABulous, EXTERNAL *) output wire        SOC_BREADY,

    (* FABulous, EXTERNAL *) output wire [31:0] SOC_ARADDR,
    (* FABulous, EXTERNAL *) output wire [7:0]  SOC_ARLEN,
    (* FABulous, EXTERNAL *) output wire [2:0]  SOC_ARSIZE,
    (* FABulous, EXTERNAL *) output wire [1:0]  SOC_ARBURST,
    (* FABulous, EXTERNAL *) output wire        SOC_ARLOCK,
    (* FABulous, EXTERNAL *) output wire [3:0]  SOC_ARCACHE,
    (* FABulous, EXTERNAL *) output wire        SOC_ARVALID,
    (* FABulous, EXTERNAL *) input  wire        SOC_ARREADY,

    (* FABulous, EXTERNAL *) input  wire [31:0] SOC_RDATA,
    (* FABulous, EXTERNAL *) input  wire [1:0]  SOC_RRESP,
    (* FABulous, EXTERNAL *) input  wire        SOC_RLAST,
    (* FABulous, EXTERNAL *) input  wire        SOC_RVALID,
    (* FABulous, EXTERNAL *) output wire        SOC_RREADY,

    // =========================================================================
    // Fabric Facing Pins (Switch Matrix Routing)
    // =========================================================================
    input  wire [31:0] FAB_AWADDR,
    input  wire [7:0]  FAB_AWLEN,
    input  wire [2:0]  FAB_AWSIZE,
    input  wire [1:0]  FAB_AWBURST,
    input  wire        FAB_AWLOCK,
    input  wire [3:0]  FAB_AWCACHE,
    input  wire        FAB_AWVALID,
    output wire        FAB_AWREADY,

    input  wire [31:0] FAB_WDATA,
    input  wire [3:0]  FAB_WSTRB,
    input  wire        FAB_WLAST,
    input  wire        FAB_WVALID,
    output wire        FAB_WREADY,

    output wire [1:0]  FAB_BRESP,
    output wire        FAB_BVALID,
    input  wire        FAB_BREADY,

    input  wire [31:0] FAB_ARADDR,
    input  wire [7:0]  FAB_ARLEN,
    input  wire [2:0]  FAB_ARSIZE,
    input  wire [1:0]  FAB_ARBURST,
    input  wire        FAB_ARLOCK,
    input  wire [3:0]  FAB_ARCACHE,
    input  wire        FAB_ARVALID,
    output wire        FAB_ARREADY,

    output wire [31:0] FAB_RDATA,
    output wire [1:0]  FAB_RRESP,
    output wire        FAB_RLAST,
    output wire        FAB_RVALID,
    input  wire        FAB_RREADY,

    // Static Tie-off Configuration Bits
    (* FABulous, GLOBAL *) input wire [NoConfigBits-1:0] ConfigBits
);

    // -------------------------------------------------------------------------
    // Fabric -> SoC (Asynchronous Pass-Through with Configurable Tie-Offs)
    // -------------------------------------------------------------------------
    assign SOC_AWADDR  = FAB_AWADDR;
    assign SOC_AWLEN   = ConfigBits[0] ? 8'd0 : FAB_AWLEN;
    assign SOC_AWSIZE  = ConfigBits[1] ? 3'b010 : FAB_AWSIZE;
    assign SOC_AWBURST = ConfigBits[2] ? 2'b01 : FAB_AWBURST;
    assign SOC_AWLOCK  = ConfigBits[3] ? 1'b0 : FAB_AWLOCK;
    assign SOC_AWCACHE = ConfigBits[4] ? 4'b0011 : FAB_AWCACHE;
    assign SOC_AWVALID = FAB_AWVALID;

    assign SOC_WDATA   = FAB_WDATA;
    assign SOC_WSTRB   = ConfigBits[5] ? 4'b1111 : FAB_WSTRB;
    assign SOC_WLAST   = ConfigBits[6] ? 1'b1 : FAB_WLAST;
    assign SOC_WVALID  = FAB_WVALID;

    assign SOC_BREADY  = FAB_BREADY;

    assign SOC_ARADDR  = FAB_ARADDR;
    assign SOC_ARLEN   = ConfigBits[7] ? 8'd0 : FAB_ARLEN;
    assign SOC_ARSIZE  = ConfigBits[8] ? 3'b010 : FAB_ARSIZE;
    assign SOC_ARBURST = ConfigBits[9] ? 2'b01 : FAB_ARBURST;
    assign SOC_ARLOCK  = ConfigBits[10] ? 1'b0 : FAB_ARLOCK;
    assign SOC_ARCACHE = ConfigBits[11] ? 4'b0011 : FAB_ARCACHE;
    assign SOC_ARVALID = FAB_ARVALID;

    assign SOC_RREADY  = FAB_RREADY;

    // -------------------------------------------------------------------------
    // SoC -> Fabric (Asynchronous Pass-Through)
    // -------------------------------------------------------------------------
    assign FAB_AWREADY = SOC_AWREADY;
    assign FAB_WREADY  = SOC_WREADY;
    assign FAB_BRESP   = SOC_BRESP;
    assign FAB_BVALID  = SOC_BVALID;
    assign FAB_ARREADY = SOC_ARREADY;
    assign FAB_RDATA   = SOC_RDATA;
    assign FAB_RRESP   = SOC_RRESP;
    assign FAB_RLAST   = SOC_RLAST;
    assign FAB_RVALID  = SOC_RVALID;

endmodule
