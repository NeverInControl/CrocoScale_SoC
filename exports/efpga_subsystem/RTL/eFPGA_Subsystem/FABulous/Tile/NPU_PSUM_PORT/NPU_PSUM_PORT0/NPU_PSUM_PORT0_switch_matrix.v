 // NumberOfConfigBits: 0
module NPU_PSUM_PORT0_switch_matrix
    (
        input  N1END0,
        input  N1END1,
        input  N1END2,
        input  N1END3,
        input  N2MID0,
        input  N2MID1,
        input  N2MID2,
        input  N2MID3,
        input  N2MID4,
        input  N2MID5,
        input  N2MID6,
        input  N2MID7,
        input  N2END0,
        input  N2END1,
        input  N2END2,
        input  N2END3,
        input  N2END4,
        input  N2END5,
        input  N2END6,
        input  N2END7,
        input  N4END0,
        input  N4END1,
        input  N4END2,
        input  N4END3,
        input  N4END4,
        input  N4END5,
        input  N4END6,
        input  N4END7,
        input  N4END8,
        input  N4END9,
        input  N4END10,
        input  N4END11,
        input  N4END12,
        input  N4END13,
        input  N4END14,
        input  N4END15,
        input  NN4END0,
        input  NN4END1,
        input  NN4END2,
        input  NN4END3,
        input  NN4END4,
        input  NN4END5,
        input  NN4END6,
        input  NN4END7,
        input  NN4END8,
        input  NN4END9,
        input  NN4END10,
        input  NN4END11,
        input  NN4END12,
        input  NN4END13,
        input  NN4END14,
        input  NN4END15,
        input  Ci0,
        output  S1BEG0,
        output  S1BEG1,
        output  S1BEG2,
        output  S1BEG3,
        output  S2BEG0,
        output  S2BEG1,
        output  S2BEG2,
        output  S2BEG3,
        output  S2BEG4,
        output  S2BEG5,
        output  S2BEG6,
        output  S2BEG7,
        output  S2BEGb0,
        output  S2BEGb1,
        output  S2BEGb2,
        output  S2BEGb3,
        output  S2BEGb4,
        output  S2BEGb5,
        output  S2BEGb6,
        output  S2BEGb7,
        output  S4BEG0,
        output  S4BEG1,
        output  S4BEG2,
        output  S4BEG3,
        output  S4BEG4,
        output  S4BEG5,
        output  S4BEG6,
        output  S4BEG7,
        output  S4BEG8,
        output  S4BEG9,
        output  S4BEG10,
        output  S4BEG11,
        output  S4BEG12,
        output  S4BEG13,
        output  S4BEG14,
        output  S4BEG15,
        output  SS4BEG0,
        output  SS4BEG1,
        output  SS4BEG2,
        output  SS4BEG3,
        output  SS4BEG4,
        output  SS4BEG5,
        output  SS4BEG6,
        output  SS4BEG7,
        output  SS4BEG8,
        output  SS4BEG9,
        output  SS4BEG10,
        output  SS4BEG11,
        output  SS4BEG12,
        output  SS4BEG13,
        output  SS4BEG14,
        output  SS4BEG15,
        output  BASE_TO_TOP0,
        output  BASE_TO_TOP1,
        output  BASE_TO_TOP2,
        output  BASE_TO_TOP3,
        output  BASE_TO_TOP4,
        output  BASE_TO_TOP5,
        output  BASE_TO_TOP6,
        output  BASE_TO_TOP7,
        output  BASE_TO_TOP8,
        output  BASE_TO_TOP9,
        output  BASE_TO_TOP10,
        output  BASE_TO_TOP11,
        output  BASE_TO_TOP12,
        output  BASE_TO_TOP13,
        output  BASE_TO_TOP14,
        output  BASE_TO_TOP15,
        output  BASE_TO_TOP16,
        output  BASE_TO_TOP17,
        output  BASE_TO_TOP18,
        output  BASE_TO_TOP19,
        output  BASE_TO_TOP20,
        output  BASE_TO_TOP21,
        output  BASE_TO_TOP22,
        output  BASE_TO_TOP23,
        output  BASE_TO_TOP24,
        output  BASE_TO_TOP25,
        output  BASE_TO_TOP26,
        output  BASE_TO_TOP27,
        output  BASE_TO_TOP28,
        output  BASE_TO_TOP29,
        output  BASE_TO_TOP30,
        output  BASE_TO_TOP31,
        input  TOP_TO_BASE0,
        input  TOP_TO_BASE1,
        input  TOP_TO_BASE2,
        input  TOP_TO_BASE3,
        input  TOP_TO_BASE4,
        input  TOP_TO_BASE5,
        input  TOP_TO_BASE6,
        input  TOP_TO_BASE7,
        input  TOP_TO_BASE8,
        input  TOP_TO_BASE9,
        input  TOP_TO_BASE10,
        input  TOP_TO_BASE11,
        input  TOP_TO_BASE12,
        input  TOP_TO_BASE13,
        input  TOP_TO_BASE14,
        input  TOP_TO_BASE15
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
 //switch matrix multiplexer S1BEG0 MUX-1
assign S1BEG0 = N1END3;

 //switch matrix multiplexer S1BEG1 MUX-1
assign S1BEG1 = N1END2;

 //switch matrix multiplexer S1BEG2 MUX-1
assign S1BEG2 = N1END1;

 //switch matrix multiplexer S1BEG3 MUX-1
assign S1BEG3 = N1END0;

 //switch matrix multiplexer S2BEG0 MUX-1
assign S2BEG0 = N2MID7;

 //switch matrix multiplexer S2BEG1 MUX-1
assign S2BEG1 = N2MID6;

 //switch matrix multiplexer S2BEG2 MUX-1
assign S2BEG2 = N2MID5;

 //switch matrix multiplexer S2BEG3 MUX-1
assign S2BEG3 = N2MID4;

 //switch matrix multiplexer S2BEG4 MUX-1
assign S2BEG4 = N2MID3;

 //switch matrix multiplexer S2BEG5 MUX-1
assign S2BEG5 = N2MID2;

 //switch matrix multiplexer S2BEG6 MUX-1
assign S2BEG6 = N2MID1;

 //switch matrix multiplexer S2BEG7 MUX-1
assign S2BEG7 = N2MID0;

 //switch matrix multiplexer S2BEGb0 MUX-1
assign S2BEGb0 = N2END7;

 //switch matrix multiplexer S2BEGb1 MUX-1
assign S2BEGb1 = N2END6;

 //switch matrix multiplexer S2BEGb2 MUX-1
assign S2BEGb2 = N2END5;

 //switch matrix multiplexer S2BEGb3 MUX-1
assign S2BEGb3 = N2END4;

 //switch matrix multiplexer S2BEGb4 MUX-1
assign S2BEGb4 = N2END3;

 //switch matrix multiplexer S2BEGb5 MUX-1
assign S2BEGb5 = N2END2;

 //switch matrix multiplexer S2BEGb6 MUX-1
assign S2BEGb6 = N2END1;

 //switch matrix multiplexer S2BEGb7 MUX-1
assign S2BEGb7 = N2END0;

 //switch matrix multiplexer S4BEG0 MUX-1
assign S4BEG0 = TOP_TO_BASE15;

 //switch matrix multiplexer S4BEG1 MUX-1
assign S4BEG1 = TOP_TO_BASE14;

 //switch matrix multiplexer S4BEG2 MUX-1
assign S4BEG2 = TOP_TO_BASE13;

 //switch matrix multiplexer S4BEG3 MUX-1
assign S4BEG3 = TOP_TO_BASE12;

 //switch matrix multiplexer S4BEG4 MUX-1
assign S4BEG4 = TOP_TO_BASE11;

 //switch matrix multiplexer S4BEG5 MUX-1
assign S4BEG5 = TOP_TO_BASE10;

 //switch matrix multiplexer S4BEG6 MUX-1
assign S4BEG6 = TOP_TO_BASE9;

 //switch matrix multiplexer S4BEG7 MUX-1
assign S4BEG7 = TOP_TO_BASE8;

 //switch matrix multiplexer S4BEG8 MUX-1
assign S4BEG8 = TOP_TO_BASE7;

 //switch matrix multiplexer S4BEG9 MUX-1
assign S4BEG9 = TOP_TO_BASE6;

 //switch matrix multiplexer S4BEG10 MUX-1
assign S4BEG10 = TOP_TO_BASE5;

 //switch matrix multiplexer S4BEG11 MUX-1
assign S4BEG11 = TOP_TO_BASE4;

 //switch matrix multiplexer S4BEG12 MUX-1
assign S4BEG12 = TOP_TO_BASE3;

 //switch matrix multiplexer S4BEG13 MUX-1
assign S4BEG13 = TOP_TO_BASE2;

 //switch matrix multiplexer S4BEG14 MUX-1
assign S4BEG14 = TOP_TO_BASE1;

 //switch matrix multiplexer S4BEG15 MUX-1
assign S4BEG15 = TOP_TO_BASE0;

 //switch matrix multiplexer SS4BEG0 MUX-1
assign SS4BEG0 = NN4END15;

 //switch matrix multiplexer SS4BEG1 MUX-1
assign SS4BEG1 = NN4END14;

 //switch matrix multiplexer SS4BEG2 MUX-1
assign SS4BEG2 = NN4END13;

 //switch matrix multiplexer SS4BEG3 MUX-1
assign SS4BEG3 = NN4END12;

 //switch matrix multiplexer SS4BEG4 MUX-1
assign SS4BEG4 = NN4END11;

 //switch matrix multiplexer SS4BEG5 MUX-1
assign SS4BEG5 = NN4END10;

 //switch matrix multiplexer SS4BEG6 MUX-1
assign SS4BEG6 = NN4END9;

 //switch matrix multiplexer SS4BEG7 MUX-1
assign SS4BEG7 = NN4END8;

 //switch matrix multiplexer SS4BEG8 MUX-1
assign SS4BEG8 = NN4END7;

 //switch matrix multiplexer SS4BEG9 MUX-1
assign SS4BEG9 = NN4END6;

 //switch matrix multiplexer SS4BEG10 MUX-1
assign SS4BEG10 = NN4END5;

 //switch matrix multiplexer SS4BEG11 MUX-1
assign SS4BEG11 = NN4END4;

 //switch matrix multiplexer SS4BEG12 MUX-1
assign SS4BEG12 = NN4END3;

 //switch matrix multiplexer SS4BEG13 MUX-1
assign SS4BEG13 = NN4END2;

 //switch matrix multiplexer SS4BEG14 MUX-1
assign SS4BEG14 = NN4END1;

 //switch matrix multiplexer SS4BEG15 MUX-1
assign SS4BEG15 = NN4END0;

 //switch matrix multiplexer BASE_TO_TOP0 MUX-1
assign BASE_TO_TOP0 = N4END15;

 //switch matrix multiplexer BASE_TO_TOP1 MUX-1
assign BASE_TO_TOP1 = N4END14;

 //switch matrix multiplexer BASE_TO_TOP2 MUX-1
assign BASE_TO_TOP2 = N4END13;

 //switch matrix multiplexer BASE_TO_TOP3 MUX-1
assign BASE_TO_TOP3 = N4END12;

 //switch matrix multiplexer BASE_TO_TOP4 MUX-1
assign BASE_TO_TOP4 = N4END11;

 //switch matrix multiplexer BASE_TO_TOP5 MUX-1
assign BASE_TO_TOP5 = N4END10;

 //switch matrix multiplexer BASE_TO_TOP6 MUX-1
assign BASE_TO_TOP6 = N4END9;

 //switch matrix multiplexer BASE_TO_TOP7 MUX-1
assign BASE_TO_TOP7 = N4END8;

 //switch matrix multiplexer BASE_TO_TOP8 MUX-1
assign BASE_TO_TOP8 = N4END7;

 //switch matrix multiplexer BASE_TO_TOP9 MUX-1
assign BASE_TO_TOP9 = N4END6;

 //switch matrix multiplexer BASE_TO_TOP10 MUX-1
assign BASE_TO_TOP10 = N4END5;

 //switch matrix multiplexer BASE_TO_TOP11 MUX-1
assign BASE_TO_TOP11 = N4END4;

 //switch matrix multiplexer BASE_TO_TOP12 MUX-1
assign BASE_TO_TOP12 = N4END3;

 //switch matrix multiplexer BASE_TO_TOP13 MUX-1
assign BASE_TO_TOP13 = N4END2;

 //switch matrix multiplexer BASE_TO_TOP14 MUX-1
assign BASE_TO_TOP14 = N4END1;

 //switch matrix multiplexer BASE_TO_TOP15 MUX-1
assign BASE_TO_TOP15 = N4END0;

 //switch matrix multiplexer BASE_TO_TOP16 MUX-1
assign BASE_TO_TOP16 = NN4END15;

 //switch matrix multiplexer BASE_TO_TOP17 MUX-1
assign BASE_TO_TOP17 = NN4END14;

 //switch matrix multiplexer BASE_TO_TOP18 MUX-1
assign BASE_TO_TOP18 = NN4END13;

 //switch matrix multiplexer BASE_TO_TOP19 MUX-1
assign BASE_TO_TOP19 = NN4END12;

 //switch matrix multiplexer BASE_TO_TOP20 MUX-1
assign BASE_TO_TOP20 = NN4END11;

 //switch matrix multiplexer BASE_TO_TOP21 MUX-1
assign BASE_TO_TOP21 = NN4END10;

 //switch matrix multiplexer BASE_TO_TOP22 MUX-1
assign BASE_TO_TOP22 = NN4END9;

 //switch matrix multiplexer BASE_TO_TOP23 MUX-1
assign BASE_TO_TOP23 = NN4END8;

 //switch matrix multiplexer BASE_TO_TOP24 MUX-1
assign BASE_TO_TOP24 = NN4END7;

 //switch matrix multiplexer BASE_TO_TOP25 MUX-1
assign BASE_TO_TOP25 = NN4END6;

 //switch matrix multiplexer BASE_TO_TOP26 MUX-1
assign BASE_TO_TOP26 = NN4END5;

 //switch matrix multiplexer BASE_TO_TOP27 MUX-1
assign BASE_TO_TOP27 = NN4END4;

 //switch matrix multiplexer BASE_TO_TOP28 MUX-1
assign BASE_TO_TOP28 = NN4END3;

 //switch matrix multiplexer BASE_TO_TOP29 MUX-1
assign BASE_TO_TOP29 = NN4END2;

 //switch matrix multiplexer BASE_TO_TOP30 MUX-1
assign BASE_TO_TOP30 = NN4END1;

 //switch matrix multiplexer BASE_TO_TOP31 MUX-1
assign BASE_TO_TOP31 = NN4END0;

endmodule