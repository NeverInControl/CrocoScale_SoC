module NPU_SLICE
    #(
`ifdef EMULATION
        parameter [639:0] Tile_X0Y0_Emulate_Bitstream=640'b0,
        parameter [639:0] Tile_X0Y1_Emulate_Bitstream=640'b0,
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
        input  [3:0] Tile_X0Y0_S1END, //TilePort({N} INPUT S1END[3:0])
        input  [7:0] Tile_X0Y0_S2MID, //TilePort({N} INPUT S2MID[7:0])
        input  [7:0] Tile_X0Y0_S2END, //TilePort({N} INPUT S2END[7:0])
        input  [15:0] Tile_X0Y0_S4END, //TilePort({N} INPUT S4END[3:0])
    //Tile_X0Y0_Direction.EAST
        input  [3:0] Tile_X0Y0_E1END, //TilePort({W} INPUT E1END[3:0])
        input  [7:0] Tile_X0Y0_E2MID, //TilePort({W} INPUT E2MID[7:0])
        input  [7:0] Tile_X0Y0_E2END, //TilePort({W} INPUT E2END[7:0])
        input  [15:0] Tile_X0Y0_EE4END, //TilePort({W} INPUT EE4END[3:0])
        input  [11:0] Tile_X0Y0_E6END, //TilePort({W} INPUT E6END[1:0])
        output  [3:0] Tile_X0Y0_W1BEG, //TilePort({W} OUTPUT W1BEG[3:0])
        output  [7:0] Tile_X0Y0_W2BEG, //TilePort({W} OUTPUT W2BEG[7:0])
        output  [7:0] Tile_X0Y0_W2BEGb, //TilePort({W} OUTPUT W2BEGb[7:0])
        output  [15:0] Tile_X0Y0_WW4BEG, //TilePort({W} OUTPUT WW4BEG[3:0])
        output  [11:0] Tile_X0Y0_W6BEG, //TilePort({W} OUTPUT W6BEG[1:0])
    //Tile_X0Y1_Direction.NORTH
        input  [3:0] Tile_X0Y1_N1END, //TilePort({S} INPUT N1END[3:0])
        input  [7:0] Tile_X0Y1_N2MID, //TilePort({S} INPUT N2MID[7:0])
        input  [7:0] Tile_X0Y1_N2END, //TilePort({S} INPUT N2END[7:0])
        input  [15:0] Tile_X0Y1_N4END, //TilePort({S} INPUT N4END[3:0])
        output  [3:0] Tile_X0Y1_S1BEG, //TilePort({S} OUTPUT S1BEG[3:0])
        output  [7:0] Tile_X0Y1_S2BEG, //TilePort({S} OUTPUT S2BEG[7:0])
        output  [7:0] Tile_X0Y1_S2BEGb, //TilePort({S} OUTPUT S2BEGb[7:0])
        output  [15:0] Tile_X0Y1_S4BEG, //TilePort({S} OUTPUT S4BEG[3:0])
    //Tile_X0Y1_Direction.EAST
        input  [3:0] Tile_X0Y1_E1END, //TilePort({W} INPUT E1END[3:0])
        input  [7:0] Tile_X0Y1_E2MID, //TilePort({W} INPUT E2MID[7:0])
        input  [7:0] Tile_X0Y1_E2END, //TilePort({W} INPUT E2END[7:0])
        input  [15:0] Tile_X0Y1_EE4END, //TilePort({W} INPUT EE4END[3:0])
        input  [11:0] Tile_X0Y1_E6END, //TilePort({W} INPUT E6END[1:0])
        output  [3:0] Tile_X0Y1_W1BEG, //TilePort({W} OUTPUT W1BEG[3:0])
        output  [7:0] Tile_X0Y1_W2BEG, //TilePort({W} OUTPUT W2BEG[7:0])
        output  [7:0] Tile_X0Y1_W2BEGb, //TilePort({W} OUTPUT W2BEGb[7:0])
        output  [15:0] Tile_X0Y1_WW4BEG, //TilePort({W} OUTPUT WW4BEG[3:0])
        output  [11:0] Tile_X0Y1_W6BEG, //TilePort({W} OUTPUT W6BEG[1:0])
    //Tile IO ports from BELs
    //SuperTile BEL IO ports
        input  NPU_ACT_RDATA0,
        input  NPU_ACT_RDATA1,
        input  NPU_ACT_RDATA2,
        input  NPU_ACT_RDATA3,
        input  NPU_ACT_RDATA4,
        input  NPU_ACT_RDATA5,
        input  NPU_ACT_RDATA6,
        input  NPU_ACT_RDATA7,
        input  NPU_OUT_ACT0,
        input  NPU_OUT_ACT1,
        input  NPU_OUT_ACT2,
        input  NPU_OUT_ACT3,
        input  NPU_OUT_ACT4,
        input  NPU_OUT_ACT5,
        input  NPU_OUT_ACT6,
        input  NPU_OUT_ACT7,
        output  NPU_ACT_ADDR0,
        output  NPU_ACT_ADDR1,
        output  NPU_ACT_ADDR2,
        output  NPU_ACT_ADDR3,
        output  NPU_ACT_ADDR4,
        output  NPU_ACT_ADDR5,
        output  NPU_ACT_ADDR6,
        output  NPU_ACT_ADDR7,
        output  NPU_ACT_ADDR8,
        output  NPU_ACT_WDATA0,
        output  NPU_ACT_WDATA1,
        output  NPU_ACT_WDATA2,
        output  NPU_ACT_WDATA3,
        output  NPU_ACT_WDATA4,
        output  NPU_ACT_WDATA5,
        output  NPU_ACT_WDATA6,
        output  NPU_ACT_WDATA7,
        output  NPU_ACT_WE,
        output  NPU_WEIGHT_IN0,
        output  NPU_WEIGHT_IN1,
        output  NPU_WEIGHT_IN2,
        output  NPU_WEIGHT_IN3,
        output  NPU_WEIGHT_IN4,
        output  NPU_WEIGHT_IN5,
        output  NPU_WEIGHT_IN6,
        output  NPU_WEIGHT_IN7,
        output  NPU_WEIGHT_SHIFT_EN,
        output  NPU_XBAR_SEL0,
        output  NPU_XBAR_SEL1,
        output  NPU_XBAR_SEL2,
        output  NPU_XBAR_SEL3,
        output  [MaxFramesPerCol-1:0] Tile_X0Y0_FrameStrobe_O, //CONFIG_PORT
        input  [FrameBitsPerRow-1:0] Tile_X0Y0_FrameData, //CONFIG_PORT
        output  [FrameBitsPerRow-1:0] Tile_X0Y0_FrameData_O, //CONFIG_PORT
        input  [FrameBitsPerRow-1:0] Tile_X0Y1_FrameData, //CONFIG_PORT
        input  [MaxFramesPerCol-1:0] Tile_X0Y1_FrameStrobe, //CONFIG_PORT
        output  [FrameBitsPerRow-1:0] Tile_X0Y1_FrameData_O, //CONFIG_PORT
        output  Tile_X0Y0_UserCLKo,
        input  Tile_X0Y0_UserCLK,
        output  Tile_X0Y1_UserCLKo,
        input  Tile_X0Y1_UserCLK
);

 //signal declarations
 //SJUMP signals (child tile -> supertile SM)
    wire[15-1:0] NPU_SLICE_1_BASE_TO_TOP;
    wire[16-1:0] NPU_SLICE_0_BASE_TO_TOP;
 //SJUMP signals (supertile SM -> child tile)
    wire[8-1:0] NPU_SLICE_1_TOP_TO_BASE;
    wire[8-1:0] NPU_SLICE_0_TOP_TO_BASE;
 //BEL pin signals (BEL <-> supertile SM)
    wire FAB_ACT_ADDR0;
    wire FAB_ACT_ADDR1;
    wire FAB_ACT_ADDR2;
    wire FAB_ACT_ADDR3;
    wire FAB_ACT_ADDR4;
    wire FAB_ACT_ADDR5;
    wire FAB_ACT_ADDR6;
    wire FAB_ACT_ADDR7;
    wire FAB_ACT_ADDR8;
    wire FAB_ACT_WDATA0;
    wire FAB_ACT_WDATA1;
    wire FAB_ACT_WDATA2;
    wire FAB_ACT_WDATA3;
    wire FAB_ACT_WDATA4;
    wire FAB_ACT_WDATA5;
    wire FAB_ACT_WDATA6;
    wire FAB_ACT_WDATA7;
    wire FAB_ACT_WE;
    wire FAB_WEIGHT_IN0;
    wire FAB_WEIGHT_IN1;
    wire FAB_WEIGHT_IN2;
    wire FAB_WEIGHT_IN3;
    wire FAB_WEIGHT_IN4;
    wire FAB_WEIGHT_IN5;
    wire FAB_WEIGHT_IN6;
    wire FAB_WEIGHT_IN7;
    wire FAB_WEIGHT_SHIFT_EN;
    wire FAB_XBAR_SEL0;
    wire FAB_XBAR_SEL1;
    wire FAB_XBAR_SEL2;
    wire FAB_XBAR_SEL3;
    wire FAB_ACT_RDATA0;
    wire FAB_ACT_RDATA1;
    wire FAB_ACT_RDATA2;
    wire FAB_ACT_RDATA3;
    wire FAB_ACT_RDATA4;
    wire FAB_ACT_RDATA5;
    wire FAB_ACT_RDATA6;
    wire FAB_ACT_RDATA7;
    wire FAB_OUT_ACT0;
    wire FAB_OUT_ACT1;
    wire FAB_OUT_ACT2;
    wire FAB_OUT_ACT3;
    wire FAB_OUT_ACT4;
    wire FAB_OUT_ACT5;
    wire FAB_OUT_ACT6;
    wire FAB_OUT_ACT7;
 //Tile_X0Y0_Direction.NORTH
    wire[3:0] Tile_X0Y0_S1BEG; //TilePort({S} OUTPUT S1BEG[3:0])
    wire[7:0] Tile_X0Y0_S2BEG; //TilePort({S} OUTPUT S2BEG[7:0])
    wire[7:0] Tile_X0Y0_S2BEGb; //TilePort({S} OUTPUT S2BEGb[7:0])
    wire[15:0] Tile_X0Y0_S4BEG; //TilePort({S} OUTPUT S4BEG[3:0])
 //Tile_X0Y1_Direction.NORTH
    wire[3:0] Tile_X0Y1_N1BEG; //TilePort({N} OUTPUT N1BEG[3:0])
    wire[7:0] Tile_X0Y1_N2BEG; //TilePort({N} OUTPUT N2BEG[7:0])
    wire[7:0] Tile_X0Y1_N2BEGb; //TilePort({N} OUTPUT N2BEGb[7:0])
    wire[15:0] Tile_X0Y1_N4BEG; //TilePort({N} OUTPUT N4BEG[3:0])
    wire[MaxFramesPerCol-1:0] Tile_X0Y1_FrameStrobe_O;
    wire[6-1:0] ST_ConfigBits;
    wire[6-1:0] ST_ConfigBits_N;

NPU_SLICE_1
`ifdef EMULATION
    #(
    .Emulate_Bitstream(Tile_X0Y0_Emulate_Bitstream)
    )
`endif
    Tile_X0Y0_NPU_SLICE_1
    (
    .N1END(Tile_X0Y1_N1BEG),
    .N2MID(Tile_X0Y1_N2BEG),
    .N2END(Tile_X0Y1_N2BEGb),
    .N4END(Tile_X0Y1_N4BEG),
    .E1END(Tile_X0Y0_E1END),
    .E2MID(Tile_X0Y0_E2MID),
    .E2END(Tile_X0Y0_E2END),
    .EE4END(Tile_X0Y0_EE4END),
    .E6END(Tile_X0Y0_E6END),
    .S1END(Tile_X0Y0_S1END),
    .S2MID(Tile_X0Y0_S2MID),
    .S2END(Tile_X0Y0_S2END),
    .S4END(Tile_X0Y0_S4END),
    .N1BEG(Tile_X0Y0_N1BEG),
    .N2BEG(Tile_X0Y0_N2BEG),
    .N2BEGb(Tile_X0Y0_N2BEGb),
    .N4BEG(Tile_X0Y0_N4BEG),
    .S1BEG(Tile_X0Y0_S1BEG),
    .S2BEG(Tile_X0Y0_S2BEG),
    .S2BEGb(Tile_X0Y0_S2BEGb),
    .S4BEG(Tile_X0Y0_S4BEG),
    .W1BEG(Tile_X0Y0_W1BEG),
    .W2BEG(Tile_X0Y0_W2BEG),
    .W2BEGb(Tile_X0Y0_W2BEGb),
    .WW4BEG(Tile_X0Y0_WW4BEG),
    .W6BEG(Tile_X0Y0_W6BEG),
    .BASE_TO_TOP(NPU_SLICE_1_BASE_TO_TOP),
    .TOP_TO_BASE(NPU_SLICE_1_TOP_TO_BASE),
    .UserCLK(Tile_X0Y0_UserCLK),
    .UserCLKo(Tile_X0Y0_UserCLKo),
    .FrameData(Tile_X0Y0_FrameData),
    .FrameData_O(Tile_X0Y0_FrameData_O),
    .FrameStrobe(Tile_X0Y1_FrameStrobe_O),
    .FrameStrobe_O(Tile_X0Y0_FrameStrobe_O)
);

NPU_SLICE_0
`ifdef EMULATION
    #(
    .Emulate_Bitstream(Tile_X0Y1_Emulate_Bitstream)
    )
`endif
    Tile_X0Y1_NPU_SLICE_0
    (
    .N1END(Tile_X0Y1_N1END),
    .N2MID(Tile_X0Y1_N2MID),
    .N2END(Tile_X0Y1_N2END),
    .N4END(Tile_X0Y1_N4END),
    .E1END(Tile_X0Y1_E1END),
    .E2MID(Tile_X0Y1_E2MID),
    .E2END(Tile_X0Y1_E2END),
    .EE4END(Tile_X0Y1_EE4END),
    .E6END(Tile_X0Y1_E6END),
    .S1END(Tile_X0Y0_S1BEG),
    .S2MID(Tile_X0Y0_S2BEG),
    .S2END(Tile_X0Y0_S2BEGb),
    .S4END(Tile_X0Y0_S4BEG),
    .N1BEG(Tile_X0Y1_N1BEG),
    .N2BEG(Tile_X0Y1_N2BEG),
    .N2BEGb(Tile_X0Y1_N2BEGb),
    .N4BEG(Tile_X0Y1_N4BEG),
    .S1BEG(Tile_X0Y1_S1BEG),
    .S2BEG(Tile_X0Y1_S2BEG),
    .S2BEGb(Tile_X0Y1_S2BEGb),
    .S4BEG(Tile_X0Y1_S4BEG),
    .W1BEG(Tile_X0Y1_W1BEG),
    .W2BEG(Tile_X0Y1_W2BEG),
    .W2BEGb(Tile_X0Y1_W2BEGb),
    .WW4BEG(Tile_X0Y1_WW4BEG),
    .W6BEG(Tile_X0Y1_W6BEG),
    .BASE_TO_TOP(NPU_SLICE_0_BASE_TO_TOP),
    .TOP_TO_BASE(NPU_SLICE_0_TOP_TO_BASE),
    .UserCLK(Tile_X0Y1_UserCLK),
    .UserCLKo(Tile_X0Y1_UserCLKo),
    .FrameData(Tile_X0Y1_FrameData),
    .FrameData_O(Tile_X0Y1_FrameData_O),
    .FrameStrobe(Tile_X0Y1_FrameStrobe),
    .FrameStrobe_O(Tile_X0Y1_FrameStrobe_O)
);

NPU_SLICE_ConfigMem
`ifdef EMULATION
    #(
    .Emulate_Bitstream(Tile_X0Y1_Emulate_Bitstream)
    )
`endif
    Inst_NPU_SLICE_ConfigMem
    (
    .FrameData(Tile_X0Y1_FrameData),
    .FrameStrobe(Tile_X0Y1_FrameStrobe),
    .ConfigBits(ST_ConfigBits[6-1:0]),
    .ConfigBits_N(ST_ConfigBits_N[6-1:0])
);

NPU_SLICE_switch_matrix Inst_NPU_SLICE_switch_matrix (
    .NPU_SLICE_1_BASE_TO_TOP0(NPU_SLICE_1_BASE_TO_TOP[0]),
    .NPU_SLICE_1_BASE_TO_TOP1(NPU_SLICE_1_BASE_TO_TOP[1]),
    .NPU_SLICE_1_BASE_TO_TOP2(NPU_SLICE_1_BASE_TO_TOP[2]),
    .NPU_SLICE_1_BASE_TO_TOP3(NPU_SLICE_1_BASE_TO_TOP[3]),
    .NPU_SLICE_1_BASE_TO_TOP4(NPU_SLICE_1_BASE_TO_TOP[4]),
    .NPU_SLICE_1_BASE_TO_TOP5(NPU_SLICE_1_BASE_TO_TOP[5]),
    .NPU_SLICE_1_BASE_TO_TOP6(NPU_SLICE_1_BASE_TO_TOP[6]),
    .NPU_SLICE_1_BASE_TO_TOP7(NPU_SLICE_1_BASE_TO_TOP[7]),
    .NPU_SLICE_1_BASE_TO_TOP8(NPU_SLICE_1_BASE_TO_TOP[8]),
    .NPU_SLICE_1_BASE_TO_TOP9(NPU_SLICE_1_BASE_TO_TOP[9]),
    .NPU_SLICE_1_BASE_TO_TOP10(NPU_SLICE_1_BASE_TO_TOP[10]),
    .NPU_SLICE_1_BASE_TO_TOP11(NPU_SLICE_1_BASE_TO_TOP[11]),
    .NPU_SLICE_1_BASE_TO_TOP12(NPU_SLICE_1_BASE_TO_TOP[12]),
    .NPU_SLICE_1_BASE_TO_TOP13(NPU_SLICE_1_BASE_TO_TOP[13]),
    .NPU_SLICE_1_BASE_TO_TOP14(NPU_SLICE_1_BASE_TO_TOP[14]),
    .NPU_SLICE_0_BASE_TO_TOP0(NPU_SLICE_0_BASE_TO_TOP[0]),
    .NPU_SLICE_0_BASE_TO_TOP1(NPU_SLICE_0_BASE_TO_TOP[1]),
    .NPU_SLICE_0_BASE_TO_TOP2(NPU_SLICE_0_BASE_TO_TOP[2]),
    .NPU_SLICE_0_BASE_TO_TOP3(NPU_SLICE_0_BASE_TO_TOP[3]),
    .NPU_SLICE_0_BASE_TO_TOP4(NPU_SLICE_0_BASE_TO_TOP[4]),
    .NPU_SLICE_0_BASE_TO_TOP5(NPU_SLICE_0_BASE_TO_TOP[5]),
    .NPU_SLICE_0_BASE_TO_TOP6(NPU_SLICE_0_BASE_TO_TOP[6]),
    .NPU_SLICE_0_BASE_TO_TOP7(NPU_SLICE_0_BASE_TO_TOP[7]),
    .NPU_SLICE_0_BASE_TO_TOP8(NPU_SLICE_0_BASE_TO_TOP[8]),
    .NPU_SLICE_0_BASE_TO_TOP9(NPU_SLICE_0_BASE_TO_TOP[9]),
    .NPU_SLICE_0_BASE_TO_TOP10(NPU_SLICE_0_BASE_TO_TOP[10]),
    .NPU_SLICE_0_BASE_TO_TOP11(NPU_SLICE_0_BASE_TO_TOP[11]),
    .NPU_SLICE_0_BASE_TO_TOP12(NPU_SLICE_0_BASE_TO_TOP[12]),
    .NPU_SLICE_0_BASE_TO_TOP13(NPU_SLICE_0_BASE_TO_TOP[13]),
    .NPU_SLICE_0_BASE_TO_TOP14(NPU_SLICE_0_BASE_TO_TOP[14]),
    .NPU_SLICE_0_BASE_TO_TOP15(NPU_SLICE_0_BASE_TO_TOP[15]),
    .FAB_ACT_ADDR0(FAB_ACT_ADDR0),
    .FAB_ACT_ADDR1(FAB_ACT_ADDR1),
    .FAB_ACT_ADDR2(FAB_ACT_ADDR2),
    .FAB_ACT_ADDR3(FAB_ACT_ADDR3),
    .FAB_ACT_ADDR4(FAB_ACT_ADDR4),
    .FAB_ACT_ADDR5(FAB_ACT_ADDR5),
    .FAB_ACT_ADDR6(FAB_ACT_ADDR6),
    .FAB_ACT_ADDR7(FAB_ACT_ADDR7),
    .FAB_ACT_ADDR8(FAB_ACT_ADDR8),
    .FAB_ACT_WDATA0(FAB_ACT_WDATA0),
    .FAB_ACT_WDATA1(FAB_ACT_WDATA1),
    .FAB_ACT_WDATA2(FAB_ACT_WDATA2),
    .FAB_ACT_WDATA3(FAB_ACT_WDATA3),
    .FAB_ACT_WDATA4(FAB_ACT_WDATA4),
    .FAB_ACT_WDATA5(FAB_ACT_WDATA5),
    .FAB_ACT_WDATA6(FAB_ACT_WDATA6),
    .FAB_ACT_WDATA7(FAB_ACT_WDATA7),
    .FAB_ACT_WE(FAB_ACT_WE),
    .FAB_WEIGHT_IN0(FAB_WEIGHT_IN0),
    .FAB_WEIGHT_IN1(FAB_WEIGHT_IN1),
    .FAB_WEIGHT_IN2(FAB_WEIGHT_IN2),
    .FAB_WEIGHT_IN3(FAB_WEIGHT_IN3),
    .FAB_WEIGHT_IN4(FAB_WEIGHT_IN4),
    .FAB_WEIGHT_IN5(FAB_WEIGHT_IN5),
    .FAB_WEIGHT_IN6(FAB_WEIGHT_IN6),
    .FAB_WEIGHT_IN7(FAB_WEIGHT_IN7),
    .FAB_WEIGHT_SHIFT_EN(FAB_WEIGHT_SHIFT_EN),
    .FAB_XBAR_SEL0(FAB_XBAR_SEL0),
    .FAB_XBAR_SEL1(FAB_XBAR_SEL1),
    .FAB_XBAR_SEL2(FAB_XBAR_SEL2),
    .FAB_XBAR_SEL3(FAB_XBAR_SEL3),
    .FAB_ACT_RDATA0(FAB_ACT_RDATA0),
    .FAB_ACT_RDATA1(FAB_ACT_RDATA1),
    .FAB_ACT_RDATA2(FAB_ACT_RDATA2),
    .FAB_ACT_RDATA3(FAB_ACT_RDATA3),
    .FAB_ACT_RDATA4(FAB_ACT_RDATA4),
    .FAB_ACT_RDATA5(FAB_ACT_RDATA5),
    .FAB_ACT_RDATA6(FAB_ACT_RDATA6),
    .FAB_ACT_RDATA7(FAB_ACT_RDATA7),
    .FAB_OUT_ACT0(FAB_OUT_ACT0),
    .FAB_OUT_ACT1(FAB_OUT_ACT1),
    .FAB_OUT_ACT2(FAB_OUT_ACT2),
    .FAB_OUT_ACT3(FAB_OUT_ACT3),
    .FAB_OUT_ACT4(FAB_OUT_ACT4),
    .FAB_OUT_ACT5(FAB_OUT_ACT5),
    .FAB_OUT_ACT6(FAB_OUT_ACT6),
    .FAB_OUT_ACT7(FAB_OUT_ACT7),
    .NPU_SLICE_1_TOP_TO_BASE0(NPU_SLICE_1_TOP_TO_BASE[0]),
    .NPU_SLICE_1_TOP_TO_BASE1(NPU_SLICE_1_TOP_TO_BASE[1]),
    .NPU_SLICE_1_TOP_TO_BASE2(NPU_SLICE_1_TOP_TO_BASE[2]),
    .NPU_SLICE_1_TOP_TO_BASE3(NPU_SLICE_1_TOP_TO_BASE[3]),
    .NPU_SLICE_1_TOP_TO_BASE4(NPU_SLICE_1_TOP_TO_BASE[4]),
    .NPU_SLICE_1_TOP_TO_BASE5(NPU_SLICE_1_TOP_TO_BASE[5]),
    .NPU_SLICE_1_TOP_TO_BASE6(NPU_SLICE_1_TOP_TO_BASE[6]),
    .NPU_SLICE_1_TOP_TO_BASE7(NPU_SLICE_1_TOP_TO_BASE[7]),
    .NPU_SLICE_0_TOP_TO_BASE0(NPU_SLICE_0_TOP_TO_BASE[0]),
    .NPU_SLICE_0_TOP_TO_BASE1(NPU_SLICE_0_TOP_TO_BASE[1]),
    .NPU_SLICE_0_TOP_TO_BASE2(NPU_SLICE_0_TOP_TO_BASE[2]),
    .NPU_SLICE_0_TOP_TO_BASE3(NPU_SLICE_0_TOP_TO_BASE[3]),
    .NPU_SLICE_0_TOP_TO_BASE4(NPU_SLICE_0_TOP_TO_BASE[4]),
    .NPU_SLICE_0_TOP_TO_BASE5(NPU_SLICE_0_TOP_TO_BASE[5]),
    .NPU_SLICE_0_TOP_TO_BASE6(NPU_SLICE_0_TOP_TO_BASE[6]),
    .NPU_SLICE_0_TOP_TO_BASE7(NPU_SLICE_0_TOP_TO_BASE[7])
);

NPU_SLICE_DATA_SRAM_BEL Inst_ST_NPU_SLICE_DATA_SRAM_BEL (
    .FAB_ACT_ADDR({FAB_ACT_ADDR8, FAB_ACT_ADDR7, FAB_ACT_ADDR6, FAB_ACT_ADDR5, FAB_ACT_ADDR4, FAB_ACT_ADDR3, FAB_ACT_ADDR2, FAB_ACT_ADDR1, FAB_ACT_ADDR0}),
    .FAB_ACT_WDATA({FAB_ACT_WDATA7, FAB_ACT_WDATA6, FAB_ACT_WDATA5, FAB_ACT_WDATA4, FAB_ACT_WDATA3, FAB_ACT_WDATA2, FAB_ACT_WDATA1, FAB_ACT_WDATA0}),
    .FAB_ACT_RDATA({FAB_ACT_RDATA7, FAB_ACT_RDATA6, FAB_ACT_RDATA5, FAB_ACT_RDATA4, FAB_ACT_RDATA3, FAB_ACT_RDATA2, FAB_ACT_RDATA1, FAB_ACT_RDATA0}),
    .FAB_ACT_WE(FAB_ACT_WE),
    .FAB_WEIGHT_IN({FAB_WEIGHT_IN7, FAB_WEIGHT_IN6, FAB_WEIGHT_IN5, FAB_WEIGHT_IN4, FAB_WEIGHT_IN3, FAB_WEIGHT_IN2, FAB_WEIGHT_IN1, FAB_WEIGHT_IN0}),
    .FAB_WEIGHT_SHIFT_EN(FAB_WEIGHT_SHIFT_EN),
    .FAB_XBAR_SEL({FAB_XBAR_SEL3, FAB_XBAR_SEL2, FAB_XBAR_SEL1, FAB_XBAR_SEL0}),
    .FAB_OUT_ACT({FAB_OUT_ACT7, FAB_OUT_ACT6, FAB_OUT_ACT5, FAB_OUT_ACT4, FAB_OUT_ACT3, FAB_OUT_ACT2, FAB_OUT_ACT1, FAB_OUT_ACT0}),
    .NPU_ACT_ADDR({NPU_ACT_ADDR8, NPU_ACT_ADDR7, NPU_ACT_ADDR6, NPU_ACT_ADDR5, NPU_ACT_ADDR4, NPU_ACT_ADDR3, NPU_ACT_ADDR2, NPU_ACT_ADDR1, NPU_ACT_ADDR0}),
    .NPU_ACT_WDATA({NPU_ACT_WDATA7, NPU_ACT_WDATA6, NPU_ACT_WDATA5, NPU_ACT_WDATA4, NPU_ACT_WDATA3, NPU_ACT_WDATA2, NPU_ACT_WDATA1, NPU_ACT_WDATA0}),
    .NPU_ACT_RDATA({NPU_ACT_RDATA7, NPU_ACT_RDATA6, NPU_ACT_RDATA5, NPU_ACT_RDATA4, NPU_ACT_RDATA3, NPU_ACT_RDATA2, NPU_ACT_RDATA1, NPU_ACT_RDATA0}),
    .NPU_ACT_WE(NPU_ACT_WE),
    .NPU_WEIGHT_IN({NPU_WEIGHT_IN7, NPU_WEIGHT_IN6, NPU_WEIGHT_IN5, NPU_WEIGHT_IN4, NPU_WEIGHT_IN3, NPU_WEIGHT_IN2, NPU_WEIGHT_IN1, NPU_WEIGHT_IN0}),
    .NPU_WEIGHT_SHIFT_EN(NPU_WEIGHT_SHIFT_EN),
    .NPU_XBAR_SEL({NPU_XBAR_SEL3, NPU_XBAR_SEL2, NPU_XBAR_SEL1, NPU_XBAR_SEL0}),
    .NPU_OUT_ACT({NPU_OUT_ACT7, NPU_OUT_ACT6, NPU_OUT_ACT5, NPU_OUT_ACT4, NPU_OUT_ACT3, NPU_OUT_ACT2, NPU_OUT_ACT1, NPU_OUT_ACT0}),
    .UserCLK(Tile_X0Y1_UserCLK),
    .ConfigBits(ST_ConfigBits[6-1:0])
);

endmodule