 // NumberOfConfigBits: 36
module NPU_CTRL_CFG_0_switch_matrix
    #(
        parameter NoConfigBits=36
    )
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
 //global
        input  [NoConfigBits-1:0] ConfigBits,
        input  [NoConfigBits-1:0] ConfigBits_N
);
parameter GND0 = 1'b0;
parameter GND = 1'b0;
parameter VCC0 = 1'b1;
parameter VCC = 1'b1;
parameter VDD0 = 1'b1;
parameter VDD = 1'b1;

wire[4-1:0] BASE_TO_TOP0_input;
wire[4-1:0] BASE_TO_TOP1_input;
wire[4-1:0] BASE_TO_TOP2_input;
wire[4-1:0] BASE_TO_TOP3_input;
wire[4-1:0] BASE_TO_TOP4_input;
wire[4-1:0] BASE_TO_TOP5_input;
wire[4-1:0] BASE_TO_TOP6_input;
wire[4-1:0] BASE_TO_TOP7_input;
wire[4-1:0] BASE_TO_TOP8_input;
wire[4-1:0] BASE_TO_TOP9_input;
wire[4-1:0] BASE_TO_TOP10_input;
wire[4-1:0] BASE_TO_TOP11_input;
wire[4-1:0] BASE_TO_TOP12_input;
wire[4-1:0] BASE_TO_TOP13_input;
wire[4-1:0] BASE_TO_TOP14_input;
wire[4-1:0] BASE_TO_TOP15_input;
wire[4-1:0] BASE_TO_TOP16_input;
wire[4-1:0] BASE_TO_TOP17_input;
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
assign S4BEG0 = N4END15;

 //switch matrix multiplexer S4BEG1 MUX-1
assign S4BEG1 = N4END14;

 //switch matrix multiplexer S4BEG2 MUX-1
assign S4BEG2 = N4END13;

 //switch matrix multiplexer S4BEG3 MUX-1
assign S4BEG3 = N4END12;

 //switch matrix multiplexer S4BEG4 MUX-1
assign S4BEG4 = N4END11;

 //switch matrix multiplexer S4BEG5 MUX-1
assign S4BEG5 = N4END10;

 //switch matrix multiplexer S4BEG6 MUX-1
assign S4BEG6 = N4END9;

 //switch matrix multiplexer S4BEG7 MUX-1
assign S4BEG7 = N4END8;

 //switch matrix multiplexer S4BEG8 MUX-1
assign S4BEG8 = N4END7;

 //switch matrix multiplexer S4BEG9 MUX-1
assign S4BEG9 = N4END6;

 //switch matrix multiplexer S4BEG10 MUX-1
assign S4BEG10 = N4END5;

 //switch matrix multiplexer S4BEG11 MUX-1
assign S4BEG11 = N4END4;

 //switch matrix multiplexer S4BEG12 MUX-1
assign S4BEG12 = N4END3;

 //switch matrix multiplexer S4BEG13 MUX-1
assign S4BEG13 = N4END2;

 //switch matrix multiplexer S4BEG14 MUX-1
assign S4BEG14 = N4END1;

 //switch matrix multiplexer S4BEG15 MUX-1
assign S4BEG15 = N4END0;

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

 //switch matrix multiplexer BASE_TO_TOP0 MUX-4
assign BASE_TO_TOP0_input = {NN4END2,NN4END0,N4END1,N4END0};
cus_mux41 inst_cus_mux41_BASE_TO_TOP0 (
    .A0(BASE_TO_TOP0_input[0]),
    .A1(BASE_TO_TOP0_input[1]),
    .A2(BASE_TO_TOP0_input[2]),
    .A3(BASE_TO_TOP0_input[3]),
    .S0(ConfigBits[0+0]),
    .S0N(ConfigBits_N[0+0]),
    .S1(ConfigBits[0+1]),
    .S1N(ConfigBits_N[0+1]),
    .X(BASE_TO_TOP0)
);

 //switch matrix multiplexer BASE_TO_TOP1 MUX-4
assign BASE_TO_TOP1_input = {NN4END3,NN4END1,N4END2,N4END1};
cus_mux41 inst_cus_mux41_BASE_TO_TOP1 (
    .A0(BASE_TO_TOP1_input[0]),
    .A1(BASE_TO_TOP1_input[1]),
    .A2(BASE_TO_TOP1_input[2]),
    .A3(BASE_TO_TOP1_input[3]),
    .S0(ConfigBits[2+0]),
    .S0N(ConfigBits_N[2+0]),
    .S1(ConfigBits[2+1]),
    .S1N(ConfigBits_N[2+1]),
    .X(BASE_TO_TOP1)
);

 //switch matrix multiplexer BASE_TO_TOP2 MUX-4
assign BASE_TO_TOP2_input = {NN4END2,NN4END0,N4END3,N4END2};
cus_mux41 inst_cus_mux41_BASE_TO_TOP2 (
    .A0(BASE_TO_TOP2_input[0]),
    .A1(BASE_TO_TOP2_input[1]),
    .A2(BASE_TO_TOP2_input[2]),
    .A3(BASE_TO_TOP2_input[3]),
    .S0(ConfigBits[4+0]),
    .S0N(ConfigBits_N[4+0]),
    .S1(ConfigBits[4+1]),
    .S1N(ConfigBits_N[4+1]),
    .X(BASE_TO_TOP2)
);

 //switch matrix multiplexer BASE_TO_TOP3 MUX-4
assign BASE_TO_TOP3_input = {NN4END3,NN4END1,N4END3,N4END0};
cus_mux41 inst_cus_mux41_BASE_TO_TOP3 (
    .A0(BASE_TO_TOP3_input[0]),
    .A1(BASE_TO_TOP3_input[1]),
    .A2(BASE_TO_TOP3_input[2]),
    .A3(BASE_TO_TOP3_input[3]),
    .S0(ConfigBits[6+0]),
    .S0N(ConfigBits_N[6+0]),
    .S1(ConfigBits[6+1]),
    .S1N(ConfigBits_N[6+1]),
    .X(BASE_TO_TOP3)
);

 //switch matrix multiplexer BASE_TO_TOP4 MUX-4
assign BASE_TO_TOP4_input = {NN4END6,NN4END4,N4END5,N4END4};
cus_mux41 inst_cus_mux41_BASE_TO_TOP4 (
    .A0(BASE_TO_TOP4_input[0]),
    .A1(BASE_TO_TOP4_input[1]),
    .A2(BASE_TO_TOP4_input[2]),
    .A3(BASE_TO_TOP4_input[3]),
    .S0(ConfigBits[8+0]),
    .S0N(ConfigBits_N[8+0]),
    .S1(ConfigBits[8+1]),
    .S1N(ConfigBits_N[8+1]),
    .X(BASE_TO_TOP4)
);

 //switch matrix multiplexer BASE_TO_TOP5 MUX-4
assign BASE_TO_TOP5_input = {NN4END7,NN4END5,N4END6,N4END5};
cus_mux41 inst_cus_mux41_BASE_TO_TOP5 (
    .A0(BASE_TO_TOP5_input[0]),
    .A1(BASE_TO_TOP5_input[1]),
    .A2(BASE_TO_TOP5_input[2]),
    .A3(BASE_TO_TOP5_input[3]),
    .S0(ConfigBits[10+0]),
    .S0N(ConfigBits_N[10+0]),
    .S1(ConfigBits[10+1]),
    .S1N(ConfigBits_N[10+1]),
    .X(BASE_TO_TOP5)
);

 //switch matrix multiplexer BASE_TO_TOP6 MUX-4
assign BASE_TO_TOP6_input = {NN4END6,NN4END4,N4END7,N4END6};
cus_mux41 inst_cus_mux41_BASE_TO_TOP6 (
    .A0(BASE_TO_TOP6_input[0]),
    .A1(BASE_TO_TOP6_input[1]),
    .A2(BASE_TO_TOP6_input[2]),
    .A3(BASE_TO_TOP6_input[3]),
    .S0(ConfigBits[12+0]),
    .S0N(ConfigBits_N[12+0]),
    .S1(ConfigBits[12+1]),
    .S1N(ConfigBits_N[12+1]),
    .X(BASE_TO_TOP6)
);

 //switch matrix multiplexer BASE_TO_TOP7 MUX-4
assign BASE_TO_TOP7_input = {NN4END7,NN4END5,N4END7,N4END4};
cus_mux41 inst_cus_mux41_BASE_TO_TOP7 (
    .A0(BASE_TO_TOP7_input[0]),
    .A1(BASE_TO_TOP7_input[1]),
    .A2(BASE_TO_TOP7_input[2]),
    .A3(BASE_TO_TOP7_input[3]),
    .S0(ConfigBits[14+0]),
    .S0N(ConfigBits_N[14+0]),
    .S1(ConfigBits[14+1]),
    .S1N(ConfigBits_N[14+1]),
    .X(BASE_TO_TOP7)
);

 //switch matrix multiplexer BASE_TO_TOP8 MUX-4
assign BASE_TO_TOP8_input = {NN4END10,NN4END8,N4END9,N4END8};
cus_mux41 inst_cus_mux41_BASE_TO_TOP8 (
    .A0(BASE_TO_TOP8_input[0]),
    .A1(BASE_TO_TOP8_input[1]),
    .A2(BASE_TO_TOP8_input[2]),
    .A3(BASE_TO_TOP8_input[3]),
    .S0(ConfigBits[16+0]),
    .S0N(ConfigBits_N[16+0]),
    .S1(ConfigBits[16+1]),
    .S1N(ConfigBits_N[16+1]),
    .X(BASE_TO_TOP8)
);

 //switch matrix multiplexer BASE_TO_TOP9 MUX-4
assign BASE_TO_TOP9_input = {NN4END11,NN4END9,N4END10,N4END9};
cus_mux41 inst_cus_mux41_BASE_TO_TOP9 (
    .A0(BASE_TO_TOP9_input[0]),
    .A1(BASE_TO_TOP9_input[1]),
    .A2(BASE_TO_TOP9_input[2]),
    .A3(BASE_TO_TOP9_input[3]),
    .S0(ConfigBits[18+0]),
    .S0N(ConfigBits_N[18+0]),
    .S1(ConfigBits[18+1]),
    .S1N(ConfigBits_N[18+1]),
    .X(BASE_TO_TOP9)
);

 //switch matrix multiplexer BASE_TO_TOP10 MUX-4
assign BASE_TO_TOP10_input = {NN4END10,NN4END8,N4END11,N4END10};
cus_mux41 inst_cus_mux41_BASE_TO_TOP10 (
    .A0(BASE_TO_TOP10_input[0]),
    .A1(BASE_TO_TOP10_input[1]),
    .A2(BASE_TO_TOP10_input[2]),
    .A3(BASE_TO_TOP10_input[3]),
    .S0(ConfigBits[20+0]),
    .S0N(ConfigBits_N[20+0]),
    .S1(ConfigBits[20+1]),
    .S1N(ConfigBits_N[20+1]),
    .X(BASE_TO_TOP10)
);

 //switch matrix multiplexer BASE_TO_TOP11 MUX-4
assign BASE_TO_TOP11_input = {NN4END11,NN4END9,N4END11,N4END8};
cus_mux41 inst_cus_mux41_BASE_TO_TOP11 (
    .A0(BASE_TO_TOP11_input[0]),
    .A1(BASE_TO_TOP11_input[1]),
    .A2(BASE_TO_TOP11_input[2]),
    .A3(BASE_TO_TOP11_input[3]),
    .S0(ConfigBits[22+0]),
    .S0N(ConfigBits_N[22+0]),
    .S1(ConfigBits[22+1]),
    .S1N(ConfigBits_N[22+1]),
    .X(BASE_TO_TOP11)
);

 //switch matrix multiplexer BASE_TO_TOP12 MUX-4
assign BASE_TO_TOP12_input = {NN4END14,NN4END12,N4END13,N4END12};
cus_mux41 inst_cus_mux41_BASE_TO_TOP12 (
    .A0(BASE_TO_TOP12_input[0]),
    .A1(BASE_TO_TOP12_input[1]),
    .A2(BASE_TO_TOP12_input[2]),
    .A3(BASE_TO_TOP12_input[3]),
    .S0(ConfigBits[24+0]),
    .S0N(ConfigBits_N[24+0]),
    .S1(ConfigBits[24+1]),
    .S1N(ConfigBits_N[24+1]),
    .X(BASE_TO_TOP12)
);

 //switch matrix multiplexer BASE_TO_TOP13 MUX-4
assign BASE_TO_TOP13_input = {NN4END15,NN4END13,N4END14,N4END13};
cus_mux41 inst_cus_mux41_BASE_TO_TOP13 (
    .A0(BASE_TO_TOP13_input[0]),
    .A1(BASE_TO_TOP13_input[1]),
    .A2(BASE_TO_TOP13_input[2]),
    .A3(BASE_TO_TOP13_input[3]),
    .S0(ConfigBits[26+0]),
    .S0N(ConfigBits_N[26+0]),
    .S1(ConfigBits[26+1]),
    .S1N(ConfigBits_N[26+1]),
    .X(BASE_TO_TOP13)
);

 //switch matrix multiplexer BASE_TO_TOP14 MUX-4
assign BASE_TO_TOP14_input = {NN4END14,NN4END12,N4END15,N4END14};
cus_mux41 inst_cus_mux41_BASE_TO_TOP14 (
    .A0(BASE_TO_TOP14_input[0]),
    .A1(BASE_TO_TOP14_input[1]),
    .A2(BASE_TO_TOP14_input[2]),
    .A3(BASE_TO_TOP14_input[3]),
    .S0(ConfigBits[28+0]),
    .S0N(ConfigBits_N[28+0]),
    .S1(ConfigBits[28+1]),
    .S1N(ConfigBits_N[28+1]),
    .X(BASE_TO_TOP14)
);

 //switch matrix multiplexer BASE_TO_TOP15 MUX-4
assign BASE_TO_TOP15_input = {N2END7,N2MID7,N2MID0,N1END0};
cus_mux41 inst_cus_mux41_BASE_TO_TOP15 (
    .A0(BASE_TO_TOP15_input[0]),
    .A1(BASE_TO_TOP15_input[1]),
    .A2(BASE_TO_TOP15_input[2]),
    .A3(BASE_TO_TOP15_input[3]),
    .S0(ConfigBits[30+0]),
    .S0N(ConfigBits_N[30+0]),
    .S1(ConfigBits[30+1]),
    .S1N(ConfigBits_N[30+1]),
    .X(BASE_TO_TOP15)
);

 //switch matrix multiplexer BASE_TO_TOP16 MUX-4
assign BASE_TO_TOP16_input = {N2END6,N2MID6,N2MID1,N1END1};
cus_mux41 inst_cus_mux41_BASE_TO_TOP16 (
    .A0(BASE_TO_TOP16_input[0]),
    .A1(BASE_TO_TOP16_input[1]),
    .A2(BASE_TO_TOP16_input[2]),
    .A3(BASE_TO_TOP16_input[3]),
    .S0(ConfigBits[32+0]),
    .S0N(ConfigBits_N[32+0]),
    .S1(ConfigBits[32+1]),
    .S1N(ConfigBits_N[32+1]),
    .X(BASE_TO_TOP16)
);

 //switch matrix multiplexer BASE_TO_TOP17 MUX-4
assign BASE_TO_TOP17_input = {N2END5,N2MID5,N2MID2,N1END2};
cus_mux41 inst_cus_mux41_BASE_TO_TOP17 (
    .A0(BASE_TO_TOP17_input[0]),
    .A1(BASE_TO_TOP17_input[1]),
    .A2(BASE_TO_TOP17_input[2]),
    .A3(BASE_TO_TOP17_input[3]),
    .S0(ConfigBits[34+0]),
    .S0N(ConfigBits_N[34+0]),
    .S1(ConfigBits[34+1]),
    .S1N(ConfigBits_N[34+1]),
    .X(BASE_TO_TOP17)
);

endmodule