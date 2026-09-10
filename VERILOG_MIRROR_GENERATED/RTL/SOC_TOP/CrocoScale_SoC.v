module crocoscale_soc (
	clk_i,
	rstn_i,
	gpio_o,
	uart0_txd_o,
	uart0_rxd_i
);
	parameter signed [31:0] NUM_SLOTS = 1;
	parameter signed [31:0] MEM_SIZE = 131072;
	parameter [31:0] HW_VERSION = 32'hfab00001;
	parameter signed [31:0] AXI_ID_WIDTH = 8;
	input wire clk_i;
	input wire rstn_i;
	output wire [7:0] gpio_o;
	output wire uart0_txd_o;
	input wire uart0_rxd_i;
	wire [31:0] con_gpio_out;
	assign gpio_o = con_gpio_out[7:0];
	wire clk_10mhz = clk_i;
	reg rst_sync_0;
	reg rst_sync_1;
	always @(posedge clk_10mhz or negedge rstn_i)
		if (!rstn_i) begin
			rst_sync_0 <= 1'b0;
			rst_sync_1 <= 1'b0;
		end
		else begin
			rst_sync_0 <= 1'b1;
			rst_sync_1 <= rst_sync_0;
		end
	wire sys_rstn;
	wire sys_rst;
	assign sys_rstn = rst_sync_1;
	assign sys_rst = ~sys_rstn;
	localparam signed [31:0] S_COUNT = 1 + NUM_SLOTS;
	localparam signed [31:0] M_COUNT = 2 + NUM_SLOTS;
	localparam signed [31:0] M_ID_WIDTH = AXI_ID_WIDTH + $clog2(S_COUNT);
	function automatic [(M_COUNT * 32) - 1:0] get_m_base_addrs;
		input reg _sv2v_unused;
		reg [(M_COUNT * 32) - 1:0] map;
		begin
			map[0+:32] = 32'h00000000;
			map[32+:32] = 32'h10000000;
			begin : sv2v_autoblock_1
				reg signed [31:0] i;
				for (i = 0; i < NUM_SLOTS; i = i + 1)
					map[(2 + i) * 32+:32] = 32'h20000000 + (i * 32'h01000000);
			end
			get_m_base_addrs = map;
		end
	endfunction
	function automatic [(M_COUNT * 32) - 1:0] get_m_addr_widths;
		input reg _sv2v_unused;
		reg [(M_COUNT * 32) - 1:0] map;
		begin
			map[0+:32] = $clog2(MEM_SIZE);
			map[32+:32] = 32'd16;
			begin : sv2v_autoblock_2
				reg signed [31:0] i;
				for (i = 0; i < NUM_SLOTS; i = i + 1)
					map[(2 + i) * 32+:32] = 32'd16;
			end
			get_m_addr_widths = map;
		end
	endfunction
	localparam [(M_COUNT * 32) - 1:0] CROSSBAR_BASE_ADDRS = get_m_base_addrs(0);
	localparam [(M_COUNT * 32) - 1:0] CROSSBAR_ADDR_WIDTHS = get_m_addr_widths(0);
	wire [(S_COUNT * AXI_ID_WIDTH) - 1:0] s_axi_awid;
	wire [(S_COUNT * 32) - 1:0] s_axi_awaddr;
	wire [(S_COUNT * 8) - 1:0] s_axi_awlen;
	wire [(S_COUNT * 3) - 1:0] s_axi_awsize;
	wire [(S_COUNT * 2) - 1:0] s_axi_awburst;
	wire [S_COUNT - 1:0] s_axi_awlock;
	wire [(S_COUNT * 4) - 1:0] s_axi_awcache;
	wire [(S_COUNT * 3) - 1:0] s_axi_awprot;
	wire [S_COUNT - 1:0] s_axi_awvalid;
	wire [S_COUNT - 1:0] s_axi_awready;
	wire [(S_COUNT * 32) - 1:0] s_axi_wdata;
	wire [(S_COUNT * 4) - 1:0] s_axi_wstrb;
	wire [S_COUNT - 1:0] s_axi_wlast;
	wire [S_COUNT - 1:0] s_axi_wvalid;
	wire [S_COUNT - 1:0] s_axi_wready;
	wire [(S_COUNT * AXI_ID_WIDTH) - 1:0] s_axi_bid;
	wire [(S_COUNT * 2) - 1:0] s_axi_bresp;
	wire [S_COUNT - 1:0] s_axi_bvalid;
	wire [S_COUNT - 1:0] s_axi_bready;
	wire [(S_COUNT * AXI_ID_WIDTH) - 1:0] s_axi_arid;
	wire [(S_COUNT * 32) - 1:0] s_axi_araddr;
	wire [(S_COUNT * 8) - 1:0] s_axi_arlen;
	wire [(S_COUNT * 3) - 1:0] s_axi_arsize;
	wire [(S_COUNT * 2) - 1:0] s_axi_arburst;
	wire [S_COUNT - 1:0] s_axi_arlock;
	wire [(S_COUNT * 4) - 1:0] s_axi_arcache;
	wire [(S_COUNT * 3) - 1:0] s_axi_arprot;
	wire [S_COUNT - 1:0] s_axi_arvalid;
	wire [S_COUNT - 1:0] s_axi_arready;
	wire [(S_COUNT * AXI_ID_WIDTH) - 1:0] s_axi_rid;
	wire [(S_COUNT * 32) - 1:0] s_axi_rdata;
	wire [(S_COUNT * 2) - 1:0] s_axi_rresp;
	wire [S_COUNT - 1:0] s_axi_rlast;
	wire [S_COUNT - 1:0] s_axi_rvalid;
	wire [S_COUNT - 1:0] s_axi_rready;
	wire [(M_COUNT * M_ID_WIDTH) - 1:0] m_axi_awid;
	wire [(M_COUNT * 32) - 1:0] m_axi_awaddr;
	wire [(M_COUNT * 8) - 1:0] m_axi_awlen;
	wire [(M_COUNT * 3) - 1:0] m_axi_awsize;
	wire [(M_COUNT * 2) - 1:0] m_axi_awburst;
	wire [M_COUNT - 1:0] m_axi_awlock;
	wire [(M_COUNT * 4) - 1:0] m_axi_awcache;
	wire [(M_COUNT * 3) - 1:0] m_axi_awprot;
	wire [(M_COUNT * 4) - 1:0] m_axi_awqos;
	wire [(M_COUNT * 4) - 1:0] m_axi_awregion;
	wire [M_COUNT - 1:0] m_axi_awvalid;
	wire [M_COUNT - 1:0] m_axi_awready;
	wire [(M_COUNT * 32) - 1:0] m_axi_wdata;
	wire [(M_COUNT * 4) - 1:0] m_axi_wstrb;
	wire [M_COUNT - 1:0] m_axi_wlast;
	wire [M_COUNT - 1:0] m_axi_wvalid;
	wire [M_COUNT - 1:0] m_axi_wready;
	wire [(M_COUNT * M_ID_WIDTH) - 1:0] m_axi_bid;
	wire [(M_COUNT * 2) - 1:0] m_axi_bresp;
	wire [M_COUNT - 1:0] m_axi_bvalid;
	wire [M_COUNT - 1:0] m_axi_bready;
	wire [(M_COUNT * M_ID_WIDTH) - 1:0] m_axi_arid;
	wire [(M_COUNT * 32) - 1:0] m_axi_araddr;
	wire [(M_COUNT * 8) - 1:0] m_axi_arlen;
	wire [(M_COUNT * 3) - 1:0] m_axi_arsize;
	wire [(M_COUNT * 2) - 1:0] m_axi_arburst;
	wire [M_COUNT - 1:0] m_axi_arlock;
	wire [(M_COUNT * 4) - 1:0] m_axi_arcache;
	wire [(M_COUNT * 3) - 1:0] m_axi_arprot;
	wire [(M_COUNT * 4) - 1:0] m_axi_arqos;
	wire [(M_COUNT * 4) - 1:0] m_axi_arregion;
	wire [M_COUNT - 1:0] m_axi_arvalid;
	wire [M_COUNT - 1:0] m_axi_arready;
	wire [(M_COUNT * M_ID_WIDTH) - 1:0] m_axi_rid;
	wire [(M_COUNT * 32) - 1:0] m_axi_rdata;
	wire [(M_COUNT * 2) - 1:0] m_axi_rresp;
	wire [M_COUNT - 1:0] m_axi_rlast;
	wire [M_COUNT - 1:0] m_axi_rvalid;
	wire [M_COUNT - 1:0] m_axi_rready;
	neorv32_axi_wrapper cpu_complex_inst(
		.clk_i(clk_10mhz),
		.rstn_i(sys_rstn),
		.gpio_o(con_gpio_out),
		.uart0_txd_o(uart0_txd_o),
		.uart0_rxd_i(uart0_rxd_i),
		.m_axi_awaddr(s_axi_awaddr[0+:32]),
		.m_axi_awlen(s_axi_awlen[0+:8]),
		.m_axi_awsize(s_axi_awsize[0+:3]),
		.m_axi_awburst(s_axi_awburst[0+:2]),
		.m_axi_awcache(s_axi_awcache[0+:4]),
		.m_axi_awprot(s_axi_awprot[0+:3]),
		.m_axi_awvalid(s_axi_awvalid[0]),
		.m_axi_awready(s_axi_awready[0]),
		.m_axi_wdata(s_axi_wdata[0+:32]),
		.m_axi_wstrb(s_axi_wstrb[0+:4]),
		.m_axi_wlast(s_axi_wlast[0]),
		.m_axi_wvalid(s_axi_wvalid[0]),
		.m_axi_wready(s_axi_wready[0]),
		.m_axi_bresp(s_axi_bresp[0+:2]),
		.m_axi_bvalid(s_axi_bvalid[0]),
		.m_axi_bready(s_axi_bready[0]),
		.m_axi_araddr(s_axi_araddr[0+:32]),
		.m_axi_arlen(s_axi_arlen[0+:8]),
		.m_axi_arsize(s_axi_arsize[0+:3]),
		.m_axi_arburst(s_axi_arburst[0+:2]),
		.m_axi_arcache(s_axi_arcache[0+:4]),
		.m_axi_arprot(s_axi_arprot[0+:3]),
		.m_axi_arvalid(s_axi_arvalid[0]),
		.m_axi_arready(s_axi_arready[0]),
		.m_axi_rdata(s_axi_rdata[0+:32]),
		.m_axi_rresp(s_axi_rresp[0+:2]),
		.m_axi_rlast(s_axi_rlast[0]),
		.m_axi_rvalid(s_axi_rvalid[0]),
		.m_axi_rready(s_axi_rready[0])
	);
	assign s_axi_awid[0+:AXI_ID_WIDTH] = {AXI_ID_WIDTH {1'b0}};
	assign s_axi_arid[0+:AXI_ID_WIDTH] = {AXI_ID_WIDTH {1'b0}};
	assign s_axi_awlock[0] = 1'b0;
	assign s_axi_arlock[0] = 1'b0;
	axi_crossbar #(
		.S_COUNT(S_COUNT),
		.M_COUNT(M_COUNT),
		.DATA_WIDTH(32),
		.ADDR_WIDTH(32),
		.STRB_WIDTH(4),
		.S_ID_WIDTH(AXI_ID_WIDTH),
		.M_ID_WIDTH(M_ID_WIDTH),
		.M_BASE_ADDR(CROSSBAR_BASE_ADDRS),
		.M_ADDR_WIDTH(CROSSBAR_ADDR_WIDTHS),
		.S_AW_REG_TYPE({S_COUNT {2'd1}}),
		.S_W_REG_TYPE({S_COUNT {2'd2}}),
		.S_B_REG_TYPE({S_COUNT {2'd1}}),
		.S_AR_REG_TYPE({S_COUNT {2'd1}}),
		.S_R_REG_TYPE({S_COUNT {2'd2}}),
		.M_AW_REG_TYPE({M_COUNT {2'd1}}),
		.M_W_REG_TYPE({M_COUNT {2'd2}}),
		.M_B_REG_TYPE({M_COUNT {2'd1}}),
		.M_AR_REG_TYPE({M_COUNT {2'd1}}),
		.M_R_REG_TYPE({M_COUNT {2'd2}})
	) axi_crossbar_inst(
		.clk(clk_10mhz),
		.rst(sys_rst),
		.s_axi_awid(s_axi_awid),
		.s_axi_awaddr(s_axi_awaddr),
		.s_axi_awlen(s_axi_awlen),
		.s_axi_awsize(s_axi_awsize),
		.s_axi_awburst(s_axi_awburst),
		.s_axi_awlock(s_axi_awlock),
		.s_axi_awcache(s_axi_awcache),
		.s_axi_awprot(s_axi_awprot),
		.s_axi_awqos(1'sb0),
		.s_axi_awuser(1'sb0),
		.s_axi_awvalid(s_axi_awvalid),
		.s_axi_awready(s_axi_awready),
		.s_axi_wdata(s_axi_wdata),
		.s_axi_wstrb(s_axi_wstrb),
		.s_axi_wlast(s_axi_wlast),
		.s_axi_wuser(1'sb0),
		.s_axi_wvalid(s_axi_wvalid),
		.s_axi_wready(s_axi_wready),
		.s_axi_bid(s_axi_bid),
		.s_axi_bresp(s_axi_bresp),
		.s_axi_buser(),
		.s_axi_bvalid(s_axi_bvalid),
		.s_axi_bready(s_axi_bready),
		.s_axi_arid(s_axi_arid),
		.s_axi_araddr(s_axi_araddr),
		.s_axi_arlen(s_axi_arlen),
		.s_axi_arsize(s_axi_arsize),
		.s_axi_arburst(s_axi_arburst),
		.s_axi_arlock(s_axi_arlock),
		.s_axi_arcache(s_axi_arcache),
		.s_axi_arprot(s_axi_arprot),
		.s_axi_arqos(1'sb0),
		.s_axi_aruser(1'sb0),
		.s_axi_arvalid(s_axi_arvalid),
		.s_axi_arready(s_axi_arready),
		.s_axi_rid(s_axi_rid),
		.s_axi_rdata(s_axi_rdata),
		.s_axi_rresp(s_axi_rresp),
		.s_axi_rlast(s_axi_rlast),
		.s_axi_ruser(),
		.s_axi_rvalid(s_axi_rvalid),
		.s_axi_rready(s_axi_rready),
		.m_axi_awid(m_axi_awid),
		.m_axi_awaddr(m_axi_awaddr),
		.m_axi_awlen(m_axi_awlen),
		.m_axi_awsize(m_axi_awsize),
		.m_axi_awburst(m_axi_awburst),
		.m_axi_awlock(m_axi_awlock),
		.m_axi_awcache(m_axi_awcache),
		.m_axi_awprot(m_axi_awprot),
		.m_axi_awqos(m_axi_awqos),
		.m_axi_awregion(m_axi_awregion),
		.m_axi_awuser(),
		.m_axi_awvalid(m_axi_awvalid),
		.m_axi_awready(m_axi_awready),
		.m_axi_wdata(m_axi_wdata),
		.m_axi_wstrb(m_axi_wstrb),
		.m_axi_wlast(m_axi_wlast),
		.m_axi_wuser(),
		.m_axi_wvalid(m_axi_wvalid),
		.m_axi_wready(m_axi_wready),
		.m_axi_bid(m_axi_bid),
		.m_axi_bresp(m_axi_bresp),
		.m_axi_buser(1'sb0),
		.m_axi_bvalid(m_axi_bvalid),
		.m_axi_bready(m_axi_bready),
		.m_axi_arid(m_axi_arid),
		.m_axi_araddr(m_axi_araddr),
		.m_axi_arlen(m_axi_arlen),
		.m_axi_arsize(m_axi_arsize),
		.m_axi_arburst(m_axi_arburst),
		.m_axi_arlock(m_axi_arlock),
		.m_axi_arcache(m_axi_arcache),
		.m_axi_arprot(m_axi_arprot),
		.m_axi_arqos(m_axi_arqos),
		.m_axi_arregion(m_axi_arregion),
		.m_axi_aruser(),
		.m_axi_arvalid(m_axi_arvalid),
		.m_axi_arready(m_axi_arready),
		.m_axi_rid(m_axi_rid),
		.m_axi_rdata(m_axi_rdata),
		.m_axi_rresp(m_axi_rresp),
		.m_axi_rlast(m_axi_rlast),
		.m_axi_ruser(1'sb0),
		.m_axi_rvalid(m_axi_rvalid),
		.m_axi_rready(m_axi_rready)
	);
	axi_ram #(
		.DATA_WIDTH(32),
		.ADDR_WIDTH($clog2(MEM_SIZE)),
		.ID_WIDTH(M_ID_WIDTH)
	) ext_mem_inst(
		.clk(clk_10mhz),
		.rst(sys_rst),
		.s_axi_awid(m_axi_awid[0+:M_ID_WIDTH]),
		.s_axi_awaddr(m_axi_awaddr[0+:$clog2(MEM_SIZE)]),
		.s_axi_awlen(m_axi_awlen[0+:8]),
		.s_axi_awsize(m_axi_awsize[0+:3]),
		.s_axi_awburst(m_axi_awburst[0+:2]),
		.s_axi_awlock(m_axi_awlock[0]),
		.s_axi_awcache(m_axi_awcache[0+:4]),
		.s_axi_awprot(m_axi_awprot[0+:3]),
		.s_axi_awvalid(m_axi_awvalid[0]),
		.s_axi_awready(m_axi_awready[0]),
		.s_axi_wdata(m_axi_wdata[0+:32]),
		.s_axi_wstrb(m_axi_wstrb[0+:4]),
		.s_axi_wlast(m_axi_wlast[0]),
		.s_axi_wvalid(m_axi_wvalid[0]),
		.s_axi_wready(m_axi_wready[0]),
		.s_axi_bid(m_axi_bid[0+:M_ID_WIDTH]),
		.s_axi_bresp(m_axi_bresp[0+:2]),
		.s_axi_bvalid(m_axi_bvalid[0]),
		.s_axi_bready(m_axi_bready[0]),
		.s_axi_arid(m_axi_arid[0+:M_ID_WIDTH]),
		.s_axi_araddr(m_axi_araddr[0+:$clog2(MEM_SIZE)]),
		.s_axi_arlen(m_axi_arlen[0+:8]),
		.s_axi_arsize(m_axi_arsize[0+:3]),
		.s_axi_arburst(m_axi_arburst[0+:2]),
		.s_axi_arlock(m_axi_arlock[0]),
		.s_axi_arcache(m_axi_arcache[0+:4]),
		.s_axi_arprot(m_axi_arprot[0+:3]),
		.s_axi_arvalid(m_axi_arvalid[0]),
		.s_axi_arready(m_axi_arready[0]),
		.s_axi_rid(m_axi_rid[0+:M_ID_WIDTH]),
		.s_axi_rdata(m_axi_rdata[0+:32]),
		.s_axi_rresp(m_axi_rresp[0+:2]),
		.s_axi_rlast(m_axi_rlast[0]),
		.s_axi_rvalid(m_axi_rvalid[0]),
		.s_axi_rready(m_axi_rready[0])
	);
	wire [31:0] axil_mgr_awaddr;
	wire [31:0] axil_mgr_wdata;
	wire [31:0] axil_mgr_araddr;
	wire [31:0] axil_mgr_rdata;
	wire [3:0] axil_mgr_wstrb;
	wire [2:0] axil_mgr_awprot;
	wire [2:0] axil_mgr_arprot;
	wire [1:0] axil_mgr_bresp;
	wire [1:0] axil_mgr_rresp;
	wire axil_mgr_awvalid;
	wire axil_mgr_awready;
	wire axil_mgr_wvalid;
	wire axil_mgr_wready;
	wire axil_mgr_bvalid;
	wire axil_mgr_bready;
	wire axil_mgr_arvalid;
	wire axil_mgr_arready;
	wire axil_mgr_rvalid;
	wire axil_mgr_rready;
	wire [(NUM_SLOTS * 32) - 1:0] axil_ctrl_s_awaddr;
	wire [(NUM_SLOTS * 32) - 1:0] axil_ctrl_s_wdata;
	wire [(NUM_SLOTS * 32) - 1:0] axil_ctrl_s_araddr;
	wire [(NUM_SLOTS * 32) - 1:0] axil_ctrl_s_rdata;
	wire [(NUM_SLOTS * 4) - 1:0] axil_ctrl_s_wstrb;
	wire [(NUM_SLOTS * 3) - 1:0] axil_ctrl_s_awprot;
	wire [(NUM_SLOTS * 3) - 1:0] axil_ctrl_s_arprot;
	wire [(NUM_SLOTS * 2) - 1:0] axil_ctrl_s_bresp;
	wire [(NUM_SLOTS * 2) - 1:0] axil_ctrl_s_rresp;
	wire [NUM_SLOTS - 1:0] axil_ctrl_s_awvalid;
	wire [NUM_SLOTS - 1:0] axil_ctrl_s_awready;
	wire [NUM_SLOTS - 1:0] axil_ctrl_s_wvalid;
	wire [NUM_SLOTS - 1:0] axil_ctrl_s_wready;
	wire [NUM_SLOTS - 1:0] axil_ctrl_s_bvalid;
	wire [NUM_SLOTS - 1:0] axil_ctrl_s_bready;
	wire [NUM_SLOTS - 1:0] axil_ctrl_s_arvalid;
	wire [NUM_SLOTS - 1:0] axil_ctrl_s_arready;
	wire [NUM_SLOTS - 1:0] axil_ctrl_s_rvalid;
	wire [NUM_SLOTS - 1:0] axil_ctrl_s_rready;
	axi_axil_adapter #(
		.ADDR_WIDTH(32),
		.AXI_DATA_WIDTH(32),
		.AXIL_DATA_WIDTH(32),
		.AXI_ID_WIDTH(M_ID_WIDTH)
	) manager_bridge(
		.clk(clk_10mhz),
		.rst(sys_rst),
		.s_axi_awid(m_axi_awid[1 * M_ID_WIDTH+:M_ID_WIDTH]),
		.s_axi_awaddr(m_axi_awaddr[32+:32]),
		.s_axi_awlen(m_axi_awlen[8+:8]),
		.s_axi_awsize(m_axi_awsize[3+:3]),
		.s_axi_awburst(m_axi_awburst[2+:2]),
		.s_axi_awlock(m_axi_awlock[1]),
		.s_axi_awcache(m_axi_awcache[4+:4]),
		.s_axi_awprot(m_axi_awprot[3+:3]),
		.s_axi_awvalid(m_axi_awvalid[1]),
		.s_axi_awready(m_axi_awready[1]),
		.s_axi_wdata(m_axi_wdata[32+:32]),
		.s_axi_wstrb(m_axi_wstrb[4+:4]),
		.s_axi_wlast(m_axi_wlast[1]),
		.s_axi_wvalid(m_axi_wvalid[1]),
		.s_axi_wready(m_axi_wready[1]),
		.s_axi_bid(m_axi_bid[1 * M_ID_WIDTH+:M_ID_WIDTH]),
		.s_axi_bresp(m_axi_bresp[2+:2]),
		.s_axi_bvalid(m_axi_bvalid[1]),
		.s_axi_bready(m_axi_bready[1]),
		.s_axi_arid(m_axi_arid[1 * M_ID_WIDTH+:M_ID_WIDTH]),
		.s_axi_araddr(m_axi_araddr[32+:32]),
		.s_axi_arlen(m_axi_arlen[8+:8]),
		.s_axi_arsize(m_axi_arsize[3+:3]),
		.s_axi_arburst(m_axi_arburst[2+:2]),
		.s_axi_arlock(m_axi_arlock[1]),
		.s_axi_arcache(m_axi_arcache[4+:4]),
		.s_axi_arprot(m_axi_arprot[3+:3]),
		.s_axi_arvalid(m_axi_arvalid[1]),
		.s_axi_arready(m_axi_arready[1]),
		.s_axi_rid(m_axi_rid[1 * M_ID_WIDTH+:M_ID_WIDTH]),
		.s_axi_rdata(m_axi_rdata[32+:32]),
		.s_axi_rresp(m_axi_rresp[2+:2]),
		.s_axi_rlast(m_axi_rlast[1]),
		.s_axi_rvalid(m_axi_rvalid[1]),
		.s_axi_rready(m_axi_rready[1]),
		.m_axil_awaddr(axil_mgr_awaddr),
		.m_axil_awprot(axil_mgr_awprot),
		.m_axil_awvalid(axil_mgr_awvalid),
		.m_axil_awready(axil_mgr_awready),
		.m_axil_wdata(axil_mgr_wdata),
		.m_axil_wstrb(axil_mgr_wstrb),
		.m_axil_wvalid(axil_mgr_wvalid),
		.m_axil_wready(axil_mgr_wready),
		.m_axil_bresp(axil_mgr_bresp),
		.m_axil_bvalid(axil_mgr_bvalid),
		.m_axil_bready(axil_mgr_bready),
		.m_axil_araddr(axil_mgr_araddr),
		.m_axil_arprot(axil_mgr_arprot),
		.m_axil_arvalid(axil_mgr_arvalid),
		.m_axil_arready(axil_mgr_arready),
		.m_axil_rdata(axil_mgr_rdata),
		.m_axil_rresp(axil_mgr_rresp),
		.m_axil_rvalid(axil_mgr_rvalid),
		.m_axil_rready(axil_mgr_rready)
	);
	genvar _gv_i_1;
	generate
		for (_gv_i_1 = 0; _gv_i_1 < NUM_SLOTS; _gv_i_1 = _gv_i_1 + 1) begin : gen_ctrl_bridges
			localparam i = _gv_i_1;
			axi_axil_adapter #(
				.ADDR_WIDTH(32),
				.AXI_DATA_WIDTH(32),
				.AXIL_DATA_WIDTH(32),
				.AXI_ID_WIDTH(M_ID_WIDTH)
			) ctrl_bridge(
				.clk(clk_10mhz),
				.rst(sys_rst),
				.s_axi_awid(m_axi_awid[(2 + i) * M_ID_WIDTH+:M_ID_WIDTH]),
				.s_axi_awaddr(m_axi_awaddr[(2 + i) * 32+:32]),
				.s_axi_awlen(m_axi_awlen[(2 + i) * 8+:8]),
				.s_axi_awsize(m_axi_awsize[(2 + i) * 3+:3]),
				.s_axi_awburst(m_axi_awburst[(2 + i) * 2+:2]),
				.s_axi_awlock(m_axi_awlock[2 + i]),
				.s_axi_awcache(m_axi_awcache[(2 + i) * 4+:4]),
				.s_axi_awprot(m_axi_awprot[(2 + i) * 3+:3]),
				.s_axi_awvalid(m_axi_awvalid[2 + i]),
				.s_axi_awready(m_axi_awready[2 + i]),
				.s_axi_wdata(m_axi_wdata[(2 + i) * 32+:32]),
				.s_axi_wstrb(m_axi_wstrb[(2 + i) * 4+:4]),
				.s_axi_wlast(m_axi_wlast[2 + i]),
				.s_axi_wvalid(m_axi_wvalid[2 + i]),
				.s_axi_wready(m_axi_wready[2 + i]),
				.s_axi_bid(m_axi_bid[(2 + i) * M_ID_WIDTH+:M_ID_WIDTH]),
				.s_axi_bresp(m_axi_bresp[(2 + i) * 2+:2]),
				.s_axi_bvalid(m_axi_bvalid[2 + i]),
				.s_axi_bready(m_axi_bready[2 + i]),
				.s_axi_arid(m_axi_arid[(2 + i) * M_ID_WIDTH+:M_ID_WIDTH]),
				.s_axi_araddr(m_axi_araddr[(2 + i) * 32+:32]),
				.s_axi_arlen(m_axi_arlen[(2 + i) * 8+:8]),
				.s_axi_arsize(m_axi_arsize[(2 + i) * 3+:3]),
				.s_axi_arburst(m_axi_arburst[(2 + i) * 2+:2]),
				.s_axi_arlock(m_axi_arlock[2 + i]),
				.s_axi_arcache(m_axi_arcache[(2 + i) * 4+:4]),
				.s_axi_arprot(m_axi_arprot[(2 + i) * 3+:3]),
				.s_axi_arvalid(m_axi_arvalid[2 + i]),
				.s_axi_arready(m_axi_arready[2 + i]),
				.s_axi_rid(m_axi_rid[(2 + i) * M_ID_WIDTH+:M_ID_WIDTH]),
				.s_axi_rdata(m_axi_rdata[(2 + i) * 32+:32]),
				.s_axi_rresp(m_axi_rresp[(2 + i) * 2+:2]),
				.s_axi_rlast(m_axi_rlast[2 + i]),
				.s_axi_rvalid(m_axi_rvalid[2 + i]),
				.s_axi_rready(m_axi_rready[2 + i]),
				.m_axil_awaddr(axil_ctrl_s_awaddr[i * 32+:32]),
				.m_axil_awprot(axil_ctrl_s_awprot[i * 3+:3]),
				.m_axil_awvalid(axil_ctrl_s_awvalid[i]),
				.m_axil_awready(axil_ctrl_s_awready[i]),
				.m_axil_wdata(axil_ctrl_s_wdata[i * 32+:32]),
				.m_axil_wstrb(axil_ctrl_s_wstrb[i * 4+:4]),
				.m_axil_wvalid(axil_ctrl_s_wvalid[i]),
				.m_axil_wready(axil_ctrl_s_wready[i]),
				.m_axil_bresp(axil_ctrl_s_bresp[i * 2+:2]),
				.m_axil_bvalid(axil_ctrl_s_bvalid[i]),
				.m_axil_bready(axil_ctrl_s_bready[i]),
				.m_axil_araddr(axil_ctrl_s_araddr[i * 32+:32]),
				.m_axil_arprot(axil_ctrl_s_arprot[i * 3+:3]),
				.m_axil_arvalid(axil_ctrl_s_arvalid[i]),
				.m_axil_arready(axil_ctrl_s_arready[i]),
				.m_axil_rdata(axil_ctrl_s_rdata[i * 32+:32]),
				.m_axil_rresp(axil_ctrl_s_rresp[i * 2+:2]),
				.m_axil_rvalid(axil_ctrl_s_rvalid[i]),
				.m_axil_rready(axil_ctrl_s_rready[i])
			);
		end
	endgenerate
	efpga_subsystem_top #(
		.NUM_SLOTS(NUM_SLOTS),
		.AXI_ID_WIDTH(AXI_ID_WIDTH),
		.HW_VERSION(HW_VERSION)
	) efpga_subsystem_top_inst(
		.clk_i(clk_10mhz),
		.rstn_i(sys_rstn),
		.rst_i(sys_rst),
		.s_axil_mgr_awaddr(axil_mgr_awaddr),
		.s_axil_mgr_awprot(axil_mgr_awprot),
		.s_axil_mgr_awvalid(axil_mgr_awvalid),
		.s_axil_mgr_awready(axil_mgr_awready),
		.s_axil_mgr_wdata(axil_mgr_wdata),
		.s_axil_mgr_wstrb(axil_mgr_wstrb),
		.s_axil_mgr_wvalid(axil_mgr_wvalid),
		.s_axil_mgr_wready(axil_mgr_wready),
		.s_axil_mgr_bresp(axil_mgr_bresp),
		.s_axil_mgr_bvalid(axil_mgr_bvalid),
		.s_axil_mgr_bready(axil_mgr_bready),
		.s_axil_mgr_araddr(axil_mgr_araddr),
		.s_axil_mgr_arprot(axil_mgr_arprot),
		.s_axil_mgr_arvalid(axil_mgr_arvalid),
		.s_axil_mgr_arready(axil_mgr_arready),
		.s_axil_mgr_rdata(axil_mgr_rdata),
		.s_axil_mgr_rresp(axil_mgr_rresp),
		.s_axil_mgr_rvalid(axil_mgr_rvalid),
		.s_axil_mgr_rready(axil_mgr_rready),
		.s_axil_ctrl_awaddr(axil_ctrl_s_awaddr),
		.s_axil_ctrl_awprot(axil_ctrl_s_awprot),
		.s_axil_ctrl_awvalid(axil_ctrl_s_awvalid),
		.s_axil_ctrl_awready(axil_ctrl_s_awready),
		.s_axil_ctrl_wdata(axil_ctrl_s_wdata),
		.s_axil_ctrl_wstrb(axil_ctrl_s_wstrb),
		.s_axil_ctrl_wvalid(axil_ctrl_s_wvalid),
		.s_axil_ctrl_wready(axil_ctrl_s_wready),
		.s_axil_ctrl_bresp(axil_ctrl_s_bresp),
		.s_axil_ctrl_bvalid(axil_ctrl_s_bvalid),
		.s_axil_ctrl_bready(axil_ctrl_s_bready),
		.s_axil_ctrl_araddr(axil_ctrl_s_araddr),
		.s_axil_ctrl_arprot(axil_ctrl_s_arprot),
		.s_axil_ctrl_arvalid(axil_ctrl_s_arvalid),
		.s_axil_ctrl_arready(axil_ctrl_s_arready),
		.s_axil_ctrl_rdata(axil_ctrl_s_rdata),
		.s_axil_ctrl_rresp(axil_ctrl_s_rresp),
		.s_axil_ctrl_rvalid(axil_ctrl_s_rvalid),
		.s_axil_ctrl_rready(axil_ctrl_s_rready),
		.m_axi_dma_awid(s_axi_awid[1 * AXI_ID_WIDTH+:NUM_SLOTS * AXI_ID_WIDTH]),
		.m_axi_dma_awaddr(s_axi_awaddr[32+:NUM_SLOTS * 32]),
		.m_axi_dma_awlen(s_axi_awlen[8+:NUM_SLOTS * 8]),
		.m_axi_dma_awsize(s_axi_awsize[3+:NUM_SLOTS * 3]),
		.m_axi_dma_awburst(s_axi_awburst[2+:NUM_SLOTS * 2]),
		.m_axi_dma_awlock(s_axi_awlock[1+:NUM_SLOTS]),
		.m_axi_dma_awcache(s_axi_awcache[4+:NUM_SLOTS * 4]),
		.m_axi_dma_awprot(s_axi_awprot[3+:NUM_SLOTS * 3]),
		.m_axi_dma_awvalid(s_axi_awvalid[1+:NUM_SLOTS]),
		.m_axi_dma_awready(s_axi_awready[1+:NUM_SLOTS]),
		.m_axi_dma_wdata(s_axi_wdata[32+:NUM_SLOTS * 32]),
		.m_axi_dma_wstrb(s_axi_wstrb[4+:NUM_SLOTS * 4]),
		.m_axi_dma_wlast(s_axi_wlast[1+:NUM_SLOTS]),
		.m_axi_dma_wvalid(s_axi_wvalid[1+:NUM_SLOTS]),
		.m_axi_dma_wready(s_axi_wready[1+:NUM_SLOTS]),
		.m_axi_dma_bid(s_axi_bid[1 * AXI_ID_WIDTH+:NUM_SLOTS * AXI_ID_WIDTH]),
		.m_axi_dma_bresp(s_axi_bresp[2+:NUM_SLOTS * 2]),
		.m_axi_dma_bvalid(s_axi_bvalid[1+:NUM_SLOTS]),
		.m_axi_dma_bready(s_axi_bready[1+:NUM_SLOTS]),
		.m_axi_dma_arid(s_axi_arid[1 * AXI_ID_WIDTH+:NUM_SLOTS * AXI_ID_WIDTH]),
		.m_axi_dma_araddr(s_axi_araddr[32+:NUM_SLOTS * 32]),
		.m_axi_dma_arlen(s_axi_arlen[8+:NUM_SLOTS * 8]),
		.m_axi_dma_arsize(s_axi_arsize[3+:NUM_SLOTS * 3]),
		.m_axi_dma_arburst(s_axi_arburst[2+:NUM_SLOTS * 2]),
		.m_axi_dma_arlock(s_axi_arlock[1+:NUM_SLOTS]),
		.m_axi_dma_arcache(s_axi_arcache[4+:NUM_SLOTS * 4]),
		.m_axi_dma_arprot(s_axi_arprot[3+:NUM_SLOTS * 3]),
		.m_axi_dma_arvalid(s_axi_arvalid[1+:NUM_SLOTS]),
		.m_axi_dma_arready(s_axi_arready[1+:NUM_SLOTS]),
		.m_axi_dma_rid(s_axi_rid[1 * AXI_ID_WIDTH+:NUM_SLOTS * AXI_ID_WIDTH]),
		.m_axi_dma_rdata(s_axi_rdata[32+:NUM_SLOTS * 32]),
		.m_axi_dma_rresp(s_axi_rresp[2+:NUM_SLOTS * 2]),
		.m_axi_dma_rlast(s_axi_rlast[1+:NUM_SLOTS]),
		.m_axi_dma_rvalid(s_axi_rvalid[1+:NUM_SLOTS]),
		.m_axi_dma_rready(s_axi_rready[1+:NUM_SLOTS]),
		.pmod_io_i(8'd0),
		.pmod_io_o(),
		.pmod_io_oe_o(),
		.efpga_usr_irq_o(),
		.efpga_fault_irq_o()
	);
endmodule
