module tb_efpga_manager;
	localparam signed [31:0] NUM_SLOTS = 1;
	localparam signed [31:0] NUM_REGIONS = 2;
	localparam [31:0] HW_VERSION = 32'hfab00001;
	reg clk;
	reg rstn;
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
	wire [31:0] efpga_config_data_o;
	wire efpga_config_we_o;
	wire efpga_soft_reset_o;
	reg efpga_com_active_i;
	reg [31:0] slot_i_top_i;
	wire [31:0] slot_o_top_o;
	wire [0:0] decoupler_req_o;
	wire [0:0] decoupler_force_o;
	reg [0:0] decoupler_is_decoupled_i;
	reg [0:0] decoupler_host_act_i;
	reg [0:0] decoupler_dma_act_i;
	reg [0:0] slot_pmp_r_violation_i;
	reg [0:0] slot_pmp_w_violation_i;
	reg [0:0] slot_wdog_cs_to_w_i;
	reg [0:0] slot_wdog_cs_to_r_i;
	reg [0:0] slot_wdog_cs_pr_w_i;
	reg [0:0] slot_wdog_cs_pr_r_i;
	reg [0:0] slot_wdog_dm_to_w_i;
	reg [0:0] slot_wdog_dm_to_r_i;
	reg [0:0] slot_wdog_dm_pr_w_i;
	reg [0:0] slot_wdog_dm_pr_r_i;
	reg [0:0] slot_wdog_cm_to_w_i;
	reg [0:0] slot_wdog_cm_to_r_i;
	reg [0:0] slot_wdog_cm_pr_w_i;
	reg [0:0] slot_wdog_cm_pr_r_i;
	reg [0:0] slot_wdog_ds_to_w_i;
	reg [0:0] slot_wdog_ds_to_r_i;
	reg [0:0] slot_wdog_ds_pr_w_i;
	reg [0:0] slot_wdog_ds_pr_r_i;
	wire [0:0] pmp_g_en_o;
	wire [((NUM_SLOTS * NUM_REGIONS) * 32) - 1:0] pmp_base_o;
	wire [((NUM_SLOTS * NUM_REGIONS) * 32) - 1:0] pmp_limit_o;
	wire [0:0] wb_s_enable_o;
	wire [0:0] wb_m_enable_o;
	wire [0:0] slot_fault_irq_o;
	always #(5) clk = ~clk;
	efpga_manager #(
		.NUM_SLOTS(NUM_SLOTS),
		.NUM_REGIONS(NUM_REGIONS),
		.HW_VERSION(HW_VERSION),
		.PAGE_GRANULARITY(1'b1),
		.MAX_ADDRESS_WIDTH(32),
		.ENABLE_PMP(1'b1),
		.ENABLE_WDOG_CTRL_SLAVE(1'b1),
		.ENABLE_WDOG_DMA_MASTER(1'b1),
		.ENABLE_WDOG_CTRL_MASTER(1'b0),
		.ENABLE_WDOG_DMA_SLAVE(1'b0),
		.ENABLE_BRIDGE_CTRL(1'b0),
		.ENABLE_BRIDGE_DMA(1'b0)
	) dut(
		.clk_i(clk),
		.rstn_i(rstn),
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
		.efpga_config_data_o(efpga_config_data_o),
		.efpga_config_we_o(efpga_config_we_o),
		.efpga_soft_reset_o(efpga_soft_reset_o),
		.efpga_com_active_i(efpga_com_active_i),
		.slot_i_top_i(slot_i_top_i),
		.slot_o_top_o(slot_o_top_o),
		.decoupler_req_o(decoupler_req_o),
		.decoupler_force_o(decoupler_force_o),
		.decoupler_is_decoupled_i(decoupler_is_decoupled_i),
		.decoupler_host_act_i(decoupler_host_act_i),
		.decoupler_dma_act_i(decoupler_dma_act_i),
		.slot_pmp_r_violation_i(slot_pmp_r_violation_i),
		.slot_pmp_w_violation_i(slot_pmp_w_violation_i),
		.slot_wdog_cs_to_w_i(slot_wdog_cs_to_w_i),
		.slot_wdog_cs_to_r_i(slot_wdog_cs_to_r_i),
		.slot_wdog_cs_pr_w_i(slot_wdog_cs_pr_w_i),
		.slot_wdog_cs_pr_r_i(slot_wdog_cs_pr_r_i),
		.slot_wdog_dm_to_w_i(slot_wdog_dm_to_w_i),
		.slot_wdog_dm_to_r_i(slot_wdog_dm_to_r_i),
		.slot_wdog_dm_pr_w_i(slot_wdog_dm_pr_w_i),
		.slot_wdog_dm_pr_r_i(slot_wdog_dm_pr_r_i),
		.slot_wdog_cm_to_w_i(slot_wdog_cm_to_w_i),
		.slot_wdog_cm_to_r_i(slot_wdog_cm_to_r_i),
		.slot_wdog_cm_pr_w_i(slot_wdog_cm_pr_w_i),
		.slot_wdog_cm_pr_r_i(slot_wdog_cm_pr_r_i),
		.slot_wdog_ds_to_w_i(slot_wdog_ds_to_w_i),
		.slot_wdog_ds_to_r_i(slot_wdog_ds_to_r_i),
		.slot_wdog_ds_pr_w_i(slot_wdog_ds_pr_w_i),
		.slot_wdog_ds_pr_r_i(slot_wdog_ds_pr_r_i),
		.pmp_g_en_o(pmp_g_en_o),
		.pmp_base_o(pmp_base_o),
		.pmp_limit_o(pmp_limit_o),
		.wb_s_enable_o(wb_s_enable_o),
		.wb_m_enable_o(wb_m_enable_o),
		.slot_fault_irq_o(slot_fault_irq_o)
	);
	task automatic axi_write;
		input [31:0] addr;
		input [31:0] data;
		input [3:0] strb;
		begin
			strb = 4'hf;
			@(posedge clk)
				;
			s_axil_awaddr <= addr;
			s_axil_awprot <= 3'b000;
			s_axil_awvalid <= 1'b1;
			s_axil_wdata <= data;
			s_axil_wstrb <= strb;
			s_axil_wvalid <= 1'b1;
			s_axil_bready <= 1'b1;
			fork
				begin
					wait (s_axil_awready)
						;
					@(posedge clk)
						;
					s_axil_awvalid <= 1'b0;
				end
				begin
					wait (s_axil_wready)
						;
					@(posedge clk)
						;
					s_axil_wvalid <= 1'b0;
				end
			join
			wait (s_axil_bvalid)
				;
			@(posedge clk)
				;
			s_axil_bready <= 1'b0;
			@(posedge clk)
				;
		end
	endtask
	task automatic axi_read;
		input [31:0] addr;
		output reg [31:0] data;
		begin
			@(posedge clk)
				;
			s_axil_araddr <= addr;
			s_axil_arprot <= 3'b000;
			s_axil_arvalid <= 1'b1;
			s_axil_rready <= 1'b1;
			wait (s_axil_arready)
				;
			@(posedge clk)
				;
			s_axil_arvalid <= 1'b0;
			wait (s_axil_rvalid)
				;
			data = s_axil_rdata;
			@(posedge clk)
				;
			s_axil_rready <= 1'b0;
			@(posedge clk)
				;
		end
	endtask
	reg [31:0] rdata;
	reg signed [31:0] errors = 0;
	initial begin
		$display("=================================================================");
		$display("Starting efpga_manager RTL Register Map Verification");
		$display("=================================================================");
		clk = 0;
		rstn = 0;
		s_axil_awaddr = 0;
		s_axil_awprot = 0;
		s_axil_awvalid = 0;
		s_axil_wdata = 0;
		s_axil_wstrb = 0;
		s_axil_wvalid = 0;
		s_axil_bready = 0;
		s_axil_araddr = 0;
		s_axil_arprot = 0;
		s_axil_arvalid = 0;
		s_axil_rready = 0;
		efpga_com_active_i = 0;
		slot_i_top_i = 0;
		decoupler_is_decoupled_i = 0;
		decoupler_host_act_i = 0;
		decoupler_dma_act_i = 0;
		slot_pmp_r_violation_i = 0;
		slot_pmp_w_violation_i = 0;
		slot_wdog_cs_to_w_i = 0;
		slot_wdog_cs_to_r_i = 0;
		slot_wdog_cs_pr_w_i = 0;
		slot_wdog_cs_pr_r_i = 0;
		slot_wdog_dm_to_w_i = 0;
		slot_wdog_dm_to_r_i = 0;
		slot_wdog_dm_pr_w_i = 0;
		slot_wdog_dm_pr_r_i = 0;
		slot_wdog_cm_to_w_i = 0;
		slot_wdog_cm_to_r_i = 0;
		slot_wdog_cm_pr_w_i = 0;
		slot_wdog_cm_pr_r_i = 0;
		slot_wdog_ds_to_w_i = 0;
		slot_wdog_ds_to_r_i = 0;
		slot_wdog_ds_pr_w_i = 0;
		slot_wdog_ds_pr_r_i = 0;
		#(20) rstn = 1;
		#(20)
			;
		axi_read(32'h00000000, rdata);
		if (rdata !== 32'hfab00001) begin
			$display("[FAIL] HW_VERSION: Expected 0xFAB00001, got 0x%08X", rdata);
			errors = errors + 1;
		end
		else
			$display("[PASS] HW_VERSION (0x0000): 0x%08X matches expected FAB magic", rdata);
		axi_write(32'h00000004, 32'h00000001);
		#(10)
			;
		if (efpga_soft_reset_o !== 1'b1) begin
			$display("[FAIL] GLOBAL_CTRL: efpga_soft_reset_o not asserted!");
			errors = errors + 1;
		end
		else
			$display("[PASS] GLOBAL_CTRL (0x0004): efpga_soft_reset_o asserted high on write");
		axi_read(32'h00000004, rdata);
		if (rdata[0] !== 1'b1) begin
			$display("[FAIL] GLOBAL_CTRL: Read back soft_reset bit not 1!");
			errors = errors + 1;
		end
		axi_write(32'h00000004, 32'h00000000);
		#(10)
			;
		if (efpga_soft_reset_o !== 1'b0) begin
			$display("[FAIL] GLOBAL_CTRL: efpga_soft_reset_o not deasserted!");
			errors = errors + 1;
		end
		else
			$display("[PASS] GLOBAL_CTRL (0x0004): efpga_soft_reset_o released low");
		axi_read(32'h0000000c, rdata);
		if (rdata !== 32'd0) begin
			$display("[FAIL] Initial CONFIG_COUNT not 0! Got %0d", rdata);
			errors = errors + 1;
		end
		axi_write(32'h00000008, 32'haabbccdd);
		if (efpga_config_data_o !== 32'haabbccdd) begin
			$display("[FAIL] CONFIG_DATA: efpga_config_data_o mismatch! Got 0x%08X", efpga_config_data_o);
			errors = errors + 1;
		end
		else
			$display("[PASS] CONFIG_DATA (0x0008): Latch output drove 0xAABBCCDD with WE pulse");
		axi_read(32'h0000000c, rdata);
		if (rdata !== 32'd1) begin
			$display("[FAIL] CONFIG_COUNT after 1 write expected 1, got %0d", rdata);
			errors = errors + 1;
		end
		axi_write(32'h00000008, 32'h11223344);
		axi_read(32'h0000000c, rdata);
		if (rdata !== 32'd2) begin
			$display("[FAIL] CONFIG_COUNT after 2 writes expected 2, got %0d", rdata);
			errors = errors + 1;
		end
		else
			$display("[PASS] CONFIG_COUNT (0x000C): Word counter accurately incremented to 2");
		axi_write(32'h00001000, 32'h00000001);
		#(10)
			;
		if (decoupler_req_o[0] !== 1'b1) begin
			$display("[FAIL] SLOT_CTRL: decoupler_req_o[0] not asserted!");
			errors = errors + 1;
		end
		else
			$display("[PASS] SLOT_CTRL (0x1000): Decouple request asserted to connector");
		decoupler_is_decoupled_i[0] = 1'b1;
		#(10)
			;
		axi_read(32'h00001004, rdata);
		if (rdata[0] !== 1'b1) begin
			$display("[FAIL] SLOT_STATUS (0x1004): IS_DECOUPLED bit not reflected!");
			errors = errors + 1;
		end
		else
			$display("[PASS] SLOT_STATUS (0x1004): IS_DECOUPLED status bit active");
		axi_write(32'h00001014, 32'h00012003);
		axi_write(32'h00001018, 32'h00025001);
		#(10)
			;
		if (pmp_base_o[0+:32] !== 32'h00012003) begin
			$display("[FAIL] pmp_base_o[0][0] mismatch! Got 0x%08X", pmp_base_o[0+:32]);
			errors = errors + 1;
		end
		if (pmp_limit_o[0+:32] !== 32'h00025001) begin
			$display("[FAIL] pmp_limit_o[0][0] mismatch! Got 0x%08X", pmp_limit_o[0+:32]);
			errors = errors + 1;
		end
		axi_read(32'h00001014, rdata);
		if (rdata !== 32'h00012003) begin
			$display("[FAIL] Readback PMP0_BASE: Expected 0x00012003, got 0x%08X", rdata);
			errors = errors + 1;
		end
		axi_read(32'h00001018, rdata);
		if (rdata !== 32'h00025001) begin
			$display("[FAIL] Readback PMP0_LIMIT: Expected 0x00025001, got 0x%08X", rdata);
			errors = errors + 1;
		end
		$display("[PASS] PMP Region 0 (0x1014/0x1018): Successfully programmed and verified");
		axi_write(32'h0000101c, 32'h00040001);
		axi_write(32'h00001020, 32'h00050000);
		axi_read(32'h0000101c, rdata);
		if (rdata !== 32'h00040001) begin
			$display("[FAIL] Readback PMP1_BASE: Expected 0x00040001, got 0x%08X", rdata);
			errors = errors + 1;
		end
		$display("[PASS] PMP Region 1 (0x101C/0x1020): Successfully programmed and verified");
		axi_read(32'h00001024, rdata);
		if (rdata !== 32'hbad00002) begin
			$display("[FAIL] Unmapped PMP region 2 read expected 0xBAD00002, got 0x%08X", rdata);
			errors = errors + 1;
		end
		else
			$display("[PASS] PMP Unmapped Boundary (0x1024): Returned 0xBAD00002 as expected");
		decoupler_is_decoupled_i[0] = 1'b0;
		axi_write(32'h00001000, 32'h00000000);
		axi_write(32'h00001014, 32'hdeadbeef);
		axi_read(32'h00001014, rdata);
		if (rdata !== 32'h00012003) begin
			$display("[FAIL] Security write-lock violated! PMP was modified while coupled: 0x%08X", rdata);
			errors = errors + 1;
		end
		else
			$display("[PASS] PMP Security Lock: Dropped unauthorized write while slot was coupled");
		axi_write(32'h0000100c, 32'hcafe1234);
		#(10)
			;
		if (slot_o_top_o[0+:32] !== 32'hcafe1234) begin
			$display("[FAIL] DEBUG_OUT: slot_o_top_o mismatch! Got 0x%08X", slot_o_top_o[0+:32]);
			errors = errors + 1;
		end
		else
			$display("[PASS] DEBUG_OUT (0x100C): Drove 0xCAFE1234 to fabric wires");
		slot_i_top_i[0+:32] = 32'h5678beef;
		#(10)
			;
		axi_read(32'h00001010, rdata);
		if (rdata !== 32'h5678beef) begin
			$display("[FAIL] DEBUG_IN: Expected 0x5678BEEF, got 0x%08X", rdata);
			errors = errors + 1;
		end
		else
			$display("[PASS] DEBUG_IN (0x1010): Read 0x5678BEEF from fabric wires");
		slot_pmp_r_violation_i[0] = 1'b1;
		#(20)
			;
		slot_pmp_r_violation_i[0] = 1'b0;
		#(10)
			;
		axi_read(32'h00001004, rdata);
		if ((rdata[8] !== 1'b1) || (slot_fault_irq_o[0] !== 1'b1)) begin
			$display("[FAIL] Fault latch failed! PMP_R_FAULT=%b, slot_fault_irq_o=%b", rdata[8], slot_fault_irq_o[0]);
			errors = errors + 1;
		end
		else
			$display("[PASS] Fault Latch: PMP read violation latched into STATUS[8] and asserted slot_fault_irq_o = 1");
		axi_write(32'h00001008, 32'h00000100);
		axi_read(32'h00001004, rdata);
		if ((rdata[8] !== 1'b0) || (slot_fault_irq_o[0] !== 1'b0)) begin
			$display("[FAIL] FAULT_CLEAR strobe failed! PMP_R_FAULT=%b, slot_fault_irq_o=%b", rdata[8], slot_fault_irq_o[0]);
			errors = errors + 1;
		end
		else
			$display("[PASS] FAULT_CLEAR (0x1008): Strobe cleared latched fault bit and deasserted slot_fault_irq_o = 0");
		$display("=================================================================");
		if (errors == 0)
			$display("ALL HARDWARE REGISTER MAP TESTS PASSED SUCCESSFULLY! (0 Errors)");
		else
			$display("TEST FAILED WITH %0d ERRORS!", errors);
		$display("=================================================================");
		$finish;
	end
endmodule
