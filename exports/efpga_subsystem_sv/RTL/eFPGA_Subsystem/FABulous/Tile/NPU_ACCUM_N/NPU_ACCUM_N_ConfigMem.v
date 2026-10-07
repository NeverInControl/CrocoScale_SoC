module NPU_ACCUM_N_ConfigMem
    #(
`ifdef EMULATION
        parameter [639:0] Emulate_Bitstream=640'b0,
`endif
        parameter MaxFramesPerCol=20,
        parameter FrameBitsPerRow=32,
        parameter NoConfigBits=8
    )
    (
        input  [FrameBitsPerRow - 1:0] FrameData,
        input  [MaxFramesPerCol - 1:0] FrameStrobe,
        output  [NoConfigBits - 1:0] ConfigBits,
        output  [NoConfigBits - 1:0] ConfigBits_N
    );

`ifdef EMULATION
assign ConfigBits[0] = Emulate_Bitstream[25];
assign ConfigBits[1] = Emulate_Bitstream[24];
assign ConfigBits[2] = Emulate_Bitstream[23];
assign ConfigBits[3] = Emulate_Bitstream[22];
assign ConfigBits[4] = Emulate_Bitstream[21];
assign ConfigBits[5] = Emulate_Bitstream[20];
assign ConfigBits[6] = Emulate_Bitstream[19];
assign ConfigBits[7] = Emulate_Bitstream[18];
`else

 //instantiate frame latches
config_latch Inst_frame0_bit25 (
    .D(FrameData[25]),
    .E(FrameStrobe[0]),
    .Q(ConfigBits[0]),
    .QN(ConfigBits_N[0])
);

config_latch Inst_frame0_bit24 (
    .D(FrameData[24]),
    .E(FrameStrobe[0]),
    .Q(ConfigBits[1]),
    .QN(ConfigBits_N[1])
);

config_latch Inst_frame0_bit23 (
    .D(FrameData[23]),
    .E(FrameStrobe[0]),
    .Q(ConfigBits[2]),
    .QN(ConfigBits_N[2])
);

config_latch Inst_frame0_bit22 (
    .D(FrameData[22]),
    .E(FrameStrobe[0]),
    .Q(ConfigBits[3]),
    .QN(ConfigBits_N[3])
);

config_latch Inst_frame0_bit21 (
    .D(FrameData[21]),
    .E(FrameStrobe[0]),
    .Q(ConfigBits[4]),
    .QN(ConfigBits_N[4])
);

config_latch Inst_frame0_bit20 (
    .D(FrameData[20]),
    .E(FrameStrobe[0]),
    .Q(ConfigBits[5]),
    .QN(ConfigBits_N[5])
);

config_latch Inst_frame0_bit19 (
    .D(FrameData[19]),
    .E(FrameStrobe[0]),
    .Q(ConfigBits[6]),
    .QN(ConfigBits_N[6])
);

config_latch Inst_frame0_bit18 (
    .D(FrameData[18]),
    .E(FrameStrobe[0]),
    .Q(ConfigBits[7]),
    .QN(ConfigBits_N[7])
);

`endif
endmodule