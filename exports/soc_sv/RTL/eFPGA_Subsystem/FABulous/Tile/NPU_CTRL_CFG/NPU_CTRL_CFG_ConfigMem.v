module NPU_CTRL_CFG_ConfigMem
    #(
`ifdef EMULATION
        parameter [639:0] Emulate_Bitstream=640'b0,
`endif
        parameter MaxFramesPerCol=20,
        parameter FrameBitsPerRow=32,
        parameter NoConfigBits=1
    )
    (
        input  [FrameBitsPerRow - 1:0] FrameData,
        input  [MaxFramesPerCol - 1:0] FrameStrobe,
        output  [NoConfigBits - 1:0] ConfigBits,
        output  [NoConfigBits - 1:0] ConfigBits_N
    );

`ifdef EMULATION
assign ConfigBits[0] = Emulate_Bitstream[57];
`else

 //instantiate frame latches
config_latch Inst_frame1_bit25 (
    .D(FrameData[25]),
    .E(FrameStrobe[1]),
    .Q(ConfigBits[0]),
    .QN(ConfigBits_N[0])
);

`endif
endmodule