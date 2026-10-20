 // NumberOfConfigBits: 0
module EXT_PMOD_switch_matrix
    (
 //SJUMP inputs from child tiles
        input  EXT_PMOD_0_BASE_TO_TOP0,
        input  EXT_PMOD_0_BASE_TO_TOP1,
        input  EXT_PMOD_0_BASE_TO_TOP2,
        input  EXT_PMOD_0_BASE_TO_TOP3,
        input  EXT_PMOD_0_BASE_TO_TOP4,
        input  EXT_PMOD_0_BASE_TO_TOP5,
        input  EXT_PMOD_1_BASE_TO_TOP0,
        input  EXT_PMOD_1_BASE_TO_TOP1,
        input  EXT_PMOD_1_BASE_TO_TOP2,
        input  EXT_PMOD_1_BASE_TO_TOP3,
        input  EXT_PMOD_1_BASE_TO_TOP4,
        input  EXT_PMOD_1_BASE_TO_TOP5,
        input  EXT_PMOD_1_BASE_TO_TOP6,
        input  EXT_PMOD_1_BASE_TO_TOP7,
        input  EXT_PMOD_1_BASE_TO_TOP8,
        input  EXT_PMOD_1_BASE_TO_TOP9,
 //BEL input ports (SM outputs)
        output  FAB_PMOD_O0,
        output  FAB_PMOD_O1,
        output  FAB_PMOD_O2,
        output  FAB_PMOD_O3,
        output  FAB_PMOD_O4,
        output  FAB_PMOD_O5,
        output  FAB_PMOD_O6,
        output  FAB_PMOD_O7,
        output  FAB_PMOD_OE0,
        output  FAB_PMOD_OE1,
        output  FAB_PMOD_OE2,
        output  FAB_PMOD_OE3,
        output  FAB_PMOD_OE4,
        output  FAB_PMOD_OE5,
        output  FAB_PMOD_OE6,
        output  FAB_PMOD_OE7,
 //BEL output ports (SM inputs)
        input  FAB_PMOD_I0,
        input  FAB_PMOD_I1,
        input  FAB_PMOD_I2,
        input  FAB_PMOD_I3,
        input  FAB_PMOD_I4,
        input  FAB_PMOD_I5,
        input  FAB_PMOD_I6,
        input  FAB_PMOD_I7,
 //Reverse SJUMP outputs (SM -> child tile)
        output  EXT_PMOD_0_TOP_TO_BASE0,
        output  EXT_PMOD_0_TOP_TO_BASE1,
        output  EXT_PMOD_0_TOP_TO_BASE2,
        output  EXT_PMOD_1_TOP_TO_BASE0,
        output  EXT_PMOD_1_TOP_TO_BASE1,
        output  EXT_PMOD_1_TOP_TO_BASE2,
        output  EXT_PMOD_1_TOP_TO_BASE3,
        output  EXT_PMOD_1_TOP_TO_BASE4
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
 //switch matrix multiplexer FAB_PMOD_O0 MUX-1
assign FAB_PMOD_O0 = EXT_PMOD_0_BASE_TO_TOP0;

 //switch matrix multiplexer FAB_PMOD_OE0 MUX-1
assign FAB_PMOD_OE0 = EXT_PMOD_0_BASE_TO_TOP1;

 //switch matrix multiplexer FAB_PMOD_O1 MUX-1
assign FAB_PMOD_O1 = EXT_PMOD_0_BASE_TO_TOP2;

 //switch matrix multiplexer FAB_PMOD_OE1 MUX-1
assign FAB_PMOD_OE1 = EXT_PMOD_0_BASE_TO_TOP3;

 //switch matrix multiplexer FAB_PMOD_O2 MUX-1
assign FAB_PMOD_O2 = EXT_PMOD_0_BASE_TO_TOP4;

 //switch matrix multiplexer FAB_PMOD_OE2 MUX-1
assign FAB_PMOD_OE2 = EXT_PMOD_0_BASE_TO_TOP5;

 //switch matrix multiplexer EXT_PMOD_0_TOP_TO_BASE0 MUX-1
assign EXT_PMOD_0_TOP_TO_BASE0 = FAB_PMOD_I0;

 //switch matrix multiplexer EXT_PMOD_0_TOP_TO_BASE1 MUX-1
assign EXT_PMOD_0_TOP_TO_BASE1 = FAB_PMOD_I1;

 //switch matrix multiplexer EXT_PMOD_0_TOP_TO_BASE2 MUX-1
assign EXT_PMOD_0_TOP_TO_BASE2 = FAB_PMOD_I2;

 //switch matrix multiplexer FAB_PMOD_O3 MUX-1
assign FAB_PMOD_O3 = EXT_PMOD_1_BASE_TO_TOP0;

 //switch matrix multiplexer FAB_PMOD_OE3 MUX-1
assign FAB_PMOD_OE3 = EXT_PMOD_1_BASE_TO_TOP1;

 //switch matrix multiplexer FAB_PMOD_O4 MUX-1
assign FAB_PMOD_O4 = EXT_PMOD_1_BASE_TO_TOP2;

 //switch matrix multiplexer FAB_PMOD_OE4 MUX-1
assign FAB_PMOD_OE4 = EXT_PMOD_1_BASE_TO_TOP3;

 //switch matrix multiplexer FAB_PMOD_O5 MUX-1
assign FAB_PMOD_O5 = EXT_PMOD_1_BASE_TO_TOP4;

 //switch matrix multiplexer FAB_PMOD_OE5 MUX-1
assign FAB_PMOD_OE5 = EXT_PMOD_1_BASE_TO_TOP5;

 //switch matrix multiplexer FAB_PMOD_O6 MUX-1
assign FAB_PMOD_O6 = EXT_PMOD_1_BASE_TO_TOP6;

 //switch matrix multiplexer FAB_PMOD_OE6 MUX-1
assign FAB_PMOD_OE6 = EXT_PMOD_1_BASE_TO_TOP7;

 //switch matrix multiplexer FAB_PMOD_O7 MUX-1
assign FAB_PMOD_O7 = EXT_PMOD_1_BASE_TO_TOP8;

 //switch matrix multiplexer FAB_PMOD_OE7 MUX-1
assign FAB_PMOD_OE7 = EXT_PMOD_1_BASE_TO_TOP9;

 //switch matrix multiplexer EXT_PMOD_1_TOP_TO_BASE0 MUX-1
assign EXT_PMOD_1_TOP_TO_BASE0 = FAB_PMOD_I3;

 //switch matrix multiplexer EXT_PMOD_1_TOP_TO_BASE1 MUX-1
assign EXT_PMOD_1_TOP_TO_BASE1 = FAB_PMOD_I4;

 //switch matrix multiplexer EXT_PMOD_1_TOP_TO_BASE2 MUX-1
assign EXT_PMOD_1_TOP_TO_BASE2 = FAB_PMOD_I5;

 //switch matrix multiplexer EXT_PMOD_1_TOP_TO_BASE3 MUX-1
assign EXT_PMOD_1_TOP_TO_BASE3 = FAB_PMOD_I6;

 //switch matrix multiplexer EXT_PMOD_1_TOP_TO_BASE4 MUX-1
assign EXT_PMOD_1_TOP_TO_BASE4 = FAB_PMOD_I7;

endmodule