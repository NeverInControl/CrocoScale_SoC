module efpga_subsystem_top (
	clk_i,
	rstn_i,
	rst_i,
	s_axil_mgr_awaddr,
	s_axil_mgr_awprot,
	s_axil_mgr_awvalid,
	s_axil_mgr_awready,
	s_axil_mgr_wdata,
	s_axil_mgr_wstrb,
	s_axil_mgr_wvalid,
	s_axil_mgr_wready,
	s_axil_mgr_bresp,
	s_axil_mgr_bvalid,
	s_axil_mgr_bready,
	s_axil_mgr_araddr,
	s_axil_mgr_arprot,
	s_axil_mgr_arvalid,
	s_axil_mgr_arready,
	s_axil_mgr_rdata,
	s_axil_mgr_rresp,
	s_axil_mgr_rvalid,
	s_axil_mgr_rready,
	s_axil_ctrl_awaddr,
	s_axil_ctrl_awprot,
	s_axil_ctrl_awvalid,
	s_axil_ctrl_awready,
	s_axil_ctrl_wdata,
	s_axil_ctrl_wstrb,
	s_axil_ctrl_wvalid,
	s_axil_ctrl_wready,
	s_axil_ctrl_bresp,
	s_axil_ctrl_bvalid,
	s_axil_ctrl_bready,
	s_axil_ctrl_araddr,
	s_axil_ctrl_arprot,
	s_axil_ctrl_arvalid,
	s_axil_ctrl_arready,
	s_axil_ctrl_rdata,
	s_axil_ctrl_rresp,
	s_axil_ctrl_rvalid,
	s_axil_ctrl_rready,
	m_axi_dma_awid,
	m_axi_dma_awaddr,
	m_axi_dma_awlen,
	m_axi_dma_awsize,
	m_axi_dma_awburst,
	m_axi_dma_awlock,
	m_axi_dma_awcache,
	m_axi_dma_awprot,
	m_axi_dma_awvalid,
	m_axi_dma_awready,
	m_axi_dma_wdata,
	m_axi_dma_wstrb,
	m_axi_dma_wlast,
	m_axi_dma_wvalid,
	m_axi_dma_wready,
	m_axi_dma_bid,
	m_axi_dma_bresp,
	m_axi_dma_bvalid,
	m_axi_dma_bready,
	m_axi_dma_arid,
	m_axi_dma_araddr,
	m_axi_dma_arlen,
	m_axi_dma_arsize,
	m_axi_dma_arburst,
	m_axi_dma_arlock,
	m_axi_dma_arcache,
	m_axi_dma_arprot,
	m_axi_dma_arvalid,
	m_axi_dma_arready,
	m_axi_dma_rid,
	m_axi_dma_rdata,
	m_axi_dma_rresp,
	m_axi_dma_rlast,
	m_axi_dma_rvalid,
	m_axi_dma_rready
);
	parameter signed [31:0] NUM_SLOTS = 1;
	parameter signed [31:0] AXI_ID_WIDTH = 8;
	parameter [31:0] HW_VERSION = 32'hfab00001;
	input wire clk_i;
	input wire rstn_i;
	input wire rst_i;
	input wire [31:0] s_axil_mgr_awaddr;
	input wire [2:0] s_axil_mgr_awprot;
	input wire s_axil_mgr_awvalid;
	output wire s_axil_mgr_awready;
	input wire [31:0] s_axil_mgr_wdata;
	input wire [3:0] s_axil_mgr_wstrb;
	input wire s_axil_mgr_wvalid;
	output wire s_axil_mgr_wready;
	output wire [1:0] s_axil_mgr_bresp;
	output wire s_axil_mgr_bvalid;
	input wire s_axil_mgr_bready;
	input wire [31:0] s_axil_mgr_araddr;
	input wire [2:0] s_axil_mgr_arprot;
	input wire s_axil_mgr_arvalid;
	output wire s_axil_mgr_arready;
	output wire [31:0] s_axil_mgr_rdata;
	output wire [1:0] s_axil_mgr_rresp;
	output wire s_axil_mgr_rvalid;
	input wire s_axil_mgr_rready;
	input wire [(NUM_SLOTS * 32) - 1:0] s_axil_ctrl_awaddr;
	input wire [(NUM_SLOTS * 3) - 1:0] s_axil_ctrl_awprot;
	input wire [NUM_SLOTS - 1:0] s_axil_ctrl_awvalid;
	output wire [NUM_SLOTS - 1:0] s_axil_ctrl_awready;
	input wire [(NUM_SLOTS * 32) - 1:0] s_axil_ctrl_wdata;
	input wire [(NUM_SLOTS * 4) - 1:0] s_axil_ctrl_wstrb;
	input wire [NUM_SLOTS - 1:0] s_axil_ctrl_wvalid;
	output wire [NUM_SLOTS - 1:0] s_axil_ctrl_wready;
	output wire [(NUM_SLOTS * 2) - 1:0] s_axil_ctrl_bresp;
	output wire [NUM_SLOTS - 1:0] s_axil_ctrl_bvalid;
	input wire [NUM_SLOTS - 1:0] s_axil_ctrl_bready;
	input wire [(NUM_SLOTS * 32) - 1:0] s_axil_ctrl_araddr;
	input wire [(NUM_SLOTS * 3) - 1:0] s_axil_ctrl_arprot;
	input wire [NUM_SLOTS - 1:0] s_axil_ctrl_arvalid;
	output wire [NUM_SLOTS - 1:0] s_axil_ctrl_arready;
	output wire [(NUM_SLOTS * 32) - 1:0] s_axil_ctrl_rdata;
	output wire [(NUM_SLOTS * 2) - 1:0] s_axil_ctrl_rresp;
	output wire [NUM_SLOTS - 1:0] s_axil_ctrl_rvalid;
	input wire [NUM_SLOTS - 1:0] s_axil_ctrl_rready;
	output wire [(NUM_SLOTS * AXI_ID_WIDTH) - 1:0] m_axi_dma_awid;
	output wire [(NUM_SLOTS * 32) - 1:0] m_axi_dma_awaddr;
	output wire [(NUM_SLOTS * 8) - 1:0] m_axi_dma_awlen;
	output wire [(NUM_SLOTS * 3) - 1:0] m_axi_dma_awsize;
	output wire [(NUM_SLOTS * 2) - 1:0] m_axi_dma_awburst;
	output wire [NUM_SLOTS - 1:0] m_axi_dma_awlock;
	output wire [(NUM_SLOTS * 4) - 1:0] m_axi_dma_awcache;
	output wire [(NUM_SLOTS * 3) - 1:0] m_axi_dma_awprot;
	output wire [NUM_SLOTS - 1:0] m_axi_dma_awvalid;
	input wire [NUM_SLOTS - 1:0] m_axi_dma_awready;
	output wire [(NUM_SLOTS * 32) - 1:0] m_axi_dma_wdata;
	output wire [(NUM_SLOTS * 4) - 1:0] m_axi_dma_wstrb;
	output wire [NUM_SLOTS - 1:0] m_axi_dma_wlast;
	output wire [NUM_SLOTS - 1:0] m_axi_dma_wvalid;
	input wire [NUM_SLOTS - 1:0] m_axi_dma_wready;
	input wire [(NUM_SLOTS * AXI_ID_WIDTH) - 1:0] m_axi_dma_bid;
	input wire [(NUM_SLOTS * 2) - 1:0] m_axi_dma_bresp;
	input wire [NUM_SLOTS - 1:0] m_axi_dma_bvalid;
	output wire [NUM_SLOTS - 1:0] m_axi_dma_bready;
	output wire [(NUM_SLOTS * AXI_ID_WIDTH) - 1:0] m_axi_dma_arid;
	output wire [(NUM_SLOTS * 32) - 1:0] m_axi_dma_araddr;
	output wire [(NUM_SLOTS * 8) - 1:0] m_axi_dma_arlen;
	output wire [(NUM_SLOTS * 3) - 1:0] m_axi_dma_arsize;
	output wire [(NUM_SLOTS * 2) - 1:0] m_axi_dma_arburst;
	output wire [NUM_SLOTS - 1:0] m_axi_dma_arlock;
	output wire [(NUM_SLOTS * 4) - 1:0] m_axi_dma_arcache;
	output wire [(NUM_SLOTS * 3) - 1:0] m_axi_dma_arprot;
	output wire [NUM_SLOTS - 1:0] m_axi_dma_arvalid;
	input wire [NUM_SLOTS - 1:0] m_axi_dma_arready;
	input wire [(NUM_SLOTS * AXI_ID_WIDTH) - 1:0] m_axi_dma_rid;
	input wire [(NUM_SLOTS * 32) - 1:0] m_axi_dma_rdata;
	input wire [(NUM_SLOTS * 2) - 1:0] m_axi_dma_rresp;
	input wire [NUM_SLOTS - 1:0] m_axi_dma_rlast;
	input wire [NUM_SLOTS - 1:0] m_axi_dma_rvalid;
	output wire [NUM_SLOTS - 1:0] m_axi_dma_rready;
	wire [(NUM_SLOTS * 32) - 1:0] axil_ctrl_m_awaddr;
	wire [(NUM_SLOTS * 32) - 1:0] axil_ctrl_m_wdata;
	wire [(NUM_SLOTS * 32) - 1:0] axil_ctrl_m_araddr;
	wire [(NUM_SLOTS * 32) - 1:0] axil_ctrl_m_rdata;
	wire [(NUM_SLOTS * 4) - 1:0] axil_ctrl_m_wstrb;
	wire [(NUM_SLOTS * 3) - 1:0] axil_ctrl_m_awprot;
	wire [(NUM_SLOTS * 3) - 1:0] axil_ctrl_m_arprot;
	wire [(NUM_SLOTS * 2) - 1:0] axil_ctrl_m_bresp;
	wire [(NUM_SLOTS * 2) - 1:0] axil_ctrl_m_rresp;
	wire [NUM_SLOTS - 1:0] axil_ctrl_m_awvalid;
	wire [NUM_SLOTS - 1:0] axil_ctrl_m_awready;
	wire [NUM_SLOTS - 1:0] axil_ctrl_m_wvalid;
	wire [NUM_SLOTS - 1:0] axil_ctrl_m_wready;
	wire [NUM_SLOTS - 1:0] axil_ctrl_m_bvalid;
	wire [NUM_SLOTS - 1:0] axil_ctrl_m_bready;
	wire [NUM_SLOTS - 1:0] axil_ctrl_m_arvalid;
	wire [NUM_SLOTS - 1:0] axil_ctrl_m_arready;
	wire [NUM_SLOTS - 1:0] axil_ctrl_m_rvalid;
	wire [NUM_SLOTS - 1:0] axil_ctrl_m_rready;
	wire [(NUM_SLOTS * 32) - 1:0] axi4_dma_s_awaddr;
	wire [(NUM_SLOTS * 32) - 1:0] axi4_dma_s_wdata;
	wire [(NUM_SLOTS * 32) - 1:0] axi4_dma_s_araddr;
	wire [(NUM_SLOTS * 32) - 1:0] axi4_dma_s_rdata;
	wire [(NUM_SLOTS * 4) - 1:0] axi4_dma_s_wstrb;
	wire [(NUM_SLOTS * 4) - 1:0] axi4_dma_s_awcache;
	wire [(NUM_SLOTS * 4) - 1:0] axi4_dma_s_arcache;
	wire [(NUM_SLOTS * 3) - 1:0] axi4_dma_s_awsize;
	wire [(NUM_SLOTS * 3) - 1:0] axi4_dma_s_arsize;
	wire [(NUM_SLOTS * 3) - 1:0] axi4_dma_s_awprot;
	wire [(NUM_SLOTS * 3) - 1:0] axi4_dma_s_arprot;
	wire [(NUM_SLOTS * 2) - 1:0] axi4_dma_s_awburst;
	wire [(NUM_SLOTS * 2) - 1:0] axi4_dma_s_arburst;
	wire [(NUM_SLOTS * 2) - 1:0] axi4_dma_s_bresp;
	wire [(NUM_SLOTS * 2) - 1:0] axi4_dma_s_rresp;
	wire [(NUM_SLOTS * AXI_ID_WIDTH) - 1:0] axi4_dma_s_awid;
	wire [(NUM_SLOTS * AXI_ID_WIDTH) - 1:0] axi4_dma_s_bid;
	wire [(NUM_SLOTS * AXI_ID_WIDTH) - 1:0] axi4_dma_s_arid;
	wire [(NUM_SLOTS * AXI_ID_WIDTH) - 1:0] axi4_dma_s_rid;
	wire [(NUM_SLOTS * 8) - 1:0] axi4_dma_s_awlen;
	wire [(NUM_SLOTS * 8) - 1:0] axi4_dma_s_arlen;
	wire [NUM_SLOTS - 1:0] axi4_dma_s_awvalid;
	wire [NUM_SLOTS - 1:0] axi4_dma_s_awready;
	wire [NUM_SLOTS - 1:0] axi4_dma_s_wvalid;
	wire [NUM_SLOTS - 1:0] axi4_dma_s_wready;
	wire [NUM_SLOTS - 1:0] axi4_dma_s_bvalid;
	wire [NUM_SLOTS - 1:0] axi4_dma_s_bready;
	wire [NUM_SLOTS - 1:0] axi4_dma_s_arvalid;
	wire [NUM_SLOTS - 1:0] axi4_dma_s_arready;
	wire [NUM_SLOTS - 1:0] axi4_dma_s_rvalid;
	wire [NUM_SLOTS - 1:0] axi4_dma_s_rready;
	wire [NUM_SLOTS - 1:0] axi4_dma_s_wlast;
	wire [NUM_SLOTS - 1:0] axi4_dma_s_rlast;
	wire [NUM_SLOTS - 1:0] axi4_dma_s_awlock;
	wire [NUM_SLOTS - 1:0] axi4_dma_s_arlock;
	wire [31:0] efpga_config_data;
	wire efpga_config_we;
	wire efpga_soft_reset;
	wire efpga_com_active;
	wire [(NUM_SLOTS * 32) - 1:0] slot_i_top_arr;
	wire [(NUM_SLOTS * 32) - 1:0] slot_o_top_arr;
	efpga_connector #(
		.NUM_SLOTS(NUM_SLOTS),
		.AXI_ID_WIDTH(AXI_ID_WIDTH),
		.HW_VERSION(HW_VERSION)
	) efpga_connector_inst(
		.clk_i(clk_i),
		.rstn_i(rstn_i),
		.rst_i(rst_i),
		.mgr_s_awaddr(s_axil_mgr_awaddr),
		.mgr_s_awprot(s_axil_mgr_awprot),
		.mgr_s_awvalid(s_axil_mgr_awvalid),
		.mgr_s_awready(s_axil_mgr_awready),
		.mgr_s_wdata(s_axil_mgr_wdata),
		.mgr_s_wstrb(s_axil_mgr_wstrb),
		.mgr_s_wvalid(s_axil_mgr_wvalid),
		.mgr_s_wready(s_axil_mgr_wready),
		.mgr_s_bresp(s_axil_mgr_bresp),
		.mgr_s_bvalid(s_axil_mgr_bvalid),
		.mgr_s_bready(s_axil_mgr_bready),
		.mgr_s_araddr(s_axil_mgr_araddr),
		.mgr_s_arprot(s_axil_mgr_arprot),
		.mgr_s_arvalid(s_axil_mgr_arvalid),
		.mgr_s_arready(s_axil_mgr_arready),
		.mgr_s_rdata(s_axil_mgr_rdata),
		.mgr_s_rresp(s_axil_mgr_rresp),
		.mgr_s_rvalid(s_axil_mgr_rvalid),
		.mgr_s_rready(s_axil_mgr_rready),
		.ctrl_s_awaddr(s_axil_ctrl_awaddr),
		.ctrl_s_awprot(s_axil_ctrl_awprot),
		.ctrl_s_awvalid(s_axil_ctrl_awvalid),
		.ctrl_s_awready(s_axil_ctrl_awready),
		.ctrl_s_wdata(s_axil_ctrl_wdata),
		.ctrl_s_wstrb(s_axil_ctrl_wstrb),
		.ctrl_s_wvalid(s_axil_ctrl_wvalid),
		.ctrl_s_wready(s_axil_ctrl_wready),
		.ctrl_s_bresp(s_axil_ctrl_bresp),
		.ctrl_s_bvalid(s_axil_ctrl_bvalid),
		.ctrl_s_bready(s_axil_ctrl_bready),
		.ctrl_s_araddr(s_axil_ctrl_araddr),
		.ctrl_s_arprot(s_axil_ctrl_arprot),
		.ctrl_s_arvalid(s_axil_ctrl_arvalid),
		.ctrl_s_arready(s_axil_ctrl_arready),
		.ctrl_s_rdata(s_axil_ctrl_rdata),
		.ctrl_s_rresp(s_axil_ctrl_rresp),
		.ctrl_s_rvalid(s_axil_ctrl_rvalid),
		.ctrl_s_rready(s_axil_ctrl_rready),
		.ctrl_m_awaddr(axil_ctrl_m_awaddr),
		.ctrl_m_awprot(axil_ctrl_m_awprot),
		.ctrl_m_awvalid(axil_ctrl_m_awvalid),
		.ctrl_m_awready(axil_ctrl_m_awready),
		.ctrl_m_wdata(axil_ctrl_m_wdata),
		.ctrl_m_wstrb(axil_ctrl_m_wstrb),
		.ctrl_m_wvalid(axil_ctrl_m_wvalid),
		.ctrl_m_wready(axil_ctrl_m_wready),
		.ctrl_m_bresp(axil_ctrl_m_bresp),
		.ctrl_m_bvalid(axil_ctrl_m_bvalid),
		.ctrl_m_bready(axil_ctrl_m_bready),
		.ctrl_m_araddr(axil_ctrl_m_araddr),
		.ctrl_m_arprot(axil_ctrl_m_arprot),
		.ctrl_m_arvalid(axil_ctrl_m_arvalid),
		.ctrl_m_arready(axil_ctrl_m_arready),
		.ctrl_m_rdata(axil_ctrl_m_rdata),
		.ctrl_m_rresp(axil_ctrl_m_rresp),
		.ctrl_m_rvalid(axil_ctrl_m_rvalid),
		.ctrl_m_rready(axil_ctrl_m_rready),
		.dma_s_awid(axi4_dma_s_awid),
		.dma_s_awaddr(axi4_dma_s_awaddr),
		.dma_s_awlen(axi4_dma_s_awlen),
		.dma_s_awsize(axi4_dma_s_awsize),
		.dma_s_awburst(axi4_dma_s_awburst),
		.dma_s_awlock(axi4_dma_s_awlock),
		.dma_s_awcache(axi4_dma_s_awcache),
		.dma_s_awprot(axi4_dma_s_awprot),
		.dma_s_awvalid(axi4_dma_s_awvalid),
		.dma_s_awready(axi4_dma_s_awready),
		.dma_s_wdata(axi4_dma_s_wdata),
		.dma_s_wstrb(axi4_dma_s_wstrb),
		.dma_s_wlast(axi4_dma_s_wlast),
		.dma_s_wvalid(axi4_dma_s_wvalid),
		.dma_s_wready(axi4_dma_s_wready),
		.dma_s_bid(axi4_dma_s_bid),
		.dma_s_bresp(axi4_dma_s_bresp),
		.dma_s_bvalid(axi4_dma_s_bvalid),
		.dma_s_bready(axi4_dma_s_bready),
		.dma_s_arid(axi4_dma_s_arid),
		.dma_s_araddr(axi4_dma_s_araddr),
		.dma_s_arlen(axi4_dma_s_arlen),
		.dma_s_arsize(axi4_dma_s_arsize),
		.dma_s_arburst(axi4_dma_s_arburst),
		.dma_s_arlock(axi4_dma_s_arlock),
		.dma_s_arcache(axi4_dma_s_arcache),
		.dma_s_arprot(axi4_dma_s_arprot),
		.dma_s_arvalid(axi4_dma_s_arvalid),
		.dma_s_arready(axi4_dma_s_arready),
		.dma_s_rid(axi4_dma_s_rid),
		.dma_s_rdata(axi4_dma_s_rdata),
		.dma_s_rresp(axi4_dma_s_rresp),
		.dma_s_rlast(axi4_dma_s_rlast),
		.dma_s_rvalid(axi4_dma_s_rvalid),
		.dma_s_rready(axi4_dma_s_rready),
		.dma_m_awid(m_axi_dma_awid),
		.dma_m_awaddr(m_axi_dma_awaddr),
		.dma_m_awlen(m_axi_dma_awlen),
		.dma_m_awsize(m_axi_dma_awsize),
		.dma_m_awburst(m_axi_dma_awburst),
		.dma_m_awlock(m_axi_dma_awlock),
		.dma_m_awcache(m_axi_dma_awcache),
		.dma_m_awprot(m_axi_dma_awprot),
		.dma_m_awvalid(m_axi_dma_awvalid),
		.dma_m_awready(m_axi_dma_awready),
		.dma_m_wdata(m_axi_dma_wdata),
		.dma_m_wstrb(m_axi_dma_wstrb),
		.dma_m_wlast(m_axi_dma_wlast),
		.dma_m_wvalid(m_axi_dma_wvalid),
		.dma_m_wready(m_axi_dma_wready),
		.dma_m_bid(m_axi_dma_bid),
		.dma_m_bresp(m_axi_dma_bresp),
		.dma_m_bvalid(m_axi_dma_bvalid),
		.dma_m_bready(m_axi_dma_bready),
		.dma_m_arid(m_axi_dma_arid),
		.dma_m_araddr(m_axi_dma_araddr),
		.dma_m_arlen(m_axi_dma_arlen),
		.dma_m_arsize(m_axi_dma_arsize),
		.dma_m_arburst(m_axi_dma_arburst),
		.dma_m_arlock(m_axi_dma_arlock),
		.dma_m_arcache(m_axi_dma_arcache),
		.dma_m_arprot(m_axi_dma_arprot),
		.dma_m_arvalid(m_axi_dma_arvalid),
		.dma_m_arready(m_axi_dma_arready),
		.dma_m_rid(m_axi_dma_rid),
		.dma_m_rdata(m_axi_dma_rdata),
		.dma_m_rresp(m_axi_dma_rresp),
		.dma_m_rlast(m_axi_dma_rlast),
		.dma_m_rvalid(m_axi_dma_rvalid),
		.dma_m_rready(m_axi_dma_rready),
		.efpga_config_data_o(efpga_config_data),
		.efpga_config_we_o(efpga_config_we),
		.efpga_soft_reset_o(efpga_soft_reset),
		.efpga_com_active_i(efpga_com_active),
		.slot_i_top_i(slot_i_top_arr),
		.slot_o_top_o(slot_o_top_arr)
	);
	efpga_axi_subsystem_wrapper #(
		.NUM_SLOTS(NUM_SLOTS),
		.AXI_ID_WIDTH(AXI_ID_WIDTH)
	) efpga_subsystem_inst(
		.clk_i(clk_i),
		.rstn_i(rstn_i),
		.ctrl_m_awaddr(axil_ctrl_m_awaddr),
		.ctrl_m_awprot(axil_ctrl_m_awprot),
		.ctrl_m_awvalid(axil_ctrl_m_awvalid),
		.ctrl_m_awready(axil_ctrl_m_awready),
		.ctrl_m_wdata(axil_ctrl_m_wdata),
		.ctrl_m_wstrb(axil_ctrl_m_wstrb),
		.ctrl_m_wvalid(axil_ctrl_m_wvalid),
		.ctrl_m_wready(axil_ctrl_m_wready),
		.ctrl_m_bresp(axil_ctrl_m_bresp),
		.ctrl_m_bvalid(axil_ctrl_m_bvalid),
		.ctrl_m_bready(axil_ctrl_m_bready),
		.ctrl_m_araddr(axil_ctrl_m_araddr),
		.ctrl_m_arprot(axil_ctrl_m_arprot),
		.ctrl_m_arvalid(axil_ctrl_m_arvalid),
		.ctrl_m_arready(axil_ctrl_m_arready),
		.ctrl_m_rdata(axil_ctrl_m_rdata),
		.ctrl_m_rresp(axil_ctrl_m_rresp),
		.ctrl_m_rvalid(axil_ctrl_m_rvalid),
		.ctrl_m_rready(axil_ctrl_m_rready),
		.dma_s_awid(axi4_dma_s_awid),
		.dma_s_awaddr(axi4_dma_s_awaddr),
		.dma_s_awlen(axi4_dma_s_awlen),
		.dma_s_awsize(axi4_dma_s_awsize),
		.dma_s_awburst(axi4_dma_s_awburst),
		.dma_s_awlock(axi4_dma_s_awlock),
		.dma_s_awcache(axi4_dma_s_awcache),
		.dma_s_awprot(axi4_dma_s_awprot),
		.dma_s_awvalid(axi4_dma_s_awvalid),
		.dma_s_awready(axi4_dma_s_awready),
		.dma_s_wdata(axi4_dma_s_wdata),
		.dma_s_wstrb(axi4_dma_s_wstrb),
		.dma_s_wlast(axi4_dma_s_wlast),
		.dma_s_wvalid(axi4_dma_s_wvalid),
		.dma_s_wready(axi4_dma_s_wready),
		.dma_s_bid(axi4_dma_s_bid),
		.dma_s_bresp(axi4_dma_s_bresp),
		.dma_s_bvalid(axi4_dma_s_bvalid),
		.dma_s_bready(axi4_dma_s_bready),
		.dma_s_arid(axi4_dma_s_arid),
		.dma_s_araddr(axi4_dma_s_araddr),
		.dma_s_arlen(axi4_dma_s_arlen),
		.dma_s_arsize(axi4_dma_s_arsize),
		.dma_s_arburst(axi4_dma_s_arburst),
		.dma_s_arlock(axi4_dma_s_arlock),
		.dma_s_arcache(axi4_dma_s_arcache),
		.dma_s_arprot(axi4_dma_s_arprot),
		.dma_s_arvalid(axi4_dma_s_arvalid),
		.dma_s_arready(axi4_dma_s_arready),
		.dma_s_rid(axi4_dma_s_rid),
		.dma_s_rdata(axi4_dma_s_rdata),
		.dma_s_rresp(axi4_dma_s_rresp),
		.dma_s_rlast(axi4_dma_s_rlast),
		.dma_s_rvalid(axi4_dma_s_rvalid),
		.dma_s_rready(axi4_dma_s_rready),
		.efpga_config_we_i(efpga_config_we),
		.efpga_config_data_i(efpga_config_data),
		.efpga_soft_reset_i(efpga_soft_reset),
		.efpga_com_active_o(efpga_com_active),
		.slot_i_top_o(slot_i_top_arr),
		.slot_o_top_i(slot_o_top_arr)
	);
endmodule
