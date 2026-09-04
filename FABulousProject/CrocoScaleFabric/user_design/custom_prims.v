
//Warning: The primitive InPass4_frame_config_mux was added by FABulous automatically.
(* blackbox, keep *)
module InPass4_frame_config_mux (
    output O0,
    output O1,
    output O2,
    output O3,
    (* iopad_external_pin *)
    input I0,
    (* iopad_external_pin *)
    input I1,
    (* iopad_external_pin *)
    input I2,
    (* iopad_external_pin *)
    input I3,
    input CLK
);
    parameter I0_reg = 0;
    parameter I1_reg = 0;
    parameter I2_reg = 0;
    parameter I3_reg = 0;
endmodule

//Warning: The primitive OutPass4_frame_config_mux was added by FABulous automatically.
(* blackbox, keep *)
module OutPass4_frame_config_mux (
    input I0,
    input I1,
    input I2,
    input I3,
    (* iopad_external_pin *)
    output O0,
    (* iopad_external_pin *)
    output O1,
    (* iopad_external_pin *)
    output O2,
    (* iopad_external_pin *)
    output O3,
    input CLK
);
    parameter I0_reg = 0;
    parameter I1_reg = 0;
    parameter I2_reg = 0;
    parameter I3_reg = 0;
endmodule

//Warning: The primitive AXI4_FULL_MASTER_BEL was added by FABulous automatically.
(* blackbox, keep *)
module AXI_M_BEL (
    input FAB_AWADDR0,
    input FAB_AWADDR1,
    input FAB_AWADDR2,
    input FAB_AWADDR3,
    input FAB_AWADDR4,
    input FAB_AWADDR5,
    input FAB_AWADDR6,
    input FAB_AWADDR7,
    input FAB_AWADDR8,
    input FAB_AWADDR9,
    input FAB_AWADDR10,
    input FAB_AWADDR11,
    input FAB_AWADDR12,
    input FAB_AWADDR13,
    input FAB_AWADDR14,
    input FAB_AWADDR15,
    input FAB_AWADDR16,
    input FAB_AWADDR17,
    input FAB_AWADDR18,
    input FAB_AWADDR19,
    input FAB_AWADDR20,
    input FAB_AWADDR21,
    input FAB_AWADDR22,
    input FAB_AWADDR23,
    input FAB_AWADDR24,
    input FAB_AWADDR25,
    input FAB_AWADDR26,
    input FAB_AWADDR27,
    input FAB_AWADDR28,
    input FAB_AWADDR29,
    input FAB_AWADDR30,
    input FAB_AWADDR31,
    input FAB_AWLEN0,
    input FAB_AWLEN1,
    input FAB_AWLEN2,
    input FAB_AWLEN3,
    input FAB_AWLEN4,
    input FAB_AWLEN5,
    input FAB_AWLEN6,
    input FAB_AWLEN7,
    input FAB_AWSIZE0,
    input FAB_AWSIZE1,
    input FAB_AWSIZE2,
    input FAB_AWBURST0,
    input FAB_AWBURST1,
    input FAB_AWVALID,
    input FAB_WDATA0,
    input FAB_WDATA1,
    input FAB_WDATA2,
    input FAB_WDATA3,
    input FAB_WDATA4,
    input FAB_WDATA5,
    input FAB_WDATA6,
    input FAB_WDATA7,
    input FAB_WDATA8,
    input FAB_WDATA9,
    input FAB_WDATA10,
    input FAB_WDATA11,
    input FAB_WDATA12,
    input FAB_WDATA13,
    input FAB_WDATA14,
    input FAB_WDATA15,
    input FAB_WDATA16,
    input FAB_WDATA17,
    input FAB_WDATA18,
    input FAB_WDATA19,
    input FAB_WDATA20,
    input FAB_WDATA21,
    input FAB_WDATA22,
    input FAB_WDATA23,
    input FAB_WDATA24,
    input FAB_WDATA25,
    input FAB_WDATA26,
    input FAB_WDATA27,
    input FAB_WDATA28,
    input FAB_WDATA29,
    input FAB_WDATA30,
    input FAB_WDATA31,
    input FAB_WSTRB0,
    input FAB_WSTRB1,
    input FAB_WSTRB2,
    input FAB_WSTRB3,
    input FAB_WLAST,
    input FAB_WVALID,
    input FAB_BREADY,
    input FAB_ARADDR0,
    input FAB_ARADDR1,
    input FAB_ARADDR2,
    input FAB_ARADDR3,
    input FAB_ARADDR4,
    input FAB_ARADDR5,
    input FAB_ARADDR6,
    input FAB_ARADDR7,
    input FAB_ARADDR8,
    input FAB_ARADDR9,
    input FAB_ARADDR10,
    input FAB_ARADDR11,
    input FAB_ARADDR12,
    input FAB_ARADDR13,
    input FAB_ARADDR14,
    input FAB_ARADDR15,
    input FAB_ARADDR16,
    input FAB_ARADDR17,
    input FAB_ARADDR18,
    input FAB_ARADDR19,
    input FAB_ARADDR20,
    input FAB_ARADDR21,
    input FAB_ARADDR22,
    input FAB_ARADDR23,
    input FAB_ARADDR24,
    input FAB_ARADDR25,
    input FAB_ARADDR26,
    input FAB_ARADDR27,
    input FAB_ARADDR28,
    input FAB_ARADDR29,
    input FAB_ARADDR30,
    input FAB_ARADDR31,
    input FAB_ARLEN0,
    input FAB_ARLEN1,
    input FAB_ARLEN2,
    input FAB_ARLEN3,
    input FAB_ARLEN4,
    input FAB_ARLEN5,
    input FAB_ARLEN6,
    input FAB_ARLEN7,
    input FAB_ARSIZE0,
    input FAB_ARSIZE1,
    input FAB_ARSIZE2,
    input FAB_ARBURST0,
    input FAB_ARBURST1,
    input FAB_ARVALID,
    input FAB_RREADY,
    output FAB_AWREADY,
    output FAB_WREADY,
    output FAB_BRESP0,
    output FAB_BRESP1,
    output FAB_BVALID,
    output FAB_ARREADY,
    output FAB_RDATA0,
    output FAB_RDATA1,
    output FAB_RDATA2,
    output FAB_RDATA3,
    output FAB_RDATA4,
    output FAB_RDATA5,
    output FAB_RDATA6,
    output FAB_RDATA7,
    output FAB_RDATA8,
    output FAB_RDATA9,
    output FAB_RDATA10,
    output FAB_RDATA11,
    output FAB_RDATA12,
    output FAB_RDATA13,
    output FAB_RDATA14,
    output FAB_RDATA15,
    output FAB_RDATA16,
    output FAB_RDATA17,
    output FAB_RDATA18,
    output FAB_RDATA19,
    output FAB_RDATA20,
    output FAB_RDATA21,
    output FAB_RDATA22,
    output FAB_RDATA23,
    output FAB_RDATA24,
    output FAB_RDATA25,
    output FAB_RDATA26,
    output FAB_RDATA27,
    output FAB_RDATA28,
    output FAB_RDATA29,
    output FAB_RDATA30,
    output FAB_RDATA31,
    output FAB_RRESP0,
    output FAB_RRESP1,
    output FAB_RLAST,
    output FAB_RVALID,
    (* iopad_external_pin *)
    input SOC_AWREADY,
    (* iopad_external_pin *)
    input SOC_WREADY,
    (* iopad_external_pin *)
    input SOC_BRESP0,
    (* iopad_external_pin *)
    input SOC_BRESP1,
    (* iopad_external_pin *)
    input SOC_BVALID,
    (* iopad_external_pin *)
    input SOC_ARREADY,
    (* iopad_external_pin *)
    input SOC_RDATA0,
    (* iopad_external_pin *)
    input SOC_RDATA1,
    (* iopad_external_pin *)
    input SOC_RDATA2,
    (* iopad_external_pin *)
    input SOC_RDATA3,
    (* iopad_external_pin *)
    input SOC_RDATA4,
    (* iopad_external_pin *)
    input SOC_RDATA5,
    (* iopad_external_pin *)
    input SOC_RDATA6,
    (* iopad_external_pin *)
    input SOC_RDATA7,
    (* iopad_external_pin *)
    input SOC_RDATA8,
    (* iopad_external_pin *)
    input SOC_RDATA9,
    (* iopad_external_pin *)
    input SOC_RDATA10,
    (* iopad_external_pin *)
    input SOC_RDATA11,
    (* iopad_external_pin *)
    input SOC_RDATA12,
    (* iopad_external_pin *)
    input SOC_RDATA13,
    (* iopad_external_pin *)
    input SOC_RDATA14,
    (* iopad_external_pin *)
    input SOC_RDATA15,
    (* iopad_external_pin *)
    input SOC_RDATA16,
    (* iopad_external_pin *)
    input SOC_RDATA17,
    (* iopad_external_pin *)
    input SOC_RDATA18,
    (* iopad_external_pin *)
    input SOC_RDATA19,
    (* iopad_external_pin *)
    input SOC_RDATA20,
    (* iopad_external_pin *)
    input SOC_RDATA21,
    (* iopad_external_pin *)
    input SOC_RDATA22,
    (* iopad_external_pin *)
    input SOC_RDATA23,
    (* iopad_external_pin *)
    input SOC_RDATA24,
    (* iopad_external_pin *)
    input SOC_RDATA25,
    (* iopad_external_pin *)
    input SOC_RDATA26,
    (* iopad_external_pin *)
    input SOC_RDATA27,
    (* iopad_external_pin *)
    input SOC_RDATA28,
    (* iopad_external_pin *)
    input SOC_RDATA29,
    (* iopad_external_pin *)
    input SOC_RDATA30,
    (* iopad_external_pin *)
    input SOC_RDATA31,
    (* iopad_external_pin *)
    input SOC_RRESP0,
    (* iopad_external_pin *)
    input SOC_RRESP1,
    (* iopad_external_pin *)
    input SOC_RLAST,
    (* iopad_external_pin *)
    input SOC_RVALID,
    (* iopad_external_pin *)
    output SOC_AWADDR0,
    (* iopad_external_pin *)
    output SOC_AWADDR1,
    (* iopad_external_pin *)
    output SOC_AWADDR2,
    (* iopad_external_pin *)
    output SOC_AWADDR3,
    (* iopad_external_pin *)
    output SOC_AWADDR4,
    (* iopad_external_pin *)
    output SOC_AWADDR5,
    (* iopad_external_pin *)
    output SOC_AWADDR6,
    (* iopad_external_pin *)
    output SOC_AWADDR7,
    (* iopad_external_pin *)
    output SOC_AWADDR8,
    (* iopad_external_pin *)
    output SOC_AWADDR9,
    (* iopad_external_pin *)
    output SOC_AWADDR10,
    (* iopad_external_pin *)
    output SOC_AWADDR11,
    (* iopad_external_pin *)
    output SOC_AWADDR12,
    (* iopad_external_pin *)
    output SOC_AWADDR13,
    (* iopad_external_pin *)
    output SOC_AWADDR14,
    (* iopad_external_pin *)
    output SOC_AWADDR15,
    (* iopad_external_pin *)
    output SOC_AWADDR16,
    (* iopad_external_pin *)
    output SOC_AWADDR17,
    (* iopad_external_pin *)
    output SOC_AWADDR18,
    (* iopad_external_pin *)
    output SOC_AWADDR19,
    (* iopad_external_pin *)
    output SOC_AWADDR20,
    (* iopad_external_pin *)
    output SOC_AWADDR21,
    (* iopad_external_pin *)
    output SOC_AWADDR22,
    (* iopad_external_pin *)
    output SOC_AWADDR23,
    (* iopad_external_pin *)
    output SOC_AWADDR24,
    (* iopad_external_pin *)
    output SOC_AWADDR25,
    (* iopad_external_pin *)
    output SOC_AWADDR26,
    (* iopad_external_pin *)
    output SOC_AWADDR27,
    (* iopad_external_pin *)
    output SOC_AWADDR28,
    (* iopad_external_pin *)
    output SOC_AWADDR29,
    (* iopad_external_pin *)
    output SOC_AWADDR30,
    (* iopad_external_pin *)
    output SOC_AWADDR31,
    (* iopad_external_pin *)
    output SOC_AWLEN0,
    (* iopad_external_pin *)
    output SOC_AWLEN1,
    (* iopad_external_pin *)
    output SOC_AWLEN2,
    (* iopad_external_pin *)
    output SOC_AWLEN3,
    (* iopad_external_pin *)
    output SOC_AWLEN4,
    (* iopad_external_pin *)
    output SOC_AWLEN5,
    (* iopad_external_pin *)
    output SOC_AWLEN6,
    (* iopad_external_pin *)
    output SOC_AWLEN7,
    (* iopad_external_pin *)
    output SOC_AWSIZE0,
    (* iopad_external_pin *)
    output SOC_AWSIZE1,
    (* iopad_external_pin *)
    output SOC_AWSIZE2,
    (* iopad_external_pin *)
    output SOC_AWBURST0,
    (* iopad_external_pin *)
    output SOC_AWBURST1,
    (* iopad_external_pin *)
    output SOC_AWVALID,
    (* iopad_external_pin *)
    output SOC_WDATA0,
    (* iopad_external_pin *)
    output SOC_WDATA1,
    (* iopad_external_pin *)
    output SOC_WDATA2,
    (* iopad_external_pin *)
    output SOC_WDATA3,
    (* iopad_external_pin *)
    output SOC_WDATA4,
    (* iopad_external_pin *)
    output SOC_WDATA5,
    (* iopad_external_pin *)
    output SOC_WDATA6,
    (* iopad_external_pin *)
    output SOC_WDATA7,
    (* iopad_external_pin *)
    output SOC_WDATA8,
    (* iopad_external_pin *)
    output SOC_WDATA9,
    (* iopad_external_pin *)
    output SOC_WDATA10,
    (* iopad_external_pin *)
    output SOC_WDATA11,
    (* iopad_external_pin *)
    output SOC_WDATA12,
    (* iopad_external_pin *)
    output SOC_WDATA13,
    (* iopad_external_pin *)
    output SOC_WDATA14,
    (* iopad_external_pin *)
    output SOC_WDATA15,
    (* iopad_external_pin *)
    output SOC_WDATA16,
    (* iopad_external_pin *)
    output SOC_WDATA17,
    (* iopad_external_pin *)
    output SOC_WDATA18,
    (* iopad_external_pin *)
    output SOC_WDATA19,
    (* iopad_external_pin *)
    output SOC_WDATA20,
    (* iopad_external_pin *)
    output SOC_WDATA21,
    (* iopad_external_pin *)
    output SOC_WDATA22,
    (* iopad_external_pin *)
    output SOC_WDATA23,
    (* iopad_external_pin *)
    output SOC_WDATA24,
    (* iopad_external_pin *)
    output SOC_WDATA25,
    (* iopad_external_pin *)
    output SOC_WDATA26,
    (* iopad_external_pin *)
    output SOC_WDATA27,
    (* iopad_external_pin *)
    output SOC_WDATA28,
    (* iopad_external_pin *)
    output SOC_WDATA29,
    (* iopad_external_pin *)
    output SOC_WDATA30,
    (* iopad_external_pin *)
    output SOC_WDATA31,
    (* iopad_external_pin *)
    output SOC_WSTRB0,
    (* iopad_external_pin *)
    output SOC_WSTRB1,
    (* iopad_external_pin *)
    output SOC_WSTRB2,
    (* iopad_external_pin *)
    output SOC_WSTRB3,
    (* iopad_external_pin *)
    output SOC_WLAST,
    (* iopad_external_pin *)
    output SOC_WVALID,
    (* iopad_external_pin *)
    output SOC_BREADY,
    (* iopad_external_pin *)
    output SOC_ARADDR0,
    (* iopad_external_pin *)
    output SOC_ARADDR1,
    (* iopad_external_pin *)
    output SOC_ARADDR2,
    (* iopad_external_pin *)
    output SOC_ARADDR3,
    (* iopad_external_pin *)
    output SOC_ARADDR4,
    (* iopad_external_pin *)
    output SOC_ARADDR5,
    (* iopad_external_pin *)
    output SOC_ARADDR6,
    (* iopad_external_pin *)
    output SOC_ARADDR7,
    (* iopad_external_pin *)
    output SOC_ARADDR8,
    (* iopad_external_pin *)
    output SOC_ARADDR9,
    (* iopad_external_pin *)
    output SOC_ARADDR10,
    (* iopad_external_pin *)
    output SOC_ARADDR11,
    (* iopad_external_pin *)
    output SOC_ARADDR12,
    (* iopad_external_pin *)
    output SOC_ARADDR13,
    (* iopad_external_pin *)
    output SOC_ARADDR14,
    (* iopad_external_pin *)
    output SOC_ARADDR15,
    (* iopad_external_pin *)
    output SOC_ARADDR16,
    (* iopad_external_pin *)
    output SOC_ARADDR17,
    (* iopad_external_pin *)
    output SOC_ARADDR18,
    (* iopad_external_pin *)
    output SOC_ARADDR19,
    (* iopad_external_pin *)
    output SOC_ARADDR20,
    (* iopad_external_pin *)
    output SOC_ARADDR21,
    (* iopad_external_pin *)
    output SOC_ARADDR22,
    (* iopad_external_pin *)
    output SOC_ARADDR23,
    (* iopad_external_pin *)
    output SOC_ARADDR24,
    (* iopad_external_pin *)
    output SOC_ARADDR25,
    (* iopad_external_pin *)
    output SOC_ARADDR26,
    (* iopad_external_pin *)
    output SOC_ARADDR27,
    (* iopad_external_pin *)
    output SOC_ARADDR28,
    (* iopad_external_pin *)
    output SOC_ARADDR29,
    (* iopad_external_pin *)
    output SOC_ARADDR30,
    (* iopad_external_pin *)
    output SOC_ARADDR31,
    (* iopad_external_pin *)
    output SOC_ARLEN0,
    (* iopad_external_pin *)
    output SOC_ARLEN1,
    (* iopad_external_pin *)
    output SOC_ARLEN2,
    (* iopad_external_pin *)
    output SOC_ARLEN3,
    (* iopad_external_pin *)
    output SOC_ARLEN4,
    (* iopad_external_pin *)
    output SOC_ARLEN5,
    (* iopad_external_pin *)
    output SOC_ARLEN6,
    (* iopad_external_pin *)
    output SOC_ARLEN7,
    (* iopad_external_pin *)
    output SOC_ARSIZE0,
    (* iopad_external_pin *)
    output SOC_ARSIZE1,
    (* iopad_external_pin *)
    output SOC_ARSIZE2,
    (* iopad_external_pin *)
    output SOC_ARBURST0,
    (* iopad_external_pin *)
    output SOC_ARBURST1,
    (* iopad_external_pin *)
    output SOC_ARVALID,
    (* iopad_external_pin *)
    output SOC_RREADY
);
    parameter TIE_OFF_AWLEN = 0;
    parameter TIE_OFF_AWSIZE = 0;
    parameter TIE_OFF_AWBURST = 0;
    parameter TIE_OFF_WSTRB = 0;
    parameter TIE_OFF_WLAST = 0;
    parameter TIE_OFF_ARLEN = 0;
    parameter TIE_OFF_ARSIZE = 0;
    parameter TIE_OFF_ARBURST = 0;
endmodule

//Warning: The primitive AXI4_LITE_SLAVE_BEL was added by FABulous automatically.
(* blackbox, keep *)
module AXIL_S_BEL (
    input FAB_AWREADY,
    input FAB_WREADY,
    input FAB_BRESP0,
    input FAB_BRESP1,
    input FAB_BVALID,
    input FAB_ARREADY,
    input FAB_RDATA0,
    input FAB_RDATA1,
    input FAB_RDATA2,
    input FAB_RDATA3,
    input FAB_RDATA4,
    input FAB_RDATA5,
    input FAB_RDATA6,
    input FAB_RDATA7,
    input FAB_RDATA8,
    input FAB_RDATA9,
    input FAB_RDATA10,
    input FAB_RDATA11,
    input FAB_RDATA12,
    input FAB_RDATA13,
    input FAB_RDATA14,
    input FAB_RDATA15,
    input FAB_RDATA16,
    input FAB_RDATA17,
    input FAB_RDATA18,
    input FAB_RDATA19,
    input FAB_RDATA20,
    input FAB_RDATA21,
    input FAB_RDATA22,
    input FAB_RDATA23,
    input FAB_RDATA24,
    input FAB_RDATA25,
    input FAB_RDATA26,
    input FAB_RDATA27,
    input FAB_RDATA28,
    input FAB_RDATA29,
    input FAB_RDATA30,
    input FAB_RDATA31,
    input FAB_RRESP0,
    input FAB_RRESP1,
    input FAB_RVALID,
    output FAB_AWADDR0,
    output FAB_AWADDR1,
    output FAB_AWADDR2,
    output FAB_AWADDR3,
    output FAB_AWADDR4,
    output FAB_AWADDR5,
    output FAB_AWADDR6,
    output FAB_AWADDR7,
    output FAB_AWADDR8,
    output FAB_AWADDR9,
    output FAB_AWVALID,
    output FAB_WDATA0,
    output FAB_WDATA1,
    output FAB_WDATA2,
    output FAB_WDATA3,
    output FAB_WDATA4,
    output FAB_WDATA5,
    output FAB_WDATA6,
    output FAB_WDATA7,
    output FAB_WDATA8,
    output FAB_WDATA9,
    output FAB_WDATA10,
    output FAB_WDATA11,
    output FAB_WDATA12,
    output FAB_WDATA13,
    output FAB_WDATA14,
    output FAB_WDATA15,
    output FAB_WDATA16,
    output FAB_WDATA17,
    output FAB_WDATA18,
    output FAB_WDATA19,
    output FAB_WDATA20,
    output FAB_WDATA21,
    output FAB_WDATA22,
    output FAB_WDATA23,
    output FAB_WDATA24,
    output FAB_WDATA25,
    output FAB_WDATA26,
    output FAB_WDATA27,
    output FAB_WDATA28,
    output FAB_WDATA29,
    output FAB_WDATA30,
    output FAB_WDATA31,
    output FAB_WSTRB0,
    output FAB_WSTRB1,
    output FAB_WSTRB2,
    output FAB_WSTRB3,
    output FAB_WVALID,
    output FAB_BREADY,
    output FAB_ARADDR0,
    output FAB_ARADDR1,
    output FAB_ARADDR2,
    output FAB_ARADDR3,
    output FAB_ARADDR4,
    output FAB_ARADDR5,
    output FAB_ARADDR6,
    output FAB_ARADDR7,
    output FAB_ARADDR8,
    output FAB_ARADDR9,
    output FAB_ARVALID,
    output FAB_RREADY,
    (* iopad_external_pin *)
    input SOC_AWADDR0,
    (* iopad_external_pin *)
    input SOC_AWADDR1,
    (* iopad_external_pin *)
    input SOC_AWADDR2,
    (* iopad_external_pin *)
    input SOC_AWADDR3,
    (* iopad_external_pin *)
    input SOC_AWADDR4,
    (* iopad_external_pin *)
    input SOC_AWADDR5,
    (* iopad_external_pin *)
    input SOC_AWADDR6,
    (* iopad_external_pin *)
    input SOC_AWADDR7,
    (* iopad_external_pin *)
    input SOC_AWADDR8,
    (* iopad_external_pin *)
    input SOC_AWADDR9,
    (* iopad_external_pin *)
    input SOC_AWVALID,
    (* iopad_external_pin *)
    input SOC_WDATA0,
    (* iopad_external_pin *)
    input SOC_WDATA1,
    (* iopad_external_pin *)
    input SOC_WDATA2,
    (* iopad_external_pin *)
    input SOC_WDATA3,
    (* iopad_external_pin *)
    input SOC_WDATA4,
    (* iopad_external_pin *)
    input SOC_WDATA5,
    (* iopad_external_pin *)
    input SOC_WDATA6,
    (* iopad_external_pin *)
    input SOC_WDATA7,
    (* iopad_external_pin *)
    input SOC_WDATA8,
    (* iopad_external_pin *)
    input SOC_WDATA9,
    (* iopad_external_pin *)
    input SOC_WDATA10,
    (* iopad_external_pin *)
    input SOC_WDATA11,
    (* iopad_external_pin *)
    input SOC_WDATA12,
    (* iopad_external_pin *)
    input SOC_WDATA13,
    (* iopad_external_pin *)
    input SOC_WDATA14,
    (* iopad_external_pin *)
    input SOC_WDATA15,
    (* iopad_external_pin *)
    input SOC_WDATA16,
    (* iopad_external_pin *)
    input SOC_WDATA17,
    (* iopad_external_pin *)
    input SOC_WDATA18,
    (* iopad_external_pin *)
    input SOC_WDATA19,
    (* iopad_external_pin *)
    input SOC_WDATA20,
    (* iopad_external_pin *)
    input SOC_WDATA21,
    (* iopad_external_pin *)
    input SOC_WDATA22,
    (* iopad_external_pin *)
    input SOC_WDATA23,
    (* iopad_external_pin *)
    input SOC_WDATA24,
    (* iopad_external_pin *)
    input SOC_WDATA25,
    (* iopad_external_pin *)
    input SOC_WDATA26,
    (* iopad_external_pin *)
    input SOC_WDATA27,
    (* iopad_external_pin *)
    input SOC_WDATA28,
    (* iopad_external_pin *)
    input SOC_WDATA29,
    (* iopad_external_pin *)
    input SOC_WDATA30,
    (* iopad_external_pin *)
    input SOC_WDATA31,
    (* iopad_external_pin *)
    input SOC_WSTRB0,
    (* iopad_external_pin *)
    input SOC_WSTRB1,
    (* iopad_external_pin *)
    input SOC_WSTRB2,
    (* iopad_external_pin *)
    input SOC_WSTRB3,
    (* iopad_external_pin *)
    input SOC_WVALID,
    (* iopad_external_pin *)
    input SOC_BREADY,
    (* iopad_external_pin *)
    input SOC_ARADDR0,
    (* iopad_external_pin *)
    input SOC_ARADDR1,
    (* iopad_external_pin *)
    input SOC_ARADDR2,
    (* iopad_external_pin *)
    input SOC_ARADDR3,
    (* iopad_external_pin *)
    input SOC_ARADDR4,
    (* iopad_external_pin *)
    input SOC_ARADDR5,
    (* iopad_external_pin *)
    input SOC_ARADDR6,
    (* iopad_external_pin *)
    input SOC_ARADDR7,
    (* iopad_external_pin *)
    input SOC_ARADDR8,
    (* iopad_external_pin *)
    input SOC_ARADDR9,
    (* iopad_external_pin *)
    input SOC_ARVALID,
    (* iopad_external_pin *)
    input SOC_RREADY,
    (* iopad_external_pin *)
    output SOC_AWREADY,
    (* iopad_external_pin *)
    output SOC_WREADY,
    (* iopad_external_pin *)
    output SOC_BRESP0,
    (* iopad_external_pin *)
    output SOC_BRESP1,
    (* iopad_external_pin *)
    output SOC_BVALID,
    (* iopad_external_pin *)
    output SOC_ARREADY,
    (* iopad_external_pin *)
    output SOC_RDATA0,
    (* iopad_external_pin *)
    output SOC_RDATA1,
    (* iopad_external_pin *)
    output SOC_RDATA2,
    (* iopad_external_pin *)
    output SOC_RDATA3,
    (* iopad_external_pin *)
    output SOC_RDATA4,
    (* iopad_external_pin *)
    output SOC_RDATA5,
    (* iopad_external_pin *)
    output SOC_RDATA6,
    (* iopad_external_pin *)
    output SOC_RDATA7,
    (* iopad_external_pin *)
    output SOC_RDATA8,
    (* iopad_external_pin *)
    output SOC_RDATA9,
    (* iopad_external_pin *)
    output SOC_RDATA10,
    (* iopad_external_pin *)
    output SOC_RDATA11,
    (* iopad_external_pin *)
    output SOC_RDATA12,
    (* iopad_external_pin *)
    output SOC_RDATA13,
    (* iopad_external_pin *)
    output SOC_RDATA14,
    (* iopad_external_pin *)
    output SOC_RDATA15,
    (* iopad_external_pin *)
    output SOC_RDATA16,
    (* iopad_external_pin *)
    output SOC_RDATA17,
    (* iopad_external_pin *)
    output SOC_RDATA18,
    (* iopad_external_pin *)
    output SOC_RDATA19,
    (* iopad_external_pin *)
    output SOC_RDATA20,
    (* iopad_external_pin *)
    output SOC_RDATA21,
    (* iopad_external_pin *)
    output SOC_RDATA22,
    (* iopad_external_pin *)
    output SOC_RDATA23,
    (* iopad_external_pin *)
    output SOC_RDATA24,
    (* iopad_external_pin *)
    output SOC_RDATA25,
    (* iopad_external_pin *)
    output SOC_RDATA26,
    (* iopad_external_pin *)
    output SOC_RDATA27,
    (* iopad_external_pin *)
    output SOC_RDATA28,
    (* iopad_external_pin *)
    output SOC_RDATA29,
    (* iopad_external_pin *)
    output SOC_RDATA30,
    (* iopad_external_pin *)
    output SOC_RDATA31,
    (* iopad_external_pin *)
    output SOC_RRESP0,
    (* iopad_external_pin *)
    output SOC_RRESP1,
    (* iopad_external_pin *)
    output SOC_RVALID
);
endmodule

//Warning: The primitive NPU_ACT_ROW_BEL was added by FABulous automatically.
(* blackbox, keep *)
module NPU_ACT_ROW_BEL (
    input FAB_ACT_WE,
    input FAB_ACT_ADDR0,
    input FAB_ACT_ADDR1,
    input FAB_ACT_ADDR2,
    input FAB_ACT_ADDR3,
    input FAB_ACT_ADDR4,
    input FAB_ACT_ADDR5,
    input FAB_ACT_ADDR6,
    input FAB_ACT_ADDR7,
    input FAB_ACT_ADDR8,
    input FAB_ACT_WDATA0,
    input FAB_ACT_WDATA1,
    input FAB_ACT_WDATA2,
    input FAB_ACT_WDATA3,
    input FAB_ACT_WDATA4,
    input FAB_ACT_WDATA5,
    input FAB_ACT_WDATA6,
    input FAB_ACT_WDATA7,
    input FAB_WEIGHT_IN0,
    input FAB_WEIGHT_IN1,
    input FAB_WEIGHT_IN2,
    input FAB_WEIGHT_IN3,
    input FAB_WEIGHT_IN4,
    input FAB_WEIGHT_IN5,
    input FAB_WEIGHT_IN6,
    input FAB_WEIGHT_IN7,
    output FAB_ACT_RDATA0,
    output FAB_ACT_RDATA1,
    output FAB_ACT_RDATA2,
    output FAB_ACT_RDATA3,
    output FAB_ACT_RDATA4,
    output FAB_ACT_RDATA5,
    output FAB_ACT_RDATA6,
    output FAB_ACT_RDATA7,
    (* iopad_external_pin *)
    input NPU_ACT_RDATA0,
    (* iopad_external_pin *)
    input NPU_ACT_RDATA1,
    (* iopad_external_pin *)
    input NPU_ACT_RDATA2,
    (* iopad_external_pin *)
    input NPU_ACT_RDATA3,
    (* iopad_external_pin *)
    input NPU_ACT_RDATA4,
    (* iopad_external_pin *)
    input NPU_ACT_RDATA5,
    (* iopad_external_pin *)
    input NPU_ACT_RDATA6,
    (* iopad_external_pin *)
    input NPU_ACT_RDATA7,
    (* iopad_external_pin *)
    output NPU_ACT_WE,
    (* iopad_external_pin *)
    output NPU_ACT_ADDR0,
    (* iopad_external_pin *)
    output NPU_ACT_ADDR1,
    (* iopad_external_pin *)
    output NPU_ACT_ADDR2,
    (* iopad_external_pin *)
    output NPU_ACT_ADDR3,
    (* iopad_external_pin *)
    output NPU_ACT_ADDR4,
    (* iopad_external_pin *)
    output NPU_ACT_ADDR5,
    (* iopad_external_pin *)
    output NPU_ACT_ADDR6,
    (* iopad_external_pin *)
    output NPU_ACT_ADDR7,
    (* iopad_external_pin *)
    output NPU_ACT_ADDR8,
    (* iopad_external_pin *)
    output NPU_ACT_WDATA0,
    (* iopad_external_pin *)
    output NPU_ACT_WDATA1,
    (* iopad_external_pin *)
    output NPU_ACT_WDATA2,
    (* iopad_external_pin *)
    output NPU_ACT_WDATA3,
    (* iopad_external_pin *)
    output NPU_ACT_WDATA4,
    (* iopad_external_pin *)
    output NPU_ACT_WDATA5,
    (* iopad_external_pin *)
    output NPU_ACT_WDATA6,
    (* iopad_external_pin *)
    output NPU_ACT_WDATA7,
    (* iopad_external_pin *)
    output NPU_WEIGHT_IN0,
    (* iopad_external_pin *)
    output NPU_WEIGHT_IN1,
    (* iopad_external_pin *)
    output NPU_WEIGHT_IN2,
    (* iopad_external_pin *)
    output NPU_WEIGHT_IN3,
    (* iopad_external_pin *)
    output NPU_WEIGHT_IN4,
    (* iopad_external_pin *)
    output NPU_WEIGHT_IN5,
    (* iopad_external_pin *)
    output NPU_WEIGHT_IN6,
    (* iopad_external_pin *)
    output NPU_WEIGHT_IN7
);
endmodule

//Warning: The primitive NPU_PSUM_PORT_BEL was added by FABulous automatically.
(* blackbox, keep *)
module NPU_PSUM_PORT_BEL (
    input FAB_ADDR0,
    input FAB_ADDR1,
    input FAB_ADDR2,
    input FAB_ADDR3,
    input FAB_ADDR4,
    input FAB_ADDR5,
    input FAB_ADDR6,
    input FAB_ADDR7,
    input FAB_WE0,
    input FAB_WE1,
    input FAB_WE2,
    input FAB_WE3,
    input FAB_WE4,
    input FAB_WE5,
    input FAB_WE6,
    input FAB_WE7,
    input FAB_WDATA0,
    input FAB_WDATA1,
    input FAB_WDATA2,
    input FAB_WDATA3,
    input FAB_WDATA4,
    input FAB_WDATA5,
    input FAB_WDATA6,
    input FAB_WDATA7,
    input FAB_WDATA8,
    input FAB_WDATA9,
    input FAB_WDATA10,
    input FAB_WDATA11,
    input FAB_WDATA12,
    input FAB_WDATA13,
    input FAB_WDATA14,
    input FAB_WDATA15,
    input FAB_WDATA16,
    input FAB_WDATA17,
    input FAB_WDATA18,
    input FAB_WDATA19,
    input FAB_WDATA20,
    input FAB_WDATA21,
    input FAB_WDATA22,
    input FAB_WDATA23,
    input FAB_WDATA24,
    input FAB_WDATA25,
    input FAB_WDATA26,
    input FAB_WDATA27,
    input FAB_WDATA28,
    input FAB_WDATA29,
    input FAB_WDATA30,
    input FAB_WDATA31,
    input FAB_READ_BANK_SEL0,
    input FAB_READ_BANK_SEL1,
    input FAB_READ_BANK_SEL2,
    output FAB_RDATA0,
    output FAB_RDATA1,
    output FAB_RDATA2,
    output FAB_RDATA3,
    output FAB_RDATA4,
    output FAB_RDATA5,
    output FAB_RDATA6,
    output FAB_RDATA7,
    output FAB_RDATA8,
    output FAB_RDATA9,
    output FAB_RDATA10,
    output FAB_RDATA11,
    output FAB_RDATA12,
    output FAB_RDATA13,
    output FAB_RDATA14,
    output FAB_RDATA15,
    output FAB_RDATA16,
    output FAB_RDATA17,
    output FAB_RDATA18,
    output FAB_RDATA19,
    output FAB_RDATA20,
    output FAB_RDATA21,
    output FAB_RDATA22,
    output FAB_RDATA23,
    output FAB_RDATA24,
    output FAB_RDATA25,
    output FAB_RDATA26,
    output FAB_RDATA27,
    output FAB_RDATA28,
    output FAB_RDATA29,
    output FAB_RDATA30,
    output FAB_RDATA31,
    (* iopad_external_pin *)
    input NPU_RDATA0,
    (* iopad_external_pin *)
    input NPU_RDATA1,
    (* iopad_external_pin *)
    input NPU_RDATA2,
    (* iopad_external_pin *)
    input NPU_RDATA3,
    (* iopad_external_pin *)
    input NPU_RDATA4,
    (* iopad_external_pin *)
    input NPU_RDATA5,
    (* iopad_external_pin *)
    input NPU_RDATA6,
    (* iopad_external_pin *)
    input NPU_RDATA7,
    (* iopad_external_pin *)
    input NPU_RDATA8,
    (* iopad_external_pin *)
    input NPU_RDATA9,
    (* iopad_external_pin *)
    input NPU_RDATA10,
    (* iopad_external_pin *)
    input NPU_RDATA11,
    (* iopad_external_pin *)
    input NPU_RDATA12,
    (* iopad_external_pin *)
    input NPU_RDATA13,
    (* iopad_external_pin *)
    input NPU_RDATA14,
    (* iopad_external_pin *)
    input NPU_RDATA15,
    (* iopad_external_pin *)
    input NPU_RDATA16,
    (* iopad_external_pin *)
    input NPU_RDATA17,
    (* iopad_external_pin *)
    input NPU_RDATA18,
    (* iopad_external_pin *)
    input NPU_RDATA19,
    (* iopad_external_pin *)
    input NPU_RDATA20,
    (* iopad_external_pin *)
    input NPU_RDATA21,
    (* iopad_external_pin *)
    input NPU_RDATA22,
    (* iopad_external_pin *)
    input NPU_RDATA23,
    (* iopad_external_pin *)
    input NPU_RDATA24,
    (* iopad_external_pin *)
    input NPU_RDATA25,
    (* iopad_external_pin *)
    input NPU_RDATA26,
    (* iopad_external_pin *)
    input NPU_RDATA27,
    (* iopad_external_pin *)
    input NPU_RDATA28,
    (* iopad_external_pin *)
    input NPU_RDATA29,
    (* iopad_external_pin *)
    input NPU_RDATA30,
    (* iopad_external_pin *)
    input NPU_RDATA31,
    (* iopad_external_pin *)
    output NPU_ADDR0,
    (* iopad_external_pin *)
    output NPU_ADDR1,
    (* iopad_external_pin *)
    output NPU_ADDR2,
    (* iopad_external_pin *)
    output NPU_ADDR3,
    (* iopad_external_pin *)
    output NPU_ADDR4,
    (* iopad_external_pin *)
    output NPU_ADDR5,
    (* iopad_external_pin *)
    output NPU_ADDR6,
    (* iopad_external_pin *)
    output NPU_ADDR7,
    (* iopad_external_pin *)
    output NPU_WE0,
    (* iopad_external_pin *)
    output NPU_WE1,
    (* iopad_external_pin *)
    output NPU_WE2,
    (* iopad_external_pin *)
    output NPU_WE3,
    (* iopad_external_pin *)
    output NPU_WE4,
    (* iopad_external_pin *)
    output NPU_WE5,
    (* iopad_external_pin *)
    output NPU_WE6,
    (* iopad_external_pin *)
    output NPU_WE7,
    (* iopad_external_pin *)
    output NPU_WDATA0,
    (* iopad_external_pin *)
    output NPU_WDATA1,
    (* iopad_external_pin *)
    output NPU_WDATA2,
    (* iopad_external_pin *)
    output NPU_WDATA3,
    (* iopad_external_pin *)
    output NPU_WDATA4,
    (* iopad_external_pin *)
    output NPU_WDATA5,
    (* iopad_external_pin *)
    output NPU_WDATA6,
    (* iopad_external_pin *)
    output NPU_WDATA7,
    (* iopad_external_pin *)
    output NPU_WDATA8,
    (* iopad_external_pin *)
    output NPU_WDATA9,
    (* iopad_external_pin *)
    output NPU_WDATA10,
    (* iopad_external_pin *)
    output NPU_WDATA11,
    (* iopad_external_pin *)
    output NPU_WDATA12,
    (* iopad_external_pin *)
    output NPU_WDATA13,
    (* iopad_external_pin *)
    output NPU_WDATA14,
    (* iopad_external_pin *)
    output NPU_WDATA15,
    (* iopad_external_pin *)
    output NPU_WDATA16,
    (* iopad_external_pin *)
    output NPU_WDATA17,
    (* iopad_external_pin *)
    output NPU_WDATA18,
    (* iopad_external_pin *)
    output NPU_WDATA19,
    (* iopad_external_pin *)
    output NPU_WDATA20,
    (* iopad_external_pin *)
    output NPU_WDATA21,
    (* iopad_external_pin *)
    output NPU_WDATA22,
    (* iopad_external_pin *)
    output NPU_WDATA23,
    (* iopad_external_pin *)
    output NPU_WDATA24,
    (* iopad_external_pin *)
    output NPU_WDATA25,
    (* iopad_external_pin *)
    output NPU_WDATA26,
    (* iopad_external_pin *)
    output NPU_WDATA27,
    (* iopad_external_pin *)
    output NPU_WDATA28,
    (* iopad_external_pin *)
    output NPU_WDATA29,
    (* iopad_external_pin *)
    output NPU_WDATA30,
    (* iopad_external_pin *)
    output NPU_WDATA31,
    (* iopad_external_pin *)
    output NPU_READ_BANK_SEL0,
    (* iopad_external_pin *)
    output NPU_READ_BANK_SEL1,
    (* iopad_external_pin *)
    output NPU_READ_BANK_SEL2
);
endmodule
