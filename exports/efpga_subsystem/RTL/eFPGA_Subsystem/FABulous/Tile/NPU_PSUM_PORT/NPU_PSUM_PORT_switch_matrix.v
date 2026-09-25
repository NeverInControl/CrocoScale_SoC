 // NumberOfConfigBits: 0
module NPU_PSUM_PORT_switch_matrix
    (
 //SJUMP inputs from child tiles
        input  NPU_PSUM_PORT0_BASE_TO_TOP0,
        input  NPU_PSUM_PORT0_BASE_TO_TOP1,
        input  NPU_PSUM_PORT0_BASE_TO_TOP2,
        input  NPU_PSUM_PORT0_BASE_TO_TOP3,
        input  NPU_PSUM_PORT0_BASE_TO_TOP4,
        input  NPU_PSUM_PORT0_BASE_TO_TOP5,
        input  NPU_PSUM_PORT0_BASE_TO_TOP6,
        input  NPU_PSUM_PORT0_BASE_TO_TOP7,
        input  NPU_PSUM_PORT0_BASE_TO_TOP8,
        input  NPU_PSUM_PORT0_BASE_TO_TOP9,
        input  NPU_PSUM_PORT0_BASE_TO_TOP10,
        input  NPU_PSUM_PORT0_BASE_TO_TOP11,
        input  NPU_PSUM_PORT0_BASE_TO_TOP12,
        input  NPU_PSUM_PORT0_BASE_TO_TOP13,
        input  NPU_PSUM_PORT0_BASE_TO_TOP14,
        input  NPU_PSUM_PORT0_BASE_TO_TOP15,
        input  NPU_PSUM_PORT0_BASE_TO_TOP16,
        input  NPU_PSUM_PORT0_BASE_TO_TOP17,
        input  NPU_PSUM_PORT0_BASE_TO_TOP18,
        input  NPU_PSUM_PORT0_BASE_TO_TOP19,
        input  NPU_PSUM_PORT0_BASE_TO_TOP20,
        input  NPU_PSUM_PORT0_BASE_TO_TOP21,
        input  NPU_PSUM_PORT0_BASE_TO_TOP22,
        input  NPU_PSUM_PORT0_BASE_TO_TOP23,
        input  NPU_PSUM_PORT0_BASE_TO_TOP24,
        input  NPU_PSUM_PORT0_BASE_TO_TOP25,
        input  NPU_PSUM_PORT0_BASE_TO_TOP26,
        input  NPU_PSUM_PORT0_BASE_TO_TOP27,
        input  NPU_PSUM_PORT0_BASE_TO_TOP28,
        input  NPU_PSUM_PORT0_BASE_TO_TOP29,
        input  NPU_PSUM_PORT0_BASE_TO_TOP30,
        input  NPU_PSUM_PORT0_BASE_TO_TOP31,
        input  NPU_PSUM_PORT1_BASE_TO_TOP0,
        input  NPU_PSUM_PORT1_BASE_TO_TOP1,
        input  NPU_PSUM_PORT1_BASE_TO_TOP2,
        input  NPU_PSUM_PORT1_BASE_TO_TOP3,
        input  NPU_PSUM_PORT1_BASE_TO_TOP4,
        input  NPU_PSUM_PORT1_BASE_TO_TOP5,
        input  NPU_PSUM_PORT1_BASE_TO_TOP6,
        input  NPU_PSUM_PORT1_BASE_TO_TOP7,
        input  NPU_PSUM_PORT1_BASE_TO_TOP8,
        input  NPU_PSUM_PORT1_BASE_TO_TOP9,
        input  NPU_PSUM_PORT1_BASE_TO_TOP10,
        input  NPU_PSUM_PORT1_BASE_TO_TOP11,
        input  NPU_PSUM_PORT1_BASE_TO_TOP12,
        input  NPU_PSUM_PORT1_BASE_TO_TOP13,
        input  NPU_PSUM_PORT1_BASE_TO_TOP14,
        input  NPU_PSUM_PORT1_BASE_TO_TOP15,
        input  NPU_PSUM_PORT1_BASE_TO_TOP16,
        input  NPU_PSUM_PORT1_BASE_TO_TOP17,
        input  NPU_PSUM_PORT1_BASE_TO_TOP18,
 //BEL input ports (SM outputs)
        output  FAB_ADDR0,
        output  FAB_ADDR1,
        output  FAB_ADDR2,
        output  FAB_ADDR3,
        output  FAB_ADDR4,
        output  FAB_ADDR5,
        output  FAB_ADDR6,
        output  FAB_ADDR7,
        output  FAB_WE0,
        output  FAB_WE1,
        output  FAB_WE2,
        output  FAB_WE3,
        output  FAB_WE4,
        output  FAB_WE5,
        output  FAB_WE6,
        output  FAB_WE7,
        output  FAB_WDATA0,
        output  FAB_WDATA1,
        output  FAB_WDATA2,
        output  FAB_WDATA3,
        output  FAB_WDATA4,
        output  FAB_WDATA5,
        output  FAB_WDATA6,
        output  FAB_WDATA7,
        output  FAB_WDATA8,
        output  FAB_WDATA9,
        output  FAB_WDATA10,
        output  FAB_WDATA11,
        output  FAB_WDATA12,
        output  FAB_WDATA13,
        output  FAB_WDATA14,
        output  FAB_WDATA15,
        output  FAB_WDATA16,
        output  FAB_WDATA17,
        output  FAB_WDATA18,
        output  FAB_WDATA19,
        output  FAB_WDATA20,
        output  FAB_WDATA21,
        output  FAB_WDATA22,
        output  FAB_WDATA23,
        output  FAB_WDATA24,
        output  FAB_WDATA25,
        output  FAB_WDATA26,
        output  FAB_WDATA27,
        output  FAB_WDATA28,
        output  FAB_WDATA29,
        output  FAB_WDATA30,
        output  FAB_WDATA31,
        output  FAB_READ_BANK_SEL0,
        output  FAB_READ_BANK_SEL1,
        output  FAB_READ_BANK_SEL2,
 //BEL output ports (SM inputs)
        input  FAB_RDATA0,
        input  FAB_RDATA1,
        input  FAB_RDATA2,
        input  FAB_RDATA3,
        input  FAB_RDATA4,
        input  FAB_RDATA5,
        input  FAB_RDATA6,
        input  FAB_RDATA7,
        input  FAB_RDATA8,
        input  FAB_RDATA9,
        input  FAB_RDATA10,
        input  FAB_RDATA11,
        input  FAB_RDATA12,
        input  FAB_RDATA13,
        input  FAB_RDATA14,
        input  FAB_RDATA15,
        input  FAB_RDATA16,
        input  FAB_RDATA17,
        input  FAB_RDATA18,
        input  FAB_RDATA19,
        input  FAB_RDATA20,
        input  FAB_RDATA21,
        input  FAB_RDATA22,
        input  FAB_RDATA23,
        input  FAB_RDATA24,
        input  FAB_RDATA25,
        input  FAB_RDATA26,
        input  FAB_RDATA27,
        input  FAB_RDATA28,
        input  FAB_RDATA29,
        input  FAB_RDATA30,
        input  FAB_RDATA31,
 //Reverse SJUMP outputs (SM -> child tile)
        output  NPU_PSUM_PORT0_TOP_TO_BASE0,
        output  NPU_PSUM_PORT0_TOP_TO_BASE1,
        output  NPU_PSUM_PORT0_TOP_TO_BASE2,
        output  NPU_PSUM_PORT0_TOP_TO_BASE3,
        output  NPU_PSUM_PORT0_TOP_TO_BASE4,
        output  NPU_PSUM_PORT0_TOP_TO_BASE5,
        output  NPU_PSUM_PORT0_TOP_TO_BASE6,
        output  NPU_PSUM_PORT0_TOP_TO_BASE7,
        output  NPU_PSUM_PORT0_TOP_TO_BASE8,
        output  NPU_PSUM_PORT0_TOP_TO_BASE9,
        output  NPU_PSUM_PORT0_TOP_TO_BASE10,
        output  NPU_PSUM_PORT0_TOP_TO_BASE11,
        output  NPU_PSUM_PORT0_TOP_TO_BASE12,
        output  NPU_PSUM_PORT0_TOP_TO_BASE13,
        output  NPU_PSUM_PORT0_TOP_TO_BASE14,
        output  NPU_PSUM_PORT0_TOP_TO_BASE15,
        output  NPU_PSUM_PORT1_TOP_TO_BASE0,
        output  NPU_PSUM_PORT1_TOP_TO_BASE1,
        output  NPU_PSUM_PORT1_TOP_TO_BASE2,
        output  NPU_PSUM_PORT1_TOP_TO_BASE3,
        output  NPU_PSUM_PORT1_TOP_TO_BASE4,
        output  NPU_PSUM_PORT1_TOP_TO_BASE5,
        output  NPU_PSUM_PORT1_TOP_TO_BASE6,
        output  NPU_PSUM_PORT1_TOP_TO_BASE7,
        output  NPU_PSUM_PORT1_TOP_TO_BASE8,
        output  NPU_PSUM_PORT1_TOP_TO_BASE9,
        output  NPU_PSUM_PORT1_TOP_TO_BASE10,
        output  NPU_PSUM_PORT1_TOP_TO_BASE11,
        output  NPU_PSUM_PORT1_TOP_TO_BASE12,
        output  NPU_PSUM_PORT1_TOP_TO_BASE13,
        output  NPU_PSUM_PORT1_TOP_TO_BASE14,
        output  NPU_PSUM_PORT1_TOP_TO_BASE15
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
 //switch matrix multiplexer FAB_WDATA0 MUX-1
assign FAB_WDATA0 = NPU_PSUM_PORT0_BASE_TO_TOP0;

 //switch matrix multiplexer FAB_WDATA1 MUX-1
assign FAB_WDATA1 = NPU_PSUM_PORT0_BASE_TO_TOP1;

 //switch matrix multiplexer FAB_WDATA2 MUX-1
assign FAB_WDATA2 = NPU_PSUM_PORT0_BASE_TO_TOP2;

 //switch matrix multiplexer FAB_WDATA3 MUX-1
assign FAB_WDATA3 = NPU_PSUM_PORT0_BASE_TO_TOP3;

 //switch matrix multiplexer FAB_WDATA4 MUX-1
assign FAB_WDATA4 = NPU_PSUM_PORT0_BASE_TO_TOP4;

 //switch matrix multiplexer FAB_WDATA5 MUX-1
assign FAB_WDATA5 = NPU_PSUM_PORT0_BASE_TO_TOP5;

 //switch matrix multiplexer FAB_WDATA6 MUX-1
assign FAB_WDATA6 = NPU_PSUM_PORT0_BASE_TO_TOP6;

 //switch matrix multiplexer FAB_WDATA7 MUX-1
assign FAB_WDATA7 = NPU_PSUM_PORT0_BASE_TO_TOP7;

 //switch matrix multiplexer FAB_WDATA8 MUX-1
assign FAB_WDATA8 = NPU_PSUM_PORT0_BASE_TO_TOP8;

 //switch matrix multiplexer FAB_WDATA9 MUX-1
assign FAB_WDATA9 = NPU_PSUM_PORT0_BASE_TO_TOP9;

 //switch matrix multiplexer FAB_WDATA10 MUX-1
assign FAB_WDATA10 = NPU_PSUM_PORT0_BASE_TO_TOP10;

 //switch matrix multiplexer FAB_WDATA11 MUX-1
assign FAB_WDATA11 = NPU_PSUM_PORT0_BASE_TO_TOP11;

 //switch matrix multiplexer FAB_WDATA12 MUX-1
assign FAB_WDATA12 = NPU_PSUM_PORT0_BASE_TO_TOP12;

 //switch matrix multiplexer FAB_WDATA13 MUX-1
assign FAB_WDATA13 = NPU_PSUM_PORT0_BASE_TO_TOP13;

 //switch matrix multiplexer FAB_WDATA14 MUX-1
assign FAB_WDATA14 = NPU_PSUM_PORT0_BASE_TO_TOP14;

 //switch matrix multiplexer FAB_WDATA15 MUX-1
assign FAB_WDATA15 = NPU_PSUM_PORT0_BASE_TO_TOP15;

 //switch matrix multiplexer FAB_WDATA16 MUX-1
assign FAB_WDATA16 = NPU_PSUM_PORT0_BASE_TO_TOP16;

 //switch matrix multiplexer FAB_WDATA17 MUX-1
assign FAB_WDATA17 = NPU_PSUM_PORT0_BASE_TO_TOP17;

 //switch matrix multiplexer FAB_WDATA18 MUX-1
assign FAB_WDATA18 = NPU_PSUM_PORT0_BASE_TO_TOP18;

 //switch matrix multiplexer FAB_WDATA19 MUX-1
assign FAB_WDATA19 = NPU_PSUM_PORT0_BASE_TO_TOP19;

 //switch matrix multiplexer FAB_WDATA20 MUX-1
assign FAB_WDATA20 = NPU_PSUM_PORT0_BASE_TO_TOP20;

 //switch matrix multiplexer FAB_WDATA21 MUX-1
assign FAB_WDATA21 = NPU_PSUM_PORT0_BASE_TO_TOP21;

 //switch matrix multiplexer FAB_WDATA22 MUX-1
assign FAB_WDATA22 = NPU_PSUM_PORT0_BASE_TO_TOP22;

 //switch matrix multiplexer FAB_WDATA23 MUX-1
assign FAB_WDATA23 = NPU_PSUM_PORT0_BASE_TO_TOP23;

 //switch matrix multiplexer FAB_WDATA24 MUX-1
assign FAB_WDATA24 = NPU_PSUM_PORT0_BASE_TO_TOP24;

 //switch matrix multiplexer FAB_WDATA25 MUX-1
assign FAB_WDATA25 = NPU_PSUM_PORT0_BASE_TO_TOP25;

 //switch matrix multiplexer FAB_WDATA26 MUX-1
assign FAB_WDATA26 = NPU_PSUM_PORT0_BASE_TO_TOP26;

 //switch matrix multiplexer FAB_WDATA27 MUX-1
assign FAB_WDATA27 = NPU_PSUM_PORT0_BASE_TO_TOP27;

 //switch matrix multiplexer FAB_WDATA28 MUX-1
assign FAB_WDATA28 = NPU_PSUM_PORT0_BASE_TO_TOP28;

 //switch matrix multiplexer FAB_WDATA29 MUX-1
assign FAB_WDATA29 = NPU_PSUM_PORT0_BASE_TO_TOP29;

 //switch matrix multiplexer FAB_WDATA30 MUX-1
assign FAB_WDATA30 = NPU_PSUM_PORT0_BASE_TO_TOP30;

 //switch matrix multiplexer FAB_WDATA31 MUX-1
assign FAB_WDATA31 = NPU_PSUM_PORT0_BASE_TO_TOP31;

 //switch matrix multiplexer FAB_ADDR0 MUX-1
assign FAB_ADDR0 = NPU_PSUM_PORT1_BASE_TO_TOP0;

 //switch matrix multiplexer FAB_ADDR1 MUX-1
assign FAB_ADDR1 = NPU_PSUM_PORT1_BASE_TO_TOP1;

 //switch matrix multiplexer FAB_ADDR2 MUX-1
assign FAB_ADDR2 = NPU_PSUM_PORT1_BASE_TO_TOP2;

 //switch matrix multiplexer FAB_ADDR3 MUX-1
assign FAB_ADDR3 = NPU_PSUM_PORT1_BASE_TO_TOP3;

 //switch matrix multiplexer FAB_ADDR4 MUX-1
assign FAB_ADDR4 = NPU_PSUM_PORT1_BASE_TO_TOP4;

 //switch matrix multiplexer FAB_ADDR5 MUX-1
assign FAB_ADDR5 = NPU_PSUM_PORT1_BASE_TO_TOP5;

 //switch matrix multiplexer FAB_ADDR6 MUX-1
assign FAB_ADDR6 = NPU_PSUM_PORT1_BASE_TO_TOP6;

 //switch matrix multiplexer FAB_ADDR7 MUX-1
assign FAB_ADDR7 = NPU_PSUM_PORT1_BASE_TO_TOP7;

 //switch matrix multiplexer FAB_WE0 MUX-1
assign FAB_WE0 = NPU_PSUM_PORT1_BASE_TO_TOP8;

 //switch matrix multiplexer FAB_WE1 MUX-1
assign FAB_WE1 = NPU_PSUM_PORT1_BASE_TO_TOP9;

 //switch matrix multiplexer FAB_WE2 MUX-1
assign FAB_WE2 = NPU_PSUM_PORT1_BASE_TO_TOP10;

 //switch matrix multiplexer FAB_WE3 MUX-1
assign FAB_WE3 = NPU_PSUM_PORT1_BASE_TO_TOP11;

 //switch matrix multiplexer FAB_WE4 MUX-1
assign FAB_WE4 = NPU_PSUM_PORT1_BASE_TO_TOP12;

 //switch matrix multiplexer FAB_WE5 MUX-1
assign FAB_WE5 = NPU_PSUM_PORT1_BASE_TO_TOP13;

 //switch matrix multiplexer FAB_WE6 MUX-1
assign FAB_WE6 = NPU_PSUM_PORT1_BASE_TO_TOP14;

 //switch matrix multiplexer FAB_WE7 MUX-1
assign FAB_WE7 = NPU_PSUM_PORT1_BASE_TO_TOP15;

 //switch matrix multiplexer FAB_READ_BANK_SEL0 MUX-1
assign FAB_READ_BANK_SEL0 = NPU_PSUM_PORT1_BASE_TO_TOP16;

 //switch matrix multiplexer FAB_READ_BANK_SEL1 MUX-1
assign FAB_READ_BANK_SEL1 = NPU_PSUM_PORT1_BASE_TO_TOP17;

 //switch matrix multiplexer FAB_READ_BANK_SEL2 MUX-1
assign FAB_READ_BANK_SEL2 = NPU_PSUM_PORT1_BASE_TO_TOP18;

 //switch matrix multiplexer NPU_PSUM_PORT0_TOP_TO_BASE0 MUX-1
assign NPU_PSUM_PORT0_TOP_TO_BASE0 = FAB_RDATA0;

 //switch matrix multiplexer NPU_PSUM_PORT0_TOP_TO_BASE1 MUX-1
assign NPU_PSUM_PORT0_TOP_TO_BASE1 = FAB_RDATA1;

 //switch matrix multiplexer NPU_PSUM_PORT0_TOP_TO_BASE2 MUX-1
assign NPU_PSUM_PORT0_TOP_TO_BASE2 = FAB_RDATA2;

 //switch matrix multiplexer NPU_PSUM_PORT0_TOP_TO_BASE3 MUX-1
assign NPU_PSUM_PORT0_TOP_TO_BASE3 = FAB_RDATA3;

 //switch matrix multiplexer NPU_PSUM_PORT0_TOP_TO_BASE4 MUX-1
assign NPU_PSUM_PORT0_TOP_TO_BASE4 = FAB_RDATA4;

 //switch matrix multiplexer NPU_PSUM_PORT0_TOP_TO_BASE5 MUX-1
assign NPU_PSUM_PORT0_TOP_TO_BASE5 = FAB_RDATA5;

 //switch matrix multiplexer NPU_PSUM_PORT0_TOP_TO_BASE6 MUX-1
assign NPU_PSUM_PORT0_TOP_TO_BASE6 = FAB_RDATA6;

 //switch matrix multiplexer NPU_PSUM_PORT0_TOP_TO_BASE7 MUX-1
assign NPU_PSUM_PORT0_TOP_TO_BASE7 = FAB_RDATA7;

 //switch matrix multiplexer NPU_PSUM_PORT0_TOP_TO_BASE8 MUX-1
assign NPU_PSUM_PORT0_TOP_TO_BASE8 = FAB_RDATA8;

 //switch matrix multiplexer NPU_PSUM_PORT0_TOP_TO_BASE9 MUX-1
assign NPU_PSUM_PORT0_TOP_TO_BASE9 = FAB_RDATA9;

 //switch matrix multiplexer NPU_PSUM_PORT0_TOP_TO_BASE10 MUX-1
assign NPU_PSUM_PORT0_TOP_TO_BASE10 = FAB_RDATA10;

 //switch matrix multiplexer NPU_PSUM_PORT0_TOP_TO_BASE11 MUX-1
assign NPU_PSUM_PORT0_TOP_TO_BASE11 = FAB_RDATA11;

 //switch matrix multiplexer NPU_PSUM_PORT0_TOP_TO_BASE12 MUX-1
assign NPU_PSUM_PORT0_TOP_TO_BASE12 = FAB_RDATA12;

 //switch matrix multiplexer NPU_PSUM_PORT0_TOP_TO_BASE13 MUX-1
assign NPU_PSUM_PORT0_TOP_TO_BASE13 = FAB_RDATA13;

 //switch matrix multiplexer NPU_PSUM_PORT0_TOP_TO_BASE14 MUX-1
assign NPU_PSUM_PORT0_TOP_TO_BASE14 = FAB_RDATA14;

 //switch matrix multiplexer NPU_PSUM_PORT0_TOP_TO_BASE15 MUX-1
assign NPU_PSUM_PORT0_TOP_TO_BASE15 = FAB_RDATA15;

 //switch matrix multiplexer NPU_PSUM_PORT1_TOP_TO_BASE0 MUX-1
assign NPU_PSUM_PORT1_TOP_TO_BASE0 = FAB_RDATA16;

 //switch matrix multiplexer NPU_PSUM_PORT1_TOP_TO_BASE1 MUX-1
assign NPU_PSUM_PORT1_TOP_TO_BASE1 = FAB_RDATA17;

 //switch matrix multiplexer NPU_PSUM_PORT1_TOP_TO_BASE2 MUX-1
assign NPU_PSUM_PORT1_TOP_TO_BASE2 = FAB_RDATA18;

 //switch matrix multiplexer NPU_PSUM_PORT1_TOP_TO_BASE3 MUX-1
assign NPU_PSUM_PORT1_TOP_TO_BASE3 = FAB_RDATA19;

 //switch matrix multiplexer NPU_PSUM_PORT1_TOP_TO_BASE4 MUX-1
assign NPU_PSUM_PORT1_TOP_TO_BASE4 = FAB_RDATA20;

 //switch matrix multiplexer NPU_PSUM_PORT1_TOP_TO_BASE5 MUX-1
assign NPU_PSUM_PORT1_TOP_TO_BASE5 = FAB_RDATA21;

 //switch matrix multiplexer NPU_PSUM_PORT1_TOP_TO_BASE6 MUX-1
assign NPU_PSUM_PORT1_TOP_TO_BASE6 = FAB_RDATA22;

 //switch matrix multiplexer NPU_PSUM_PORT1_TOP_TO_BASE7 MUX-1
assign NPU_PSUM_PORT1_TOP_TO_BASE7 = FAB_RDATA23;

 //switch matrix multiplexer NPU_PSUM_PORT1_TOP_TO_BASE8 MUX-1
assign NPU_PSUM_PORT1_TOP_TO_BASE8 = FAB_RDATA24;

 //switch matrix multiplexer NPU_PSUM_PORT1_TOP_TO_BASE9 MUX-1
assign NPU_PSUM_PORT1_TOP_TO_BASE9 = FAB_RDATA25;

 //switch matrix multiplexer NPU_PSUM_PORT1_TOP_TO_BASE10 MUX-1
assign NPU_PSUM_PORT1_TOP_TO_BASE10 = FAB_RDATA26;

 //switch matrix multiplexer NPU_PSUM_PORT1_TOP_TO_BASE11 MUX-1
assign NPU_PSUM_PORT1_TOP_TO_BASE11 = FAB_RDATA27;

 //switch matrix multiplexer NPU_PSUM_PORT1_TOP_TO_BASE12 MUX-1
assign NPU_PSUM_PORT1_TOP_TO_BASE12 = FAB_RDATA28;

 //switch matrix multiplexer NPU_PSUM_PORT1_TOP_TO_BASE13 MUX-1
assign NPU_PSUM_PORT1_TOP_TO_BASE13 = FAB_RDATA29;

 //switch matrix multiplexer NPU_PSUM_PORT1_TOP_TO_BASE14 MUX-1
assign NPU_PSUM_PORT1_TOP_TO_BASE14 = FAB_RDATA30;

 //switch matrix multiplexer NPU_PSUM_PORT1_TOP_TO_BASE15 MUX-1
assign NPU_PSUM_PORT1_TOP_TO_BASE15 = FAB_RDATA31;

endmodule