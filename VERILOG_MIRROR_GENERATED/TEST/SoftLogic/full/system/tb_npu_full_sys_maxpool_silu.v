module tb_npu_full_sys_maxpool_silu;
	reg _sv2v_0;
	parameter signed [31:0] ARRAY_HEIGHT = 8;
	parameter signed [31:0] ARRAY_WIDTH = 8;
	parameter signed [31:0] TILE_SIZE = 16;
	parameter signed [31:0] ACT_HALO_PAD = 2;
	parameter signed [31:0] ACTIVATION_WIDTH = 8;
	parameter signed [31:0] WEIGHT_WIDTH = 8;
	parameter signed [31:0] PSUM_WIDTH = 32;
	parameter signed [31:0] SCALE_WIDTH = 16;
	parameter signed [31:0] WEIGHT_SPLIT = 2;
	parameter signed [31:0] AXI_ADDR_WIDTH = 32;
	parameter signed [31:0] AXI_DATA_WIDTH = 32;
	parameter signed [31:0] TOTAL_PASSES = 144;
	parameter signed [31:0] CIN = 128;
	parameter signed [31:0] COUT = 32;
	localparam signed [31:0] CONV_H = 48;
	localparam signed [31:0] CONV_W = 48;
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
	wire m_axi_arvalid;
	wire m_axi_arready;
	wire [AXI_DATA_WIDTH - 1:0] m_axi_rdata;
	wire [1:0] m_axi_rresp;
	wire m_axi_rlast;
	wire m_axi_rvalid;
	wire m_axi_rready;
	wire npu_array_en;
	wire npu_psum_systolic_en;
	wire npu_psum_lut_en;
	wire npu_psum_skew_en;
	wire npu_compute_bank_swap;
	wire [(ARRAY_HEIGHT * 4) - 1:0] npu_crossbar_sel;
	wire signed [(ARRAY_HEIGHT * WEIGHT_WIDTH) - 1:0] npu_weight_shift_in;
	wire [WEIGHT_SPLIT - 1:0] npu_weight_shift_en;
	wire npu_swap_weights;
	wire [29:0] npu_quant_shift_in;
	wire npu_quant_shift_en;
	wire npu_stochastic_round_en;
	wire [7:0] npu_psum_A_addr;
	wire [ARRAY_WIDTH - 1:0] npu_psum_A_we;
	wire signed [PSUM_WIDTH - 1:0] npu_psum_A_wdata;
	wire [2:0] npu_psum_A_read_bank_sel;
	wire signed [PSUM_WIDTH - 1:0] npu_psum_A_rdata;
	wire [7:0] npu_psum_B_addr;
	wire [ARRAY_WIDTH - 1:0] npu_psum_B_we;
	wire signed [PSUM_WIDTH - 1:0] npu_psum_B_wdata;
	wire [2:0] npu_psum_B_read_bank_sel;
	wire signed [PSUM_WIDTH - 1:0] npu_psum_B_rdata;
	wire [ARRAY_HEIGHT - 1:0] npu_ext_act_sram_we;
	wire [(ARRAY_HEIGHT * 9) - 1:0] npu_ext_act_sram_addr;
	reg signed [(ARRAY_HEIGHT * ACTIVATION_WIDTH) - 1:0] npu_ext_act_sram_wdata;
	wire signed [(ARRAY_HEIGHT * ACTIVATION_WIDTH) - 1:0] npu_act_sram_rdata;
	wire signed [(ARRAY_WIDTH * ACTIVATION_WIDTH) - 1:0] npu_out_act;
	wire [3:0] efpga_usr_irq_o;
	wire [SCALE_WIDTH - 1:0] lfsr_data_out;
	initial clk = 0;
	always #(5) clk = ~clk;
	localparam signed [31:0] MEM_ADDR_WIDTH = 16;
	localparam [31:0] ACT_BASE_ADDR = 32'h00001000;
	localparam [31:0] WEIGHT_BASE_ADDR = 32'h00006000;
	localparam [31:0] BIAS_BASE_ADDR = 32'h00009000;
	localparam [31:0] QUANT_BASE_ADDR = 32'h00009800;
	localparam [31:0] OUT_BASE_ADDR = 32'h0000a000;
	localparam [31:0] LUT_BASE_ADDR = 32'h0000b000;
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
		.s_axi_rid(),
		.s_axi_rdata(m_axi_rdata),
		.s_axi_rresp(m_axi_rresp),
		.s_axi_rlast(m_axi_rlast),
		.s_axi_rvalid(m_axi_rvalid),
		.s_axi_rready(m_axi_rready)
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
		.ENABLE_LFSR(0),
		.WEIGHT_SPLIT(WEIGHT_SPLIT)
	) npu_core_inst(
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
		.stochastic_round_en(1'b0),
		.lfsr_data_out(lfsr_data_out),
		.psum_skew_en(npu_psum_skew_en),
		.compute_bank_swap(npu_compute_bank_swap),
		.psum_A_addr(npu_psum_A_addr),
		.psum_A_we(npu_psum_A_we),
		.psum_A_wdata(npu_psum_A_wdata),
		.psum_A_read_bank_sel(3'd0),
		.psum_A_rdata(npu_psum_A_rdata),
		.psum_B_addr(npu_psum_B_addr),
		.psum_B_we(npu_psum_B_we),
		.psum_B_wdata(npu_psum_B_wdata),
		.psum_B_read_bank_sel(3'd0),
		.psum_B_rdata(npu_psum_B_rdata),
		.ext_act_sram_we(npu_ext_act_sram_we),
		.ext_act_sram_addr(npu_ext_act_sram_addr),
		.ext_act_sram_wdata(npu_ext_act_sram_wdata),
		.act_sram_rdata(npu_act_sram_rdata),
		.out_act(npu_out_act)
	);
	npu_full_controller #(
		.ARRAY_HEIGHT(ARRAY_HEIGHT),
		.ARRAY_WIDTH(ARRAY_WIDTH),
		.TILE_SIZE(TILE_SIZE),
		.ACT_HALO_PAD(ACT_HALO_PAD),
		.ACTIVATION_WIDTH(ACTIVATION_WIDTH),
		.WEIGHT_WIDTH(WEIGHT_WIDTH),
		.PSUM_WIDTH(PSUM_WIDTH),
		.SCALE_WIDTH(SCALE_WIDTH),
		.WEIGHT_SPLIT(WEIGHT_SPLIT),
		.AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
		.AXI_DATA_WIDTH(AXI_DATA_WIDTH),
		.TOTAL_PASSES(TOTAL_PASSES),
		.CIN(CIN),
		.COUT(COUT)
	) dut(
		.clk_i(clk),
		.rst_n(rst_n),
		.s_axil_awaddr(s_axil_awaddr),
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
		.s_axil_araddr(s_axil_araddr),
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
		.m_axi_arvalid(m_axi_arvalid),
		.m_axi_arready(m_axi_arready),
		.m_axi_rdata(m_axi_rdata),
		.m_axi_rresp(m_axi_rresp),
		.m_axi_rlast(m_axi_rlast),
		.m_axi_rvalid(m_axi_rvalid),
		.m_axi_rready(m_axi_rready),
		.npu_array_en(npu_array_en),
		.npu_psum_systolic_en(npu_psum_systolic_en),
		.npu_psum_lut_en(npu_psum_lut_en),
		.npu_psum_skew_en(npu_psum_skew_en),
		.npu_compute_bank_swap(npu_compute_bank_swap),
		.npu_crossbar_sel(npu_crossbar_sel),
		.npu_weight_shift_in(npu_weight_shift_in),
		.npu_weight_shift_en(npu_weight_shift_en),
		.npu_swap_weights(npu_swap_weights),
		.npu_quant_shift_in(npu_quant_shift_in),
		.npu_quant_shift_en(npu_quant_shift_en),
		.npu_stochastic_round_en(npu_stochastic_round_en),
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
		.npu_ext_act_sram_we(npu_ext_act_sram_we),
		.npu_ext_act_sram_addr(npu_ext_act_sram_addr),
		.npu_out_act(npu_out_act),
		.efpga_usr_irq_o(efpga_usr_irq_o)
	);
	reg signed [ACTIVATION_WIDTH - 1:0] fmap_in [0:((CONV_H * CONV_W) * CIN) - 1];
	reg signed [WEIGHT_WIDTH - 1:0] w1_flat [0:((9 * CIN) * COUT) - 1];
	reg signed [31:0] b1_flat [0:COUT - 1];
	reg [31:0] p1_cfg [0:COUT - 1];
	reg signed [ACTIVATION_WIDTH - 1:0] gold_l1 [0:((CONV_H * CONV_W) * COUT) - 1];
	reg signed [ACTIVATION_WIDTH - 1:0] conv1x1_act [0:24604];
	reg signed [WEIGHT_WIDTH - 1:0] conv1x1_w [0:398];
	reg signed [ACTIVATION_WIDTH - 1:0] conv1x1_gold [0:27194];
	reg [7:0] lut_silu_mem [0:255];
	reg signed [ACTIVATION_WIDTH - 1:0] phase2_out [0:255][0:7];
	task automatic ram_write_word;
		input [31:0] addr;
		input [31:0] data;
		axi_ram_inst.mem[addr[15:2]] = data;
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
	function automatic signed [7:0] get_fmap_val;
		input reg signed [31:0] c_idx;
		input reg signed [31:0] b_idx;
		input reg signed [31:0] i_idx;
		input reg signed [31:0] ty_idx;
		input reg signed [31:0] tx_idx;
		reg signed [31:0] ly_val;
		reg signed [31:0] lx_val;
		reg signed [31:0] gy_val;
		reg signed [31:0] gx_val;
		begin
			ly_val = (b_idx / 2) + ((i_idx / 9) * 3);
			lx_val = ((b_idx % 2) == 1 ? 9 : 0) + (i_idx % 9);
			gy_val = ((ty_idx * 16) + ly_val) - 1;
			gx_val = ((tx_idx * 16) + lx_val) - 1;
			if (((((gy_val >= 0) && (gy_val < CONV_H)) && (gx_val >= 0)) && (gx_val < CONV_W)) && (c_idx < CIN))
				get_fmap_val = fmap_in[(((gy_val * CONV_W) * CIN) + (gx_val * CIN)) + c_idx];
			else
				get_fmap_val = 8'sd0;
		end
	endfunction
	function automatic signed [7:0] get_weight_val;
		input reg signed [31:0] p;
		input reg signed [31:0] cout_b;
		input reg signed [31:0] r;
		input reg signed [31:0] c;
		reg signed [31:0] g_idx;
		reg signed [31:0] cin_curr;
		reg signed [31:0] tap_curr;
		reg signed [31:0] ky_curr;
		reg signed [31:0] kx_curr;
		reg signed [31:0] ch_out;
		begin
			g_idx = (p * 8) + r;
			if (g_idx < (CIN * 9)) begin
				cin_curr = g_idx / 9;
				tap_curr = g_idx % 9;
				ky_curr = tap_curr / 3;
				kx_curr = tap_curr % 3;
				ch_out = (cout_b * 8) + c;
				if (ch_out < COUT)
					get_weight_val = w1_flat[(((((ky_curr * 3) * CIN) * COUT) + ((kx_curr * CIN) * COUT)) + (cin_curr * COUT)) + ch_out];
				else
					get_weight_val = 8'sd0;
			end
			else
				get_weight_val = 8'sd0;
		end
	endfunction
	reg signed [31:0] feeder_p_idx;
	reg signed [31:0] feeder_y_idx;
	reg signed [31:0] feeder_x_idx;
	reg signed [31:0] feeder_next_ch_base;
	function automatic signed [31:0] sv2v_cast_32_signed;
		input reg signed [31:0] inp;
		sv2v_cast_32_signed = inp;
	endfunction
	always @(negedge clk)
		if (!rst_n)
			npu_ext_act_sram_wdata <= 1'sb0;
		else if (dut.config_reg[4] == 1'b0) begin
			if (dut.preload_phase) begin
				begin : sv2v_autoblock_1
					reg signed [31:0] b;
					for (b = 0; b < 6; b = b + 1)
						npu_ext_act_sram_wdata[b * ACTIVATION_WIDTH+:ACTIVATION_WIDTH] <= get_fmap_val(0, b, sv2v_cast_32_signed(dut.preload_step), 0, 0);
				end
				npu_ext_act_sram_wdata[6 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH] <= 1'sb0;
				npu_ext_act_sram_wdata[7 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH] <= 1'sb0;
			end
			else if (dut.dma_channel_to_load >= 0) begin
				begin : sv2v_autoblock_2
					reg signed [31:0] b;
					for (b = 0; b < 6; b = b + 1)
						npu_ext_act_sram_wdata[b * ACTIVATION_WIDTH+:ACTIVATION_WIDTH] <= get_fmap_val(sv2v_cast_32_signed(dut.dma_channel_to_load), b, sv2v_cast_32_signed(dut.dma_bank_ptr[b]), 0, 0);
				end
				npu_ext_act_sram_wdata[6 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH] <= 1'sb0;
				npu_ext_act_sram_wdata[7 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH] <= 1'sb0;
			end
		end
		else if (dut.preload_phase) begin
			feeder_p_idx = sv2v_cast_32_signed(dut.preload_step);
			feeder_y_idx = feeder_p_idx / 16;
			feeder_x_idx = feeder_p_idx % 16;
			begin : sv2v_autoblock_3
				reg signed [31:0] b;
				for (b = 0; b < 4; b = b + 1)
					if (((feeder_y_idx < 35) && (feeder_x_idx < 37)) && (b < 19))
						npu_ext_act_sram_wdata[b * ACTIVATION_WIDTH+:ACTIVATION_WIDTH] <= conv1x1_act[(((feeder_y_idx * 37) * 19) + (feeder_x_idx * 19)) + b];
					else
						npu_ext_act_sram_wdata[b * ACTIVATION_WIDTH+:ACTIVATION_WIDTH] <= 8'sd0;
			end
			begin : sv2v_autoblock_4
				reg signed [31:0] b;
				for (b = 4; b < 8; b = b + 1)
					npu_ext_act_sram_wdata[b * ACTIVATION_WIDTH+:ACTIVATION_WIDTH] <= 8'sd0;
			end
		end
		else if (dut.sequencer_inst.addr_1x1_inst.act_sram_we_o != 8'h00) begin
			feeder_p_idx = sv2v_cast_32_signed(dut.cycle_in_pass);
			feeder_y_idx = feeder_p_idx / 16;
			feeder_x_idx = feeder_p_idx % 16;
			feeder_next_ch_base = (dut.current_pass + 1) * 4;
			if (dut.current_pass[0] == 1'b0) begin : sv2v_autoblock_5
				reg signed [31:0] b;
				for (b = 0; b < 4; b = b + 1)
					begin : sv2v_autoblock_6
						reg signed [31:0] ch;
						ch = feeder_next_ch_base + b;
						if ((((feeder_p_idx < 256) && (feeder_y_idx < 35)) && (feeder_x_idx < 37)) && (ch < 19))
							npu_ext_act_sram_wdata[(b + 4) * ACTIVATION_WIDTH+:ACTIVATION_WIDTH] <= conv1x1_act[(((feeder_y_idx * 37) * 19) + (feeder_x_idx * 19)) + ch];
						else
							npu_ext_act_sram_wdata[(b + 4) * ACTIVATION_WIDTH+:ACTIVATION_WIDTH] <= 8'sd0;
					end
			end
			else begin : sv2v_autoblock_7
				reg signed [31:0] b;
				for (b = 0; b < 4; b = b + 1)
					begin : sv2v_autoblock_8
						reg signed [31:0] ch;
						ch = feeder_next_ch_base + b;
						if ((((feeder_p_idx < 256) && (feeder_y_idx < 35)) && (feeder_x_idx < 37)) && (ch < 19))
							npu_ext_act_sram_wdata[b * ACTIVATION_WIDTH+:ACTIVATION_WIDTH] <= conv1x1_act[(((feeder_y_idx * 37) * 19) + (feeder_x_idx * 19)) + ch];
						else
							npu_ext_act_sram_wdata[b * ACTIVATION_WIDTH+:ACTIVATION_WIDTH] <= 8'sd0;
					end
			end
		end
	initial begin
		#(800000)
			;
		$display("\n[ERROR] Simulation Watchdog Timeout (80,000 cycles)!");
		$display("DUT FSM state=%0d pass=%0d k=%0d lut_phase=%0b lut_load_done=%0b", dut.sequencer_inst.state, dut.current_pass, dut.cycle_in_pass, dut.seq_lut_phase, dut.dma_lut_load_done);
		$display("DMA state: preload_active=%0b lut_active=%0b", dut.dma_inst.preload_active_reg, dut.dma_inst.lut_active_reg);
		$display("LUT loader state=%0d beat_cnt=%0d burst_idx=%0d", dut.dma_inst.lut_loader_inst.state, dut.dma_inst.lut_loader_inst.beat_cnt, dut.dma_inst.lut_loader_inst.burst_idx);
		$display("AXI read master state=%0d arvalid=%0b arready=%0b rvalid=%0b rready=%0b", dut.dma_inst.axi_read_master_inst.state, dut.dma_inst.axi_read_master_inst.m_axi_arvalid, dut.m_axi_arready, dut.m_axi_rvalid, dut.dma_inst.axi_read_master_inst.m_axi_rready);
		$finish;
	end
	initial begin : sv2v_autoblock_9
		reg signed [63:0] start_time;
		reg signed [63:0] total_cycles;
		reg signed [63:0] ideal_macs;
		reg signed [63:0] ideal_cycles;
		real compute_eff;
		real e2e_eff;
		reg signed [31:0] errs;
		reg signed [31:0] tol_ok;
		reg signed [31:0] exact_ok;
		reg signed [31:0] lut_errs;
		reg signed [31:0] tol_5;
		reg signed [31:0] max_diff;
		reg signed [31:0] pool_errs_lin;
		reg signed [31:0] pool_errs_silu;
		reg [31:0] read_status;
		reg signed [31:0] p_idx;
		reg signed [31:0] y_idx;
		reg signed [31:0] x_idx;
		reg signed [31:0] ch_idx;
		reg signed [31:0] flat_idx;
		reg signed [31:0] diff_val;
		reg signed [31:0] py_idx;
		reg signed [31:0] px_idx;
		reg signed [31:0] p_out_idx;
		reg signed [7:0] q0;
		reg signed [7:0] q1;
		reg signed [7:0] q2;
		reg signed [7:0] q3;
		reg signed [7:0] m01;
		reg signed [7:0] m23;
		reg [31:0] word0;
		reg [31:0] word1;
		reg signed [7:0] ram_pix [0:7];
		reg signed [7:0] gold_val;
		reg signed [7:0] act_val;
		reg signed [7:0] w_val0;
		reg signed [7:0] w_val1;
		reg signed [7:0] w_val2;
		reg signed [7:0] w_val3;
		reg [7:0] lut_idx_val;
		reg [7:0] u_q0;
		reg [7:0] u_q1;
		reg [7:0] u_q2;
		reg [7:0] u_q3;
		$display("\n=========================================================================================");
		$display(">>> Starting Unified Dual-Mode System Verification (3x3, 1x1, & SiLU LUT over AXI) <<<");
		$display("=========================================================================================");
		$readmemh("TEST/NPU/GoldenReference/bench_im2col_act.mem", fmap_in);
		$readmemh("TEST/NPU/GoldenReference/bench_im2col_w.mem", w1_flat);
		$readmemh("TEST/NPU/GoldenReference/bench_im2col_b.mem", b1_flat);
		$readmemh("TEST/NPU/GoldenReference/bench_im2col_cfg.mem", p1_cfg);
		$readmemh("TEST/NPU/GoldenReference/bench_im2col_out_quant.mem", gold_l1);
		$readmemh("TEST/NPU/GoldenReference/gen_conv1x1_act.mem", conv1x1_act);
		$readmemh("TEST/NPU/GoldenReference/gen_conv1x1_w.mem", conv1x1_w);
		$readmemh("TEST/NPU/GoldenReference/gen_conv1x1_out_quant.mem", conv1x1_gold);
		$readmemh("TEST/NPU/GoldenReference/gen_lut_silu.mem", lut_silu_mem);
		$display("Reference test vectors loaded successfully.");
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
		$display("\n-----------------------------------------------------------------------------------------");
		$display(">>> PHASE 2: Simple 1x1 Functional Test (3 Passes = 12 Channels, Half-Array Ping-Pong) <<<");
		$display("-----------------------------------------------------------------------------------------");
		begin : sv2v_autoblock_10
			reg signed [31:0] ch;
			for (ch = 0; ch < 8; ch = ch + 1)
				ram_write_word(BIAS_BASE_ADDR + (ch * 4), 32'sd0);
		end
		begin : sv2v_autoblock_11
			reg signed [31:0] ch;
			for (ch = 0; ch < 8; ch = ch + 1)
				ram_write_word(QUANT_BASE_ADDR + (ch * 4), 32'h000e4000);
		end
		begin : sv2v_autoblock_12
			reg signed [31:0] p;
			for (p = 0; p < 3; p = p + 1)
				begin : sv2v_autoblock_13
					reg signed [31:0] s;
					for (s = 0; s < 8; s = s + 1)
						begin : sv2v_autoblock_14
							reg signed [31:0] c_out;
							c_out = 7 - s;
							w_val0 = ((((p * 4) + 0) < 19) && (c_out < 21) ? conv1x1_w[(((p * 4) + 0) * 21) + c_out] : 8'sd0);
							w_val1 = ((((p * 4) + 1) < 19) && (c_out < 21) ? conv1x1_w[(((p * 4) + 1) * 21) + c_out] : 8'sd0);
							w_val2 = ((((p * 4) + 2) < 19) && (c_out < 21) ? conv1x1_w[(((p * 4) + 2) * 21) + c_out] : 8'sd0);
							w_val3 = ((((p * 4) + 3) < 19) && (c_out < 21) ? conv1x1_w[(((p * 4) + 3) * 21) + c_out] : 8'sd0);
							ram_write_word((WEIGHT_BASE_ADDR + (p * 32)) + (s * 4), {w_val3, w_val2, w_val1, w_val0});
						end
				end
		end
		axil_write(32'h00000008, 32'h00000311);
		axil_write(32'h00000010, ACT_BASE_ADDR);
		axil_write(32'h00000014, WEIGHT_BASE_ADDR);
		axil_write(32'h00000018, OUT_BASE_ADDR);
		axil_write(32'h0000001c, BIAS_BASE_ADDR);
		axil_write(32'h00000020, QUANT_BASE_ADDR);
		axil_write(32'h00000024, LUT_BASE_ADDR);
		start_time = $time;
		axil_write(32'h00000000, 32'h00000001);
		read_status = 32'h00000000;
		while (!read_status[1]) begin
			#(100)
				;
			axil_read(32'h00000004, read_status);
		end
		total_cycles = ($time - start_time) / 10;
		$display(">>> Phase 2 (Simple 1x1 Half-Array) Finished in %0d cycles! Status: OK <<<", total_cycles);
		for (p_idx = 0; p_idx < 256; p_idx = p_idx + 1)
			begin
				word0 = axi_ram_inst.mem[(OUT_BASE_ADDR[15:2] + (p_idx * 2)) + 0];
				word1 = axi_ram_inst.mem[(OUT_BASE_ADDR[15:2] + (p_idx * 2)) + 1];
				phase2_out[p_idx][0] = $signed(word0[7:0]);
				phase2_out[p_idx][1] = $signed(word0[15:8]);
				phase2_out[p_idx][2] = $signed(word0[23:16]);
				phase2_out[p_idx][3] = $signed(word0[31:24]);
				phase2_out[p_idx][4] = $signed(word1[7:0]);
				phase2_out[p_idx][5] = $signed(word1[15:8]);
				phase2_out[p_idx][6] = $signed(word1[23:16]);
				phase2_out[p_idx][7] = $signed(word1[31:24]);
				if (p_idx < 2)
					$display("   [Phase 2 Sample] Pixel %0d: w0=0x%08X w1=0x%08X -> Ch[0..7] = [%3d, %3d, %3d, %3d, %3d, %3d, %3d, %3d]", p_idx, word0, word1, phase2_out[p_idx][0], phase2_out[p_idx][1], phase2_out[p_idx][2], phase2_out[p_idx][3], phase2_out[p_idx][4], phase2_out[p_idx][5], phase2_out[p_idx][6], phase2_out[p_idx][7]);
			end
		$display("\n>>> Sub-Phase 5B: SiLU LUT Activation with Inline 2x2 MaxPool <<<");
		begin : sv2v_autoblock_15
			reg signed [31:0] w;
			for (w = 0; w < 64; w = w + 1)
				ram_write_word(LUT_BASE_ADDR + (w * 4), {lut_silu_mem[(w * 4) + 3], lut_silu_mem[(w * 4) + 2], lut_silu_mem[(w * 4) + 1], lut_silu_mem[(w * 4) + 0]});
		end
		begin : sv2v_autoblock_16
			reg signed [31:0] w;
			for (w = 0; w < 128; w = w + 1)
				ram_write_word(OUT_BASE_ADDR + (w * 4), 32'h00000000);
		end
		axil_write(32'h00000008, 32'h00000371);
		axil_write(32'h00000010, ACT_BASE_ADDR);
		axil_write(32'h00000014, WEIGHT_BASE_ADDR);
		axil_write(32'h00000018, OUT_BASE_ADDR);
		axil_write(32'h0000001c, BIAS_BASE_ADDR);
		axil_write(32'h00000020, QUANT_BASE_ADDR);
		axil_write(32'h00000024, LUT_BASE_ADDR);
		start_time = $time;
		axil_write(32'h00000000, 32'h00000001);
		read_status = 32'h00000000;
		while (!read_status[1]) begin
			#(100)
				;
			axil_read(32'h00000004, read_status);
		end
		total_cycles = ($time - start_time) / 10;
		$display(">>> Phase 5B (SiLU LUT + MaxPool) Finished in %0d cycles! Status: OK <<<", total_cycles);
		pool_errs_silu = 0;
		for (py_idx = 0; py_idx < 8; py_idx = py_idx + 1)
			for (px_idx = 0; px_idx < 8; px_idx = px_idx + 1)
				begin
					p_out_idx = (py_idx * 8) + px_idx;
					word0 = axi_ram_inst.mem[(OUT_BASE_ADDR[15:2] + (p_out_idx * 2)) + 0];
					word1 = axi_ram_inst.mem[(OUT_BASE_ADDR[15:2] + (p_out_idx * 2)) + 1];
					ram_pix[0] = $signed(word0[7:0]);
					ram_pix[1] = $signed(word0[15:8]);
					ram_pix[2] = $signed(word0[23:16]);
					ram_pix[3] = $signed(word0[31:24]);
					ram_pix[4] = $signed(word1[7:0]);
					ram_pix[5] = $signed(word1[15:8]);
					ram_pix[6] = $signed(word1[23:16]);
					ram_pix[7] = $signed(word1[31:24]);
					if (p_out_idx < 2) begin
						$display("   [Phase 5B Sample] Pooled Pixel %0d (py=%0d, px=%0d): w0=0x%08X w1=0x%08X", p_out_idx, py_idx, px_idx, word0, word1);
						for (ch_idx = 0; ch_idx < 8; ch_idx = ch_idx + 1)
							begin
								u_q0 = phase2_out[(((2 * py_idx) + 0) * 16) + ((2 * px_idx) + 0)][ch_idx];
								u_q1 = phase2_out[(((2 * py_idx) + 0) * 16) + ((2 * px_idx) + 1)][ch_idx];
								u_q2 = phase2_out[(((2 * py_idx) + 1) * 16) + ((2 * px_idx) + 0)][ch_idx];
								u_q3 = phase2_out[(((2 * py_idx) + 1) * 16) + ((2 * px_idx) + 1)][ch_idx];
								q0 = $signed(lut_silu_mem[u_q0]);
								q1 = $signed(lut_silu_mem[u_q1]);
								q2 = $signed(lut_silu_mem[u_q2]);
								q3 = $signed(lut_silu_mem[u_q3]);
								m01 = (q0 > q1 ? q0 : q1);
								m23 = (q2 > q3 ? q2 : q3);
								gold_val = (m01 > m23 ? m01 : m23);
								$display("     Ch %0d: SiLU Quad=[%3d, %3d, %3d, %3d] -> Act=%3d, Gold=%3d", ch_idx, q0, q1, q2, q3, ram_pix[ch_idx], gold_val);
							end
					end
					for (ch_idx = 0; ch_idx < 8; ch_idx = ch_idx + 1)
						begin
							u_q0 = phase2_out[(((2 * py_idx) + 0) * 16) + ((2 * px_idx) + 0)][ch_idx];
							u_q1 = phase2_out[(((2 * py_idx) + 0) * 16) + ((2 * px_idx) + 1)][ch_idx];
							u_q2 = phase2_out[(((2 * py_idx) + 1) * 16) + ((2 * px_idx) + 0)][ch_idx];
							u_q3 = phase2_out[(((2 * py_idx) + 1) * 16) + ((2 * px_idx) + 1)][ch_idx];
							q0 = $signed(lut_silu_mem[u_q0]);
							q1 = $signed(lut_silu_mem[u_q1]);
							q2 = $signed(lut_silu_mem[u_q2]);
							q3 = $signed(lut_silu_mem[u_q3]);
							m01 = (q0 > q1 ? q0 : q1);
							m23 = (q2 > q3 ? q2 : q3);
							gold_val = (m01 > m23 ? m01 : m23);
							act_val = ram_pix[ch_idx];
							if (act_val !== gold_val) begin
								if (pool_errs_silu < 8)
									$display("  [POOL SILU MISMATCH] Pooled (py=%0d, px=%0d), Ch %0d: Expected %0d, Got %0d", py_idx, px_idx, ch_idx, gold_val, act_val);
								pool_errs_silu = pool_errs_silu + 1;
							end
						end
				end
		$display("-----------------------------------------------------------------------------------------");
		$display("  SiLU MaxPool Matches           : %0d / 512 (%5.2f%%)", 512 - pool_errs_silu, (real'(512 - pool_errs_silu) / 512.0) * 100.0);
		$display("-----------------------------------------------------------------------------------------");
		if (pool_errs_silu == 0)
			$display(">>> SUCCESS: Phase 5B (SiLU LUT + 2x2 MaxPool) Verified 100%% Bit-Exact! <<<");
		else
			$display("[ERROR] SiLU MaxPool mismatches: %0d", pool_errs_silu);
		$display("=========================================================================================\n");
		$finish;
	end
	initial _sv2v_0 = 0;
endmodule
