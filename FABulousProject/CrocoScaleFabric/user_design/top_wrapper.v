`timescale 1ns / 1ps

/* ===============================================================================================
 * File: FABulousProject/CrocoScaleFabric/user_design/top_wrapper.v
 * Description:
 *   Comprehensive FABulous bitstream top-level wrapper for the CrocoScale SoC eFPGA fabric.
 *   Instantiates ALL physical boundary BELs across the complete 12 x 12 grid:
 *
 * Fabric Geometry Summary (12 x 12 grid, X=0..11, Y=0..11):
 *   - WEST  (X=0):  AXI_M_BEL (X0Y6/X0Y1) + AXIL_S_BEL (X0Y10/X0Y7)
 *   - EAST  (X=11): 2x RAM_IO tiles (X11Y2, X11Y1: 14 OutPass4 + 8 InPass4 BELs)
 *                   8x NPU_ACT_ROW_BEL (X11Y10 down to X11Y3, Rows 0 to 7)
 *   - NORTH (Y=0):  6x N_IO tiles (X1Y0..X6Y0, UIO_TOP_: 120 FIN + 120 FOUT pins)
 *                   2x NPU_PSUM_PORT_BEL (X7Y0 Port A, X9Y0 Port B)
 *   - SOUTH (Y=11): 10x S_IO tiles (X1Y11..X10Y11, UIO_BOT_: 200 FIN + 200 FOUT pins)
 *
 * Wire Renaming & Soft-Logic Alignment:
 *   - RAM_IO FAB2RAM_D wires mapped directly into npu_crossbar_sel [7:0][3:0].
 *   - RAM_IO FAB2RAM_C/A wires mapped to NPU control signals.
 *   - North & South UIO buses cleanly partitioned and routed to soft logic, with all
 *     remaining pins exposed on buses for seamless expansion.
 * =============================================================================================== */

module top_wrapper;

    // ========================================================================
    // 0. Global Clock
    // ========================================================================
    wire clk;
    (* keep *) Global_Clock clk_inst (.CLK(clk));


    // ========================================================================
    // 1. WEST EDGE (X=0): AXI-Lite Slave & AXI-Full Master
    // ========================================================================
    // AXI4-Lite Slave Wires (from SoC Master)
    wire [9:0]  s_axil_awaddr; wire s_axil_awvalid; wire s_axil_awready;
    wire [31:0] s_axil_wdata;  wire [3:0] s_axil_wstrb; wire s_axil_wvalid; wire s_axil_wready;
    wire [1:0]  s_axil_bresp;  wire s_axil_bvalid;  wire s_axil_bready;
    wire [9:0]  s_axil_araddr; wire s_axil_arvalid; wire s_axil_arready;
    wire [31:0] s_axil_rdata;  wire [1:0] s_axil_rresp; wire s_axil_rvalid; wire s_axil_rready;

    // AXI4 Full Master Wires (to SoC Slave RAM)
    wire [31:0] m_axi_awaddr;  wire [7:0] m_axi_awlen;   wire [2:0] m_axi_awsize; wire [1:0] m_axi_awburst; wire m_axi_awvalid; wire m_axi_awready;
    wire [31:0] m_axi_wdata;   wire [3:0] m_axi_wstrb;   wire m_axi_wlast;        wire m_axi_wvalid;        wire m_axi_wready;
    wire [1:0]  m_axi_bresp;   wire m_axi_bvalid;  wire m_axi_bready;
    wire [31:0] m_axi_araddr;  wire [7:0] m_axi_arlen;   wire [2:0] m_axi_arsize; wire [1:0] m_axi_arburst; wire m_axi_arvalid; wire m_axi_arready;
    wire [31:0] m_axi_rdata;   wire [1:0] m_axi_rresp;   wire m_axi_rlast;        wire m_axi_rvalid;        wire m_axi_rready;

    // AXIL_S_BEL placed on West Supertile (Anchor X0Y10 / AXIL_S_IO_W_0)
    (* keep, BEL="X0Y10.AXIL_S_" *) AXIL_S_BEL axil_s_bel_inst (
        .FAB_AWADDR0(s_axil_awaddr[0]), .FAB_AWADDR1(s_axil_awaddr[1]), .FAB_AWADDR2(s_axil_awaddr[2]), .FAB_AWADDR3(s_axil_awaddr[3]),
        .FAB_AWADDR4(s_axil_awaddr[4]), .FAB_AWADDR5(s_axil_awaddr[5]), .FAB_AWADDR6(s_axil_awaddr[6]), .FAB_AWADDR7(s_axil_awaddr[7]),
        .FAB_AWADDR8(s_axil_awaddr[8]), .FAB_AWADDR9(s_axil_awaddr[9]), .FAB_AWVALID(s_axil_awvalid),   .FAB_AWREADY(s_axil_awready),
        .FAB_WDATA0(s_axil_wdata[0]),   .FAB_WDATA1(s_axil_wdata[1]),   .FAB_WDATA2(s_axil_wdata[2]),   .FAB_WDATA3(s_axil_wdata[3]),
        .FAB_WDATA4(s_axil_wdata[4]),   .FAB_WDATA5(s_axil_wdata[5]),   .FAB_WDATA6(s_axil_wdata[6]),   .FAB_WDATA7(s_axil_wdata[7]),
        .FAB_WDATA8(s_axil_wdata[8]),   .FAB_WDATA9(s_axil_wdata[9]),   .FAB_WDATA10(s_axil_wdata[10]), .FAB_WDATA11(s_axil_wdata[11]),
        .FAB_WDATA12(s_axil_wdata[12]), .FAB_WDATA13(s_axil_wdata[13]), .FAB_WDATA14(s_axil_wdata[14]), .FAB_WDATA15(s_axil_wdata[15]),
        .FAB_WDATA16(s_axil_wdata[16]), .FAB_WDATA17(s_axil_wdata[17]), .FAB_WDATA18(s_axil_wdata[18]), .FAB_WDATA19(s_axil_wdata[19]),
        .FAB_WDATA20(s_axil_wdata[20]), .FAB_WDATA21(s_axil_wdata[21]), .FAB_WDATA22(s_axil_wdata[22]), .FAB_WDATA23(s_axil_wdata[23]),
        .FAB_WDATA24(s_axil_wdata[24]), .FAB_WDATA25(s_axil_wdata[25]), .FAB_WDATA26(s_axil_wdata[26]), .FAB_WDATA27(s_axil_wdata[27]),
        .FAB_WDATA28(s_axil_wdata[28]), .FAB_WDATA29(s_axil_wdata[29]), .FAB_WDATA30(s_axil_wdata[30]), .FAB_WDATA31(s_axil_wdata[31]),
        .FAB_WSTRB0(s_axil_wstrb[0]),   .FAB_WSTRB1(s_axil_wstrb[1]),   .FAB_WSTRB2(s_axil_wstrb[2]),   .FAB_WSTRB3(s_axil_wstrb[3]),
        .FAB_WVALID(s_axil_wvalid),     .FAB_WREADY(s_axil_wready),
        .FAB_BRESP0(s_axil_bresp[0]),   .FAB_BRESP1(s_axil_bresp[1]),   .FAB_BVALID(s_axil_bvalid),     .FAB_BREADY(s_axil_bready),
        .FAB_ARADDR0(s_axil_araddr[0]), .FAB_ARADDR1(s_axil_araddr[1]), .FAB_ARADDR2(s_axil_araddr[2]), .FAB_ARADDR3(s_axil_araddr[3]),
        .FAB_ARADDR4(s_axil_araddr[4]), .FAB_ARADDR5(s_axil_araddr[5]), .FAB_ARADDR6(s_axil_araddr[6]), .FAB_ARADDR7(s_axil_araddr[7]),
        .FAB_ARADDR8(s_axil_araddr[8]), .FAB_ARADDR9(s_axil_araddr[9]), .FAB_ARVALID(s_axil_arvalid),   .FAB_ARREADY(s_axil_arready),
        .FAB_RDATA0(s_axil_rdata[0]),   .FAB_RDATA1(s_axil_rdata[1]),   .FAB_RDATA2(s_axil_rdata[2]),   .FAB_RDATA3(s_axil_rdata[3]),
        .FAB_RDATA4(s_axil_rdata[4]),   .FAB_RDATA5(s_axil_rdata[5]),   .FAB_RDATA6(s_axil_rdata[6]),   .FAB_RDATA7(s_axil_rdata[7]),
        .FAB_RDATA8(s_axil_rdata[8]),   .FAB_RDATA9(s_axil_rdata[9]),   .FAB_RDATA10(s_axil_rdata[10]), .FAB_RDATA11(s_axil_rdata[11]),
        .FAB_RDATA12(s_axil_rdata[12]), .FAB_RDATA13(s_axil_rdata[13]), .FAB_RDATA14(s_axil_rdata[14]), .FAB_RDATA15(s_axil_rdata[15]),
        .FAB_RDATA16(s_axil_rdata[16]), .FAB_RDATA17(s_axil_rdata[17]), .FAB_RDATA18(s_axil_rdata[18]), .FAB_RDATA19(s_axil_rdata[19]),
        .FAB_RDATA20(s_axil_rdata[20]), .FAB_RDATA21(s_axil_rdata[21]), .FAB_RDATA22(s_axil_rdata[22]), .FAB_RDATA23(s_axil_rdata[23]),
        .FAB_RDATA24(s_axil_rdata[24]), .FAB_RDATA25(s_axil_rdata[25]), .FAB_RDATA26(s_axil_rdata[26]), .FAB_RDATA27(s_axil_rdata[27]),
        .FAB_RDATA28(s_axil_rdata[28]), .FAB_RDATA29(s_axil_rdata[29]), .FAB_RDATA30(s_axil_rdata[30]), .FAB_RDATA31(s_axil_rdata[31]),
        .FAB_RRESP0(s_axil_rresp[0]),   .FAB_RRESP1(s_axil_rresp[1]),   .FAB_RVALID(s_axil_rvalid),     .FAB_RREADY(s_axil_rready)
    );

    // AXI_M_BEL placed on West Supertile (Anchor X0Y6 / AXI_M_IO_W_0)
    (* keep, BEL="X0Y6.AXI_M_" *) AXI_M_BEL axi_m_bel_inst (
        .FAB_AWADDR0(m_axi_awaddr[0]),   .FAB_AWADDR1(m_axi_awaddr[1]),   .FAB_AWADDR2(m_axi_awaddr[2]),   .FAB_AWADDR3(m_axi_awaddr[3]),
        .FAB_AWADDR4(m_axi_awaddr[4]),   .FAB_AWADDR5(m_axi_awaddr[5]),   .FAB_AWADDR6(m_axi_awaddr[6]),   .FAB_AWADDR7(m_axi_awaddr[7]),
        .FAB_AWADDR8(m_axi_awaddr[8]),   .FAB_AWADDR9(m_axi_awaddr[9]),   .FAB_AWADDR10(m_axi_awaddr[10]), .FAB_AWADDR11(m_axi_awaddr[11]),
        .FAB_AWADDR12(m_axi_awaddr[12]), .FAB_AWADDR13(m_axi_awaddr[13]), .FAB_AWADDR14(m_axi_awaddr[14]), .FAB_AWADDR15(m_axi_awaddr[15]),
        .FAB_AWADDR16(m_axi_awaddr[16]), .FAB_AWADDR17(m_axi_awaddr[17]), .FAB_AWADDR18(m_axi_awaddr[18]), .FAB_AWADDR19(m_axi_awaddr[19]),
        .FAB_AWADDR20(m_axi_awaddr[20]), .FAB_AWADDR21(m_axi_awaddr[21]), .FAB_AWADDR22(m_axi_awaddr[22]), .FAB_AWADDR23(m_axi_awaddr[23]),
        .FAB_AWADDR24(m_axi_awaddr[24]), .FAB_AWADDR25(m_axi_awaddr[25]), .FAB_AWADDR26(m_axi_awaddr[26]), .FAB_AWADDR27(m_axi_awaddr[27]),
        .FAB_AWADDR28(m_axi_awaddr[28]), .FAB_AWADDR29(m_axi_awaddr[29]), .FAB_AWADDR30(m_axi_awaddr[30]), .FAB_AWADDR31(m_axi_awaddr[31]),
        .FAB_AWLEN0(m_axi_awlen[0]),     .FAB_AWLEN1(m_axi_awlen[1]),     .FAB_AWLEN2(m_axi_awlen[2]),     .FAB_AWLEN3(m_axi_awlen[3]),
        .FAB_AWLEN4(m_axi_awlen[4]),     .FAB_AWLEN5(m_axi_awlen[5]),     .FAB_AWLEN6(m_axi_awlen[6]),     .FAB_AWLEN7(m_axi_awlen[7]),
        .FAB_AWSIZE0(m_axi_awsize[0]),   .FAB_AWSIZE1(m_axi_awsize[1]),   .FAB_AWSIZE2(m_axi_awsize[2]),
        .FAB_AWBURST0(m_axi_awburst[0]), .FAB_AWBURST1(m_axi_awburst[1]), .FAB_AWVALID(m_axi_awvalid),     .FAB_AWREADY(m_axi_awready),
        .FAB_WDATA0(m_axi_wdata[0]),     .FAB_WDATA1(m_axi_wdata[1]),     .FAB_WDATA2(m_axi_wdata[2]),     .FAB_WDATA3(m_axi_wdata[3]),
        .FAB_WDATA4(m_axi_wdata[4]),     .FAB_WDATA5(m_axi_wdata[5]),     .FAB_WDATA6(m_axi_wdata[6]),     .FAB_WDATA7(m_axi_wdata[7]),
        .FAB_WDATA8(m_axi_wdata[8]),     .FAB_WDATA9(m_axi_wdata[9]),     .FAB_WDATA10(m_axi_wdata[10]),   .FAB_WDATA11(m_axi_wdata[11]),
        .FAB_WDATA12(m_axi_wdata[12]),   .FAB_WDATA13(m_axi_wdata[13]),   .FAB_WDATA14(m_axi_wdata[14]),   .FAB_WDATA15(m_axi_wdata[15]),
        .FAB_WDATA16(m_axi_wdata[16]),   .FAB_WDATA17(m_axi_wdata[17]),   .FAB_WDATA18(m_axi_wdata[18]),   .FAB_WDATA19(m_axi_wdata[19]),
        .FAB_WDATA20(m_axi_wdata[20]),   .FAB_WDATA21(m_axi_wdata[21]),   .FAB_WDATA22(m_axi_wdata[22]),   .FAB_WDATA23(m_axi_wdata[23]),
        .FAB_WDATA24(m_axi_wdata[24]),   .FAB_WDATA25(m_axi_wdata[25]),   .FAB_WDATA26(m_axi_wdata[26]),   .FAB_WDATA27(m_axi_wdata[27]),
        .FAB_WDATA28(m_axi_wdata[28]),   .FAB_WDATA29(m_axi_wdata[29]),   .FAB_WDATA30(m_axi_wdata[30]),   .FAB_WDATA31(m_axi_wdata[31]),
        .FAB_WSTRB0(m_axi_wstrb[0]),     .FAB_WSTRB1(m_axi_wstrb[1]),     .FAB_WSTRB2(m_axi_wstrb[2]),     .FAB_WSTRB3(m_axi_wstrb[3]),
        .FAB_WLAST(m_axi_wlast),         .FAB_WVALID(m_axi_wvalid),       .FAB_WREADY(m_axi_wready),
        .FAB_BRESP0(m_axi_bresp[0]),     .FAB_BRESP1(m_axi_bresp[1]),     .FAB_BVALID(m_axi_bvalid),       .FAB_BREADY(m_axi_bready),
        .FAB_ARADDR0(m_axi_araddr[0]),   .FAB_ARADDR1(m_axi_araddr[1]),   .FAB_ARADDR2(m_axi_araddr[2]),   .FAB_ARADDR3(m_axi_araddr[3]),
        .FAB_ARADDR4(m_axi_araddr[4]),   .FAB_ARADDR5(m_axi_araddr[5]),   .FAB_ARADDR6(m_axi_araddr[6]),   .FAB_ARADDR7(m_axi_araddr[7]),
        .FAB_ARADDR8(m_axi_araddr[8]),   .FAB_ARADDR9(m_axi_araddr[9]),   .FAB_ARADDR10(m_axi_araddr[10]), .FAB_ARADDR11(m_axi_araddr[11]),
        .FAB_ARADDR12(m_axi_araddr[12]), .FAB_ARADDR13(m_axi_araddr[13]), .FAB_ARADDR14(m_axi_araddr[14]), .FAB_ARADDR15(m_axi_araddr[15]),
        .FAB_ARADDR16(m_axi_araddr[16]), .FAB_ARADDR17(m_axi_araddr[17]), .FAB_ARADDR18(m_axi_araddr[18]), .FAB_ARADDR19(m_axi_araddr[19]),
        .FAB_ARADDR20(m_axi_araddr[20]), .FAB_ARADDR21(m_axi_araddr[21]), .FAB_ARADDR22(m_axi_araddr[22]), .FAB_ARADDR23(m_axi_araddr[23]),
        .FAB_ARADDR24(m_axi_araddr[24]), .FAB_ARADDR25(m_axi_araddr[25]), .FAB_ARADDR26(m_axi_araddr[26]), .FAB_ARADDR27(m_axi_araddr[27]),
        .FAB_ARADDR28(m_axi_araddr[28]), .FAB_ARADDR29(m_axi_araddr[29]), .FAB_ARADDR30(m_axi_araddr[30]), .FAB_ARADDR31(m_axi_araddr[31]),
        .FAB_ARLEN0(m_axi_arlen[0]),     .FAB_ARLEN1(m_axi_arlen[1]),     .FAB_ARLEN2(m_axi_arlen[2]),     .FAB_ARLEN3(m_axi_arlen[3]),
        .FAB_ARLEN4(m_axi_arlen[4]),     .FAB_ARLEN5(m_axi_arlen[5]),     .FAB_ARLEN6(m_axi_arlen[6]),     .FAB_ARLEN7(m_axi_arlen[7]),
        .FAB_ARSIZE0(m_axi_arsize[0]),   .FAB_ARSIZE1(m_axi_arsize[1]),   .FAB_ARSIZE2(m_axi_arsize[2]),
        .FAB_ARBURST0(m_axi_arburst[0]), .FAB_ARBURST1(m_axi_arburst[1]), .FAB_ARVALID(m_axi_arvalid),     .FAB_ARREADY(m_axi_arready),
        .FAB_RDATA0(m_axi_rdata[0]),     .FAB_RDATA1(m_axi_rdata[1]),     .FAB_RDATA2(m_axi_rdata[2]),     .FAB_RDATA3(m_axi_rdata[3]),
        .FAB_RDATA4(m_axi_rdata[4]),     .FAB_RDATA5(m_axi_rdata[5]),     .FAB_RDATA6(m_axi_rdata[6]),     .FAB_RDATA7(m_axi_rdata[7]),
        .FAB_RDATA8(m_axi_rdata[8]),     .FAB_RDATA9(m_axi_rdata[9]),     .FAB_RDATA10(m_axi_rdata[10]),   .FAB_RDATA11(m_axi_rdata[11]),
        .FAB_RDATA12(m_axi_rdata[12]),   .FAB_RDATA13(m_axi_rdata[13]),   .FAB_RDATA14(m_axi_rdata[14]),   .FAB_RDATA15(m_axi_rdata[15]),
        .FAB_RDATA16(m_axi_rdata[16]),   .FAB_RDATA17(m_axi_rdata[17]),   .FAB_RDATA18(m_axi_rdata[18]),   .FAB_RDATA19(m_axi_rdata[19]),
        .FAB_RDATA20(m_axi_rdata[20]),   .FAB_RDATA21(m_axi_rdata[21]),   .FAB_RDATA22(m_axi_rdata[22]),   .FAB_RDATA23(m_axi_rdata[23]),
        .FAB_RDATA24(m_axi_rdata[24]),   .FAB_RDATA25(m_axi_rdata[25]),   .FAB_RDATA26(m_axi_rdata[26]),   .FAB_RDATA27(m_axi_rdata[27]),
        .FAB_RDATA28(m_axi_rdata[28]),   .FAB_RDATA29(m_axi_rdata[29]),   .FAB_RDATA30(m_axi_rdata[30]),   .FAB_RDATA31(m_axi_rdata[31]),
        .FAB_RRESP0(m_axi_rresp[0]),     .FAB_RRESP1(m_axi_rresp[1]),     .FAB_RLAST(m_axi_rlast),         .FAB_RVALID(m_axi_rvalid), .FAB_RREADY(m_axi_rready)
    );


    // ========================================================================
    // 2. EAST EDGE (X=11): RAM_IO (Y=1..2) & NPU_ACT_ROW (Y=3..10)
    // ========================================================================
    // Raw RAM_IO output/input wires
    wire [15:0] ram_a_o;
    wire [7:0]  ram_c_o;
    wire [31:0] ram_d_o;
    wire [31:0] ram_d_i;

    // --- Tile X11Y2: RAM_IO (Upper Bank) ---
    (* keep, BEL="X11Y2.FAB2RAM_C_"  *) OutPass4_frame_config_mux bel_X11Y2_C  (.CLK(clk), .I0(ram_c_o[0]), .I1(ram_c_o[1]), .I2(ram_c_o[2]), .I3(ram_c_o[3]));
    (* keep, BEL="X11Y2.FAB2RAM_A0_" *) OutPass4_frame_config_mux bel_X11Y2_A0 (.CLK(clk), .I0(ram_a_o[0]), .I1(ram_a_o[1]), .I2(ram_a_o[2]), .I3(ram_a_o[3]));
    (* keep, BEL="X11Y2.FAB2RAM_A1_" *) OutPass4_frame_config_mux bel_X11Y2_A1 (.CLK(clk), .I0(ram_a_o[4]), .I1(ram_a_o[5]), .I2(ram_a_o[6]), .I3(ram_a_o[7]));
    (* keep, BEL="X11Y2.FAB2RAM_D0_" *) OutPass4_frame_config_mux bel_X11Y2_D0 (.CLK(clk), .I0(ram_d_o[0]), .I1(ram_d_o[1]), .I2(ram_d_o[2]), .I3(ram_d_o[3]));
    (* keep, BEL="X11Y2.FAB2RAM_D1_" *) OutPass4_frame_config_mux bel_X11Y2_D1 (.CLK(clk), .I0(ram_d_o[4]), .I1(ram_d_o[5]), .I2(ram_d_o[6]), .I3(ram_d_o[7]));
    (* keep, BEL="X11Y2.FAB2RAM_D2_" *) OutPass4_frame_config_mux bel_X11Y2_D2 (.CLK(clk), .I0(ram_d_o[8]), .I1(ram_d_o[9]), .I2(ram_d_o[10]), .I3(ram_d_o[11]));
    (* keep, BEL="X11Y2.FAB2RAM_D3_" *) OutPass4_frame_config_mux bel_X11Y2_D3 (.CLK(clk), .I0(ram_d_o[12]), .I1(ram_d_o[13]), .I2(ram_d_o[14]), .I3(ram_d_o[15]));
    (* keep, BEL="X11Y2.RAM2FAB_D0_" *) InPass4_frame_config_mux  bel_X11Y2_InD0 (.CLK(clk), .O0(ram_d_i[0]), .O1(ram_d_i[1]), .O2(ram_d_i[2]), .O3(ram_d_i[3]));
    (* keep, BEL="X11Y2.RAM2FAB_D1_" *) InPass4_frame_config_mux  bel_X11Y2_InD1 (.CLK(clk), .O0(ram_d_i[4]), .O1(ram_d_i[5]), .O2(ram_d_i[6]), .O3(ram_d_i[7]));
    (* keep, BEL="X11Y2.RAM2FAB_D2_" *) InPass4_frame_config_mux  bel_X11Y2_InD2 (.CLK(clk), .O0(ram_d_i[8]), .O1(ram_d_i[9]), .O2(ram_d_i[10]), .O3(ram_d_i[11]));
    (* keep, BEL="X11Y2.RAM2FAB_D3_" *) InPass4_frame_config_mux  bel_X11Y2_InD3 (.CLK(clk), .O0(ram_d_i[12]), .O1(ram_d_i[13]), .O2(ram_d_i[14]), .O3(ram_d_i[15]));

    // --- Tile X11Y1: RAM_IO (Lower Bank) ---
    (* keep, BEL="X11Y1.FAB2RAM_C_"  *) OutPass4_frame_config_mux bel_X11Y1_C  (.CLK(clk), .I0(ram_c_o[4]), .I1(ram_c_o[5]), .I2(ram_c_o[6]), .I3(ram_c_o[7]));
    (* keep, BEL="X11Y1.FAB2RAM_A0_" *) OutPass4_frame_config_mux bel_X11Y1_A0 (.CLK(clk), .I0(ram_a_o[8]), .I1(ram_a_o[9]), .I2(ram_a_o[10]), .I3(ram_a_o[11]));
    (* keep, BEL="X11Y1.FAB2RAM_A1_" *) OutPass4_frame_config_mux bel_X11Y1_A1 (.CLK(clk), .I0(ram_a_o[12]), .I1(ram_a_o[13]), .I2(ram_a_o[14]), .I3(ram_a_o[15]));
    (* keep, BEL="X11Y1.FAB2RAM_D0_" *) OutPass4_frame_config_mux bel_X11Y1_D0 (.CLK(clk), .I0(ram_d_o[16]), .I1(ram_d_o[17]), .I2(ram_d_o[18]), .I3(ram_d_o[19]));
    (* keep, BEL="X11Y1.FAB2RAM_D1_" *) OutPass4_frame_config_mux bel_X11Y1_D1 (.CLK(clk), .I0(ram_d_o[20]), .I1(ram_d_o[21]), .I2(ram_d_o[22]), .I3(ram_d_o[23]));
    (* keep, BEL="X11Y1.FAB2RAM_D2_" *) OutPass4_frame_config_mux bel_X11Y1_D2 (.CLK(clk), .I0(ram_d_o[24]), .I1(ram_d_o[25]), .I2(ram_d_o[26]), .I3(ram_d_o[27]));
    (* keep, BEL="X11Y1.FAB2RAM_D3_" *) OutPass4_frame_config_mux bel_X11Y1_D3 (.CLK(clk), .I0(ram_d_o[28]), .I1(ram_d_o[29]), .I2(ram_d_o[30]), .I3(ram_d_o[31]));
    (* keep, BEL="X11Y1.RAM2FAB_D0_" *) InPass4_frame_config_mux  bel_X11Y1_InD0 (.CLK(clk), .O0(ram_d_i[16]), .O1(ram_d_i[17]), .O2(ram_d_i[18]), .O3(ram_d_i[19]));
    (* keep, BEL="X11Y1.RAM2FAB_D1_" *) InPass4_frame_config_mux  bel_X11Y1_InD1 (.CLK(clk), .O0(ram_d_i[20]), .O1(ram_d_i[21]), .O2(ram_d_i[22]), .O3(ram_d_i[23]));
    (* keep, BEL="X11Y1.RAM2FAB_D2_" *) InPass4_frame_config_mux  bel_X11Y1_InD2 (.CLK(clk), .O0(ram_d_i[24]), .O1(ram_d_i[25]), .O2(ram_d_i[26]), .O3(ram_d_i[27]));
    (* keep, BEL="X11Y1.RAM2FAB_D3_" *) InPass4_frame_config_mux  bel_X11Y1_InD3 (.CLK(clk), .O0(ram_d_i[28]), .O1(ram_d_i[29]), .O2(ram_d_i[30]), .O3(ram_d_i[31]));

    // --- Tiles X11Y10 down to X11Y3: NPU_ACT_ROW (Rows 0 to 7) ---
    wire [7:0]       npu_act_we;
    wire [7:0][8:0]  npu_act_addr;
    wire [7:0][7:0]  npu_act_wdata;
    wire [7:0][7:0]  npu_act_rdata;
    wire [7:0][7:0]  npu_weight_in;

    // Row 0 (Tile X11Y10)
    (* keep, BEL="X11Y10." *) NPU_ACT_ROW_BEL bel_act_row0 (
        .FAB_ACT_WE(npu_act_we[0]),
        .FAB_ACT_ADDR0(npu_act_addr[0][0]), .FAB_ACT_ADDR1(npu_act_addr[0][1]), .FAB_ACT_ADDR2(npu_act_addr[0][2]),
        .FAB_ACT_ADDR3(npu_act_addr[0][3]), .FAB_ACT_ADDR4(npu_act_addr[0][4]), .FAB_ACT_ADDR5(npu_act_addr[0][5]),
        .FAB_ACT_ADDR6(npu_act_addr[0][6]), .FAB_ACT_ADDR7(npu_act_addr[0][7]), .FAB_ACT_ADDR8(npu_act_addr[0][8]),
        .FAB_ACT_WDATA0(npu_act_wdata[0][0]), .FAB_ACT_WDATA1(npu_act_wdata[0][1]), .FAB_ACT_WDATA2(npu_act_wdata[0][2]), .FAB_ACT_WDATA3(npu_act_wdata[0][3]),
        .FAB_ACT_WDATA4(npu_act_wdata[0][4]), .FAB_ACT_WDATA5(npu_act_wdata[0][5]), .FAB_ACT_WDATA6(npu_act_wdata[0][6]), .FAB_ACT_WDATA7(npu_act_wdata[0][7]),
        .FAB_ACT_RDATA0(npu_act_rdata[0][0]), .FAB_ACT_RDATA1(npu_act_rdata[0][1]), .FAB_ACT_RDATA2(npu_act_rdata[0][2]), .FAB_ACT_RDATA3(npu_act_rdata[0][3]),
        .FAB_ACT_RDATA4(npu_act_rdata[0][4]), .FAB_ACT_RDATA5(npu_act_rdata[0][5]), .FAB_ACT_RDATA6(npu_act_rdata[0][6]), .FAB_ACT_RDATA7(npu_act_rdata[0][7]),
        .FAB_WEIGHT_IN0(npu_weight_in[0][0]), .FAB_WEIGHT_IN1(npu_weight_in[0][1]), .FAB_WEIGHT_IN2(npu_weight_in[0][2]), .FAB_WEIGHT_IN3(npu_weight_in[0][3]),
        .FAB_WEIGHT_IN4(npu_weight_in[0][4]), .FAB_WEIGHT_IN5(npu_weight_in[0][5]), .FAB_WEIGHT_IN6(npu_weight_in[0][6]), .FAB_WEIGHT_IN7(npu_weight_in[0][7])
    );

    // Row 1 (Tile X11Y9)
    (* keep, BEL="X11Y9." *) NPU_ACT_ROW_BEL bel_act_row1 (
        .FAB_ACT_WE(npu_act_we[1]),
        .FAB_ACT_ADDR0(npu_act_addr[1][0]), .FAB_ACT_ADDR1(npu_act_addr[1][1]), .FAB_ACT_ADDR2(npu_act_addr[1][2]),
        .FAB_ACT_ADDR3(npu_act_addr[1][3]), .FAB_ACT_ADDR4(npu_act_addr[1][4]), .FAB_ACT_ADDR5(npu_act_addr[1][5]),
        .FAB_ACT_ADDR6(npu_act_addr[1][6]), .FAB_ACT_ADDR7(npu_act_addr[1][7]), .FAB_ACT_ADDR8(npu_act_addr[1][8]),
        .FAB_ACT_WDATA0(npu_act_wdata[1][0]), .FAB_ACT_WDATA1(npu_act_wdata[1][1]), .FAB_ACT_WDATA2(npu_act_wdata[1][2]), .FAB_ACT_WDATA3(npu_act_wdata[1][3]),
        .FAB_ACT_WDATA4(npu_act_wdata[1][4]), .FAB_ACT_WDATA5(npu_act_wdata[1][5]), .FAB_ACT_WDATA6(npu_act_wdata[1][6]), .FAB_ACT_WDATA7(npu_act_wdata[1][7]),
        .FAB_ACT_RDATA0(npu_act_rdata[1][0]), .FAB_ACT_RDATA1(npu_act_rdata[1][1]), .FAB_ACT_RDATA2(npu_act_rdata[1][2]), .FAB_ACT_RDATA3(npu_act_rdata[1][3]),
        .FAB_ACT_RDATA4(npu_act_rdata[1][4]), .FAB_ACT_RDATA5(npu_act_rdata[1][5]), .FAB_ACT_RDATA6(npu_act_rdata[1][6]), .FAB_ACT_RDATA7(npu_act_rdata[1][7]),
        .FAB_WEIGHT_IN0(npu_weight_in[1][0]), .FAB_WEIGHT_IN1(npu_weight_in[1][1]), .FAB_WEIGHT_IN2(npu_weight_in[1][2]), .FAB_WEIGHT_IN3(npu_weight_in[1][3]),
        .FAB_WEIGHT_IN4(npu_weight_in[1][4]), .FAB_WEIGHT_IN5(npu_weight_in[1][5]), .FAB_WEIGHT_IN6(npu_weight_in[1][6]), .FAB_WEIGHT_IN7(npu_weight_in[1][7])
    );

    // Row 2 (Tile X11Y8)
    (* keep, BEL="X11Y8." *) NPU_ACT_ROW_BEL bel_act_row2 (
        .FAB_ACT_WE(npu_act_we[2]),
        .FAB_ACT_ADDR0(npu_act_addr[2][0]), .FAB_ACT_ADDR1(npu_act_addr[2][1]), .FAB_ACT_ADDR2(npu_act_addr[2][2]),
        .FAB_ACT_ADDR3(npu_act_addr[2][3]), .FAB_ACT_ADDR4(npu_act_addr[2][4]), .FAB_ACT_ADDR5(npu_act_addr[2][5]),
        .FAB_ACT_ADDR6(npu_act_addr[2][6]), .FAB_ACT_ADDR7(npu_act_addr[2][7]), .FAB_ACT_ADDR8(npu_act_addr[2][8]),
        .FAB_ACT_WDATA0(npu_act_wdata[2][0]), .FAB_ACT_WDATA1(npu_act_wdata[2][1]), .FAB_ACT_WDATA2(npu_act_wdata[2][2]), .FAB_ACT_WDATA3(npu_act_wdata[2][3]),
        .FAB_ACT_WDATA4(npu_act_wdata[2][4]), .FAB_ACT_WDATA5(npu_act_wdata[2][5]), .FAB_ACT_WDATA6(npu_act_wdata[2][6]), .FAB_ACT_WDATA7(npu_act_wdata[2][7]),
        .FAB_ACT_RDATA0(npu_act_rdata[2][0]), .FAB_ACT_RDATA1(npu_act_rdata[2][1]), .FAB_ACT_RDATA2(npu_act_rdata[2][2]), .FAB_ACT_RDATA3(npu_act_rdata[2][3]),
        .FAB_ACT_RDATA4(npu_act_rdata[2][4]), .FAB_ACT_RDATA5(npu_act_rdata[2][5]), .FAB_ACT_RDATA6(npu_act_rdata[2][6]), .FAB_ACT_RDATA7(npu_act_rdata[2][7]),
        .FAB_WEIGHT_IN0(npu_weight_in[2][0]), .FAB_WEIGHT_IN1(npu_weight_in[2][1]), .FAB_WEIGHT_IN2(npu_weight_in[2][2]), .FAB_WEIGHT_IN3(npu_weight_in[2][3]),
        .FAB_WEIGHT_IN4(npu_weight_in[2][4]), .FAB_WEIGHT_IN5(npu_weight_in[2][5]), .FAB_WEIGHT_IN6(npu_weight_in[2][6]), .FAB_WEIGHT_IN7(npu_weight_in[2][7])
    );

    // Row 3 (Tile X11Y7)
    (* keep, BEL="X11Y7." *) NPU_ACT_ROW_BEL bel_act_row3 (
        .FAB_ACT_WE(npu_act_we[3]),
        .FAB_ACT_ADDR0(npu_act_addr[3][0]), .FAB_ACT_ADDR1(npu_act_addr[3][1]), .FAB_ACT_ADDR2(npu_act_addr[3][2]),
        .FAB_ACT_ADDR3(npu_act_addr[3][3]), .FAB_ACT_ADDR4(npu_act_addr[3][4]), .FAB_ACT_ADDR5(npu_act_addr[3][5]),
        .FAB_ACT_ADDR6(npu_act_addr[3][6]), .FAB_ACT_ADDR7(npu_act_addr[3][7]), .FAB_ACT_ADDR8(npu_act_addr[3][8]),
        .FAB_ACT_WDATA0(npu_act_wdata[3][0]), .FAB_ACT_WDATA1(npu_act_wdata[3][1]), .FAB_ACT_WDATA2(npu_act_wdata[3][2]), .FAB_ACT_WDATA3(npu_act_wdata[3][3]),
        .FAB_ACT_WDATA4(npu_act_wdata[3][4]), .FAB_ACT_WDATA5(npu_act_wdata[3][5]), .FAB_ACT_WDATA6(npu_act_wdata[3][6]), .FAB_ACT_WDATA7(npu_act_wdata[3][7]),
        .FAB_ACT_RDATA0(npu_act_rdata[3][0]), .FAB_ACT_RDATA1(npu_act_rdata[3][1]), .FAB_ACT_RDATA2(npu_act_rdata[3][2]), .FAB_ACT_RDATA3(npu_act_rdata[3][3]),
        .FAB_ACT_RDATA4(npu_act_rdata[3][4]), .FAB_ACT_RDATA5(npu_act_rdata[3][5]), .FAB_ACT_RDATA6(npu_act_rdata[3][6]), .FAB_ACT_RDATA7(npu_act_rdata[3][7]),
        .FAB_WEIGHT_IN0(npu_weight_in[3][0]), .FAB_WEIGHT_IN1(npu_weight_in[3][1]), .FAB_WEIGHT_IN2(npu_weight_in[3][2]), .FAB_WEIGHT_IN3(npu_weight_in[3][3]),
        .FAB_WEIGHT_IN4(npu_weight_in[3][4]), .FAB_WEIGHT_IN5(npu_weight_in[3][5]), .FAB_WEIGHT_IN6(npu_weight_in[3][6]), .FAB_WEIGHT_IN7(npu_weight_in[3][7])
    );

    // Row 4 (Tile X11Y6)
    (* keep, BEL="X11Y6." *) NPU_ACT_ROW_BEL bel_act_row4 (
        .FAB_ACT_WE(npu_act_we[4]),
        .FAB_ACT_ADDR0(npu_act_addr[4][0]), .FAB_ACT_ADDR1(npu_act_addr[4][1]), .FAB_ACT_ADDR2(npu_act_addr[4][2]),
        .FAB_ACT_ADDR3(npu_act_addr[4][3]), .FAB_ACT_ADDR4(npu_act_addr[4][4]), .FAB_ACT_ADDR5(npu_act_addr[4][5]),
        .FAB_ACT_ADDR6(npu_act_addr[4][6]), .FAB_ACT_ADDR7(npu_act_addr[4][7]), .FAB_ACT_ADDR8(npu_act_addr[4][8]),
        .FAB_ACT_WDATA0(npu_act_wdata[4][0]), .FAB_ACT_WDATA1(npu_act_wdata[4][1]), .FAB_ACT_WDATA2(npu_act_wdata[4][2]), .FAB_ACT_WDATA3(npu_act_wdata[4][3]),
        .FAB_ACT_WDATA4(npu_act_wdata[4][4]), .FAB_ACT_WDATA5(npu_act_wdata[4][5]), .FAB_ACT_WDATA6(npu_act_wdata[4][6]), .FAB_ACT_WDATA7(npu_act_wdata[4][7]),
        .FAB_ACT_RDATA0(npu_act_rdata[4][0]), .FAB_ACT_RDATA1(npu_act_rdata[4][1]), .FAB_ACT_RDATA2(npu_act_rdata[4][2]), .FAB_ACT_RDATA3(npu_act_rdata[4][3]),
        .FAB_ACT_RDATA4(npu_act_rdata[4][4]), .FAB_ACT_RDATA5(npu_act_rdata[4][5]), .FAB_ACT_RDATA6(npu_act_rdata[4][6]), .FAB_ACT_RDATA7(npu_act_rdata[4][7]),
        .FAB_WEIGHT_IN0(npu_weight_in[4][0]), .FAB_WEIGHT_IN1(npu_weight_in[4][1]), .FAB_WEIGHT_IN2(npu_weight_in[4][2]), .FAB_WEIGHT_IN3(npu_weight_in[4][3]),
        .FAB_WEIGHT_IN4(npu_weight_in[4][4]), .FAB_WEIGHT_IN5(npu_weight_in[4][5]), .FAB_WEIGHT_IN6(npu_weight_in[4][6]), .FAB_WEIGHT_IN7(npu_weight_in[4][7])
    );

    // Row 5 (Tile X11Y5)
    (* keep, BEL="X11Y5." *) NPU_ACT_ROW_BEL bel_act_row5 (
        .FAB_ACT_WE(npu_act_we[5]),
        .FAB_ACT_ADDR0(npu_act_addr[5][0]), .FAB_ACT_ADDR1(npu_act_addr[5][1]), .FAB_ACT_ADDR2(npu_act_addr[5][2]),
        .FAB_ACT_ADDR3(npu_act_addr[5][3]), .FAB_ACT_ADDR4(npu_act_addr[5][4]), .FAB_ACT_ADDR5(npu_act_addr[5][5]),
        .FAB_ACT_ADDR6(npu_act_addr[5][6]), .FAB_ACT_ADDR7(npu_act_addr[5][7]), .FAB_ACT_ADDR8(npu_act_addr[5][8]),
        .FAB_ACT_WDATA0(npu_act_wdata[5][0]), .FAB_ACT_WDATA1(npu_act_wdata[5][1]), .FAB_ACT_WDATA2(npu_act_wdata[5][2]), .FAB_ACT_WDATA3(npu_act_wdata[5][3]),
        .FAB_ACT_WDATA4(npu_act_wdata[5][4]), .FAB_ACT_WDATA5(npu_act_wdata[5][5]), .FAB_ACT_WDATA6(npu_act_wdata[5][6]), .FAB_ACT_WDATA7(npu_act_wdata[5][7]),
        .FAB_ACT_RDATA0(npu_act_rdata[5][0]), .FAB_ACT_RDATA1(npu_act_rdata[5][1]), .FAB_ACT_RDATA2(npu_act_rdata[5][2]), .FAB_ACT_RDATA3(npu_act_rdata[5][3]),
        .FAB_ACT_RDATA4(npu_act_rdata[5][4]), .FAB_ACT_RDATA5(npu_act_rdata[5][5]), .FAB_ACT_RDATA6(npu_act_rdata[5][6]), .FAB_ACT_RDATA7(npu_act_rdata[5][7]),
        .FAB_WEIGHT_IN0(npu_weight_in[5][0]), .FAB_WEIGHT_IN1(npu_weight_in[5][1]), .FAB_WEIGHT_IN2(npu_weight_in[5][2]), .FAB_WEIGHT_IN3(npu_weight_in[5][3]),
        .FAB_WEIGHT_IN4(npu_weight_in[5][4]), .FAB_WEIGHT_IN5(npu_weight_in[5][5]), .FAB_WEIGHT_IN6(npu_weight_in[5][6]), .FAB_WEIGHT_IN7(npu_weight_in[5][7])
    );

    // Row 6 (Tile X11Y4)
    (* keep, BEL="X11Y4." *) NPU_ACT_ROW_BEL bel_act_row6 (
        .FAB_ACT_WE(npu_act_we[6]),
        .FAB_ACT_ADDR0(npu_act_addr[6][0]), .FAB_ACT_ADDR1(npu_act_addr[6][1]), .FAB_ACT_ADDR2(npu_act_addr[6][2]),
        .FAB_ACT_ADDR3(npu_act_addr[6][3]), .FAB_ACT_ADDR4(npu_act_addr[6][4]), .FAB_ACT_ADDR5(npu_act_addr[6][5]),
        .FAB_ACT_ADDR6(npu_act_addr[6][6]), .FAB_ACT_ADDR7(npu_act_addr[6][7]), .FAB_ACT_ADDR8(npu_act_addr[6][8]),
        .FAB_ACT_WDATA0(npu_act_wdata[6][0]), .FAB_ACT_WDATA1(npu_act_wdata[6][1]), .FAB_ACT_WDATA2(npu_act_wdata[6][2]), .FAB_ACT_WDATA3(npu_act_wdata[6][3]),
        .FAB_ACT_WDATA4(npu_act_wdata[6][4]), .FAB_ACT_WDATA5(npu_act_wdata[6][5]), .FAB_ACT_WDATA6(npu_act_wdata[6][6]), .FAB_ACT_WDATA7(npu_act_wdata[6][7]),
        .FAB_ACT_RDATA0(npu_act_rdata[6][0]), .FAB_ACT_RDATA1(npu_act_rdata[6][1]), .FAB_ACT_RDATA2(npu_act_rdata[6][2]), .FAB_ACT_RDATA3(npu_act_rdata[6][3]),
        .FAB_ACT_RDATA4(npu_act_rdata[6][4]), .FAB_ACT_RDATA5(npu_act_rdata[6][5]), .FAB_ACT_RDATA6(npu_act_rdata[6][6]), .FAB_ACT_RDATA7(npu_act_rdata[6][7]),
        .FAB_WEIGHT_IN0(npu_weight_in[6][0]), .FAB_WEIGHT_IN1(npu_weight_in[6][1]), .FAB_WEIGHT_IN2(npu_weight_in[6][2]), .FAB_WEIGHT_IN3(npu_weight_in[6][3]),
        .FAB_WEIGHT_IN4(npu_weight_in[6][4]), .FAB_WEIGHT_IN5(npu_weight_in[6][5]), .FAB_WEIGHT_IN6(npu_weight_in[6][6]), .FAB_WEIGHT_IN7(npu_weight_in[6][7])
    );

    // Row 7 (Tile X11Y3)
    (* keep, BEL="X11Y3." *) NPU_ACT_ROW_BEL bel_act_row7 (
        .FAB_ACT_WE(npu_act_we[7]),
        .FAB_ACT_ADDR0(npu_act_addr[7][0]), .FAB_ACT_ADDR1(npu_act_addr[7][1]), .FAB_ACT_ADDR2(npu_act_addr[7][2]),
        .FAB_ACT_ADDR3(npu_act_addr[7][3]), .FAB_ACT_ADDR4(npu_act_addr[7][4]), .FAB_ACT_ADDR5(npu_act_addr[7][5]),
        .FAB_ACT_ADDR6(npu_act_addr[7][6]), .FAB_ACT_ADDR7(npu_act_addr[7][7]), .FAB_ACT_ADDR8(npu_act_addr[7][8]),
        .FAB_ACT_WDATA0(npu_act_wdata[7][0]), .FAB_ACT_WDATA1(npu_act_wdata[7][1]), .FAB_ACT_WDATA2(npu_act_wdata[7][2]), .FAB_ACT_WDATA3(npu_act_wdata[7][3]),
        .FAB_ACT_WDATA4(npu_act_wdata[7][4]), .FAB_ACT_WDATA5(npu_act_wdata[7][5]), .FAB_ACT_WDATA6(npu_act_wdata[7][6]), .FAB_ACT_WDATA7(npu_act_wdata[7][7]),
        .FAB_ACT_RDATA0(npu_act_rdata[7][0]), .FAB_ACT_RDATA1(npu_act_rdata[7][1]), .FAB_ACT_RDATA2(npu_act_rdata[7][2]), .FAB_ACT_RDATA3(npu_act_rdata[7][3]),
        .FAB_ACT_RDATA4(npu_act_rdata[7][4]), .FAB_ACT_RDATA5(npu_act_rdata[7][5]), .FAB_ACT_RDATA6(npu_act_rdata[7][6]), .FAB_ACT_RDATA7(npu_act_rdata[7][7]),
        .FAB_WEIGHT_IN0(npu_weight_in[7][0]), .FAB_WEIGHT_IN1(npu_weight_in[7][1]), .FAB_WEIGHT_IN2(npu_weight_in[7][2]), .FAB_WEIGHT_IN3(npu_weight_in[7][3]),
        .FAB_WEIGHT_IN4(npu_weight_in[7][4]), .FAB_WEIGHT_IN5(npu_weight_in[7][5]), .FAB_WEIGHT_IN6(npu_weight_in[7][6]), .FAB_WEIGHT_IN7(npu_weight_in[7][7])
    );


    // ========================================================================
    // 3. NORTH EDGE (Y=0): NPU_PSUM_PORT (X=7..10) & ALL 6 N_IO TILES (X=1..6)
    // ========================================================================
    // PSum Port A (Tile X7Y0)
    wire [7:0]  npu_psum_A_addr;
    wire [7:0]  npu_psum_A_we;
    wire [31:0] npu_psum_A_wdata;
    wire [2:0]  npu_psum_A_read_bank_sel;
    wire [31:0] npu_psum_A_rdata;

    (* keep, BEL="X7Y0." *) NPU_PSUM_PORT_BEL bel_psum_portA (
        .FAB_ADDR0(npu_psum_A_addr[0]), .FAB_ADDR1(npu_psum_A_addr[1]), .FAB_ADDR2(npu_psum_A_addr[2]), .FAB_ADDR3(npu_psum_A_addr[3]),
        .FAB_ADDR4(npu_psum_A_addr[4]), .FAB_ADDR5(npu_psum_A_addr[5]), .FAB_ADDR6(npu_psum_A_addr[6]), .FAB_ADDR7(npu_psum_A_addr[7]),
        .FAB_WE0(npu_psum_A_we[0]),     .FAB_WE1(npu_psum_A_we[1]),     .FAB_WE2(npu_psum_A_we[2]),     .FAB_WE3(npu_psum_A_we[3]),
        .FAB_WE4(npu_psum_A_we[4]),     .FAB_WE5(npu_psum_A_we[5]),     .FAB_WE6(npu_psum_A_we[6]),     .FAB_WE7(npu_psum_A_we[7]),
        .FAB_WDATA0(npu_psum_A_wdata[0]),   .FAB_WDATA1(npu_psum_A_wdata[1]),   .FAB_WDATA2(npu_psum_A_wdata[2]),   .FAB_WDATA3(npu_psum_A_wdata[3]),
        .FAB_WDATA4(npu_psum_A_wdata[4]),   .FAB_WDATA5(npu_psum_A_wdata[5]),   .FAB_WDATA6(npu_psum_A_wdata[6]),   .FAB_WDATA7(npu_psum_A_wdata[7]),
        .FAB_WDATA8(npu_psum_A_wdata[8]),   .FAB_WDATA9(npu_psum_A_wdata[9]),   .FAB_WDATA10(npu_psum_A_wdata[10]), .FAB_WDATA11(npu_psum_A_wdata[11]),
        .FAB_WDATA12(npu_psum_A_wdata[12]), .FAB_WDATA13(npu_psum_A_wdata[13]), .FAB_WDATA14(npu_psum_A_wdata[14]), .FAB_WDATA15(npu_psum_A_wdata[15]),
        .FAB_WDATA16(npu_psum_A_wdata[16]), .FAB_WDATA17(npu_psum_A_wdata[17]), .FAB_WDATA18(npu_psum_A_wdata[18]), .FAB_WDATA19(npu_psum_A_wdata[19]),
        .FAB_WDATA20(npu_psum_A_wdata[20]), .FAB_WDATA21(npu_psum_A_wdata[21]), .FAB_WDATA22(npu_psum_A_wdata[22]), .FAB_WDATA23(npu_psum_A_wdata[23]),
        .FAB_WDATA24(npu_psum_A_wdata[24]), .FAB_WDATA25(npu_psum_A_wdata[25]), .FAB_WDATA26(npu_psum_A_wdata[26]), .FAB_WDATA27(npu_psum_A_wdata[27]),
        .FAB_WDATA28(npu_psum_A_wdata[28]), .FAB_WDATA29(npu_psum_A_wdata[29]), .FAB_WDATA30(npu_psum_A_wdata[30]), .FAB_WDATA31(npu_psum_A_wdata[31]),
        .FAB_READ_BANK_SEL0(npu_psum_A_read_bank_sel[0]), .FAB_READ_BANK_SEL1(npu_psum_A_read_bank_sel[1]), .FAB_READ_BANK_SEL2(npu_psum_A_read_bank_sel[2]),
        .FAB_RDATA0(npu_psum_A_rdata[0]),   .FAB_RDATA1(npu_psum_A_rdata[1]),   .FAB_RDATA2(npu_psum_A_rdata[2]),   .FAB_RDATA3(npu_psum_A_rdata[3]),
        .FAB_RDATA4(npu_psum_A_rdata[4]),   .FAB_RDATA5(npu_psum_A_rdata[5]),   .FAB_RDATA6(npu_psum_A_rdata[6]),   .FAB_RDATA7(npu_psum_A_rdata[7]),
        .FAB_RDATA8(npu_psum_A_rdata[8]),   .FAB_RDATA9(npu_psum_A_rdata[9]),   .FAB_RDATA10(npu_psum_A_rdata[10]), .FAB_RDATA11(npu_psum_A_rdata[11]),
        .FAB_RDATA12(npu_psum_A_rdata[12]), .FAB_RDATA13(npu_psum_A_rdata[13]), .FAB_RDATA14(npu_psum_A_rdata[14]), .FAB_RDATA15(npu_psum_A_rdata[15]),
        .FAB_RDATA16(npu_psum_A_rdata[16]), .FAB_RDATA17(npu_psum_A_rdata[17]), .FAB_RDATA18(npu_psum_A_rdata[18]), .FAB_RDATA19(npu_psum_A_rdata[19]),
        .FAB_RDATA20(npu_psum_A_rdata[20]), .FAB_RDATA21(npu_psum_A_rdata[21]), .FAB_RDATA22(npu_psum_A_rdata[22]), .FAB_RDATA23(npu_psum_A_rdata[23]),
        .FAB_RDATA24(npu_psum_A_rdata[24]), .FAB_RDATA25(npu_psum_A_rdata[25]), .FAB_RDATA26(npu_psum_A_rdata[26]), .FAB_RDATA27(npu_psum_A_rdata[27]),
        .FAB_RDATA28(npu_psum_A_rdata[28]), .FAB_RDATA29(npu_psum_A_rdata[29]), .FAB_RDATA30(npu_psum_A_rdata[30]), .FAB_RDATA31(npu_psum_A_rdata[31])
    );

    // PSum Port B (Tile X9Y0)
    wire [7:0]  npu_psum_B_addr;
    wire [7:0]  npu_psum_B_we;
    wire [31:0] npu_psum_B_wdata;
    wire [2:0]  npu_psum_B_read_bank_sel;
    wire [31:0] npu_psum_B_rdata;

    (* keep, BEL="X9Y0." *) NPU_PSUM_PORT_BEL bel_psum_portB (
        .FAB_ADDR0(npu_psum_B_addr[0]), .FAB_ADDR1(npu_psum_B_addr[1]), .FAB_ADDR2(npu_psum_B_addr[2]), .FAB_ADDR3(npu_psum_B_addr[3]),
        .FAB_ADDR4(npu_psum_B_addr[4]), .FAB_ADDR5(npu_psum_B_addr[5]), .FAB_ADDR6(npu_psum_B_addr[6]), .FAB_ADDR7(npu_psum_B_addr[7]),
        .FAB_WE0(npu_psum_B_we[0]),     .FAB_WE1(npu_psum_B_we[1]),     .FAB_WE2(npu_psum_B_we[2]),     .FAB_WE3(npu_psum_B_we[3]),
        .FAB_WE4(npu_psum_B_we[4]),     .FAB_WE5(npu_psum_B_we[5]),     .FAB_WE6(npu_psum_B_we[6]),     .FAB_WE7(npu_psum_B_we[7]),
        .FAB_WDATA0(npu_psum_B_wdata[0]),   .FAB_WDATA1(npu_psum_B_wdata[1]),   .FAB_WDATA2(npu_psum_B_wdata[2]),   .FAB_WDATA3(npu_psum_B_wdata[3]),
        .FAB_WDATA4(npu_psum_B_wdata[4]),   .FAB_WDATA5(npu_psum_B_wdata[5]),   .FAB_WDATA6(npu_psum_B_wdata[6]),   .FAB_WDATA7(npu_psum_B_wdata[7]),
        .FAB_WDATA8(npu_psum_B_wdata[8]),   .FAB_WDATA9(npu_psum_B_wdata[9]),   .FAB_WDATA10(npu_psum_B_wdata[10]), .FAB_WDATA11(npu_psum_B_wdata[11]),
        .FAB_WDATA12(npu_psum_B_wdata[12]), .FAB_WDATA13(npu_psum_B_wdata[13]), .FAB_WDATA14(npu_psum_B_wdata[14]), .FAB_WDATA15(npu_psum_B_wdata[15]),
        .FAB_WDATA16(npu_psum_B_wdata[16]), .FAB_WDATA17(npu_psum_B_wdata[17]), .FAB_WDATA18(npu_psum_B_wdata[18]), .FAB_WDATA19(npu_psum_B_wdata[19]),
        .FAB_WDATA20(npu_psum_B_wdata[20]), .FAB_WDATA21(npu_psum_B_wdata[21]), .FAB_WDATA22(npu_psum_B_wdata[22]), .FAB_WDATA23(npu_psum_B_wdata[23]),
        .FAB_WDATA24(npu_psum_B_wdata[24]), .FAB_WDATA25(npu_psum_B_wdata[25]), .FAB_WDATA26(npu_psum_B_wdata[26]), .FAB_WDATA27(npu_psum_B_wdata[27]),
        .FAB_WDATA28(npu_psum_B_wdata[28]), .FAB_WDATA29(npu_psum_B_wdata[29]), .FAB_WDATA30(npu_psum_B_wdata[30]), .FAB_WDATA31(npu_psum_B_wdata[31]),
        .FAB_READ_BANK_SEL0(npu_psum_B_read_bank_sel[0]), .FAB_READ_BANK_SEL1(npu_psum_B_read_bank_sel[1]), .FAB_READ_BANK_SEL2(npu_psum_B_read_bank_sel[2]),
        .FAB_RDATA0(npu_psum_B_rdata[0]),   .FAB_RDATA1(npu_psum_B_rdata[1]),   .FAB_RDATA2(npu_psum_B_rdata[2]),   .FAB_RDATA3(npu_psum_B_rdata[3]),
        .FAB_RDATA4(npu_psum_B_rdata[4]),   .FAB_RDATA5(npu_psum_B_rdata[5]),   .FAB_RDATA6(npu_psum_B_rdata[6]),   .FAB_RDATA7(npu_psum_B_rdata[7]),
        .FAB_RDATA8(npu_psum_B_rdata[8]),   .FAB_RDATA9(npu_psum_B_rdata[9]),   .FAB_RDATA10(npu_psum_B_rdata[10]), .FAB_RDATA11(npu_psum_B_rdata[11]),
        .FAB_RDATA12(npu_psum_B_rdata[12]), .FAB_RDATA13(npu_psum_B_rdata[13]), .FAB_RDATA14(npu_psum_B_rdata[14]), .FAB_RDATA15(npu_psum_B_rdata[15]),
        .FAB_RDATA16(npu_psum_B_rdata[16]), .FAB_RDATA17(npu_psum_B_rdata[17]), .FAB_RDATA18(npu_psum_B_rdata[18]), .FAB_RDATA19(npu_psum_B_rdata[19]),
        .FAB_RDATA20(npu_psum_B_rdata[20]), .FAB_RDATA21(npu_psum_B_rdata[21]), .FAB_RDATA22(npu_psum_B_rdata[22]), .FAB_RDATA23(npu_psum_B_rdata[23]),
        .FAB_RDATA24(npu_psum_B_rdata[24]), .FAB_RDATA25(npu_psum_B_rdata[25]), .FAB_RDATA26(npu_psum_B_rdata[26]), .FAB_RDATA27(npu_psum_B_rdata[27]),
        .FAB_RDATA28(npu_psum_B_rdata[28]), .FAB_RDATA29(npu_psum_B_rdata[29]), .FAB_RDATA30(npu_psum_B_rdata[30]), .FAB_RDATA31(npu_psum_B_rdata[31])
    );

    // North UIO Wires: 6 Tiles x 20 bits = 120 bits total
    //   uio_top_fin:  Signals driven FROM fabric soft-logic TO external SoC/pads
    //   uio_top_fout: Signals driven FROM external SoC/pads INTO fabric soft-logic
    wire [119:0] uio_top_fin;
    wire [119:0] uio_top_fout;

    // Tile X1Y0: North UIO [19:0]
    (* keep, BEL="X1Y0.UIO_TOP_" *) User_project_IO uio_top_x1 (
        .FIN0(uio_top_fin[0]),   .FIN1(uio_top_fin[1]),   .FIN2(uio_top_fin[2]),   .FIN3(uio_top_fin[3]),
        .FIN4(uio_top_fin[4]),   .FIN5(uio_top_fin[5]),   .FIN6(uio_top_fin[6]),   .FIN7(uio_top_fin[7]),
        .FIN8(uio_top_fin[8]),   .FIN9(uio_top_fin[9]),   .FIN10(uio_top_fin[10]), .FIN11(uio_top_fin[11]),
        .FIN12(uio_top_fin[12]), .FIN13(uio_top_fin[13]), .FIN14(uio_top_fin[14]), .FIN15(uio_top_fin[15]),
        .FIN16(uio_top_fin[16]), .FIN17(uio_top_fin[17]), .FIN18(uio_top_fin[18]), .FIN19(uio_top_fin[19]),
        .FOUT0(uio_top_fout[0]),   .FOUT1(uio_top_fout[1]),   .FOUT2(uio_top_fout[2]),   .FOUT3(uio_top_fout[3]),
        .FOUT4(uio_top_fout[4]),   .FOUT5(uio_top_fout[5]),   .FOUT6(uio_top_fout[6]),   .FOUT7(uio_top_fout[7]),
        .FOUT8(uio_top_fout[8]),   .FOUT9(uio_top_fout[9]),   .FOUT10(uio_top_fout[10]), .FOUT11(uio_top_fout[11]),
        .FOUT12(uio_top_fout[12]), .FOUT13(uio_top_fout[13]), .FOUT14(uio_top_fout[14]), .FOUT15(uio_top_fout[15]),
        .FOUT16(uio_top_fout[16]), .FOUT17(uio_top_fout[17]), .FOUT18(uio_top_fout[18]), .FOUT19(uio_top_fout[19])
    );

    // Tile X2Y0: North UIO [39:20]
    (* keep, BEL="X2Y0.UIO_TOP_" *) User_project_IO uio_top_x2 (
        .FIN0(uio_top_fin[20]), .FIN1(uio_top_fin[21]), .FIN2(uio_top_fin[22]), .FIN3(uio_top_fin[23]),
        .FIN4(uio_top_fin[24]), .FIN5(uio_top_fin[25]), .FIN6(uio_top_fin[26]), .FIN7(uio_top_fin[27]),
        .FIN8(uio_top_fin[28]), .FIN9(uio_top_fin[29]), .FIN10(uio_top_fin[30]), .FIN11(uio_top_fin[31]),
        .FIN12(uio_top_fin[32]), .FIN13(uio_top_fin[33]), .FIN14(uio_top_fin[34]), .FIN15(uio_top_fin[35]),
        .FIN16(uio_top_fin[36]), .FIN17(uio_top_fin[37]), .FIN18(uio_top_fin[38]), .FIN19(uio_top_fin[39]),
        .FOUT0(uio_top_fout[20]), .FOUT1(uio_top_fout[21]), .FOUT2(uio_top_fout[22]), .FOUT3(uio_top_fout[23]),
        .FOUT4(uio_top_fout[24]), .FOUT5(uio_top_fout[25]), .FOUT6(uio_top_fout[26]), .FOUT7(uio_top_fout[27]),
        .FOUT8(uio_top_fout[28]), .FOUT9(uio_top_fout[29]), .FOUT10(uio_top_fout[30]), .FOUT11(uio_top_fout[31]),
        .FOUT12(uio_top_fout[32]), .FOUT13(uio_top_fout[33]), .FOUT14(uio_top_fout[34]), .FOUT15(uio_top_fout[35]),
        .FOUT16(uio_top_fout[36]), .FOUT17(uio_top_fout[37]), .FOUT18(uio_top_fout[38]), .FOUT19(uio_top_fout[39])
    );

    // Tile X3Y0: North UIO [59:40]
    (* keep, BEL="X3Y0.UIO_TOP_" *) User_project_IO uio_top_x3 (
        .FIN0(uio_top_fin[40]), .FIN1(uio_top_fin[41]), .FIN2(uio_top_fin[42]), .FIN3(uio_top_fin[43]),
        .FIN4(uio_top_fin[44]), .FIN5(uio_top_fin[45]), .FIN6(uio_top_fin[46]), .FIN7(uio_top_fin[47]),
        .FIN8(uio_top_fin[48]), .FIN9(uio_top_fin[49]), .FIN10(uio_top_fin[50]), .FIN11(uio_top_fin[51]),
        .FIN12(uio_top_fin[52]), .FIN13(uio_top_fin[53]), .FIN14(uio_top_fin[54]), .FIN15(uio_top_fin[55]),
        .FIN16(uio_top_fin[56]), .FIN17(uio_top_fin[57]), .FIN18(uio_top_fin[58]), .FIN19(uio_top_fin[59]),
        .FOUT0(uio_top_fout[40]), .FOUT1(uio_top_fout[41]), .FOUT2(uio_top_fout[42]), .FOUT3(uio_top_fout[43]),
        .FOUT4(uio_top_fout[44]), .FOUT5(uio_top_fout[45]), .FOUT6(uio_top_fout[46]), .FOUT7(uio_top_fout[47]),
        .FOUT8(uio_top_fout[48]), .FOUT9(uio_top_fout[49]), .FOUT10(uio_top_fout[50]), .FOUT11(uio_top_fout[51]),
        .FOUT12(uio_top_fout[52]), .FOUT13(uio_top_fout[53]), .FOUT14(uio_top_fout[54]), .FOUT15(uio_top_fout[55]),
        .FOUT16(uio_top_fout[56]), .FOUT17(uio_top_fout[57]), .FOUT18(uio_top_fout[58]), .FOUT19(uio_top_fout[59])
    );

    // Tile X4Y0: North UIO [79:60]
    (* keep, BEL="X4Y0.UIO_TOP_" *) User_project_IO uio_top_x4 (
        .FIN0(uio_top_fin[60]), .FIN1(uio_top_fin[61]), .FIN2(uio_top_fin[62]), .FIN3(uio_top_fin[63]),
        .FIN4(uio_top_fin[64]), .FIN5(uio_top_fin[65]), .FIN6(uio_top_fin[66]), .FIN7(uio_top_fin[67]),
        .FIN8(uio_top_fin[68]), .FIN9(uio_top_fin[69]), .FIN10(uio_top_fin[70]), .FIN11(uio_top_fin[71]),
        .FIN12(uio_top_fin[72]), .FIN13(uio_top_fin[73]), .FIN14(uio_top_fin[74]), .FIN15(uio_top_fin[75]),
        .FIN16(uio_top_fin[76]), .FIN17(uio_top_fin[77]), .FIN18(uio_top_fin[78]), .FIN19(uio_top_fin[79]),
        .FOUT0(uio_top_fout[60]), .FOUT1(uio_top_fout[61]), .FOUT2(uio_top_fout[62]), .FOUT3(uio_top_fout[63]),
        .FOUT4(uio_top_fout[64]), .FOUT5(uio_top_fout[65]), .FOUT6(uio_top_fout[66]), .FOUT7(uio_top_fout[67]),
        .FOUT8(uio_top_fout[68]), .FOUT9(uio_top_fout[69]), .FOUT10(uio_top_fout[70]), .FOUT11(uio_top_fout[71]),
        .FOUT12(uio_top_fout[72]), .FOUT13(uio_top_fout[73]), .FOUT14(uio_top_fout[74]), .FOUT15(uio_top_fout[75]),
        .FOUT16(uio_top_fout[76]), .FOUT17(uio_top_fout[77]), .FOUT18(uio_top_fout[78]), .FOUT19(uio_top_fout[79])
    );

    // Tile X5Y0: North UIO [99:80]
    (* keep, BEL="X5Y0.UIO_TOP_" *) User_project_IO uio_top_x5 (
        .FIN0(uio_top_fin[80]), .FIN1(uio_top_fin[81]), .FIN2(uio_top_fin[82]), .FIN3(uio_top_fin[83]),
        .FIN4(uio_top_fin[84]), .FIN5(uio_top_fin[85]), .FIN6(uio_top_fin[86]), .FIN7(uio_top_fin[87]),
        .FIN8(uio_top_fin[88]), .FIN9(uio_top_fin[89]), .FIN10(uio_top_fin[90]), .FIN11(uio_top_fin[91]),
        .FIN12(uio_top_fin[92]), .FIN13(uio_top_fin[93]), .FIN14(uio_top_fin[94]), .FIN15(uio_top_fin[95]),
        .FIN16(uio_top_fin[96]), .FIN17(uio_top_fin[97]), .FIN18(uio_top_fin[98]), .FIN19(uio_top_fin[99]),
        .FOUT0(uio_top_fout[80]), .FOUT1(uio_top_fout[81]), .FOUT2(uio_top_fout[82]), .FOUT3(uio_top_fout[83]),
        .FOUT4(uio_top_fout[84]), .FOUT5(uio_top_fout[85]), .FOUT6(uio_top_fout[86]), .FOUT7(uio_top_fout[87]),
        .FOUT8(uio_top_fout[88]), .FOUT9(uio_top_fout[89]), .FOUT10(uio_top_fout[90]), .FOUT11(uio_top_fout[91]),
        .FOUT12(uio_top_fout[92]), .FOUT13(uio_top_fout[93]), .FOUT14(uio_top_fout[94]), .FOUT15(uio_top_fout[95]),
        .FOUT16(uio_top_fout[96]), .FOUT17(uio_top_fout[97]), .FOUT18(uio_top_fout[98]), .FOUT19(uio_top_fout[99])
    );

    // Tile X6Y0: North UIO [119:100]
    (* keep, BEL="X6Y0.UIO_TOP_" *) User_project_IO uio_top_x6 (
        .FIN0(uio_top_fin[100]), .FIN1(uio_top_fin[101]), .FIN2(uio_top_fin[102]), .FIN3(uio_top_fin[103]),
        .FIN4(uio_top_fin[104]), .FIN5(uio_top_fin[105]), .FIN6(uio_top_fin[106]), .FIN7(uio_top_fin[107]),
        .FIN8(uio_top_fin[108]), .FIN9(uio_top_fin[109]), .FIN10(uio_top_fin[110]), .FIN11(uio_top_fin[111]),
        .FIN12(uio_top_fin[112]), .FIN13(uio_top_fin[113]), .FIN14(uio_top_fin[114]), .FIN15(uio_top_fin[115]),
        .FIN16(uio_top_fin[116]), .FIN17(uio_top_fin[117]), .FIN18(uio_top_fin[118]), .FIN19(uio_top_fin[119]),
        .FOUT0(uio_top_fout[100]), .FOUT1(uio_top_fout[101]), .FOUT2(uio_top_fout[102]), .FOUT3(uio_top_fout[103]),
        .FOUT4(uio_top_fout[104]), .FOUT5(uio_top_fout[105]), .FOUT6(uio_top_fout[106]), .FOUT7(uio_top_fout[107]),
        .FOUT8(uio_top_fout[108]), .FOUT9(uio_top_fout[109]), .FOUT10(uio_top_fout[110]), .FOUT11(uio_top_fout[111]),
        .FOUT12(uio_top_fout[112]), .FOUT13(uio_top_fout[113]), .FOUT14(uio_top_fout[114]), .FOUT15(uio_top_fout[115]),
        .FOUT16(uio_top_fout[116]), .FOUT17(uio_top_fout[117]), .FOUT18(uio_top_fout[118]), .FOUT19(uio_top_fout[119])
    );


    // ========================================================================
    // 4. SOUTH EDGE (Y=11): ALL 10 S_IO TILES (X=1..10, UIO_BOT)
    // ========================================================================
    // South UIO Wires: 10 Tiles x 20 bits = 200 bits total
    //   uio_bot_fin:  Signals driven FROM fabric soft-logic TO external SoC/pads
    //   uio_bot_fout: Signals driven FROM external SoC/pads INTO fabric soft-logic
    wire [199:0] uio_bot_fin;
    wire [199:0] uio_bot_fout;

    // Tile X1Y11: South UIO [19:0]
    (* keep, BEL="X1Y11.UIO_BOT_" *) User_project_IO uio_bot_x1 (
        .FIN0(uio_bot_fin[0]),   .FIN1(uio_bot_fin[1]),   .FIN2(uio_bot_fin[2]),   .FIN3(uio_bot_fin[3]),
        .FIN4(uio_bot_fin[4]),   .FIN5(uio_bot_fin[5]),   .FIN6(uio_bot_fin[6]),   .FIN7(uio_bot_fin[7]),
        .FIN8(uio_bot_fin[8]),   .FIN9(uio_bot_fin[9]),   .FIN10(uio_bot_fin[10]), .FIN11(uio_bot_fin[11]),
        .FIN12(uio_bot_fin[12]), .FIN13(uio_bot_fin[13]), .FIN14(uio_bot_fin[14]), .FIN15(uio_bot_fin[15]),
        .FIN16(uio_bot_fin[16]), .FIN17(uio_bot_fin[17]), .FIN18(uio_bot_fin[18]), .FIN19(uio_bot_fin[19]),
        .FOUT0(uio_bot_fout[0]),   .FOUT1(uio_bot_fout[1]),   .FOUT2(uio_bot_fout[2]),   .FOUT3(uio_bot_fout[3]),
        .FOUT4(uio_bot_fout[4]),   .FOUT5(uio_bot_fout[5]),   .FOUT6(uio_bot_fout[6]),   .FOUT7(uio_bot_fout[7]),
        .FOUT8(uio_bot_fout[8]),   .FOUT9(uio_bot_fout[9]),   .FOUT10(uio_bot_fout[10]), .FOUT11(uio_bot_fout[11]),
        .FOUT12(uio_bot_fout[12]), .FOUT13(uio_bot_fout[13]), .FOUT14(uio_bot_fout[14]), .FOUT15(uio_bot_fout[15]),
        .FOUT16(uio_bot_fout[16]), .FOUT17(uio_bot_fout[17]), .FOUT18(uio_bot_fout[18]), .FOUT19(uio_bot_fout[19])
    );

    // Tile X2Y11: South UIO [39:20]
    (* keep, BEL="X2Y11.UIO_BOT_" *) User_project_IO uio_bot_x2 (
        .FIN0(uio_bot_fin[20]), .FIN1(uio_bot_fin[21]), .FIN2(uio_bot_fin[22]), .FIN3(uio_bot_fin[23]),
        .FIN4(uio_bot_fin[24]), .FIN5(uio_bot_fin[25]), .FIN6(uio_bot_fin[26]), .FIN7(uio_bot_fin[27]),
        .FIN8(uio_bot_fin[28]), .FIN9(uio_bot_fin[29]), .FIN10(uio_bot_fin[30]), .FIN11(uio_bot_fin[31]),
        .FIN12(uio_bot_fin[32]), .FIN13(uio_bot_fin[33]), .FIN14(uio_bot_fin[34]), .FIN15(uio_bot_fin[35]),
        .FIN16(uio_bot_fin[36]), .FIN17(uio_bot_fin[37]), .FIN18(uio_bot_fin[38]), .FIN19(uio_bot_fin[39]),
        .FOUT0(uio_bot_fout[20]), .FOUT1(uio_bot_fout[21]), .FOUT2(uio_bot_fout[22]), .FOUT3(uio_bot_fout[23]),
        .FOUT4(uio_bot_fout[24]), .FOUT5(uio_bot_fout[25]), .FOUT6(uio_bot_fout[26]), .FOUT7(uio_bot_fout[27]),
        .FOUT8(uio_bot_fout[28]), .FOUT9(uio_bot_fout[29]), .FOUT10(uio_bot_fout[30]), .FOUT11(uio_bot_fout[31]),
        .FOUT12(uio_bot_fout[32]), .FOUT13(uio_bot_fout[33]), .FOUT14(uio_bot_fout[34]), .FOUT15(uio_bot_fout[35]),
        .FOUT16(uio_bot_fout[36]), .FOUT17(uio_bot_fout[37]), .FOUT18(uio_bot_fout[38]), .FOUT19(uio_bot_fout[39])
    );

    // Tile X3Y11: South UIO [59:40]
    (* keep, BEL="X3Y11.UIO_BOT_" *) User_project_IO uio_bot_x3 (
        .FIN0(uio_bot_fin[40]), .FIN1(uio_bot_fin[41]), .FIN2(uio_bot_fin[42]), .FIN3(uio_bot_fin[43]),
        .FIN4(uio_bot_fin[44]), .FIN5(uio_bot_fin[45]), .FIN6(uio_bot_fin[46]), .FIN7(uio_bot_fin[47]),
        .FIN8(uio_bot_fin[48]), .FIN9(uio_bot_fin[49]), .FIN10(uio_bot_fin[50]), .FIN11(uio_bot_fin[51]),
        .FIN12(uio_bot_fin[52]), .FIN13(uio_bot_fin[53]), .FIN14(uio_bot_fin[54]), .FIN15(uio_bot_fin[55]),
        .FIN16(uio_bot_fin[56]), .FIN17(uio_bot_fin[57]), .FIN18(uio_bot_fin[58]), .FIN19(uio_bot_fin[59]),
        .FOUT0(uio_bot_fout[40]), .FOUT1(uio_bot_fout[41]), .FOUT2(uio_bot_fout[42]), .FOUT3(uio_bot_fout[43]),
        .FOUT4(uio_bot_fout[44]), .FOUT5(uio_bot_fout[45]), .FOUT6(uio_bot_fout[46]), .FOUT7(uio_bot_fout[47]),
        .FOUT8(uio_bot_fout[48]), .FOUT9(uio_bot_fout[49]), .FOUT10(uio_bot_fout[50]), .FOUT11(uio_bot_fout[51]),
        .FOUT12(uio_bot_fout[52]), .FOUT13(uio_bot_fout[53]), .FOUT14(uio_bot_fout[54]), .FOUT15(uio_bot_fout[55]),
        .FOUT16(uio_bot_fout[56]), .FOUT17(uio_bot_fout[57]), .FOUT18(uio_bot_fout[58]), .FOUT19(uio_bot_fout[59])
    );

    // Tile X4Y11: South UIO [79:60]
    (* keep, BEL="X4Y11.UIO_BOT_" *) User_project_IO uio_bot_x4 (
        .FIN0(uio_bot_fin[60]), .FIN1(uio_bot_fin[61]), .FIN2(uio_bot_fin[62]), .FIN3(uio_bot_fin[63]),
        .FIN4(uio_bot_fin[64]), .FIN5(uio_bot_fin[65]), .FIN6(uio_bot_fin[66]), .FIN7(uio_bot_fin[67]),
        .FIN8(uio_bot_fin[68]), .FIN9(uio_bot_fin[69]), .FIN10(uio_bot_fin[70]), .FIN11(uio_bot_fin[71]),
        .FIN12(uio_bot_fin[72]), .FIN13(uio_bot_fin[73]), .FIN14(uio_bot_fin[74]), .FIN15(uio_bot_fin[75]),
        .FIN16(uio_bot_fin[76]), .FIN17(uio_bot_fin[77]), .FIN18(uio_bot_fin[78]), .FIN19(uio_bot_fin[79]),
        .FOUT0(uio_bot_fout[60]), .FOUT1(uio_bot_fout[61]), .FOUT2(uio_bot_fout[62]), .FOUT3(uio_bot_fout[63]),
        .FOUT4(uio_bot_fout[64]), .FOUT5(uio_bot_fout[65]), .FOUT6(uio_bot_fout[66]), .FOUT7(uio_bot_fout[67]),
        .FOUT8(uio_bot_fout[68]), .FOUT9(uio_bot_fout[69]), .FOUT10(uio_bot_fout[70]), .FOUT11(uio_bot_fout[71]),
        .FOUT12(uio_bot_fout[72]), .FOUT13(uio_bot_fout[73]), .FOUT14(uio_bot_fout[74]), .FOUT15(uio_bot_fout[75]),
        .FOUT16(uio_bot_fout[76]), .FOUT17(uio_bot_fout[77]), .FOUT18(uio_bot_fout[78]), .FOUT19(uio_bot_fout[79])
    );

    // Tile X5Y11: South UIO [99:80]
    (* keep, BEL="X5Y11.UIO_BOT_" *) User_project_IO uio_bot_x5 (
        .FIN0(uio_bot_fin[80]), .FIN1(uio_bot_fin[81]), .FIN2(uio_bot_fin[82]), .FIN3(uio_bot_fin[83]),
        .FIN4(uio_bot_fin[84]), .FIN5(uio_bot_fin[85]), .FIN6(uio_bot_fin[86]), .FIN7(uio_bot_fin[87]),
        .FIN8(uio_bot_fin[88]), .FIN9(uio_bot_fin[89]), .FIN10(uio_bot_fin[90]), .FIN11(uio_bot_fin[91]),
        .FIN12(uio_bot_fin[92]), .FIN13(uio_bot_fin[93]), .FIN14(uio_bot_fin[94]), .FIN15(uio_bot_fin[95]),
        .FIN16(uio_bot_fin[96]), .FIN17(uio_bot_fin[97]), .FIN18(uio_bot_fin[98]), .FIN19(uio_bot_fin[99]),
        .FOUT0(uio_bot_fout[80]), .FOUT1(uio_bot_fout[81]), .FOUT2(uio_bot_fout[82]), .FOUT3(uio_bot_fout[83]),
        .FOUT4(uio_bot_fout[84]), .FOUT5(uio_bot_fout[85]), .FOUT6(uio_bot_fout[86]), .FOUT7(uio_bot_fout[87]),
        .FOUT8(uio_bot_fout[88]), .FOUT9(uio_bot_fout[89]), .FOUT10(uio_bot_fout[90]), .FOUT11(uio_bot_fout[91]),
        .FOUT12(uio_bot_fout[92]), .FOUT13(uio_bot_fout[93]), .FOUT14(uio_bot_fout[94]), .FOUT15(uio_bot_fout[95]),
        .FOUT16(uio_bot_fout[96]), .FOUT17(uio_bot_fout[97]), .FOUT18(uio_bot_fout[98]), .FOUT19(uio_bot_fout[99])
    );

    // Tile X6Y11: South UIO [119:100]
    (* keep, BEL="X6Y11.UIO_BOT_" *) User_project_IO uio_bot_x6 (
        .FIN0(uio_bot_fin[100]), .FIN1(uio_bot_fin[101]), .FIN2(uio_bot_fin[102]), .FIN3(uio_bot_fin[103]),
        .FIN4(uio_bot_fin[104]), .FIN5(uio_bot_fin[105]), .FIN6(uio_bot_fin[106]), .FIN7(uio_bot_fin[107]),
        .FIN8(uio_bot_fin[108]), .FIN9(uio_bot_fin[109]), .FIN10(uio_bot_fin[110]), .FIN11(uio_bot_fin[111]),
        .FIN12(uio_bot_fin[112]), .FIN13(uio_bot_fin[113]), .FIN14(uio_bot_fin[114]), .FIN15(uio_bot_fin[115]),
        .FIN16(uio_bot_fin[116]), .FIN17(uio_bot_fin[117]), .FIN18(uio_bot_fin[118]), .FIN19(uio_bot_fin[119]),
        .FOUT0(uio_bot_fout[100]), .FOUT1(uio_bot_fout[101]), .FOUT2(uio_bot_fout[102]), .FOUT3(uio_bot_fout[103]),
        .FOUT4(uio_bot_fout[104]), .FOUT5(uio_bot_fout[105]), .FOUT6(uio_bot_fout[106]), .FOUT7(uio_bot_fout[107]),
        .FOUT8(uio_bot_fout[108]), .FOUT9(uio_bot_fout[109]), .FOUT10(uio_bot_fout[110]), .FOUT11(uio_bot_fout[111]),
        .FOUT12(uio_bot_fout[112]), .FOUT13(uio_bot_fout[113]), .FOUT14(uio_bot_fout[114]), .FOUT15(uio_bot_fout[115]),
        .FOUT16(uio_bot_fout[116]), .FOUT17(uio_bot_fout[117]), .FOUT18(uio_bot_fout[118]), .FOUT19(uio_bot_fout[119])
    );

    // Tile X7Y11: South UIO [139:120]
    (* keep, BEL="X7Y11.UIO_BOT_" *) User_project_IO uio_bot_x7 (
        .FIN0(uio_bot_fin[120]), .FIN1(uio_bot_fin[121]), .FIN2(uio_bot_fin[122]), .FIN3(uio_bot_fin[123]),
        .FIN4(uio_bot_fin[124]), .FIN5(uio_bot_fin[125]), .FIN6(uio_bot_fin[126]), .FIN7(uio_bot_fin[127]),
        .FIN8(uio_bot_fin[128]), .FIN9(uio_bot_fin[129]), .FIN10(uio_bot_fin[130]), .FIN11(uio_bot_fin[131]),
        .FIN12(uio_bot_fin[132]), .FIN13(uio_bot_fin[133]), .FIN14(uio_bot_fin[134]), .FIN15(uio_bot_fin[135]),
        .FIN16(uio_bot_fin[136]), .FIN17(uio_bot_fin[137]), .FIN18(uio_bot_fin[138]), .FIN19(uio_bot_fin[139]),
        .FOUT0(uio_bot_fout[120]), .FOUT1(uio_bot_fout[121]), .FOUT2(uio_bot_fout[122]), .FOUT3(uio_bot_fout[123]),
        .FOUT4(uio_bot_fout[124]), .FOUT5(uio_bot_fout[125]), .FOUT6(uio_bot_fout[126]), .FOUT7(uio_bot_fout[127]),
        .FOUT8(uio_bot_fout[128]), .FOUT9(uio_bot_fout[129]), .FOUT10(uio_bot_fout[130]), .FOUT11(uio_bot_fout[131]),
        .FOUT12(uio_bot_fout[132]), .FOUT13(uio_bot_fout[133]), .FOUT14(uio_bot_fout[134]), .FOUT15(uio_bot_fout[135]),
        .FOUT16(uio_bot_fout[136]), .FOUT17(uio_bot_fout[137]), .FOUT18(uio_bot_fout[138]), .FOUT19(uio_bot_fout[139])
    );

    // Tile X8Y11: South UIO [159:140]
    (* keep, BEL="X8Y11.UIO_BOT_" *) User_project_IO uio_bot_x8 (
        .FIN0(uio_bot_fin[140]), .FIN1(uio_bot_fin[141]), .FIN2(uio_bot_fin[142]), .FIN3(uio_bot_fin[143]),
        .FIN4(uio_bot_fin[144]), .FIN5(uio_bot_fin[145]), .FIN6(uio_bot_fin[146]), .FIN7(uio_bot_fin[147]),
        .FIN8(uio_bot_fin[148]), .FIN9(uio_bot_fin[149]), .FIN10(uio_bot_fin[150]), .FIN11(uio_bot_fin[151]),
        .FIN12(uio_bot_fin[152]), .FIN13(uio_bot_fin[153]), .FIN14(uio_bot_fin[154]), .FIN15(uio_bot_fin[155]),
        .FIN16(uio_bot_fin[156]), .FIN17(uio_bot_fin[157]), .FIN18(uio_bot_fin[158]), .FIN19(uio_bot_fin[159]),
        .FOUT0(uio_bot_fout[140]), .FOUT1(uio_bot_fout[141]), .FOUT2(uio_bot_fout[142]), .FOUT3(uio_bot_fout[143]),
        .FOUT4(uio_bot_fout[144]), .FOUT5(uio_bot_fout[145]), .FOUT6(uio_bot_fout[146]), .FOUT7(uio_bot_fout[147]),
        .FOUT8(uio_bot_fout[148]), .FOUT9(uio_bot_fout[149]), .FOUT10(uio_bot_fout[150]), .FOUT11(uio_bot_fout[151]),
        .FOUT12(uio_bot_fout[152]), .FOUT13(uio_bot_fout[153]), .FOUT14(uio_bot_fout[154]), .FOUT15(uio_bot_fout[155]),
        .FOUT16(uio_bot_fout[156]), .FOUT17(uio_bot_fout[157]), .FOUT18(uio_bot_fout[158]), .FOUT19(uio_bot_fout[159])
    );

    // Tile X9Y11: South UIO [179:160]
    (* keep, BEL="X9Y11.UIO_BOT_" *) User_project_IO uio_bot_x9 (
        .FIN0(uio_bot_fin[160]), .FIN1(uio_bot_fin[161]), .FIN2(uio_bot_fin[162]), .FIN3(uio_bot_fin[163]),
        .FIN4(uio_bot_fin[164]), .FIN5(uio_bot_fin[165]), .FIN6(uio_bot_fin[166]), .FIN7(uio_bot_fin[167]),
        .FIN8(uio_bot_fin[168]), .FIN9(uio_bot_fin[169]), .FIN10(uio_bot_fin[170]), .FIN11(uio_bot_fin[171]),
        .FIN12(uio_bot_fin[172]), .FIN13(uio_bot_fin[173]), .FIN14(uio_bot_fin[174]), .FIN15(uio_bot_fin[175]),
        .FIN16(uio_bot_fin[176]), .FIN17(uio_bot_fin[177]), .FIN18(uio_bot_fin[178]), .FIN19(uio_bot_fin[179]),
        .FOUT0(uio_bot_fout[160]), .FOUT1(uio_bot_fout[161]), .FOUT2(uio_bot_fout[162]), .FOUT3(uio_bot_fout[163]),
        .FOUT4(uio_bot_fout[164]), .FOUT5(uio_bot_fout[165]), .FOUT6(uio_bot_fout[166]), .FOUT7(uio_bot_fout[167]),
        .FOUT8(uio_bot_fout[168]), .FOUT9(uio_bot_fout[169]), .FOUT10(uio_bot_fout[170]), .FOUT11(uio_bot_fout[171]),
        .FOUT12(uio_bot_fout[172]), .FOUT13(uio_bot_fout[173]), .FOUT14(uio_bot_fout[174]), .FOUT15(uio_bot_fout[175]),
        .FOUT16(uio_bot_fout[176]), .FOUT17(uio_bot_fout[177]), .FOUT18(uio_bot_fout[178]), .FOUT19(uio_bot_fout[179])
    );

    // Tile X10Y11: South UIO [199:180]
    (* keep, BEL="X10Y11.UIO_BOT_" *) User_project_IO uio_bot_x10 (
        .FIN0(uio_bot_fin[180]), .FIN1(uio_bot_fin[181]), .FIN2(uio_bot_fin[182]), .FIN3(uio_bot_fin[183]),
        .FIN4(uio_bot_fin[184]), .FIN5(uio_bot_fin[185]), .FIN6(uio_bot_fin[186]), .FIN7(uio_bot_fin[187]),
        .FIN8(uio_bot_fin[188]), .FIN9(uio_bot_fin[189]), .FIN10(uio_bot_fin[190]), .FIN11(uio_bot_fin[191]),
        .FIN12(uio_bot_fin[192]), .FIN13(uio_bot_fin[193]), .FIN14(uio_bot_fin[194]), .FIN15(uio_bot_fin[195]),
        .FIN16(uio_bot_fin[196]), .FIN17(uio_bot_fin[197]), .FIN18(uio_bot_fin[198]), .FIN19(uio_bot_fin[199]),
        .FOUT0(uio_bot_fout[180]), .FOUT1(uio_bot_fout[181]), .FOUT2(uio_bot_fout[182]), .FOUT3(uio_bot_fout[183]),
        .FOUT4(uio_bot_fout[184]), .FOUT5(uio_bot_fout[185]), .FOUT6(uio_bot_fout[186]), .FOUT7(uio_bot_fout[187]),
        .FOUT8(uio_bot_fout[188]), .FOUT9(uio_bot_fout[189]), .FOUT10(uio_bot_fout[190]), .FOUT11(uio_bot_fout[191]),
        .FOUT12(uio_bot_fout[192]), .FOUT13(uio_bot_fout[193]), .FOUT14(uio_bot_fout[194]), .FOUT15(uio_bot_fout[195]),
        .FOUT16(uio_bot_fout[196]), .FOUT17(uio_bot_fout[197]), .FOUT18(uio_bot_fout[198]), .FOUT19(uio_bot_fout[199])
    );


    // ========================================================================
    // 5. WIRE RENAMING / GROUPING & SOFT-LOGIC ALIGNMENT (LAST STEP)
    // ========================================================================
    // A. Crossbar Select: 8 rows x 4 bits from soft logic drive RAM_IO OutPass4 D lines
    wire [7:0][3:0] npu_crossbar_sel;
    assign ram_d_o[3:0]   = npu_crossbar_sel[0];
    assign ram_d_o[7:4]   = npu_crossbar_sel[1];
    assign ram_d_o[11:8]  = npu_crossbar_sel[2];
    assign ram_d_o[15:12] = npu_crossbar_sel[3];
    assign ram_d_o[19:16] = npu_crossbar_sel[4];
    assign ram_d_o[23:20] = npu_crossbar_sel[5];
    assign ram_d_o[27:24] = npu_crossbar_sel[6];
    assign ram_d_o[31:28] = npu_crossbar_sel[7];

    // B. NPU Array Control: Soft-logic control signals drive RAM_IO OutPass4 C & A lines
    wire npu_array_en;
    wire npu_psum_systolic_en;
    wire npu_psum_lut_en;
    wire [1:0] npu_weight_shift_en;
    wire npu_swap_weights;
    wire npu_stochastic_round_en;
    wire npu_psum_skew_en;
    wire npu_compute_bank_swap;

    assign ram_c_o[0] = npu_array_en;
    assign ram_c_o[1] = npu_psum_systolic_en;
    assign ram_c_o[2] = npu_psum_lut_en;
    assign ram_c_o[3] = npu_weight_shift_en[0];
    assign ram_c_o[4] = npu_swap_weights;
    assign ram_c_o[5] = npu_stochastic_round_en;
    assign ram_c_o[6] = npu_psum_skew_en;
    assign ram_c_o[7] = npu_compute_bank_swap;

    assign ram_a_o[0] = npu_weight_shift_en[1];
    assign ram_a_o[15:1] = 15'b0;

    // C. South UIO Signals (Tile X1Y11 provides Reset & IRQs; remaining 196 lines available)
    wire sys_rstn                = uio_bot_fout[0];  // From SoC DEBUG_OUT[0]
    wire [3:0] efpga_usr_irq_o;
    assign uio_bot_fin[3:0]      = efpga_usr_irq_o;  // To SoC usr_irq
    assign uio_bot_fin[199:4]    = 196'b0;           // Unused South outputs tied off

    // D. North UIO Signals (Tile X6Y0 provides Shift Config & Streamed Activations; remaining lines available)
    wire [29:0] npu_quant_shift_in;
    wire        npu_quant_shift_en;
    wire [63:0] npu_out_act;

    assign uio_top_fin[119]      = npu_quant_shift_en;
    assign uio_top_fin[118:100]  = npu_quant_shift_in[18:0];
    assign uio_top_fin[99:0]     = 100'b0;           // Unused North outputs tied off
    assign npu_out_act           = {uio_top_fout[119:116], 60'b0}; // Read from upper North pins (expandable)


    // ========================================================================
    // 6. INNER USER DESIGN / SOFT-LOGIC CONTROLLER PAYLOAD
    // ========================================================================
    npu_minimal_controller user_controller_inst (
        .clk_i                   (clk),
        .rst_n                   (sys_rstn),

        // AXI4-Lite Slave CSR
        .s_axil_awaddr           ({22'b0, s_axil_awaddr}),
        .s_axil_awprot           (3'b0),
        .s_axil_awvalid          (s_axil_awvalid),
        .s_axil_awready          (s_axil_awready),
        .s_axil_wdata            (s_axil_wdata),
        .s_axil_wstrb            (s_axil_wstrb),
        .s_axil_wvalid           (s_axil_wvalid),
        .s_axil_wready           (s_axil_wready),
        .s_axil_bresp            (s_axil_bresp),
        .s_axil_bvalid           (s_axil_bvalid),
        .s_axil_bready           (s_axil_bready),
        .s_axil_araddr           ({22'b0, s_axil_araddr}),
        .s_axil_arprot           (3'b0),
        .s_axil_arvalid          (s_axil_arvalid),
        .s_axil_arready          (s_axil_arready),
        .s_axil_rdata            (s_axil_rdata),
        .s_axil_rresp            (s_axil_rresp),
        .s_axil_rvalid           (s_axil_rvalid),
        .s_axil_rready           (s_axil_rready),

        // AXI4 Master DMA
        .m_axi_awaddr            (m_axi_awaddr),
        .m_axi_awlen             (m_axi_awlen),
        .m_axi_awsize            (m_axi_awsize),
        .m_axi_awburst           (m_axi_awburst),
        .m_axi_awvalid           (m_axi_awvalid),
        .m_axi_awready           (m_axi_awready),
        .m_axi_wdata             (m_axi_wdata),
        .m_axi_wstrb             (m_axi_wstrb),
        .m_axi_wlast             (m_axi_wlast),
        .m_axi_wvalid            (m_axi_wvalid),
        .m_axi_wready            (m_axi_wready),
        .m_axi_bresp             (m_axi_bresp),
        .m_axi_bvalid            (m_axi_bvalid),
        .m_axi_bready            (m_axi_bready),
        .m_axi_araddr            (m_axi_araddr),
        .m_axi_arlen             (m_axi_arlen),
        .m_axi_arsize            (m_axi_arsize),
        .m_axi_arburst           (m_axi_arburst),
        .m_axi_arvalid           (m_axi_arvalid),
        .m_axi_arready           (m_axi_arready),
        .m_axi_rdata             (m_axi_rdata),
        .m_axi_rresp             (m_axi_rresp),
        .m_axi_rlast             (m_axi_rlast),
        .m_axi_rvalid            (m_axi_rvalid),
        .m_axi_rready            (m_axi_rready),

        // Dedicated NPU Complex Controls (Renamed RAM_IO lines)
        .npu_array_en            (npu_array_en),
        .npu_psum_systolic_en    (npu_psum_systolic_en),
        .npu_psum_lut_en         (npu_psum_lut_en),
        .npu_psum_skew_en        (npu_psum_skew_en),
        .npu_compute_bank_swap   (npu_compute_bank_swap),
        .npu_crossbar_sel        (npu_crossbar_sel),
        .npu_weight_shift_en     (npu_weight_shift_en),
        .npu_swap_weights        (npu_swap_weights),
        .npu_stochastic_round_en (npu_stochastic_round_en),

        // Weight & Activation SRAM Ports
        .npu_weight_shift_in     (npu_weight_in),
        .npu_ext_act_sram_we     (npu_act_we),
        .npu_ext_act_sram_addr   (npu_act_addr),

        // PSum Ports
        .npu_psum_A_addr         (npu_psum_A_addr),
        .npu_psum_A_we           (npu_psum_A_we),
        .npu_psum_A_wdata        (npu_psum_A_wdata),
        .npu_psum_A_read_bank_sel(npu_psum_A_read_bank_sel),
        .npu_psum_A_rdata        (npu_psum_A_rdata),

        .npu_psum_B_addr         (npu_psum_B_addr),
        .npu_psum_B_we           (npu_psum_B_we),
        .npu_psum_B_wdata        (npu_psum_B_wdata),
        .npu_psum_B_read_bank_sel(npu_psum_B_read_bank_sel),
        .npu_psum_B_rdata        (npu_psum_B_rdata),

        // Requantizer Shift & Streamed Output
        .npu_quant_shift_in      (npu_quant_shift_in),
        .npu_quant_shift_en      (npu_quant_shift_en),
        .npu_out_act             (npu_out_act),

        // Status & Interrupts
        .efpga_usr_irq_o         (efpga_usr_irq_o)
    );

endmodule
