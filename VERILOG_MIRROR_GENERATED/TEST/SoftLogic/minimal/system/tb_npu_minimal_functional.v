module tb_npu_minimal_functional;
	reg clk;
	reg rst_n;
	reg test_mode;
	reg [31:0] s_axil_awaddr;
	reg [2:0] s_axil_awprot;
	reg s_axil_awvalid;
	wire s_axil_awready;
	reg [31:0] s_axil_wdata;
	reg [3:0] s_axil_wstrb;
	reg s_axil_wvalid;
	wire s_axil_wready;
	wire [1:0] s_axil_bresp;
	wire s_axil_bvalid;
	reg s_axil_bready;
	reg [31:0] s_axil_araddr;
	reg [2:0] s_axil_arprot;
	reg s_axil_arvalid;
	wire s_axil_arready;
	wire [31:0] s_axil_rdata;
	wire [1:0] s_axil_rresp;
	wire s_axil_rvalid;
	reg s_axil_rready;
	wire [31:0] m_axi_awaddr;
	wire [7:0] m_axi_awlen;
	wire [2:0] m_axi_awsize;
	wire [1:0] m_axi_awburst;
	wire m_axi_awvalid;
	wire m_axi_awready;
	wire [31:0] m_axi_wdata;
	wire [3:0] m_axi_wstrb;
	wire m_axi_wlast;
	wire m_axi_wvalid;
	wire m_axi_wready;
	wire [1:0] m_axi_bresp;
	wire m_axi_bvalid;
	wire m_axi_bready;
	wire [31:0] m_axi_araddr;
	wire [7:0] m_axi_arlen;
	wire [2:0] m_axi_arsize;
	wire [1:0] m_axi_arburst;
	wire m_axi_arvalid;
	wire m_axi_arready;
	wire [31:0] m_axi_rdata;
	wire [1:0] m_axi_rresp;
	wire m_axi_rlast;
	wire m_axi_rvalid;
	wire m_axi_rready;
	wire npu_array_en;
	wire npu_psum_systolic_en;
	wire npu_psum_lut_en;
	wire npu_psum_skew_en;
	wire npu_compute_bank_swap;
	wire [31:0] npu_crossbar_sel;
	wire signed [63:0] npu_weight_shift_in;
	wire [1:0] npu_weight_shift_en;
	wire npu_swap_weights;
	wire [29:0] npu_quant_shift_in;
	wire npu_quant_shift_en;
	wire npu_stochastic_round_en;
	wire [15:0] npu_lfsr_data_out;
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
	localparam signed [31:0] MEM_ADDR_WIDTH = 16;
	localparam [31:0] ACT_BASE_ADDR = 32'h00001000;
	localparam [31:0] WEIGHT_BASE_ADDR = 32'h00002000;
	localparam [31:0] OUT_BASE_ADDR = 32'h00003000;
	localparam [31:0] BIAS_BASE_ADDR = 32'h00004000;
	axi_ram #(
		.DATA_WIDTH(32),
		.ADDR_WIDTH(MEM_ADDR_WIDTH),
		.ID_WIDTH(1),
		.PIPELINE_OUTPUT(0)
	) axi_ram_inst(
		.clk(clk),
		.rst(~rst_n),
		.s_axi_awid(1'b0),
		.s_axi_awaddr(m_axi_awaddr[15:0]),
		.s_axi_awlen(m_axi_awlen),
		.s_axi_awsize(m_axi_awsize),
		.s_axi_awburst(m_axi_awburst),
		.s_axi_awlock(1'b0),
		.s_axi_awcache(4'b0011),
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
		.s_axi_araddr(m_axi_araddr[15:0]),
		.s_axi_arlen(m_axi_arlen),
		.s_axi_arsize(m_axi_arsize),
		.s_axi_arburst(m_axi_arburst),
		.s_axi_arlock(1'b0),
		.s_axi_arcache(4'b0011),
		.s_axi_arprot(3'b000),
		.s_axi_arvalid(m_axi_arvalid),
		.s_axi_arready(m_axi_arready),
		.s_axi_rdata(m_axi_rdata),
		.s_axi_rresp(m_axi_rresp),
		.s_axi_rlast(m_axi_rlast),
		.s_axi_rvalid(m_axi_rvalid),
		.s_axi_rready(m_axi_rready)
	);
	npu_wrapper #(
		.ARRAY_HEIGHT(8),
		.ARRAY_WIDTH(8),
		.TILE_SIZE(16),
		.ACTIVATION_WIDTH(8),
		.WEIGHT_WIDTH(8),
		.PSUM_WIDTH(32),
		.SCALE_WIDTH(16),
		.WEIGHT_SPLIT(2)
	) npu_wrapper_inst(
		.clk_i(clk),
		.rst_n(rst_n),
		.array_en(npu_array_en),
		.psum_systolic_en(npu_psum_systolic_en),
		.psum_lut_en(npu_psum_lut_en),
		.crossbar_sel(npu_crossbar_sel),
		.weight_shift_in(npu_weight_shift_in),
		.weight_shift_en(npu_weight_shift_en),
		.swap_weights(npu_swap_weights),
		.quant_shift_in(npu_quant_shift_in),
		.quant_shift_en(npu_quant_shift_en),
		.stochastic_round_en(npu_stochastic_round_en),
		.lfsr_data_out(npu_lfsr_data_out),
		.psum_skew_en(npu_psum_skew_en),
		.compute_bank_swap(npu_compute_bank_swap),
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
	wire dut1_s_axil_awready;
	wire dut1_s_axil_wready;
	wire dut1_s_axil_bvalid;
	wire dut1_s_axil_arready;
	wire dut1_s_axil_rvalid;
	wire [1:0] dut1_s_axil_bresp;
	wire [1:0] dut1_s_axil_rresp;
	wire [31:0] dut1_s_axil_rdata;
	wire [31:0] dut1_m_axi_awaddr;
	wire [31:0] dut1_m_axi_wdata;
	wire [31:0] dut1_m_axi_araddr;
	wire [7:0] dut1_m_axi_awlen;
	wire [7:0] dut1_m_axi_arlen;
	wire [2:0] dut1_m_axi_awsize;
	wire [2:0] dut1_m_axi_arsize;
	wire [1:0] dut1_m_axi_awburst;
	wire [1:0] dut1_m_axi_arburst;
	wire [3:0] dut1_m_axi_wstrb;
	wire dut1_m_axi_awvalid;
	wire dut1_m_axi_wlast;
	wire dut1_m_axi_wvalid;
	wire dut1_m_axi_bready;
	wire dut1_m_axi_arvalid;
	wire dut1_m_axi_rready;
	wire dut1_array_en;
	wire dut1_psum_systolic_en;
	wire dut1_psum_lut_en;
	wire dut1_psum_skew_en;
	wire dut1_compute_bank_swap;
	wire dut1_swap_weights;
	wire dut1_quant_shift_en;
	wire dut1_stochastic_round_en;
	wire [31:0] dut1_crossbar_sel;
	wire signed [63:0] dut1_weight_shift_in;
	wire [1:0] dut1_weight_shift_en;
	wire [29:0] dut1_quant_shift_in;
	wire [7:0] dut1_psum_A_addr;
	wire [7:0] dut1_psum_A_we;
	wire [7:0] dut1_psum_B_addr;
	wire [7:0] dut1_psum_B_we;
	wire signed [31:0] dut1_psum_A_wdata;
	wire signed [31:0] dut1_psum_B_wdata;
	wire [2:0] dut1_psum_A_read_bank_sel;
	wire [2:0] dut1_psum_B_read_bank_sel;
	wire [7:0] dut1_ext_act_sram_we;
	wire [71:0] dut1_ext_act_sram_addr;
	wire signed [63:0] dut1_ext_act_sram_wdata;
	wire [3:0] dut1_usr_irq;
	wire rst_n_1x1 = rst_n && (test_mode == 1'b0);
	npu_min_controller #(
		.KERNEL_SIZE(1),
		.ARRAY_HEIGHT(8),
		.ARRAY_WIDTH(8),
		.TILE_SIZE(16),
		.ACTIVATION_WIDTH(8),
		.WEIGHT_WIDTH(8),
		.PSUM_WIDTH(32),
		.SCALE_WIDTH(16),
		.WEIGHT_SPLIT(2),
		.AXI_ADDR_WIDTH(32),
		.AXI_DATA_WIDTH(32)
	) dut_1x1(
		.clk_i(clk),
		.rst_n(rst_n_1x1),
		.s_axil_awaddr(s_axil_awaddr),
		.s_axil_awprot(s_axil_awprot),
		.s_axil_awvalid(s_axil_awvalid & (test_mode == 1'b0)),
		.s_axil_awready(dut1_s_axil_awready),
		.s_axil_wdata(s_axil_wdata),
		.s_axil_wstrb(s_axil_wstrb),
		.s_axil_wvalid(s_axil_wvalid & (test_mode == 1'b0)),
		.s_axil_wready(dut1_s_axil_wready),
		.s_axil_bresp(dut1_s_axil_bresp),
		.s_axil_bvalid(dut1_s_axil_bvalid),
		.s_axil_bready(s_axil_bready & (test_mode == 1'b0)),
		.s_axil_araddr(s_axil_araddr),
		.s_axil_arprot(s_axil_arprot),
		.s_axil_arvalid(s_axil_arvalid & (test_mode == 1'b0)),
		.s_axil_arready(dut1_s_axil_arready),
		.s_axil_rdata(dut1_s_axil_rdata),
		.s_axil_rresp(dut1_s_axil_rresp),
		.s_axil_rvalid(dut1_s_axil_rvalid),
		.s_axil_rready(s_axil_rready & (test_mode == 1'b0)),
		.m_axi_awaddr(dut1_m_axi_awaddr),
		.m_axi_awlen(dut1_m_axi_awlen),
		.m_axi_awsize(dut1_m_axi_awsize),
		.m_axi_awburst(dut1_m_axi_awburst),
		.m_axi_awvalid(dut1_m_axi_awvalid),
		.m_axi_awready(m_axi_awready),
		.m_axi_wdata(dut1_m_axi_wdata),
		.m_axi_wstrb(dut1_m_axi_wstrb),
		.m_axi_wlast(dut1_m_axi_wlast),
		.m_axi_wvalid(dut1_m_axi_wvalid),
		.m_axi_wready(m_axi_wready),
		.m_axi_bresp(m_axi_bresp),
		.m_axi_bvalid(m_axi_bvalid),
		.m_axi_bready(dut1_m_axi_bready),
		.m_axi_araddr(dut1_m_axi_araddr),
		.m_axi_arlen(dut1_m_axi_arlen),
		.m_axi_arsize(dut1_m_axi_arsize),
		.m_axi_arburst(dut1_m_axi_arburst),
		.m_axi_arvalid(dut1_m_axi_arvalid),
		.m_axi_arready(m_axi_arready),
		.m_axi_rdata(m_axi_rdata),
		.m_axi_rresp(m_axi_rresp),
		.m_axi_rlast(m_axi_rlast),
		.m_axi_rvalid(m_axi_rvalid),
		.m_axi_rready(dut1_m_axi_rready),
		.npu_array_en(dut1_array_en),
		.npu_psum_systolic_en(dut1_psum_systolic_en),
		.npu_psum_lut_en(dut1_psum_lut_en),
		.npu_psum_skew_en(dut1_psum_skew_en),
		.npu_compute_bank_swap(dut1_compute_bank_swap),
		.npu_crossbar_sel(dut1_crossbar_sel),
		.npu_weight_shift_in(dut1_weight_shift_in),
		.npu_weight_shift_en(dut1_weight_shift_en),
		.npu_swap_weights(dut1_swap_weights),
		.npu_quant_shift_in(dut1_quant_shift_in),
		.npu_quant_shift_en(dut1_quant_shift_en),
		.npu_stochastic_round_en(dut1_stochastic_round_en),
		.npu_psum_A_addr(dut1_psum_A_addr),
		.npu_psum_A_we(dut1_psum_A_we),
		.npu_psum_A_wdata(dut1_psum_A_wdata),
		.npu_psum_A_read_bank_sel(dut1_psum_A_read_bank_sel),
		.npu_psum_A_rdata(npu_psum_A_rdata),
		.npu_psum_B_addr(dut1_psum_B_addr),
		.npu_psum_B_we(dut1_psum_B_we),
		.npu_psum_B_wdata(dut1_psum_B_wdata),
		.npu_psum_B_read_bank_sel(dut1_psum_B_read_bank_sel),
		.npu_psum_B_rdata(npu_psum_B_rdata),
		.npu_ext_act_sram_we(dut1_ext_act_sram_we),
		.npu_ext_act_sram_addr(dut1_ext_act_sram_addr),
		.npu_ext_act_sram_wdata(dut1_ext_act_sram_wdata),
		.npu_act_sram_rdata(npu_act_sram_rdata),
		.npu_out_act(npu_out_act),
		.efpga_usr_irq_o(dut1_usr_irq)
	);
	wire dut3_s_axil_awready;
	wire dut3_s_axil_wready;
	wire dut3_s_axil_bvalid;
	wire dut3_s_axil_arready;
	wire dut3_s_axil_rvalid;
	wire [1:0] dut3_s_axil_bresp;
	wire [1:0] dut3_s_axil_rresp;
	wire [31:0] dut3_s_axil_rdata;
	wire [31:0] dut3_m_axi_awaddr;
	wire [31:0] dut3_m_axi_wdata;
	wire [31:0] dut3_m_axi_araddr;
	wire [7:0] dut3_m_axi_awlen;
	wire [7:0] dut3_m_axi_arlen;
	wire [2:0] dut3_m_axi_awsize;
	wire [2:0] dut3_m_axi_arsize;
	wire [1:0] dut3_m_axi_awburst;
	wire [1:0] dut3_m_axi_arburst;
	wire [3:0] dut3_m_axi_wstrb;
	wire dut3_m_axi_awvalid;
	wire dut3_m_axi_wlast;
	wire dut3_m_axi_wvalid;
	wire dut3_m_axi_bready;
	wire dut3_m_axi_arvalid;
	wire dut3_m_axi_rready;
	wire dut3_array_en;
	wire dut3_psum_systolic_en;
	wire dut3_psum_lut_en;
	wire dut3_psum_skew_en;
	wire dut3_compute_bank_swap;
	wire dut3_swap_weights;
	wire dut3_quant_shift_en;
	wire dut3_stochastic_round_en;
	wire [31:0] dut3_crossbar_sel;
	wire signed [63:0] dut3_weight_shift_in;
	wire [1:0] dut3_weight_shift_en;
	wire [29:0] dut3_quant_shift_in;
	wire [7:0] dut3_psum_A_addr;
	wire [7:0] dut3_psum_A_we;
	wire [7:0] dut3_psum_B_addr;
	wire [7:0] dut3_psum_B_we;
	wire signed [31:0] dut3_psum_A_wdata;
	wire signed [31:0] dut3_psum_B_wdata;
	wire [2:0] dut3_psum_A_read_bank_sel;
	wire [2:0] dut3_psum_B_read_bank_sel;
	wire [7:0] dut3_ext_act_sram_we;
	wire [71:0] dut3_ext_act_sram_addr;
	wire signed [63:0] dut3_ext_act_sram_wdata;
	wire [3:0] dut3_usr_irq;
	wire rst_n_3x3 = rst_n && (test_mode == 1'b1);
	npu_min_controller #(
		.KERNEL_SIZE(3),
		.ARRAY_HEIGHT(8),
		.ARRAY_WIDTH(8),
		.TILE_SIZE(16),
		.ACTIVATION_WIDTH(8),
		.WEIGHT_WIDTH(8),
		.PSUM_WIDTH(32),
		.SCALE_WIDTH(16),
		.WEIGHT_SPLIT(2),
		.AXI_ADDR_WIDTH(32),
		.AXI_DATA_WIDTH(32)
	) dut_3x3(
		.clk_i(clk),
		.rst_n(rst_n_3x3),
		.s_axil_awaddr(s_axil_awaddr),
		.s_axil_awprot(s_axil_awprot),
		.s_axil_awvalid(s_axil_awvalid & (test_mode == 1'b1)),
		.s_axil_awready(dut3_s_axil_awready),
		.s_axil_wdata(s_axil_wdata),
		.s_axil_wstrb(s_axil_wstrb),
		.s_axil_wvalid(s_axil_wvalid & (test_mode == 1'b1)),
		.s_axil_wready(dut3_s_axil_wready),
		.s_axil_bresp(dut3_s_axil_bresp),
		.s_axil_bvalid(dut3_s_axil_bvalid),
		.s_axil_bready(s_axil_bready & (test_mode == 1'b1)),
		.s_axil_araddr(s_axil_araddr),
		.s_axil_arprot(s_axil_arprot),
		.s_axil_arvalid(s_axil_arvalid & (test_mode == 1'b1)),
		.s_axil_arready(dut3_s_axil_arready),
		.s_axil_rdata(dut3_s_axil_rdata),
		.s_axil_rresp(dut3_s_axil_rresp),
		.s_axil_rvalid(dut3_s_axil_rvalid),
		.s_axil_rready(s_axil_rready & (test_mode == 1'b1)),
		.m_axi_awaddr(dut3_m_axi_awaddr),
		.m_axi_awlen(dut3_m_axi_awlen),
		.m_axi_awsize(dut3_m_axi_awsize),
		.m_axi_awburst(dut3_m_axi_awburst),
		.m_axi_awvalid(dut3_m_axi_awvalid),
		.m_axi_awready(m_axi_awready),
		.m_axi_wdata(dut3_m_axi_wdata),
		.m_axi_wstrb(dut3_m_axi_wstrb),
		.m_axi_wlast(dut3_m_axi_wlast),
		.m_axi_wvalid(dut3_m_axi_wvalid),
		.m_axi_wready(m_axi_wready),
		.m_axi_bresp(m_axi_bresp),
		.m_axi_bvalid(m_axi_bvalid),
		.m_axi_bready(dut3_m_axi_bready),
		.m_axi_araddr(dut3_m_axi_araddr),
		.m_axi_arlen(dut3_m_axi_arlen),
		.m_axi_arsize(dut3_m_axi_arsize),
		.m_axi_arburst(dut3_m_axi_arburst),
		.m_axi_arvalid(dut3_m_axi_arvalid),
		.m_axi_arready(m_axi_arready),
		.m_axi_rdata(m_axi_rdata),
		.m_axi_rresp(m_axi_rresp),
		.m_axi_rlast(m_axi_rlast),
		.m_axi_rvalid(m_axi_rvalid),
		.m_axi_rready(dut3_m_axi_rready),
		.npu_array_en(dut3_array_en),
		.npu_psum_systolic_en(dut3_psum_systolic_en),
		.npu_psum_lut_en(dut3_psum_lut_en),
		.npu_psum_skew_en(dut3_psum_skew_en),
		.npu_compute_bank_swap(dut3_compute_bank_swap),
		.npu_crossbar_sel(dut3_crossbar_sel),
		.npu_weight_shift_in(dut3_weight_shift_in),
		.npu_weight_shift_en(dut3_weight_shift_en),
		.npu_swap_weights(dut3_swap_weights),
		.npu_quant_shift_in(dut3_quant_shift_in),
		.npu_quant_shift_en(dut3_quant_shift_en),
		.npu_stochastic_round_en(dut3_stochastic_round_en),
		.npu_psum_A_addr(dut3_psum_A_addr),
		.npu_psum_A_we(dut3_psum_A_we),
		.npu_psum_A_wdata(dut3_psum_A_wdata),
		.npu_psum_A_read_bank_sel(dut3_psum_A_read_bank_sel),
		.npu_psum_A_rdata(npu_psum_A_rdata),
		.npu_psum_B_addr(dut3_psum_B_addr),
		.npu_psum_B_we(dut3_psum_B_we),
		.npu_psum_B_wdata(dut3_psum_B_wdata),
		.npu_psum_B_read_bank_sel(dut3_psum_B_read_bank_sel),
		.npu_psum_B_rdata(npu_psum_B_rdata),
		.npu_ext_act_sram_we(dut3_ext_act_sram_we),
		.npu_ext_act_sram_addr(dut3_ext_act_sram_addr),
		.npu_ext_act_sram_wdata(dut3_ext_act_sram_wdata),
		.npu_act_sram_rdata(npu_act_sram_rdata),
		.npu_out_act(npu_out_act),
		.efpga_usr_irq_o(dut3_usr_irq)
	);
	assign s_axil_awready = (test_mode == 1'b0 ? dut1_s_axil_awready : dut3_s_axil_awready);
	assign s_axil_wready = (test_mode == 1'b0 ? dut1_s_axil_wready : dut3_s_axil_wready);
	assign s_axil_bresp = (test_mode == 1'b0 ? dut1_s_axil_bresp : dut3_s_axil_bresp);
	assign s_axil_bvalid = (test_mode == 1'b0 ? dut1_s_axil_bvalid : dut3_s_axil_bvalid);
	assign s_axil_arready = (test_mode == 1'b0 ? dut1_s_axil_arready : dut3_s_axil_arready);
	assign s_axil_rdata = (test_mode == 1'b0 ? dut1_s_axil_rdata : dut3_s_axil_rdata);
	assign s_axil_rresp = (test_mode == 1'b0 ? dut1_s_axil_rresp : dut3_s_axil_rresp);
	assign s_axil_rvalid = (test_mode == 1'b0 ? dut1_s_axil_rvalid : dut3_s_axil_rvalid);
	assign m_axi_awaddr = (test_mode == 1'b0 ? dut1_m_axi_awaddr : dut3_m_axi_awaddr);
	assign m_axi_awlen = (test_mode == 1'b0 ? dut1_m_axi_awlen : dut3_m_axi_awlen);
	assign m_axi_awsize = (test_mode == 1'b0 ? dut1_m_axi_awsize : dut3_m_axi_awsize);
	assign m_axi_awburst = (test_mode == 1'b0 ? dut1_m_axi_awburst : dut3_m_axi_awburst);
	assign m_axi_awvalid = (test_mode == 1'b0 ? dut1_m_axi_awvalid : dut3_m_axi_awvalid);
	assign m_axi_wdata = (test_mode == 1'b0 ? dut1_m_axi_wdata : dut3_m_axi_wdata);
	assign m_axi_wstrb = (test_mode == 1'b0 ? dut1_m_axi_wstrb : dut3_m_axi_wstrb);
	assign m_axi_wlast = (test_mode == 1'b0 ? dut1_m_axi_wlast : dut3_m_axi_wlast);
	assign m_axi_wvalid = (test_mode == 1'b0 ? dut1_m_axi_wvalid : dut3_m_axi_wvalid);
	assign m_axi_bready = (test_mode == 1'b0 ? dut1_m_axi_bready : dut3_m_axi_bready);
	assign m_axi_araddr = (test_mode == 1'b0 ? dut1_m_axi_araddr : dut3_m_axi_araddr);
	assign m_axi_arlen = (test_mode == 1'b0 ? dut1_m_axi_arlen : dut3_m_axi_arlen);
	assign m_axi_arsize = (test_mode == 1'b0 ? dut1_m_axi_arsize : dut3_m_axi_arsize);
	assign m_axi_arburst = (test_mode == 1'b0 ? dut1_m_axi_arburst : dut3_m_axi_arburst);
	assign m_axi_arvalid = (test_mode == 1'b0 ? dut1_m_axi_arvalid : dut3_m_axi_arvalid);
	assign m_axi_rready = (test_mode == 1'b0 ? dut1_m_axi_rready : dut3_m_axi_rready);
	assign npu_array_en = (test_mode == 1'b0 ? dut1_array_en : dut3_array_en);
	assign npu_psum_systolic_en = (test_mode == 1'b0 ? dut1_psum_systolic_en : dut3_psum_systolic_en);
	assign npu_psum_lut_en = (test_mode == 1'b0 ? dut1_psum_lut_en : dut3_psum_lut_en);
	assign npu_psum_skew_en = (test_mode == 1'b0 ? dut1_psum_skew_en : dut3_psum_skew_en);
	assign npu_compute_bank_swap = (test_mode == 1'b0 ? dut1_compute_bank_swap : dut3_compute_bank_swap);
	assign npu_crossbar_sel = (test_mode == 1'b0 ? dut1_crossbar_sel : dut3_crossbar_sel);
	assign npu_weight_shift_in = (test_mode == 1'b0 ? dut1_weight_shift_in : dut3_weight_shift_in);
	assign npu_weight_shift_en = (test_mode == 1'b0 ? dut1_weight_shift_en : dut3_weight_shift_en);
	assign npu_swap_weights = (test_mode == 1'b0 ? dut1_swap_weights : dut3_swap_weights);
	assign npu_quant_shift_in = (test_mode == 1'b0 ? dut1_quant_shift_in : dut3_quant_shift_in);
	assign npu_quant_shift_en = (test_mode == 1'b0 ? dut1_quant_shift_en : dut3_quant_shift_en);
	assign npu_stochastic_round_en = (test_mode == 1'b0 ? dut1_stochastic_round_en : dut3_stochastic_round_en);
	assign npu_psum_A_addr = (test_mode == 1'b0 ? dut1_psum_A_addr : dut3_psum_A_addr);
	assign npu_psum_A_we = (test_mode == 1'b0 ? dut1_psum_A_we : dut3_psum_A_we);
	assign npu_psum_A_wdata = (test_mode == 1'b0 ? dut1_psum_A_wdata : dut3_psum_A_wdata);
	assign npu_psum_A_read_bank_sel = (test_mode == 1'b0 ? dut1_psum_A_read_bank_sel : dut3_psum_A_read_bank_sel);
	assign npu_psum_B_addr = (test_mode == 1'b0 ? dut1_psum_B_addr : dut3_psum_B_addr);
	assign npu_psum_B_we = (test_mode == 1'b0 ? dut1_psum_B_we : dut3_psum_B_we);
	assign npu_psum_B_wdata = (test_mode == 1'b0 ? dut1_psum_B_wdata : dut3_psum_B_wdata);
	assign npu_psum_B_read_bank_sel = (test_mode == 1'b0 ? dut1_psum_B_read_bank_sel : dut3_psum_B_read_bank_sel);
	assign npu_ext_act_sram_we = (test_mode == 1'b0 ? dut1_ext_act_sram_we : dut3_ext_act_sram_we);
	assign npu_ext_act_sram_addr = (test_mode == 1'b0 ? dut1_ext_act_sram_addr : dut3_ext_act_sram_addr);
	assign npu_ext_act_sram_wdata = (test_mode == 1'b0 ? dut1_ext_act_sram_wdata : dut3_ext_act_sram_wdata);
	assign efpga_usr_irq_o = (test_mode == 1'b0 ? dut1_usr_irq : dut3_usr_irq);
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
	function automatic [127:0] get_state_name;
		input [3:0] st;
		case (st)
			4'd0: get_state_name = "IDLE";
			4'd2: get_state_name = "LOAD_QUANT";
			4'd3: get_state_name = "DMA_BIAS";
			4'd4: get_state_name = "DMA_ACT";
			4'd6: get_state_name = "DMA_WEIGHT";
			4'd7: get_state_name = "SWAP_PAUSE";
			4'd8: get_state_name = "COMPUTE_STEP";
			4'd10: get_state_name = "DMA_DRAIN";
			default: get_state_name = "UNKNOWN";
		endcase
	endfunction
	task automatic resolve_mem_dir;
		input string sample_file;
		output string mem_dir;
		reg signed [31:0] fd;
		reg found;
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
				mem_dir = "TEST/NPU/GoldenReference/";
				fd = $fopen({mem_dir, sample_file}, "r");
				if (fd != 0) begin
					$fclose(fd);
					found = 1;
				end
			end
			if (!found) begin
				mem_dir = "TEST/SoftLogic/GoldenReference/";
				fd = $fopen({mem_dir, sample_file}, "r");
				if (fd != 0) begin
					$fclose(fd);
					found = 1;
				end
			end
			if (!found) begin
				$display(" [FATAL ERROR] Required test vector file '%s' was NOT found!", sample_file);
				$display("Fatal [%0t] /mnt/c/Users/Niels/Documents/nct/MyProjects/CrocoScale_SoC/TEST/SoftLogic/minimal/system/tb_npu_minimal_functional.sv:683:13 - tb_npu_minimal_functional.resolve_mem_dir.<unnamed_block>\n msg: ", $time, "Aborting simulation due to missing test vector files.");
				$finish(1);
			end
		end
	endtask
	initial begin
		#(4000000)
			;
		$display("\n[ERROR] Simulation Watchdog Timeout (400,000 cycles reached)!");
		$fflush;
		$finish;
	end
	reg signed [7:0] raw_act_mem [0:24604];
	reg signed [7:0] raw_w_mem [0:3590];
	reg signed [7:0] raw_w_mem_1x1 [0:398];
	reg signed [7:0] act_1x1 [0:15][0:15][0:7];
	reg signed [7:0] w_1x1 [0:7][0:7];
	reg signed [31:0] bias_1x1 [0:7];
	reg signed [31:0] acc_1x1 [0:15][0:15][0:7];
	reg signed [7:0] gold_1x1 [0:15][0:15][0:7];
	reg signed [7:0] act_3x3 [0:17][0:17][0:7];
	reg signed [7:0] w_3x3 [0:2][0:2][0:7][0:7];
	reg signed [31:0] bias_3x3 [0:7];
	reg signed [31:0] acc_3x3 [0:15][0:15][0:7];
	reg signed [7:0] gold_3x3 [0:15][0:15][0:7];
	reg irq_seen;
	always @(posedge clk)
		if (efpga_usr_irq_o[0])
			irq_seen <= 1'b1;
	reg signed [31:0] cyc_busy;
	reg signed [31:0] cyc_quant;
	reg signed [31:0] cyc_bias;
	reg signed [31:0] cyc_act;
	reg signed [31:0] cyc_weight;
	reg signed [31:0] cyc_swap;
	reg signed [31:0] cyc_comp;
	reg signed [31:0] cyc_drain;
	wire [3:0] active_state = (test_mode == 1'b0 ? dut_1x1.state_reg : dut_3x3.state_reg);
	wire active_busy = (test_mode == 1'b0 ? dut_1x1.seq_inst.busy_o : dut_3x3.seq_inst.busy_o);
	always @(posedge clk)
		if (rst_n && active_busy) begin
			cyc_busy = cyc_busy + 1;
			case (active_state)
				4'd2: cyc_quant = cyc_quant + 1;
				4'd3: cyc_bias = cyc_bias + 1;
				4'd4: cyc_act = cyc_act + 1;
				4'd6: cyc_weight = cyc_weight + 1;
				4'd7: cyc_swap = cyc_swap + 1;
				4'd8: cyc_comp = cyc_comp + 1;
				4'd10: cyc_drain = cyc_drain + 1;
				default:
					;
			endcase
		end
	reg signed [31:0] hits_1x1 = 0;
	reg signed [31:0] errors_1x1 = 0;
	reg signed [31:0] cycles_1x1 = 0;
	reg signed [31:0] hits_3x3 = 0;
	reg signed [31:0] errors_3x3 = 0;
	reg signed [31:0] cycles_3x3 = 0;
	initial begin : sv2v_autoblock_1
		string mem_dir;
		reg [31:0] read_status;
		reg signed [63:0] start_t;
		reg signed [31:0] out_addr;
		reg signed [31:0] gy;
		reg signed [31:0] gx;
		reg signed [31:0] p;
		reg signed [7:0] actual_val;
		reg signed [7:0] expect_val;
		$display("\n=====================================================================================");
		$display(">>> Starting Verification of eFPGA NPU Minimal Soft-Logic Controller <<<");
		$display("    Architectural Scope: Compile-Time Dual Mode (KERNEL_SIZE=1 and KERNEL_SIZE=3)");
		$display("    Zero Max-Pooling. Absolute Minimal LUT Footprint. 100%% Bit-Exact Validation.");
		$display("=====================================================================================");
		rst_n = 0;
		test_mode = 0;
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
		$display("\n-------------------------------------------------------------------------------------");
		$display(">>> PHASE 1: Verifying Minimal 1x1 Convolution Controller (dut_1x1) <<<");
		$display("-------------------------------------------------------------------------------------");
		test_mode = 1'b0;
		irq_seen = 1'b0;
		cyc_busy = 0;
		cyc_quant = 0;
		cyc_bias = 0;
		cyc_act = 0;
		cyc_weight = 0;
		cyc_swap = 0;
		cyc_comp = 0;
		cyc_drain = 0;
		resolve_mem_dir("gen_conv1x1_act.mem", mem_dir);
		$display("[1/4] Loading 'gen_conv1x1_act.mem' and 'gen_conv1x1_w.mem' from '%s'...", mem_dir);
		$readmemh({mem_dir, "gen_conv1x1_act.mem"}, raw_act_mem);
		$readmemh({mem_dir, "gen_conv1x1_w.mem"}, raw_w_mem_1x1);
		begin : sv2v_autoblock_2
			reg signed [31:0] y;
			for (y = 0; y < 16; y = y + 1)
				begin : sv2v_autoblock_3
					reg signed [31:0] x;
					for (x = 0; x < 16; x = x + 1)
						begin : sv2v_autoblock_4
							reg signed [31:0] ci;
							for (ci = 0; ci < 8; ci = ci + 1)
								begin
									act_1x1[y][x][ci] = raw_act_mem[(((y * 37) * 19) + (x * 19)) + ci];
									ram_write_byte((ACT_BASE_ADDR + (((y * 16) + x) * 8)) + ci, act_1x1[y][x][ci]);
								end
						end
				end
		end
		begin : sv2v_autoblock_5
			reg signed [31:0] ci;
			for (ci = 0; ci < 8; ci = ci + 1)
				begin : sv2v_autoblock_6
					reg signed [31:0] co;
					for (co = 0; co < 8; co = co + 1)
						w_1x1[ci][co] = raw_w_mem_1x1[(ci * 21) + co];
				end
		end
		begin : sv2v_autoblock_7
			reg signed [31:0] s;
			for (s = 0; s < 8; s = s + 1)
				begin : sv2v_autoblock_8
					reg signed [31:0] ci;
					for (ci = 0; ci < 8; ci = ci + 1)
						ram_write_byte((WEIGHT_BASE_ADDR + (s * 8)) + ci, w_1x1[ci][7 - s]);
				end
		end
		bias_1x1[0] = 32'sd10;
		bias_1x1[1] = -32'sd20;
		bias_1x1[2] = 32'sd15;
		bias_1x1[3] = 32'sd0;
		bias_1x1[4] = -32'sd8;
		bias_1x1[5] = 32'sd25;
		bias_1x1[6] = -32'sd14;
		bias_1x1[7] = 32'sd5;
		begin : sv2v_autoblock_9
			reg signed [31:0] co;
			for (co = 0; co < 8; co = co + 1)
				ram_write_word(BIAS_BASE_ADDR + (co * 4), bias_1x1[co]);
		end
		begin : sv2v_autoblock_10
			reg signed [31:0] oy;
			for (oy = 0; oy < 16; oy = oy + 1)
				begin : sv2v_autoblock_11
					reg signed [31:0] ox;
					for (ox = 0; ox < 16; ox = ox + 1)
						begin : sv2v_autoblock_12
							reg signed [31:0] co;
							for (co = 0; co < 8; co = co + 1)
								begin : sv2v_autoblock_13
									reg signed [31:0] a;
									a = bias_1x1[co];
									begin : sv2v_autoblock_14
										reg signed [31:0] ci;
										for (ci = 0; ci < 8; ci = ci + 1)
											a = a + ($signed(act_1x1[oy][ox][ci]) * $signed(w_1x1[ci][co]));
									end
									acc_1x1[oy][ox][co] = a;
									gold_1x1[oy][ox][co] = requantize(a, 16'sd16384, 14, 8'sd0);
								end
						end
				end
		end
		$display("      1x1 Tile memory prepared in AXI RAM. Golden outputs calculated.");
		$display("[2/4] Programming Registers via AXI-Lite MMIO...");
		axil_write(32'h00000008, ACT_BASE_ADDR);
		axil_write(32'h0000000c, WEIGHT_BASE_ADDR);
		axil_write(32'h00000010, OUT_BASE_ADDR);
		axil_write(32'h00000014, BIAS_BASE_ADDR);
		axil_write(32'h00000018, 32'h000e4000);
		axil_write(32'h0000001c, 32'h00000001);
		$display("[3/4] Triggering 1x1 Execution (REG_CTRL[0]=1)...");
		start_t = $time;
		axil_write(32'h00000000, 32'h00000001);
		read_status = 32'h00000000;
		while (!read_status[1]) begin
			#(100)
				;
			axil_read(32'h00000004, read_status);
		end
		cycles_1x1 = ($time - start_t) / 10;
		$display("      1x1 Execution finished in %0d clock cycles!", cycles_1x1);
		if (!irq_seen) begin
			$display("[FAIL] efpga_usr_irq_o[0] did not pulse for 1x1!");
			errors_1x1 = errors_1x1 + 1;
		end
		else
			$display("      [OK] Interrupt line pulsed correctly.");
		$display("[4/4] Verifying 2048 Activations against Golden Model...");
		begin : sv2v_autoblock_15
			reg signed [31:0] oy;
			for (oy = 0; oy < 16; oy = oy + 1)
				begin : sv2v_autoblock_16
					reg signed [31:0] ox;
					for (ox = 0; ox < 16; ox = ox + 1)
						begin : sv2v_autoblock_17
							reg signed [31:0] co;
							for (co = 0; co < 8; co = co + 1)
								begin
									out_addr = (OUT_BASE_ADDR + (((oy * 16) + ox) * 8)) + co;
									ram_read_byte(out_addr, actual_val);
									expect_val = gold_1x1[oy][ox][co];
									if (actual_val === expect_val)
										hits_1x1 = hits_1x1 + 1;
									else begin
										if (errors_1x1 < 10)
											$display("      [MISMATCH 1x1] (%0d,%0d,ch%0d) Addr 0x%04X | Act: %0d | Exp: %0d | Acc: %0d", oy, ox, co, out_addr, actual_val, expect_val, acc_1x1[oy][ox][co]);
										errors_1x1 = errors_1x1 + 1;
									end
								end
						end
				end
		end
		if (errors_1x1 == 0) begin
			$display(">>> PHASE 1 PASSED: 100%% Bit-Exact Match for 1x1 Conv! (Hits: 2048 / 2048) <<<");
			$display("    Execution Latency: %0d cycles | Throughput: %0.2f MACs/cycle", cycles_1x1, (2048 * 8.0) / cycles_1x1);
		end
		else
			$display(">>> PHASE 1 FAILED: %0d Mismatches Encountered! <<<", errors_1x1);
		$display("\n  1x1 Cycle Breakdown (Total Busy = %0d cycles):", cyc_busy);
		$display("    Quant Config:  %5d cycles (%5.2f%%)", cyc_quant, (cyc_quant * 100.0) / cyc_busy);
		$display("    Bias Preload:  %5d cycles (%5.2f%%)", cyc_bias, (cyc_bias * 100.0) / cyc_busy);
		$display("    Act Fetch:     %5d cycles (%5.2f%%)", cyc_act, (cyc_act * 100.0) / cyc_busy);
		$display("    Weight Fetch:  %5d cycles (%5.2f%%)", cyc_weight, (cyc_weight * 100.0) / cyc_busy);
		$display("    Compute:       %5d cycles (%5.2f%%)", cyc_comp, (cyc_comp * 100.0) / cyc_busy);
		$display("    Output Drain:  %5d cycles (%5.2f%%)", cyc_drain, (cyc_drain * 100.0) / cyc_busy);
		#(100)
			;
		rst_n = 0;
		#(50)
			;
		@(negedge clk)
			;
		rst_n = 1;
		#(50)
			;
		$display("\n-------------------------------------------------------------------------------------");
		$display(">>> PHASE 2: Verifying Minimal 3x3 Halo Convolution Controller (dut_3x3) <<<");
		$display("-------------------------------------------------------------------------------------");
		test_mode = 1'b1;
		irq_seen = 1'b0;
		cyc_busy = 0;
		cyc_quant = 0;
		cyc_bias = 0;
		cyc_act = 0;
		cyc_weight = 0;
		cyc_swap = 0;
		cyc_comp = 0;
		cyc_drain = 0;
		resolve_mem_dir("gen_conv3x3_halo_act.mem", mem_dir);
		$display("[1/4] Loading 'gen_conv3x3_halo_act.mem' and 'gen_conv3x3_halo_w.mem' from '%s'...", mem_dir);
		$readmemh({mem_dir, "gen_conv3x3_halo_act.mem"}, raw_act_mem);
		$readmemh({mem_dir, "gen_conv3x3_halo_w.mem"}, raw_w_mem);
		begin : sv2v_autoblock_18
			reg signed [31:0] y;
			for (y = 0; y < 18; y = y + 1)
				begin : sv2v_autoblock_19
					reg signed [31:0] x;
					for (x = 0; x < 18; x = x + 1)
						begin
							gy = y - 1;
							gx = x - 1;
							begin : sv2v_autoblock_20
								reg signed [31:0] ci;
								for (ci = 0; ci < 8; ci = ci + 1)
									begin
										if (((((gy >= 0) && (gy < 35)) && (gx >= 0)) && (gx < 37)) && (ci < 19))
											act_3x3[y][x][ci] = raw_act_mem[(((gy * 37) * 19) + (gx * 19)) + ci];
										else
											act_3x3[y][x][ci] = 8'sd0;
										ram_write_byte((ACT_BASE_ADDR + (((y * 18) + x) * 8)) + ci, act_3x3[y][x][ci]);
									end
							end
						end
				end
		end
		begin : sv2v_autoblock_21
			reg signed [31:0] ky;
			for (ky = 0; ky < 3; ky = ky + 1)
				begin : sv2v_autoblock_22
					reg signed [31:0] kx;
					for (kx = 0; kx < 3; kx = kx + 1)
						begin
							p = (ky * 3) + kx;
							begin : sv2v_autoblock_23
								reg signed [31:0] ci;
								for (ci = 0; ci < 8; ci = ci + 1)
									begin : sv2v_autoblock_24
										reg signed [31:0] co;
										for (co = 0; co < 8; co = co + 1)
											if ((ci < 19) && (co < 21))
												w_3x3[ky][kx][ci][co] = raw_w_mem[(((((ky * 3) * 19) * 21) + ((kx * 19) * 21)) + (ci * 21)) + co];
											else
												w_3x3[ky][kx][ci][co] = 8'sd0;
									end
							end
							begin : sv2v_autoblock_25
								reg signed [31:0] s;
								for (s = 0; s < 8; s = s + 1)
									begin : sv2v_autoblock_26
										reg signed [31:0] ci;
										for (ci = 0; ci < 8; ci = ci + 1)
											ram_write_byte(((WEIGHT_BASE_ADDR + (p * 64)) + (s * 8)) + ci, w_3x3[ky][kx][ci][7 - s]);
									end
							end
						end
				end
		end
		bias_3x3[0] = 32'sd25;
		bias_3x3[1] = -32'sd40;
		bias_3x3[2] = 32'sd15;
		bias_3x3[3] = 32'sd0;
		bias_3x3[4] = -32'sd12;
		bias_3x3[5] = 32'sd60;
		bias_3x3[6] = -32'sd33;
		bias_3x3[7] = 32'sd8;
		begin : sv2v_autoblock_27
			reg signed [31:0] co;
			for (co = 0; co < 8; co = co + 1)
				ram_write_word(BIAS_BASE_ADDR + (co * 4), bias_3x3[co]);
		end
		begin : sv2v_autoblock_28
			reg signed [31:0] oy;
			for (oy = 0; oy < 16; oy = oy + 1)
				begin : sv2v_autoblock_29
					reg signed [31:0] ox;
					for (ox = 0; ox < 16; ox = ox + 1)
						begin : sv2v_autoblock_30
							reg signed [31:0] co;
							for (co = 0; co < 8; co = co + 1)
								begin : sv2v_autoblock_31
									reg signed [31:0] a;
									a = bias_3x3[co];
									begin : sv2v_autoblock_32
										reg signed [31:0] ky;
										for (ky = 0; ky < 3; ky = ky + 1)
											begin : sv2v_autoblock_33
												reg signed [31:0] kx;
												for (kx = 0; kx < 3; kx = kx + 1)
													begin : sv2v_autoblock_34
														reg signed [31:0] ci;
														for (ci = 0; ci < 8; ci = ci + 1)
															a = a + ($signed(act_3x3[oy + ky][ox + kx][ci]) * $signed(w_3x3[ky][kx][ci][co]));
													end
											end
									end
									acc_3x3[oy][ox][co] = a;
									gold_3x3[oy][ox][co] = requantize(a, 16'sd16384, 15, 8'sd0);
								end
						end
				end
		end
		$display("      3x3 Halo Tile memory prepared in AXI RAM. Golden outputs calculated.");
		$display("[2/4] Programming Registers via AXI-Lite MMIO...");
		axil_write(32'h00000008, ACT_BASE_ADDR);
		axil_write(32'h0000000c, WEIGHT_BASE_ADDR);
		axil_write(32'h00000010, OUT_BASE_ADDR);
		axil_write(32'h00000014, BIAS_BASE_ADDR);
		axil_write(32'h00000018, 32'h000f4000);
		axil_write(32'h0000001c, 32'h00000001);
		$display("[3/4] Triggering 3x3 Execution (REG_CTRL[0]=1)...");
		start_t = $time;
		axil_write(32'h00000000, 32'h00000001);
		read_status = 32'h00000000;
		while (!read_status[1]) begin
			#(100)
				;
			axil_read(32'h00000004, read_status);
		end
		cycles_3x3 = ($time - start_t) / 10;
		$display("      3x3 Execution finished in %0d clock cycles!", cycles_3x3);
		if (!irq_seen) begin
			$display("[FAIL] efpga_usr_irq_o[0] did not pulse for 3x3!");
			errors_3x3 = errors_3x3 + 1;
		end
		else
			$display("      [OK] Interrupt line pulsed correctly.");
		$display("[4/4] Verifying 2048 Activations against Golden Model...");
		begin : sv2v_autoblock_35
			reg signed [31:0] oy;
			for (oy = 0; oy < 16; oy = oy + 1)
				begin : sv2v_autoblock_36
					reg signed [31:0] ox;
					for (ox = 0; ox < 16; ox = ox + 1)
						begin : sv2v_autoblock_37
							reg signed [31:0] co;
							for (co = 0; co < 8; co = co + 1)
								begin
									out_addr = (OUT_BASE_ADDR + (((oy * 16) + ox) * 8)) + co;
									ram_read_byte(out_addr, actual_val);
									expect_val = gold_3x3[oy][ox][co];
									if (actual_val === expect_val)
										hits_3x3 = hits_3x3 + 1;
									else begin
										if (errors_3x3 < 10)
											$display("      [MISMATCH 3x3] (%0d,%0d,ch%0d) Addr 0x%04X | Act: %0d | Exp: %0d | Acc: %0d", oy, ox, co, out_addr, actual_val, expect_val, acc_3x3[oy][ox][co]);
										errors_3x3 = errors_3x3 + 1;
									end
								end
						end
				end
		end
		if (errors_3x3 == 0) begin
			$display(">>> PHASE 2 PASSED: 100%% Bit-Exact Match for 3x3 Conv! (Hits: 2048 / 2048) <<<");
			$display("    Execution Latency: %0d cycles | Throughput: %0.2f MACs/cycle", cycles_3x3, (18432 * 8.0) / cycles_3x3);
		end
		else
			$display(">>> PHASE 2 FAILED: %0d Mismatches Encountered! <<<", errors_3x3);
		$display("\n  3x3 Cycle Breakdown (Total Busy = %0d cycles):", cyc_busy);
		$display("    Quant Config:  %5d cycles (%5.2f%%)", cyc_quant, (cyc_quant * 100.0) / cyc_busy);
		$display("    Bias Preload:  %5d cycles (%5.2f%%)", cyc_bias, (cyc_bias * 100.0) / cyc_busy);
		$display("    Act Fetch:     %5d cycles (%5.2f%%)", cyc_act, (cyc_act * 100.0) / cyc_busy);
		$display("    Weight Fetch:  %5d cycles (%5.2f%%)", cyc_weight, (cyc_weight * 100.0) / cyc_busy);
		$display("    Swap Pauses:   %5d cycles (%5.2f%%)", cyc_swap, (cyc_swap * 100.0) / cyc_busy);
		$display("    Compute:       %5d cycles (%5.2f%%)", cyc_comp, (cyc_comp * 100.0) / cyc_busy);
		$display("    Output Drain:  %5d cycles (%5.2f%%)", cyc_drain, (cyc_drain * 100.0) / cyc_busy);
		$display("\n=========================================================================================================");
		$display(">>> DUAL-MODE MINIMAL CONTROLLER VERIFICATION SUMMARY <<<");
		$display("=========================================================================================================");
		$display("  Mode        | Status | Bit-Exact Hits  | Clock Cycles | Throughput (MACs/cyc) | Efficiency");
		$display("  ------------+--------+-----------------+--------------+-----------------------+-----------");
		$display("  1x1 Conv    | %-6s | %4d / %4d (%5.1f%%) | %12d | %21.2f | %9.2f%%", (errors_1x1 == 0 ? "PASS" : "FAIL"), hits_1x1, hits_1x1 + errors_1x1, (hits_1x1 * 100.0) / (hits_1x1 + errors_1x1), cycles_1x1, (2048 * 8.0) / cycles_1x1, (((2048 * 8.0) / cycles_1x1) / 64.0) * 100.0);
		$display("  3x3 Conv    | %-6s | %4d / %4d (%5.1f%%) | %12d | %21.2f | %9.2f%%", (errors_3x3 == 0 ? "PASS" : "FAIL"), hits_3x3, hits_3x3 + errors_3x3, (hits_3x3 * 100.0) / (hits_3x3 + errors_3x3), cycles_3x3, (18432 * 8.0) / cycles_3x3, (((18432 * 8.0) / cycles_3x3) / 64.0) * 100.0);
		$display("=========================================================================================================\n");
		if ((errors_1x1 == 0) && (errors_3x3 == 0))
			$display(">>> ALL DUAL-MODE MINIMAL TESTS PASSED SUCCESSFULLY! <<<\n");
		else begin
			$display("Fatal [%0t] /mnt/c/Users/Niels/Documents/nct/MyProjects/CrocoScale_SoC/TEST/SoftLogic/minimal/system/tb_npu_minimal_functional.sv:1095:13 - tb_npu_minimal_functional.<unnamed_block>.<unnamed_block>\n msg: ", $time, "Verification failed with errors!");
			$finish(1);
		end
		#(100)
			;
		$finish;
	end
endmodule
