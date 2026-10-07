module EXT_PMOD
    #(
`ifdef EMULATION
        parameter [639:0] Tile_X0Y0_Emulate_Bitstream=640'b0,
        parameter [639:0] Tile_X1Y0_Emulate_Bitstream=640'b0,
`endif
        parameter MaxFramesPerCol=20,
        parameter FrameBitsPerRow=32
    )
    (
    //Tile_X0Y0_Direction.NORTH
        input  [3:0] Tile_X0Y0_N1END, //TilePort({S} INPUT N1END[3:0])
        input  [7:0] Tile_X0Y0_N2MID, //TilePort({S} INPUT N2MID[7:0])
        input  [7:0] Tile_X0Y0_N2END, //TilePort({S} INPUT N2END[7:0])
        input  [15:0] Tile_X0Y0_N4END, //TilePort({S} INPUT N4END[3:0])
        input  [15:0] Tile_X0Y0_NN4END, //TilePort({S} INPUT NN4END[3:0])
        input  [0:0] Tile_X0Y0_Ci, //TilePort({S} INPUT Ci[0:0])
        output  [3:0] Tile_X0Y0_S1BEG, //TilePort({S} OUTPUT S1BEG[3:0])
        output  [7:0] Tile_X0Y0_S2BEG, //TilePort({S} OUTPUT S2BEG[7:0])
        output  [7:0] Tile_X0Y0_S2BEGb, //TilePort({S} OUTPUT S2BEGb[7:0])
        output  [15:0] Tile_X0Y0_S4BEG, //TilePort({S} OUTPUT S4BEG[3:0])
        output  [15:0] Tile_X0Y0_SS4BEG, //TilePort({S} OUTPUT SS4BEG[3:0])
    //Tile_X1Y0_Direction.NORTH
        input  [3:0] Tile_X1Y0_N1END, //TilePort({S} INPUT N1END[3:0])
        input  [7:0] Tile_X1Y0_N2MID, //TilePort({S} INPUT N2MID[7:0])
        input  [7:0] Tile_X1Y0_N2END, //TilePort({S} INPUT N2END[7:0])
        input  [15:0] Tile_X1Y0_N4END, //TilePort({S} INPUT N4END[3:0])
        input  [15:0] Tile_X1Y0_NN4END, //TilePort({S} INPUT NN4END[3:0])
        input  [0:0] Tile_X1Y0_Ci, //TilePort({S} INPUT Ci[0:0])
        output  [3:0] Tile_X1Y0_S1BEG, //TilePort({S} OUTPUT S1BEG[3:0])
        output  [7:0] Tile_X1Y0_S2BEG, //TilePort({S} OUTPUT S2BEG[7:0])
        output  [7:0] Tile_X1Y0_S2BEGb, //TilePort({S} OUTPUT S2BEGb[7:0])
        output  [15:0] Tile_X1Y0_S4BEG, //TilePort({S} OUTPUT S4BEG[3:0])
        output  [15:0] Tile_X1Y0_SS4BEG, //TilePort({S} OUTPUT SS4BEG[3:0])
    //Tile IO ports from BELs
    //SuperTile BEL IO ports
        input  PMOD_IO_I0,
        input  PMOD_IO_I1,
        input  PMOD_IO_I2,
        input  PMOD_IO_I3,
        input  PMOD_IO_I4,
        input  PMOD_IO_I5,
        input  PMOD_IO_I6,
        input  PMOD_IO_I7,
        output  PMOD_IO_O0,
        output  PMOD_IO_O1,
        output  PMOD_IO_O2,
        output  PMOD_IO_O3,
        output  PMOD_IO_O4,
        output  PMOD_IO_O5,
        output  PMOD_IO_O6,
        output  PMOD_IO_O7,
        output  PMOD_IO_OE_O0,
        output  PMOD_IO_OE_O1,
        output  PMOD_IO_OE_O2,
        output  PMOD_IO_OE_O3,
        output  PMOD_IO_OE_O4,
        output  PMOD_IO_OE_O5,
        output  PMOD_IO_OE_O6,
        output  PMOD_IO_OE_O7,
        output  [MaxFramesPerCol-1:0] Tile_X0Y0_FrameStrobe_O, //CONFIG_PORT
        input  [FrameBitsPerRow-1:0] Tile_X0Y0_FrameData, //CONFIG_PORT
        input  [MaxFramesPerCol-1:0] Tile_X0Y0_FrameStrobe, //CONFIG_PORT
        output  [MaxFramesPerCol-1:0] Tile_X1Y0_FrameStrobe_O, //CONFIG_PORT
        input  [MaxFramesPerCol-1:0] Tile_X1Y0_FrameStrobe, //CONFIG_PORT
        output  [FrameBitsPerRow-1:0] Tile_X1Y0_FrameData_O, //CONFIG_PORT
        input  Tile_X0Y0_UserCLK,
        output  Tile_X1Y0_UserCLKo
);

 //signal declarations
 //SJUMP signals (child tile -> supertile SM)
    wire[6-1:0] EXT_PMOD_0_BASE_TO_TOP;
    wire[10-1:0] EXT_PMOD_1_BASE_TO_TOP;
 //SJUMP signals (supertile SM -> child tile)
    wire[3-1:0] EXT_PMOD_0_TOP_TO_BASE;
    wire[5-1:0] EXT_PMOD_1_TOP_TO_BASE;
 //BEL pin signals (BEL <-> supertile SM)
    wire FAB_PMOD_O0;
    wire FAB_PMOD_O1;
    wire FAB_PMOD_O2;
    wire FAB_PMOD_O3;
    wire FAB_PMOD_O4;
    wire FAB_PMOD_O5;
    wire FAB_PMOD_O6;
    wire FAB_PMOD_O7;
    wire FAB_PMOD_OE0;
    wire FAB_PMOD_OE1;
    wire FAB_PMOD_OE2;
    wire FAB_PMOD_OE3;
    wire FAB_PMOD_OE4;
    wire FAB_PMOD_OE5;
    wire FAB_PMOD_OE6;
    wire FAB_PMOD_OE7;
    wire FAB_PMOD_I0;
    wire FAB_PMOD_I1;
    wire FAB_PMOD_I2;
    wire FAB_PMOD_I3;
    wire FAB_PMOD_I4;
    wire FAB_PMOD_I5;
    wire FAB_PMOD_I6;
    wire FAB_PMOD_I7;
    wire Tile_X0Y0_UserCLKo;
    wire[FrameBitsPerRow-1:0] Tile_X0Y0_FrameData_O;
    wire[13-1:0] ST_ConfigBits;
    wire[13-1:0] ST_ConfigBits_N;

EXT_PMOD_0
`ifdef EMULATION
    #(
    .Emulate_Bitstream(Tile_X0Y0_Emulate_Bitstream)
    )
`endif
    Tile_X0Y0_EXT_PMOD_0
    (
    .N1END(Tile_X0Y0_N1END),
    .N2MID(Tile_X0Y0_N2MID),
    .N2END(Tile_X0Y0_N2END),
    .N4END(Tile_X0Y0_N4END),
    .NN4END(Tile_X0Y0_NN4END),
    .Ci(Tile_X0Y0_Ci),
    .S1BEG(Tile_X0Y0_S1BEG),
    .S2BEG(Tile_X0Y0_S2BEG),
    .S2BEGb(Tile_X0Y0_S2BEGb),
    .S4BEG(Tile_X0Y0_S4BEG),
    .SS4BEG(Tile_X0Y0_SS4BEG),
    .BASE_TO_TOP(EXT_PMOD_0_BASE_TO_TOP),
    .TOP_TO_BASE(EXT_PMOD_0_TOP_TO_BASE),
    .UserCLK(Tile_X0Y0_UserCLK),
    .UserCLKo(Tile_X0Y0_UserCLKo),
    .FrameData(Tile_X0Y0_FrameData),
    .FrameData_O(Tile_X0Y0_FrameData_O),
    .FrameStrobe(Tile_X0Y0_FrameStrobe),
    .FrameStrobe_O(Tile_X0Y0_FrameStrobe_O)
);

EXT_PMOD_1
`ifdef EMULATION
    #(
    .Emulate_Bitstream(Tile_X1Y0_Emulate_Bitstream)
    )
`endif
    Tile_X1Y0_EXT_PMOD_1
    (
    .N1END(Tile_X1Y0_N1END),
    .N2MID(Tile_X1Y0_N2MID),
    .N2END(Tile_X1Y0_N2END),
    .N4END(Tile_X1Y0_N4END),
    .NN4END(Tile_X1Y0_NN4END),
    .Ci(Tile_X1Y0_Ci),
    .S1BEG(Tile_X1Y0_S1BEG),
    .S2BEG(Tile_X1Y0_S2BEG),
    .S2BEGb(Tile_X1Y0_S2BEGb),
    .S4BEG(Tile_X1Y0_S4BEG),
    .SS4BEG(Tile_X1Y0_SS4BEG),
    .BASE_TO_TOP(EXT_PMOD_1_BASE_TO_TOP),
    .TOP_TO_BASE(EXT_PMOD_1_TOP_TO_BASE),
    .UserCLK(Tile_X0Y0_UserCLKo),
    .UserCLKo(Tile_X1Y0_UserCLKo),
    .FrameData(Tile_X0Y0_FrameData_O),
    .FrameData_O(Tile_X1Y0_FrameData_O),
    .FrameStrobe(Tile_X1Y0_FrameStrobe),
    .FrameStrobe_O(Tile_X1Y0_FrameStrobe_O)
);

EXT_PMOD_ConfigMem
`ifdef EMULATION
    #(
    .Emulate_Bitstream(Tile_X1Y0_Emulate_Bitstream)
    )
`endif
    Inst_EXT_PMOD_ConfigMem
    (
    .FrameData(Tile_X0Y0_FrameData_O),
    .FrameStrobe(Tile_X1Y0_FrameStrobe),
    .ConfigBits(ST_ConfigBits[13-1:0]),
    .ConfigBits_N(ST_ConfigBits_N[13-1:0])
);

EXT_PMOD_switch_matrix Inst_EXT_PMOD_switch_matrix (
    .EXT_PMOD_0_BASE_TO_TOP0(EXT_PMOD_0_BASE_TO_TOP[0]),
    .EXT_PMOD_0_BASE_TO_TOP1(EXT_PMOD_0_BASE_TO_TOP[1]),
    .EXT_PMOD_0_BASE_TO_TOP2(EXT_PMOD_0_BASE_TO_TOP[2]),
    .EXT_PMOD_0_BASE_TO_TOP3(EXT_PMOD_0_BASE_TO_TOP[3]),
    .EXT_PMOD_0_BASE_TO_TOP4(EXT_PMOD_0_BASE_TO_TOP[4]),
    .EXT_PMOD_0_BASE_TO_TOP5(EXT_PMOD_0_BASE_TO_TOP[5]),
    .EXT_PMOD_1_BASE_TO_TOP0(EXT_PMOD_1_BASE_TO_TOP[0]),
    .EXT_PMOD_1_BASE_TO_TOP1(EXT_PMOD_1_BASE_TO_TOP[1]),
    .EXT_PMOD_1_BASE_TO_TOP2(EXT_PMOD_1_BASE_TO_TOP[2]),
    .EXT_PMOD_1_BASE_TO_TOP3(EXT_PMOD_1_BASE_TO_TOP[3]),
    .EXT_PMOD_1_BASE_TO_TOP4(EXT_PMOD_1_BASE_TO_TOP[4]),
    .EXT_PMOD_1_BASE_TO_TOP5(EXT_PMOD_1_BASE_TO_TOP[5]),
    .EXT_PMOD_1_BASE_TO_TOP6(EXT_PMOD_1_BASE_TO_TOP[6]),
    .EXT_PMOD_1_BASE_TO_TOP7(EXT_PMOD_1_BASE_TO_TOP[7]),
    .EXT_PMOD_1_BASE_TO_TOP8(EXT_PMOD_1_BASE_TO_TOP[8]),
    .EXT_PMOD_1_BASE_TO_TOP9(EXT_PMOD_1_BASE_TO_TOP[9]),
    .FAB_PMOD_O0(FAB_PMOD_O0),
    .FAB_PMOD_O1(FAB_PMOD_O1),
    .FAB_PMOD_O2(FAB_PMOD_O2),
    .FAB_PMOD_O3(FAB_PMOD_O3),
    .FAB_PMOD_O4(FAB_PMOD_O4),
    .FAB_PMOD_O5(FAB_PMOD_O5),
    .FAB_PMOD_O6(FAB_PMOD_O6),
    .FAB_PMOD_O7(FAB_PMOD_O7),
    .FAB_PMOD_OE0(FAB_PMOD_OE0),
    .FAB_PMOD_OE1(FAB_PMOD_OE1),
    .FAB_PMOD_OE2(FAB_PMOD_OE2),
    .FAB_PMOD_OE3(FAB_PMOD_OE3),
    .FAB_PMOD_OE4(FAB_PMOD_OE4),
    .FAB_PMOD_OE5(FAB_PMOD_OE5),
    .FAB_PMOD_OE6(FAB_PMOD_OE6),
    .FAB_PMOD_OE7(FAB_PMOD_OE7),
    .FAB_PMOD_I0(FAB_PMOD_I0),
    .FAB_PMOD_I1(FAB_PMOD_I1),
    .FAB_PMOD_I2(FAB_PMOD_I2),
    .FAB_PMOD_I3(FAB_PMOD_I3),
    .FAB_PMOD_I4(FAB_PMOD_I4),
    .FAB_PMOD_I5(FAB_PMOD_I5),
    .FAB_PMOD_I6(FAB_PMOD_I6),
    .FAB_PMOD_I7(FAB_PMOD_I7),
    .EXT_PMOD_0_TOP_TO_BASE0(EXT_PMOD_0_TOP_TO_BASE[0]),
    .EXT_PMOD_0_TOP_TO_BASE1(EXT_PMOD_0_TOP_TO_BASE[1]),
    .EXT_PMOD_0_TOP_TO_BASE2(EXT_PMOD_0_TOP_TO_BASE[2]),
    .EXT_PMOD_1_TOP_TO_BASE0(EXT_PMOD_1_TOP_TO_BASE[0]),
    .EXT_PMOD_1_TOP_TO_BASE1(EXT_PMOD_1_TOP_TO_BASE[1]),
    .EXT_PMOD_1_TOP_TO_BASE2(EXT_PMOD_1_TOP_TO_BASE[2]),
    .EXT_PMOD_1_TOP_TO_BASE3(EXT_PMOD_1_TOP_TO_BASE[3]),
    .EXT_PMOD_1_TOP_TO_BASE4(EXT_PMOD_1_TOP_TO_BASE[4])
);

EXT_PMOD_BEL Inst_ST_EXT_PMOD_BEL (
    .FAB_PMOD_I({FAB_PMOD_I7, FAB_PMOD_I6, FAB_PMOD_I5, FAB_PMOD_I4, FAB_PMOD_I3, FAB_PMOD_I2, FAB_PMOD_I1, FAB_PMOD_I0}),
    .FAB_PMOD_O({FAB_PMOD_O7, FAB_PMOD_O6, FAB_PMOD_O5, FAB_PMOD_O4, FAB_PMOD_O3, FAB_PMOD_O2, FAB_PMOD_O1, FAB_PMOD_O0}),
    .FAB_PMOD_OE({FAB_PMOD_OE7, FAB_PMOD_OE6, FAB_PMOD_OE5, FAB_PMOD_OE4, FAB_PMOD_OE3, FAB_PMOD_OE2, FAB_PMOD_OE1, FAB_PMOD_OE0}),
    .PMOD_IO_I({PMOD_IO_I7, PMOD_IO_I6, PMOD_IO_I5, PMOD_IO_I4, PMOD_IO_I3, PMOD_IO_I2, PMOD_IO_I1, PMOD_IO_I0}),
    .PMOD_IO_O({PMOD_IO_O7, PMOD_IO_O6, PMOD_IO_O5, PMOD_IO_O4, PMOD_IO_O3, PMOD_IO_O2, PMOD_IO_O1, PMOD_IO_O0}),
    .PMOD_IO_OE_O({PMOD_IO_OE_O7, PMOD_IO_OE_O6, PMOD_IO_OE_O5, PMOD_IO_OE_O4, PMOD_IO_OE_O3, PMOD_IO_OE_O2, PMOD_IO_OE_O1, PMOD_IO_OE_O0}),
    .UserCLK(Tile_X0Y0_UserCLKo),
    .ConfigBits(ST_ConfigBits[13-1:0])
);

endmodule