 // NumberOfConfigBits: 0
module NPU_SLICE_switch_matrix
    (
 //SJUMP inputs from child tiles
        input  NPU_SLICE_1_BASE_TO_TOP0,
        input  NPU_SLICE_1_BASE_TO_TOP1,
        input  NPU_SLICE_1_BASE_TO_TOP2,
        input  NPU_SLICE_1_BASE_TO_TOP3,
        input  NPU_SLICE_1_BASE_TO_TOP4,
        input  NPU_SLICE_1_BASE_TO_TOP5,
        input  NPU_SLICE_1_BASE_TO_TOP6,
        input  NPU_SLICE_1_BASE_TO_TOP7,
        input  NPU_SLICE_1_BASE_TO_TOP8,
        input  NPU_SLICE_1_BASE_TO_TOP9,
        input  NPU_SLICE_1_BASE_TO_TOP10,
        input  NPU_SLICE_1_BASE_TO_TOP11,
        input  NPU_SLICE_1_BASE_TO_TOP12,
        input  NPU_SLICE_1_BASE_TO_TOP13,
        input  NPU_SLICE_1_BASE_TO_TOP14,
        input  NPU_SLICE_0_BASE_TO_TOP0,
        input  NPU_SLICE_0_BASE_TO_TOP1,
        input  NPU_SLICE_0_BASE_TO_TOP2,
        input  NPU_SLICE_0_BASE_TO_TOP3,
        input  NPU_SLICE_0_BASE_TO_TOP4,
        input  NPU_SLICE_0_BASE_TO_TOP5,
        input  NPU_SLICE_0_BASE_TO_TOP6,
        input  NPU_SLICE_0_BASE_TO_TOP7,
        input  NPU_SLICE_0_BASE_TO_TOP8,
        input  NPU_SLICE_0_BASE_TO_TOP9,
        input  NPU_SLICE_0_BASE_TO_TOP10,
        input  NPU_SLICE_0_BASE_TO_TOP11,
        input  NPU_SLICE_0_BASE_TO_TOP12,
        input  NPU_SLICE_0_BASE_TO_TOP13,
        input  NPU_SLICE_0_BASE_TO_TOP14,
        input  NPU_SLICE_0_BASE_TO_TOP15,
 //BEL input ports (SM outputs)
        output  FAB_ACT_ADDR0,
        output  FAB_ACT_ADDR1,
        output  FAB_ACT_ADDR2,
        output  FAB_ACT_ADDR3,
        output  FAB_ACT_ADDR4,
        output  FAB_ACT_ADDR5,
        output  FAB_ACT_ADDR6,
        output  FAB_ACT_ADDR7,
        output  FAB_ACT_ADDR8,
        output  FAB_ACT_WDATA0,
        output  FAB_ACT_WDATA1,
        output  FAB_ACT_WDATA2,
        output  FAB_ACT_WDATA3,
        output  FAB_ACT_WDATA4,
        output  FAB_ACT_WDATA5,
        output  FAB_ACT_WDATA6,
        output  FAB_ACT_WDATA7,
        output  FAB_ACT_WE,
        output  FAB_WEIGHT_IN0,
        output  FAB_WEIGHT_IN1,
        output  FAB_WEIGHT_IN2,
        output  FAB_WEIGHT_IN3,
        output  FAB_WEIGHT_IN4,
        output  FAB_WEIGHT_IN5,
        output  FAB_WEIGHT_IN6,
        output  FAB_WEIGHT_IN7,
        output  FAB_WEIGHT_SHIFT_EN,
        output  FAB_XBAR_SEL0,
        output  FAB_XBAR_SEL1,
        output  FAB_XBAR_SEL2,
        output  FAB_XBAR_SEL3,
 //BEL output ports (SM inputs)
        input  FAB_ACT_RDATA0,
        input  FAB_ACT_RDATA1,
        input  FAB_ACT_RDATA2,
        input  FAB_ACT_RDATA3,
        input  FAB_ACT_RDATA4,
        input  FAB_ACT_RDATA5,
        input  FAB_ACT_RDATA6,
        input  FAB_ACT_RDATA7,
        input  FAB_OUT_ACT0,
        input  FAB_OUT_ACT1,
        input  FAB_OUT_ACT2,
        input  FAB_OUT_ACT3,
        input  FAB_OUT_ACT4,
        input  FAB_OUT_ACT5,
        input  FAB_OUT_ACT6,
        input  FAB_OUT_ACT7,
 //Reverse SJUMP outputs (SM -> child tile)
        output  NPU_SLICE_1_TOP_TO_BASE0,
        output  NPU_SLICE_1_TOP_TO_BASE1,
        output  NPU_SLICE_1_TOP_TO_BASE2,
        output  NPU_SLICE_1_TOP_TO_BASE3,
        output  NPU_SLICE_1_TOP_TO_BASE4,
        output  NPU_SLICE_1_TOP_TO_BASE5,
        output  NPU_SLICE_1_TOP_TO_BASE6,
        output  NPU_SLICE_1_TOP_TO_BASE7,
        output  NPU_SLICE_0_TOP_TO_BASE0,
        output  NPU_SLICE_0_TOP_TO_BASE1,
        output  NPU_SLICE_0_TOP_TO_BASE2,
        output  NPU_SLICE_0_TOP_TO_BASE3,
        output  NPU_SLICE_0_TOP_TO_BASE4,
        output  NPU_SLICE_0_TOP_TO_BASE5,
        output  NPU_SLICE_0_TOP_TO_BASE6,
        output  NPU_SLICE_0_TOP_TO_BASE7
 //global
);
parameter GND0 = 1'b0;
parameter GND = 1'b0;
parameter VCC0 = 1'b1;
parameter VCC = 1'b1;
parameter VDD0 = 1'b1;
parameter VDD = 1'b1;

 //The configuration bits (if any) are just a long shift register
 //This shift register is padded to an even number of flops/latches
 //switch matrix multiplexer FAB_XBAR_SEL0 MUX-1
assign FAB_XBAR_SEL0 = NPU_SLICE_1_BASE_TO_TOP0;

 //switch matrix multiplexer FAB_XBAR_SEL1 MUX-1
assign FAB_XBAR_SEL1 = NPU_SLICE_1_BASE_TO_TOP1;

 //switch matrix multiplexer FAB_XBAR_SEL2 MUX-1
assign FAB_XBAR_SEL2 = NPU_SLICE_1_BASE_TO_TOP2;

 //switch matrix multiplexer FAB_XBAR_SEL3 MUX-1
assign FAB_XBAR_SEL3 = NPU_SLICE_1_BASE_TO_TOP3;

 //switch matrix multiplexer FAB_ACT_ADDR0 MUX-1
assign FAB_ACT_ADDR0 = NPU_SLICE_1_BASE_TO_TOP4;

 //switch matrix multiplexer FAB_ACT_ADDR1 MUX-1
assign FAB_ACT_ADDR1 = NPU_SLICE_1_BASE_TO_TOP5;

 //switch matrix multiplexer FAB_ACT_ADDR2 MUX-1
assign FAB_ACT_ADDR2 = NPU_SLICE_1_BASE_TO_TOP6;

 //switch matrix multiplexer FAB_ACT_ADDR3 MUX-1
assign FAB_ACT_ADDR3 = NPU_SLICE_1_BASE_TO_TOP7;

 //switch matrix multiplexer FAB_ACT_ADDR4 MUX-1
assign FAB_ACT_ADDR4 = NPU_SLICE_1_BASE_TO_TOP8;

 //switch matrix multiplexer FAB_ACT_ADDR5 MUX-1
assign FAB_ACT_ADDR5 = NPU_SLICE_1_BASE_TO_TOP9;

 //switch matrix multiplexer FAB_ACT_ADDR6 MUX-1
assign FAB_ACT_ADDR6 = NPU_SLICE_1_BASE_TO_TOP10;

 //switch matrix multiplexer FAB_ACT_ADDR7 MUX-1
assign FAB_ACT_ADDR7 = NPU_SLICE_1_BASE_TO_TOP11;

 //switch matrix multiplexer FAB_ACT_ADDR8 MUX-1
assign FAB_ACT_ADDR8 = NPU_SLICE_1_BASE_TO_TOP12;

 //switch matrix multiplexer FAB_ACT_WE MUX-1
assign FAB_ACT_WE = NPU_SLICE_1_BASE_TO_TOP13;

 //switch matrix multiplexer FAB_WEIGHT_SHIFT_EN MUX-1
assign FAB_WEIGHT_SHIFT_EN = NPU_SLICE_1_BASE_TO_TOP14;

 //switch matrix multiplexer NPU_SLICE_1_TOP_TO_BASE0 MUX-1
assign NPU_SLICE_1_TOP_TO_BASE0 = FAB_OUT_ACT0;

 //switch matrix multiplexer NPU_SLICE_1_TOP_TO_BASE1 MUX-1
assign NPU_SLICE_1_TOP_TO_BASE1 = FAB_OUT_ACT1;

 //switch matrix multiplexer NPU_SLICE_1_TOP_TO_BASE2 MUX-1
assign NPU_SLICE_1_TOP_TO_BASE2 = FAB_OUT_ACT2;

 //switch matrix multiplexer NPU_SLICE_1_TOP_TO_BASE3 MUX-1
assign NPU_SLICE_1_TOP_TO_BASE3 = FAB_OUT_ACT3;

 //switch matrix multiplexer NPU_SLICE_1_TOP_TO_BASE4 MUX-1
assign NPU_SLICE_1_TOP_TO_BASE4 = FAB_OUT_ACT4;

 //switch matrix multiplexer NPU_SLICE_1_TOP_TO_BASE5 MUX-1
assign NPU_SLICE_1_TOP_TO_BASE5 = FAB_OUT_ACT5;

 //switch matrix multiplexer NPU_SLICE_1_TOP_TO_BASE6 MUX-1
assign NPU_SLICE_1_TOP_TO_BASE6 = FAB_OUT_ACT6;

 //switch matrix multiplexer NPU_SLICE_1_TOP_TO_BASE7 MUX-1
assign NPU_SLICE_1_TOP_TO_BASE7 = FAB_OUT_ACT7;

 //switch matrix multiplexer FAB_ACT_WDATA0 MUX-1
assign FAB_ACT_WDATA0 = NPU_SLICE_0_BASE_TO_TOP0;

 //switch matrix multiplexer FAB_ACT_WDATA1 MUX-1
assign FAB_ACT_WDATA1 = NPU_SLICE_0_BASE_TO_TOP1;

 //switch matrix multiplexer FAB_ACT_WDATA2 MUX-1
assign FAB_ACT_WDATA2 = NPU_SLICE_0_BASE_TO_TOP2;

 //switch matrix multiplexer FAB_ACT_WDATA3 MUX-1
assign FAB_ACT_WDATA3 = NPU_SLICE_0_BASE_TO_TOP3;

 //switch matrix multiplexer FAB_ACT_WDATA4 MUX-1
assign FAB_ACT_WDATA4 = NPU_SLICE_0_BASE_TO_TOP4;

 //switch matrix multiplexer FAB_ACT_WDATA5 MUX-1
assign FAB_ACT_WDATA5 = NPU_SLICE_0_BASE_TO_TOP5;

 //switch matrix multiplexer FAB_ACT_WDATA6 MUX-1
assign FAB_ACT_WDATA6 = NPU_SLICE_0_BASE_TO_TOP6;

 //switch matrix multiplexer FAB_ACT_WDATA7 MUX-1
assign FAB_ACT_WDATA7 = NPU_SLICE_0_BASE_TO_TOP7;

 //switch matrix multiplexer FAB_WEIGHT_IN0 MUX-1
assign FAB_WEIGHT_IN0 = NPU_SLICE_0_BASE_TO_TOP8;

 //switch matrix multiplexer FAB_WEIGHT_IN1 MUX-1
assign FAB_WEIGHT_IN1 = NPU_SLICE_0_BASE_TO_TOP9;

 //switch matrix multiplexer FAB_WEIGHT_IN2 MUX-1
assign FAB_WEIGHT_IN2 = NPU_SLICE_0_BASE_TO_TOP10;

 //switch matrix multiplexer FAB_WEIGHT_IN3 MUX-1
assign FAB_WEIGHT_IN3 = NPU_SLICE_0_BASE_TO_TOP11;

 //switch matrix multiplexer FAB_WEIGHT_IN4 MUX-1
assign FAB_WEIGHT_IN4 = NPU_SLICE_0_BASE_TO_TOP12;

 //switch matrix multiplexer FAB_WEIGHT_IN5 MUX-1
assign FAB_WEIGHT_IN5 = NPU_SLICE_0_BASE_TO_TOP13;

 //switch matrix multiplexer FAB_WEIGHT_IN6 MUX-1
assign FAB_WEIGHT_IN6 = NPU_SLICE_0_BASE_TO_TOP14;

 //switch matrix multiplexer FAB_WEIGHT_IN7 MUX-1
assign FAB_WEIGHT_IN7 = NPU_SLICE_0_BASE_TO_TOP15;

 //switch matrix multiplexer NPU_SLICE_0_TOP_TO_BASE0 MUX-1
assign NPU_SLICE_0_TOP_TO_BASE0 = FAB_ACT_RDATA0;

 //switch matrix multiplexer NPU_SLICE_0_TOP_TO_BASE1 MUX-1
assign NPU_SLICE_0_TOP_TO_BASE1 = FAB_ACT_RDATA1;

 //switch matrix multiplexer NPU_SLICE_0_TOP_TO_BASE2 MUX-1
assign NPU_SLICE_0_TOP_TO_BASE2 = FAB_ACT_RDATA2;

 //switch matrix multiplexer NPU_SLICE_0_TOP_TO_BASE3 MUX-1
assign NPU_SLICE_0_TOP_TO_BASE3 = FAB_ACT_RDATA3;

 //switch matrix multiplexer NPU_SLICE_0_TOP_TO_BASE4 MUX-1
assign NPU_SLICE_0_TOP_TO_BASE4 = FAB_ACT_RDATA4;

 //switch matrix multiplexer NPU_SLICE_0_TOP_TO_BASE5 MUX-1
assign NPU_SLICE_0_TOP_TO_BASE5 = FAB_ACT_RDATA5;

 //switch matrix multiplexer NPU_SLICE_0_TOP_TO_BASE6 MUX-1
assign NPU_SLICE_0_TOP_TO_BASE6 = FAB_ACT_RDATA6;

 //switch matrix multiplexer NPU_SLICE_0_TOP_TO_BASE7 MUX-1
assign NPU_SLICE_0_TOP_TO_BASE7 = FAB_ACT_RDATA7;

endmodule