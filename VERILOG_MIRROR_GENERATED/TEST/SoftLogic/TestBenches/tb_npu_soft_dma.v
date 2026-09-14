module tb_npu_soft_dma;
	reg clk;
	reg rst_n;
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
	reg [31:0] act_base;
	reg [31:0] weight_base;
	reg [31:0] out_base;
	reg start_act;
	wire act_done;
	reg start_weight;
	reg [3:0] weight_pass_idx;
	wire weight_done;
	wire signed [63:0] weight_shift_in;
	wire [1:0] weight_shift_en;
	reg start_drain;
	wire drain_done;
	wire [7:0] drain_psum_addr;
	reg signed [63:0] npu_out_act;
	wire [7:0] ext_act_sram_we;
	wire [71:0] ext_act_sram_addr;
	wire signed [63:0] ext_act_sram_wdata;
	initial clk = 0;
	always #(5) clk = ~clk;
	localparam signed [31:0] MEM_ADDR_WIDTH = 16;
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
	npu_soft_dma #(
		.ARRAY_HEIGHT(8),
		.ARRAY_WIDTH(8),
		.TILE_SIZE(16),
		.ACT_HALO_PAD(2),
		.ACTIVATION_WIDTH(8),
		.WEIGHT_WIDTH(8),
		.AXI_ADDR_WIDTH(32),
		.AXI_DATA_WIDTH(32)
	) dut(
		.clk_i(clk),
		.rst_n(rst_n),
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
		.act_base_i(act_base),
		.weight_base_i(weight_base),
		.out_base_i(out_base),
		.start_act_i(start_act),
		.act_done_o(act_done),
		.start_weight_i(start_weight),
		.weight_pass_idx_i(weight_pass_idx),
		.weight_done_o(weight_done),
		.weight_shift_in_o(weight_shift_in),
		.weight_shift_en_o(weight_shift_en),
		.start_drain_i(start_drain),
		.drain_done_o(drain_done),
		.drain_psum_addr_o(drain_psum_addr),
		.npu_out_act_i(npu_out_act),
		.ext_act_sram_we_o(ext_act_sram_we),
		.ext_act_sram_addr_o(ext_act_sram_addr),
		.ext_act_sram_wdata_o(ext_act_sram_wdata)
	);
	reg [7:0] drain_addr_d1;
	reg [7:0] drain_addr_d2;
	function automatic [7:0] sv2v_cast_8;
		input reg [7:0] inp;
		sv2v_cast_8 = inp;
	endfunction
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			drain_addr_d1 <= 1'sb0;
			drain_addr_d2 <= 1'sb0;
			npu_out_act <= 1'sb0;
		end
		else begin
			drain_addr_d1 <= drain_psum_addr;
			drain_addr_d2 <= drain_addr_d1;
			begin : sv2v_autoblock_1
				reg signed [31:0] c;
				for (c = 0; c < 8; c = c + 1)
					npu_out_act[c * 8+:8] <= $signed(sv2v_cast_8((drain_addr_d2 * 8) + c));
			end
		end
	task automatic ram_write_byte;
		input reg signed [31:0] addr;
		input reg [7:0] val;
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
	task automatic ram_read_byte;
		input reg signed [31:0] addr;
		output reg [7:0] val;
		reg signed [31:0] word_addr;
		reg signed [31:0] byte_lane;
		begin
			word_addr = addr >> 2;
			byte_lane = addr & 2'd3;
			case (byte_lane)
				2'd0: val = axi_ram_inst.mem[word_addr][7:0];
				2'd1: val = axi_ram_inst.mem[word_addr][15:8];
				2'd2: val = axi_ram_inst.mem[word_addr][23:16];
				2'd3: val = axi_ram_inst.mem[word_addr][31:24];
			endcase
		end
	endtask
	reg signed [7:0] mock_sram [0:7][0:511];
	always @(posedge clk) begin : sv2v_autoblock_2
		reg signed [31:0] b;
		for (b = 0; b < 8; b = b + 1)
			if (ext_act_sram_we[b])
				mock_sram[b][ext_act_sram_addr[b * 9+:9]] <= ext_act_sram_wdata[b * 8+:8];
	end
	reg signed [7:0] mock_pe_shadow [0:7][0:7];
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin : sv2v_autoblock_3
			reg signed [31:0] r_idx;
			for (r_idx = 0; r_idx < 8; r_idx = r_idx + 1)
				begin : sv2v_autoblock_4
					reg signed [31:0] c_idx;
					for (c_idx = 0; c_idx < 8; c_idx = c_idx + 1)
						mock_pe_shadow[r_idx][c_idx] <= 1'sb0;
				end
		end
		else begin : sv2v_autoblock_5
			reg signed [31:0] r_idx;
			for (r_idx = 0; r_idx < 8; r_idx = r_idx + 1)
				if ((r_idx < 4 ? weight_shift_en[0] : weight_shift_en[1])) begin
					mock_pe_shadow[r_idx][0] <= weight_shift_in[r_idx * 8+:8];
					begin : sv2v_autoblock_6
						reg signed [31:0] c_idx;
						for (c_idx = 1; c_idx < 8; c_idx = c_idx + 1)
							mock_pe_shadow[r_idx][c_idx] <= mock_pe_shadow[r_idx][c_idx - 1];
					end
				end
		end
	reg signed [31:0] errors = 0;
	function automatic signed [7:0] sv2v_cast_8_signed;
		input reg signed [7:0] inp;
		sv2v_cast_8_signed = inp;
	endfunction
	initial begin : sv2v_autoblock_7
		reg signed [31:0] i;
		reg signed [31:0] p;
		reg signed [31:0] ch;
		reg signed [31:0] r;
		reg signed [31:0] c;
		reg signed [7:0] expected_w;
		reg signed [7:0] expected_act;
		reg [7:0] expected_out;
		reg [7:0] actual_out;
		$display("\n==========================================================");
		$display(">>> Starting Unit Test: npu_soft_dma (AXI4 Burst DMA) <<<");
		$display("==========================================================");
		rst_n = 0;
		act_base = 32'h00001000;
		weight_base = 32'h00002000;
		out_base = 32'h00003000;
		start_act = 0;
		start_weight = 0;
		weight_pass_idx = 0;
		start_drain = 0;
		#(30)
			;
		@(negedge clk)
			;
		rst_n = 1;
		#(30)
			;
		$display("[Test 1] Testing Weight Fetch (16-beat INCR burst direct streaming)...");
		begin : sv2v_autoblock_8
			reg signed [31:0] s;
			for (s = 0; s < 8; s = s + 1)
				begin : sv2v_autoblock_9
					reg signed [31:0] r_idx;
					for (r_idx = 0; r_idx < 8; r_idx = r_idx + 1)
						ram_write_byte((weight_base + (s * 8)) + r_idx, sv2v_cast_8_signed(((r_idx * 8) + (7 - s)) + 10));
				end
		end
		@(posedge clk)
			;
		start_weight <= 1'b1;
		weight_pass_idx <= 4'd0;
		@(posedge clk)
			;
		start_weight <= 1'b0;
		while (!weight_done) @(posedge clk)
			;
		$display("   Weight DMA completed. Verifying shadow registers...");
		for (r = 0; r < 8; r = r + 1)
			for (c = 0; c < 8; c = c + 1)
				begin
					expected_w = $signed(sv2v_cast_8_signed(((r * 8) + c) + 10));
					if (mock_pe_shadow[r][c] !== expected_w) begin
						$display("   [ERROR] mock_pe_shadow[%0d][%0d] expected %0d, got %0d", r, c, expected_w, mock_pe_shadow[r][c]);
						errors = errors + 1;
					end
				end
		$display("[Test 2] Testing Activation Fetch (648 words across 41 bursts)...");
		for (p = 0; p < 324; p = p + 1)
			for (ch = 0; ch < 8; ch = ch + 1)
				ram_write_byte((act_base + (p * 8)) + ch, sv2v_cast_8_signed(((p * 7) + (ch * 3)) % 256));
		@(posedge clk)
			;
		start_act <= 1'b1;
		@(posedge clk)
			;
		start_act <= 1'b0;
		while (!act_done) @(posedge clk)
			;
		$display("   Activation DMA completed. Verifying SRAM write integrity...");
		for (p = 0; p < 324; p = p + 1)
			for (ch = 0; ch < 8; ch = ch + 1)
				begin
					expected_act = $signed(sv2v_cast_8_signed(((p * 7) + (ch * 3)) % 256));
					if (mock_sram[ch][p] !== expected_act) begin
						$display("   [ERROR] mock_sram[%0d][%0d] expected %0d, got %0d", ch, p, expected_act, mock_sram[ch][p]);
						errors = errors + 1;
					end
				end
		$display("[Test 3] Testing Output Drain Store (32 bursts x 16 beats)...");
		@(posedge clk)
			;
		start_drain <= 1'b1;
		@(posedge clk)
			;
		start_drain <= 1'b0;
		while (!drain_done) @(posedge clk)
			;
		$display("   Drain DMA completed. Verifying AXI RAM output tensor...");
		for (p = 0; p < 256; p = p + 1)
			for (ch = 0; ch < 8; ch = ch + 1)
				begin
					expected_out = sv2v_cast_8_signed((p * 8) + ch);
					ram_read_byte((out_base + (p * 8)) + ch, actual_out);
					if (actual_out !== expected_out) begin
						$display("   [ERROR] out_ram pixel %0d ch %0d expected 0x%02X, got 0x%02X", p, ch, expected_out, actual_out);
						errors = errors + 1;
					end
				end
		$display("----------------------------------------------------------");
		if (errors == 0)
			$display(">>> SUCCESS: npu_soft_dma Unit Test Passed 100%%! <<<");
		else
			$display(">>> FAILURE: %0d Errors Detected in npu_soft_dma! <<<", errors);
		$display("==========================================================\n");
		#(50)
			;
		$finish;
	end
endmodule
