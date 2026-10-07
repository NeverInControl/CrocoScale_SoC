module AXI_M_IO_W_ConfigMem
    #(
`ifdef EMULATION
        parameter [639:0] Emulate_Bitstream=640'b0,
`endif
        parameter MaxFramesPerCol=20,
        parameter FrameBitsPerRow=32,
        parameter NoConfigBits=12
    )
    (
        input  [FrameBitsPerRow - 1:0] FrameData,
        input  [MaxFramesPerCol - 1:0] FrameStrobe,
        output  [NoConfigBits - 1:0] ConfigBits,
        output  [NoConfigBits - 1:0] ConfigBits_N
    );

`ifdef EMULATION
assign ConfigBits[0] = Emulate_Bitstream[287];
assign ConfigBits[1] = Emulate_Bitstream[286];
assign ConfigBits[2] = Emulate_Bitstream[285];
assign ConfigBits[3] = Emulate_Bitstream[284];
assign ConfigBits[4] = Emulate_Bitstream[283];
assign ConfigBits[5] = Emulate_Bitstream[282];
assign ConfigBits[6] = Emulate_Bitstream[281];
assign ConfigBits[7] = Emulate_Bitstream[280];
assign ConfigBits[8] = Emulate_Bitstream[279];
assign ConfigBits[9] = Emulate_Bitstream[278];
assign ConfigBits[10] = Emulate_Bitstream[277];
assign ConfigBits[11] = Emulate_Bitstream[276];
`else

 //instantiate frame latches
config_latch Inst_frame8_bit31 (
    .D(FrameData[31]),
    .E(FrameStrobe[8]),
    .Q(ConfigBits[0]),
    .QN(ConfigBits_N[0])
);

config_latch Inst_frame8_bit30 (
    .D(FrameData[30]),
    .E(FrameStrobe[8]),
    .Q(ConfigBits[1]),
    .QN(ConfigBits_N[1])
);

config_latch Inst_frame8_bit29 (
    .D(FrameData[29]),
    .E(FrameStrobe[8]),
    .Q(ConfigBits[2]),
    .QN(ConfigBits_N[2])
);

config_latch Inst_frame8_bit28 (
    .D(FrameData[28]),
    .E(FrameStrobe[8]),
    .Q(ConfigBits[3]),
    .QN(ConfigBits_N[3])
);

config_latch Inst_frame8_bit27 (
    .D(FrameData[27]),
    .E(FrameStrobe[8]),
    .Q(ConfigBits[4]),
    .QN(ConfigBits_N[4])
);

config_latch Inst_frame8_bit26 (
    .D(FrameData[26]),
    .E(FrameStrobe[8]),
    .Q(ConfigBits[5]),
    .QN(ConfigBits_N[5])
);

config_latch Inst_frame8_bit25 (
    .D(FrameData[25]),
    .E(FrameStrobe[8]),
    .Q(ConfigBits[6]),
    .QN(ConfigBits_N[6])
);

config_latch Inst_frame8_bit24 (
    .D(FrameData[24]),
    .E(FrameStrobe[8]),
    .Q(ConfigBits[7]),
    .QN(ConfigBits_N[7])
);

config_latch Inst_frame8_bit23 (
    .D(FrameData[23]),
    .E(FrameStrobe[8]),
    .Q(ConfigBits[8]),
    .QN(ConfigBits_N[8])
);

config_latch Inst_frame8_bit22 (
    .D(FrameData[22]),
    .E(FrameStrobe[8]),
    .Q(ConfigBits[9]),
    .QN(ConfigBits_N[9])
);

config_latch Inst_frame8_bit21 (
    .D(FrameData[21]),
    .E(FrameStrobe[8]),
    .Q(ConfigBits[10]),
    .QN(ConfigBits_N[10])
);

config_latch Inst_frame8_bit20 (
    .D(FrameData[20]),
    .E(FrameStrobe[8]),
    .Q(ConfigBits[11]),
    .QN(ConfigBits_N[11])
);

`endif
endmodule