module NPU_ACCUM_S
    #(
`ifdef EMULATION
        parameter [639:0] Tile_X0Y0_Emulate_Bitstream=640'b0,
        parameter [639:0] Tile_X1Y0_Emulate_Bitstream=640'b0,
        parameter [639:0] Tile_X2Y0_Emulate_Bitstream=640'b0,
        parameter [639:0] Tile_X3Y0_Emulate_Bitstream=640'b0,
        parameter [639:0] Tile_X4Y0_Emulate_Bitstream=640'b0,
`endif
        parameter MaxFramesPerCol=20,
        parameter FrameBitsPerRow=32
    )
    (
    //Tile_X0Y0_Direction.NORTH
        output  [3:0] Tile_X0Y0_N1BEG, //TilePort({N} OUTPUT N1BEG[3:0])
        output  [7:0] Tile_X0Y0_N2BEG, //TilePort({N} OUTPUT N2BEG[7:0])
        output  [7:0] Tile_X0Y0_N2BEGb, //TilePort({N} OUTPUT N2BEGb[7:0])
        output  [15:0] Tile_X0Y0_N4BEG, //TilePort({N} OUTPUT N4BEG[3:0])
        output  [15:0] Tile_X0Y0_NN4BEG, //TilePort({N} OUTPUT NN4BEG[3:0])
        output  [0:0] Tile_X0Y0_Co, //TilePort({N} OUTPUT Co[0:0])
        input  [3:0] Tile_X0Y0_S1END, //TilePort({N} INPUT S1END[3:0])
        input  [7:0] Tile_X0Y0_S2MID, //TilePort({N} INPUT S2MID[7:0])
        input  [7:0] Tile_X0Y0_S2END, //TilePort({N} INPUT S2END[7:0])
        input  [15:0] Tile_X0Y0_S4END, //TilePort({N} INPUT S4END[3:0])
        input  [15:0] Tile_X0Y0_SS4END, //TilePort({N} INPUT SS4END[3:0])
    //Tile_X1Y0_Direction.NORTH
        output  [3:0] Tile_X1Y0_N1BEG, //TilePort({N} OUTPUT N1BEG[3:0])
        output  [7:0] Tile_X1Y0_N2BEG, //TilePort({N} OUTPUT N2BEG[7:0])
        output  [7:0] Tile_X1Y0_N2BEGb, //TilePort({N} OUTPUT N2BEGb[7:0])
        output  [15:0] Tile_X1Y0_N4BEG, //TilePort({N} OUTPUT N4BEG[3:0])
        output  [15:0] Tile_X1Y0_NN4BEG, //TilePort({N} OUTPUT NN4BEG[3:0])
        output  [0:0] Tile_X1Y0_Co, //TilePort({N} OUTPUT Co[0:0])
        input  [3:0] Tile_X1Y0_S1END, //TilePort({N} INPUT S1END[3:0])
        input  [7:0] Tile_X1Y0_S2MID, //TilePort({N} INPUT S2MID[7:0])
        input  [7:0] Tile_X1Y0_S2END, //TilePort({N} INPUT S2END[7:0])
        input  [15:0] Tile_X1Y0_S4END, //TilePort({N} INPUT S4END[3:0])
        input  [15:0] Tile_X1Y0_SS4END, //TilePort({N} INPUT SS4END[3:0])
    //Tile_X2Y0_Direction.NORTH
        output  [3:0] Tile_X2Y0_N1BEG, //TilePort({N} OUTPUT N1BEG[3:0])
        output  [7:0] Tile_X2Y0_N2BEG, //TilePort({N} OUTPUT N2BEG[7:0])
        output  [7:0] Tile_X2Y0_N2BEGb, //TilePort({N} OUTPUT N2BEGb[7:0])
        output  [15:0] Tile_X2Y0_N4BEG, //TilePort({N} OUTPUT N4BEG[3:0])
        output  [15:0] Tile_X2Y0_NN4BEG, //TilePort({N} OUTPUT NN4BEG[3:0])
        output  [0:0] Tile_X2Y0_Co, //TilePort({N} OUTPUT Co[0:0])
        input  [3:0] Tile_X2Y0_S1END, //TilePort({N} INPUT S1END[3:0])
        input  [7:0] Tile_X2Y0_S2MID, //TilePort({N} INPUT S2MID[7:0])
        input  [7:0] Tile_X2Y0_S2END, //TilePort({N} INPUT S2END[7:0])
        input  [15:0] Tile_X2Y0_S4END, //TilePort({N} INPUT S4END[3:0])
        input  [15:0] Tile_X2Y0_SS4END, //TilePort({N} INPUT SS4END[3:0])
    //Tile_X3Y0_Direction.NORTH
        output  [3:0] Tile_X3Y0_N1BEG, //TilePort({N} OUTPUT N1BEG[3:0])
        output  [7:0] Tile_X3Y0_N2BEG, //TilePort({N} OUTPUT N2BEG[7:0])
        output  [7:0] Tile_X3Y0_N2BEGb, //TilePort({N} OUTPUT N2BEGb[7:0])
        output  [15:0] Tile_X3Y0_N4BEG, //TilePort({N} OUTPUT N4BEG[3:0])
        output  [15:0] Tile_X3Y0_NN4BEG, //TilePort({N} OUTPUT NN4BEG[3:0])
        output  [0:0] Tile_X3Y0_Co, //TilePort({N} OUTPUT Co[0:0])
        input  [3:0] Tile_X3Y0_S1END, //TilePort({N} INPUT S1END[3:0])
        input  [7:0] Tile_X3Y0_S2MID, //TilePort({N} INPUT S2MID[7:0])
        input  [7:0] Tile_X3Y0_S2END, //TilePort({N} INPUT S2END[7:0])
        input  [15:0] Tile_X3Y0_S4END, //TilePort({N} INPUT S4END[3:0])
        input  [15:0] Tile_X3Y0_SS4END, //TilePort({N} INPUT SS4END[3:0])
    //Tile_X4Y0_Direction.NORTH
        output  [3:0] Tile_X4Y0_N1BEG, //TilePort({N} OUTPUT N1BEG[3:0])
        output  [7:0] Tile_X4Y0_N2BEG, //TilePort({N} OUTPUT N2BEG[7:0])
        output  [7:0] Tile_X4Y0_N2BEGb, //TilePort({N} OUTPUT N2BEGb[7:0])
        output  [15:0] Tile_X4Y0_N4BEG, //TilePort({N} OUTPUT N4BEG[3:0])
        output  [15:0] Tile_X4Y0_NN4BEG, //TilePort({N} OUTPUT NN4BEG[3:0])
        output  [0:0] Tile_X4Y0_Co, //TilePort({N} OUTPUT Co[0:0])
        input  [3:0] Tile_X4Y0_S1END, //TilePort({N} INPUT S1END[3:0])
        input  [7:0] Tile_X4Y0_S2MID, //TilePort({N} INPUT S2MID[7:0])
        input  [7:0] Tile_X4Y0_S2END, //TilePort({N} INPUT S2END[7:0])
        input  [15:0] Tile_X4Y0_S4END, //TilePort({N} INPUT S4END[3:0])
        input  [15:0] Tile_X4Y0_SS4END, //TilePort({N} INPUT SS4END[3:0])
    //Tile IO ports from BELs
    //SuperTile BEL IO ports
        input  NPU_RDATA0,
        input  NPU_RDATA1,
        input  NPU_RDATA2,
        input  NPU_RDATA3,
        input  NPU_RDATA4,
        input  NPU_RDATA5,
        input  NPU_RDATA6,
        input  NPU_RDATA7,
        input  NPU_RDATA8,
        input  NPU_RDATA9,
        input  NPU_RDATA10,
        input  NPU_RDATA11,
        input  NPU_RDATA12,
        input  NPU_RDATA13,
        input  NPU_RDATA14,
        input  NPU_RDATA15,
        input  NPU_RDATA16,
        input  NPU_RDATA17,
        input  NPU_RDATA18,
        input  NPU_RDATA19,
        input  NPU_RDATA20,
        input  NPU_RDATA21,
        input  NPU_RDATA22,
        input  NPU_RDATA23,
        input  NPU_RDATA24,
        input  NPU_RDATA25,
        input  NPU_RDATA26,
        input  NPU_RDATA27,
        input  NPU_RDATA28,
        input  NPU_RDATA29,
        input  NPU_RDATA30,
        input  NPU_RDATA31,
        output  NPU_ADDR0,
        output  NPU_ADDR1,
        output  NPU_ADDR2,
        output  NPU_ADDR3,
        output  NPU_ADDR4,
        output  NPU_ADDR5,
        output  NPU_ADDR6,
        output  NPU_ADDR7,
        output  NPU_WE0,
        output  NPU_WE1,
        output  NPU_WE2,
        output  NPU_WE3,
        output  NPU_WE4,
        output  NPU_WE5,
        output  NPU_WE6,
        output  NPU_WE7,
        output  NPU_WDATA0,
        output  NPU_WDATA1,
        output  NPU_WDATA2,
        output  NPU_WDATA3,
        output  NPU_WDATA4,
        output  NPU_WDATA5,
        output  NPU_WDATA6,
        output  NPU_WDATA7,
        output  NPU_WDATA8,
        output  NPU_WDATA9,
        output  NPU_WDATA10,
        output  NPU_WDATA11,
        output  NPU_WDATA12,
        output  NPU_WDATA13,
        output  NPU_WDATA14,
        output  NPU_WDATA15,
        output  NPU_WDATA16,
        output  NPU_WDATA17,
        output  NPU_WDATA18,
        output  NPU_WDATA19,
        output  NPU_WDATA20,
        output  NPU_WDATA21,
        output  NPU_WDATA22,
        output  NPU_WDATA23,
        output  NPU_WDATA24,
        output  NPU_WDATA25,
        output  NPU_WDATA26,
        output  NPU_WDATA27,
        output  NPU_WDATA28,
        output  NPU_WDATA29,
        output  NPU_WDATA30,
        output  NPU_WDATA31,
        output  NPU_READ_BANK_SEL0,
        output  NPU_READ_BANK_SEL1,
        output  NPU_READ_BANK_SEL2,
        output  [MaxFramesPerCol-1:0] Tile_X0Y0_FrameStrobe_O, //CONFIG_PORT
        input  [FrameBitsPerRow-1:0] Tile_X0Y0_FrameData, //CONFIG_PORT
        input  [MaxFramesPerCol-1:0] Tile_X0Y0_FrameStrobe, //CONFIG_PORT
        output  [MaxFramesPerCol-1:0] Tile_X1Y0_FrameStrobe_O, //CONFIG_PORT
        input  [MaxFramesPerCol-1:0] Tile_X1Y0_FrameStrobe, //CONFIG_PORT
        output  [MaxFramesPerCol-1:0] Tile_X2Y0_FrameStrobe_O, //CONFIG_PORT
        input  [MaxFramesPerCol-1:0] Tile_X2Y0_FrameStrobe, //CONFIG_PORT
        output  [MaxFramesPerCol-1:0] Tile_X3Y0_FrameStrobe_O, //CONFIG_PORT
        input  [MaxFramesPerCol-1:0] Tile_X3Y0_FrameStrobe, //CONFIG_PORT
        output  [MaxFramesPerCol-1:0] Tile_X4Y0_FrameStrobe_O, //CONFIG_PORT
        input  [MaxFramesPerCol-1:0] Tile_X4Y0_FrameStrobe, //CONFIG_PORT
        output  [FrameBitsPerRow-1:0] Tile_X4Y0_FrameData_O, //CONFIG_PORT
        input  Tile_X0Y0_UserCLK,
        output  Tile_X4Y0_UserCLKo
);

 //signal declarations
 //SJUMP signals (child tile -> supertile SM)
    wire[16-1:0] NPU_ACCUM_S_0_BASE_TO_TOP;
    wire[16-1:0] NPU_ACCUM_S_1_BASE_TO_TOP;
    wire[8-1:0] NPU_ACCUM_S_2_BASE_TO_TOP;
    wire[8-1:0] NPU_ACCUM_S_3_BASE_TO_TOP;
    wire[3-1:0] NPU_ACCUM_S_4_BASE_TO_TOP;
 //SJUMP signals (supertile SM -> child tile)
    wire[8-1:0] NPU_ACCUM_S_0_TOP_TO_BASE;
    wire[8-1:0] NPU_ACCUM_S_1_TOP_TO_BASE;
    wire[8-1:0] NPU_ACCUM_S_2_TOP_TO_BASE;
    wire[8-1:0] NPU_ACCUM_S_3_TOP_TO_BASE;
 //BEL pin signals (BEL <-> supertile SM)
    wire FAB_ADDR0;
    wire FAB_ADDR1;
    wire FAB_ADDR2;
    wire FAB_ADDR3;
    wire FAB_ADDR4;
    wire FAB_ADDR5;
    wire FAB_ADDR6;
    wire FAB_ADDR7;
    wire FAB_WE0;
    wire FAB_WE1;
    wire FAB_WE2;
    wire FAB_WE3;
    wire FAB_WE4;
    wire FAB_WE5;
    wire FAB_WE6;
    wire FAB_WE7;
    wire FAB_WDATA0;
    wire FAB_WDATA1;
    wire FAB_WDATA2;
    wire FAB_WDATA3;
    wire FAB_WDATA4;
    wire FAB_WDATA5;
    wire FAB_WDATA6;
    wire FAB_WDATA7;
    wire FAB_WDATA8;
    wire FAB_WDATA9;
    wire FAB_WDATA10;
    wire FAB_WDATA11;
    wire FAB_WDATA12;
    wire FAB_WDATA13;
    wire FAB_WDATA14;
    wire FAB_WDATA15;
    wire FAB_WDATA16;
    wire FAB_WDATA17;
    wire FAB_WDATA18;
    wire FAB_WDATA19;
    wire FAB_WDATA20;
    wire FAB_WDATA21;
    wire FAB_WDATA22;
    wire FAB_WDATA23;
    wire FAB_WDATA24;
    wire FAB_WDATA25;
    wire FAB_WDATA26;
    wire FAB_WDATA27;
    wire FAB_WDATA28;
    wire FAB_WDATA29;
    wire FAB_WDATA30;
    wire FAB_WDATA31;
    wire FAB_READ_BANK_SEL0;
    wire FAB_READ_BANK_SEL1;
    wire FAB_READ_BANK_SEL2;
    wire FAB_RDATA0;
    wire FAB_RDATA1;
    wire FAB_RDATA2;
    wire FAB_RDATA3;
    wire FAB_RDATA4;
    wire FAB_RDATA5;
    wire FAB_RDATA6;
    wire FAB_RDATA7;
    wire FAB_RDATA8;
    wire FAB_RDATA9;
    wire FAB_RDATA10;
    wire FAB_RDATA11;
    wire FAB_RDATA12;
    wire FAB_RDATA13;
    wire FAB_RDATA14;
    wire FAB_RDATA15;
    wire FAB_RDATA16;
    wire FAB_RDATA17;
    wire FAB_RDATA18;
    wire FAB_RDATA19;
    wire FAB_RDATA20;
    wire FAB_RDATA21;
    wire FAB_RDATA22;
    wire FAB_RDATA23;
    wire FAB_RDATA24;
    wire FAB_RDATA25;
    wire FAB_RDATA26;
    wire FAB_RDATA27;
    wire FAB_RDATA28;
    wire FAB_RDATA29;
    wire FAB_RDATA30;
    wire FAB_RDATA31;
    wire Tile_X0Y0_UserCLKo;
    wire[FrameBitsPerRow-1:0] Tile_X0Y0_FrameData_O;
    wire Tile_X1Y0_UserCLKo;
    wire[FrameBitsPerRow-1:0] Tile_X1Y0_FrameData_O;
    wire Tile_X2Y0_UserCLKo;
    wire[FrameBitsPerRow-1:0] Tile_X2Y0_FrameData_O;
    wire Tile_X3Y0_UserCLKo;
    wire[FrameBitsPerRow-1:0] Tile_X3Y0_FrameData_O;
    wire[8-1:0] ST_ConfigBits;
    wire[8-1:0] ST_ConfigBits_N;

NPU_ACCUM_S_0
`ifdef EMULATION
    #(
    .Emulate_Bitstream(Tile_X0Y0_Emulate_Bitstream)
    )
`endif
    Tile_X0Y0_NPU_ACCUM_S_0
    (
    .S1END(Tile_X0Y0_S1END),
    .S2MID(Tile_X0Y0_S2MID),
    .S2END(Tile_X0Y0_S2END),
    .S4END(Tile_X0Y0_S4END),
    .SS4END(Tile_X0Y0_SS4END),
    .N1BEG(Tile_X0Y0_N1BEG),
    .N2BEG(Tile_X0Y0_N2BEG),
    .N2BEGb(Tile_X0Y0_N2BEGb),
    .N4BEG(Tile_X0Y0_N4BEG),
    .NN4BEG(Tile_X0Y0_NN4BEG),
    .Co(Tile_X0Y0_Co),
    .BASE_TO_TOP(NPU_ACCUM_S_0_BASE_TO_TOP),
    .TOP_TO_BASE(NPU_ACCUM_S_0_TOP_TO_BASE),
    .UserCLK(Tile_X0Y0_UserCLK),
    .UserCLKo(Tile_X0Y0_UserCLKo),
    .FrameData(Tile_X0Y0_FrameData),
    .FrameData_O(Tile_X0Y0_FrameData_O),
    .FrameStrobe(Tile_X0Y0_FrameStrobe),
    .FrameStrobe_O(Tile_X0Y0_FrameStrobe_O)
);

NPU_ACCUM_S_1
`ifdef EMULATION
    #(
    .Emulate_Bitstream(Tile_X1Y0_Emulate_Bitstream)
    )
`endif
    Tile_X1Y0_NPU_ACCUM_S_1
    (
    .S1END(Tile_X1Y0_S1END),
    .S2MID(Tile_X1Y0_S2MID),
    .S2END(Tile_X1Y0_S2END),
    .S4END(Tile_X1Y0_S4END),
    .SS4END(Tile_X1Y0_SS4END),
    .N1BEG(Tile_X1Y0_N1BEG),
    .N2BEG(Tile_X1Y0_N2BEG),
    .N2BEGb(Tile_X1Y0_N2BEGb),
    .N4BEG(Tile_X1Y0_N4BEG),
    .NN4BEG(Tile_X1Y0_NN4BEG),
    .Co(Tile_X1Y0_Co),
    .BASE_TO_TOP(NPU_ACCUM_S_1_BASE_TO_TOP),
    .TOP_TO_BASE(NPU_ACCUM_S_1_TOP_TO_BASE),
    .UserCLK(Tile_X0Y0_UserCLKo),
    .UserCLKo(Tile_X1Y0_UserCLKo),
    .FrameData(Tile_X0Y0_FrameData_O),
    .FrameData_O(Tile_X1Y0_FrameData_O),
    .FrameStrobe(Tile_X1Y0_FrameStrobe),
    .FrameStrobe_O(Tile_X1Y0_FrameStrobe_O)
);

NPU_ACCUM_S_2
`ifdef EMULATION
    #(
    .Emulate_Bitstream(Tile_X2Y0_Emulate_Bitstream)
    )
`endif
    Tile_X2Y0_NPU_ACCUM_S_2
    (
    .S1END(Tile_X2Y0_S1END),
    .S2MID(Tile_X2Y0_S2MID),
    .S2END(Tile_X2Y0_S2END),
    .S4END(Tile_X2Y0_S4END),
    .SS4END(Tile_X2Y0_SS4END),
    .N1BEG(Tile_X2Y0_N1BEG),
    .N2BEG(Tile_X2Y0_N2BEG),
    .N2BEGb(Tile_X2Y0_N2BEGb),
    .N4BEG(Tile_X2Y0_N4BEG),
    .NN4BEG(Tile_X2Y0_NN4BEG),
    .Co(Tile_X2Y0_Co),
    .BASE_TO_TOP(NPU_ACCUM_S_2_BASE_TO_TOP),
    .TOP_TO_BASE(NPU_ACCUM_S_2_TOP_TO_BASE),
    .UserCLK(Tile_X1Y0_UserCLKo),
    .UserCLKo(Tile_X2Y0_UserCLKo),
    .FrameData(Tile_X1Y0_FrameData_O),
    .FrameData_O(Tile_X2Y0_FrameData_O),
    .FrameStrobe(Tile_X2Y0_FrameStrobe),
    .FrameStrobe_O(Tile_X2Y0_FrameStrobe_O)
);

NPU_ACCUM_S_3
`ifdef EMULATION
    #(
    .Emulate_Bitstream(Tile_X3Y0_Emulate_Bitstream)
    )
`endif
    Tile_X3Y0_NPU_ACCUM_S_3
    (
    .S1END(Tile_X3Y0_S1END),
    .S2MID(Tile_X3Y0_S2MID),
    .S2END(Tile_X3Y0_S2END),
    .S4END(Tile_X3Y0_S4END),
    .SS4END(Tile_X3Y0_SS4END),
    .N1BEG(Tile_X3Y0_N1BEG),
    .N2BEG(Tile_X3Y0_N2BEG),
    .N2BEGb(Tile_X3Y0_N2BEGb),
    .N4BEG(Tile_X3Y0_N4BEG),
    .NN4BEG(Tile_X3Y0_NN4BEG),
    .Co(Tile_X3Y0_Co),
    .BASE_TO_TOP(NPU_ACCUM_S_3_BASE_TO_TOP),
    .TOP_TO_BASE(NPU_ACCUM_S_3_TOP_TO_BASE),
    .UserCLK(Tile_X2Y0_UserCLKo),
    .UserCLKo(Tile_X3Y0_UserCLKo),
    .FrameData(Tile_X2Y0_FrameData_O),
    .FrameData_O(Tile_X3Y0_FrameData_O),
    .FrameStrobe(Tile_X3Y0_FrameStrobe),
    .FrameStrobe_O(Tile_X3Y0_FrameStrobe_O)
);

NPU_ACCUM_S_4
`ifdef EMULATION
    #(
    .Emulate_Bitstream(Tile_X4Y0_Emulate_Bitstream)
    )
`endif
    Tile_X4Y0_NPU_ACCUM_S_4
    (
    .S1END(Tile_X4Y0_S1END),
    .S2MID(Tile_X4Y0_S2MID),
    .S2END(Tile_X4Y0_S2END),
    .S4END(Tile_X4Y0_S4END),
    .SS4END(Tile_X4Y0_SS4END),
    .N1BEG(Tile_X4Y0_N1BEG),
    .N2BEG(Tile_X4Y0_N2BEG),
    .N2BEGb(Tile_X4Y0_N2BEGb),
    .N4BEG(Tile_X4Y0_N4BEG),
    .NN4BEG(Tile_X4Y0_NN4BEG),
    .Co(Tile_X4Y0_Co),
    .BASE_TO_TOP(NPU_ACCUM_S_4_BASE_TO_TOP),
    .UserCLK(Tile_X3Y0_UserCLKo),
    .UserCLKo(Tile_X4Y0_UserCLKo),
    .FrameData(Tile_X3Y0_FrameData_O),
    .FrameData_O(Tile_X4Y0_FrameData_O),
    .FrameStrobe(Tile_X4Y0_FrameStrobe),
    .FrameStrobe_O(Tile_X4Y0_FrameStrobe_O)
);

NPU_ACCUM_S_ConfigMem
`ifdef EMULATION
    #(
    .Emulate_Bitstream(Tile_X4Y0_Emulate_Bitstream)
    )
`endif
    Inst_NPU_ACCUM_S_ConfigMem
    (
    .FrameData(Tile_X3Y0_FrameData_O),
    .FrameStrobe(Tile_X4Y0_FrameStrobe),
    .ConfigBits(ST_ConfigBits[8-1:0]),
    .ConfigBits_N(ST_ConfigBits_N[8-1:0])
);

NPU_ACCUM_S_switch_matrix Inst_NPU_ACCUM_S_switch_matrix (
    .NPU_ACCUM_S_0_BASE_TO_TOP0(NPU_ACCUM_S_0_BASE_TO_TOP[0]),
    .NPU_ACCUM_S_0_BASE_TO_TOP1(NPU_ACCUM_S_0_BASE_TO_TOP[1]),
    .NPU_ACCUM_S_0_BASE_TO_TOP2(NPU_ACCUM_S_0_BASE_TO_TOP[2]),
    .NPU_ACCUM_S_0_BASE_TO_TOP3(NPU_ACCUM_S_0_BASE_TO_TOP[3]),
    .NPU_ACCUM_S_0_BASE_TO_TOP4(NPU_ACCUM_S_0_BASE_TO_TOP[4]),
    .NPU_ACCUM_S_0_BASE_TO_TOP5(NPU_ACCUM_S_0_BASE_TO_TOP[5]),
    .NPU_ACCUM_S_0_BASE_TO_TOP6(NPU_ACCUM_S_0_BASE_TO_TOP[6]),
    .NPU_ACCUM_S_0_BASE_TO_TOP7(NPU_ACCUM_S_0_BASE_TO_TOP[7]),
    .NPU_ACCUM_S_0_BASE_TO_TOP8(NPU_ACCUM_S_0_BASE_TO_TOP[8]),
    .NPU_ACCUM_S_0_BASE_TO_TOP9(NPU_ACCUM_S_0_BASE_TO_TOP[9]),
    .NPU_ACCUM_S_0_BASE_TO_TOP10(NPU_ACCUM_S_0_BASE_TO_TOP[10]),
    .NPU_ACCUM_S_0_BASE_TO_TOP11(NPU_ACCUM_S_0_BASE_TO_TOP[11]),
    .NPU_ACCUM_S_0_BASE_TO_TOP12(NPU_ACCUM_S_0_BASE_TO_TOP[12]),
    .NPU_ACCUM_S_0_BASE_TO_TOP13(NPU_ACCUM_S_0_BASE_TO_TOP[13]),
    .NPU_ACCUM_S_0_BASE_TO_TOP14(NPU_ACCUM_S_0_BASE_TO_TOP[14]),
    .NPU_ACCUM_S_0_BASE_TO_TOP15(NPU_ACCUM_S_0_BASE_TO_TOP[15]),
    .NPU_ACCUM_S_1_BASE_TO_TOP0(NPU_ACCUM_S_1_BASE_TO_TOP[0]),
    .NPU_ACCUM_S_1_BASE_TO_TOP1(NPU_ACCUM_S_1_BASE_TO_TOP[1]),
    .NPU_ACCUM_S_1_BASE_TO_TOP2(NPU_ACCUM_S_1_BASE_TO_TOP[2]),
    .NPU_ACCUM_S_1_BASE_TO_TOP3(NPU_ACCUM_S_1_BASE_TO_TOP[3]),
    .NPU_ACCUM_S_1_BASE_TO_TOP4(NPU_ACCUM_S_1_BASE_TO_TOP[4]),
    .NPU_ACCUM_S_1_BASE_TO_TOP5(NPU_ACCUM_S_1_BASE_TO_TOP[5]),
    .NPU_ACCUM_S_1_BASE_TO_TOP6(NPU_ACCUM_S_1_BASE_TO_TOP[6]),
    .NPU_ACCUM_S_1_BASE_TO_TOP7(NPU_ACCUM_S_1_BASE_TO_TOP[7]),
    .NPU_ACCUM_S_1_BASE_TO_TOP8(NPU_ACCUM_S_1_BASE_TO_TOP[8]),
    .NPU_ACCUM_S_1_BASE_TO_TOP9(NPU_ACCUM_S_1_BASE_TO_TOP[9]),
    .NPU_ACCUM_S_1_BASE_TO_TOP10(NPU_ACCUM_S_1_BASE_TO_TOP[10]),
    .NPU_ACCUM_S_1_BASE_TO_TOP11(NPU_ACCUM_S_1_BASE_TO_TOP[11]),
    .NPU_ACCUM_S_1_BASE_TO_TOP12(NPU_ACCUM_S_1_BASE_TO_TOP[12]),
    .NPU_ACCUM_S_1_BASE_TO_TOP13(NPU_ACCUM_S_1_BASE_TO_TOP[13]),
    .NPU_ACCUM_S_1_BASE_TO_TOP14(NPU_ACCUM_S_1_BASE_TO_TOP[14]),
    .NPU_ACCUM_S_1_BASE_TO_TOP15(NPU_ACCUM_S_1_BASE_TO_TOP[15]),
    .NPU_ACCUM_S_2_BASE_TO_TOP0(NPU_ACCUM_S_2_BASE_TO_TOP[0]),
    .NPU_ACCUM_S_2_BASE_TO_TOP1(NPU_ACCUM_S_2_BASE_TO_TOP[1]),
    .NPU_ACCUM_S_2_BASE_TO_TOP2(NPU_ACCUM_S_2_BASE_TO_TOP[2]),
    .NPU_ACCUM_S_2_BASE_TO_TOP3(NPU_ACCUM_S_2_BASE_TO_TOP[3]),
    .NPU_ACCUM_S_2_BASE_TO_TOP4(NPU_ACCUM_S_2_BASE_TO_TOP[4]),
    .NPU_ACCUM_S_2_BASE_TO_TOP5(NPU_ACCUM_S_2_BASE_TO_TOP[5]),
    .NPU_ACCUM_S_2_BASE_TO_TOP6(NPU_ACCUM_S_2_BASE_TO_TOP[6]),
    .NPU_ACCUM_S_2_BASE_TO_TOP7(NPU_ACCUM_S_2_BASE_TO_TOP[7]),
    .NPU_ACCUM_S_3_BASE_TO_TOP0(NPU_ACCUM_S_3_BASE_TO_TOP[0]),
    .NPU_ACCUM_S_3_BASE_TO_TOP1(NPU_ACCUM_S_3_BASE_TO_TOP[1]),
    .NPU_ACCUM_S_3_BASE_TO_TOP2(NPU_ACCUM_S_3_BASE_TO_TOP[2]),
    .NPU_ACCUM_S_3_BASE_TO_TOP3(NPU_ACCUM_S_3_BASE_TO_TOP[3]),
    .NPU_ACCUM_S_3_BASE_TO_TOP4(NPU_ACCUM_S_3_BASE_TO_TOP[4]),
    .NPU_ACCUM_S_3_BASE_TO_TOP5(NPU_ACCUM_S_3_BASE_TO_TOP[5]),
    .NPU_ACCUM_S_3_BASE_TO_TOP6(NPU_ACCUM_S_3_BASE_TO_TOP[6]),
    .NPU_ACCUM_S_3_BASE_TO_TOP7(NPU_ACCUM_S_3_BASE_TO_TOP[7]),
    .NPU_ACCUM_S_4_BASE_TO_TOP0(NPU_ACCUM_S_4_BASE_TO_TOP[0]),
    .NPU_ACCUM_S_4_BASE_TO_TOP1(NPU_ACCUM_S_4_BASE_TO_TOP[1]),
    .NPU_ACCUM_S_4_BASE_TO_TOP2(NPU_ACCUM_S_4_BASE_TO_TOP[2]),
    .FAB_ADDR0(FAB_ADDR0),
    .FAB_ADDR1(FAB_ADDR1),
    .FAB_ADDR2(FAB_ADDR2),
    .FAB_ADDR3(FAB_ADDR3),
    .FAB_ADDR4(FAB_ADDR4),
    .FAB_ADDR5(FAB_ADDR5),
    .FAB_ADDR6(FAB_ADDR6),
    .FAB_ADDR7(FAB_ADDR7),
    .FAB_WE0(FAB_WE0),
    .FAB_WE1(FAB_WE1),
    .FAB_WE2(FAB_WE2),
    .FAB_WE3(FAB_WE3),
    .FAB_WE4(FAB_WE4),
    .FAB_WE5(FAB_WE5),
    .FAB_WE6(FAB_WE6),
    .FAB_WE7(FAB_WE7),
    .FAB_WDATA0(FAB_WDATA0),
    .FAB_WDATA1(FAB_WDATA1),
    .FAB_WDATA2(FAB_WDATA2),
    .FAB_WDATA3(FAB_WDATA3),
    .FAB_WDATA4(FAB_WDATA4),
    .FAB_WDATA5(FAB_WDATA5),
    .FAB_WDATA6(FAB_WDATA6),
    .FAB_WDATA7(FAB_WDATA7),
    .FAB_WDATA8(FAB_WDATA8),
    .FAB_WDATA9(FAB_WDATA9),
    .FAB_WDATA10(FAB_WDATA10),
    .FAB_WDATA11(FAB_WDATA11),
    .FAB_WDATA12(FAB_WDATA12),
    .FAB_WDATA13(FAB_WDATA13),
    .FAB_WDATA14(FAB_WDATA14),
    .FAB_WDATA15(FAB_WDATA15),
    .FAB_WDATA16(FAB_WDATA16),
    .FAB_WDATA17(FAB_WDATA17),
    .FAB_WDATA18(FAB_WDATA18),
    .FAB_WDATA19(FAB_WDATA19),
    .FAB_WDATA20(FAB_WDATA20),
    .FAB_WDATA21(FAB_WDATA21),
    .FAB_WDATA22(FAB_WDATA22),
    .FAB_WDATA23(FAB_WDATA23),
    .FAB_WDATA24(FAB_WDATA24),
    .FAB_WDATA25(FAB_WDATA25),
    .FAB_WDATA26(FAB_WDATA26),
    .FAB_WDATA27(FAB_WDATA27),
    .FAB_WDATA28(FAB_WDATA28),
    .FAB_WDATA29(FAB_WDATA29),
    .FAB_WDATA30(FAB_WDATA30),
    .FAB_WDATA31(FAB_WDATA31),
    .FAB_READ_BANK_SEL0(FAB_READ_BANK_SEL0),
    .FAB_READ_BANK_SEL1(FAB_READ_BANK_SEL1),
    .FAB_READ_BANK_SEL2(FAB_READ_BANK_SEL2),
    .FAB_RDATA0(FAB_RDATA0),
    .FAB_RDATA1(FAB_RDATA1),
    .FAB_RDATA2(FAB_RDATA2),
    .FAB_RDATA3(FAB_RDATA3),
    .FAB_RDATA4(FAB_RDATA4),
    .FAB_RDATA5(FAB_RDATA5),
    .FAB_RDATA6(FAB_RDATA6),
    .FAB_RDATA7(FAB_RDATA7),
    .FAB_RDATA8(FAB_RDATA8),
    .FAB_RDATA9(FAB_RDATA9),
    .FAB_RDATA10(FAB_RDATA10),
    .FAB_RDATA11(FAB_RDATA11),
    .FAB_RDATA12(FAB_RDATA12),
    .FAB_RDATA13(FAB_RDATA13),
    .FAB_RDATA14(FAB_RDATA14),
    .FAB_RDATA15(FAB_RDATA15),
    .FAB_RDATA16(FAB_RDATA16),
    .FAB_RDATA17(FAB_RDATA17),
    .FAB_RDATA18(FAB_RDATA18),
    .FAB_RDATA19(FAB_RDATA19),
    .FAB_RDATA20(FAB_RDATA20),
    .FAB_RDATA21(FAB_RDATA21),
    .FAB_RDATA22(FAB_RDATA22),
    .FAB_RDATA23(FAB_RDATA23),
    .FAB_RDATA24(FAB_RDATA24),
    .FAB_RDATA25(FAB_RDATA25),
    .FAB_RDATA26(FAB_RDATA26),
    .FAB_RDATA27(FAB_RDATA27),
    .FAB_RDATA28(FAB_RDATA28),
    .FAB_RDATA29(FAB_RDATA29),
    .FAB_RDATA30(FAB_RDATA30),
    .FAB_RDATA31(FAB_RDATA31),
    .NPU_ACCUM_S_0_TOP_TO_BASE0(NPU_ACCUM_S_0_TOP_TO_BASE[0]),
    .NPU_ACCUM_S_0_TOP_TO_BASE1(NPU_ACCUM_S_0_TOP_TO_BASE[1]),
    .NPU_ACCUM_S_0_TOP_TO_BASE2(NPU_ACCUM_S_0_TOP_TO_BASE[2]),
    .NPU_ACCUM_S_0_TOP_TO_BASE3(NPU_ACCUM_S_0_TOP_TO_BASE[3]),
    .NPU_ACCUM_S_0_TOP_TO_BASE4(NPU_ACCUM_S_0_TOP_TO_BASE[4]),
    .NPU_ACCUM_S_0_TOP_TO_BASE5(NPU_ACCUM_S_0_TOP_TO_BASE[5]),
    .NPU_ACCUM_S_0_TOP_TO_BASE6(NPU_ACCUM_S_0_TOP_TO_BASE[6]),
    .NPU_ACCUM_S_0_TOP_TO_BASE7(NPU_ACCUM_S_0_TOP_TO_BASE[7]),
    .NPU_ACCUM_S_1_TOP_TO_BASE0(NPU_ACCUM_S_1_TOP_TO_BASE[0]),
    .NPU_ACCUM_S_1_TOP_TO_BASE1(NPU_ACCUM_S_1_TOP_TO_BASE[1]),
    .NPU_ACCUM_S_1_TOP_TO_BASE2(NPU_ACCUM_S_1_TOP_TO_BASE[2]),
    .NPU_ACCUM_S_1_TOP_TO_BASE3(NPU_ACCUM_S_1_TOP_TO_BASE[3]),
    .NPU_ACCUM_S_1_TOP_TO_BASE4(NPU_ACCUM_S_1_TOP_TO_BASE[4]),
    .NPU_ACCUM_S_1_TOP_TO_BASE5(NPU_ACCUM_S_1_TOP_TO_BASE[5]),
    .NPU_ACCUM_S_1_TOP_TO_BASE6(NPU_ACCUM_S_1_TOP_TO_BASE[6]),
    .NPU_ACCUM_S_1_TOP_TO_BASE7(NPU_ACCUM_S_1_TOP_TO_BASE[7]),
    .NPU_ACCUM_S_2_TOP_TO_BASE0(NPU_ACCUM_S_2_TOP_TO_BASE[0]),
    .NPU_ACCUM_S_2_TOP_TO_BASE1(NPU_ACCUM_S_2_TOP_TO_BASE[1]),
    .NPU_ACCUM_S_2_TOP_TO_BASE2(NPU_ACCUM_S_2_TOP_TO_BASE[2]),
    .NPU_ACCUM_S_2_TOP_TO_BASE3(NPU_ACCUM_S_2_TOP_TO_BASE[3]),
    .NPU_ACCUM_S_2_TOP_TO_BASE4(NPU_ACCUM_S_2_TOP_TO_BASE[4]),
    .NPU_ACCUM_S_2_TOP_TO_BASE5(NPU_ACCUM_S_2_TOP_TO_BASE[5]),
    .NPU_ACCUM_S_2_TOP_TO_BASE6(NPU_ACCUM_S_2_TOP_TO_BASE[6]),
    .NPU_ACCUM_S_2_TOP_TO_BASE7(NPU_ACCUM_S_2_TOP_TO_BASE[7]),
    .NPU_ACCUM_S_3_TOP_TO_BASE0(NPU_ACCUM_S_3_TOP_TO_BASE[0]),
    .NPU_ACCUM_S_3_TOP_TO_BASE1(NPU_ACCUM_S_3_TOP_TO_BASE[1]),
    .NPU_ACCUM_S_3_TOP_TO_BASE2(NPU_ACCUM_S_3_TOP_TO_BASE[2]),
    .NPU_ACCUM_S_3_TOP_TO_BASE3(NPU_ACCUM_S_3_TOP_TO_BASE[3]),
    .NPU_ACCUM_S_3_TOP_TO_BASE4(NPU_ACCUM_S_3_TOP_TO_BASE[4]),
    .NPU_ACCUM_S_3_TOP_TO_BASE5(NPU_ACCUM_S_3_TOP_TO_BASE[5]),
    .NPU_ACCUM_S_3_TOP_TO_BASE6(NPU_ACCUM_S_3_TOP_TO_BASE[6]),
    .NPU_ACCUM_S_3_TOP_TO_BASE7(NPU_ACCUM_S_3_TOP_TO_BASE[7])
);

NPU_ACCUM_SRAM_BEL Inst_ST_NPU_ACCUM_SRAM_BEL (
    .FAB_ADDR({FAB_ADDR7, FAB_ADDR6, FAB_ADDR5, FAB_ADDR4, FAB_ADDR3, FAB_ADDR2, FAB_ADDR1, FAB_ADDR0}),
    .FAB_WE({FAB_WE7, FAB_WE6, FAB_WE5, FAB_WE4, FAB_WE3, FAB_WE2, FAB_WE1, FAB_WE0}),
    .FAB_WDATA({FAB_WDATA31, FAB_WDATA30, FAB_WDATA29, FAB_WDATA28, FAB_WDATA27, FAB_WDATA26, FAB_WDATA25, FAB_WDATA24, FAB_WDATA23, FAB_WDATA22, FAB_WDATA21, FAB_WDATA20, FAB_WDATA19, FAB_WDATA18, FAB_WDATA17, FAB_WDATA16, FAB_WDATA15, FAB_WDATA14, FAB_WDATA13, FAB_WDATA12, FAB_WDATA11, FAB_WDATA10, FAB_WDATA9, FAB_WDATA8, FAB_WDATA7, FAB_WDATA6, FAB_WDATA5, FAB_WDATA4, FAB_WDATA3, FAB_WDATA2, FAB_WDATA1, FAB_WDATA0}),
    .FAB_READ_BANK_SEL({FAB_READ_BANK_SEL2, FAB_READ_BANK_SEL1, FAB_READ_BANK_SEL0}),
    .FAB_RDATA({FAB_RDATA31, FAB_RDATA30, FAB_RDATA29, FAB_RDATA28, FAB_RDATA27, FAB_RDATA26, FAB_RDATA25, FAB_RDATA24, FAB_RDATA23, FAB_RDATA22, FAB_RDATA21, FAB_RDATA20, FAB_RDATA19, FAB_RDATA18, FAB_RDATA17, FAB_RDATA16, FAB_RDATA15, FAB_RDATA14, FAB_RDATA13, FAB_RDATA12, FAB_RDATA11, FAB_RDATA10, FAB_RDATA9, FAB_RDATA8, FAB_RDATA7, FAB_RDATA6, FAB_RDATA5, FAB_RDATA4, FAB_RDATA3, FAB_RDATA2, FAB_RDATA1, FAB_RDATA0}),
    .NPU_ADDR({NPU_ADDR7, NPU_ADDR6, NPU_ADDR5, NPU_ADDR4, NPU_ADDR3, NPU_ADDR2, NPU_ADDR1, NPU_ADDR0}),
    .NPU_WE({NPU_WE7, NPU_WE6, NPU_WE5, NPU_WE4, NPU_WE3, NPU_WE2, NPU_WE1, NPU_WE0}),
    .NPU_WDATA({NPU_WDATA31, NPU_WDATA30, NPU_WDATA29, NPU_WDATA28, NPU_WDATA27, NPU_WDATA26, NPU_WDATA25, NPU_WDATA24, NPU_WDATA23, NPU_WDATA22, NPU_WDATA21, NPU_WDATA20, NPU_WDATA19, NPU_WDATA18, NPU_WDATA17, NPU_WDATA16, NPU_WDATA15, NPU_WDATA14, NPU_WDATA13, NPU_WDATA12, NPU_WDATA11, NPU_WDATA10, NPU_WDATA9, NPU_WDATA8, NPU_WDATA7, NPU_WDATA6, NPU_WDATA5, NPU_WDATA4, NPU_WDATA3, NPU_WDATA2, NPU_WDATA1, NPU_WDATA0}),
    .NPU_READ_BANK_SEL({NPU_READ_BANK_SEL2, NPU_READ_BANK_SEL1, NPU_READ_BANK_SEL0}),
    .NPU_RDATA({NPU_RDATA31, NPU_RDATA30, NPU_RDATA29, NPU_RDATA28, NPU_RDATA27, NPU_RDATA26, NPU_RDATA25, NPU_RDATA24, NPU_RDATA23, NPU_RDATA22, NPU_RDATA21, NPU_RDATA20, NPU_RDATA19, NPU_RDATA18, NPU_RDATA17, NPU_RDATA16, NPU_RDATA15, NPU_RDATA14, NPU_RDATA13, NPU_RDATA12, NPU_RDATA11, NPU_RDATA10, NPU_RDATA9, NPU_RDATA8, NPU_RDATA7, NPU_RDATA6, NPU_RDATA5, NPU_RDATA4, NPU_RDATA3, NPU_RDATA2, NPU_RDATA1, NPU_RDATA0}),
    .UserCLK(Tile_X3Y0_UserCLKo),
    .ConfigBits(ST_ConfigBits[8-1:0])
);

endmodule