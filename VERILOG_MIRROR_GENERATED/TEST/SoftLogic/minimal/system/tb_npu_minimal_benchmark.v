module tb_npu_minimal_benchmark;
	parameter signed [31:0] ARRAY_HEIGHT = 8;
	parameter signed [31:0] ARRAY_WIDTH = 8;
	parameter signed [31:0] TILE_SIZE = 16;
	parameter signed [31:0] ACT_HALO_PAD = 2;
	parameter signed [31:0] ACTIVATION_WIDTH = 8;
	parameter signed [31:0] WEIGHT_WIDTH = 8;
	parameter signed [31:0] PSUM_WIDTH = 32;
	parameter signed [31:0] SCALE_WIDTH = 16;
	parameter signed [31:0] WEIGHT_SPLIT = 8;
	parameter signed [31:0] AXI_ADDR_WIDTH = 32;
	parameter signed [31:0] AXI_DATA_WIDTH = 32;
	localparam signed [31:0] CONV_H = 48;
	localparam signed [31:0] CONV_W = 48;
	localparam signed [31:0] CIN = 128;
	localparam signed [31:0] COUT = 32;
	localparam signed [31:0] TOTAL_BLOCKS = 36;
	reg clk;
	reg rst_n;
	reg [AXI_ADDR_WIDTH - 1:0] s_axil_awaddr;
	reg [2:0] s_axil_awprot;
	reg s_axil_awvalid;
	wire s_axil_awready;
	reg [AXI_DATA_WIDTH - 1:0] s_axil_wdata;
	reg [3:0] s_axil_wstrb;
	reg s_axil_wvalid;
	wire s_axil_wready;
	wire [1:0] s_axil_bresp;
	wire s_axil_bvalid;
	reg s_axil_bready;
	reg [AXI_ADDR_WIDTH - 1:0] s_axil_araddr;
	reg [2:0] s_axil_arprot;
	reg s_axil_arvalid;
	wire s_axil_arready;
	wire [AXI_DATA_WIDTH - 1:0] s_axil_rdata;
	wire [1:0] s_axil_rresp;
	wire s_axil_rvalid;
	reg s_axil_rready;
	wire [AXI_ADDR_WIDTH - 1:0] m_axi_awaddr;
	wire [7:0] m_axi_awlen;
	wire [2:0] m_axi_awsize;
	wire [1:0] m_axi_awburst;
	wire m_axi_awlock;
	wire [3:0] m_axi_awcache;
	wire m_axi_awvalid;
	wire m_axi_awready;
	wire [AXI_DATA_WIDTH - 1:0] m_axi_wdata;
	wire [3:0] m_axi_wstrb;
	wire m_axi_wlast;
	wire m_axi_wvalid;
	wire m_axi_wready;
	wire [1:0] m_axi_bresp;
	wire m_axi_bvalid;
	wire m_axi_bready;
	wire [AXI_ADDR_WIDTH - 1:0] m_axi_araddr;
	wire [7:0] m_axi_arlen;
	wire [2:0] m_axi_arsize;
	wire [1:0] m_axi_arburst;
	wire m_axi_arlock;
	wire [3:0] m_axi_arcache;
	wire m_axi_arvalid;
	wire m_axi_arready;
	wire [AXI_DATA_WIDTH - 1:0] m_axi_rdata;
	wire [1:0] m_axi_rresp;
	wire m_axi_rlast;
	wire m_axi_rvalid;
	wire m_axi_rready;
	wire [9:0] fab_axil_awaddr;
	wire [2:0] fab_axil_awprot;
	wire fab_axil_awvalid;
	wire fab_axil_awready;
	wire [31:0] fab_axil_wdata;
	wire [3:0] fab_axil_wstrb;
	wire fab_axil_wvalid;
	wire fab_axil_wready;
	wire [1:0] fab_axil_bresp;
	wire fab_axil_bvalid;
	wire fab_axil_bready;
	wire [9:0] fab_axil_araddr;
	wire [2:0] fab_axil_arprot;
	wire fab_axil_arvalid;
	wire fab_axil_arready;
	wire [31:0] fab_axil_rdata;
	wire [1:0] fab_axil_rresp;
	wire fab_axil_rvalid;
	wire fab_axil_rready;
	wire [31:0] fab_axi_awaddr;
	wire [7:0] fab_axi_awlen;
	wire fab_axi_awvalid;
	wire fab_axi_awready;
	wire [31:0] fab_axi_wdata;
	wire fab_axi_wlast;
	wire fab_axi_wvalid;
	wire fab_axi_wready;
	wire [1:0] fab_axi_bresp;
	wire fab_axi_bvalid;
	wire fab_axi_bready;
	wire [31:0] fab_axi_araddr;
	wire [7:0] fab_axi_arlen;
	wire fab_axi_arvalid;
	wire fab_axi_arready;
	wire [31:0] fab_axi_rdata;
	wire [1:0] fab_axi_rresp;
	wire fab_axi_rlast;
	wire fab_axi_rvalid;
	wire fab_axi_rready;
	wire fab_npu_array_en;
	wire fab_npu_psum_systolic_en;
	wire fab_npu_psum_lut_en;
	wire fab_npu_compute_bank_swap;
	wire signed [63:0] fab_weight_shift_in;
	wire [7:0] fab_weight_shift_en;
	wire fab_npu_swap_weights;
	wire [29:0] fab_npu_quant_shift_in;
	wire fab_npu_quant_shift_en;
	wire [7:0] fab_psum_A_addr;
	wire [7:0] fab_psum_A_we;
	wire signed [31:0] fab_psum_A_wdata;
	wire [2:0] fab_psum_A_read_bank_sel;
	wire signed [31:0] fab_psum_A_rdata;
	wire [7:0] fab_psum_B_addr;
	wire [7:0] fab_psum_B_we;
	wire signed [31:0] fab_psum_B_wdata;
	wire [2:0] fab_psum_B_read_bank_sel;
	wire signed [31:0] fab_psum_B_rdata;
	wire [7:0] fab_ext_act_sram_we;
	wire [71:0] fab_ext_act_sram_addr;
	wire signed [63:0] fab_ext_act_sram_wdata;
	wire signed [63:0] fab_act_sram_rdata;
	wire signed [63:0] fab_out_act;
	wire [3:0] fab_slot_soft_rst_n;
	wire [3:0] fab_usr_irq;
	wire npu_array_en;
	wire npu_psum_systolic_en;
	wire npu_psum_lut_en;
	wire npu_psum_skew_en;
	wire npu_compute_bank_swap;
	wire [31:0] npu_crossbar_sel;
	wire signed [63:0] npu_weight_shift_in;
	wire [7:0] npu_weight_shift_en;
	wire npu_swap_weights;
	wire [29:0] npu_quant_shift_in;
	wire npu_quant_shift_en;
	wire [7:0] npu_psum_A_addr;
	wire [7:0] npu_psum_A_we;
	wire signed [31:0] npu_psum_A_wdata;
	wire [2:0] npu_psum_A_read_bank_sel;
	wire signed [31:0] npu_psum_A_rdata;
	wire [7:0] npu_psum_B_addr;
	wire [7:0] npu_psum_B_we;
	wire signed [31:0] npu_psum_B_wdata;
	wire [2:0] npu_psum_B_read_bank_sel;
	wire signed [31:0] npu_psum_B_rdata;
	wire [7:0] npu_ext_act_sram_we;
	wire [71:0] npu_ext_act_sram_addr;
	wire signed [63:0] npu_ext_act_sram_wdata;
	wire signed [63:0] npu_act_sram_rdata;
	wire signed [63:0] npu_out_act;
	wire [3:0] efpga_usr_irq_o;
	initial clk = 0;
	always #(5) clk = ~clk;
	localparam signed [31:0] MEM_ADDR_WIDTH = 20;
	localparam [31:0] ACT_BASE_ADDR = 32'h00000000;
	localparam [31:0] WEIGHT_BASE_ADDR = 32'h00060000;
	localparam [31:0] BIAS_BASE_ADDR = 32'h00070000;
	localparam [31:0] QUANT_BASE_ADDR = 32'h00070100;
	localparam [31:0] OUT_BASE_ADDR = 32'h00080000;
	axi_ram #(
		.DATA_WIDTH(AXI_DATA_WIDTH),
		.ADDR_WIDTH(MEM_ADDR_WIDTH),
		.ID_WIDTH(1),
		.PIPELINE_OUTPUT(0)
	) axi_ram_inst(
		.clk(clk),
		.rst(~rst_n),
		.s_axi_awid(1'b0),
		.s_axi_awaddr(m_axi_awaddr[19:0]),
		.s_axi_awlen(m_axi_awlen),
		.s_axi_awsize(m_axi_awsize),
		.s_axi_awburst(m_axi_awburst),
		.s_axi_awlock(m_axi_awlock),
		.s_axi_awcache(m_axi_awcache),
		.s_axi_awprot(3'b000),
		.s_axi_awvalid(m_axi_awvalid),
		.s_axi_awready(m_axi_awready),
		.s_axi_wdata(m_axi_wdata),
		.s_axi_wstrb(m_axi_wstrb),
		.s_axi_wlast(m_axi_wlast),
		.s_axi_wvalid(m_axi_wvalid),
		.s_axi_wready(m_axi_wready),
		.s_axi_bid(),
		.s_axi_bresp(m_axi_bresp),
		.s_axi_bvalid(m_axi_bvalid),
		.s_axi_bready(m_axi_bready),
		.s_axi_arid(1'b0),
		.s_axi_araddr(m_axi_araddr[19:0]),
		.s_axi_arlen(m_axi_arlen),
		.s_axi_arsize(m_axi_arsize),
		.s_axi_arburst(m_axi_arburst),
		.s_axi_arlock(m_axi_arlock),
		.s_axi_arcache(m_axi_arcache),
		.s_axi_arprot(3'b000),
		.s_axi_arvalid(m_axi_arvalid),
		.s_axi_arready(m_axi_arready),
		.s_axi_rdata(m_axi_rdata),
		.s_axi_rresp(m_axi_rresp),
		.s_axi_rlast(m_axi_rlast),
		.s_axi_rvalid(m_axi_rvalid),
		.s_axi_rready(m_axi_rready)
	);
	efpga_boundary_harness #(
		.ARRAY_HEIGHT(ARRAY_HEIGHT),
		.ARRAY_WIDTH(ARRAY_WIDTH),
		.ACTIVATION_WIDTH(ACTIVATION_WIDTH),
		.WEIGHT_WIDTH(WEIGHT_WIDTH),
		.PSUM_WIDTH(PSUM_WIDTH),
		.CFG_AXI_M(12'hf3e),
		.CFG_SLICE(48'h79a59238a182),
		.CFG_NPU_CTRL(1'b0),
		.CFG_DEBUG(16'h0004)
	) harness_inst(
		.clk_i(clk),
		.s_axil_awaddr(s_axil_awaddr[9:0]),
		.s_axil_awprot(s_axil_awprot),
		.s_axil_awvalid(s_axil_awvalid),
		.s_axil_awready(s_axil_awready),
		.s_axil_wdata(s_axil_wdata),
		.s_axil_wstrb(s_axil_wstrb),
		.s_axil_wvalid(s_axil_wvalid),
		.s_axil_wready(s_axil_wready),
		.s_axil_bresp(s_axil_bresp),
		.s_axil_bvalid(s_axil_bvalid),
		.s_axil_bready(s_axil_bready),
		.s_axil_araddr(s_axil_araddr[9:0]),
		.s_axil_arprot(s_axil_arprot),
		.s_axil_arvalid(s_axil_arvalid),
		.s_axil_arready(s_axil_arready),
		.s_axil_rdata(s_axil_rdata),
		.s_axil_rresp(s_axil_rresp),
		.s_axil_rvalid(s_axil_rvalid),
		.s_axil_rready(s_axil_rready),
		.m_axi_awaddr(m_axi_awaddr),
		.m_axi_awlen(m_axi_awlen),
		.m_axi_awsize(m_axi_awsize),
		.m_axi_awburst(m_axi_awburst),
		.m_axi_awlock(m_axi_awlock),
		.m_axi_awcache(m_axi_awcache),
		.m_axi_awvalid(m_axi_awvalid),
		.m_axi_awready(m_axi_awready),
		.m_axi_wdata(m_axi_wdata),
		.m_axi_wstrb(m_axi_wstrb),
		.m_axi_wlast(m_axi_wlast),
		.m_axi_wvalid(m_axi_wvalid),
		.m_axi_wready(m_axi_wready),
		.m_axi_bresp(m_axi_bresp),
		.m_axi_bvalid(m_axi_bvalid),
		.m_axi_bready(m_axi_bready),
		.m_axi_araddr(m_axi_araddr),
		.m_axi_arlen(m_axi_arlen),
		.m_axi_arsize(m_axi_arsize),
		.m_axi_arburst(m_axi_arburst),
		.m_axi_arlock(m_axi_arlock),
		.m_axi_arcache(m_axi_arcache),
		.m_axi_arvalid(m_axi_arvalid),
		.m_axi_arready(m_axi_arready),
		.m_axi_rdata(m_axi_rdata),
		.m_axi_rresp(m_axi_rresp),
		.m_axi_rlast(m_axi_rlast),
		.m_axi_rvalid(m_axi_rvalid),
		.m_axi_rready(m_axi_rready),
		.soc_debug_out_i(1'sb0),
		.soc_debug_in_o(),
		.soc_usr_irq_o(efpga_usr_irq_o),
		.soc_slot_soft_rst_n_i({3'b000, rst_n}),
		.npu_array_en(npu_array_en),
		.npu_psum_systolic_en(npu_psum_systolic_en),
		.npu_psum_lut_en(npu_psum_lut_en),
		.npu_psum_skew_en(npu_psum_skew_en),
		.npu_compute_bank_swap(npu_compute_bank_swap),
		.npu_swap_weights(npu_swap_weights),
		.npu_quant_shift_in(npu_quant_shift_in),
		.npu_quant_shift_en(npu_quant_shift_en),
		.npu_crossbar_sel(npu_crossbar_sel),
		.npu_weight_shift_in(npu_weight_shift_in),
		.npu_weight_shift_en(npu_weight_shift_en),
		.npu_ext_act_sram_we(npu_ext_act_sram_we),
		.npu_ext_act_sram_addr(npu_ext_act_sram_addr),
		.npu_ext_act_sram_wdata(npu_ext_act_sram_wdata),
		.npu_act_sram_rdata(npu_act_sram_rdata),
		.npu_out_act(npu_out_act),
		.npu_psum_A_addr(npu_psum_A_addr),
		.npu_psum_A_we(npu_psum_A_we),
		.npu_psum_A_wdata(npu_psum_A_wdata),
		.npu_psum_A_read_bank_sel(npu_psum_A_read_bank_sel),
		.npu_psum_A_rdata(npu_psum_A_rdata),
		.npu_psum_B_addr(npu_psum_B_addr),
		.npu_psum_B_we(npu_psum_B_we),
		.npu_psum_B_wdata(npu_psum_B_wdata),
		.npu_psum_B_read_bank_sel(npu_psum_B_read_bank_sel),
		.npu_psum_B_rdata(npu_psum_B_rdata),
		.fab_axil_awaddr(fab_axil_awaddr),
		.fab_axil_awprot(fab_axil_awprot),
		.fab_axil_awvalid(fab_axil_awvalid),
		.fab_axil_awready(fab_axil_awready),
		.fab_axil_wdata(fab_axil_wdata),
		.fab_axil_wstrb(fab_axil_wstrb),
		.fab_axil_wvalid(fab_axil_wvalid),
		.fab_axil_wready(fab_axil_wready),
		.fab_axil_bresp(fab_axil_bresp),
		.fab_axil_bvalid(fab_axil_bvalid),
		.fab_axil_bready(fab_axil_bready),
		.fab_axil_araddr(fab_axil_araddr),
		.fab_axil_arprot(fab_axil_arprot),
		.fab_axil_arvalid(fab_axil_arvalid),
		.fab_axil_arready(fab_axil_arready),
		.fab_axil_rdata(fab_axil_rdata),
		.fab_axil_rresp(fab_axil_rresp),
		.fab_axil_rvalid(fab_axil_rvalid),
		.fab_axil_rready(fab_axil_rready),
		.fab_axi_awaddr(fab_axi_awaddr),
		.fab_axi_awlen(fab_axi_awlen),
		.fab_axi_awvalid(fab_axi_awvalid),
		.fab_axi_awready(fab_axi_awready),
		.fab_axi_wdata(fab_axi_wdata),
		.fab_axi_wlast(fab_axi_wlast),
		.fab_axi_wvalid(fab_axi_wvalid),
		.fab_axi_wready(fab_axi_wready),
		.fab_axi_bresp(fab_axi_bresp),
		.fab_axi_bvalid(fab_axi_bvalid),
		.fab_axi_bready(fab_axi_bready),
		.fab_axi_araddr(fab_axi_araddr),
		.fab_axi_arlen(fab_axi_arlen),
		.fab_axi_arvalid(fab_axi_arvalid),
		.fab_axi_arready(fab_axi_arready),
		.fab_axi_rdata(fab_axi_rdata),
		.fab_axi_rresp(fab_axi_rresp),
		.fab_axi_rlast(fab_axi_rlast),
		.fab_axi_rvalid(fab_axi_rvalid),
		.fab_axi_rready(fab_axi_rready),
		.fab_npu_array_en(fab_npu_array_en),
		.fab_npu_psum_systolic_en(fab_npu_psum_systolic_en),
		.fab_npu_psum_lut_en(fab_npu_psum_lut_en),
		.fab_npu_psum_skew_en(fab_npu_psum_systolic_en),
		.fab_npu_compute_bank_swap(fab_npu_compute_bank_swap),
		.fab_npu_swap_weights(fab_npu_swap_weights),
		.fab_npu_quant_shift_in(fab_npu_quant_shift_in),
		.fab_npu_quant_shift_en(fab_npu_quant_shift_en),
		.fab_crossbar_sel(1'sb0),
		.fab_weight_shift_in(fab_weight_shift_in),
		.fab_weight_shift_en(fab_weight_shift_en),
		.fab_ext_act_sram_we(fab_ext_act_sram_we),
		.fab_ext_act_sram_addr(fab_ext_act_sram_addr),
		.fab_ext_act_sram_wdata(fab_ext_act_sram_wdata),
		.fab_act_sram_rdata(fab_act_sram_rdata),
		.fab_out_act(fab_out_act),
		.fab_psum_A_addr(fab_psum_A_addr),
		.fab_psum_A_we(fab_psum_A_we),
		.fab_psum_A_wdata(fab_psum_A_wdata),
		.fab_psum_A_read_bank_sel(fab_psum_A_read_bank_sel),
		.fab_psum_A_rdata(fab_psum_A_rdata),
		.fab_psum_B_addr(fab_psum_B_addr),
		.fab_psum_B_we(fab_psum_B_we),
		.fab_psum_B_wdata(fab_psum_B_wdata),
		.fab_psum_B_read_bank_sel(fab_psum_B_read_bank_sel),
		.fab_psum_B_rdata(fab_psum_B_rdata),
		.fab_debug_out_o(),
		.fab_debug_in_i(1'sb0),
		.fab_usr_irq_i(fab_usr_irq),
		.fab_slot_soft_rst_n_o(fab_slot_soft_rst_n)
	);
	npu_wrapper #(
		.ARRAY_HEIGHT(ARRAY_HEIGHT),
		.ARRAY_WIDTH(ARRAY_WIDTH),
		.TILE_SIZE(TILE_SIZE),
		.ACT_HALO_PAD(ACT_HALO_PAD),
		.ACTIVATION_WIDTH(ACTIVATION_WIDTH),
		.WEIGHT_WIDTH(WEIGHT_WIDTH),
		.PSUM_WIDTH(PSUM_WIDTH),
		.SCALE_WIDTH(SCALE_WIDTH),
		.WEIGHT_SPLIT(WEIGHT_SPLIT)
	) npu_wrapper_inst(
		.clk_i(clk),
		.rst_n(rst_n),
		.array_en(npu_array_en),
		.psum_systolic_en(npu_psum_systolic_en),
		.psum_lut_en(npu_psum_lut_en),
		.psum_skew_en(npu_psum_skew_en),
		.compute_bank_swap(npu_compute_bank_swap),
		.crossbar_sel(npu_crossbar_sel),
		.weight_shift_in(npu_weight_shift_in),
		.weight_shift_en(npu_weight_shift_en),
		.swap_weights(npu_swap_weights),
		.quant_shift_in(npu_quant_shift_in),
		.quant_shift_en(npu_quant_shift_en),
		.stochastic_round_en(1'b0),
		.lfsr_data_out(),
		.psum_A_addr(npu_psum_A_addr),
		.psum_A_we(npu_psum_A_we),
		.psum_A_wdata(npu_psum_A_wdata),
		.psum_A_read_bank_sel(npu_psum_A_read_bank_sel),
		.psum_A_rdata(npu_psum_A_rdata),
		.psum_B_addr(npu_psum_B_addr),
		.psum_B_we(npu_psum_B_we),
		.psum_B_wdata(npu_psum_B_wdata),
		.psum_B_read_bank_sel(npu_psum_B_read_bank_sel),
		.psum_B_rdata(npu_psum_B_rdata),
		.ext_act_sram_we(npu_ext_act_sram_we),
		.ext_act_sram_addr(npu_ext_act_sram_addr),
		.ext_act_sram_wdata(npu_ext_act_sram_wdata),
		.act_sram_rdata(npu_act_sram_rdata),
		.out_act(npu_out_act)
	);
	npu_min_controller #(
		.KERNEL_SIZE(3),
		.ARRAY_HEIGHT(ARRAY_HEIGHT),
		.ARRAY_WIDTH(ARRAY_WIDTH),
		.TILE_SIZE(TILE_SIZE),
		.ACT_HALO_PAD(ACT_HALO_PAD),
		.ACTIVATION_WIDTH(ACTIVATION_WIDTH),
		.WEIGHT_WIDTH(WEIGHT_WIDTH),
		.PSUM_WIDTH(PSUM_WIDTH),
		.SCALE_WIDTH(SCALE_WIDTH),
		.WEIGHT_SPLIT(WEIGHT_SPLIT),
		.AXIL_ADDR_WIDTH(10),
		.AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
		.AXI_DATA_WIDTH(AXI_DATA_WIDTH)
	) dut_inst(
		.clk_i(clk),
		.rst_n(fab_slot_soft_rst_n[0]),
		.s_axil_awaddr(fab_axil_awaddr),
		.s_axil_awprot(fab_axil_awprot),
		.s_axil_awvalid(fab_axil_awvalid),
		.s_axil_awready(fab_axil_awready),
		.s_axil_wdata(fab_axil_wdata),
		.s_axil_wstrb(fab_axil_wstrb),
		.s_axil_wvalid(fab_axil_wvalid),
		.s_axil_wready(fab_axil_wready),
		.s_axil_bresp(fab_axil_bresp),
		.s_axil_bvalid(fab_axil_bvalid),
		.s_axil_bready(fab_axil_bready),
		.s_axil_araddr(fab_axil_araddr),
		.s_axil_arprot(fab_axil_arprot),
		.s_axil_arvalid(fab_axil_arvalid),
		.s_axil_arready(fab_axil_arready),
		.s_axil_rdata(fab_axil_rdata),
		.s_axil_rresp(fab_axil_rresp),
		.s_axil_rvalid(fab_axil_rvalid),
		.s_axil_rready(fab_axil_rready),
		.m_axi_awaddr(fab_axi_awaddr),
		.m_axi_awlen(fab_axi_awlen),
		.m_axi_awsize(),
		.m_axi_awburst(),
		.m_axi_awvalid(fab_axi_awvalid),
		.m_axi_awready(fab_axi_awready),
		.m_axi_wdata(fab_axi_wdata),
		.m_axi_wstrb(),
		.m_axi_wlast(fab_axi_wlast),
		.m_axi_wvalid(fab_axi_wvalid),
		.m_axi_wready(fab_axi_wready),
		.m_axi_bresp(fab_axi_bresp),
		.m_axi_bvalid(fab_axi_bvalid),
		.m_axi_bready(fab_axi_bready),
		.m_axi_araddr(fab_axi_araddr),
		.m_axi_arlen(fab_axi_arlen),
		.m_axi_arsize(),
		.m_axi_arburst(),
		.m_axi_arvalid(fab_axi_arvalid),
		.m_axi_arready(fab_axi_arready),
		.m_axi_rdata(fab_axi_rdata),
		.m_axi_rresp(fab_axi_rresp),
		.m_axi_rlast(fab_axi_rlast),
		.m_axi_rvalid(fab_axi_rvalid),
		.m_axi_rready(fab_axi_rready),
		.npu_array_en(fab_npu_array_en),
		.npu_psum_systolic_en(fab_npu_psum_systolic_en),
		.npu_psum_lut_en(fab_npu_psum_lut_en),
		.npu_psum_skew_en(),
		.npu_compute_bank_swap(fab_npu_compute_bank_swap),
		.npu_crossbar_sel(),
		.npu_weight_shift_in(fab_weight_shift_in),
		.npu_weight_shift_en(fab_weight_shift_en),
		.npu_swap_weights(fab_npu_swap_weights),
		.npu_quant_shift_in(fab_npu_quant_shift_in),
		.npu_quant_shift_en(fab_npu_quant_shift_en),
		.npu_stochastic_round_en(),
		.npu_psum_A_addr(fab_psum_A_addr),
		.npu_psum_A_we(fab_psum_A_we),
		.npu_psum_A_wdata(fab_psum_A_wdata),
		.npu_psum_A_read_bank_sel(fab_psum_A_read_bank_sel),
		.npu_psum_A_rdata(fab_psum_A_rdata),
		.npu_psum_B_addr(fab_psum_B_addr),
		.npu_psum_B_we(fab_psum_B_we),
		.npu_psum_B_wdata(fab_psum_B_wdata),
		.npu_psum_B_read_bank_sel(fab_psum_B_read_bank_sel),
		.npu_psum_B_rdata(fab_psum_B_rdata),
		.npu_ext_act_sram_we(fab_ext_act_sram_we),
		.npu_ext_act_sram_addr(fab_ext_act_sram_addr),
		.npu_ext_act_sram_wdata(fab_ext_act_sram_wdata),
		.npu_act_sram_rdata(fab_act_sram_rdata),
		.npu_out_act(fab_out_act),
		.efpga_usr_irq_o(fab_usr_irq)
	);
	reg signed [ACTIVATION_WIDTH - 1:0] fmap_in [0:((CONV_H * CONV_W) * CIN) - 1];
	reg signed [WEIGHT_WIDTH - 1:0] w1_flat [0:36863];
	reg signed [31:0] b1_flat [0:31];
	reg [31:0] p1_cfg [0:31];
	reg signed [ACTIVATION_WIDTH - 1:0] gold_act [0:73727];
	task automatic ram_write_byte;
		input reg signed [31:0] addr;
		input reg signed [7:0] val;
		reg signed [31:0] word_addr;
		reg signed [31:0] byte_lane;
		begin
			word_addr = addr >> 2;
			byte_lane = addr & 2'd3;
			case (byte_lane)
				2'd0: axi_ram_inst.mem[word_addr][7:0] = val;
				2'd1: axi_ram_inst.mem[word_addr][15:8] = val;
				2'd2: axi_ram_inst.mem[word_addr][23:16] = val;
				2'd3: axi_ram_inst.mem[word_addr][31:24] = val;
			endcase
		end
	endtask
	task automatic ram_write_word;
		input reg signed [31:0] addr;
		input reg [31:0] val;
		reg signed [31:0] word_addr;
		begin
			word_addr = addr >> 2;
			axi_ram_inst.mem[word_addr] = val;
		end
	endtask
	task automatic ram_read_byte;
		input reg signed [31:0] addr;
		output reg signed [7:0] val;
		reg signed [31:0] word_addr;
		reg signed [31:0] byte_lane;
		begin
			word_addr = addr >> 2;
			byte_lane = addr & 2'd3;
			case (byte_lane)
				2'd0: val = $signed(axi_ram_inst.mem[word_addr][7:0]);
				2'd1: val = $signed(axi_ram_inst.mem[word_addr][15:8]);
				2'd2: val = $signed(axi_ram_inst.mem[word_addr][23:16]);
				2'd3: val = $signed(axi_ram_inst.mem[word_addr][31:24]);
			endcase
		end
	endtask
	task automatic axil_write;
		input reg [31:0] addr;
		input reg [31:0] data;
		begin
			@(posedge clk)
				;
			#(1)
				;
			s_axil_awaddr = addr;
			s_axil_awvalid = 1'b1;
			s_axil_wdata = data;
			s_axil_wstrb = 4'hf;
			s_axil_wvalid = 1'b1;
			s_axil_bready = 1'b0;
			fork
				begin
					while (!s_axil_awready) @(posedge clk)
						;
					@(posedge clk)
						;
					#(1)
						;
					s_axil_awvalid = 1'b0;
				end
				begin
					while (!s_axil_wready) @(posedge clk)
						;
					@(posedge clk)
						;
					#(1)
						;
					s_axil_wvalid = 1'b0;
				end
			join
			while (!s_axil_bvalid) @(posedge clk)
				;
			#(1)
				;
			s_axil_bready = 1'b1;
			@(posedge clk)
				;
			#(1)
				;
			s_axil_bready = 1'b0;
		end
	endtask
	task automatic axil_read;
		input reg [31:0] addr;
		output reg [31:0] data;
		begin
			@(posedge clk)
				;
			#(1)
				;
			s_axil_araddr = addr;
			s_axil_arvalid = 1'b1;
			s_axil_rready = 1'b0;
			while (!s_axil_arready) @(posedge clk)
				;
			@(posedge clk)
				;
			#(1)
				;
			s_axil_arvalid = 1'b0;
			while (!s_axil_rvalid) @(posedge clk)
				;
			#(1)
				;
			data = s_axil_rdata;
			s_axil_rready = 1'b1;
			@(posedge clk)
				;
			#(1)
				;
			s_axil_rready = 1'b0;
		end
	endtask
	task automatic resolve_mem_dir;
		input string sample_file;
		output string mem_dir;
		reg signed [31:0] fd;
		reg signed [31:0] found;
		begin
			found = 0;
			if ($value$plusargs("MEM_DIR=%s", mem_dir)) begin
				if (((mem_dir.len() > 0) && (mem_dir[mem_dir.len() - 1] != "/")) && (mem_dir[mem_dir.len() - 1] != "\\"))
					mem_dir = {mem_dir, "/"};
				fd = $fopen({mem_dir, sample_file}, "r");
				if (fd != 0) begin
					$fclose(fd);
					found = 1;
				end
			end
			if (!found) begin
				mem_dir = "TEST/GoldenReference/";
				fd = $fopen({mem_dir, sample_file}, "r");
				if (fd != 0) begin
					$fclose(fd);
					found = 1;
				end
			end
			if (!found) begin
				$display("\n=====================================================================================");
				$display(" [FATAL ERROR] Required test vector file '%s' was NOT found!", sample_file);
				$display(" Checked plusarg path and standard default 'TEST/GoldenReference/'.");
				$display(" Please provide a valid path via +MEM_DIR=<path> (e.g. in Vivado simulation settings).");
				$display("=====================================================================================\n");
				$display("Fatal [%0t] /mnt/c/Users/Niels/Documents/nct/MyProjects/CrocoScale_SoC/TEST/SoftLogic/minimal/system/tb_npu_minimal_benchmark.sv:712:13 - tb_npu_minimal_benchmark.resolve_mem_dir.<unnamed_block>\n msg: ", $time, "Aborting simulation due to missing test vector files.");
				$finish(1);
			end
		end
	endtask
	task automatic check_file_exists;
		input string filename;
		reg signed [31:0] fd;
		begin
			fd = $fopen(filename, "r");
			if (fd == 0) begin
				$display("\n[FATAL ERROR] Required memory file '%s' was NOT found!", filename);
				$display("Fatal [%0t] /mnt/c/Users/Niels/Documents/nct/MyProjects/CrocoScale_SoC/TEST/SoftLogic/minimal/system/tb_npu_minimal_benchmark.sv:721:13 - tb_npu_minimal_benchmark.check_file_exists.<unnamed_block>\n msg: ", $time, "Aborting simulation due to missing test vector files.");
				$finish(1);
			end
			$fclose(fd);
		end
	endtask
	task automatic assert_vector_nonzero;
		input string vec_name;
		input reg signed [31:0] nonzero_count;
		input reg signed [31:0] min_required;
		begin
			min_required = 1;
			if (nonzero_count < min_required) begin
				$display("\n[FATAL ERROR] Vector '%s' contains NO non-zero elements (%0d found, min %0d required)!", vec_name, nonzero_count, min_required);
				$display("Fatal [%0t] /mnt/c/Users/Niels/Documents/nct/MyProjects/CrocoScale_SoC/TEST/SoftLogic/minimal/system/tb_npu_minimal_benchmark.sv:734:13 - tb_npu_minimal_benchmark.assert_vector_nonzero.<unnamed_block>\n msg: ", $time, "Zero-data assertion failure on vector: %s", vec_name);
				$finish(1);
			end
		end
	endtask
	function automatic string get_progress_bar;
		input reg signed [31:0] current;
		input reg signed [31:0] total;
		string bar;
		reg signed [31:0] filled;
		begin
			bar = "[";
			filled = (current * 20) / total;
			begin : sv2v_autoblock_1
				reg signed [31:0] i;
				for (i = 0; i < 20; i = i + 1)
					if (i < filled)
						bar = {bar, "="};
					else if (i == filled)
						bar = {bar, ">"};
					else
						bar = {bar, " "};
			end
			bar = {bar, "]"};
			get_progress_bar = bar;
		end
	endfunction
	function automatic signed [7:0] requantize;
		input reg signed [31:0] psum;
		input reg signed [15:0] scale_m0;
		input reg signed [31:0] shift_n;
		input reg signed [7:0] zp;
		reg signed [47:0] prod;
		reg signed [47:0] round_offset;
		reg signed [47:0] rounded_prod;
		reg signed [47:0] shifted_val;
		reg signed [47:0] offset_val;
		begin
			prod = psum * scale_m0;
			if (shift_n > 0)
				round_offset = (48'sd1 <<< (shift_n - 1)) - (prod[47] ? 48'sd1 : 48'sd0);
			else
				round_offset = 48'sd0;
			rounded_prod = prod + round_offset;
			shifted_val = rounded_prod >>> shift_n;
			offset_val = shifted_val + zp;
			if (offset_val > 48'sd127)
				requantize = 8'sd127;
			else if (offset_val < -48'sd128)
				requantize = -8'sd128;
			else
				requantize = offset_val[7:0];
		end
	endfunction
	function automatic signed [31:0] get_hw_psum_mem0;
		input reg signed [31:0] ch;
		case (ch)
			0: get_hw_psum_mem0 = npu_wrapper_inst.gen_psum_srams[0].psum_sram_inst.mem[0];
			1: get_hw_psum_mem0 = npu_wrapper_inst.gen_psum_srams[1].psum_sram_inst.mem[0];
			2: get_hw_psum_mem0 = npu_wrapper_inst.gen_psum_srams[2].psum_sram_inst.mem[0];
			3: get_hw_psum_mem0 = npu_wrapper_inst.gen_psum_srams[3].psum_sram_inst.mem[0];
			4: get_hw_psum_mem0 = npu_wrapper_inst.gen_psum_srams[4].psum_sram_inst.mem[0];
			5: get_hw_psum_mem0 = npu_wrapper_inst.gen_psum_srams[5].psum_sram_inst.mem[0];
			6: get_hw_psum_mem0 = npu_wrapper_inst.gen_psum_srams[6].psum_sram_inst.mem[0];
			7: get_hw_psum_mem0 = npu_wrapper_inst.gen_psum_srams[7].psum_sram_inst.mem[0];
			default: get_hw_psum_mem0 = 32'sd0;
		endcase
	endfunction
	initial begin
		#(500000000)
			;
		$display("\n[ERROR] Simulation Watchdog Timeout in Benchmark (50,000,000 cycles)!");
		$finish;
	end
	function automatic [31:0] sv2v_cast_32;
		input reg [31:0] inp;
		sv2v_cast_32 = inp;
	endfunction
	initial begin : sv2v_autoblock_2
		reg signed [63:0] start_time;
		reg signed [63:0] total_cycles;
		reg signed [63:0] ideal_macs;
		reg signed [63:0] ideal_cycles;
		reg signed [63:0] compute_cycles;
		real compute_eff;
		real e2e_eff;
		reg signed [31:0] errs;
		reg signed [31:0] tol_ok;
		reg signed [31:0] exact_ok;
		reg signed [31:0] max_diff;
		reg signed [31:0] diff_val;
		reg signed [31:0] p_idx;
		reg signed [31:0] ch_idx;
		reg signed [31:0] ch_global;
		reg signed [31:0] ty;
		reg signed [31:0] tx;
		reg signed [31:0] cout_b;
		reg signed [31:0] block_idx;
		reg signed [31:0] done_blks;
		reg signed [31:0] tile_id;
		reg signed [31:0] flat_idx;
		reg [31:0] read_status;
		string mem_dir;
		reg signed [31:0] nz_act;
		reg signed [31:0] nz_w;
		reg signed [31:0] nz_b;
		reg signed [31:0] nz_cfg;
		reg signed [31:0] nz_gold;
		reg signed [7:0] act_val;
		reg signed [7:0] gold_val;
		reg signed [31:0] i_init;
		reg signed [31:0] p;
		reg signed [31:0] s;
		reg signed [31:0] ci;
		reg signed [31:0] co;
		reg signed [31:0] ky;
		reg signed [31:0] kx;
		reg signed [31:0] cb;
		reg signed [31:0] cin_curr;
		reg signed [31:0] gy;
		reg signed [31:0] gx;
		reg signed [31:0] mem_addr;
		reg signed [31:0] y;
		reg signed [31:0] x;
		reg signed [31:0] max_blocks;
		reg signed [31:0] ch_exact [0:7];
		reg signed [31:0] ch_tol [0:7];
		reg signed [31:0] ch_err [0:7];
		reg signed [31:0] print_err_cnt;
		reg signed [31:0] c;
		reg signed [31:0] diag_hw_psum;
		reg signed [31:0] diag_math_psum;
		reg signed [15:0] diag_scale_m0;
		reg signed [31:0] diag_shift_n;
		reg signed [31:0] d_ky;
		reg signed [31:0] d_kx;
		reg signed [31:0] d_ci;
		reg signed [31:0] d_gy;
		reg signed [31:0] d_gx;
		reg signed [7:0] diag_zp;
		reg signed [7:0] diag_req_hw;
		reg signed [7:0] diag_req_math;
		reg signed [7:0] diag_axi_act;
		reg signed [7:0] diag_gold;
		$display("=====================================================================================");
		$display("   NPU SCALING EVALUATION: 3x3 CONVOLUTION (MINIMAL SOFT-LOGIC BENCHMARK)            ");
		$display("=====================================================================================");
		$display("   Input Tensor Dimensions  : 48x48 (Height x Width), 128 Channels");
		$display("   Output Tensor Dimensions : 48x48 (Height x Width), 32 Channels");
		$display("   Kernel Configuration     : 3x3 Conv, Stride 1, SAME Padding");
		$display("   Spatial Partitioning     : 3x3 Tiles of 16x16 (Exact 100%% Spatial Alignment)");
		$display("   Channel Processing       : 4 Output Channel Blocks (Exact 100%% Channel Alignment)");
		$display("   Total Workload Execution : 36 Total Blocks | 144 Passes/Block (5,184 Passes Total)");
		$display("   Reduction Depth (K_total): 1152 Taps -> 144 Passes (8 Taps/Pass continuous streaming)");
		$display("   Harness Configuration    : efpga_boundary_harness (CFG_AXI_M=12'hF3E, CFG_SLICE=48'h1E1A16120E0A0602)");
		$display("   Memory Persistence       : Multi-Block In-Place AXI RAM Retention (No Reset/Wipe)");
		$display("=====================================================================================\n");
		resolve_mem_dir("bench_im2col_act.mem", mem_dir);
		$display("[INFO] Resolved memory directory: '%s'", mem_dir);
		check_file_exists({mem_dir, "bench_im2col_act.mem"});
		check_file_exists({mem_dir, "bench_im2col_w.mem"});
		check_file_exists({mem_dir, "bench_im2col_b.mem"});
		check_file_exists({mem_dir, "bench_im2col_cfg.mem"});
		check_file_exists({mem_dir, "bench_im2col_out_quant.mem"});
		$readmemh({mem_dir, "bench_im2col_act.mem"}, fmap_in);
		$readmemh({mem_dir, "bench_im2col_w.mem"}, w1_flat);
		$readmemh({mem_dir, "bench_im2col_b.mem"}, b1_flat);
		$readmemh({mem_dir, "bench_im2col_cfg.mem"}, p1_cfg);
		$readmemh({mem_dir, "bench_im2col_out_quant.mem"}, gold_act);
		nz_act = 0;
		nz_w = 0;
		nz_b = 0;
		nz_cfg = 0;
		nz_gold = 0;
		for (i_init = 0; i_init < ((CONV_H * CONV_W) * CIN); i_init = i_init + 1)
			if (fmap_in[i_init] !== 8'sd0)
				nz_act = nz_act + 1;
		for (i_init = 0; i_init < 36864; i_init = i_init + 1)
			if (w1_flat[i_init] !== 8'sd0)
				nz_w = nz_w + 1;
		for (i_init = 0; i_init < COUT; i_init = i_init + 1)
			if (b1_flat[i_init] !== 32'sd0)
				nz_b = nz_b + 1;
		for (i_init = 0; i_init < COUT; i_init = i_init + 1)
			if (p1_cfg[i_init] !== 32'd0)
				nz_cfg = nz_cfg + 1;
		for (i_init = 0; i_init < 73728; i_init = i_init + 1)
			if (gold_act[i_init] !== 8'sd0)
				nz_gold = nz_gold + 1;
		$display("[INFO] Loaded test vectors: %0d non-zero activations, %0d non-zero weights, %0d non-zero biases, %0d non-zero golden outputs.", nz_act, nz_w, nz_b, nz_gold);
		assert_vector_nonzero("fmap_in", nz_act, 10);
		assert_vector_nonzero("w1_flat", nz_w, 10);
		assert_vector_nonzero("b1_flat", nz_b, 1);
		assert_vector_nonzero("gold_act", nz_gold, 10);
		rst_n = 0;
		s_axil_awaddr = 1'sb0;
		s_axil_awprot = 1'sb0;
		s_axil_awvalid = 1'sb0;
		s_axil_wdata = 1'sb0;
		s_axil_wstrb = 1'sb0;
		s_axil_wvalid = 1'sb0;
		s_axil_bready = 1'sb0;
		s_axil_araddr = 1'sb0;
		s_axil_arprot = 1'sb0;
		s_axil_arvalid = 1'sb0;
		s_axil_rready = 1'sb0;
		#(50)
			;
		@(negedge clk)
			;
		rst_n = 1;
		#(50)
			;
		for (cout_b = 0; cout_b < 4; cout_b = cout_b + 1)
			for (co = 0; co < 8; co = co + 1)
				ram_write_word((BIAS_BASE_ADDR + (cout_b * 32)) + (co * 4), b1_flat[(cout_b * 8) + co]);
		for (cout_b = 0; cout_b < 4; cout_b = cout_b + 1)
			for (cb = 0; cb < 16; cb = cb + 1)
				for (ky = 0; ky < 3; ky = ky + 1)
					for (kx = 0; kx < 3; kx = kx + 1)
						begin
							p = ((cb * 9) + (ky * 3)) + kx;
							for (s = 0; s < 8; s = s + 1)
								for (ci = 0; ci < 8; ci = ci + 1)
									begin
										co = 7 - s;
										mem_addr = (((WEIGHT_BASE_ADDR + ((cout_b * 144) * 64)) + (p * 64)) + (s * 8)) + ci;
										ram_write_byte(mem_addr, w1_flat[(((((ky * 3) * CIN) * COUT) + ((kx * CIN) * COUT)) + (((cb * 8) + ci) * COUT)) + ((cout_b * 8) + co)]);
									end
						end
		for (ty = 0; ty < 3; ty = ty + 1)
			for (tx = 0; tx < 3; tx = tx + 1)
				begin
					tile_id = (ty * 3) + tx;
					for (cb = 0; cb < 16; cb = cb + 1)
						for (y = 0; y < 18; y = y + 1)
							for (x = 0; x < 18; x = x + 1)
								begin
									gy = ((ty * 16) + y) - 1;
									gx = ((tx * 16) + x) - 1;
									for (ci = 0; ci < 8; ci = ci + 1)
										begin
											cin_curr = (cb * 8) + ci;
											mem_addr = (((ACT_BASE_ADDR + ((tile_id * 16) * 2592)) + (cb * 2592)) + (((y * 18) + x) * 8)) + ci;
											if (((((gy >= 0) && (gy < CONV_H)) && (gx >= 0)) && (gx < CONV_W)) && (cin_curr < CIN))
												ram_write_byte(mem_addr, fmap_in[(((gy * CONV_W) * CIN) + (gx * CIN)) + cin_curr]);
											else
												ram_write_byte(mem_addr, 8'sd0);
										end
								end
				end
		$display(">>> Prepopulation Complete. Beginning 36-Block Continuous Benchmark Execution <<<\n");
		done_blks = 0;
		start_time = $time;
		if (!$value$plusargs("MAX_BLOCKS=%d", max_blocks))
			max_blocks = TOTAL_BLOCKS;
		for (c = 0; c < 8; c = c + 1)
			begin
				ch_exact[c] = 0;
				ch_tol[c] = 0;
				ch_err[c] = 0;
			end
		for (ty = 0; ty < 3; ty = ty + 1)
			for (tx = 0; tx < 3; tx = tx + 1)
				for (cout_b = 0; cout_b < 4; cout_b = cout_b + 1)
					if (done_blks < max_blocks) begin
						block_idx = (((ty * 3) + tx) * 4) + cout_b;
						axil_write(32'h00000008, ACT_BASE_ADDR + ((((ty * 3) + tx) * 16) * 2592));
						axil_write(32'h0000000c, WEIGHT_BASE_ADDR + ((cout_b * 144) * 64));
						axil_write(32'h00000010, OUT_BASE_ADDR + (block_idx * 2048));
						axil_write(32'h00000014, BIAS_BASE_ADDR + (cout_b * 32));
						for (c = 7; c >= 0; c = c - 1)
							axil_write(32'h00000018, {2'b00, p1_cfg[(cout_b * 8) + c][29:0]});
						axil_write(32'h0000001c, 32'h00009001);
						axil_write(32'h00000000, 32'h00000001);
						read_status = 32'h00000000;
						while (!read_status[1]) begin
							#(500)
								;
							axil_read(32'h00000004, read_status);
						end
						done_blks = done_blks + 1;
						$display("  %s %3d%% (Block %2d/%0d) [Tile (%0d,%0d), Cout Blk %0d/4] | Latency: %8d cycles", get_progress_bar(done_blks, max_blocks), (done_blks * 100) / max_blocks, done_blks, max_blocks, ty, tx, cout_b + 1, ($time - start_time) / 10);
						if (done_blks == 1) begin
							$display("\n=========================================================================================");
							$display("   [DIAGNOSTIC BLOCK 0 COMPLETED] DIRECT PSUM SRAM INSPECTION (Pixel 0, Channels 0..7)   ");
							$display("=========================================================================================");
							for (c = 0; c < 8; c = c + 1)
								begin
									diag_hw_psum = get_hw_psum_mem0(c);
									diag_math_psum = b1_flat[c];
									for (d_ky = 0; d_ky < 3; d_ky = d_ky + 1)
										begin
											d_gy = d_ky - 1;
											for (d_kx = 0; d_kx < 3; d_kx = d_kx + 1)
												begin
													d_gx = d_kx - 1;
													if ((((d_gy >= 0) && (d_gy < CONV_H)) && (d_gx >= 0)) && (d_gx < CONV_W))
														for (d_ci = 0; d_ci < CIN; d_ci = d_ci + 1)
															diag_math_psum = diag_math_psum + (sv2v_cast_32(fmap_in[(((d_gy * CONV_W) * CIN) + (d_gx * CIN)) + d_ci]) * sv2v_cast_32(w1_flat[(((((d_ky * 3) * CIN) * COUT) + ((d_kx * CIN) * COUT)) + (d_ci * COUT)) + c]));
												end
										end
									diag_scale_m0 = p1_cfg[c][15:0];
									diag_shift_n = p1_cfg[c][21:16];
									diag_zp = $signed(p1_cfg[c][29:22]);
									diag_req_hw = requantize(diag_hw_psum, diag_scale_m0, diag_shift_n, diag_zp);
									diag_req_math = requantize(diag_math_psum, diag_scale_m0, diag_shift_n, diag_zp);
									ram_read_byte(OUT_BASE_ADDR + c, diag_axi_act);
									diag_gold = gold_act[c];
									$display("  Ch %0d: HW_PSUM=%8d | Math_PSUM=%8d | Diff_PSUM=%6d | HW_Req=%4d | Math_Req=%4d | AXI_RAM=%4d | Gold=%4d", c, diag_hw_psum, diag_math_psum, diag_hw_psum - diag_math_psum, diag_req_hw, diag_req_math, diag_axi_act, diag_gold);
								end
							$display("=========================================================================================\n");
						end
					end
		total_cycles = ($time - start_time) / 10;
		$display("\n=========================================================================================");
		$display(">>> VALIDATING PERSISTENT OUTPUT TENSOR IN AXI RAM (%0d BLOCKS, %0d ACTIVATIONS) <<<", done_blks, done_blks * 2048);
		$display("=========================================================================================");
		errs = 0;
		tol_ok = 0;
		exact_ok = 0;
		max_diff = 0;
		print_err_cnt = 0;
		for (ty = 0; ty < 3; ty = ty + 1)
			for (tx = 0; tx < 3; tx = tx + 1)
				for (cout_b = 0; cout_b < 4; cout_b = cout_b + 1)
					begin
						block_idx = (((ty * 3) + tx) * 4) + cout_b;
						if (block_idx < done_blks)
							for (p_idx = 0; p_idx < 256; p_idx = p_idx + 1)
								begin
									gy = (ty * 16) + (p_idx / 16);
									gx = (tx * 16) + (p_idx % 16);
									for (ch_idx = 0; ch_idx < 8; ch_idx = ch_idx + 1)
										begin
											ch_global = (cout_b * 8) + ch_idx;
											flat_idx = (((gy * CONV_W) * COUT) + (gx * COUT)) + ch_global;
											gold_val = gold_act[flat_idx];
											ram_read_byte(((OUT_BASE_ADDR + (block_idx * 2048)) + (p_idx * 8)) + ch_idx, act_val);
											if ($isunknown(act_val)) begin
												errs = errs + 1;
												ch_err[ch_idx] = ch_err[ch_idx] + 1;
												max_diff = 255;
												if (errs <= 10)
													$display("[FATAL] RAM activation at flat_idx=%0d (block=%0d, p=%0d, ch=%0d) is UNKNOWN (X)!", flat_idx, block_idx, p_idx, ch_idx);
											end
											else begin
												diff_val = (act_val > gold_val ? act_val - gold_val : gold_val - act_val);
												if (diff_val == 0) begin
													exact_ok = exact_ok + 1;
													ch_exact[ch_idx] = ch_exact[ch_idx] + 1;
												end
												else if (diff_val <= 1) begin
													tol_ok = tol_ok + 1;
													ch_tol[ch_idx] = ch_tol[ch_idx] + 1;
												end
												else begin
													errs = errs + 1;
													ch_err[ch_idx] = ch_err[ch_idx] + 1;
													if (print_err_cnt < 16) begin
														$display("  [MISMATCH #%0d] Block %0d (Tile %0d,%0d, Cout %0d) p=%0d (gy=%0d, gx=%0d) ch_local=%0d (ch_glob=%0d) | Act=%4d Gold=%4d Diff=%2d", print_err_cnt + 1, block_idx, ty, tx, cout_b, p_idx, gy, gx, ch_idx, ch_global, $signed(act_val), $signed(gold_val), diff_val);
														print_err_cnt = print_err_cnt + 1;
													end
												end
												if (diff_val > max_diff)
													max_diff = diff_val;
											end
										end
								end
					end
		$display("\n=========================================================================================");
		$display("   PER-CHANNEL VERIFICATION BREAKDOWN (Across Local Channels 0..7)                       ");
		$display("=========================================================================================");
		for (c = 0; c < 8; c = c + 1)
			$display("  Local Ch %0d: Exact=%5d | Tol(+/-1)=%5d | Err(>1)=%5d", c, ch_exact[c], ch_tol[c], ch_err[c]);
		$display("=========================================================================================");
		ideal_macs = (((64'd48 * 64'd48) * 64'd128) * 64'd32) * 64'd9;
		ideal_cycles = ideal_macs / 64;
		compute_cycles = (64'd36 * 64'd144) * 64'd260;
		compute_eff = ($itor(ideal_cycles) / $itor(compute_cycles)) * 100.0;
		e2e_eff = ($itor(ideal_cycles) / $itor(total_cycles)) * 100.0;
		$display("\n=========================================================================================");
		$display(">>> MINIMAL CONTROLLER BENCHMARK RESULTS (%0d BLOCKS, %0d PASSES) <<<", done_blks, done_blks * 144);
		$display("=========================================================================================");
		$display("  Total Latency:         %0d clock cycles", total_cycles);
		$display("  Ideal Peak Cycles:     %0d clock cycles (at 64 MACs/cycle)", ideal_cycles);
		$display("  Mathematical MACs:     %0d operations", ideal_macs);
		$display("  Compute Array Eff:     %0.2f%%", compute_eff);
		$display("  End-to-End System Eff: %0.2f%%", e2e_eff);
		$display("  Sustained Throughput:  %0.2f MACs/cycle", $itor(ideal_macs) / $itor(total_cycles));
		$display("  Peak Theoretical:      64.00 MACs/cycle");
		$display("  Total Validated:       %0d activations", done_blks * 2048);
		$display("  Exact Matches (diff 0):%0d (%0.2f%%)", exact_ok, ($itor(exact_ok) / (done_blks * 2048.0)) * 100.0);
		$display("  Tol Matches   (diff 1):%0d (%0.2f%%)", tol_ok, ($itor(tol_ok) / (done_blks * 2048.0)) * 100.0);
		$display("  Errors        (diff >1):%0d", errs);
		$display("  Max Discrepancy:       %0d", max_diff);
		$display("=========================================================================================");
		if ((errs == 0) && (exact_ok > 0))
			$display(">>> SUCCESS: Minimal 36-Block Benchmark PASSED 100%%! <<<");
		else begin
			$display(">>> FAILED: Benchmark had %0d mismatches across the output tensor! <<<", errs);
			$display("Fatal [%0t] /mnt/c/Users/Niels/Documents/nct/MyProjects/CrocoScale_SoC/TEST/SoftLogic/minimal/system/tb_npu_minimal_benchmark.sv:1118:13 - tb_npu_minimal_benchmark.<unnamed_block>.<unnamed_block>\n msg: ", $time, "Minimal benchmark verification failed!");
			$finish(1);
		end
		$finish;
	end
endmodule
