// =============================================================================
// File: TEST/SoftLogic/common/efpga_boundary_harness.sv
// Module: efpga_boundary_harness
// Project: CrocoScale SoC -- eFPGA Perimeter BEL Boundary Test Harness
//
// Description:
//   Instantiates the exact physical boundary BELs of the CrocoScale 9x16 eFPGA
//   fabric without any internal logic, multiplexers, or artificial zero-padding.
//   Serves as a transparent, cycle-accurate physical perimeter model:
//
//   - West Edge:
//       1x AXIL_S_BEL          (Rows 10..15: Asynchronous pass-through, 10-bit address)
//       1x AXI_M_BEL           (Rows 0..9:   Asynchronous with tie-offs)
//   - North Edge:
//       1x NPU_CTRL_CFG_BEL    (Cols 3..4:   +1 cycle launch to NPU)
//       1x NPU_ACCUM_SRAM_BEL  (Cols 5..9:   Bank A, +1 cyc launch, +1 cyc capture)
//   - East Edge:
//       8x NPU_SLICE_DATA_SRAM_BEL (Rows 0..15: Slices 0..7, +1 launch, +1 capture)
//   - South Edge:
//       1x NPU_ACCUM_SRAM_BEL  (Cols 5..9:   Bank B, +1 cyc launch, +1 cyc capture)
//       4x SOC_DEBUG_CTRL_BEL  (Cols 1..4:   Slots 0..3, soft reset & user IRQ)
// =============================================================================

`timescale 1ns / 1ps

module efpga_boundary_harness #(
    parameter int ARRAY_HEIGHT     = 8,
    parameter int ARRAY_WIDTH      = 8,
    parameter int ACTIVATION_WIDTH = 8,
    parameter int WEIGHT_WIDTH     = 8,
    parameter int PSUM_WIDTH       = 32,

    // Static BEL Configuration Words
    parameter bit [11:0] CFG_AXI_M       = 12'h000,
    parameter bit [47:0] CFG_SLICE       = 48'h0,
    parameter bit [7:0]  CFG_ACCUM_A     = 8'h00,
    parameter bit [7:0]  CFG_ACCUM_B     = 8'h00,
    parameter bit [0:0]  CFG_NPU_CTRL    = 1'b0,
    parameter bit [15:0] CFG_DEBUG       = 16'h0
) (
    input  wire                                                          clk_i,

    // =========================================================================
    // External / SoC Facing Ports (Driven by TB / CPU / Interconnect / RAM)
    // =========================================================================

    // CPU Control: AXI-Lite Slave Interface (from TB)
    input  wire        [9:0]                                             s_axil_awaddr,
    input  wire        [2:0]                                             s_axil_awprot,
    input  wire                                                          s_axil_awvalid,
    output wire                                                          s_axil_awready,
    input  wire        [31:0]                                            s_axil_wdata,
    input  wire        [3:0]                                             s_axil_wstrb,
    input  wire                                                          s_axil_wvalid,
    output wire                                                          s_axil_wready,
    output wire        [1:0]                                             s_axil_bresp,
    output wire                                                          s_axil_bvalid,
    input  wire                                                          s_axil_bready,
    input  wire        [9:0]                                             s_axil_araddr,
    input  wire        [2:0]                                             s_axil_arprot,
    input  wire                                                          s_axil_arvalid,
    output wire                                                          s_axil_arready,
    output wire        [31:0]                                            s_axil_rdata,
    output wire        [1:0]                                             s_axil_rresp,
    output wire                                                          s_axil_rvalid,
    input  wire                                                          s_axil_rready,

    // DMA Master: AXI4 Master Interface (to System RAM)
    output wire        [31:0]                                            m_axi_awaddr,
    output wire        [7:0]                                             m_axi_awlen,
    output wire        [2:0]                                             m_axi_awsize,
    output wire        [1:0]                                             m_axi_awburst,
    output wire                                                          m_axi_awlock,
    output wire        [3:0]                                             m_axi_awcache,
    output wire                                                          m_axi_awvalid,
    input  wire                                                          m_axi_awready,
    output wire        [31:0]                                            m_axi_wdata,
    output wire        [3:0]                                             m_axi_wstrb,
    output wire                                                          m_axi_wlast,
    output wire                                                          m_axi_wvalid,
    input  wire                                                          m_axi_wready,
    input  wire        [1:0]                                             m_axi_bresp,
    input  wire                                                          m_axi_bvalid,
    output wire                                                          m_axi_bready,
    output wire        [31:0]                                            m_axi_araddr,
    output wire        [7:0]                                             m_axi_arlen,
    output wire        [2:0]                                             m_axi_arsize,
    output wire        [1:0]                                             m_axi_arburst,
    output wire                                                          m_axi_arlock,
    output wire        [3:0]                                             m_axi_arcache,
    output wire                                                          m_axi_arvalid,
    input  wire                                                          m_axi_arready,
    input  wire        [31:0]                                            m_axi_rdata,
    input  wire        [1:0]                                             m_axi_rresp,
    input  wire                                                          m_axi_rlast,
    input  wire                                                          m_axi_rvalid,
    output wire                                                          m_axi_rready,

    // SoC Debug & Control / IRQ
    input  wire        [3:0][7:0]                                        soc_debug_out_i,
    output wire        [3:0][7:0]                                        soc_debug_in_o,
    output wire        [3:0]                                             soc_usr_irq_o,
    input  wire        [3:0]                                             soc_slot_soft_rst_n_i,

    // =========================================================================
    // NPU Facing Ports (Connected to npu_wrapper / npu_top)
    // =========================================================================
    output wire                                                          npu_array_en,
    output wire                                                          npu_psum_systolic_en,
    output wire                                                          npu_psum_lut_en,
    output wire                                                          npu_psum_skew_en,
    output wire                                                          npu_compute_bank_swap,
    output wire                                                          npu_swap_weights,
    output wire        [29:0]                                            npu_quant_shift_in,
    output wire                                                          npu_quant_shift_en,

    output wire        [ARRAY_HEIGHT-1:0][3:0]                           npu_crossbar_sel,
    output wire signed [ARRAY_HEIGHT-1:0][WEIGHT_WIDTH-1:0]              npu_weight_shift_in,
    output wire        [ARRAY_HEIGHT-1:0]                                npu_weight_shift_en,

    output wire        [ARRAY_HEIGHT-1:0]                                npu_ext_act_sram_we,
    output wire        [ARRAY_HEIGHT-1:0][8:0]                           npu_ext_act_sram_addr,
    output wire        [ARRAY_HEIGHT-1:0][ACTIVATION_WIDTH-1:0]          npu_ext_act_sram_wdata,
    input  wire        [ARRAY_HEIGHT-1:0][ACTIVATION_WIDTH-1:0]          npu_act_sram_rdata,
    input  wire        [ARRAY_WIDTH-1:0][ACTIVATION_WIDTH-1:0]           npu_out_act,

    output wire        [7:0]                                             npu_psum_A_addr,
    output wire        [ARRAY_WIDTH-1:0]                                 npu_psum_A_we,
    output wire signed [PSUM_WIDTH-1:0]                                  npu_psum_A_wdata,
    output wire        [2:0]                                             npu_psum_A_read_bank_sel,
    input  wire signed [PSUM_WIDTH-1:0]                                  npu_psum_A_rdata,

    output wire        [7:0]                                             npu_psum_B_addr,
    output wire        [ARRAY_WIDTH-1:0]                                 npu_psum_B_we,
    output wire signed [PSUM_WIDTH-1:0]                                  npu_psum_B_wdata,
    output wire        [2:0]                                             npu_psum_B_read_bank_sel,
    input  wire signed [PSUM_WIDTH-1:0]                                  npu_psum_B_rdata,

    // =========================================================================
    // Fabric Facing Ports (Connected to SoftLogic Controller DUT)
    // =========================================================================

    // Fabric AXI-Lite Slave (to DUT s_axil_*)
    output wire        [9:0]                                             fab_axil_awaddr,
    output wire        [2:0]                                             fab_axil_awprot,
    output wire                                                          fab_axil_awvalid,
    input  wire                                                          fab_axil_awready,
    output wire        [31:0]                                            fab_axil_wdata,
    output wire        [3:0]                                             fab_axil_wstrb,
    output wire                                                          fab_axil_wvalid,
    input  wire                                                          fab_axil_wready,
    input  wire        [1:0]                                             fab_axil_bresp,
    input  wire                                                          fab_axil_bvalid,
    output wire                                                          fab_axil_bready,
    output wire        [9:0]                                             fab_axil_araddr,
    output wire        [2:0]                                             fab_axil_arprot,
    output wire                                                          fab_axil_arvalid,
    input  wire                                                          fab_axil_arready,
    input  wire        [31:0]                                            fab_axil_rdata,
    input  wire        [1:0]                                             fab_axil_rresp,
    input  wire                                                          fab_axil_rvalid,
    output wire                                                          fab_axil_rready,

    // Fabric AXI Master (from DUT m_axi_*)
    input  wire        [31:0]                                            fab_axi_awaddr,
    input  wire        [7:0]                                             fab_axi_awlen,
    input  wire        [2:0]                                             fab_axi_awsize,
    input  wire        [1:0]                                             fab_axi_awburst,
    input  wire                                                          fab_axi_awlock,
    input  wire        [3:0]                                             fab_axi_awcache,
    input  wire                                                          fab_axi_awvalid,
    output wire                                                          fab_axi_awready,
    input  wire        [31:0]                                            fab_axi_wdata,
    input  wire        [3:0]                                             fab_axi_wstrb,
    input  wire                                                          fab_axi_wlast,
    input  wire                                                          fab_axi_wvalid,
    output wire                                                          fab_axi_wready,
    output wire        [1:0]                                             fab_axi_bresp,
    output wire                                                          fab_axi_bvalid,
    input  wire                                                          fab_axi_bready,
    input  wire        [31:0]                                            fab_axi_araddr,
    input  wire        [7:0]                                             fab_axi_arlen,
    input  wire        [2:0]                                             fab_axi_arsize,
    input  wire        [1:0]                                             fab_axi_arburst,
    input  wire                                                          fab_axi_arlock,
    input  wire        [3:0]                                             fab_axi_arcache,
    input  wire                                                          fab_axi_arvalid,
    output wire                                                          fab_axi_arready,
    output wire        [31:0]                                            fab_axi_rdata,
    output wire        [1:0]                                             fab_axi_rresp,
    output wire                                                          fab_axi_rlast,
    output wire                                                          fab_axi_rvalid,
    input  wire                                                          fab_axi_rready,

    // Fabric NPU Control (from DUT npu_*)
    input  wire                                                          fab_npu_array_en,
    input  wire                                                          fab_npu_psum_systolic_en,
    input  wire                                                          fab_npu_psum_lut_en,
    input  wire                                                          fab_npu_psum_skew_en,
    input  wire                                                          fab_npu_compute_bank_swap,
    input  wire                                                          fab_npu_swap_weights,
    input  wire        [29:0]                                            fab_npu_quant_shift_in,
    input  wire                                                          fab_npu_quant_shift_en,

    input  wire        [ARRAY_HEIGHT-1:0][3:0]                           fab_crossbar_sel,
    input  wire signed [ARRAY_HEIGHT-1:0][WEIGHT_WIDTH-1:0]              fab_weight_shift_in,
    input  wire        [ARRAY_HEIGHT-1:0]                                fab_weight_shift_en,

    input  wire        [ARRAY_HEIGHT-1:0]                                fab_ext_act_sram_we,
    input  wire        [ARRAY_HEIGHT-1:0][8:0]                           fab_ext_act_sram_addr,
    input  wire        [ARRAY_HEIGHT-1:0][ACTIVATION_WIDTH-1:0]          fab_ext_act_sram_wdata,
    output wire        [ARRAY_HEIGHT-1:0][ACTIVATION_WIDTH-1:0]          fab_act_sram_rdata,
    output wire        [ARRAY_WIDTH-1:0][ACTIVATION_WIDTH-1:0]           fab_out_act,

    input  wire        [7:0]                                             fab_psum_A_addr,
    input  wire        [ARRAY_WIDTH-1:0]                                 fab_psum_A_we,
    input  wire signed [PSUM_WIDTH-1:0]                                  fab_psum_A_wdata,
    input  wire        [2:0]                                             fab_psum_A_read_bank_sel,
    output wire signed [PSUM_WIDTH-1:0]                                  fab_psum_A_rdata,

    input  wire        [7:0]                                             fab_psum_B_addr,
    input  wire        [ARRAY_WIDTH-1:0]                                 fab_psum_B_we,
    input  wire signed [PSUM_WIDTH-1:0]                                  fab_psum_B_wdata,
    input  wire        [2:0]                                             fab_psum_B_read_bank_sel,
    output wire signed [PSUM_WIDTH-1:0]                                  fab_psum_B_rdata,

    // Fabric Debug & Control / IRQ
    output wire        [3:0][7:0]                                        fab_debug_out_o,
    input  wire        [3:0][7:0]                                        fab_debug_in_i,
    input  wire        [3:0]                                             fab_usr_irq_i,
    output wire        [3:0]                                             fab_slot_soft_rst_n_o
);

    // =========================================================================
    // 1. West Edge: AXI-Lite Slave BEL (Rows 10..15)
    // =========================================================================
    AXIL_S_BEL u_axil_s_bel (
        .SOC_AWADDR  (s_axil_awaddr),
        .SOC_AWPROT  (s_axil_awprot),
        .SOC_AWVALID (s_axil_awvalid),
        .SOC_AWREADY (s_axil_awready),
        .SOC_WDATA   (s_axil_wdata),
        .SOC_WSTRB   (s_axil_wstrb),
        .SOC_WVALID  (s_axil_wvalid),
        .SOC_WREADY  (s_axil_wready),
        .SOC_BRESP   (s_axil_bresp),
        .SOC_BVALID  (s_axil_bvalid),
        .SOC_BREADY  (s_axil_bready),
        .SOC_ARADDR  (s_axil_araddr),
        .SOC_ARPROT  (s_axil_arprot),
        .SOC_ARVALID (s_axil_arvalid),
        .SOC_ARREADY (s_axil_arready),
        .SOC_RDATA   (s_axil_rdata),
        .SOC_RRESP   (s_axil_rresp),
        .SOC_RVALID  (s_axil_rvalid),
        .SOC_RREADY  (s_axil_rready),

        .FAB_AWADDR  (fab_axil_awaddr),
        .FAB_AWPROT  (fab_axil_awprot),
        .FAB_AWVALID (fab_axil_awvalid),
        .FAB_AWREADY (fab_axil_awready),
        .FAB_WDATA   (fab_axil_wdata),
        .FAB_WSTRB   (fab_axil_wstrb),
        .FAB_WVALID  (fab_axil_wvalid),
        .FAB_WREADY  (fab_axil_wready),
        .FAB_BRESP   (fab_axil_bresp),
        .FAB_BVALID  (fab_axil_bvalid),
        .FAB_BREADY  (fab_axil_bready),
        .FAB_ARADDR  (fab_axil_araddr),
        .FAB_ARPROT  (fab_axil_arprot),
        .FAB_ARVALID (fab_axil_arvalid),
        .FAB_ARREADY (fab_axil_arready),
        .FAB_RDATA   (fab_axil_rdata),
        .FAB_RRESP   (fab_axil_rresp),
        .FAB_RVALID  (fab_axil_rvalid),
        .FAB_RREADY  (fab_axil_rready)
    );

    // =========================================================================
    // 2. West Edge: AXI4 Master BEL (Rows 0..9)
    // =========================================================================
    AXI_M_BEL #(
        .NoConfigBits(12)
    ) u_axi_m_bel (
        .SOC_AWADDR  (m_axi_awaddr),
        .SOC_AWLEN   (m_axi_awlen),
        .SOC_AWSIZE  (m_axi_awsize),
        .SOC_AWBURST (m_axi_awburst),
        .SOC_AWLOCK  (m_axi_awlock),
        .SOC_AWCACHE (m_axi_awcache),
        .SOC_AWVALID (m_axi_awvalid),
        .SOC_AWREADY (m_axi_awready),
        .SOC_WDATA   (m_axi_wdata),
        .SOC_WSTRB   (m_axi_wstrb),
        .SOC_WLAST   (m_axi_wlast),
        .SOC_WVALID  (m_axi_wvalid),
        .SOC_WREADY  (m_axi_wready),
        .SOC_BRESP   (m_axi_bresp),
        .SOC_BVALID  (m_axi_bvalid),
        .SOC_BREADY  (m_axi_bready),
        .SOC_ARADDR  (m_axi_araddr),
        .SOC_ARLEN   (m_axi_arlen),
        .SOC_ARSIZE  (m_axi_arsize),
        .SOC_ARBURST (m_axi_arburst),
        .SOC_ARLOCK  (m_axi_arlock),
        .SOC_ARCACHE (m_axi_arcache),
        .SOC_ARVALID (m_axi_arvalid),
        .SOC_ARREADY (m_axi_arready),
        .SOC_RDATA   (m_axi_rdata),
        .SOC_RRESP   (m_axi_rresp),
        .SOC_RLAST   (m_axi_rlast),
        .SOC_RVALID  (m_axi_rvalid),
        .SOC_RREADY  (m_axi_rready),

        .FAB_AWADDR  (fab_axi_awaddr),
        .FAB_AWLEN   (fab_axi_awlen),
        .FAB_AWSIZE  (fab_axi_awsize),
        .FAB_AWBURST (fab_axi_awburst),
        .FAB_AWLOCK  (fab_axi_awlock),
        .FAB_AWCACHE (fab_axi_awcache),
        .FAB_AWVALID (fab_axi_awvalid),
        .FAB_AWREADY (fab_axi_awready),
        .FAB_WDATA   (fab_axi_wdata),
        .FAB_WSTRB   (fab_axi_wstrb),
        .FAB_WLAST   (fab_axi_wlast),
        .FAB_WVALID  (fab_axi_wvalid),
        .FAB_WREADY  (fab_axi_wready),
        .FAB_BRESP   (fab_axi_bresp),
        .FAB_BVALID  (fab_axi_bvalid),
        .FAB_BREADY  (fab_axi_bready),
        .FAB_ARADDR  (fab_axi_araddr),
        .FAB_ARLEN   (fab_axi_arlen),
        .FAB_ARSIZE  (fab_axi_arsize),
        .FAB_ARBURST (fab_axi_arburst),
        .FAB_ARLOCK  (fab_axi_arlock),
        .FAB_ARCACHE (fab_axi_arcache),
        .FAB_ARVALID (fab_axi_arvalid),
        .FAB_ARREADY (fab_axi_arready),
        .FAB_RDATA   (fab_axi_rdata),
        .FAB_RRESP   (fab_axi_rresp),
        .FAB_RLAST   (fab_axi_rlast),
        .FAB_RVALID  (fab_axi_rvalid),
        .FAB_RREADY  (fab_axi_rready),

        .ConfigBits  (CFG_AXI_M)
    );

    // =========================================================================
    // 3. North Edge: NPU Control & Quantization Config BEL (Cols 3..4)
    // =========================================================================
    NPU_CTRL_CFG_BEL #(
        .NoConfigBits(1)
    ) u_npu_ctrl_cfg_bel (
        .NPU_QUANT_SHIFT_IN    (npu_quant_shift_in),
        .NPU_QUANT_SHIFT_EN    (npu_quant_shift_en),
        .NPU_ARRAY_EN          (npu_array_en),
        .NPU_PSUM_SYSTOLIC_EN  (npu_psum_systolic_en),
        .NPU_PSUM_LUT_EN       (npu_psum_lut_en),
        .NPU_SWAP_WEIGHTS      (npu_swap_weights),
        .NPU_PSUM_SKEW_EN      (npu_psum_skew_en),
        .NPU_COMPUTE_BANK_SWAP (npu_compute_bank_swap),

        .FAB_QUANT_SHIFT_IN    (fab_npu_quant_shift_in),
        .FAB_QUANT_SHIFT_EN    (fab_npu_quant_shift_en),
        .FAB_ARRAY_EN          (fab_npu_array_en),
        .FAB_PSUM_SYSTOLIC_EN  (fab_npu_psum_systolic_en),
        .FAB_PSUM_LUT_EN       (fab_npu_psum_lut_en),
        .FAB_SWAP_WEIGHTS      (fab_npu_swap_weights),
        .FAB_PSUM_SKEW_EN      (fab_npu_psum_skew_en),
        .FAB_COMPUTE_BANK_SWAP (fab_npu_compute_bank_swap),

        .UserCLK               (clk_i),
        .ConfigBits            (CFG_NPU_CTRL)
    );

    // =========================================================================
    // 4. North & South Edges: PSUM Accumulator SRAM BELs (Cols 5..9)
    // =========================================================================
    NPU_ACCUM_SRAM_BEL #(
        .NoConfigBits(8)
    ) u_accum_bel_a (
        .NPU_ADDR          (npu_psum_A_addr),
        .NPU_WE            (npu_psum_A_we),
        .NPU_WDATA         (npu_psum_A_wdata),
        .NPU_READ_BANK_SEL (npu_psum_A_read_bank_sel),
        .NPU_RDATA         (npu_psum_A_rdata),

        .FAB_ADDR          (fab_psum_A_addr),
        .FAB_WE            (fab_psum_A_we),
        .FAB_WDATA         (fab_psum_A_wdata),
        .FAB_READ_BANK_SEL (fab_psum_A_read_bank_sel),
        .FAB_RDATA         (fab_psum_A_rdata),

        .UserCLK           (clk_i),
        .ConfigBits        (CFG_ACCUM_A)
    );

    NPU_ACCUM_SRAM_BEL #(
        .NoConfigBits(8)
    ) u_accum_bel_b (
        .NPU_ADDR          (npu_psum_B_addr),
        .NPU_WE            (npu_psum_B_we),
        .NPU_WDATA         (npu_psum_B_wdata),
        .NPU_READ_BANK_SEL (npu_psum_B_read_bank_sel),
        .NPU_RDATA         (npu_psum_B_rdata),

        .FAB_ADDR          (fab_psum_B_addr),
        .FAB_WE            (fab_psum_B_we),
        .FAB_WDATA         (fab_psum_B_wdata),
        .FAB_READ_BANK_SEL (fab_psum_B_read_bank_sel),
        .FAB_RDATA         (fab_psum_B_rdata),

        .UserCLK           (clk_i),
        .ConfigBits        (CFG_ACCUM_B)
    );

    // =========================================================================
    // 5. East Edge: NPU Slice Data & Activation SRAM BELs (Rows 0..15)
    // =========================================================================
    generate
        for (genvar r = 0; r < ARRAY_HEIGHT; r = r + 1) begin : gen_slice
            NPU_SLICE_DATA_SRAM_BEL #(
                .NoConfigBits(6)
            ) u_slice_bel (
                .NPU_ACT_ADDR        (npu_ext_act_sram_addr[r]),
                .NPU_ACT_WDATA       (npu_ext_act_sram_wdata[r]),
                .NPU_ACT_RDATA       (npu_act_sram_rdata[r]),
                .NPU_ACT_WE          (npu_ext_act_sram_we[r]),
                .NPU_WEIGHT_IN       (npu_weight_shift_in[r]),
                .NPU_WEIGHT_SHIFT_EN (npu_weight_shift_en[r]),
                .NPU_XBAR_SEL        (npu_crossbar_sel[r]),
                .NPU_OUT_ACT         (npu_out_act[r]),

                .FAB_ACT_ADDR        (fab_ext_act_sram_addr[r]),
                .FAB_ACT_WDATA       (fab_ext_act_sram_wdata[r]),
                .FAB_ACT_RDATA       (fab_act_sram_rdata[r]),
                .FAB_ACT_WE          (fab_ext_act_sram_we[r]),
                .FAB_WEIGHT_IN       (fab_weight_shift_in[r]),
                .FAB_WEIGHT_SHIFT_EN (fab_weight_shift_en[r]),
                .FAB_XBAR_SEL        (fab_crossbar_sel[r]),
                .FAB_OUT_ACT         (fab_out_act[r]),

                .UserCLK             (clk_i),
                .ConfigBits          (CFG_SLICE[r*6 +: 6])
            );
        end
    endgenerate

    // =========================================================================
    // 6. South Edge: SoC Debug & Control BELs (Cols 1..4)
    // =========================================================================
    generate
        for (genvar s = 0; s < 4; s = s + 1) begin : gen_debug
            SOC_DEBUG_CTRL_BEL #(
                .NoConfigBits(4)
            ) u_debug_bel (
                .DEBUG_OUT           (soc_debug_out_i[s]),
                .DEBUG_IN            (soc_debug_in_o[s]),
                .USR_IRQ             (soc_usr_irq_o[s]),
                .SLOT_SOFT_RST_N     (soc_slot_soft_rst_n_i[s]),

                .FAB_DEBUG_OUT       (fab_debug_out_o[s]),
                .FAB_DEBUG_IN        (fab_debug_in_i[s]),
                .FAB_USR_IRQ         (fab_usr_irq_i[s]),
                .FAB_SLOT_SOFT_RST_N (fab_slot_soft_rst_n_o[s]),

                .UserCLK             (clk_i),
                .ConfigBits          (CFG_DEBUG[s*4 +: 4])
            );
        end
    endgenerate

endmodule
