 // NumberOfConfigBits: 0
module NPU_CTRL_CFG_switch_matrix
    (
 //SJUMP inputs from child tiles
        input  NPU_CTRL_CFG_0_BASE_TO_TOP0,
        input  NPU_CTRL_CFG_0_BASE_TO_TOP1,
        input  NPU_CTRL_CFG_0_BASE_TO_TOP2,
        input  NPU_CTRL_CFG_0_BASE_TO_TOP3,
        input  NPU_CTRL_CFG_0_BASE_TO_TOP4,
        input  NPU_CTRL_CFG_0_BASE_TO_TOP5,
        input  NPU_CTRL_CFG_0_BASE_TO_TOP6,
        input  NPU_CTRL_CFG_0_BASE_TO_TOP7,
        input  NPU_CTRL_CFG_0_BASE_TO_TOP8,
        input  NPU_CTRL_CFG_0_BASE_TO_TOP9,
        input  NPU_CTRL_CFG_0_BASE_TO_TOP10,
        input  NPU_CTRL_CFG_0_BASE_TO_TOP11,
        input  NPU_CTRL_CFG_0_BASE_TO_TOP12,
        input  NPU_CTRL_CFG_0_BASE_TO_TOP13,
        input  NPU_CTRL_CFG_0_BASE_TO_TOP14,
        input  NPU_CTRL_CFG_0_BASE_TO_TOP15,
        input  NPU_CTRL_CFG_0_BASE_TO_TOP16,
        input  NPU_CTRL_CFG_0_BASE_TO_TOP17,
        input  NPU_CTRL_CFG_1_BASE_TO_TOP0,
        input  NPU_CTRL_CFG_1_BASE_TO_TOP1,
        input  NPU_CTRL_CFG_1_BASE_TO_TOP2,
        input  NPU_CTRL_CFG_1_BASE_TO_TOP3,
        input  NPU_CTRL_CFG_1_BASE_TO_TOP4,
        input  NPU_CTRL_CFG_1_BASE_TO_TOP5,
        input  NPU_CTRL_CFG_1_BASE_TO_TOP6,
        input  NPU_CTRL_CFG_1_BASE_TO_TOP7,
        input  NPU_CTRL_CFG_1_BASE_TO_TOP8,
        input  NPU_CTRL_CFG_1_BASE_TO_TOP9,
        input  NPU_CTRL_CFG_1_BASE_TO_TOP10,
        input  NPU_CTRL_CFG_1_BASE_TO_TOP11,
        input  NPU_CTRL_CFG_1_BASE_TO_TOP12,
        input  NPU_CTRL_CFG_1_BASE_TO_TOP13,
        input  NPU_CTRL_CFG_1_BASE_TO_TOP14,
        input  NPU_CTRL_CFG_1_BASE_TO_TOP15,
        input  NPU_CTRL_CFG_1_BASE_TO_TOP16,
        input  NPU_CTRL_CFG_1_BASE_TO_TOP17,
        input  NPU_CTRL_CFG_1_BASE_TO_TOP18,
 //BEL input ports (SM outputs)
        output  FAB_QUANT_SHIFT_IN0,
        output  FAB_QUANT_SHIFT_IN1,
        output  FAB_QUANT_SHIFT_IN2,
        output  FAB_QUANT_SHIFT_IN3,
        output  FAB_QUANT_SHIFT_IN4,
        output  FAB_QUANT_SHIFT_IN5,
        output  FAB_QUANT_SHIFT_IN6,
        output  FAB_QUANT_SHIFT_IN7,
        output  FAB_QUANT_SHIFT_IN8,
        output  FAB_QUANT_SHIFT_IN9,
        output  FAB_QUANT_SHIFT_IN10,
        output  FAB_QUANT_SHIFT_IN11,
        output  FAB_QUANT_SHIFT_IN12,
        output  FAB_QUANT_SHIFT_IN13,
        output  FAB_QUANT_SHIFT_IN14,
        output  FAB_QUANT_SHIFT_IN15,
        output  FAB_QUANT_SHIFT_IN16,
        output  FAB_QUANT_SHIFT_IN17,
        output  FAB_QUANT_SHIFT_IN18,
        output  FAB_QUANT_SHIFT_IN19,
        output  FAB_QUANT_SHIFT_IN20,
        output  FAB_QUANT_SHIFT_IN21,
        output  FAB_QUANT_SHIFT_IN22,
        output  FAB_QUANT_SHIFT_IN23,
        output  FAB_QUANT_SHIFT_IN24,
        output  FAB_QUANT_SHIFT_IN25,
        output  FAB_QUANT_SHIFT_IN26,
        output  FAB_QUANT_SHIFT_IN27,
        output  FAB_QUANT_SHIFT_IN28,
        output  FAB_QUANT_SHIFT_IN29,
        output  FAB_QUANT_SHIFT_EN,
        output  FAB_ARRAY_EN,
        output  FAB_PSUM_SYSTOLIC_EN,
        output  FAB_PSUM_LUT_EN,
        output  FAB_SWAP_WEIGHTS,
        output  FAB_PSUM_SKEW_EN,
        output  FAB_COMPUTE_BANK_SWAP
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
 //switch matrix multiplexer FAB_QUANT_SHIFT_IN0 MUX-1
assign FAB_QUANT_SHIFT_IN0 = NPU_CTRL_CFG_0_BASE_TO_TOP0;

 //switch matrix multiplexer FAB_QUANT_SHIFT_IN1 MUX-1
assign FAB_QUANT_SHIFT_IN1 = NPU_CTRL_CFG_0_BASE_TO_TOP1;

 //switch matrix multiplexer FAB_QUANT_SHIFT_IN2 MUX-1
assign FAB_QUANT_SHIFT_IN2 = NPU_CTRL_CFG_0_BASE_TO_TOP2;

 //switch matrix multiplexer FAB_QUANT_SHIFT_IN3 MUX-1
assign FAB_QUANT_SHIFT_IN3 = NPU_CTRL_CFG_0_BASE_TO_TOP3;

 //switch matrix multiplexer FAB_QUANT_SHIFT_IN4 MUX-1
assign FAB_QUANT_SHIFT_IN4 = NPU_CTRL_CFG_0_BASE_TO_TOP4;

 //switch matrix multiplexer FAB_QUANT_SHIFT_IN5 MUX-1
assign FAB_QUANT_SHIFT_IN5 = NPU_CTRL_CFG_0_BASE_TO_TOP5;

 //switch matrix multiplexer FAB_QUANT_SHIFT_IN6 MUX-1
assign FAB_QUANT_SHIFT_IN6 = NPU_CTRL_CFG_0_BASE_TO_TOP6;

 //switch matrix multiplexer FAB_QUANT_SHIFT_IN7 MUX-1
assign FAB_QUANT_SHIFT_IN7 = NPU_CTRL_CFG_0_BASE_TO_TOP7;

 //switch matrix multiplexer FAB_QUANT_SHIFT_IN8 MUX-1
assign FAB_QUANT_SHIFT_IN8 = NPU_CTRL_CFG_0_BASE_TO_TOP8;

 //switch matrix multiplexer FAB_QUANT_SHIFT_IN9 MUX-1
assign FAB_QUANT_SHIFT_IN9 = NPU_CTRL_CFG_0_BASE_TO_TOP9;

 //switch matrix multiplexer FAB_QUANT_SHIFT_IN10 MUX-1
assign FAB_QUANT_SHIFT_IN10 = NPU_CTRL_CFG_0_BASE_TO_TOP10;

 //switch matrix multiplexer FAB_QUANT_SHIFT_IN11 MUX-1
assign FAB_QUANT_SHIFT_IN11 = NPU_CTRL_CFG_0_BASE_TO_TOP11;

 //switch matrix multiplexer FAB_QUANT_SHIFT_IN12 MUX-1
assign FAB_QUANT_SHIFT_IN12 = NPU_CTRL_CFG_0_BASE_TO_TOP12;

 //switch matrix multiplexer FAB_QUANT_SHIFT_IN13 MUX-1
assign FAB_QUANT_SHIFT_IN13 = NPU_CTRL_CFG_0_BASE_TO_TOP13;

 //switch matrix multiplexer FAB_QUANT_SHIFT_IN14 MUX-1
assign FAB_QUANT_SHIFT_IN14 = NPU_CTRL_CFG_0_BASE_TO_TOP14;

 //switch matrix multiplexer FAB_QUANT_SHIFT_EN MUX-1
assign FAB_QUANT_SHIFT_EN = NPU_CTRL_CFG_0_BASE_TO_TOP15;

 //switch matrix multiplexer FAB_ARRAY_EN MUX-1
assign FAB_ARRAY_EN = NPU_CTRL_CFG_0_BASE_TO_TOP16;

 //switch matrix multiplexer FAB_PSUM_SYSTOLIC_EN MUX-1
assign FAB_PSUM_SYSTOLIC_EN = NPU_CTRL_CFG_0_BASE_TO_TOP17;

 //switch matrix multiplexer FAB_QUANT_SHIFT_IN15 MUX-1
assign FAB_QUANT_SHIFT_IN15 = NPU_CTRL_CFG_1_BASE_TO_TOP0;

 //switch matrix multiplexer FAB_QUANT_SHIFT_IN16 MUX-1
assign FAB_QUANT_SHIFT_IN16 = NPU_CTRL_CFG_1_BASE_TO_TOP1;

 //switch matrix multiplexer FAB_QUANT_SHIFT_IN17 MUX-1
assign FAB_QUANT_SHIFT_IN17 = NPU_CTRL_CFG_1_BASE_TO_TOP2;

 //switch matrix multiplexer FAB_QUANT_SHIFT_IN18 MUX-1
assign FAB_QUANT_SHIFT_IN18 = NPU_CTRL_CFG_1_BASE_TO_TOP3;

 //switch matrix multiplexer FAB_QUANT_SHIFT_IN19 MUX-1
assign FAB_QUANT_SHIFT_IN19 = NPU_CTRL_CFG_1_BASE_TO_TOP4;

 //switch matrix multiplexer FAB_QUANT_SHIFT_IN20 MUX-1
assign FAB_QUANT_SHIFT_IN20 = NPU_CTRL_CFG_1_BASE_TO_TOP5;

 //switch matrix multiplexer FAB_QUANT_SHIFT_IN21 MUX-1
assign FAB_QUANT_SHIFT_IN21 = NPU_CTRL_CFG_1_BASE_TO_TOP6;

 //switch matrix multiplexer FAB_QUANT_SHIFT_IN22 MUX-1
assign FAB_QUANT_SHIFT_IN22 = NPU_CTRL_CFG_1_BASE_TO_TOP7;

 //switch matrix multiplexer FAB_QUANT_SHIFT_IN23 MUX-1
assign FAB_QUANT_SHIFT_IN23 = NPU_CTRL_CFG_1_BASE_TO_TOP8;

 //switch matrix multiplexer FAB_QUANT_SHIFT_IN24 MUX-1
assign FAB_QUANT_SHIFT_IN24 = NPU_CTRL_CFG_1_BASE_TO_TOP9;

 //switch matrix multiplexer FAB_QUANT_SHIFT_IN25 MUX-1
assign FAB_QUANT_SHIFT_IN25 = NPU_CTRL_CFG_1_BASE_TO_TOP10;

 //switch matrix multiplexer FAB_QUANT_SHIFT_IN26 MUX-1
assign FAB_QUANT_SHIFT_IN26 = NPU_CTRL_CFG_1_BASE_TO_TOP11;

 //switch matrix multiplexer FAB_QUANT_SHIFT_IN27 MUX-1
assign FAB_QUANT_SHIFT_IN27 = NPU_CTRL_CFG_1_BASE_TO_TOP12;

 //switch matrix multiplexer FAB_QUANT_SHIFT_IN28 MUX-1
assign FAB_QUANT_SHIFT_IN28 = NPU_CTRL_CFG_1_BASE_TO_TOP13;

 //switch matrix multiplexer FAB_QUANT_SHIFT_IN29 MUX-1
assign FAB_QUANT_SHIFT_IN29 = NPU_CTRL_CFG_1_BASE_TO_TOP14;

 //switch matrix multiplexer FAB_PSUM_LUT_EN MUX-1
assign FAB_PSUM_LUT_EN = NPU_CTRL_CFG_1_BASE_TO_TOP15;

 //switch matrix multiplexer FAB_SWAP_WEIGHTS MUX-1
assign FAB_SWAP_WEIGHTS = NPU_CTRL_CFG_1_BASE_TO_TOP16;

 //switch matrix multiplexer FAB_PSUM_SKEW_EN MUX-1
assign FAB_PSUM_SKEW_EN = NPU_CTRL_CFG_1_BASE_TO_TOP17;

 //switch matrix multiplexer FAB_COMPUTE_BANK_SWAP MUX-1
assign FAB_COMPUTE_BANK_SWAP = NPU_CTRL_CFG_1_BASE_TO_TOP18;

endmodule