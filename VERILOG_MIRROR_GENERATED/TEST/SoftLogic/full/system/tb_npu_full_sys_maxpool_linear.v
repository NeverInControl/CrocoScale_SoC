module tb_npu_full_sys_maxpool_linear;
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
	parameter signed [31:0] TOTAL_PASSES = 3;
	parameter signed [31:0] CIN = 128;
	parameter signed [31:0] COUT = 32;
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
	wire [(AXI_DATA_WIDTH / 8) - 1:0] m_axi_wstrb;
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
	wire [(ARRAY_WIDTH * WEIGHT_WIDTH) - 1:0] npu_weight_shift_in;
	wire [1:0] npu_weight_shift_en;
	wire npu_swap_weights;
	wire [SCALE_WIDTH - 1:0] npu_quant_shift_in;
	wire npu_quant_shift_en;
	wire npu_stochastic_round_en;
	wire [7:0] npu_psum_A_addr;
	wire [ARRAY_WIDTH - 1:0] npu_psum_A_we;
	wire [(ARRAY_WIDTH * PSUM_WIDTH) - 1:0] npu_psum_A_wdata;
	wire npu_psum_A_read_bank_sel;
	wire [(ARRAY_WIDTH * PSUM_WIDTH) - 1:0] npu_psum_A_rdata;
	wire [7:0] npu_psum_B_addr;
	wire [ARRAY_WIDTH - 1:0] npu_psum_B_we;
	wire [(ARRAY_WIDTH * PSUM_WIDTH) - 1:0] npu_psum_B_wdata;
	wire npu_psum_B_read_bank_sel;
	wire [(ARRAY_WIDTH * PSUM_WIDTH) - 1:0] npu_psum_B_rdata;
	wire [ARRAY_HEIGHT - 1:0] npu_ext_act_sram_we;
	wire [(ARRAY_HEIGHT * 9) - 1:0] npu_ext_act_sram_addr;
	reg [(ARRAY_HEIGHT * ACTIVATION_WIDTH) - 1:0] npu_ext_act_sram_wdata;
	wire [(ARRAY_HEIGHT * ACTIVATION_WIDTH) - 1:0] npu_act_sram_rdata;
	wire [(ARRAY_WIDTH * ACTIVATION_WIDTH) - 1:0] npu_out_act;
	wire [3:0] efpga_usr_irq_o;
	initial clk = 0;
	always #(5) clk = ~clk;
	localparam signed [31:0] MEM_ADDR_WIDTH = 17;
	axi_ram #(
		.DATA_WIDTH(AXI_DATA_WIDTH),
		.ADDR_WIDTH(MEM_ADDR_WIDTH)
	) axi_ram_inst(
		.clk(clk),
		.rst_n(rst_n),
		.s_axi_awaddr(m_axi_awaddr[16:0]),
		.s_axi_awlen(m_axi_awlen),
		.s_axi_awsize(m_axi_awsize),
		.s_axi_awburst(m_axi_awburst),
		.s_axi_awvalid(m_axi_awvalid),
		.s_axi_awready(m_axi_awready),
		.s_axi_wdata(m_axi_wdata),
		.s_axi_wstrb(m_axi_wstrb),
		.s_axi_wlast(m_axi_wlast),
		.s_axi_wvalid(m_axi_wvalid),
		.s_axi_wready(m_axi_wready),
		.s_axi_bresp(m_axi_bresp),
		.s_axi_bvalid(m_axi_bvalid),
		.s_axi_bready(m_axi_bready),
		.s_axi_araddr(m_axi_araddr[16:0]),
		.s_axi_arlen(m_axi_arlen),
		.s_axi_arsize(m_axi_arsize),
		.s_axi_arburst(m_axi_arburst),
		.s_axi_arvalid(m_axi_arvalid),
		.s_axi_arready(m_axi_arready),
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
		.WEIGHT_SPLIT(WEIGHT_SPLIT)
	) npu_inst(
		.clk(clk),
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
		.stochastic_round_en(npu_stochastic_round_en),
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
		.crossbar_sel(npu_crossbar_sel),
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
	reg signed [ACTIVATION_WIDTH - 1:0] conv1x1_act [0:24604];
	reg signed [WEIGHT_WIDTH - 1:0] conv1x1_w [0:398];
	reg signed [ACTIVATION_WIDTH - 1:0] linear_out [0:255][0:7];
	localparam [31:0] ACT_BASE_ADDR = 32'h00000000;
	localparam [31:0] WEIGHT_BASE_ADDR = 32'h00010000;
	localparam [31:0] OUT_BASE_ADDR = 32'h00018000;
	localparam [31:0] BIAS_BASE_ADDR = 32'h0001c000;
	localparam [31:0] QUANT_BASE_ADDR = 32'h0001d000;
	localparam [31:0] LUT_BASE_ADDR = 32'h0001e000;
	task automatic ram_write_word;
		input [31:0] addr;
		input [31:0] data;
		axi_ram_inst.mem[addr[16:2]] = data;
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
		else if (dut.preload_phase) begin
			feeder_p_idx = sv2v_cast_32_signed(dut.preload_step);
			feeder_y_idx = feeder_p_idx / 16;
			feeder_x_idx = feeder_p_idx % 16;
			begin : sv2v_autoblock_1
				reg signed [31:0] b;
				for (b = 0; b < 4; b = b + 1)
					if (((feeder_y_idx < 35) && (feeder_x_idx < 37)) && (b < 19))
						npu_ext_act_sram_wdata[b * ACTIVATION_WIDTH+:ACTIVATION_WIDTH] <= conv1x1_act[(((feeder_y_idx * 37) * 19) + (feeder_x_idx * 19)) + b];
					else
						npu_ext_act_sram_wdata[b * ACTIVATION_WIDTH+:ACTIVATION_WIDTH] <= 8'sd0;
			end
			begin : sv2v_autoblock_2
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
			if (dut.current_pass[0] == 1'b0) begin : sv2v_autoblock_3
				reg signed [31:0] b;
				for (b = 0; b < 4; b = b + 1)
					begin : sv2v_autoblock_4
						reg signed [31:0] ch;
						ch = feeder_next_ch_base + b;
						if ((((feeder_p_idx < 256) && (feeder_y_idx < 35)) && (feeder_x_idx < 37)) && (ch < 19))
							npu_ext_act_sram_wdata[(b + 4) * ACTIVATION_WIDTH+:ACTIVATION_WIDTH] <= conv1x1_act[(((feeder_y_idx * 37) * 19) + (feeder_x_idx * 19)) + ch];
						else
							npu_ext_act_sram_wdata[(b + 4) * ACTIVATION_WIDTH+:ACTIVATION_WIDTH] <= 8'sd0;
					end
			end
			else begin : sv2v_autoblock_5
				reg signed [31:0] b;
				for (b = 0; b < 4; b = b + 1)
					begin : sv2v_autoblock_6
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
		#(400000)
			;
		$display("\n[ERROR] Simulation Watchdog Timeout in Phase 5A (40,000 cycles)!");
		$finish;
	end
	initial begin : sv2v_autoblock_7
		reg signed [63:0] start_time;
		reg signed [63:0] total_cycles;
		reg [31:0] read_status;
		reg signed [7:0] w_val0;
		reg signed [7:0] w_val1;
		reg signed [7:0] w_val2;
		reg signed [7:0] w_val3;
		reg [31:0] word0;
		reg [31:0] word1;
		reg signed [31:0] pool_errs;
		reg signed [31:0] py_idx;
		reg signed [31:0] px_idx;
		reg signed [31:0] p_out_idx;
		reg signed [31:0] ch_idx;
		reg signed [31:0] p_idx;
		reg signed [7:0] q0;
		reg signed [7:0] q1;
		reg signed [7:0] q2;
		reg signed [7:0] q3;
		reg signed [7:0] m01;
		reg signed [7:0] m23;
		reg signed [7:0] gold_val;
		reg signed [7:0] act_val;
		$display("\n=========================================================================================");
		$display(">>> Starting Standalone Phase 5A: Inline 2x2 MaxPool (Linear) <<<");
		$display("=========================================================================================");
		$readmemh("TEST/NPU/GoldenReference/gen_conv1x1_act.mem", conv1x1_act);
		$readmemh("TEST/NPU/GoldenReference/gen_conv1x1_w.mem", conv1x1_w);
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
		begin : sv2v_autoblock_8
			reg signed [31:0] ch;
			for (ch = 0; ch < 8; ch = ch + 1)
				ram_write_word(BIAS_BASE_ADDR + (ch * 4), 32'sd0);
		end
		begin : sv2v_autoblock_9
			reg signed [31:0] ch;
			for (ch = 0; ch < 8; ch = ch + 1)
				ram_write_word(QUANT_BASE_ADDR + (ch * 4), 32'h000e4000);
		end
		begin : sv2v_autoblock_10
			reg signed [31:0] p;
			for (p = 0; p < 3; p = p + 1)
				begin : sv2v_autoblock_11
					reg signed [31:0] s;
					for (s = 0; s < 8; s = s + 1)
						begin : sv2v_autoblock_12
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
		axil_write(32'h00000000, 32'h00000001);
		read_status = 32'h00000000;
		while (!read_status[1]) begin
			#(100)
				;
			axil_read(32'h00000004, read_status);
		end
		for (p_idx = 0; p_idx < 256; p_idx = p_idx + 1)
			begin
				word0 = axi_ram_inst.mem[(OUT_BASE_ADDR[16:2] + (p_idx * 2)) + 0];
				word1 = axi_ram_inst.mem[(OUT_BASE_ADDR[16:2] + (p_idx * 2)) + 1];
				linear_out[p_idx][0] = $signed(word0[7:0]);
				linear_out[p_idx][1] = $signed(word0[15:8]);
				linear_out[p_idx][2] = $signed(word0[23:16]);
				linear_out[p_idx][3] = $signed(word0[31:24]);
				linear_out[p_idx][4] = $signed(word1[7:0]);
				linear_out[p_idx][5] = $signed(word1[15:8]);
				linear_out[p_idx][6] = $signed(word1[23:16]);
				linear_out[p_idx][7] = $signed(word1[31:24]);
			end
		axil_write(32'h00000008, 32'h00000351);
		start_time = $time;
		axil_write(32'h00000000, 32'h00000001);
		read_status = 32'h00000000;
		while (!read_status[1]) begin
			#(100)
				;
			axil_read(32'h00000004, read_status);
		end
		total_cycles = ($time - start_time) / 10;
		$display(">>> Phase 5A (Linear MaxPool) Finished in %0d cycles! Status: OK <<<", total_cycles);
		pool_errs = 0;
		for (py_idx = 0; py_idx < 8; py_idx = py_idx + 1)
			for (px_idx = 0; px_idx < 8; px_idx = px_idx + 1)
				begin
					p_out_idx = (py_idx * 8) + px_idx;
					word0 = axi_ram_inst.mem[(OUT_BASE_ADDR[16:2] + (p_out_idx * 2)) + 0];
					word1 = axi_ram_inst.mem[(OUT_BASE_ADDR[16:2] + (p_out_idx * 2)) + 1];
					for (ch_idx = 0; ch_idx < 8; ch_idx = ch_idx + 1)
						begin
							q0 = linear_out[(((2 * py_idx) + 0) * 16) + ((2 * px_idx) + 0)][ch_idx];
							q1 = linear_out[(((2 * py_idx) + 0) * 16) + ((2 * px_idx) + 1)][ch_idx];
							q2 = linear_out[(((2 * py_idx) + 1) * 16) + ((2 * px_idx) + 0)][ch_idx];
							q3 = linear_out[(((2 * py_idx) + 1) * 16) + ((2 * px_idx) + 1)][ch_idx];
							m01 = (q0 > q1 ? q0 : q1);
							m23 = (q2 > q3 ? q2 : q3);
							gold_val = (m01 > m23 ? m01 : m23);
							case (ch_idx)
								0: act_val = $signed(word0[7:0]);
								1: act_val = $signed(word0[15:8]);
								2: act_val = $signed(word0[23:16]);
								3: act_val = $signed(word0[31:24]);
								4: act_val = $signed(word1[7:0]);
								5: act_val = $signed(word1[15:8]);
								6: act_val = $signed(word1[23:16]);
								7: act_val = $signed(word1[31:24]);
							endcase
							if (act_val !== gold_val) begin
								$display("[FAIL Phase 5A] Pooled (%0d,%0d) Ch %0d: Quad=[%0d,%0d,%0d,%0d], Got=%0d, Exp=%0d", py_idx, px_idx, ch_idx, q0, q1, q2, q3, act_val, gold_val);
								pool_errs = pool_errs + 1;
							end
						end
				end
		$display("-----------------------------------------------------------------------------------------");
		$display("  Linear MaxPool Matches         : %0d / 512 (%0.2f%%)", 512 - pool_errs, (real'(512 - pool_errs) / 512.0) * 100.0);
		$display("-----------------------------------------------------------------------------------------");
		if (pool_errs == 0)
			$display(">>> SUCCESS: Phase 5A (Linear 2x2 MaxPool) Verified 100%% Bit-Exact! <<<");
		else
			$display(">>> FAILED: Phase 5A had %0d mismatches! <<<", pool_errs);
		$finish;
	end
endmodule
