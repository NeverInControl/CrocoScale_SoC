module efpga_manager (
	clk_i,
	rstn_i,
	s_axil_awaddr,
	s_axil_awprot,
	s_axil_awvalid,
	s_axil_awready,
	s_axil_wdata,
	s_axil_wstrb,
	s_axil_wvalid,
	s_axil_wready,
	s_axil_bresp,
	s_axil_bvalid,
	s_axil_bready,
	s_axil_araddr,
	s_axil_arprot,
	s_axil_arvalid,
	s_axil_arready,
	s_axil_rdata,
	s_axil_rresp,
	s_axil_rvalid,
	s_axil_rready,
	efpga_config_data_o,
	efpga_config_we_o,
	efpga_com_active_i,
	efpga_bitbang_active_i,
	slot_debug_in_i,
	slot_debug_out_o,
	decoupler_req_o,
	decoupler_force_o,
	decoupler_is_decoupled_i,
	decoupler_host_act_i,
	decoupler_dma_act_i,
	slot_usr_irq_en_o,
	slot_pmod_en_o,
	slot_pmp_r_violation_i,
	slot_pmp_w_violation_i,
	slot_wdog_cs_to_w_i,
	slot_wdog_cs_to_r_i,
	slot_wdog_cs_pr_w_i,
	slot_wdog_cs_pr_r_i,
	slot_wdog_dm_to_w_i,
	slot_wdog_dm_to_r_i,
	slot_wdog_dm_pr_w_i,
	slot_wdog_dm_pr_r_i,
	slot_wdog_cm_to_w_i,
	slot_wdog_cm_to_r_i,
	slot_wdog_cm_pr_w_i,
	slot_wdog_cm_pr_r_i,
	slot_wdog_ds_to_w_i,
	slot_wdog_ds_to_r_i,
	slot_wdog_ds_pr_w_i,
	slot_wdog_ds_pr_r_i,
	pmp_g_en_o,
	pmp_base_o,
	pmp_limit_o,
	wb_s_enable_o,
	wb_m_enable_o,
	slot_fault_irq_o,
	slot_dma_awprot_o,
	slot_dma_arprot_o
);
	reg _sv2v_0;
	parameter signed [31:0] NUM_SLOTS = 1;
	parameter signed [31:0] NUM_PMP_REGIONS = 2;
	parameter [31:0] HW_VERSION = 32'hfab00001;
	parameter [0:0] PAGE_GRANULARITY = 1'b1;
	parameter signed [31:0] ADDR_WIDTH = 32;
	parameter [0:0] ENABLE_PMP = 1'b1;
	parameter [0:0] ENABLE_WDOG_CTRL_SLAVE = 1'b1;
	parameter [0:0] ENABLE_WDOG_DMA_MASTER = 1'b1;
	parameter [0:0] ENABLE_WDOG_CTRL_MASTER = 1'b0;
	parameter [0:0] ENABLE_WDOG_DMA_SLAVE = 1'b0;
	parameter [0:0] ENABLE_BRIDGE_CTRL = 1'b0;
	parameter [0:0] ENABLE_BRIDGE_DMA = 1'b0;
	input wire clk_i;
	input wire rstn_i;
	input wire [31:0] s_axil_awaddr;
	input wire [2:0] s_axil_awprot;
	input wire s_axil_awvalid;
	output wire s_axil_awready;
	input wire [31:0] s_axil_wdata;
	input wire [3:0] s_axil_wstrb;
	input wire s_axil_wvalid;
	output wire s_axil_wready;
	output wire [1:0] s_axil_bresp;
	output wire s_axil_bvalid;
	input wire s_axil_bready;
	input wire [31:0] s_axil_araddr;
	input wire [2:0] s_axil_arprot;
	input wire s_axil_arvalid;
	output wire s_axil_arready;
	output wire [31:0] s_axil_rdata;
	output wire [1:0] s_axil_rresp;
	output wire s_axil_rvalid;
	input wire s_axil_rready;
	output reg [31:0] efpga_config_data_o;
	output reg efpga_config_we_o;
	input wire efpga_com_active_i;
	input wire efpga_bitbang_active_i;
	input wire [(NUM_SLOTS * 32) - 1:0] slot_debug_in_i;
	output wire [(NUM_SLOTS * 32) - 1:0] slot_debug_out_o;
	output wire [NUM_SLOTS - 1:0] decoupler_req_o;
	output wire [NUM_SLOTS - 1:0] decoupler_force_o;
	input wire [NUM_SLOTS - 1:0] decoupler_is_decoupled_i;
	input wire [NUM_SLOTS - 1:0] decoupler_host_act_i;
	input wire [NUM_SLOTS - 1:0] decoupler_dma_act_i;
	output wire [NUM_SLOTS - 1:0] slot_usr_irq_en_o;
	output wire [NUM_SLOTS - 1:0] slot_pmod_en_o;
	input wire [NUM_SLOTS - 1:0] slot_pmp_r_violation_i;
	input wire [NUM_SLOTS - 1:0] slot_pmp_w_violation_i;
	input wire [NUM_SLOTS - 1:0] slot_wdog_cs_to_w_i;
	input wire [NUM_SLOTS - 1:0] slot_wdog_cs_to_r_i;
	input wire [NUM_SLOTS - 1:0] slot_wdog_cs_pr_w_i;
	input wire [NUM_SLOTS - 1:0] slot_wdog_cs_pr_r_i;
	input wire [NUM_SLOTS - 1:0] slot_wdog_dm_to_w_i;
	input wire [NUM_SLOTS - 1:0] slot_wdog_dm_to_r_i;
	input wire [NUM_SLOTS - 1:0] slot_wdog_dm_pr_w_i;
	input wire [NUM_SLOTS - 1:0] slot_wdog_dm_pr_r_i;
	input wire [NUM_SLOTS - 1:0] slot_wdog_cm_to_w_i;
	input wire [NUM_SLOTS - 1:0] slot_wdog_cm_to_r_i;
	input wire [NUM_SLOTS - 1:0] slot_wdog_cm_pr_w_i;
	input wire [NUM_SLOTS - 1:0] slot_wdog_cm_pr_r_i;
	input wire [NUM_SLOTS - 1:0] slot_wdog_ds_to_w_i;
	input wire [NUM_SLOTS - 1:0] slot_wdog_ds_to_r_i;
	input wire [NUM_SLOTS - 1:0] slot_wdog_ds_pr_w_i;
	input wire [NUM_SLOTS - 1:0] slot_wdog_ds_pr_r_i;
	output wire [NUM_SLOTS - 1:0] pmp_g_en_o;
	output wire [((NUM_SLOTS * NUM_PMP_REGIONS) * 32) - 1:0] pmp_base_o;
	output wire [((NUM_SLOTS * NUM_PMP_REGIONS) * 32) - 1:0] pmp_limit_o;
	output wire [NUM_SLOTS - 1:0] wb_s_enable_o;
	output wire [NUM_SLOTS - 1:0] wb_m_enable_o;
	output wire [NUM_SLOTS - 1:0] slot_fault_irq_o;
	output wire [(NUM_SLOTS * 3) - 1:0] slot_dma_awprot_o;
	output wire [(NUM_SLOTS * 3) - 1:0] slot_dma_arprot_o;
	localparam [0:0] PMP_ACTIVE = ENABLE_PMP & (NUM_PMP_REGIONS > 0);
	localparam signed [31:0] ADDR_SHIFT = (PAGE_GRANULARITY ? 12 : 2);
	localparam signed [31:0] COMP_WIDTH = ADDR_WIDTH - ADDR_SHIFT;
	wire [15:0] local_awaddr = s_axil_awaddr[15:0];
	wire [15:0] local_araddr = s_axil_araddr[15:0];
	function automatic [3:0] sv2v_cast_4;
		input reg [3:0] inp;
		sv2v_cast_4 = inp;
	endfunction
	wire [3:0] aw_slot_idx = sv2v_cast_4((local_awaddr - 16'h1000) >> 12);
	wire [3:0] ar_slot_idx = sv2v_cast_4((local_araddr - 16'h1000) >> 12);
	localparam signed [31:0] SLOT_IDX_W = (NUM_SLOTS > 1 ? $clog2(NUM_SLOTS) : 1);
	wire [SLOT_IDX_W - 1:0] aw_slot_sel = aw_slot_idx[SLOT_IDX_W - 1:0];
	wire [SLOT_IDX_W - 1:0] ar_slot_sel = ar_slot_idx[SLOT_IDX_W - 1:0];
	reg axi_awready;
	reg axi_wready;
	reg axi_bvalid;
	reg axi_arready;
	reg axi_rvalid;
	reg [31:0] axi_rdata;
	assign s_axil_awready = axi_awready;
	assign s_axil_wready = axi_wready;
	assign s_axil_bvalid = axi_bvalid;
	assign s_axil_bresp = 2'b00;
	assign s_axil_arready = axi_arready;
	assign s_axil_rvalid = axi_rvalid;
	assign s_axil_rdata = axi_rdata;
	assign s_axil_rresp = 2'b00;
	reg [31:0] config_count_reg;
	reg user_design_loaded_reg;
	reg com_active_q;
	reg bitbang_active_q;
	reg bitbang_sticky_reg;
	reg [NUM_SLOTS - 1:0] dec_req_reg;
	reg [NUM_SLOTS - 1:0] dec_force_reg;
	reg [NUM_SLOTS - 1:0] usr_irq_en_reg;
	reg [NUM_SLOTS - 1:0] pmod_en_reg;
	reg [(NUM_SLOTS * 32) - 1:0] slot_debug_out_reg;
	reg [(NUM_SLOTS * 3) - 1:0] dma_awprot_reg;
	reg [(NUM_SLOTS * 3) - 1:0] dma_arprot_reg;
	assign slot_debug_out_o = slot_debug_out_reg;
	assign decoupler_req_o = dec_req_reg;
	assign slot_usr_irq_en_o = usr_irq_en_reg;
	assign slot_pmod_en_o = pmod_en_reg;
	assign slot_dma_awprot_o = dma_awprot_reg;
	assign slot_dma_arprot_o = dma_arprot_reg;
	wire axi_write_en = (((s_axil_awvalid && s_axil_wvalid) && !axi_awready) && !axi_wready) && !axi_bvalid;
	function automatic signed [3:0] sv2v_cast_4_signed;
		input reg signed [3:0] inp;
		sv2v_cast_4_signed = inp;
	endfunction
	wire is_slot_write = (axi_write_en && (local_awaddr >= 16'h1000)) && (aw_slot_idx < sv2v_cast_4_signed(NUM_SLOTS));
	wire [11:0] slot_aw_offset = local_awaddr[11:0] & 12'hffc;
	wire [11:0] pmp_aw_offset = (local_awaddr[11:0] & 12'hffc) - 12'h018;
	wire [7:0] pmp_aw_region_idx = pmp_aw_offset[10:3];
	wire [11:0] pmp_ar_offset = (local_araddr[11:0] & 12'hffc) - 12'h018;
	wire [7:0] pmp_ar_region_idx = pmp_ar_offset[10:3];
	wire [NUM_SLOTS - 1:0] pmp_g_en_wire;
	wire [NUM_SLOTS - 1:0] pmp_r_flag_wire;
	wire [NUM_SLOTS - 1:0] pmp_w_flag_wire;
	function automatic signed [7:0] sv2v_cast_8_signed;
		input reg signed [7:0] inp;
		sv2v_cast_8_signed = inp;
	endfunction
	function automatic signed [SLOT_IDX_W - 1:0] sv2v_cast_9A159_signed;
		input reg signed [SLOT_IDX_W - 1:0] inp;
		sv2v_cast_9A159_signed = inp;
	endfunction
	generate
		if (PMP_ACTIVE) begin : gen_pmp
			reg [NUM_SLOTS - 1:0] pmp_g_en_reg;
			reg [NUM_SLOTS - 1:0] pmp_r_flag_reg;
			reg [NUM_SLOTS - 1:0] pmp_w_flag_reg;
			reg [((NUM_SLOTS * NUM_PMP_REGIONS) * COMP_WIDTH) - 1:0] pmp_base_addr_reg;
			reg [((NUM_SLOTS * NUM_PMP_REGIONS) * 2) - 1:0] pmp_base_cfg_reg;
			reg [((NUM_SLOTS * NUM_PMP_REGIONS) * COMP_WIDTH) - 1:0] pmp_limit_addr_reg;
			reg [((NUM_SLOTS * NUM_PMP_REGIONS) * 2) - 1:0] pmp_limit_cfg_reg;
			assign pmp_g_en_wire = pmp_g_en_reg;
			assign pmp_r_flag_wire = pmp_r_flag_reg;
			assign pmp_w_flag_wire = pmp_w_flag_reg;
			assign pmp_g_en_o = pmp_g_en_reg;
			genvar _gv_s_1;
			for (_gv_s_1 = 0; _gv_s_1 < NUM_SLOTS; _gv_s_1 = _gv_s_1 + 1) begin : gen_pmp_out_slot
				localparam s = _gv_s_1;
				genvar _gv_r_1;
				for (_gv_r_1 = 0; _gv_r_1 < NUM_PMP_REGIONS; _gv_r_1 = _gv_r_1 + 1) begin : gen_pmp_out_reg
					localparam r = _gv_r_1;
					if (PAGE_GRANULARITY) begin : gen_4k_out
						if (ADDR_WIDTH < 32) begin : gen_pad
							assign pmp_base_o[((s * NUM_PMP_REGIONS) + r) * 32+:32] = {{32 - ADDR_WIDTH {1'b0}}, pmp_base_addr_reg[((s * NUM_PMP_REGIONS) + r) * COMP_WIDTH+:COMP_WIDTH], 10'd0, pmp_base_cfg_reg[((s * NUM_PMP_REGIONS) + r) * 2+:2]};
							assign pmp_limit_o[((s * NUM_PMP_REGIONS) + r) * 32+:32] = {{32 - ADDR_WIDTH {1'b0}}, pmp_limit_addr_reg[((s * NUM_PMP_REGIONS) + r) * COMP_WIDTH+:COMP_WIDTH], 10'd0, pmp_limit_cfg_reg[((s * NUM_PMP_REGIONS) + r) * 2+:2]};
						end
						else begin : gen_nopad
							assign pmp_base_o[((s * NUM_PMP_REGIONS) + r) * 32+:32] = {pmp_base_addr_reg[((s * NUM_PMP_REGIONS) + r) * COMP_WIDTH+:COMP_WIDTH], 10'd0, pmp_base_cfg_reg[((s * NUM_PMP_REGIONS) + r) * 2+:2]};
							assign pmp_limit_o[((s * NUM_PMP_REGIONS) + r) * 32+:32] = {pmp_limit_addr_reg[((s * NUM_PMP_REGIONS) + r) * COMP_WIDTH+:COMP_WIDTH], 10'd0, pmp_limit_cfg_reg[((s * NUM_PMP_REGIONS) + r) * 2+:2]};
						end
					end
					else begin : gen_word_out
						if (ADDR_WIDTH < 32) begin : gen_pad
							assign pmp_base_o[((s * NUM_PMP_REGIONS) + r) * 32+:32] = {{32 - ADDR_WIDTH {1'b0}}, pmp_base_addr_reg[((s * NUM_PMP_REGIONS) + r) * COMP_WIDTH+:COMP_WIDTH], pmp_base_cfg_reg[((s * NUM_PMP_REGIONS) + r) * 2+:2]};
							assign pmp_limit_o[((s * NUM_PMP_REGIONS) + r) * 32+:32] = {{32 - ADDR_WIDTH {1'b0}}, pmp_limit_addr_reg[((s * NUM_PMP_REGIONS) + r) * COMP_WIDTH+:COMP_WIDTH], pmp_limit_cfg_reg[((s * NUM_PMP_REGIONS) + r) * 2+:2]};
						end
						else begin : gen_nopad
							assign pmp_base_o[((s * NUM_PMP_REGIONS) + r) * 32+:32] = {pmp_base_addr_reg[((s * NUM_PMP_REGIONS) + r) * COMP_WIDTH+:COMP_WIDTH], pmp_base_cfg_reg[((s * NUM_PMP_REGIONS) + r) * 2+:2]};
							assign pmp_limit_o[((s * NUM_PMP_REGIONS) + r) * 32+:32] = {pmp_limit_addr_reg[((s * NUM_PMP_REGIONS) + r) * COMP_WIDTH+:COMP_WIDTH], pmp_limit_cfg_reg[((s * NUM_PMP_REGIONS) + r) * 2+:2]};
						end
					end
				end
			end
			reg [31:0] pmp_w_curr_val;
			reg [31:0] pmp_w_next_val;
			always @(*) begin
				if (_sv2v_0)
					;
				pmp_w_curr_val = 32'b00000000000000000000000000000000;
				if ((aw_slot_idx < sv2v_cast_4_signed(NUM_SLOTS)) && (pmp_aw_region_idx < sv2v_cast_8_signed(NUM_PMP_REGIONS)))
					pmp_w_curr_val = (pmp_aw_offset[2] == 1'b0 ? pmp_base_o[((aw_slot_sel * NUM_PMP_REGIONS) + pmp_aw_region_idx) * 32+:32] : pmp_limit_o[((aw_slot_sel * NUM_PMP_REGIONS) + pmp_aw_region_idx) * 32+:32]);
				pmp_w_next_val[7:0] = (s_axil_wstrb[0] ? s_axil_wdata[7:0] : pmp_w_curr_val[7:0]);
				pmp_w_next_val[15:8] = (s_axil_wstrb[1] ? s_axil_wdata[15:8] : pmp_w_curr_val[15:8]);
				pmp_w_next_val[23:16] = (s_axil_wstrb[2] ? s_axil_wdata[23:16] : pmp_w_curr_val[23:16]);
				pmp_w_next_val[31:24] = (s_axil_wstrb[3] ? s_axil_wdata[31:24] : pmp_w_curr_val[31:24]);
			end
			always @(posedge clk_i or negedge rstn_i)
				if (!rstn_i) begin
					pmp_g_en_reg <= 1'sb0;
					pmp_r_flag_reg <= 1'sb0;
					pmp_w_flag_reg <= 1'sb0;
					pmp_base_addr_reg <= 1'sb0;
					pmp_base_cfg_reg <= 1'sb0;
					pmp_limit_addr_reg <= 1'sb0;
					pmp_limit_cfg_reg <= 1'sb0;
				end
				else begin
					begin : sv2v_autoblock_1
						reg signed [31:0] j;
						for (j = 0; j < NUM_SLOTS; j = j + 1)
							begin
								if (slot_pmp_r_violation_i[j])
									pmp_r_flag_reg[j] <= 1'b1;
								else if ((((is_slot_write && (aw_slot_sel == sv2v_cast_9A159_signed(j))) && (slot_aw_offset == 12'h00c)) && s_axil_wstrb[1]) && s_axil_wdata[8])
									pmp_r_flag_reg[j] <= 1'b0;
								if (slot_pmp_w_violation_i[j])
									pmp_w_flag_reg[j] <= 1'b1;
								else if ((((is_slot_write && (aw_slot_sel == sv2v_cast_9A159_signed(j))) && (slot_aw_offset == 12'h00c)) && s_axil_wstrb[1]) && s_axil_wdata[9])
									pmp_w_flag_reg[j] <= 1'b0;
							end
					end
					if (is_slot_write) begin
						if (slot_aw_offset == 12'h004) begin
							if (s_axil_wstrb[1])
								pmp_g_en_reg[aw_slot_sel] <= s_axil_wdata[8];
						end
						else if ((slot_aw_offset >= 12'h018) && decoupler_is_decoupled_i[aw_slot_sel]) begin
							if (pmp_aw_region_idx < sv2v_cast_8_signed(NUM_PMP_REGIONS)) begin
								if (pmp_aw_offset[2] == 1'b0) begin
									pmp_base_addr_reg[((aw_slot_sel * NUM_PMP_REGIONS) + pmp_aw_region_idx) * COMP_WIDTH+:COMP_WIDTH] <= pmp_w_next_val[ADDR_WIDTH - 1:ADDR_SHIFT];
									pmp_base_cfg_reg[((aw_slot_sel * NUM_PMP_REGIONS) + pmp_aw_region_idx) * 2+:2] <= pmp_w_next_val[1:0];
								end
								else begin
									pmp_limit_addr_reg[((aw_slot_sel * NUM_PMP_REGIONS) + pmp_aw_region_idx) * COMP_WIDTH+:COMP_WIDTH] <= pmp_w_next_val[ADDR_WIDTH - 1:ADDR_SHIFT];
									pmp_limit_cfg_reg[((aw_slot_sel * NUM_PMP_REGIONS) + pmp_aw_region_idx) * 2+:2] <= pmp_w_next_val[1:0];
								end
							end
						end
					end
				end
		end
		else begin : gen_no_pmp
			assign pmp_g_en_wire = 1'sb0;
			assign pmp_r_flag_wire = 1'sb0;
			assign pmp_w_flag_wire = 1'sb0;
			assign pmp_g_en_o = 1'sb0;
			assign pmp_base_o = 1'sb0;
			assign pmp_limit_o = 1'sb0;
		end
	endgenerate
	wire [NUM_SLOTS - 1:0] wdog_en_dm_wire;
	wire [NUM_SLOTS - 1:0] wdog_en_cs_wire;
	wire [NUM_SLOTS - 1:0] wdog_en_ds_wire;
	wire [NUM_SLOTS - 1:0] wdog_en_cm_wire;
	wire [NUM_SLOTS - 1:0] wdog_dm_pr_wire;
	wire [NUM_SLOTS - 1:0] wdog_dm_to_wire;
	wire [NUM_SLOTS - 1:0] wdog_cs_pr_wire;
	wire [NUM_SLOTS - 1:0] wdog_cs_to_wire;
	wire [NUM_SLOTS - 1:0] wdog_soc_wire;
	wire [NUM_SLOTS - 1:0] raw_dm_pr;
	wire [NUM_SLOTS - 1:0] raw_dm_to;
	wire [NUM_SLOTS - 1:0] raw_cs_pr;
	wire [NUM_SLOTS - 1:0] raw_cs_to;
	wire [NUM_SLOTS - 1:0] raw_soc;
	generate
		if (ENABLE_WDOG_DMA_MASTER) begin : gen_wdog_dm
			reg [NUM_SLOTS - 1:0] wdog_en_dm_reg;
			reg [NUM_SLOTS - 1:0] wdog_dm_pr_reg;
			reg [NUM_SLOTS - 1:0] wdog_dm_to_reg;
			assign wdog_en_dm_wire = wdog_en_dm_reg;
			assign wdog_dm_pr_wire = wdog_dm_pr_reg;
			assign wdog_dm_to_wire = wdog_dm_to_reg;
			genvar _gv_j_1;
			for (_gv_j_1 = 0; _gv_j_1 < NUM_SLOTS; _gv_j_1 = _gv_j_1 + 1) begin : gen_raw_dm
				localparam j = _gv_j_1;
				assign raw_dm_pr[j] = (slot_wdog_dm_pr_w_i[j] | slot_wdog_dm_pr_r_i[j]) & wdog_en_dm_reg[j];
				assign raw_dm_to[j] = (slot_wdog_dm_to_w_i[j] | slot_wdog_dm_to_r_i[j]) & wdog_en_dm_reg[j];
			end
			always @(posedge clk_i or negedge rstn_i)
				if (!rstn_i) begin
					wdog_en_dm_reg <= 1'sb1;
					wdog_dm_pr_reg <= 1'sb0;
					wdog_dm_to_reg <= 1'sb0;
				end
				else begin
					begin : sv2v_autoblock_2
						reg signed [31:0] j;
						for (j = 0; j < NUM_SLOTS; j = j + 1)
							begin
								if (raw_dm_pr[j])
									wdog_dm_pr_reg[j] <= 1'b1;
								else if ((((is_slot_write && (aw_slot_sel == sv2v_cast_9A159_signed(j))) && (slot_aw_offset == 12'h00c)) && s_axil_wstrb[2]) && s_axil_wdata[16])
									wdog_dm_pr_reg[j] <= 1'b0;
								if (raw_dm_to[j])
									wdog_dm_to_reg[j] <= 1'b1;
								else if ((((is_slot_write && (aw_slot_sel == sv2v_cast_9A159_signed(j))) && (slot_aw_offset == 12'h00c)) && s_axil_wstrb[2]) && s_axil_wdata[17])
									wdog_dm_to_reg[j] <= 1'b0;
							end
					end
					if ((is_slot_write && (slot_aw_offset == 12'h004)) && s_axil_wstrb[2])
						wdog_en_dm_reg[aw_slot_sel] <= s_axil_wdata[16];
				end
		end
		else begin : gen_no_wdog_dm
			assign wdog_en_dm_wire = 1'sb0;
			assign wdog_dm_pr_wire = 1'sb0;
			assign wdog_dm_to_wire = 1'sb0;
			assign raw_dm_pr = 1'sb0;
			assign raw_dm_to = 1'sb0;
		end
		if (ENABLE_WDOG_CTRL_SLAVE) begin : gen_wdog_cs
			reg [NUM_SLOTS - 1:0] wdog_en_cs_reg;
			reg [NUM_SLOTS - 1:0] wdog_cs_pr_reg;
			reg [NUM_SLOTS - 1:0] wdog_cs_to_reg;
			assign wdog_en_cs_wire = wdog_en_cs_reg;
			assign wdog_cs_pr_wire = wdog_cs_pr_reg;
			assign wdog_cs_to_wire = wdog_cs_to_reg;
			genvar _gv_j_2;
			for (_gv_j_2 = 0; _gv_j_2 < NUM_SLOTS; _gv_j_2 = _gv_j_2 + 1) begin : gen_raw_cs
				localparam j = _gv_j_2;
				assign raw_cs_pr[j] = (slot_wdog_cs_pr_w_i[j] | slot_wdog_cs_pr_r_i[j]) & wdog_en_cs_reg[j];
				assign raw_cs_to[j] = (slot_wdog_cs_to_w_i[j] | slot_wdog_cs_to_r_i[j]) & wdog_en_cs_reg[j];
			end
			always @(posedge clk_i or negedge rstn_i)
				if (!rstn_i) begin
					wdog_en_cs_reg <= 1'sb1;
					wdog_cs_pr_reg <= 1'sb0;
					wdog_cs_to_reg <= 1'sb0;
				end
				else begin
					begin : sv2v_autoblock_3
						reg signed [31:0] j;
						for (j = 0; j < NUM_SLOTS; j = j + 1)
							begin
								if (raw_cs_pr[j])
									wdog_cs_pr_reg[j] <= 1'b1;
								else if ((((is_slot_write && (aw_slot_sel == sv2v_cast_9A159_signed(j))) && (slot_aw_offset == 12'h00c)) && s_axil_wstrb[2]) && s_axil_wdata[18])
									wdog_cs_pr_reg[j] <= 1'b0;
								if (raw_cs_to[j])
									wdog_cs_to_reg[j] <= 1'b1;
								else if ((((is_slot_write && (aw_slot_sel == sv2v_cast_9A159_signed(j))) && (slot_aw_offset == 12'h00c)) && s_axil_wstrb[2]) && s_axil_wdata[19])
									wdog_cs_to_reg[j] <= 1'b0;
							end
					end
					if ((is_slot_write && (slot_aw_offset == 12'h004)) && s_axil_wstrb[2])
						wdog_en_cs_reg[aw_slot_sel] <= s_axil_wdata[17];
				end
		end
		else begin : gen_no_wdog_cs
			assign wdog_en_cs_wire = 1'sb0;
			assign wdog_cs_pr_wire = 1'sb0;
			assign wdog_cs_to_wire = 1'sb0;
			assign raw_cs_pr = 1'sb0;
			assign raw_cs_to = 1'sb0;
		end
		if (ENABLE_WDOG_DMA_SLAVE) begin : gen_wdog_ds
			reg [NUM_SLOTS - 1:0] wdog_en_ds_reg;
			assign wdog_en_ds_wire = wdog_en_ds_reg;
			always @(posedge clk_i or negedge rstn_i)
				if (!rstn_i)
					wdog_en_ds_reg <= 1'sb1;
				else if ((is_slot_write && (slot_aw_offset == 12'h004)) && s_axil_wstrb[2])
					wdog_en_ds_reg[aw_slot_sel] <= s_axil_wdata[18];
		end
		else begin : gen_no_wdog_ds
			assign wdog_en_ds_wire = 1'sb0;
		end
		if (ENABLE_WDOG_CTRL_MASTER) begin : gen_wdog_cm
			reg [NUM_SLOTS - 1:0] wdog_en_cm_reg;
			assign wdog_en_cm_wire = wdog_en_cm_reg;
			always @(posedge clk_i or negedge rstn_i)
				if (!rstn_i)
					wdog_en_cm_reg <= 1'sb1;
				else if ((is_slot_write && (slot_aw_offset == 12'h004)) && s_axil_wstrb[2])
					wdog_en_cm_reg[aw_slot_sel] <= s_axil_wdata[19];
		end
		else begin : gen_no_wdog_cm
			assign wdog_en_cm_wire = 1'sb0;
		end
		if (ENABLE_WDOG_CTRL_MASTER || ENABLE_WDOG_DMA_SLAVE) begin : gen_wdog_soc
			reg [NUM_SLOTS - 1:0] wdog_soc_reg;
			assign wdog_soc_wire = wdog_soc_reg;
			genvar _gv_j_3;
			for (_gv_j_3 = 0; _gv_j_3 < NUM_SLOTS; _gv_j_3 = _gv_j_3 + 1) begin : gen_raw_soc
				localparam j = _gv_j_3;
				wire cm_fault = (((slot_wdog_cm_to_w_i[j] | slot_wdog_cm_to_r_i[j]) | slot_wdog_cm_pr_w_i[j]) | slot_wdog_cm_pr_r_i[j]) & wdog_en_cm_wire[j];
				wire ds_fault = (((slot_wdog_ds_to_w_i[j] | slot_wdog_ds_to_r_i[j]) | slot_wdog_ds_pr_w_i[j]) | slot_wdog_ds_pr_r_i[j]) & wdog_en_ds_wire[j];
				assign raw_soc[j] = cm_fault | ds_fault;
			end
			always @(posedge clk_i or negedge rstn_i)
				if (!rstn_i)
					wdog_soc_reg <= 1'sb0;
				else begin : sv2v_autoblock_4
					reg signed [31:0] j;
					for (j = 0; j < NUM_SLOTS; j = j + 1)
						if (raw_soc[j])
							wdog_soc_reg[j] <= 1'b1;
						else if ((((is_slot_write && (aw_slot_sel == sv2v_cast_9A159_signed(j))) && (slot_aw_offset == 12'h00c)) && s_axil_wstrb[2]) && s_axil_wdata[20])
							wdog_soc_reg[j] <= 1'b0;
				end
		end
		else begin : gen_no_wdog_soc
			assign wdog_soc_wire = 1'sb0;
			assign raw_soc = 1'sb0;
		end
	endgenerate
	wire [NUM_SLOTS - 1:0] wb_s_enable_wire;
	wire [NUM_SLOTS - 1:0] wb_m_enable_wire;
	generate
		if (ENABLE_BRIDGE_CTRL) begin : gen_bridge_ctrl_reg
			reg [NUM_SLOTS - 1:0] wb_s_enable_reg;
			assign wb_s_enable_wire = wb_s_enable_reg;
			assign wb_s_enable_o = wb_s_enable_reg;
			always @(posedge clk_i or negedge rstn_i)
				if (!rstn_i)
					wb_s_enable_reg <= 1'sb0;
				else if ((is_slot_write && (slot_aw_offset == 12'h004)) && s_axil_wstrb[3])
					wb_s_enable_reg[aw_slot_sel] <= s_axil_wdata[24];
		end
		else begin : gen_no_bridge_ctrl_reg
			assign wb_s_enable_wire = 1'sb0;
			assign wb_s_enable_o = 1'sb0;
		end
		if (ENABLE_BRIDGE_DMA) begin : gen_bridge_dma_reg
			reg [NUM_SLOTS - 1:0] wb_m_enable_reg;
			assign wb_m_enable_wire = wb_m_enable_reg;
			assign wb_m_enable_o = wb_m_enable_reg;
			always @(posedge clk_i or negedge rstn_i)
				if (!rstn_i)
					wb_m_enable_reg <= 1'sb0;
				else if ((is_slot_write && (slot_aw_offset == 12'h004)) && s_axil_wstrb[3])
					wb_m_enable_reg[aw_slot_sel] <= s_axil_wdata[25];
		end
		else begin : gen_no_bridge_dma_reg
			assign wb_m_enable_wire = 1'sb0;
			assign wb_m_enable_o = 1'sb0;
		end
	endgenerate
	genvar _gv_i_1;
	generate
		for (_gv_i_1 = 0; _gv_i_1 < NUM_SLOTS; _gv_i_1 = _gv_i_1 + 1) begin : gen_slot_outputs
			localparam i = _gv_i_1;
			assign decoupler_force_o[i] = (((((((((((((dec_force_reg[i] | raw_dm_pr[i]) | raw_dm_to[i]) | raw_cs_pr[i]) | raw_cs_to[i]) | raw_soc[i]) | wdog_dm_pr_wire[i]) | wdog_dm_to_wire[i]) | wdog_cs_pr_wire[i]) | wdog_cs_to_wire[i]) | wdog_soc_wire[i]) | slot_pmp_r_violation_i[i]) | pmp_r_flag_wire[i]) | slot_pmp_w_violation_i[i]) | pmp_w_flag_wire[i];
			assign slot_fault_irq_o[i] = (((((pmp_r_flag_wire[i] | pmp_w_flag_wire[i]) | wdog_dm_to_wire[i]) | wdog_dm_pr_wire[i]) | wdog_cs_to_wire[i]) | wdog_cs_pr_wire[i]) | wdog_soc_wire[i];
		end
	endgenerate
	always @(posedge clk_i or negedge rstn_i)
		if (!rstn_i) begin
			axi_awready <= 1'b0;
			axi_wready <= 1'b0;
			axi_bvalid <= 1'b0;
			config_count_reg <= 1'sb0;
			efpga_config_data_o <= 1'sb0;
			efpga_config_we_o <= 1'b0;
			user_design_loaded_reg <= 1'b0;
			com_active_q <= 1'b0;
			bitbang_active_q <= 1'b0;
			bitbang_sticky_reg <= 1'b0;
			dec_req_reg <= 1'sb1;
			dec_force_reg <= 1'sb1;
			usr_irq_en_reg <= 1'sb0;
			pmod_en_reg <= 1'sb0;
			slot_debug_out_reg <= 1'sb0;
			dma_awprot_reg <= 1'sb0;
			dma_arprot_reg <= 1'sb0;
		end
		else begin
			efpga_config_we_o <= 1'b0;
			com_active_q <= efpga_com_active_i;
			bitbang_active_q <= efpga_bitbang_active_i;
			if (efpga_bitbang_active_i && !bitbang_active_q)
				bitbang_sticky_reg <= 1'b1;
			if (axi_write_en) begin
				axi_awready <= 1'b1;
				axi_wready <= 1'b1;
				axi_bvalid <= 1'b1;
				if (local_awaddr < 16'h1000)
					case (local_awaddr[11:0] & 12'hffc)
						12'h004:
							if (s_axil_wstrb[0]) begin
								user_design_loaded_reg <= s_axil_wdata[2];
								if (s_axil_wdata[4])
									bitbang_sticky_reg <= 1'b0;
							end
						12'h008: begin
							config_count_reg <= config_count_reg + 32'd1;
							efpga_config_data_o <= {s_axil_wdata[7:0], s_axil_wdata[15:8], s_axil_wdata[23:16], s_axil_wdata[31:24]};
							efpga_config_we_o <= 1'b1;
							user_design_loaded_reg <= 1'b1;
						end
						default:
							;
					endcase
				else if (aw_slot_idx < sv2v_cast_4_signed(NUM_SLOTS))
					case (slot_aw_offset)
						12'h000:
							;
						12'h004: begin
							if (s_axil_wstrb[0]) begin
								dec_req_reg[aw_slot_sel] <= s_axil_wdata[0];
								dec_force_reg[aw_slot_sel] <= s_axil_wdata[1];
								usr_irq_en_reg[aw_slot_sel] <= s_axil_wdata[2];
								pmod_en_reg[aw_slot_sel] <= s_axil_wdata[3];
							end
							if (s_axil_wstrb[1]) begin
								dma_awprot_reg[aw_slot_sel * 3+:3] <= s_axil_wdata[12:10];
								dma_arprot_reg[aw_slot_sel * 3+:3] <= s_axil_wdata[15:13];
							end
						end
						12'h010: begin
							if (s_axil_wstrb[0])
								slot_debug_out_reg[(aw_slot_sel * 32) + 7-:8] <= s_axil_wdata[7:0];
							if (s_axil_wstrb[1])
								slot_debug_out_reg[(aw_slot_sel * 32) + 15-:8] <= s_axil_wdata[15:8];
							if (s_axil_wstrb[2])
								slot_debug_out_reg[(aw_slot_sel * 32) + 23-:8] <= s_axil_wdata[23:16];
							if (s_axil_wstrb[3])
								slot_debug_out_reg[(aw_slot_sel * 32) + 31-:8] <= s_axil_wdata[31:24];
						end
						default:
							;
					endcase
			end
			else begin
				axi_awready <= 1'b0;
				axi_wready <= 1'b0;
			end
			if (s_axil_bready && axi_bvalid)
				axi_bvalid <= 1'b0;
		end
	always @(posedge clk_i or negedge rstn_i)
		if (!rstn_i) begin
			axi_arready <= 1'b0;
			axi_rvalid <= 1'b0;
			axi_rdata <= 32'h00000000;
		end
		else if ((s_axil_arvalid && !axi_arready) && !axi_rvalid) begin
			axi_arready <= 1'b1;
			axi_rvalid <= 1'b1;
			if (local_araddr < 16'h1000)
				case (local_araddr[11:0] & 12'hffc)
					12'h000: axi_rdata <= HW_VERSION;
					12'h004: axi_rdata <= {27'd0, bitbang_sticky_reg, efpga_bitbang_active_i, user_design_loaded_reg, efpga_com_active_i, 1'b0};
					12'h008: axi_rdata <= 32'h00000000;
					12'h00c: axi_rdata <= config_count_reg;
					default: axi_rdata <= 32'hbad00000;
				endcase
			else if (ar_slot_idx < sv2v_cast_4_signed(NUM_SLOTS)) begin
				if ((local_araddr[11:0] & 12'hffc) < 12'h018)
					case (local_araddr[11:0] & 12'hffc)
						12'h000: axi_rdata <= 32'h00000000;
						12'h004: axi_rdata <= {6'd0, wb_m_enable_wire[ar_slot_sel], wb_s_enable_wire[ar_slot_sel], 4'd0, wdog_en_cm_wire[ar_slot_sel], wdog_en_ds_wire[ar_slot_sel], wdog_en_cs_wire[ar_slot_sel], wdog_en_dm_wire[ar_slot_sel], dma_arprot_reg[ar_slot_sel * 3+:3], dma_awprot_reg[ar_slot_sel * 3+:3], 1'b0, pmp_g_en_wire[ar_slot_sel], 4'd0, pmod_en_reg[ar_slot_sel], usr_irq_en_reg[ar_slot_sel], dec_force_reg[ar_slot_sel], dec_req_reg[ar_slot_sel]};
						12'h008: axi_rdata <= {11'd0, wdog_soc_wire[ar_slot_sel], wdog_cs_to_wire[ar_slot_sel], wdog_cs_pr_wire[ar_slot_sel], wdog_dm_to_wire[ar_slot_sel], wdog_dm_pr_wire[ar_slot_sel], 6'd0, pmp_w_flag_wire[ar_slot_sel], pmp_r_flag_wire[ar_slot_sel], 5'd0, decoupler_dma_act_i[ar_slot_sel], decoupler_host_act_i[ar_slot_sel], decoupler_is_decoupled_i[ar_slot_sel]};
						12'h00c: axi_rdata <= 32'h00000000;
						12'h010: axi_rdata <= slot_debug_out_reg[ar_slot_sel * 32+:32];
						12'h014: axi_rdata <= slot_debug_in_i[ar_slot_sel * 32+:32];
						default: axi_rdata <= 32'hbad00001;
					endcase
				else if (PMP_ACTIVE) begin
					if (pmp_ar_region_idx < sv2v_cast_8_signed(NUM_PMP_REGIONS)) begin
						if (pmp_ar_offset[2] == 1'b0)
							axi_rdata <= pmp_base_o[((ar_slot_sel * NUM_PMP_REGIONS) + pmp_ar_region_idx) * 32+:32];
						else
							axi_rdata <= pmp_limit_o[((ar_slot_sel * NUM_PMP_REGIONS) + pmp_ar_region_idx) * 32+:32];
					end
					else
						axi_rdata <= 32'hbad00002;
				end
				else
					axi_rdata <= 32'h00000000;
			end
			else
				axi_rdata <= 32'hbad00003;
		end
		else begin
			axi_arready <= 1'b0;
			if (s_axil_rready && axi_rvalid)
				axi_rvalid <= 1'b0;
		end
	initial _sv2v_0 = 0;
endmodule
