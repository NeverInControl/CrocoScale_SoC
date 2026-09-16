module npu_full_dma (
	clk_i,
	rst_n,
	m_axi_awaddr,
	m_axi_awlen,
	m_axi_awsize,
	m_axi_awburst,
	m_axi_awvalid,
	m_axi_awready,
	m_axi_wdata,
	m_axi_wstrb,
	m_axi_wlast,
	m_axi_wvalid,
	m_axi_wready,
	m_axi_bresp,
	m_axi_bvalid,
	m_axi_bready,
	m_axi_araddr,
	m_axi_arlen,
	m_axi_arsize,
	m_axi_arburst,
	m_axi_arvalid,
	m_axi_arready,
	m_axi_rdata,
	m_axi_rresp,
	m_axi_rlast,
	m_axi_rvalid,
	m_axi_rready,
	act_base_i,
	weight_base_i,
	out_base_i,
	bias_base_i,
	quant_base_i,
	lut_base_i,
	mode_1x1_i,
	lut_en_i,
	pool_en_i,
	start_preload_i,
	preload_done_o,
	start_weight_fetch_i,
	fetch_pass_idx_i,
	weight_fetch_done_o,
	start_lut_load_i,
	lut_load_done_o,
	start_drain_i,
	drain_done_o,
	drain_psum_addr_o,
	npu_out_act_i,
	weight_shift_in_o,
	weight_shift_en_o,
	bias_wdata_o,
	bias_channel_o,
	bias_we_o,
	quant_shift_in_o,
	quant_shift_en_o,
	psum_B_addr_o,
	psum_B_wdata_o,
	psum_B_we_o
);
	parameter signed [31:0] ARRAY_HEIGHT = 8;
	parameter signed [31:0] ARRAY_WIDTH = 8;
	parameter signed [31:0] ACTIVATION_WIDTH = 8;
	parameter signed [31:0] WEIGHT_WIDTH = 8;
	parameter signed [31:0] PSUM_WIDTH = 32;
	parameter signed [31:0] AXI_ADDR_WIDTH = 32;
	parameter signed [31:0] AXI_DATA_WIDTH = 32;
	input wire clk_i;
	input wire rst_n;
	output wire [AXI_ADDR_WIDTH - 1:0] m_axi_awaddr;
	output wire [7:0] m_axi_awlen;
	output wire [2:0] m_axi_awsize;
	output wire [1:0] m_axi_awburst;
	output wire m_axi_awvalid;
	input wire m_axi_awready;
	output wire [AXI_DATA_WIDTH - 1:0] m_axi_wdata;
	output wire [(AXI_DATA_WIDTH / 8) - 1:0] m_axi_wstrb;
	output wire m_axi_wlast;
	output wire m_axi_wvalid;
	input wire m_axi_wready;
	input wire [1:0] m_axi_bresp;
	input wire m_axi_bvalid;
	output wire m_axi_bready;
	output wire [AXI_ADDR_WIDTH - 1:0] m_axi_araddr;
	output wire [7:0] m_axi_arlen;
	output wire [2:0] m_axi_arsize;
	output wire [1:0] m_axi_arburst;
	output wire m_axi_arvalid;
	input wire m_axi_arready;
	input wire [AXI_DATA_WIDTH - 1:0] m_axi_rdata;
	input wire [1:0] m_axi_rresp;
	input wire m_axi_rlast;
	input wire m_axi_rvalid;
	output wire m_axi_rready;
	input wire [31:0] act_base_i;
	input wire [31:0] weight_base_i;
	input wire [31:0] out_base_i;
	input wire [31:0] bias_base_i;
	input wire [31:0] quant_base_i;
	input wire [31:0] lut_base_i;
	input wire mode_1x1_i;
	input wire lut_en_i;
	input wire pool_en_i;
	input wire start_preload_i;
	output wire preload_done_o;
	input wire start_weight_fetch_i;
	input wire [7:0] fetch_pass_idx_i;
	output wire weight_fetch_done_o;
	input wire start_lut_load_i;
	output wire lut_load_done_o;
	input wire start_drain_i;
	output wire drain_done_o;
	output wire [7:0] drain_psum_addr_o;
	input wire signed [(ARRAY_WIDTH * ACTIVATION_WIDTH) - 1:0] npu_out_act_i;
	output wire signed [(ARRAY_HEIGHT * WEIGHT_WIDTH) - 1:0] weight_shift_in_o;
	output wire [1:0] weight_shift_en_o;
	output wire signed [PSUM_WIDTH - 1:0] bias_wdata_o;
	output wire [2:0] bias_channel_o;
	output wire bias_we_o;
	output wire [29:0] quant_shift_in_o;
	output wire quant_shift_en_o;
	output wire [7:0] psum_B_addr_o;
	output wire [31:0] psum_B_wdata_o;
	output wire [7:0] psum_B_we_o;
	wire axi_req_valid;
	wire [31:0] axi_req_addr;
	wire [7:0] axi_req_len;
	wire axi_req_ready;
	wire [31:0] axi_rdata;
	wire axi_rvalid;
	wire axi_rlast;
	wire axi_rready;
	wire preload_req_valid;
	wire [31:0] preload_req_addr;
	wire [7:0] preload_req_len;
	wire preload_req_ready;
	wire preload_rready;
	wire w_req_valid;
	wire [31:0] w_req_addr;
	wire [7:0] w_req_len;
	wire w_req_ready;
	wire w_rready;
	wire lut_req_valid;
	wire [31:0] lut_req_addr;
	wire [7:0] lut_req_len;
	wire lut_req_ready;
	wire lut_rready;
	reg preload_active_reg;
	reg lut_active_reg;
	always @(posedge clk_i or negedge rst_n)
		if (!rst_n) begin
			preload_active_reg <= 1'b0;
			lut_active_reg <= 1'b0;
		end
		else begin
			if (start_preload_i)
				preload_active_reg <= 1'b1;
			else if (preload_done_o)
				preload_active_reg <= 1'b0;
			if (start_lut_load_i)
				lut_active_reg <= 1'b1;
			else if (lut_load_done_o)
				lut_active_reg <= 1'b0;
		end
	assign axi_req_valid = (preload_active_reg ? preload_req_valid : (lut_active_reg ? lut_req_valid : w_req_valid));
	assign axi_req_addr = (preload_active_reg ? preload_req_addr : (lut_active_reg ? lut_req_addr : w_req_addr));
	assign axi_req_len = (preload_active_reg ? preload_req_len : (lut_active_reg ? lut_req_len : w_req_len));
	assign preload_req_ready = (preload_active_reg ? axi_req_ready : 1'b0);
	assign lut_req_ready = (lut_active_reg ? axi_req_ready : 1'b0);
	assign w_req_ready = (!preload_active_reg && !lut_active_reg ? axi_req_ready : 1'b0);
	assign axi_rready = (preload_active_reg ? preload_rready : (lut_active_reg ? lut_rready : w_rready));
	npu_axi_read_master #(
		.AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
		.AXI_DATA_WIDTH(AXI_DATA_WIDTH)
	) axi_read_master_inst(
		.clk_i(clk_i),
		.rst_n(rst_n),
		.req_valid_i(axi_req_valid),
		.req_addr_i(axi_req_addr),
		.req_len_i(axi_req_len),
		.req_ready_o(axi_req_ready),
		.rdata_o(axi_rdata),
		.rvalid_o(axi_rvalid),
		.rlast_o(axi_rlast),
		.rready_i(axi_rready),
		.m_axi_araddr(m_axi_araddr),
		.m_axi_arlen(m_axi_arlen),
		.m_axi_arsize(m_axi_arsize),
		.m_axi_arburst(m_axi_arburst),
		.m_axi_arvalid(m_axi_arvalid),
		.m_axi_arready(m_axi_arready),
		.m_axi_rdata(m_axi_rdata),
		.m_axi_rresp(m_axi_rresp),
		.m_axi_rlast(m_axi_rlast),
		.m_axi_rvalid(m_axi_rvalid),
		.m_axi_rready(m_axi_rready)
	);
	npu_dma_preload_engine #(
		.PSUM_WIDTH(PSUM_WIDTH),
		.AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
		.AXI_DATA_WIDTH(AXI_DATA_WIDTH)
	) preload_engine_inst(
		.clk_i(clk_i),
		.rst_n(rst_n),
		.start_i(start_preload_i),
		.bias_base_i(bias_base_i),
		.quant_base_i(quant_base_i),
		.req_valid_o(preload_req_valid),
		.req_addr_o(preload_req_addr),
		.req_len_o(preload_req_len),
		.req_ready_i(preload_req_ready),
		.rdata_i(axi_rdata),
		.rvalid_i((preload_active_reg ? axi_rvalid : 1'b0)),
		.rlast_i(axi_rlast),
		.rready_o(preload_rready),
		.bias_wdata_o(bias_wdata_o),
		.bias_channel_o(bias_channel_o),
		.bias_we_o(bias_we_o),
		.quant_shift_in_o(quant_shift_in_o),
		.quant_shift_en_o(quant_shift_en_o),
		.done_o(preload_done_o)
	);
	npu_dma_weight_fetcher #(
		.ARRAY_HEIGHT(ARRAY_HEIGHT),
		.WEIGHT_WIDTH(WEIGHT_WIDTH),
		.AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
		.AXI_DATA_WIDTH(AXI_DATA_WIDTH)
	) weight_fetcher_inst(
		.clk_i(clk_i),
		.rst_n(rst_n),
		.start_i(start_weight_fetch_i),
		.mode_1x1_i(mode_1x1_i),
		.fetch_pass_idx_i(fetch_pass_idx_i),
		.weight_base_i(weight_base_i),
		.req_valid_o(w_req_valid),
		.req_addr_o(w_req_addr),
		.req_len_o(w_req_len),
		.req_ready_i(w_req_ready),
		.rdata_i(axi_rdata),
		.rvalid_i((!preload_active_reg && !lut_active_reg ? axi_rvalid : 1'b0)),
		.rlast_i(axi_rlast),
		.rready_o(w_rready),
		.weight_shift_in_o(weight_shift_in_o),
		.weight_shift_en_o(weight_shift_en_o),
		.done_o(weight_fetch_done_o)
	);
	npu_dma_lut_loader #(
		.AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
		.AXI_DATA_WIDTH(AXI_DATA_WIDTH)
	) lut_loader_inst(
		.clk_i(clk_i),
		.rst_n(rst_n),
		.start_i(start_lut_load_i),
		.lut_base_i(lut_base_i),
		.req_valid_o(lut_req_valid),
		.req_addr_o(lut_req_addr),
		.req_len_o(lut_req_len),
		.req_ready_i(lut_req_ready),
		.rdata_i(axi_rdata),
		.rvalid_i((lut_active_reg ? axi_rvalid : 1'b0)),
		.rlast_i(axi_rlast),
		.rready_o(lut_rready),
		.psum_B_addr_o(psum_B_addr_o),
		.psum_B_wdata_o(psum_B_wdata_o),
		.psum_B_we_o(psum_B_we_o),
		.done_o(lut_load_done_o)
	);
	npu_dma_drainer #(
		.ARRAY_WIDTH(ARRAY_WIDTH),
		.ACTIVATION_WIDTH(ACTIVATION_WIDTH)
	) drainer_inst(
		.clk_i(clk_i),
		.rst_n(rst_n),
		.start_i(start_drain_i),
		.lut_en_i(lut_en_i),
		.pool_en_i(pool_en_i),
		.out_base_i(out_base_i),
		.drain_psum_addr_o(drain_psum_addr_o),
		.npu_out_act_i(npu_out_act_i),
		.awaddr_o(m_axi_awaddr),
		.awlen_o(m_axi_awlen),
		.awsize_o(m_axi_awsize),
		.awburst_o(m_axi_awburst),
		.awvalid_o(m_axi_awvalid),
		.awready_i(m_axi_awready),
		.wdata_o(m_axi_wdata),
		.wstrb_o(m_axi_wstrb),
		.wlast_o(m_axi_wlast),
		.wvalid_o(m_axi_wvalid),
		.wready_i(m_axi_wready),
		.bresp_i(m_axi_bresp),
		.bvalid_i(m_axi_bvalid),
		.bready_o(m_axi_bready),
		.done_o(drain_done_o)
	);
endmodule
