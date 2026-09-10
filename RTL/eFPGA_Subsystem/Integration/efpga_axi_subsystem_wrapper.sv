`timescale 1ns / 1ps

module efpga_axi_subsystem_wrapper #(
    parameter int NUM_SLOTS    = 1,
    parameter int AXI_ID_WIDTH = 8
)(
    input  logic clk_i,
    input  logic rstn_i,

    // --- Control Path (AXI-Lite Slave, Driven by Connector) ---
    input  logic [NUM_SLOTS*32-1:0] ctrl_m_awaddr,
    input  logic [NUM_SLOTS*3-1:0]  ctrl_m_awprot,
    input  logic [NUM_SLOTS-1:0]    ctrl_m_awvalid,
    output logic [NUM_SLOTS-1:0]    ctrl_m_awready,
    input  logic [NUM_SLOTS*32-1:0] ctrl_m_wdata,
    input  logic [NUM_SLOTS*4-1:0]  ctrl_m_wstrb,
    input  logic [NUM_SLOTS-1:0]    ctrl_m_wvalid,
    output logic [NUM_SLOTS-1:0]    ctrl_m_wready,
    output logic [NUM_SLOTS*2-1:0]  ctrl_m_bresp,
    output logic [NUM_SLOTS-1:0]    ctrl_m_bvalid,
    input  logic [NUM_SLOTS-1:0]    ctrl_m_bready,
    input  logic [NUM_SLOTS*32-1:0] ctrl_m_araddr,
    input  logic [NUM_SLOTS*3-1:0]  ctrl_m_arprot,
    input  logic [NUM_SLOTS-1:0]    ctrl_m_arvalid,
    output logic [NUM_SLOTS-1:0]    ctrl_m_arready,
    output logic [NUM_SLOTS*32-1:0] ctrl_m_rdata,
    output logic [NUM_SLOTS*2-1:0]  ctrl_m_rresp,
    output logic [NUM_SLOTS-1:0]    ctrl_m_rvalid,
    input  logic [NUM_SLOTS-1:0]    ctrl_m_rready,

    // --- DMA Path (AXI-Full Master, Drives Connector) ---
    output logic [NUM_SLOTS*AXI_ID_WIDTH-1:0] dma_s_awid,
    output logic [NUM_SLOTS*32-1:0]           dma_s_awaddr,
    output logic [NUM_SLOTS*8-1:0]            dma_s_awlen,
    output logic [NUM_SLOTS*3-1:0]            dma_s_awsize,
    output logic [NUM_SLOTS*2-1:0]            dma_s_awburst,
    output logic [NUM_SLOTS-1:0]              dma_s_awlock,
    output logic [NUM_SLOTS*4-1:0]            dma_s_awcache,
    output logic [NUM_SLOTS*3-1:0]            dma_s_awprot,
    output logic [NUM_SLOTS-1:0]              dma_s_awvalid,
    input  logic [NUM_SLOTS-1:0]              dma_s_awready,
    output logic [NUM_SLOTS*32-1:0]           dma_s_wdata,
    output logic [NUM_SLOTS*4-1:0]            dma_s_wstrb,
    output logic [NUM_SLOTS-1:0]              dma_s_wlast,
    output logic [NUM_SLOTS-1:0]              dma_s_wvalid,
    input  logic [NUM_SLOTS-1:0]              dma_s_wready,
    input  logic [NUM_SLOTS*AXI_ID_WIDTH-1:0] dma_s_bid,
    input  logic [NUM_SLOTS*2-1:0]            dma_s_bresp,
    input  logic [NUM_SLOTS-1:0]              dma_s_bvalid,
    output logic [NUM_SLOTS-1:0]              dma_s_bready,
    output logic [NUM_SLOTS*AXI_ID_WIDTH-1:0] dma_s_arid,
    output logic [NUM_SLOTS*32-1:0]           dma_s_araddr,
    output logic [NUM_SLOTS*8-1:0]            dma_s_arlen,
    output logic [NUM_SLOTS*3-1:0]            dma_s_arsize,
    output logic [NUM_SLOTS*2-1:0]            dma_s_arburst,
    output logic [NUM_SLOTS-1:0]              dma_s_arlock,
    output logic [NUM_SLOTS*4-1:0]            dma_s_arcache,
    output logic [NUM_SLOTS*3-1:0]            dma_s_arprot,
    output logic [NUM_SLOTS-1:0]              dma_s_arvalid,
    input  logic [NUM_SLOTS-1:0]              dma_s_arready,
    input  logic [NUM_SLOTS*AXI_ID_WIDTH-1:0] dma_s_rid,
    input  logic [NUM_SLOTS*32-1:0]           dma_s_rdata,
    input  logic [NUM_SLOTS*2-1:0]            dma_s_rresp,
    input  logic [NUM_SLOTS-1:0]              dma_s_rlast,
    input  logic [NUM_SLOTS-1:0]              dma_s_rvalid,
    output logic [NUM_SLOTS-1:0]              dma_s_rready,

    // --- Direct Configuration & Status ---
    input  logic                              efpga_config_we_i,
    input  logic [31:0]                       efpga_config_data_i,
    input  logic                              efpga_soft_reset_i,
    output logic                              efpga_com_active_o,
    output logic [NUM_SLOTS-1:0][31:0]        slot_i_top_o,
    input  logic [NUM_SLOTS-1:0][31:0]        slot_o_top_i,

    // --- External PMOD Padring Interface (24 Wires) ---
    input  logic [7:0]                        pmod_io_i,
    output logic [7:0]                        pmod_io_o,
    output logic [7:0]                        pmod_io_oe_o,

    // --- Fabric User Interrupts (4 Lines) ---
    output logic [3:0]                        efpga_usr_irq_o
);

    // =========================================================================
    // Static DMA Master Defaults
    // =========================================================================
    assign dma_s_awid    = {NUM_SLOTS{AXI_ID_WIDTH'(1)}};
    assign dma_s_arid    = {NUM_SLOTS{AXI_ID_WIDTH'(1)}};
    assign dma_s_awlock  = {NUM_SLOTS{1'b0}};
    assign dma_s_arlock  = {NUM_SLOTS{1'b0}};
    assign dma_s_awcache = {NUM_SLOTS{4'd0}};
    assign dma_s_arcache = {NUM_SLOTS{4'd0}};
    assign dma_s_awprot  = {NUM_SLOTS{3'b000}};
    assign dma_s_arprot  = {NUM_SLOTS{3'b000}};

    // =========================================================================
    // Interconnect Buses (eFPGA <-> NPU & Floorplanned UIO)
    // =========================================================================
    // 1. Dedicated NPU Interface Buses
    wire [71:0] npu_act_addr;
    wire [63:0] npu_act_rdata;
    wire [63:0] npu_act_wdata;
    wire [7:0]  npu_act_we;
    wire [15:0] npu_addr;
    wire [63:0] npu_rdata;
    wire [5:0]  npu_read_bank_sel;
    wire [63:0] npu_wdata;
    wire [15:0] npu_we;
    wire [63:0] npu_weight_in;
    wire [63:0] npu_out_act;

    // 2. RAM_IO Passthrough Buses (East Edge: X=11, Y=1..2)
    wire [15:0] ram_a_o;
    wire [7:0]  ram_c_o;
    wire [31:0] ram_d_o;
    wire [31:0] ram_d_i = 32'd0;

    // 3. UIO Top (North Edge: X=1..6, Y=0)
    wire [119:0] uio_top_uin;
    wire [119:0] uio_top_uout;

    // 4. UIO Bottom (South Edge: X=1..10, Y=11)
    wire [199:0] uio_bot_uin;
    wire [199:0] uio_bot_uout;

    // =========================================================================
    // Floorplanned Mappings
    // =========================================================================
    // South-West: Debug I/O (Slot 0)
    assign uio_bot_uin[31:0]   = slot_o_top_i[0];    // DEBUG_OUT (Manager -> eFPGA)
    assign slot_i_top_o[0]     = uio_bot_uout[31:0]; // DEBUG_IN  (eFPGA -> Manager)

    // South: PMOD Padring Interface (24 Wires)
    assign uio_bot_uin[39:32]  = pmod_io_i;          // External PMOD In -> eFPGA
    assign pmod_io_o           = uio_bot_uout[39:32]; // eFPGA -> PMOD Out
    assign pmod_io_oe_o        = uio_bot_uout[47:40]; // eFPGA -> PMOD Direction/OE

    // South: Fabric User Interrupts (4 Lines)
    assign efpga_usr_irq_o     = uio_bot_uout[51:48]; // eFPGA -> SoC IRQ lines

    // Remaining South inputs tied off
    assign uio_bot_uin[199:40] = '0;                 // Unused South inputs

    // North-East: Requantizer Output Stream (NPU -> eFPGA)
    assign uio_top_uin[55:0]   = '0;                 // North-West inputs reserved
    assign uio_top_uin[119:56] = npu_out_act;        // North-East (X=4..6) <= out_act[63:0]

    // =========================================================================
    // 1. Single eFPGA Fabric Instance
    // =========================================================================
`ifdef ASIC_MACROS
    eFPGA_top_macro fabric_inst (
        // --- Clocks and Resets ---
        .CLK                 (clk_i),
        .resetn              (rstn_i & ~efpga_soft_reset_i),
        
        // --- Configuration Interface ---
        .SelfWriteData       (efpga_config_data_i),
        .SelfWriteStrobe     (efpga_config_we_i),
        .ComActive           (efpga_com_active_o),
        .Rx                  (1'b1),
        .s_clk               (1'b0),
        .s_data              (1'b0),
        .ReceiveLED          (),

        // --- Generic RAM_IO Wires (East Edge: X=11, Y=1..2) ---
        .RAM_A_O             (ram_a_o),
        .RAM_C_O             (ram_c_o),
        .RAM_D_O             (ram_d_o),
        .RAM_D_I             (ram_d_i),
        .Config_accessC      (),

        // --- General Purpose UIO (North & South Edges) ---
        .UIO_TOP_UIN         (uio_top_uin),
        .UIO_TOP_UOUT        (uio_top_uout),
        .UIO_BOT_UIN         (uio_bot_uin),
        .UIO_BOT_UOUT        (uio_bot_uout),

        // --- Slot 0: AXI-Lite Slave (Control from SoC) ---
        .AXIL_S_SOC_AWADDR   (ctrl_m_awaddr [9:0]),
        .AXIL_S_SOC_AWVALID  (ctrl_m_awvalid[0]),
        .AXIL_S_SOC_AWREADY  (ctrl_m_awready[0]),
        .AXIL_S_SOC_WDATA    (ctrl_m_wdata  [31:0]),
        .AXIL_S_SOC_WSTRB    (ctrl_m_wstrb  [3:0]),
        .AXIL_S_SOC_WVALID   (ctrl_m_wvalid [0]),
        .AXIL_S_SOC_WREADY   (ctrl_m_wready [0]),
        .AXIL_S_SOC_BRESP    (ctrl_m_bresp  [1:0]),
        .AXIL_S_SOC_BVALID   (ctrl_m_bvalid [0]),
        .AXIL_S_SOC_BREADY   (ctrl_m_bready [0]),
        .AXIL_S_SOC_ARADDR   (ctrl_m_araddr [9:0]),
        .AXIL_S_SOC_ARVALID  (ctrl_m_arvalid[0]),
        .AXIL_S_SOC_ARREADY  (ctrl_m_arready[0]),
        .AXIL_S_SOC_RDATA    (ctrl_m_rdata  [31:0]),
        .AXIL_S_SOC_RRESP    (ctrl_m_rresp  [1:0]),
        .AXIL_S_SOC_RVALID   (ctrl_m_rvalid [0]),
        .AXIL_S_SOC_RREADY   (ctrl_m_rready [0]),

        // --- Slot 0: AXI-Full Master (DMA to SoC) ---
        .AXI_M_SOC_AWADDR    (dma_s_awaddr  [31:0]),
        .AXI_M_SOC_AWLEN     (dma_s_awlen   [7:0]),
        .AXI_M_SOC_AWSIZE    (dma_s_awsize  [2:0]),
        .AXI_M_SOC_AWBURST   (dma_s_awburst [1:0]),
        .AXI_M_SOC_AWVALID   (dma_s_awvalid [0]),
        .AXI_M_SOC_AWREADY   (dma_s_awready [0]),
        .AXI_M_SOC_WDATA     (dma_s_wdata   [31:0]),
        .AXI_M_SOC_WSTRB     (dma_s_wstrb   [3:0]),
        .AXI_M_SOC_WLAST     (dma_s_wlast   [0]),
        .AXI_M_SOC_WVALID    (dma_s_wvalid  [0]),
        .AXI_M_SOC_WREADY    (dma_s_wready  [0]),
        .AXI_M_SOC_BRESP     (dma_s_bresp   [1:0]),
        .AXI_M_SOC_BVALID    (dma_s_bvalid  [0]),
        .AXI_M_SOC_BREADY    (dma_s_bready  [0]),
        .AXI_M_SOC_ARADDR    (dma_s_araddr  [31:0]),
        .AXI_M_SOC_ARLEN     (dma_s_arlen   [7:0]),
        .AXI_M_SOC_ARSIZE    (dma_s_arsize  [2:0]),
        .AXI_M_SOC_ARBURST   (dma_s_arburst [1:0]),
        .AXI_M_SOC_ARVALID   (dma_s_arvalid [0]),
        .AXI_M_SOC_ARREADY   (dma_s_arready [0]),
        .AXI_M_SOC_RDATA     (dma_s_rdata   [31:0]),
        .AXI_M_SOC_RRESP     (dma_s_rresp   [1:0]),
        .AXI_M_SOC_RLAST     (dma_s_rlast   [0]),
        .AXI_M_SOC_RVALID    (dma_s_rvalid  [0]),
        .AXI_M_SOC_RREADY    (dma_s_rready  [0]),

        // --- Dedicated NPU Hard Interface Ports ---
        .NPU_ACT_ADDR        (npu_act_addr),
        .NPU_ACT_RDATA       (npu_act_rdata),
        .NPU_ACT_WDATA       (npu_act_wdata),
        .NPU_ACT_WE          (npu_act_we),
        .NPU_ADDR            (npu_addr),
        .NPU_RDATA           (npu_rdata),
        .NPU_READ_BANK_SEL   (npu_read_bank_sel),
        .NPU_WDATA           (npu_wdata),
        .NPU_WE              (npu_we),
        .NPU_WEIGHT_IN       (npu_weight_in)
    );
`else
    eFPGA_top fabric_inst (
        // --- Clocks and Resets ---
        .CLK                 (clk_i),
        .resetn              (rstn_i & ~efpga_soft_reset_i),
        
        // --- Configuration Interface ---
        .SelfWriteData       (efpga_config_data_i),
        .SelfWriteStrobe     (efpga_config_we_i),
        .ComActive           (efpga_com_active_o),
        .Rx                  (1'b1),
        .s_clk               (1'b0),
        .s_data              (1'b0),
        .ReceiveLED          (),

        // --- Generic RAM_IO Wires (East Edge: X=11, Y=1..2) ---
        .RAM_A_O             (ram_a_o),
        .RAM_C_O             (ram_c_o),
        .RAM_D_O             (ram_d_o),
        .RAM_D_I             (ram_d_i),
        .Config_accessC      (),

        // --- General Purpose UIO (North & South Edges) ---
        .UIO_TOP_UIN         (uio_top_uin),
        .UIO_TOP_UOUT        (uio_top_uout),
        .UIO_BOT_UIN         (uio_bot_uin),
        .UIO_BOT_UOUT        (uio_bot_uout),

        // --- Slot 0: AXI-Lite Slave (Control from SoC) ---
        .AXIL_S_SOC_AWADDR   (ctrl_m_awaddr [9:0]),
        .AXIL_S_SOC_AWVALID  (ctrl_m_awvalid[0]),
        .AXIL_S_SOC_AWREADY  (ctrl_m_awready[0]),
        .AXIL_S_SOC_WDATA    (ctrl_m_wdata  [31:0]),
        .AXIL_S_SOC_WSTRB    (ctrl_m_wstrb  [3:0]),
        .AXIL_S_SOC_WVALID   (ctrl_m_wvalid [0]),
        .AXIL_S_SOC_WREADY   (ctrl_m_wready [0]),
        .AXIL_S_SOC_BRESP    (ctrl_m_bresp  [1:0]),
        .AXIL_S_SOC_BVALID   (ctrl_m_bvalid [0]),
        .AXIL_S_SOC_BREADY   (ctrl_m_bready [0]),
        .AXIL_S_SOC_ARADDR   (ctrl_m_araddr [9:0]),
        .AXIL_S_SOC_ARVALID  (ctrl_m_arvalid[0]),
        .AXIL_S_SOC_ARREADY  (ctrl_m_arready[0]),
        .AXIL_S_SOC_RDATA    (ctrl_m_rdata  [31:0]),
        .AXIL_S_SOC_RRESP    (ctrl_m_rresp  [1:0]),
        .AXIL_S_SOC_RVALID   (ctrl_m_rvalid [0]),
        .AXIL_S_SOC_RREADY   (ctrl_m_rready [0]),

        // --- Slot 0: AXI-Full Master (DMA to SoC) ---
        .AXI_M_SOC_AWADDR    (dma_s_awaddr  [31:0]),
        .AXI_M_SOC_AWLEN     (dma_s_awlen   [7:0]),
        .AXI_M_SOC_AWSIZE    (dma_s_arsize  [2:0]),
        .AXI_M_SOC_AWBURST   (dma_s_awburst [1:0]),
        .AXI_M_SOC_AWVALID   (dma_s_awvalid [0]),
        .AXI_M_SOC_AWREADY   (dma_s_awready [0]),
        .AXI_M_SOC_WDATA     (dma_s_wdata   [31:0]),
        .AXI_M_SOC_WSTRB     (dma_s_wstrb   [3:0]),
        .AXI_M_SOC_WLAST     (dma_s_wlast   [0]),
        .AXI_M_SOC_WVALID    (dma_s_wvalid  [0]),
        .AXI_M_SOC_WREADY    (dma_s_wready  [0]),
        .AXI_M_SOC_BRESP     (dma_s_bresp   [1:0]),
        .AXI_M_SOC_BVALID    (dma_s_bvalid  [0]),
        .AXI_M_SOC_BREADY    (dma_s_bready  [0]),
        .AXI_M_SOC_ARADDR    (dma_s_araddr  [31:0]),
        .AXI_M_SOC_ARLEN     (dma_s_arlen   [7:0]),
        .AXI_M_SOC_ARSIZE    (dma_s_arsize  [2:0]),
        .AXI_M_SOC_ARBURST   (dma_s_arburst [1:0]),
        .AXI_M_SOC_ARVALID   (dma_s_arvalid [0]),
        .AXI_M_SOC_ARREADY   (dma_s_arready [0]),
        .AXI_M_SOC_RDATA     (dma_s_rdata   [31:0]),
        .AXI_M_SOC_RRESP     (dma_s_rresp   [1:0]),
        .AXI_M_SOC_RLAST     (dma_s_rlast   [0]),
        .AXI_M_SOC_RVALID    (dma_s_rvalid  [0]),
        .AXI_M_SOC_RREADY    (dma_s_rready  [0]),

        // --- Dedicated NPU Hard Interface Ports ---
        .NPU_ACT_ADDR        (npu_act_addr),
        .NPU_ACT_RDATA       (npu_act_rdata),
        .NPU_ACT_WDATA       (npu_act_wdata),
        .NPU_ACT_WE          (npu_act_we),
        .NPU_ADDR            (npu_addr),
        .NPU_RDATA           (npu_rdata),
        .NPU_READ_BANK_SEL   (npu_read_bank_sel),
        .NPU_WDATA           (npu_wdata),
        .NPU_WE              (npu_we),
        .NPU_WEIGHT_IN       (npu_weight_in)
    );
`endif

    // =========================================================================
    // 2. Single NPU Core Instance
    // =========================================================================
    npu_wrapper #(
        .ARRAY_HEIGHT        (8),
        .ARRAY_WIDTH         (8),
        .TILE_SIZE           (16),
        .ACT_HALO_PAD        (2),
        .ACTIVATION_WIDTH    (8),
        .WEIGHT_WIDTH        (8),
        .PSUM_WIDTH          (32),
        .SCALE_WIDTH         (16),
        .ENABLE_LFSR         (0),
        .WEIGHT_SPLIT        (2)
    ) npu_inst (
        .clk_i               (clk_i),
        .rst_n               (rstn_i & ~efpga_soft_reset_i),

        .crossbar_sel        (ram_d_o),

        .array_en            (ram_c_o[0]),
        .psum_systolic_en    (ram_c_o[1]),
        .psum_lut_en         (ram_c_o[2]),
        .weight_shift_en     ({ram_a_o[0], ram_c_o[3]}), // [1]: Rows 4..7, [0]: Rows 0..3
        .swap_weights        (ram_c_o[4]),
        .stochastic_round_en (ram_c_o[5]),
        .psum_skew_en        (ram_c_o[6]),
        .compute_bank_swap   (ram_c_o[7]),

        .weight_shift_in     (npu_weight_in),

        .quant_shift_in      (uio_top_uout[118:89]),
        .quant_shift_en      (uio_top_uout[119]),
        .lfsr_data_out       (),

        .psum_A_addr         (npu_addr[7:0]),
        .psum_A_we           (npu_we[7:0]),
        .psum_A_wdata        (npu_wdata[31:0]),
        .psum_A_read_bank_sel(npu_read_bank_sel[2:0]),
        .psum_A_rdata        (npu_rdata[31:0]),

        .psum_B_addr         (npu_addr[15:8]),
        .psum_B_we           (npu_we[15:8]),
        .psum_B_wdata        (npu_wdata[63:32]),
        .psum_B_read_bank_sel(npu_read_bank_sel[5:3]),
        .psum_B_rdata        (npu_rdata[63:32]),

        .ext_act_sram_we     (npu_act_we),
        .ext_act_sram_addr   (npu_act_addr),
        .ext_act_sram_wdata  (npu_act_wdata),
        .act_sram_rdata      (npu_act_rdata),

        .out_act             (npu_out_act)
    );

endmodule