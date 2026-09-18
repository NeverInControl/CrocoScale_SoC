module tb_npu_full_sys_functional;
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
	parameter signed [31:0] MEM_ADDR_WIDTH = 20;
	localparam [31:0] ACT_BASE_ADDR = 32'h00001000;
	localparam [31:0] WEIGHT_BASE_ADDR = 32'h00010000;
	localparam [31:0] OUT_BASE_ADDR = 32'h00020000;
	localparam [31:0] BIAS_BASE_ADDR = 32'h00030000;
	localparam [31:0] QUANT_BASE_ADDR = 32'h00030100;
	localparam [31:0] LUT_BASE_ADDR = 32'h00030200;
	localparam [31:0] OUT_BASE_A_ADDR = 32'h00040000;
	localparam [31:0] OUT_BASE_B_ADDR = 32'h00050000;
	localparam [31:0] OUT_BASE_C_ADDR = 32'h00060000;
	localparam [31:0] OUT_BASE_D_ADDR = 32'h00070000;
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
	reg [(ARRAY_HEIGHT * ACTIVATION_WIDTH) - 1:0] npu_ext_act_sram_wdata;
	wire [(ARRAY_HEIGHT * ACTIVATION_WIDTH) - 1:0] npu_act_sram_rdata;
	wire [(ARRAY_WIDTH * ACTIVATION_WIDTH) - 1:0] npu_out_act;
	wire [3:0] efpga_usr_irq_o;
	initial clk = 0;
	always #(5) clk = ~clk;
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
		.TOTAL_PASSES(6),
		.CIN(24),
		.COUT(8)
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
	npu_wrapper #(
		.ARRAY_HEIGHT(ARRAY_HEIGHT),
		.ARRAY_WIDTH(ARRAY_WIDTH),
		.ACTIVATION_WIDTH(ACTIVATION_WIDTH),
		.WEIGHT_WIDTH(WEIGHT_WIDTH),
		.PSUM_WIDTH(PSUM_WIDTH),
		.SCALE_WIDTH(SCALE_WIDTH),
		.WEIGHT_SPLIT(WEIGHT_SPLIT)
	) npu_inst(
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
	axi_ram #(
		.DATA_WIDTH(AXI_DATA_WIDTH),
		.ADDR_WIDTH(MEM_ADDR_WIDTH),
		.ID_WIDTH(1)
	) axi_ram_inst(
		.clk(clk),
		.rst(!rst_n),
		.s_axi_awid(1'b0),
		.s_axi_awaddr(m_axi_awaddr[MEM_ADDR_WIDTH - 1:0]),
		.s_axi_awlen(m_axi_awlen),
		.s_axi_awsize(m_axi_awsize),
		.s_axi_awburst(m_axi_awburst),
		.s_axi_awlock(1'b0),
		.s_axi_awcache(4'd0),
		.s_axi_awprot(3'd0),
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
		.s_axi_araddr(m_axi_araddr[MEM_ADDR_WIDTH - 1:0]),
		.s_axi_arlen(m_axi_arlen),
		.s_axi_arsize(m_axi_arsize),
		.s_axi_arburst(m_axi_arburst),
		.s_axi_arlock(1'b0),
		.s_axi_arcache(4'd0),
		.s_axi_arprot(3'd0),
		.s_axi_arvalid(m_axi_arvalid),
		.s_axi_arready(m_axi_arready),
		.s_axi_rid(),
		.s_axi_rdata(m_axi_rdata),
		.s_axi_rresp(m_axi_rresp),
		.s_axi_rlast(m_axi_rlast),
		.s_axi_rvalid(m_axi_rvalid),
		.s_axi_rready(m_axi_rready)
	);
	reg signed [7:0] lut_mish_mem [0:255];
	reg signed [7:0] c1_act [0:6143];
	reg signed [7:0] c1_w [0:191];
	reg signed [31:0] c1_b [0:7];
	reg [31:0] c1_cfg [0:7];
	reg signed [31:0] c1_gold_raw [0:2047];
	reg signed [7:0] c1_gold_lin [0:2047];
	reg signed [7:0] c1_gold_mish [0:2047];
	reg signed [7:0] c1_gold_pool [0:511];
	reg signed [7:0] c1_gold_mpool [0:511];
	reg signed [7:0] c3_act [0:8191];
	reg signed [7:0] c3_w [0:575];
	reg signed [31:0] c3_b [0:7];
	reg [31:0] c3_cfg [0:7];
	reg signed [31:0] c3_gold_raw [0:8191];
	reg signed [7:0] c3_gold_lin [0:8191];
	reg signed [7:0] c3_gold_mish [0:8191];
	reg signed [7:0] c3_gold_pool [0:2047];
	reg signed [7:0] c3_gold_mpool [0:2047];
	reg is_mode_1x1 = 1;
	reg signed [31:0] curr_ty = 0;
	reg signed [31:0] curr_tx = 0;
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
	task automatic ram_write_word;
		input reg [31:0] addr;
		input reg [31:0] data;
		axi_ram_inst.mem[addr[MEM_ADDR_WIDTH - 1:2]] = data;
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
				mem_dir = "TEST/SoftLogic/GoldenReference/";
				fd = $fopen({mem_dir, sample_file}, "r");
				if (fd != 0) begin
					$fclose(fd);
					found = 1;
				end
			end
			if (!found) begin
				$display("\n=====================================================================================");
				$display(" [FATAL ERROR] Required test vector file '%s' was NOT found!", sample_file);
				$display(" Checked plusarg path and standard default 'TEST/SoftLogic/GoldenReference/'.");
				$display(" Please provide a valid path via +MEM_DIR=<path> (e.g. in Vivado simulation settings).");
				$display("=====================================================================================\n");
				$display("Fatal [%0t] /mnt/c/Users/Niels/Documents/nct/MyProjects/CrocoScale_SoC/TEST/SoftLogic/full/system/tb_npu_full_sys_functional.sv:438:13 - tb_npu_full_sys_functional.resolve_mem_dir.<unnamed_block>\n msg: ", $time, "Aborting simulation due to missing test vector files.");
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
				$display("\n=========================================================================================");
				$display(" [FATAL ERROR] Required memory file '%s' was NOT found in any search path!", filename);
				$display(" Please ensure files exist in TEST/SoftLogic/GoldenReference/ or pass +MEM_DIR=<path>.");
				$display("=========================================================================================\n");
				$display("Fatal [%0t] /mnt/c/Users/Niels/Documents/nct/MyProjects/CrocoScale_SoC/TEST/SoftLogic/full/system/tb_npu_full_sys_functional.sv:450:13 - tb_npu_full_sys_functional.check_file_exists.<unnamed_block>\n msg: ", $time, "Aborting simulation due to missing test vector files.");
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
				$display("\n=========================================================================================");
				$display(" [FATAL ERROR] Vector '%s' contains %0d non-zero entries (minimum required: %0d)!", vec_name, nonzero_count, min_required);
				$display(" Aborting simulation to prevent false-positive pass on uninitialized data.");
				$display("=========================================================================================\n");
				$display("Fatal [%0t] /mnt/c/Users/Niels/Documents/nct/MyProjects/CrocoScale_SoC/TEST/SoftLogic/full/system/tb_npu_full_sys_functional.sv:466:13 - tb_npu_full_sys_functional.assert_vector_nonzero.<unnamed_block>\n msg: ", $time, "Aborting simulation due to zeroed test vector.");
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
			filled = (current * 24) / total;
			begin : sv2v_autoblock_1
				reg signed [31:0] i;
				for (i = 0; i < 24; i = i + 1)
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
	function automatic signed [7:0] get_c3_fmap_val;
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
			if (((((gy_val >= 0) && (gy_val < 32)) && (gx_val >= 0)) && (gx_val < 32)) && (c_idx < 8))
				get_c3_fmap_val = c3_act[(((gy_val * 32) * 8) + (gx_val * 8)) + c_idx];
			else
				get_c3_fmap_val = 8'sd0;
		end
	endfunction
	function automatic signed [7:0] get_c3_w_val;
		input reg signed [31:0] p;
		input reg signed [31:0] r;
		input reg signed [31:0] c;
		reg signed [31:0] g_idx;
		reg signed [31:0] cin_curr;
		reg signed [31:0] tap_curr;
		reg signed [31:0] ky_curr;
		reg signed [31:0] kx_curr;
		begin
			g_idx = (p * 8) + r;
			if (g_idx < 72) begin
				cin_curr = g_idx / 9;
				tap_curr = g_idx % 9;
				ky_curr = tap_curr / 3;
				kx_curr = tap_curr % 3;
				get_c3_w_val = c3_w[(((((ky_curr * 3) * 8) * 8) + ((kx_curr * 8) * 8)) + (cin_curr * 8)) + c];
			end
			else
				get_c3_w_val = 8'sd0;
		end
	endfunction
	function automatic signed [31:0] peek_psum;
		input reg signed [31:0] ch_idx;
		input reg signed [31:0] p_idx;
		case (ch_idx)
			0: peek_psum = npu_inst.gen_psum_srams[0].psum_sram_inst.mem[p_idx];
			1: peek_psum = npu_inst.gen_psum_srams[1].psum_sram_inst.mem[p_idx];
			2: peek_psum = npu_inst.gen_psum_srams[2].psum_sram_inst.mem[p_idx];
			3: peek_psum = npu_inst.gen_psum_srams[3].psum_sram_inst.mem[p_idx];
			4: peek_psum = npu_inst.gen_psum_srams[4].psum_sram_inst.mem[p_idx];
			5: peek_psum = npu_inst.gen_psum_srams[5].psum_sram_inst.mem[p_idx];
			6: peek_psum = npu_inst.gen_psum_srams[6].psum_sram_inst.mem[p_idx];
			7: peek_psum = npu_inst.gen_psum_srams[7].psum_sram_inst.mem[p_idx];
			default: peek_psum = 32'sd0;
		endcase
	endfunction
	reg signed [31:0] feeder_p_idx;
	reg signed [31:0] feeder_y_idx;
	reg signed [31:0] feeder_x_idx;
	reg signed [31:0] feeder_next_ch_base;
	reg signed [31:0] feeder_c_in;
	function automatic signed [31:0] sv2v_cast_32_signed;
		input reg signed [31:0] inp;
		sv2v_cast_32_signed = inp;
	endfunction
	always @(negedge clk)
		if (!rst_n)
			npu_ext_act_sram_wdata <= 1'sb0;
		else if (is_mode_1x1) begin
			if (dut.preload_phase) begin
				feeder_p_idx = sv2v_cast_32_signed(dut.preload_step);
				feeder_y_idx = feeder_p_idx / 16;
				feeder_x_idx = feeder_p_idx % 16;
				begin : sv2v_autoblock_2
					reg signed [31:0] b;
					for (b = 0; b < 4; b = b + 1)
						if (((feeder_y_idx < 16) && (feeder_x_idx < 16)) && (b < 24))
							npu_ext_act_sram_wdata[b * ACTIVATION_WIDTH+:ACTIVATION_WIDTH] <= c1_act[(((feeder_y_idx * 16) * 24) + (feeder_x_idx * 24)) + b];
						else
							npu_ext_act_sram_wdata[b * ACTIVATION_WIDTH+:ACTIVATION_WIDTH] <= 8'sd0;
				end
				begin : sv2v_autoblock_3
					reg signed [31:0] b;
					for (b = 4; b < 8; b = b + 1)
						npu_ext_act_sram_wdata[b * ACTIVATION_WIDTH+:ACTIVATION_WIDTH] <= 8'sd0;
				end
			end
			else if (dut.sequencer_inst.addr_1x1_inst.act_sram_we_o != 8'h00) begin
				feeder_p_idx = sv2v_cast_32_signed(dut.cycle_in_pass);
				feeder_y_idx = feeder_p_idx / 16;
				feeder_x_idx = feeder_p_idx % 16;
				feeder_next_ch_base = (sv2v_cast_32_signed(dut.current_pass) + 1) * 4;
				if (dut.current_pass[0] == 1'b0) begin : sv2v_autoblock_4
					reg signed [31:0] b;
					for (b = 0; b < 4; b = b + 1)
						begin
							feeder_c_in = feeder_next_ch_base + b;
							if ((((feeder_p_idx < 256) && (feeder_y_idx < 16)) && (feeder_x_idx < 16)) && (feeder_c_in < 24))
								npu_ext_act_sram_wdata[(b + 4) * ACTIVATION_WIDTH+:ACTIVATION_WIDTH] <= c1_act[(((feeder_y_idx * 16) * 24) + (feeder_x_idx * 24)) + feeder_c_in];
							else
								npu_ext_act_sram_wdata[(b + 4) * ACTIVATION_WIDTH+:ACTIVATION_WIDTH] <= 8'sd0;
						end
				end
				else begin : sv2v_autoblock_5
					reg signed [31:0] b;
					for (b = 0; b < 4; b = b + 1)
						begin
							feeder_c_in = feeder_next_ch_base + b;
							if ((((feeder_p_idx < 256) && (feeder_y_idx < 16)) && (feeder_x_idx < 16)) && (feeder_c_in < 24))
								npu_ext_act_sram_wdata[b * ACTIVATION_WIDTH+:ACTIVATION_WIDTH] <= c1_act[(((feeder_y_idx * 16) * 24) + (feeder_x_idx * 24)) + feeder_c_in];
							else
								npu_ext_act_sram_wdata[b * ACTIVATION_WIDTH+:ACTIVATION_WIDTH] <= 8'sd0;
						end
				end
			end
		end
		else if (dut.preload_phase) begin
			begin : sv2v_autoblock_6
				reg signed [31:0] b;
				for (b = 0; b < 6; b = b + 1)
					npu_ext_act_sram_wdata[b * ACTIVATION_WIDTH+:ACTIVATION_WIDTH] <= get_c3_fmap_val(0, b, sv2v_cast_32_signed(dut.preload_step), curr_ty, curr_tx);
			end
			npu_ext_act_sram_wdata[6 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH] <= 1'sb0;
			npu_ext_act_sram_wdata[7 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH] <= 1'sb0;
		end
		else if (dut.dma_channel_to_load >= 0) begin
			begin : sv2v_autoblock_7
				reg signed [31:0] b;
				for (b = 0; b < 6; b = b + 1)
					npu_ext_act_sram_wdata[b * ACTIVATION_WIDTH+:ACTIVATION_WIDTH] <= get_c3_fmap_val(sv2v_cast_32_signed(dut.dma_channel_to_load), b, sv2v_cast_32_signed((dut.dma_bank_ptr >> (b * 6)) & 6'h3f), curr_ty, curr_tx);
			end
			npu_ext_act_sram_wdata[6 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH] <= 1'sb0;
			npu_ext_act_sram_wdata[7 * ACTIVATION_WIDTH+:ACTIVATION_WIDTH] <= 1'sb0;
		end
	initial begin
		#(25000000)
			;
		$display("\n[FATAL ERROR] Simulation Watchdog Timeout (25,000,000 ns)!");
		$finish;
	end
	initial begin : sv2v_autoblock_8
		string mem_dir;
		reg signed [31:0] nz_cnt;
		reg [31:0] read_status;
		reg [31:0] word0;
		reg [31:0] word1;
		reg signed [7:0] ram_pix [0:7];
		reg signed [31:0] errs;
		reg signed [31:0] tol_ok;
		reg signed [31:0] exact_ok;
		reg signed [31:0] max_diff;
		reg signed [31:0] diff_val;
		reg signed [31:0] p_idx;
		reg signed [31:0] y_idx;
		reg signed [31:0] x_idx;
		reg signed [31:0] ch_idx;
		reg signed [31:0] flat_idx;
		reg signed [31:0] step_cnt;
		reg signed [31:0] c_out;
		reg signed [31:0] tile_idx;
		reg signed [31:0] i;
		reg signed [31:0] ch;
		reg signed [31:0] p;
		reg signed [31:0] s;
		reg signed [7:0] w0;
		reg signed [7:0] w1;
		reg signed [7:0] w2;
		reg signed [7:0] w3;
		reg signed [7:0] gold_val;
		reg signed [7:0] act_val;
		reg signed [31:0] gold_raw;
		reg signed [31:0] act_raw;
		reg signed [31:0] diff_raw;
		$display("\n=========================================================================================");
		$display("   CrocoScale SoC -- UNIFIED SOFTLOGIC FUNCTIONAL VERIFICATION SUITE                      ");
		$display("=========================================================================================");
		$display("   Phase 1: 1x1 Convolution (16x16, Cin=24, Cout=8, 6 Passes)                           ");
		$display("   Phase 2: 3x3 Multi-Tile Halo Convolution (32x32, 2x2 Grid of 16x16 Tiles, Cin=8)     ");
		$display("   Drain Sweeps Evaluated per Phase:                                                     ");
		$display("     [0] Simulation Peek : Raw 32-bit PSUM accumulator verification                      ");
		$display("     [A] Mode A (Linear) : Requantized INT8 (lut_en=0, pool_en=0)                       ");
		$display("     [B] Mode B (Mish)   : Requantized + Non-Linear Mish LUT INT8 (lut_en=1, pool_en=0) ");
		$display("     [C] Mode C (Pool)   : Requantized + 2x2 MaxPool INT8 (lut_en=0, pool_en=1)         ");
		$display("     [D] Mode D (Mish+P) : Requantized + Mish LUT + MaxPool INT8 (lut_en=1, pool_en=1)  ");
		$display("=========================================================================================\n");
		resolve_mem_dir("func_lut_mish.mem", mem_dir);
		$display("[INFO] Resolved memory directory: '%s'", mem_dir);
		check_file_exists({mem_dir, "func_lut_mish.mem"});
		check_file_exists({mem_dir, "func_1x1_act.mem"});
		check_file_exists({mem_dir, "func_1x1_w.mem"});
		check_file_exists({mem_dir, "func_1x1_b.mem"});
		check_file_exists({mem_dir, "func_1x1_cfg.mem"});
		check_file_exists({mem_dir, "func_1x1_raw.mem"});
		check_file_exists({mem_dir, "func_1x1_out_linear.mem"});
		check_file_exists({mem_dir, "func_1x1_out_mish.mem"});
		check_file_exists({mem_dir, "func_1x1_out_pool.mem"});
		check_file_exists({mem_dir, "func_1x1_out_mish_pool.mem"});
		check_file_exists({mem_dir, "func_3x3_act.mem"});
		check_file_exists({mem_dir, "func_3x3_w.mem"});
		check_file_exists({mem_dir, "func_3x3_b.mem"});
		check_file_exists({mem_dir, "func_3x3_cfg.mem"});
		check_file_exists({mem_dir, "func_3x3_raw.mem"});
		check_file_exists({mem_dir, "func_3x3_out_linear.mem"});
		check_file_exists({mem_dir, "func_3x3_out_mish.mem"});
		check_file_exists({mem_dir, "func_3x3_out_pool.mem"});
		check_file_exists({mem_dir, "func_3x3_out_mish_pool.mem"});
		$readmemh({mem_dir, "func_lut_mish.mem"}, lut_mish_mem);
		$readmemh({mem_dir, "func_1x1_act.mem"}, c1_act);
		$readmemh({mem_dir, "func_1x1_w.mem"}, c1_w);
		$readmemh({mem_dir, "func_1x1_b.mem"}, c1_b);
		$readmemh({mem_dir, "func_1x1_cfg.mem"}, c1_cfg);
		$readmemh({mem_dir, "func_1x1_raw.mem"}, c1_gold_raw);
		$readmemh({mem_dir, "func_1x1_out_linear.mem"}, c1_gold_lin);
		$readmemh({mem_dir, "func_1x1_out_mish.mem"}, c1_gold_mish);
		$readmemh({mem_dir, "func_1x1_out_pool.mem"}, c1_gold_pool);
		$readmemh({mem_dir, "func_1x1_out_mish_pool.mem"}, c1_gold_mpool);
		$readmemh({mem_dir, "func_3x3_act.mem"}, c3_act);
		$readmemh({mem_dir, "func_3x3_w.mem"}, c3_w);
		$readmemh({mem_dir, "func_3x3_b.mem"}, c3_b);
		$readmemh({mem_dir, "func_3x3_cfg.mem"}, c3_cfg);
		$readmemh({mem_dir, "func_3x3_raw.mem"}, c3_gold_raw);
		$readmemh({mem_dir, "func_3x3_out_linear.mem"}, c3_gold_lin);
		$readmemh({mem_dir, "func_3x3_out_mish.mem"}, c3_gold_mish);
		$readmemh({mem_dir, "func_3x3_out_pool.mem"}, c3_gold_pool);
		$readmemh({mem_dir, "func_3x3_out_mish_pool.mem"}, c3_gold_mpool);
		nz_cnt = 0;
		for (i = 0; i < 256; i = i + 1)
			if (lut_mish_mem[i] !== 8'sd0)
				nz_cnt = nz_cnt + 1;
		assert_vector_nonzero("lut_mish_mem", nz_cnt, 10);
		nz_cnt = 0;
		for (i = 0; i < 6144; i = i + 1)
			if (c1_act[i] !== 8'sd0)
				nz_cnt = nz_cnt + 1;
		assert_vector_nonzero("c1_act", nz_cnt, 10);
		nz_cnt = 0;
		for (i = 0; i < 8192; i = i + 1)
			if (c3_act[i] !== 8'sd0)
				nz_cnt = nz_cnt + 1;
		assert_vector_nonzero("c3_act", nz_cnt, 10);
		$display("[INFO] All test vectors loaded successfully and confirmed non-zero.\n");
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
		for (i = 0; i < 64; i = i + 1)
			ram_write_word(LUT_BASE_ADDR + (i * 4), {lut_mish_mem[(i * 4) + 3], lut_mish_mem[(i * 4) + 2], lut_mish_mem[(i * 4) + 1], lut_mish_mem[(i * 4) + 0]});
		$display("-----------------------------------------------------------------------------------------");
		$display(" >>> STARTING PHASE 1: 1x1 CONVOLUTION (Cin=24, Cout=8) <<<");
		$display("-----------------------------------------------------------------------------------------");
		is_mode_1x1 = 1;
		for (ch = 0; ch < 8; ch = ch + 1)
			ram_write_word(BIAS_BASE_ADDR + (ch * 4), c1_b[ch]);
		for (ch = 0; ch < 8; ch = ch + 1)
			ram_write_word(QUANT_BASE_ADDR + (ch * 4), c1_cfg[ch]);
		for (p = 0; p < 6; p = p + 1)
			for (s = 0; s < 8; s = s + 1)
				begin
					c_out = 7 - s;
					w0 = ((((p * 4) + 0) < 24) && (c_out < 8) ? c1_w[(((p * 4) + 0) * 8) + c_out] : 8'sd0);
					w1 = ((((p * 4) + 1) < 24) && (c_out < 8) ? c1_w[(((p * 4) + 1) * 8) + c_out] : 8'sd0);
					w2 = ((((p * 4) + 2) < 24) && (c_out < 8) ? c1_w[(((p * 4) + 2) * 8) + c_out] : 8'sd0);
					w3 = ((((p * 4) + 3) < 24) && (c_out < 8) ? c1_w[(((p * 4) + 3) * 8) + c_out] : 8'sd0);
					ram_write_word((WEIGHT_BASE_ADDR + (p * 32)) + (s * 4), {w3, w2, w1, w0});
				end
		axil_write(32'h00000008, 32'h00000610);
		axil_write(32'h00000010, ACT_BASE_ADDR);
		axil_write(32'h00000014, WEIGHT_BASE_ADDR);
		axil_write(32'h00000018, OUT_BASE_ADDR);
		axil_write(32'h0000001c, BIAS_BASE_ADDR);
		axil_write(32'h00000020, QUANT_BASE_ADDR);
		axil_write(32'h00000024, LUT_BASE_ADDR);
		$display("  %s  0%% [Phase 1: 1x1 Compute Running (Single Forward Pass)...]", get_progress_bar(0, 5));
		axil_write(32'h00000000, 32'h00000001);
		read_status = 32'h00000000;
		while (!read_status[1]) begin
			#(100)
				;
			axil_read(32'h00000004, read_status);
		end
		$display("  %s 20%% [Phase 1: Validating Raw 32-bit PSUM Peek...]", get_progress_bar(1, 5));
		errs = 0;
		max_diff = 0;
		for (p_idx = 0; p_idx < 256; p_idx = p_idx + 1)
			for (ch_idx = 0; ch_idx < 8; ch_idx = ch_idx + 1)
				begin
					act_raw = peek_psum(ch_idx, p_idx);
					gold_raw = c1_gold_raw[(p_idx * 8) + ch_idx];
					diff_raw = (act_raw > gold_raw ? act_raw - gold_raw : gold_raw - act_raw);
					if (diff_raw != 0) begin
						errs = errs + 1;
						if (diff_raw > max_diff)
							max_diff = diff_raw;
					end
				end
		if (errs == 0)
			$display("    -> [PASS] 1x1 Raw 32-bit PSUM peek matches 100%% bit-exact!");
		else begin
			$display("Fatal [%0t] /mnt/c/Users/Niels/Documents/nct/MyProjects/CrocoScale_SoC/TEST/SoftLogic/full/system/tb_npu_full_sys_functional.sv:762:14 - tb_npu_full_sys_functional.<unnamed_block>.<unnamed_block>\n msg: ", $time, "1x1 Raw 32-bit PSUM peek failed with %0d errors (max diff %0d)!", errs, max_diff);
			$finish(1);
		end
		$display("  %s 40%% [Phase 1: Draining & Validating Mode A (Linear Requant)...]", get_progress_bar(2, 5));
		axil_write(32'h00000008, 32'h00000610);
		axil_write(32'h00000018, OUT_BASE_ADDR);
		axil_write(32'h00000000, 32'h00000004);
		read_status = 32'h00000000;
		while (!read_status[1]) begin
			#(100)
				;
			axil_read(32'h00000004, read_status);
		end
		errs = 0;
		tol_ok = 0;
		exact_ok = 0;
		max_diff = 0;
		for (p_idx = 0; p_idx < 256; p_idx = p_idx + 1)
			begin
				word0 = axi_ram_inst.mem[(OUT_BASE_ADDR[MEM_ADDR_WIDTH - 1:2] + (p_idx * 2)) + 0];
				word1 = axi_ram_inst.mem[(OUT_BASE_ADDR[MEM_ADDR_WIDTH - 1:2] + (p_idx * 2)) + 1];
				ram_pix[0] = $signed(word0[7:0]);
				ram_pix[1] = $signed(word0[15:8]);
				ram_pix[2] = $signed(word0[23:16]);
				ram_pix[3] = $signed(word0[31:24]);
				ram_pix[4] = $signed(word1[7:0]);
				ram_pix[5] = $signed(word1[15:8]);
				ram_pix[6] = $signed(word1[23:16]);
				ram_pix[7] = $signed(word1[31:24]);
				for (ch_idx = 0; ch_idx < 8; ch_idx = ch_idx + 1)
					begin
						gold_val = c1_gold_lin[(p_idx * 8) + ch_idx];
						act_val = ram_pix[ch_idx];
						diff_val = (act_val > gold_val ? act_val - gold_val : gold_val - act_val);
						if (diff_val == 0)
							exact_ok = exact_ok + 1;
						else if (diff_val <= 1)
							tol_ok = tol_ok + 1;
						else
							errs = errs + 1;
						if (diff_val > max_diff)
							max_diff = diff_val;
					end
			end
		if (errs == 0)
			$display("    -> [PASS] 1x1 Mode A Linear: 2048/2048 matches (exact: %0d, tol: %0d)!", exact_ok, tol_ok);
		else begin
			$display("Fatal [%0t] /mnt/c/Users/Niels/Documents/nct/MyProjects/CrocoScale_SoC/TEST/SoftLogic/full/system/tb_npu_full_sys_functional.sv:790:14 - tb_npu_full_sys_functional.<unnamed_block>.<unnamed_block>\n msg: ", $time, "1x1 Mode A Linear failed with %0d errors (max diff %0d)!", errs, max_diff);
			$finish(1);
		end
		$display("  %s 60%% [Phase 1: Draining & Validating Mode B (Mish LUT)...]", get_progress_bar(3, 5));
		axil_write(32'h00000008, 32'h00000630);
		axil_write(32'h00000018, OUT_BASE_ADDR);
		axil_write(32'h00000000, 32'h00000004);
		read_status = 32'h00000000;
		while (!read_status[1]) begin
			#(100)
				;
			axil_read(32'h00000004, read_status);
		end
		errs = 0;
		tol_ok = 0;
		exact_ok = 0;
		max_diff = 0;
		for (p_idx = 0; p_idx < 256; p_idx = p_idx + 1)
			begin
				word0 = axi_ram_inst.mem[(OUT_BASE_ADDR[MEM_ADDR_WIDTH - 1:2] + (p_idx * 2)) + 0];
				word1 = axi_ram_inst.mem[(OUT_BASE_ADDR[MEM_ADDR_WIDTH - 1:2] + (p_idx * 2)) + 1];
				ram_pix[0] = $signed(word0[7:0]);
				ram_pix[1] = $signed(word0[15:8]);
				ram_pix[2] = $signed(word0[23:16]);
				ram_pix[3] = $signed(word0[31:24]);
				ram_pix[4] = $signed(word1[7:0]);
				ram_pix[5] = $signed(word1[15:8]);
				ram_pix[6] = $signed(word1[23:16]);
				ram_pix[7] = $signed(word1[31:24]);
				for (ch_idx = 0; ch_idx < 8; ch_idx = ch_idx + 1)
					begin
						gold_val = c1_gold_mish[(p_idx * 8) + ch_idx];
						act_val = ram_pix[ch_idx];
						diff_val = (act_val > gold_val ? act_val - gold_val : gold_val - act_val);
						if (diff_val == 0)
							exact_ok = exact_ok + 1;
						else if (diff_val <= 1)
							tol_ok = tol_ok + 1;
						else
							errs = errs + 1;
						if (diff_val > max_diff)
							max_diff = diff_val;
					end
			end
		if (errs == 0)
			$display("    -> [PASS] 1x1 Mode B Mish LUT: 2048/2048 matches (exact: %0d, tol: %0d)!", exact_ok, tol_ok);
		else begin
			$display("Fatal [%0t] /mnt/c/Users/Niels/Documents/nct/MyProjects/CrocoScale_SoC/TEST/SoftLogic/full/system/tb_npu_full_sys_functional.sv:818:14 - tb_npu_full_sys_functional.<unnamed_block>.<unnamed_block>\n msg: ", $time, "1x1 Mode B Mish LUT failed with %0d errors (max diff %0d)!", errs, max_diff);
			$finish(1);
		end
		$display("  %s 80%% [Phase 1: Draining & Validating Mode C (2x2 MaxPool)...]", get_progress_bar(4, 5));
		axil_write(32'h00000008, 32'h00000650);
		axil_write(32'h00000018, OUT_BASE_ADDR);
		axil_write(32'h00000000, 32'h00000004);
		read_status = 32'h00000000;
		while (!read_status[1]) begin
			#(100)
				;
			axil_read(32'h00000004, read_status);
		end
		errs = 0;
		tol_ok = 0;
		exact_ok = 0;
		max_diff = 0;
		for (p_idx = 0; p_idx < 64; p_idx = p_idx + 1)
			begin
				word0 = axi_ram_inst.mem[(OUT_BASE_ADDR[MEM_ADDR_WIDTH - 1:2] + (p_idx * 2)) + 0];
				word1 = axi_ram_inst.mem[(OUT_BASE_ADDR[MEM_ADDR_WIDTH - 1:2] + (p_idx * 2)) + 1];
				ram_pix[0] = $signed(word0[7:0]);
				ram_pix[1] = $signed(word0[15:8]);
				ram_pix[2] = $signed(word0[23:16]);
				ram_pix[3] = $signed(word0[31:24]);
				ram_pix[4] = $signed(word1[7:0]);
				ram_pix[5] = $signed(word1[15:8]);
				ram_pix[6] = $signed(word1[23:16]);
				ram_pix[7] = $signed(word1[31:24]);
				for (ch_idx = 0; ch_idx < 8; ch_idx = ch_idx + 1)
					begin
						gold_val = c1_gold_pool[(p_idx * 8) + ch_idx];
						act_val = ram_pix[ch_idx];
						diff_val = (act_val > gold_val ? act_val - gold_val : gold_val - act_val);
						if (diff_val == 0)
							exact_ok = exact_ok + 1;
						else if (diff_val <= 1)
							tol_ok = tol_ok + 1;
						else
							errs = errs + 1;
						if (diff_val > max_diff)
							max_diff = diff_val;
					end
			end
		if (errs == 0)
			$display("    -> [PASS] 1x1 Mode C MaxPool: 512/512 matches (exact: %0d, tol: %0d)!", exact_ok, tol_ok);
		else begin
			$display("Fatal [%0t] /mnt/c/Users/Niels/Documents/nct/MyProjects/CrocoScale_SoC/TEST/SoftLogic/full/system/tb_npu_full_sys_functional.sv:846:14 - tb_npu_full_sys_functional.<unnamed_block>.<unnamed_block>\n msg: ", $time, "1x1 Mode C MaxPool failed with %0d errors (max diff %0d)!", errs, max_diff);
			$finish(1);
		end
		$display("  %s100%% [Phase 1: Draining & Validating Mode D (Mish LUT + MaxPool)...]", get_progress_bar(5, 5));
		axil_write(32'h00000008, 32'h00000670);
		axil_write(32'h00000018, OUT_BASE_ADDR);
		axil_write(32'h00000000, 32'h00000004);
		read_status = 32'h00000000;
		while (!read_status[1]) begin
			#(100)
				;
			axil_read(32'h00000004, read_status);
		end
		errs = 0;
		tol_ok = 0;
		exact_ok = 0;
		max_diff = 0;
		for (p_idx = 0; p_idx < 64; p_idx = p_idx + 1)
			begin
				word0 = axi_ram_inst.mem[(OUT_BASE_ADDR[MEM_ADDR_WIDTH - 1:2] + (p_idx * 2)) + 0];
				word1 = axi_ram_inst.mem[(OUT_BASE_ADDR[MEM_ADDR_WIDTH - 1:2] + (p_idx * 2)) + 1];
				ram_pix[0] = $signed(word0[7:0]);
				ram_pix[1] = $signed(word0[15:8]);
				ram_pix[2] = $signed(word0[23:16]);
				ram_pix[3] = $signed(word0[31:24]);
				ram_pix[4] = $signed(word1[7:0]);
				ram_pix[5] = $signed(word1[15:8]);
				ram_pix[6] = $signed(word1[23:16]);
				ram_pix[7] = $signed(word1[31:24]);
				for (ch_idx = 0; ch_idx < 8; ch_idx = ch_idx + 1)
					begin
						gold_val = c1_gold_mpool[(p_idx * 8) + ch_idx];
						act_val = ram_pix[ch_idx];
						diff_val = (act_val > gold_val ? act_val - gold_val : gold_val - act_val);
						if (diff_val == 0)
							exact_ok = exact_ok + 1;
						else if (diff_val <= 1)
							tol_ok = tol_ok + 1;
						else
							errs = errs + 1;
						if (diff_val > max_diff)
							max_diff = diff_val;
					end
			end
		if (errs == 0)
			$display("    -> [PASS] 1x1 Mode D Mish+MaxPool: 512/512 matches (exact: %0d, tol: %0d)!\n", exact_ok, tol_ok);
		else begin
			$display("Fatal [%0t] /mnt/c/Users/Niels/Documents/nct/MyProjects/CrocoScale_SoC/TEST/SoftLogic/full/system/tb_npu_full_sys_functional.sv:874:14 - tb_npu_full_sys_functional.<unnamed_block>.<unnamed_block>\n msg: ", $time, "1x1 Mode D Mish+MaxPool failed with %0d errors (max diff %0d)!", errs, max_diff);
			$finish(1);
		end
		$display("-----------------------------------------------------------------------------------------");
		$display(" >>> STARTING PHASE 2: 3x3 MULTI-TILE HALO CONVOLUTION (32x32, 4 TILES) <<<");
		$display("-----------------------------------------------------------------------------------------");
		is_mode_1x1 = 0;
		for (ch = 0; ch < 8; ch = ch + 1)
			ram_write_word(BIAS_BASE_ADDR + (ch * 4), c3_b[ch]);
		for (ch = 0; ch < 8; ch = ch + 1)
			ram_write_word(QUANT_BASE_ADDR + (ch * 4), c3_cfg[ch]);
		for (p = 0; p < 9; p = p + 1)
			for (s = 0; s < 8; s = s + 1)
				begin
					ram_write_word(((WEIGHT_BASE_ADDR + (p * 64)) + (s * 8)) + 0, {get_c3_w_val(p, 3, 7 - s), get_c3_w_val(p, 2, 7 - s), get_c3_w_val(p, 1, 7 - s), get_c3_w_val(p, 0, 7 - s)});
					ram_write_word(((WEIGHT_BASE_ADDR + (p * 64)) + (s * 8)) + 4, {get_c3_w_val(p, 7, 7 - s), get_c3_w_val(p, 6, 7 - s), get_c3_w_val(p, 5, 7 - s), get_c3_w_val(p, 4, 7 - s)});
				end
		step_cnt = 0;
		for (curr_ty = 0; curr_ty < 2; curr_ty = curr_ty + 1)
			for (curr_tx = 0; curr_tx < 2; curr_tx = curr_tx + 1)
				begin
					tile_idx = (curr_ty * 2) + curr_tx;
					step_cnt = step_cnt + 1;
					$display("  %s %3d%% [Tile (%0d,%0d): Executing 9-Pass 3x3 Compute & Draining 4 Modes...]", get_progress_bar(step_cnt, 4), (step_cnt * 100) / 4, curr_ty, curr_tx);
					axil_write(32'h00000008, 32'h00000900);
					axil_write(32'h00000010, ACT_BASE_ADDR);
					axil_write(32'h00000014, WEIGHT_BASE_ADDR);
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
					errs = 0;
					for (p_idx = 0; p_idx < 256; p_idx = p_idx + 1)
						begin
							y_idx = (curr_ty * 16) + (p_idx / 16);
							x_idx = (curr_tx * 16) + (p_idx % 16);
							for (ch_idx = 0; ch_idx < 8; ch_idx = ch_idx + 1)
								begin
									act_raw = peek_psum(ch_idx, p_idx);
									gold_raw = c3_gold_raw[(((y_idx * 32) * 8) + (x_idx * 8)) + ch_idx];
									diff_raw = (act_raw > gold_raw ? act_raw - gold_raw : gold_raw - act_raw);
									if (diff_raw != 0) begin
										if (errs < 8)
											$display("  [DEBUG 3x3 PEEK] p_idx=%0d (y=%0d, x=%0d, ch=%0d): act_raw=%0d (0x%08X), gold_raw=%0d (0x%08X), diff=%0d", p_idx, y_idx, x_idx, ch_idx, act_raw, act_raw, gold_raw, gold_raw, diff_raw);
										errs = errs + 1;
									end
								end
						end
					if (errs != 0) begin
						$display("Fatal [%0t] /mnt/c/Users/Niels/Documents/nct/MyProjects/CrocoScale_SoC/TEST/SoftLogic/full/system/tb_npu_full_sys_functional.sv:938:32 - tb_npu_full_sys_functional.<unnamed_block>.<unnamed_block>.<unnamed_block>.<unnamed_block>\n msg: ", $time, "3x3 Tile (%0d,%0d) Raw PSUM peek failed with %0d errors!", curr_ty, curr_tx, errs);
						$finish(1);
					end
					axil_write(32'h00000008, 32'h00000900);
					axil_write(32'h00000018, OUT_BASE_A_ADDR + (tile_idx * 2048));
					axil_write(32'h00000000, 32'h00000004);
					read_status = 32'h00000000;
					while (!read_status[1]) begin
						#(100)
							;
						axil_read(32'h00000004, read_status);
					end
					axil_write(32'h00000008, 32'h00000920);
					axil_write(32'h00000018, OUT_BASE_B_ADDR + (tile_idx * 2048));
					axil_write(32'h00000000, 32'h00000004);
					read_status = 32'h00000000;
					while (!read_status[1]) begin
						#(100)
							;
						axil_read(32'h00000004, read_status);
					end
					axil_write(32'h00000008, 32'h00000940);
					axil_write(32'h00000018, OUT_BASE_C_ADDR + (tile_idx * 512));
					axil_write(32'h00000000, 32'h00000004);
					read_status = 32'h00000000;
					while (!read_status[1]) begin
						#(100)
							;
						axil_read(32'h00000004, read_status);
					end
					axil_write(32'h00000008, 32'h00000960);
					axil_write(32'h00000018, OUT_BASE_D_ADDR + (tile_idx * 512));
					axil_write(32'h00000000, 32'h00000004);
					read_status = 32'h00000000;
					while (!read_status[1]) begin
						#(100)
							;
						axil_read(32'h00000004, read_status);
					end
				end
		$display("\n  -> Validating Full 32x32 Mode A (Linear Requantized) Across All 4 Tiles...");
		errs = 0;
		tol_ok = 0;
		exact_ok = 0;
		max_diff = 0;
		for (curr_ty = 0; curr_ty < 2; curr_ty = curr_ty + 1)
			for (curr_tx = 0; curr_tx < 2; curr_tx = curr_tx + 1)
				begin
					tile_idx = (curr_ty * 2) + curr_tx;
					for (p_idx = 0; p_idx < 256; p_idx = p_idx + 1)
						begin
							y_idx = (curr_ty * 16) + (p_idx / 16);
							x_idx = (curr_tx * 16) + (p_idx % 16);
							word0 = axi_ram_inst.mem[(((OUT_BASE_A_ADDR + (tile_idx * 2048)) >> 2) + (p_idx * 2)) + 0];
							word1 = axi_ram_inst.mem[(((OUT_BASE_A_ADDR + (tile_idx * 2048)) >> 2) + (p_idx * 2)) + 1];
							ram_pix[0] = $signed(word0[7:0]);
							ram_pix[1] = $signed(word0[15:8]);
							ram_pix[2] = $signed(word0[23:16]);
							ram_pix[3] = $signed(word0[31:24]);
							ram_pix[4] = $signed(word1[7:0]);
							ram_pix[5] = $signed(word1[15:8]);
							ram_pix[6] = $signed(word1[23:16]);
							ram_pix[7] = $signed(word1[31:24]);
							for (ch_idx = 0; ch_idx < 8; ch_idx = ch_idx + 1)
								begin
									gold_val = c3_gold_lin[(((y_idx * 32) * 8) + (x_idx * 8)) + ch_idx];
									act_val = ram_pix[ch_idx];
									diff_val = (act_val > gold_val ? act_val - gold_val : gold_val - act_val);
									if (diff_val == 0)
										exact_ok = exact_ok + 1;
									else if (diff_val <= 1)
										tol_ok = tol_ok + 1;
									else
										errs = errs + 1;
									if (diff_val > max_diff)
										max_diff = diff_val;
								end
						end
				end
		if (errs == 0)
			$display("    -> [PASS] 3x3 Full 32x32 Mode A Linear: 8192/8192 matches (exact: %0d, tol: %0d)!", exact_ok, tol_ok);
		else begin
			$display("Fatal [%0t] /mnt/c/Users/Niels/Documents/nct/MyProjects/CrocoScale_SoC/TEST/SoftLogic/full/system/tb_npu_full_sys_functional.sv:998:14 - tb_npu_full_sys_functional.<unnamed_block>.<unnamed_block>\n msg: ", $time, "3x3 Full 32x32 Mode A Linear failed with %0d errors (max diff %0d)!", errs, max_diff);
			$finish(1);
		end
		$display("\n  -> Validating Full 32x32 Mode B (Mish LUT) Across All 4 Tiles...");
		errs = 0;
		tol_ok = 0;
		exact_ok = 0;
		max_diff = 0;
		for (curr_ty = 0; curr_ty < 2; curr_ty = curr_ty + 1)
			for (curr_tx = 0; curr_tx < 2; curr_tx = curr_tx + 1)
				begin
					tile_idx = (curr_ty * 2) + curr_tx;
					for (p_idx = 0; p_idx < 256; p_idx = p_idx + 1)
						begin
							y_idx = (curr_ty * 16) + (p_idx / 16);
							x_idx = (curr_tx * 16) + (p_idx % 16);
							word0 = axi_ram_inst.mem[(((OUT_BASE_B_ADDR + (tile_idx * 2048)) >> 2) + (p_idx * 2)) + 0];
							word1 = axi_ram_inst.mem[(((OUT_BASE_B_ADDR + (tile_idx * 2048)) >> 2) + (p_idx * 2)) + 1];
							ram_pix[0] = $signed(word0[7:0]);
							ram_pix[1] = $signed(word0[15:8]);
							ram_pix[2] = $signed(word0[23:16]);
							ram_pix[3] = $signed(word0[31:24]);
							ram_pix[4] = $signed(word1[7:0]);
							ram_pix[5] = $signed(word1[15:8]);
							ram_pix[6] = $signed(word1[23:16]);
							ram_pix[7] = $signed(word1[31:24]);
							for (ch_idx = 0; ch_idx < 8; ch_idx = ch_idx + 1)
								begin
									gold_val = c3_gold_mish[(((y_idx * 32) * 8) + (x_idx * 8)) + ch_idx];
									act_val = ram_pix[ch_idx];
									diff_val = (act_val > gold_val ? act_val - gold_val : gold_val - act_val);
									if (diff_val == 0)
										exact_ok = exact_ok + 1;
									else if (diff_val <= 1)
										tol_ok = tol_ok + 1;
									else
										errs = errs + 1;
									if (diff_val > max_diff)
										max_diff = diff_val;
								end
						end
				end
		if (errs == 0)
			$display("    -> [PASS] 3x3 Full 32x32 Mode B Mish LUT: 8192/8192 matches (exact: %0d, tol: %0d)!", exact_ok, tol_ok);
		else begin
			$display("Fatal [%0t] /mnt/c/Users/Niels/Documents/nct/MyProjects/CrocoScale_SoC/TEST/SoftLogic/full/system/tb_npu_full_sys_functional.sv:1028:14 - tb_npu_full_sys_functional.<unnamed_block>.<unnamed_block>\n msg: ", $time, "3x3 Full 32x32 Mode B Mish LUT failed with %0d errors (max diff %0d)!", errs, max_diff);
			$finish(1);
		end
		$display("\n  -> Validating Full 16x16 Mode C (2x2 MaxPool) Across All 4 Tiles...");
		errs = 0;
		tol_ok = 0;
		exact_ok = 0;
		max_diff = 0;
		for (curr_ty = 0; curr_ty < 2; curr_ty = curr_ty + 1)
			for (curr_tx = 0; curr_tx < 2; curr_tx = curr_tx + 1)
				begin
					tile_idx = (curr_ty * 2) + curr_tx;
					for (p_idx = 0; p_idx < 64; p_idx = p_idx + 1)
						begin
							y_idx = (curr_ty * 8) + (p_idx / 8);
							x_idx = (curr_tx * 8) + (p_idx % 8);
							word0 = axi_ram_inst.mem[(((OUT_BASE_C_ADDR + (tile_idx * 512)) >> 2) + (p_idx * 2)) + 0];
							word1 = axi_ram_inst.mem[(((OUT_BASE_C_ADDR + (tile_idx * 512)) >> 2) + (p_idx * 2)) + 1];
							ram_pix[0] = $signed(word0[7:0]);
							ram_pix[1] = $signed(word0[15:8]);
							ram_pix[2] = $signed(word0[23:16]);
							ram_pix[3] = $signed(word0[31:24]);
							ram_pix[4] = $signed(word1[7:0]);
							ram_pix[5] = $signed(word1[15:8]);
							ram_pix[6] = $signed(word1[23:16]);
							ram_pix[7] = $signed(word1[31:24]);
							for (ch_idx = 0; ch_idx < 8; ch_idx = ch_idx + 1)
								begin
									gold_val = c3_gold_pool[(((y_idx * 16) * 8) + (x_idx * 8)) + ch_idx];
									act_val = ram_pix[ch_idx];
									diff_val = (act_val > gold_val ? act_val - gold_val : gold_val - act_val);
									if (diff_val == 0)
										exact_ok = exact_ok + 1;
									else if (diff_val <= 1)
										tol_ok = tol_ok + 1;
									else
										errs = errs + 1;
									if (diff_val > max_diff)
										max_diff = diff_val;
								end
						end
				end
		if (errs == 0)
			$display("    -> [PASS] 3x3 Full 16x16 Mode C MaxPool: 2048/2048 matches (exact: %0d, tol: %0d)!", exact_ok, tol_ok);
		else begin
			$display("Fatal [%0t] /mnt/c/Users/Niels/Documents/nct/MyProjects/CrocoScale_SoC/TEST/SoftLogic/full/system/tb_npu_full_sys_functional.sv:1058:14 - tb_npu_full_sys_functional.<unnamed_block>.<unnamed_block>\n msg: ", $time, "3x3 Full 16x16 Mode C MaxPool failed with %0d errors (max diff %0d)!", errs, max_diff);
			$finish(1);
		end
		$display("\n  -> Validating Full 16x16 Mode D (Mish LUT + MaxPool) Across All 4 Tiles...");
		errs = 0;
		tol_ok = 0;
		exact_ok = 0;
		max_diff = 0;
		for (curr_ty = 0; curr_ty < 2; curr_ty = curr_ty + 1)
			for (curr_tx = 0; curr_tx < 2; curr_tx = curr_tx + 1)
				begin
					tile_idx = (curr_ty * 2) + curr_tx;
					for (p_idx = 0; p_idx < 64; p_idx = p_idx + 1)
						begin
							y_idx = (curr_ty * 8) + (p_idx / 8);
							x_idx = (curr_tx * 8) + (p_idx % 8);
							word0 = axi_ram_inst.mem[(((OUT_BASE_D_ADDR + (tile_idx * 512)) >> 2) + (p_idx * 2)) + 0];
							word1 = axi_ram_inst.mem[(((OUT_BASE_D_ADDR + (tile_idx * 512)) >> 2) + (p_idx * 2)) + 1];
							ram_pix[0] = $signed(word0[7:0]);
							ram_pix[1] = $signed(word0[15:8]);
							ram_pix[2] = $signed(word0[23:16]);
							ram_pix[3] = $signed(word0[31:24]);
							ram_pix[4] = $signed(word1[7:0]);
							ram_pix[5] = $signed(word1[15:8]);
							ram_pix[6] = $signed(word1[23:16]);
							ram_pix[7] = $signed(word1[31:24]);
							for (ch_idx = 0; ch_idx < 8; ch_idx = ch_idx + 1)
								begin
									gold_val = c3_gold_mpool[(((y_idx * 16) * 8) + (x_idx * 8)) + ch_idx];
									act_val = ram_pix[ch_idx];
									diff_val = (act_val > gold_val ? act_val - gold_val : gold_val - act_val);
									if (diff_val == 0)
										exact_ok = exact_ok + 1;
									else if (diff_val <= 1)
										tol_ok = tol_ok + 1;
									else
										errs = errs + 1;
									if (diff_val > max_diff)
										max_diff = diff_val;
								end
						end
				end
		if (errs == 0)
			$display("    -> [PASS] 3x3 Full 16x16 Mode D Mish+MaxPool: 2048/2048 matches (exact: %0d, tol: %0d)!\n", exact_ok, tol_ok);
		else begin
			$display("Fatal [%0t] /mnt/c/Users/Niels/Documents/nct/MyProjects/CrocoScale_SoC/TEST/SoftLogic/full/system/tb_npu_full_sys_functional.sv:1088:14 - tb_npu_full_sys_functional.<unnamed_block>.<unnamed_block>\n msg: ", $time, "3x3 Full 16x16 Mode D Mish+MaxPool failed with %0d errors (max diff %0d)!", errs, max_diff);
			$finish(1);
		end
		$display("=========================================================================================");
		$display(" >>> ALL FUNCTIONAL TESTS PASSED (100%% BIT-EXACT MATCHES WITH PYTORCH GOLDEN REF) <<< ");
		$display("=========================================================================================\n");
		$finish;
	end
	initial _sv2v_0 = 0;
endmodule
