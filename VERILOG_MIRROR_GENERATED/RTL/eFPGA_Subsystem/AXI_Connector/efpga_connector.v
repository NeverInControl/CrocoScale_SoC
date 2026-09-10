module efpga_connector (
	clk_i,
	rstn_i,
	rst_i,
	mgr_s_awaddr,
	mgr_s_awprot,
	mgr_s_awvalid,
	mgr_s_awready,
	mgr_s_wdata,
	mgr_s_wstrb,
	mgr_s_wvalid,
	mgr_s_wready,
	mgr_s_bresp,
	mgr_s_bvalid,
	mgr_s_bready,
	mgr_s_araddr,
	mgr_s_arprot,
	mgr_s_arvalid,
	mgr_s_arready,
	mgr_s_rdata,
	mgr_s_rresp,
	mgr_s_rvalid,
	mgr_s_rready,
	ctrl_s_awaddr,
	ctrl_s_awprot,
	ctrl_s_awvalid,
	ctrl_s_awready,
	ctrl_s_wdata,
	ctrl_s_wstrb,
	ctrl_s_wvalid,
	ctrl_s_wready,
	ctrl_s_bresp,
	ctrl_s_bvalid,
	ctrl_s_bready,
	ctrl_s_araddr,
	ctrl_s_arprot,
	ctrl_s_arvalid,
	ctrl_s_arready,
	ctrl_s_rdata,
	ctrl_s_rresp,
	ctrl_s_rvalid,
	ctrl_s_rready,
	ctrl_m_awaddr,
	ctrl_m_awprot,
	ctrl_m_awvalid,
	ctrl_m_awready,
	ctrl_m_wdata,
	ctrl_m_wstrb,
	ctrl_m_wvalid,
	ctrl_m_wready,
	ctrl_m_bresp,
	ctrl_m_bvalid,
	ctrl_m_bready,
	ctrl_m_araddr,
	ctrl_m_arprot,
	ctrl_m_arvalid,
	ctrl_m_arready,
	ctrl_m_rdata,
	ctrl_m_rresp,
	ctrl_m_rvalid,
	ctrl_m_rready,
	dma_s_awid,
	dma_s_awaddr,
	dma_s_awlen,
	dma_s_awsize,
	dma_s_awburst,
	dma_s_awlock,
	dma_s_awcache,
	dma_s_awprot,
	dma_s_awvalid,
	dma_s_awready,
	dma_s_wdata,
	dma_s_wstrb,
	dma_s_wlast,
	dma_s_wvalid,
	dma_s_wready,
	dma_s_bid,
	dma_s_bresp,
	dma_s_bvalid,
	dma_s_bready,
	dma_s_arid,
	dma_s_araddr,
	dma_s_arlen,
	dma_s_arsize,
	dma_s_arburst,
	dma_s_arlock,
	dma_s_arcache,
	dma_s_arprot,
	dma_s_arvalid,
	dma_s_arready,
	dma_s_rid,
	dma_s_rdata,
	dma_s_rresp,
	dma_s_rlast,
	dma_s_rvalid,
	dma_s_rready,
	dma_m_awid,
	dma_m_awaddr,
	dma_m_awlen,
	dma_m_awsize,
	dma_m_awburst,
	dma_m_awlock,
	dma_m_awcache,
	dma_m_awprot,
	dma_m_awvalid,
	dma_m_awready,
	dma_m_wdata,
	dma_m_wstrb,
	dma_m_wlast,
	dma_m_wvalid,
	dma_m_wready,
	dma_m_bid,
	dma_m_bresp,
	dma_m_bvalid,
	dma_m_bready,
	dma_m_arid,
	dma_m_araddr,
	dma_m_arlen,
	dma_m_arsize,
	dma_m_arburst,
	dma_m_arlock,
	dma_m_arcache,
	dma_m_arprot,
	dma_m_arvalid,
	dma_m_arready,
	dma_m_rid,
	dma_m_rdata,
	dma_m_rresp,
	dma_m_rlast,
	dma_m_rvalid,
	dma_m_rready,
	efpga_config_we_o,
	efpga_config_data_o,
	efpga_soft_reset_o,
	efpga_com_active_i,
	slot_i_top_i,
	slot_o_top_o
);
	parameter signed [31:0] NUM_SLOTS = 1;
	parameter signed [31:0] NUM_REGIONS = 2;
	parameter signed [31:0] AXI_ID_WIDTH = 8;
	parameter [31:0] HW_VERSION = 32'hfab00001;
	parameter [0:0] PAGE_GRANULARITY = 1'b1;
	parameter signed [31:0] MAX_ADDRESS_WIDTH = 30;
	parameter [0:0] ENABLE_STRICT_PAYLOAD_CHECK = 1'b0;
	parameter signed [31:0] WATCHDOG_LIMIT = 512;
	parameter [0:0] ENABLE_PMP = 1'b1;
	parameter [0:0] ENABLE_WDOG_CTRL_SLAVE = 1'b1;
	parameter [0:0] ENABLE_WDOG_DMA_MASTER = 1'b1;
	parameter [0:0] ENABLE_WDOG_CTRL_MASTER = 1'b0;
	parameter [0:0] ENABLE_WDOG_DMA_SLAVE = 1'b0;
	parameter [0:0] ENABLE_BRIDGE_CTRL = 1'b0;
	parameter [0:0] ENABLE_BRIDGE_DMA = 1'b0;
	parameter [0:0] ENABLE_REG_SLICES = 1'b1;
	input wire clk_i;
	input wire rstn_i;
	input wire rst_i;
	input wire [31:0] mgr_s_awaddr;
	input wire [2:0] mgr_s_awprot;
	input wire mgr_s_awvalid;
	output wire mgr_s_awready;
	input wire [31:0] mgr_s_wdata;
	input wire [3:0] mgr_s_wstrb;
	input wire mgr_s_wvalid;
	output wire mgr_s_wready;
	output wire [1:0] mgr_s_bresp;
	output wire mgr_s_bvalid;
	input wire mgr_s_bready;
	input wire [31:0] mgr_s_araddr;
	input wire [2:0] mgr_s_arprot;
	input wire mgr_s_arvalid;
	output wire mgr_s_arready;
	output wire [31:0] mgr_s_rdata;
	output wire [1:0] mgr_s_rresp;
	output wire mgr_s_rvalid;
	input wire mgr_s_rready;
	input wire [(NUM_SLOTS * 32) - 1:0] ctrl_s_awaddr;
	input wire [(NUM_SLOTS * 3) - 1:0] ctrl_s_awprot;
	input wire [NUM_SLOTS - 1:0] ctrl_s_awvalid;
	output wire [NUM_SLOTS - 1:0] ctrl_s_awready;
	input wire [(NUM_SLOTS * 32) - 1:0] ctrl_s_wdata;
	input wire [(NUM_SLOTS * 4) - 1:0] ctrl_s_wstrb;
	input wire [NUM_SLOTS - 1:0] ctrl_s_wvalid;
	output wire [NUM_SLOTS - 1:0] ctrl_s_wready;
	output wire [(NUM_SLOTS * 2) - 1:0] ctrl_s_bresp;
	output wire [NUM_SLOTS - 1:0] ctrl_s_bvalid;
	input wire [NUM_SLOTS - 1:0] ctrl_s_bready;
	input wire [(NUM_SLOTS * 32) - 1:0] ctrl_s_araddr;
	input wire [(NUM_SLOTS * 3) - 1:0] ctrl_s_arprot;
	input wire [NUM_SLOTS - 1:0] ctrl_s_arvalid;
	output wire [NUM_SLOTS - 1:0] ctrl_s_arready;
	output wire [(NUM_SLOTS * 32) - 1:0] ctrl_s_rdata;
	output wire [(NUM_SLOTS * 2) - 1:0] ctrl_s_rresp;
	output wire [NUM_SLOTS - 1:0] ctrl_s_rvalid;
	input wire [NUM_SLOTS - 1:0] ctrl_s_rready;
	output wire [(NUM_SLOTS * 32) - 1:0] ctrl_m_awaddr;
	output wire [(NUM_SLOTS * 3) - 1:0] ctrl_m_awprot;
	output wire [NUM_SLOTS - 1:0] ctrl_m_awvalid;
	input wire [NUM_SLOTS - 1:0] ctrl_m_awready;
	output wire [(NUM_SLOTS * 32) - 1:0] ctrl_m_wdata;
	output wire [(NUM_SLOTS * 4) - 1:0] ctrl_m_wstrb;
	output wire [NUM_SLOTS - 1:0] ctrl_m_wvalid;
	input wire [NUM_SLOTS - 1:0] ctrl_m_wready;
	input wire [(NUM_SLOTS * 2) - 1:0] ctrl_m_bresp;
	input wire [NUM_SLOTS - 1:0] ctrl_m_bvalid;
	output wire [NUM_SLOTS - 1:0] ctrl_m_bready;
	output wire [(NUM_SLOTS * 32) - 1:0] ctrl_m_araddr;
	output wire [(NUM_SLOTS * 3) - 1:0] ctrl_m_arprot;
	output wire [NUM_SLOTS - 1:0] ctrl_m_arvalid;
	input wire [NUM_SLOTS - 1:0] ctrl_m_arready;
	input wire [(NUM_SLOTS * 32) - 1:0] ctrl_m_rdata;
	input wire [(NUM_SLOTS * 2) - 1:0] ctrl_m_rresp;
	input wire [NUM_SLOTS - 1:0] ctrl_m_rvalid;
	output wire [NUM_SLOTS - 1:0] ctrl_m_rready;
	input wire [(NUM_SLOTS * AXI_ID_WIDTH) - 1:0] dma_s_awid;
	input wire [(NUM_SLOTS * 32) - 1:0] dma_s_awaddr;
	input wire [(NUM_SLOTS * 8) - 1:0] dma_s_awlen;
	input wire [(NUM_SLOTS * 3) - 1:0] dma_s_awsize;
	input wire [(NUM_SLOTS * 2) - 1:0] dma_s_awburst;
	input wire [NUM_SLOTS - 1:0] dma_s_awlock;
	input wire [(NUM_SLOTS * 4) - 1:0] dma_s_awcache;
	input wire [(NUM_SLOTS * 3) - 1:0] dma_s_awprot;
	input wire [NUM_SLOTS - 1:0] dma_s_awvalid;
	output wire [NUM_SLOTS - 1:0] dma_s_awready;
	input wire [(NUM_SLOTS * 32) - 1:0] dma_s_wdata;
	input wire [(NUM_SLOTS * 4) - 1:0] dma_s_wstrb;
	input wire [NUM_SLOTS - 1:0] dma_s_wlast;
	input wire [NUM_SLOTS - 1:0] dma_s_wvalid;
	output wire [NUM_SLOTS - 1:0] dma_s_wready;
	output wire [(NUM_SLOTS * AXI_ID_WIDTH) - 1:0] dma_s_bid;
	output wire [(NUM_SLOTS * 2) - 1:0] dma_s_bresp;
	output wire [NUM_SLOTS - 1:0] dma_s_bvalid;
	input wire [NUM_SLOTS - 1:0] dma_s_bready;
	input wire [(NUM_SLOTS * AXI_ID_WIDTH) - 1:0] dma_s_arid;
	input wire [(NUM_SLOTS * 32) - 1:0] dma_s_araddr;
	input wire [(NUM_SLOTS * 8) - 1:0] dma_s_arlen;
	input wire [(NUM_SLOTS * 3) - 1:0] dma_s_arsize;
	input wire [(NUM_SLOTS * 2) - 1:0] dma_s_arburst;
	input wire [NUM_SLOTS - 1:0] dma_s_arlock;
	input wire [(NUM_SLOTS * 4) - 1:0] dma_s_arcache;
	input wire [(NUM_SLOTS * 3) - 1:0] dma_s_arprot;
	input wire [NUM_SLOTS - 1:0] dma_s_arvalid;
	output wire [NUM_SLOTS - 1:0] dma_s_arready;
	output wire [(NUM_SLOTS * AXI_ID_WIDTH) - 1:0] dma_s_rid;
	output wire [(NUM_SLOTS * 32) - 1:0] dma_s_rdata;
	output wire [(NUM_SLOTS * 2) - 1:0] dma_s_rresp;
	output wire [NUM_SLOTS - 1:0] dma_s_rlast;
	output wire [NUM_SLOTS - 1:0] dma_s_rvalid;
	input wire [NUM_SLOTS - 1:0] dma_s_rready;
	output wire [(NUM_SLOTS * AXI_ID_WIDTH) - 1:0] dma_m_awid;
	output wire [(NUM_SLOTS * 32) - 1:0] dma_m_awaddr;
	output wire [(NUM_SLOTS * 8) - 1:0] dma_m_awlen;
	output wire [(NUM_SLOTS * 3) - 1:0] dma_m_awsize;
	output wire [(NUM_SLOTS * 2) - 1:0] dma_m_awburst;
	output wire [NUM_SLOTS - 1:0] dma_m_awlock;
	output wire [(NUM_SLOTS * 4) - 1:0] dma_m_awcache;
	output wire [(NUM_SLOTS * 3) - 1:0] dma_m_awprot;
	output wire [NUM_SLOTS - 1:0] dma_m_awvalid;
	input wire [NUM_SLOTS - 1:0] dma_m_awready;
	output wire [(NUM_SLOTS * 32) - 1:0] dma_m_wdata;
	output wire [(NUM_SLOTS * 4) - 1:0] dma_m_wstrb;
	output wire [NUM_SLOTS - 1:0] dma_m_wlast;
	output wire [NUM_SLOTS - 1:0] dma_m_wvalid;
	input wire [NUM_SLOTS - 1:0] dma_m_wready;
	input wire [(NUM_SLOTS * AXI_ID_WIDTH) - 1:0] dma_m_bid;
	input wire [(NUM_SLOTS * 2) - 1:0] dma_m_bresp;
	input wire [NUM_SLOTS - 1:0] dma_m_bvalid;
	output wire [NUM_SLOTS - 1:0] dma_m_bready;
	output wire [(NUM_SLOTS * AXI_ID_WIDTH) - 1:0] dma_m_arid;
	output wire [(NUM_SLOTS * 32) - 1:0] dma_m_araddr;
	output wire [(NUM_SLOTS * 8) - 1:0] dma_m_arlen;
	output wire [(NUM_SLOTS * 3) - 1:0] dma_m_arsize;
	output wire [(NUM_SLOTS * 2) - 1:0] dma_m_arburst;
	output wire [NUM_SLOTS - 1:0] dma_m_arlock;
	output wire [(NUM_SLOTS * 4) - 1:0] dma_m_arcache;
	output wire [(NUM_SLOTS * 3) - 1:0] dma_m_arprot;
	output wire [NUM_SLOTS - 1:0] dma_m_arvalid;
	input wire [NUM_SLOTS - 1:0] dma_m_arready;
	input wire [(NUM_SLOTS * AXI_ID_WIDTH) - 1:0] dma_m_rid;
	input wire [(NUM_SLOTS * 32) - 1:0] dma_m_rdata;
	input wire [(NUM_SLOTS * 2) - 1:0] dma_m_rresp;
	input wire [NUM_SLOTS - 1:0] dma_m_rlast;
	input wire [NUM_SLOTS - 1:0] dma_m_rvalid;
	output wire [NUM_SLOTS - 1:0] dma_m_rready;
	output wire efpga_config_we_o;
	output wire [31:0] efpga_config_data_o;
	output wire efpga_soft_reset_o;
	input wire efpga_com_active_i;
	(* keep = "true", mark_debug = "true" *) input wire [(NUM_SLOTS * 32) - 1:0] slot_i_top_i;
	(* keep = "true", mark_debug = "true" *) output wire [(NUM_SLOTS * 32) - 1:0] slot_o_top_o;
	(* keep = "true", mark_debug = "true" *) wire [NUM_SLOTS - 1:0] dec_req;
	(* keep = "true", mark_debug = "true" *) wire [NUM_SLOTS - 1:0] dec_force;
	(* keep = "true", mark_debug = "true" *) wire [NUM_SLOTS - 1:0] dec_is_dec;
	(* keep = "true", mark_debug = "true" *) wire [NUM_SLOTS - 1:0] dec_host_act;
	(* keep = "true", mark_debug = "true" *) wire [NUM_SLOTS - 1:0] dec_dma_act;
	wire [NUM_SLOTS - 1:0] pmp_r_violation;
	wire [NUM_SLOTS - 1:0] pmp_w_violation;
	wire [NUM_SLOTS - 1:0] slot_wb_s_en;
	wire [NUM_SLOTS - 1:0] slot_wb_m_en;
	wire [NUM_SLOTS - 1:0] p_g_en;
	wire [((NUM_SLOTS * NUM_REGIONS) * 32) - 1:0] p_base;
	wire [((NUM_SLOTS * NUM_REGIONS) * 32) - 1:0] p_limit;
	wire [NUM_SLOTS - 1:0] wdog_cs_to_w;
	wire [NUM_SLOTS - 1:0] wdog_cs_to_r;
	wire [NUM_SLOTS - 1:0] wdog_cs_pr_w;
	wire [NUM_SLOTS - 1:0] wdog_cs_pr_r;
	wire [NUM_SLOTS - 1:0] wdog_dm_to_w;
	wire [NUM_SLOTS - 1:0] wdog_dm_to_r;
	wire [NUM_SLOTS - 1:0] wdog_dm_pr_w;
	wire [NUM_SLOTS - 1:0] wdog_dm_pr_r;
	wire [NUM_SLOTS - 1:0] wdog_cm_to_w;
	wire [NUM_SLOTS - 1:0] wdog_cm_to_r;
	wire [NUM_SLOTS - 1:0] wdog_cm_pr_w;
	wire [NUM_SLOTS - 1:0] wdog_cm_pr_r;
	wire [NUM_SLOTS - 1:0] wdog_ds_to_w;
	wire [NUM_SLOTS - 1:0] wdog_ds_to_r;
	wire [NUM_SLOTS - 1:0] wdog_ds_pr_w;
	wire [NUM_SLOTS - 1:0] wdog_ds_pr_r;
	efpga_manager #(
		.NUM_SLOTS(NUM_SLOTS),
		.NUM_REGIONS(NUM_REGIONS),
		.HW_VERSION(HW_VERSION),
		.PAGE_GRANULARITY(PAGE_GRANULARITY),
		.MAX_ADDRESS_WIDTH(MAX_ADDRESS_WIDTH),
		.ENABLE_PMP(ENABLE_PMP),
		.ENABLE_WDOG_CTRL_SLAVE(ENABLE_WDOG_CTRL_SLAVE),
		.ENABLE_WDOG_DMA_MASTER(ENABLE_WDOG_DMA_MASTER),
		.ENABLE_WDOG_CTRL_MASTER(ENABLE_WDOG_CTRL_MASTER),
		.ENABLE_WDOG_DMA_SLAVE(ENABLE_WDOG_DMA_SLAVE),
		.ENABLE_BRIDGE_CTRL(ENABLE_BRIDGE_CTRL),
		.ENABLE_BRIDGE_DMA(ENABLE_BRIDGE_DMA)
	) manager_inst(
		.clk_i(clk_i),
		.rstn_i(rstn_i),
		.s_axil_awaddr(mgr_s_awaddr),
		.s_axil_awprot(mgr_s_awprot),
		.s_axil_awvalid(mgr_s_awvalid),
		.s_axil_awready(mgr_s_awready),
		.s_axil_wdata(mgr_s_wdata),
		.s_axil_wstrb(mgr_s_wstrb),
		.s_axil_wvalid(mgr_s_wvalid),
		.s_axil_wready(mgr_s_wready),
		.s_axil_bresp(mgr_s_bresp),
		.s_axil_bvalid(mgr_s_bvalid),
		.s_axil_bready(mgr_s_bready),
		.s_axil_araddr(mgr_s_araddr),
		.s_axil_arprot(mgr_s_arprot),
		.s_axil_arvalid(mgr_s_arvalid),
		.s_axil_arready(mgr_s_arready),
		.s_axil_rdata(mgr_s_rdata),
		.s_axil_rresp(mgr_s_rresp),
		.s_axil_rvalid(mgr_s_rvalid),
		.s_axil_rready(mgr_s_rready),
		.efpga_config_data_o(efpga_config_data_o),
		.efpga_config_we_o(efpga_config_we_o),
		.efpga_soft_reset_o(efpga_soft_reset_o),
		.efpga_com_active_i(efpga_com_active_i),
		.slot_i_top_i(slot_i_top_i),
		.slot_o_top_o(slot_o_top_o),
		.decoupler_req_o(dec_req),
		.decoupler_force_o(dec_force),
		.decoupler_is_decoupled_i(dec_is_dec),
		.decoupler_host_act_i(dec_host_act),
		.decoupler_dma_act_i(dec_dma_act),
		.slot_pmp_r_violation_i(pmp_r_violation),
		.slot_pmp_w_violation_i(pmp_w_violation),
		.slot_wdog_cs_to_w_i(wdog_cs_to_w),
		.slot_wdog_cs_to_r_i(wdog_cs_to_r),
		.slot_wdog_cs_pr_w_i(wdog_cs_pr_w),
		.slot_wdog_cs_pr_r_i(wdog_cs_pr_r),
		.slot_wdog_dm_to_w_i(wdog_dm_to_w),
		.slot_wdog_dm_to_r_i(wdog_dm_to_r),
		.slot_wdog_dm_pr_w_i(wdog_dm_pr_w),
		.slot_wdog_dm_pr_r_i(wdog_dm_pr_r),
		.slot_wdog_cm_to_w_i(wdog_cm_to_w),
		.slot_wdog_cm_to_r_i(wdog_cm_to_r),
		.slot_wdog_cm_pr_w_i(wdog_cm_pr_w),
		.slot_wdog_cm_pr_r_i(wdog_cm_pr_r),
		.slot_wdog_ds_to_w_i(wdog_ds_to_w),
		.slot_wdog_ds_to_r_i(wdog_ds_to_r),
		.slot_wdog_ds_pr_w_i(wdog_ds_pr_w),
		.slot_wdog_ds_pr_r_i(wdog_ds_pr_r),
		.pmp_g_en_o(p_g_en),
		.pmp_base_o(p_base),
		.pmp_limit_o(p_limit),
		.wb_s_enable_o(slot_wb_s_en),
		.wb_m_enable_o(slot_wb_m_en)
	);
	genvar _gv_i_1;
	generate
		for (_gv_i_1 = 0; _gv_i_1 < NUM_SLOTS; _gv_i_1 = _gv_i_1 + 1) begin : slot_gen
			localparam i = _gv_i_1;
			(* keep = "true", mark_debug = "true" *) wire [31:0] slice_ctrl_awaddr;
			(* keep = "true", mark_debug = "true" *) wire [2:0] slice_ctrl_awprot;
			(* keep = "true", mark_debug = "true" *) wire slice_ctrl_awvalid;
			(* keep = "true", mark_debug = "true" *) wire slice_ctrl_awready;
			(* keep = "true", mark_debug = "true" *) wire [31:0] slice_ctrl_wdata;
			(* keep = "true", mark_debug = "true" *) wire [3:0] slice_ctrl_wstrb;
			(* keep = "true", mark_debug = "true" *) wire slice_ctrl_wvalid;
			(* keep = "true", mark_debug = "true" *) wire slice_ctrl_wready;
			(* keep = "true", mark_debug = "true" *) wire [1:0] slice_ctrl_bresp;
			(* keep = "true", mark_debug = "true" *) wire slice_ctrl_bvalid;
			(* keep = "true", mark_debug = "true" *) wire slice_ctrl_bready;
			(* keep = "true", mark_debug = "true" *) wire [31:0] slice_ctrl_araddr;
			(* keep = "true", mark_debug = "true" *) wire [2:0] slice_ctrl_arprot;
			(* keep = "true", mark_debug = "true" *) wire slice_ctrl_arvalid;
			(* keep = "true", mark_debug = "true" *) wire slice_ctrl_arready;
			(* keep = "true", mark_debug = "true" *) wire [31:0] slice_ctrl_rdata;
			(* keep = "true", mark_debug = "true" *) wire [1:0] slice_ctrl_rresp;
			(* keep = "true", mark_debug = "true" *) wire slice_ctrl_rvalid;
			(* keep = "true", mark_debug = "true" *) wire slice_ctrl_rready;
			wire [AXI_ID_WIDTH - 1:0] slice_dma_awid;
			wire [31:0] slice_dma_awaddr;
			wire [7:0] slice_dma_awlen;
			wire [2:0] slice_dma_awsize;
			wire [1:0] slice_dma_awburst;
			wire slice_dma_awlock;
			wire [3:0] slice_dma_awcache;
			wire [2:0] slice_dma_awprot;
			wire slice_dma_awvalid;
			wire slice_dma_awready;
			wire [31:0] slice_dma_wdata;
			wire [3:0] slice_dma_wstrb;
			wire slice_dma_wlast;
			wire slice_dma_wvalid;
			wire slice_dma_wready;
			wire [AXI_ID_WIDTH - 1:0] slice_dma_bid;
			wire [1:0] slice_dma_bresp;
			wire slice_dma_bvalid;
			wire slice_dma_bready;
			wire [AXI_ID_WIDTH - 1:0] slice_dma_arid;
			wire [31:0] slice_dma_araddr;
			wire [7:0] slice_dma_arlen;
			wire [2:0] slice_dma_arsize;
			wire [1:0] slice_dma_arburst;
			wire slice_dma_arlock;
			wire [3:0] slice_dma_arcache;
			wire [2:0] slice_dma_arprot;
			wire slice_dma_arvalid;
			wire slice_dma_arready;
			wire [AXI_ID_WIDTH - 1:0] slice_dma_rid;
			wire [31:0] slice_dma_rdata;
			wire [1:0] slice_dma_rresp;
			wire slice_dma_rvalid;
			wire slice_dma_rready;
			wire slice_dma_rlast;
			if (ENABLE_REG_SLICES) begin : gen_reg_slice
				axil_register #(
					.DATA_WIDTH(32),
					.ADDR_WIDTH(32),
					.STRB_WIDTH(4),
					.AW_REG_TYPE(2),
					.W_REG_TYPE(2),
					.B_REG_TYPE(2),
					.AR_REG_TYPE(2),
					.R_REG_TYPE(2)
				) ctrl_slice(
					.clk(clk_i),
					.rst(rst_i),
					.s_axil_awaddr(ctrl_s_awaddr[i * 32+:32]),
					.s_axil_awprot(ctrl_s_awprot[i * 3+:3]),
					.s_axil_awvalid(ctrl_s_awvalid[i]),
					.s_axil_awready(ctrl_s_awready[i]),
					.s_axil_wdata(ctrl_s_wdata[i * 32+:32]),
					.s_axil_wstrb(ctrl_s_wstrb[i * 4+:4]),
					.s_axil_wvalid(ctrl_s_wvalid[i]),
					.s_axil_wready(ctrl_s_wready[i]),
					.s_axil_bresp(ctrl_s_bresp[i * 2+:2]),
					.s_axil_bvalid(ctrl_s_bvalid[i]),
					.s_axil_bready(ctrl_s_bready[i]),
					.s_axil_araddr(ctrl_s_araddr[i * 32+:32]),
					.s_axil_arprot(ctrl_s_arprot[i * 3+:3]),
					.s_axil_arvalid(ctrl_s_arvalid[i]),
					.s_axil_arready(ctrl_s_arready[i]),
					.s_axil_rdata(ctrl_s_rdata[i * 32+:32]),
					.s_axil_rresp(ctrl_s_rresp[i * 2+:2]),
					.s_axil_rvalid(ctrl_s_rvalid[i]),
					.s_axil_rready(ctrl_s_rready[i]),
					.m_axil_awaddr(slice_ctrl_awaddr),
					.m_axil_awprot(slice_ctrl_awprot),
					.m_axil_awvalid(slice_ctrl_awvalid),
					.m_axil_awready(slice_ctrl_awready),
					.m_axil_wdata(slice_ctrl_wdata),
					.m_axil_wstrb(slice_ctrl_wstrb),
					.m_axil_wvalid(slice_ctrl_wvalid),
					.m_axil_wready(slice_ctrl_wready),
					.m_axil_bresp(slice_ctrl_bresp),
					.m_axil_bvalid(slice_ctrl_bvalid),
					.m_axil_bready(slice_ctrl_bready),
					.m_axil_araddr(slice_ctrl_araddr),
					.m_axil_arprot(slice_ctrl_arprot),
					.m_axil_arvalid(slice_ctrl_arvalid),
					.m_axil_arready(slice_ctrl_arready),
					.m_axil_rdata(slice_ctrl_rdata),
					.m_axil_rresp(slice_ctrl_rresp),
					.m_axil_rvalid(slice_ctrl_rvalid),
					.m_axil_rready(slice_ctrl_rready)
				);
				axi_register #(
					.DATA_WIDTH(32),
					.ADDR_WIDTH(32),
					.ID_WIDTH(AXI_ID_WIDTH),
					.AWUSER_ENABLE(0),
					.WUSER_ENABLE(0),
					.BUSER_ENABLE(0),
					.ARUSER_ENABLE(0),
					.RUSER_ENABLE(0),
					.AW_REG_TYPE(2),
					.W_REG_TYPE(2),
					.B_REG_TYPE(2),
					.AR_REG_TYPE(2),
					.R_REG_TYPE(2)
				) dma_slice(
					.clk(clk_i),
					.rst(rst_i),
					.s_axi_awid(slice_dma_awid),
					.s_axi_awaddr(slice_dma_awaddr),
					.s_axi_awlen(slice_dma_awlen),
					.s_axi_awsize(slice_dma_awsize),
					.s_axi_awburst(slice_dma_awburst),
					.s_axi_awlock(slice_dma_awlock),
					.s_axi_awcache(slice_dma_awcache),
					.s_axi_awprot(slice_dma_awprot),
					.s_axi_awqos(4'd0),
					.s_axi_awregion(4'd0),
					.s_axi_awuser(1'b0),
					.s_axi_awvalid(slice_dma_awvalid),
					.s_axi_awready(slice_dma_awready),
					.s_axi_wdata(slice_dma_wdata),
					.s_axi_wstrb(slice_dma_wstrb),
					.s_axi_wlast(slice_dma_wlast),
					.s_axi_wuser(1'b0),
					.s_axi_wvalid(slice_dma_wvalid),
					.s_axi_wready(slice_dma_wready),
					.s_axi_bid(slice_dma_bid),
					.s_axi_bresp(slice_dma_bresp),
					.s_axi_buser(),
					.s_axi_bvalid(slice_dma_bvalid),
					.s_axi_bready(slice_dma_bready),
					.s_axi_arid(slice_dma_arid),
					.s_axi_araddr(slice_dma_araddr),
					.s_axi_arlen(slice_dma_arlen),
					.s_axi_arsize(slice_dma_arsize),
					.s_axi_arburst(slice_dma_arburst),
					.s_axi_arlock(slice_dma_arlock),
					.s_axi_arcache(slice_dma_arcache),
					.s_axi_arprot(slice_dma_arprot),
					.s_axi_arqos(4'd0),
					.s_axi_arregion(4'd0),
					.s_axi_aruser(1'b0),
					.s_axi_arvalid(slice_dma_arvalid),
					.s_axi_arready(slice_dma_arready),
					.s_axi_rid(slice_dma_rid),
					.s_axi_rdata(slice_dma_rdata),
					.s_axi_rresp(slice_dma_rresp),
					.s_axi_rlast(slice_dma_rlast),
					.s_axi_ruser(),
					.s_axi_rvalid(slice_dma_rvalid),
					.s_axi_rready(slice_dma_rready),
					.m_axi_awid(dma_m_awid[i * AXI_ID_WIDTH+:AXI_ID_WIDTH]),
					.m_axi_awaddr(dma_m_awaddr[i * 32+:32]),
					.m_axi_awlen(dma_m_awlen[i * 8+:8]),
					.m_axi_awsize(dma_m_awsize[i * 3+:3]),
					.m_axi_awburst(dma_m_awburst[i * 2+:2]),
					.m_axi_awlock(dma_m_awlock[i]),
					.m_axi_awcache(dma_m_awcache[i * 4+:4]),
					.m_axi_awprot(dma_m_awprot[i * 3+:3]),
					.m_axi_awqos(),
					.m_axi_awregion(),
					.m_axi_awuser(),
					.m_axi_awvalid(dma_m_awvalid[i]),
					.m_axi_awready(dma_m_awready[i]),
					.m_axi_wdata(dma_m_wdata[i * 32+:32]),
					.m_axi_wstrb(dma_m_wstrb[i * 4+:4]),
					.m_axi_wlast(dma_m_wlast[i]),
					.m_axi_wuser(),
					.m_axi_wvalid(dma_m_wvalid[i]),
					.m_axi_wready(dma_m_wready[i]),
					.m_axi_bid(dma_m_bid[i * AXI_ID_WIDTH+:AXI_ID_WIDTH]),
					.m_axi_bresp(dma_m_bresp[i * 2+:2]),
					.m_axi_buser(),
					.m_axi_bvalid(dma_m_bvalid[i]),
					.m_axi_bready(dma_m_bready[i]),
					.m_axi_arid(dma_m_arid[i * AXI_ID_WIDTH+:AXI_ID_WIDTH]),
					.m_axi_araddr(dma_m_araddr[i * 32+:32]),
					.m_axi_arlen(dma_m_arlen[i * 8+:8]),
					.m_axi_arsize(dma_m_arsize[i * 3+:3]),
					.m_axi_arburst(dma_m_arburst[i * 2+:2]),
					.m_axi_arlock(dma_m_arlock[i]),
					.m_axi_arcache(dma_m_arcache[i * 4+:4]),
					.m_axi_arprot(dma_m_arprot[i * 3+:3]),
					.m_axi_arqos(),
					.m_axi_arregion(),
					.m_axi_aruser(),
					.m_axi_arvalid(dma_m_arvalid[i]),
					.m_axi_arready(dma_m_arready[i]),
					.m_axi_rid(dma_m_rid[i * AXI_ID_WIDTH+:AXI_ID_WIDTH]),
					.m_axi_rdata(dma_m_rdata[i * 32+:32]),
					.m_axi_rresp(dma_m_rresp[i * 2+:2]),
					.m_axi_rlast(dma_m_rlast[i]),
					.m_axi_ruser(),
					.m_axi_rvalid(dma_m_rvalid[i]),
					.m_axi_rready(dma_m_rready[i])
				);
			end
			else begin : gen_no_reg_slice
				assign slice_ctrl_awaddr = ctrl_s_awaddr[i * 32+:32];
				assign slice_ctrl_awprot = ctrl_s_awprot[i * 3+:3];
				assign slice_ctrl_awvalid = ctrl_s_awvalid[i];
				assign ctrl_s_awready[i] = slice_ctrl_awready;
				assign slice_ctrl_wdata = ctrl_s_wdata[i * 32+:32];
				assign slice_ctrl_wstrb = ctrl_s_wstrb[i * 4+:4];
				assign slice_ctrl_wvalid = ctrl_s_wvalid[i];
				assign ctrl_s_wready[i] = slice_ctrl_wready;
				assign ctrl_s_bresp[i * 2+:2] = slice_ctrl_bresp;
				assign ctrl_s_bvalid[i] = slice_ctrl_bvalid;
				assign slice_ctrl_bready = ctrl_s_bready[i];
				assign slice_ctrl_araddr = ctrl_s_araddr[i * 32+:32];
				assign slice_ctrl_arprot = ctrl_s_arprot[i * 3+:3];
				assign slice_ctrl_arvalid = ctrl_s_arvalid[i];
				assign ctrl_s_arready[i] = slice_ctrl_arready;
				assign ctrl_s_rdata[i * 32+:32] = slice_ctrl_rdata;
				assign ctrl_s_rresp[i * 2+:2] = slice_ctrl_rresp;
				assign ctrl_s_rvalid[i] = slice_ctrl_rvalid;
				assign slice_ctrl_rready = ctrl_s_rready[i];
				assign dma_m_awid[i * AXI_ID_WIDTH+:AXI_ID_WIDTH] = slice_dma_awid;
				assign dma_m_awaddr[i * 32+:32] = slice_dma_awaddr;
				assign dma_m_awlen[i * 8+:8] = slice_dma_awlen;
				assign dma_m_awsize[i * 3+:3] = slice_dma_awsize;
				assign dma_m_awburst[i * 2+:2] = slice_dma_awburst;
				assign dma_m_awlock[i] = slice_dma_awlock;
				assign dma_m_awcache[i * 4+:4] = slice_dma_awcache;
				assign dma_m_awprot[i * 3+:3] = slice_dma_awprot;
				assign dma_m_awvalid[i] = slice_dma_awvalid;
				assign slice_dma_awready = dma_m_awready[i];
				assign dma_m_wdata[i * 32+:32] = slice_dma_wdata;
				assign dma_m_wstrb[i * 4+:4] = slice_dma_wstrb;
				assign dma_m_wlast[i] = slice_dma_wlast;
				assign dma_m_wvalid[i] = slice_dma_wvalid;
				assign slice_dma_wready = dma_m_wready[i];
				assign slice_dma_bid = dma_m_bid[i * AXI_ID_WIDTH+:AXI_ID_WIDTH];
				assign slice_dma_bresp = dma_m_bresp[i * 2+:2];
				assign slice_dma_bvalid = dma_m_bvalid[i];
				assign dma_m_bready[i] = slice_dma_bready;
				assign dma_m_arid[i * AXI_ID_WIDTH+:AXI_ID_WIDTH] = slice_dma_arid;
				assign dma_m_araddr[i * 32+:32] = slice_dma_araddr;
				assign dma_m_arlen[i * 8+:8] = slice_dma_arlen;
				assign dma_m_arsize[i * 3+:3] = slice_dma_arsize;
				assign dma_m_arburst[i * 2+:2] = slice_dma_arburst;
				assign dma_m_arlock[i] = slice_dma_arlock;
				assign dma_m_arcache[i * 4+:4] = slice_dma_arcache;
				assign dma_m_arprot[i * 3+:3] = slice_dma_arprot;
				assign dma_m_arvalid[i] = slice_dma_arvalid;
				assign slice_dma_arready = dma_m_arready[i];
				assign slice_dma_rid = dma_m_rid[i * AXI_ID_WIDTH+:AXI_ID_WIDTH];
				assign slice_dma_rdata = dma_m_rdata[i * 32+:32];
				assign slice_dma_rresp = dma_m_rresp[i * 2+:2];
				assign slice_dma_rlast = dma_m_rlast[i];
				assign slice_dma_rvalid = dma_m_rvalid[i];
				assign dma_m_rready[i] = slice_dma_rready;
			end
			(* keep = "true", mark_debug = "true" *) wire [31:0] dec_ctrl_awaddr;
			(* keep = "true", mark_debug = "true" *) wire [2:0] dec_ctrl_awprot;
			(* keep = "true", mark_debug = "true" *) wire dec_ctrl_awvalid;
			(* keep = "true", mark_debug = "true" *) wire dec_ctrl_awready;
			(* keep = "true", mark_debug = "true" *) wire [31:0] dec_ctrl_wdata;
			(* keep = "true", mark_debug = "true" *) wire [3:0] dec_ctrl_wstrb;
			(* keep = "true", mark_debug = "true" *) wire dec_ctrl_wvalid;
			(* keep = "true", mark_debug = "true" *) wire dec_ctrl_wready;
			(* keep = "true", mark_debug = "true" *) wire [1:0] dec_ctrl_bresp;
			(* keep = "true", mark_debug = "true" *) wire dec_ctrl_bvalid;
			(* keep = "true", mark_debug = "true" *) wire dec_ctrl_bready;
			(* keep = "true", mark_debug = "true" *) wire [31:0] dec_ctrl_araddr;
			(* keep = "true", mark_debug = "true" *) wire [2:0] dec_ctrl_arprot;
			(* keep = "true", mark_debug = "true" *) wire dec_ctrl_arvalid;
			(* keep = "true", mark_debug = "true" *) wire dec_ctrl_arready;
			(* keep = "true", mark_debug = "true" *) wire [31:0] dec_ctrl_rdata;
			(* keep = "true", mark_debug = "true" *) wire [1:0] dec_ctrl_rresp;
			(* keep = "true", mark_debug = "true" *) wire dec_ctrl_rvalid;
			(* keep = "true", mark_debug = "true" *) wire dec_ctrl_rready;
			wire [AXI_ID_WIDTH - 1:0] dec_dma_awid;
			wire [31:0] dec_dma_awaddr;
			wire [7:0] dec_dma_awlen;
			wire [2:0] dec_dma_awsize;
			wire [1:0] dec_dma_awburst;
			wire dec_dma_awlock;
			wire [3:0] dec_dma_awcache;
			wire [2:0] dec_dma_awprot;
			wire dec_dma_awvalid;
			wire dec_dma_awready;
			wire [31:0] dec_dma_wdata;
			wire [3:0] dec_dma_wstrb;
			wire dec_dma_wlast;
			wire dec_dma_wvalid;
			wire dec_dma_wready;
			wire [AXI_ID_WIDTH - 1:0] dec_dma_bid;
			wire [1:0] dec_dma_bresp;
			wire dec_dma_bvalid;
			wire dec_dma_bready;
			wire [AXI_ID_WIDTH - 1:0] dec_dma_arid;
			wire [31:0] dec_dma_araddr;
			wire [7:0] dec_dma_arlen;
			wire [2:0] dec_dma_arsize;
			wire [1:0] dec_dma_arburst;
			wire dec_dma_arlock;
			wire [3:0] dec_dma_arcache;
			wire [2:0] dec_dma_arprot;
			wire dec_dma_arvalid;
			wire dec_dma_arready;
			wire [AXI_ID_WIDTH - 1:0] dec_dma_rid;
			wire [31:0] dec_dma_rdata;
			wire [1:0] dec_dma_rresp;
			wire dec_dma_rvalid;
			wire dec_dma_rready;
			wire dec_dma_rlast;
			if (ENABLE_WDOG_CTRL_MASTER) begin : gen_wdog_cm
				axil_watchdog_master_monitor #(
					.ENABLE_TIMEOUT(1'b1),
					.ENABLE_PROTOCOL_CHECK(1'b1),
					.ENABLE_STRICT_PAYLOAD_CHECK(ENABLE_STRICT_PAYLOAD_CHECK),
					.WATCHDOG_LIMIT(WATCHDOG_LIMIT)
				) inst_wdog_cm(
					.clk_i(clk_i),
					.rstn_i(rstn_i),
					.awvalid(slice_ctrl_awvalid),
					.awready(slice_ctrl_awready),
					.awaddr(slice_ctrl_awaddr),
					.awprot(slice_ctrl_awprot),
					.wvalid(slice_ctrl_wvalid),
					.wready(slice_ctrl_wready),
					.wdata(slice_ctrl_wdata),
					.wstrb(slice_ctrl_wstrb),
					.bvalid(slice_ctrl_bvalid),
					.bready(slice_ctrl_bready),
					.arvalid(slice_ctrl_arvalid),
					.arready(slice_ctrl_arready),
					.araddr(slice_ctrl_araddr),
					.arprot(slice_ctrl_arprot),
					.rvalid(slice_ctrl_rvalid),
					.rready(slice_ctrl_rready),
					.timeout_w_fault_o(wdog_cm_to_w[i]),
					.timeout_r_fault_o(wdog_cm_to_r[i]),
					.protocol_w_fault_o(wdog_cm_pr_w[i]),
					.protocol_r_fault_o(wdog_cm_pr_r[i])
				);
			end
			else begin : gen_no_wdog_cm
				assign wdog_cm_to_w[i] = 0;
				assign wdog_cm_to_r[i] = 0;
				assign wdog_cm_pr_w[i] = 0;
				assign wdog_cm_pr_r[i] = 0;
			end
			axi_decoupler #(.AXI_ID_WIDTH(AXI_ID_WIDTH)) decoupler_inst(
				.clk_i(clk_i),
				.rstn_i(rstn_i),
				.decouple_req_i(dec_req[i]),
				.force_decouple_i(dec_force[i]),
				.is_decoupled_o(dec_is_dec[i]),
				.host_active_o(dec_host_act[i]),
				.dma_active_o(dec_dma_act[i]),
				.ctrl_s_axil_awaddr(slice_ctrl_awaddr),
				.ctrl_s_axil_awprot(slice_ctrl_awprot),
				.ctrl_s_axil_awvalid(slice_ctrl_awvalid),
				.ctrl_s_axil_awready(slice_ctrl_awready),
				.ctrl_s_axil_wdata(slice_ctrl_wdata),
				.ctrl_s_axil_wstrb(slice_ctrl_wstrb),
				.ctrl_s_axil_wvalid(slice_ctrl_wvalid),
				.ctrl_s_axil_wready(slice_ctrl_wready),
				.ctrl_s_axil_bresp(slice_ctrl_bresp),
				.ctrl_s_axil_bvalid(slice_ctrl_bvalid),
				.ctrl_s_axil_bready(slice_ctrl_bready),
				.ctrl_s_axil_araddr(slice_ctrl_araddr),
				.ctrl_s_axil_arprot(slice_ctrl_arprot),
				.ctrl_s_axil_arvalid(slice_ctrl_arvalid),
				.ctrl_s_axil_arready(slice_ctrl_arready),
				.ctrl_s_axil_rdata(slice_ctrl_rdata),
				.ctrl_s_axil_rresp(slice_ctrl_rresp),
				.ctrl_s_axil_rvalid(slice_ctrl_rvalid),
				.ctrl_s_axil_rready(slice_ctrl_rready),
				.ctrl_m_axil_awaddr(dec_ctrl_awaddr),
				.ctrl_m_axil_awprot(dec_ctrl_awprot),
				.ctrl_m_axil_awvalid(dec_ctrl_awvalid),
				.ctrl_m_axil_awready(dec_ctrl_awready),
				.ctrl_m_axil_wdata(dec_ctrl_wdata),
				.ctrl_m_axil_wstrb(dec_ctrl_wstrb),
				.ctrl_m_axil_wvalid(dec_ctrl_wvalid),
				.ctrl_m_axil_wready(dec_ctrl_wready),
				.ctrl_m_axil_bresp(dec_ctrl_bresp),
				.ctrl_m_axil_bvalid(dec_ctrl_bvalid),
				.ctrl_m_axil_bready(dec_ctrl_bready),
				.ctrl_m_axil_araddr(dec_ctrl_araddr),
				.ctrl_m_axil_arprot(dec_ctrl_arprot),
				.ctrl_m_axil_arvalid(dec_ctrl_arvalid),
				.ctrl_m_axil_arready(dec_ctrl_arready),
				.ctrl_m_axil_rdata(dec_ctrl_rdata),
				.ctrl_m_axil_rresp(dec_ctrl_rresp),
				.ctrl_m_axil_rvalid(dec_ctrl_rvalid),
				.ctrl_m_axil_rready(dec_ctrl_rready),
				.dma_s_axi_awid(dec_dma_awid),
				.dma_s_axi_awaddr(dec_dma_awaddr),
				.dma_s_axi_awlen(dec_dma_awlen),
				.dma_s_axi_awsize(dec_dma_awsize),
				.dma_s_axi_awburst(dec_dma_awburst),
				.dma_s_axi_awlock(dec_dma_awlock),
				.dma_s_axi_awcache(dec_dma_awcache),
				.dma_s_axi_awprot(dec_dma_awprot),
				.dma_s_axi_awvalid(dec_dma_awvalid),
				.dma_s_axi_awready(dec_dma_awready),
				.dma_s_axi_wdata(dec_dma_wdata),
				.dma_s_axi_wstrb(dec_dma_wstrb),
				.dma_s_axi_wlast(dec_dma_wlast),
				.dma_s_axi_wvalid(dec_dma_wvalid),
				.dma_s_axi_wready(dec_dma_wready),
				.dma_s_axi_bid(dec_dma_bid),
				.dma_s_axi_bresp(dec_dma_bresp),
				.dma_s_axi_bvalid(dec_dma_bvalid),
				.dma_s_axi_bready(dec_dma_bready),
				.dma_s_axi_arid(dec_dma_arid),
				.dma_s_axi_araddr(dec_dma_araddr),
				.dma_s_axi_arlen(dec_dma_arlen),
				.dma_s_axi_arsize(dec_dma_arsize),
				.dma_s_axi_arburst(dec_dma_arburst),
				.dma_s_axi_arlock(dec_dma_arlock),
				.dma_s_axi_arcache(dec_dma_arcache),
				.dma_s_axi_arprot(dec_dma_arprot),
				.dma_s_axi_arvalid(dec_dma_arvalid),
				.dma_s_axi_arready(dec_dma_arready),
				.dma_s_axi_rid(dec_dma_rid),
				.dma_s_axi_rdata(dec_dma_rdata),
				.dma_s_axi_rresp(dec_dma_rresp),
				.dma_s_axi_rlast(dec_dma_rlast),
				.dma_s_axi_rvalid(dec_dma_rvalid),
				.dma_s_axi_rready(dec_dma_rready),
				.dma_m_axi_awid(slice_dma_awid),
				.dma_m_axi_awaddr(slice_dma_awaddr),
				.dma_m_axi_awlen(slice_dma_awlen),
				.dma_m_axi_awsize(slice_dma_awsize),
				.dma_m_axi_awburst(slice_dma_awburst),
				.dma_m_axi_awlock(slice_dma_awlock),
				.dma_m_axi_awcache(slice_dma_awcache),
				.dma_m_axi_awprot(slice_dma_awprot),
				.dma_m_axi_awvalid(slice_dma_awvalid),
				.dma_m_axi_awready(slice_dma_awready),
				.dma_m_axi_wdata(slice_dma_wdata),
				.dma_m_axi_wstrb(slice_dma_wstrb),
				.dma_m_axi_wlast(slice_dma_wlast),
				.dma_m_axi_wvalid(slice_dma_wvalid),
				.dma_m_axi_wready(slice_dma_wready),
				.dma_m_axi_bid(slice_dma_bid),
				.dma_m_axi_bresp(slice_dma_bresp),
				.dma_m_axi_bvalid(slice_dma_bvalid),
				.dma_m_axi_bready(slice_dma_bready),
				.dma_m_axi_arid(slice_dma_arid),
				.dma_m_axi_araddr(slice_dma_araddr),
				.dma_m_axi_arlen(slice_dma_arlen),
				.dma_m_axi_arsize(slice_dma_arsize),
				.dma_m_axi_arburst(slice_dma_arburst),
				.dma_m_axi_arlock(slice_dma_arlock),
				.dma_m_axi_arcache(slice_dma_arcache),
				.dma_m_axi_arprot(slice_dma_arprot),
				.dma_m_axi_arvalid(slice_dma_arvalid),
				.dma_m_axi_arready(slice_dma_arready),
				.dma_m_axi_rid(slice_dma_rid),
				.dma_m_axi_rdata(slice_dma_rdata),
				.dma_m_axi_rresp(slice_dma_rresp),
				.dma_m_axi_rlast(slice_dma_rlast),
				.dma_m_axi_rvalid(slice_dma_rvalid),
				.dma_m_axi_rready(slice_dma_rready)
			);
			if (ENABLE_WDOG_CTRL_SLAVE) begin : gen_wdog_cs
				axil_watchdog_slave_monitor #(
					.ENABLE_TIMEOUT(1'b1),
					.ENABLE_PROTOCOL_CHECK(1'b1),
					.ENABLE_STRICT_PAYLOAD_CHECK(ENABLE_STRICT_PAYLOAD_CHECK),
					.WATCHDOG_LIMIT(WATCHDOG_LIMIT)
				) inst_wdog_cs(
					.clk_i(clk_i),
					.rstn_i(rstn_i),
					.awvalid(dec_ctrl_awvalid),
					.awready(dec_ctrl_awready),
					.wvalid(dec_ctrl_wvalid),
					.wready(dec_ctrl_wready),
					.bvalid(dec_ctrl_bvalid),
					.bready(dec_ctrl_bready),
					.bresp(dec_ctrl_bresp),
					.arvalid(dec_ctrl_arvalid),
					.arready(dec_ctrl_arready),
					.rvalid(dec_ctrl_rvalid),
					.rready(dec_ctrl_rready),
					.rdata(dec_ctrl_rdata),
					.rresp(dec_ctrl_rresp),
					.timeout_w_fault_o(wdog_cs_to_w[i]),
					.timeout_r_fault_o(wdog_cs_to_r[i]),
					.protocol_w_fault_o(wdog_cs_pr_w[i]),
					.protocol_r_fault_o(wdog_cs_pr_r[i])
				);
			end
			else begin : gen_no_wdog_cs
				assign wdog_cs_to_w[i] = 0;
				assign wdog_cs_to_r[i] = 0;
				assign wdog_cs_pr_w[i] = 0;
				assign wdog_cs_pr_r[i] = 0;
			end
			if (ENABLE_PMP) begin : gen_pmp
				pmp_math #(
					.NUM_REGIONS(NUM_REGIONS),
					.PAGE_GRANULARITY(PAGE_GRANULARITY),
					.MAX_ADDRESS_WIDTH(MAX_ADDRESS_WIDTH)
				) pmp_inst(
					.g_en_i(p_g_en[i]),
					.base_i(p_base[32 * (i * NUM_REGIONS)+:32 * NUM_REGIONS]),
					.limit_i(p_limit[32 * (i * NUM_REGIONS)+:32 * NUM_REGIONS]),
					.awaddr_i(dec_dma_awaddr),
					.awlen_i(dec_dma_awlen),
					.awsize_i(dec_dma_awsize),
					.awprot_i(dec_dma_awprot),
					.awvalid_i(dec_dma_awvalid),
					.araddr_i(dec_dma_araddr),
					.arlen_i(dec_dma_arlen),
					.arsize_i(dec_dma_arsize),
					.arprot_i(dec_dma_arprot),
					.arvalid_i(dec_dma_arvalid),
					.violation_r_o(pmp_r_violation[i]),
					.violation_w_o(pmp_w_violation[i])
				);
			end
			else begin : gen_no_pmp
				assign pmp_r_violation[i] = 0;
				assign pmp_w_violation[i] = 0;
			end
			if (ENABLE_WDOG_DMA_MASTER) begin : gen_wdog_dm
				axi_watchdog_master_monitor #(
					.ENABLE_TIMEOUT(1'b1),
					.ENABLE_PROTOCOL_CHECK(1'b1),
					.ENABLE_STRICT_PAYLOAD_CHECK(ENABLE_STRICT_PAYLOAD_CHECK),
					.WATCHDOG_LIMIT(WATCHDOG_LIMIT),
					.AXI_ID_WIDTH(AXI_ID_WIDTH)
				) inst_wdog_dm(
					.clk_i(clk_i),
					.rstn_i(rstn_i),
					.awvalid(dec_dma_awvalid),
					.awready(dec_dma_awready),
					.awid(dec_dma_awid),
					.awaddr(dec_dma_awaddr),
					.awlen(dec_dma_awlen),
					.awsize(dec_dma_awsize),
					.awburst(dec_dma_awburst),
					.awlock(dec_dma_awlock),
					.awcache(dec_dma_awcache),
					.awprot(dec_dma_awprot),
					.wvalid(dec_dma_wvalid),
					.wready(dec_dma_wready),
					.wlast(dec_dma_wlast),
					.wdata(dec_dma_wdata),
					.wstrb(dec_dma_wstrb),
					.bvalid(dec_dma_bvalid),
					.bready(dec_dma_bready),
					.arvalid(dec_dma_arvalid),
					.arready(dec_dma_arready),
					.arid(dec_dma_arid),
					.araddr(dec_dma_araddr),
					.arlen(dec_dma_arlen),
					.arsize(dec_dma_arsize),
					.arburst(dec_dma_arburst),
					.arlock(dec_dma_arlock),
					.arcache(dec_dma_arcache),
					.arprot(dec_dma_arprot),
					.rvalid(dec_dma_rvalid),
					.rready(dec_dma_rready),
					.rlast(dec_dma_rlast),
					.timeout_w_fault_o(wdog_dm_to_w[i]),
					.timeout_r_fault_o(wdog_dm_to_r[i]),
					.protocol_w_fault_o(wdog_dm_pr_w[i]),
					.protocol_r_fault_o(wdog_dm_pr_r[i])
				);
			end
			else begin : gen_no_wdog_dm
				assign wdog_dm_to_w[i] = 0;
				assign wdog_dm_to_r[i] = 0;
				assign wdog_dm_pr_w[i] = 0;
				assign wdog_dm_pr_r[i] = 0;
			end
			if (ENABLE_BRIDGE_CTRL) begin : gen_bridge_ctrl
				bridge_soc_to_fabric_slave bridge_ctrl_inst(
					.clk(clk_i),
					.resetn(rstn_i),
					.cfg_wb_enable(slot_wb_s_en[i]),
					.soc_awaddr(dec_ctrl_awaddr),
					.soc_awprot(dec_ctrl_awprot),
					.soc_awvalid(dec_ctrl_awvalid),
					.soc_awready(dec_ctrl_awready),
					.soc_wdata(dec_ctrl_wdata),
					.soc_wstrb(dec_ctrl_wstrb),
					.soc_wvalid(dec_ctrl_wvalid),
					.soc_wready(dec_ctrl_wready),
					.soc_bresp(dec_ctrl_bresp),
					.soc_bvalid(dec_ctrl_bvalid),
					.soc_bready(dec_ctrl_bready),
					.soc_araddr(dec_ctrl_araddr),
					.soc_arprot(dec_ctrl_arprot),
					.soc_arvalid(dec_ctrl_arvalid),
					.soc_arready(dec_ctrl_arready),
					.soc_rdata(dec_ctrl_rdata),
					.soc_rresp(dec_ctrl_rresp),
					.soc_rvalid(dec_ctrl_rvalid),
					.soc_rready(dec_ctrl_rready),
					.fab_awaddr(ctrl_m_awaddr[i * 32+:32]),
					.fab_awprot(ctrl_m_awprot[i * 3+:3]),
					.fab_awvalid(ctrl_m_awvalid[i]),
					.fab_awready(ctrl_m_awready[i]),
					.fab_wdata(ctrl_m_wdata[i * 32+:32]),
					.fab_wstrb(ctrl_m_wstrb[i * 4+:4]),
					.fab_wvalid(ctrl_m_wvalid[i]),
					.fab_wready(ctrl_m_wready[i]),
					.fab_bresp(ctrl_m_bresp[i * 2+:2]),
					.fab_bvalid(ctrl_m_bvalid[i]),
					.fab_bready(ctrl_m_bready[i]),
					.fab_araddr(ctrl_m_araddr[i * 32+:32]),
					.fab_arprot(ctrl_m_arprot[i * 3+:3]),
					.fab_arvalid(ctrl_m_arvalid[i]),
					.fab_arready(ctrl_m_arready[i]),
					.fab_rdata(ctrl_m_rdata[i * 32+:32]),
					.fab_rresp(ctrl_m_rresp[i * 2+:2]),
					.fab_rvalid(ctrl_m_rvalid[i]),
					.fab_rready(ctrl_m_rready[i])
				);
			end
			else begin : gen_bypass_bridge_ctrl
				assign ctrl_m_awaddr[i * 32+:32] = dec_ctrl_awaddr;
				assign ctrl_m_awprot[i * 3+:3] = dec_ctrl_awprot;
				assign ctrl_m_awvalid[i] = dec_ctrl_awvalid;
				assign dec_ctrl_awready = ctrl_m_awready[i];
				assign ctrl_m_wdata[i * 32+:32] = dec_ctrl_wdata;
				assign ctrl_m_wstrb[i * 4+:4] = dec_ctrl_wstrb;
				assign ctrl_m_wvalid[i] = dec_ctrl_wvalid;
				assign dec_ctrl_wready = ctrl_m_wready[i];
				assign dec_ctrl_bresp = ctrl_m_bresp[i * 2+:2];
				assign dec_ctrl_bvalid = ctrl_m_bvalid[i];
				assign ctrl_m_bready[i] = dec_ctrl_bready;
				assign ctrl_m_araddr[i * 32+:32] = dec_ctrl_araddr;
				assign ctrl_m_arprot[i * 3+:3] = dec_ctrl_arprot;
				assign ctrl_m_arvalid[i] = dec_ctrl_arvalid;
				assign dec_ctrl_arready = ctrl_m_arready[i];
				assign dec_ctrl_rdata = ctrl_m_rdata[i * 32+:32];
				assign dec_ctrl_rresp = ctrl_m_rresp[i * 2+:2];
				assign dec_ctrl_rvalid = ctrl_m_rvalid[i];
				assign ctrl_m_rready[i] = dec_ctrl_rready;
			end
			if (ENABLE_BRIDGE_DMA) begin : gen_bridge_dma
				bridge_fabric_master_to_soc #(.AXI_ID_WIDTH(AXI_ID_WIDTH)) bridge_dma_inst(
					.clk(clk_i),
					.resetn(rstn_i),
					.cfg_wb_enable(slot_wb_m_en[i]),
					.fab_awid(dma_s_awid[i * AXI_ID_WIDTH+:AXI_ID_WIDTH]),
					.fab_awaddr(dma_s_awaddr[i * 32+:32]),
					.fab_awlen(dma_s_awlen[i * 8+:8]),
					.fab_awsize(dma_s_awsize[i * 3+:3]),
					.fab_awburst(dma_s_awburst[i * 2+:2]),
					.fab_awlock(dma_s_awlock[i]),
					.fab_awcache(dma_s_awcache[i * 4+:4]),
					.fab_awprot(dma_s_awprot[i * 3+:3]),
					.fab_awvalid(dma_s_awvalid[i]),
					.fab_awready(dma_s_awready[i]),
					.fab_wdata(dma_s_wdata[i * 32+:32]),
					.fab_wstrb(dma_s_wstrb[i * 4+:4]),
					.fab_wlast(dma_s_wlast[i]),
					.fab_wvalid(dma_s_wvalid[i]),
					.fab_wready(dma_s_wready[i]),
					.fab_bid(dma_s_bid[i * AXI_ID_WIDTH+:AXI_ID_WIDTH]),
					.fab_bresp(dma_s_bresp[i * 2+:2]),
					.fab_bvalid(dma_s_bvalid[i]),
					.fab_bready(dma_s_bready[i]),
					.fab_arid(dma_s_arid[i * AXI_ID_WIDTH+:AXI_ID_WIDTH]),
					.fab_araddr(dma_s_araddr[i * 32+:32]),
					.fab_arlen(dma_s_arlen[i * 8+:8]),
					.fab_arsize(dma_s_arsize[i * 3+:3]),
					.fab_arburst(dma_s_arburst[i * 2+:2]),
					.fab_arlock(dma_s_arlock[i]),
					.fab_arcache(dma_s_arcache[i * 4+:4]),
					.fab_arprot(dma_s_arprot[i * 3+:3]),
					.fab_arvalid(dma_s_arvalid[i]),
					.fab_arready(dma_s_arready[i]),
					.fab_rid(dma_s_rid[i * AXI_ID_WIDTH+:AXI_ID_WIDTH]),
					.fab_rdata(dma_s_rdata[i * 32+:32]),
					.fab_rresp(dma_s_rresp[i * 2+:2]),
					.fab_rlast(dma_s_rlast[i]),
					.fab_rvalid(dma_s_rvalid[i]),
					.fab_rready(dma_s_rready[i]),
					.soc_awid(dec_dma_awid),
					.soc_awaddr(dec_dma_awaddr),
					.soc_awlen(dec_dma_awlen),
					.soc_awsize(dec_dma_awsize),
					.soc_awburst(dec_dma_awburst),
					.soc_awlock(dec_dma_awlock),
					.soc_awcache(dec_dma_awcache),
					.soc_awprot(dec_dma_awprot),
					.soc_awvalid(dec_dma_awvalid),
					.soc_awready(dec_dma_awready),
					.soc_wdata(dec_dma_wdata),
					.soc_wstrb(dec_dma_wstrb),
					.soc_wlast(dec_dma_wlast),
					.soc_wvalid(dec_dma_wvalid),
					.soc_wready(dec_dma_wready),
					.soc_bid(dec_dma_bid),
					.soc_bresp(dec_dma_bresp),
					.soc_bvalid(dec_dma_bvalid),
					.soc_bready(dec_dma_bready),
					.soc_arid(dec_dma_arid),
					.soc_araddr(dec_dma_araddr),
					.soc_arlen(dec_dma_arlen),
					.soc_arsize(dec_dma_arsize),
					.soc_arburst(dec_dma_arburst),
					.soc_arlock(dec_dma_arlock),
					.soc_arcache(dec_dma_arcache),
					.soc_arprot(dec_dma_arprot),
					.soc_arvalid(dec_dma_arvalid),
					.soc_arready(dec_dma_arready),
					.soc_rid(dec_dma_rid),
					.soc_rdata(dec_dma_rdata),
					.soc_rresp(dec_dma_rresp),
					.soc_rlast(dec_dma_rlast),
					.soc_rvalid(dec_dma_rvalid),
					.soc_rready(dec_dma_rready)
				);
			end
			else begin : gen_bypass_bridge_dma
				assign dec_dma_awid = dma_s_awid[i * AXI_ID_WIDTH+:AXI_ID_WIDTH];
				assign dec_dma_awaddr = dma_s_awaddr[i * 32+:32];
				assign dec_dma_awlen = dma_s_awlen[i * 8+:8];
				assign dec_dma_awsize = dma_s_awsize[i * 3+:3];
				assign dec_dma_awburst = dma_s_awburst[i * 2+:2];
				assign dec_dma_awlock = dma_s_awlock[i];
				assign dec_dma_awcache = dma_s_awcache[i * 4+:4];
				assign dec_dma_awprot = dma_s_awprot[i * 3+:3];
				assign dec_dma_awvalid = dma_s_awvalid[i];
				assign dma_s_awready[i] = dec_dma_awready;
				assign dec_dma_wdata = dma_s_wdata[i * 32+:32];
				assign dec_dma_wstrb = dma_s_wstrb[i * 4+:4];
				assign dec_dma_wlast = dma_s_wlast[i];
				assign dec_dma_wvalid = dma_s_wvalid[i];
				assign dma_s_wready[i] = dec_dma_wready;
				assign dma_s_bid[i * AXI_ID_WIDTH+:AXI_ID_WIDTH] = dec_dma_bid;
				assign dma_s_bresp[i * 2+:2] = dec_dma_bresp;
				assign dma_s_bvalid[i] = dec_dma_bvalid;
				assign dec_dma_bready = dma_s_bready[i];
				assign dec_dma_arid = dma_s_arid[i * AXI_ID_WIDTH+:AXI_ID_WIDTH];
				assign dec_dma_araddr = dma_s_araddr[i * 32+:32];
				assign dec_dma_arlen = dma_s_arlen[i * 8+:8];
				assign dec_dma_arsize = dma_s_arsize[i * 3+:3];
				assign dec_dma_arburst = dma_s_arburst[i * 2+:2];
				assign dec_dma_arlock = dma_s_arlock[i];
				assign dec_dma_arcache = dma_s_arcache[i * 4+:4];
				assign dec_dma_arprot = dma_s_arprot[i * 3+:3];
				assign dec_dma_arvalid = dma_s_arvalid[i];
				assign dma_s_arready[i] = dec_dma_arready;
				assign dma_s_rid[i * AXI_ID_WIDTH+:AXI_ID_WIDTH] = dec_dma_rid;
				assign dma_s_rdata[i * 32+:32] = dec_dma_rdata;
				assign dma_s_rresp[i * 2+:2] = dec_dma_rresp;
				assign dma_s_rlast[i] = dec_dma_rlast;
				assign dma_s_rvalid[i] = dec_dma_rvalid;
				assign dec_dma_rready = dma_s_rready[i];
			end
			if (ENABLE_WDOG_DMA_SLAVE) begin : gen_wdog_ds
				axi_watchdog_slave_monitor #(
					.ENABLE_TIMEOUT(1'b1),
					.ENABLE_PROTOCOL_CHECK(1'b1),
					.ENABLE_STRICT_PAYLOAD_CHECK(ENABLE_STRICT_PAYLOAD_CHECK),
					.WATCHDOG_LIMIT(WATCHDOG_LIMIT),
					.AXI_ID_WIDTH(AXI_ID_WIDTH)
				) inst_wdog_ds(
					.clk_i(clk_i),
					.rstn_i(rstn_i),
					.awvalid(slice_dma_awvalid),
					.awready(slice_dma_awready),
					.wvalid(slice_dma_wvalid),
					.wready(slice_dma_wready),
					.wlast(slice_dma_wlast),
					.bvalid(slice_dma_bvalid),
					.bready(slice_dma_bready),
					.bid(slice_dma_bid),
					.bresp(slice_dma_bresp),
					.arvalid(slice_dma_arvalid),
					.arready(slice_dma_arready),
					.rvalid(slice_dma_rvalid),
					.rready(slice_dma_rready),
					.rlast(slice_dma_rlast),
					.rid(slice_dma_rid),
					.rdata(slice_dma_rdata),
					.rresp(slice_dma_rresp),
					.timeout_w_fault_o(wdog_ds_to_w[i]),
					.timeout_r_fault_o(wdog_ds_to_r[i]),
					.protocol_w_fault_o(wdog_ds_pr_w[i]),
					.protocol_r_fault_o(wdog_ds_pr_r[i])
				);
			end
			else begin : gen_no_wdog_ds
				assign wdog_ds_to_w[i] = 0;
				assign wdog_ds_to_r[i] = 0;
				assign wdog_ds_pr_w[i] = 0;
				assign wdog_ds_pr_r[i] = 0;
			end
		end
	endgenerate
endmodule
