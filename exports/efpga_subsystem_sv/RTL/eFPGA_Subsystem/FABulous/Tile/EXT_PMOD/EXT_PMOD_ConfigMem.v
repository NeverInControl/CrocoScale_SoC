module EXT_PMOD_ConfigMem
    #(
`ifdef EMULATION
        parameter [639:0] Emulate_Bitstream=640'b0,
`endif
        parameter MaxFramesPerCol=20,
        parameter FrameBitsPerRow=32,
        parameter NoConfigBits=13
    )
    (
        input  [FrameBitsPerRow - 1:0] FrameData,
        input  [MaxFramesPerCol - 1:0] FrameStrobe,
        output  [NoConfigBits - 1:0] ConfigBits,
        output  [NoConfigBits - 1:0] ConfigBits_N
    );

`ifdef EMULATION
assign ConfigBits[0] = Emulate_Bitstream[123];
assign ConfigBits[1] = Emulate_Bitstream[122];
assign ConfigBits[2] = Emulate_Bitstream[121];
assign ConfigBits[3] = Emulate_Bitstream[120];
assign ConfigBits[4] = Emulate_Bitstream[119];
assign ConfigBits[5] = Emulate_Bitstream[118];
assign ConfigBits[6] = Emulate_Bitstream[117];
assign ConfigBits[7] = Emulate_Bitstream[116];
assign ConfigBits[8] = Emulate_Bitstream[115];
assign ConfigBits[9] = Emulate_Bitstream[114];
assign ConfigBits[10] = Emulate_Bitstream[113];
assign ConfigBits[11] = Emulate_Bitstream[112];
assign ConfigBits[12] = Emulate_Bitstream[111];
`else

 //instantiate frame latches
config_latch Inst_frame3_bit27 (
    .D(FrameData[27]),
    .E(FrameStrobe[3]),
    .Q(ConfigBits[0]),
    .QN(ConfigBits_N[0])
);

config_latch Inst_frame3_bit26 (
    .D(FrameData[26]),
    .E(FrameStrobe[3]),
    .Q(ConfigBits[1]),
    .QN(ConfigBits_N[1])
);

config_latch Inst_frame3_bit25 (
    .D(FrameData[25]),
    .E(FrameStrobe[3]),
    .Q(ConfigBits[2]),
    .QN(ConfigBits_N[2])
);

config_latch Inst_frame3_bit24 (
    .D(FrameData[24]),
    .E(FrameStrobe[3]),
    .Q(ConfigBits[3]),
    .QN(ConfigBits_N[3])
);

config_latch Inst_frame3_bit23 (
    .D(FrameData[23]),
    .E(FrameStrobe[3]),
    .Q(ConfigBits[4]),
    .QN(ConfigBits_N[4])
);

config_latch Inst_frame3_bit22 (
    .D(FrameData[22]),
    .E(FrameStrobe[3]),
    .Q(ConfigBits[5]),
    .QN(ConfigBits_N[5])
);

config_latch Inst_frame3_bit21 (
    .D(FrameData[21]),
    .E(FrameStrobe[3]),
    .Q(ConfigBits[6]),
    .QN(ConfigBits_N[6])
);

config_latch Inst_frame3_bit20 (
    .D(FrameData[20]),
    .E(FrameStrobe[3]),
    .Q(ConfigBits[7]),
    .QN(ConfigBits_N[7])
);

config_latch Inst_frame3_bit19 (
    .D(FrameData[19]),
    .E(FrameStrobe[3]),
    .Q(ConfigBits[8]),
    .QN(ConfigBits_N[8])
);

config_latch Inst_frame3_bit18 (
    .D(FrameData[18]),
    .E(FrameStrobe[3]),
    .Q(ConfigBits[9]),
    .QN(ConfigBits_N[9])
);

config_latch Inst_frame3_bit17 (
    .D(FrameData[17]),
    .E(FrameStrobe[3]),
    .Q(ConfigBits[10]),
    .QN(ConfigBits_N[10])
);

config_latch Inst_frame3_bit16 (
    .D(FrameData[16]),
    .E(FrameStrobe[3]),
    .Q(ConfigBits[11]),
    .QN(ConfigBits_N[11])
);

config_latch Inst_frame3_bit15 (
    .D(FrameData[15]),
    .E(FrameStrobe[3]),
    .Q(ConfigBits[12]),
    .QN(ConfigBits_N[12])
);

`endif
endmodule