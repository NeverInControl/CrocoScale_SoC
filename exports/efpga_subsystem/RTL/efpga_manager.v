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
	efpga_soft_reset_o,
	efpga_com_active_i,
	slot_i_top_i,
	slot_o_top_o,
	decoupler_req_o,
	decoupler_force_o,
	decoupler_is_decoupled_i,
	decoupler_host_act_i,
	decoupler_dma_act_i,
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
	slot_fault_irq_o
);
	reg _sv2v_0;
	parameter signed [31:0] NUM_SLOTS = 1;
	parameter signed [31:0] NUM_REGIONS = 2;
	parameter [31:0] HW_VERSION = 32'hfab00001;
	parameter [0:0] PAGE_GRANULARITY = 1'b1;
	parameter signed [31:0] MAX_ADDRESS_WIDTH = 32;
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
	output wire efpga_soft_reset_o;
	input wire efpga_com_active_i;
	input wire [(NUM_SLOTS * 32) - 1:0] slot_i_top_i;
	output wire [(NUM_SLOTS * 32) - 1:0] slot_o_top_o;
	output wire [NUM_SLOTS - 1:0] decoupler_req_o;
	output wire [NUM_SLOTS - 1:0] decoupler_force_o;
	input wire [NUM_SLOTS - 1:0] decoupler_is_decoupled_i;
	input wire [NUM_SLOTS - 1:0] decoupler_host_act_i;
	input wire [NUM_SLOTS - 1:0] decoupler_dma_act_i;
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
	output wire [((NUM_SLOTS * NUM_REGIONS) * 32) - 1:0] pmp_base_o;
	output wire [((NUM_SLOTS * NUM_REGIONS) * 32) - 1:0] pmp_limit_o;
	output wire [NUM_SLOTS - 1:0] wb_s_enable_o;
	output wire [NUM_SLOTS - 1:0] wb_m_enable_o;
	output wire [NUM_SLOTS - 1:0] slot_fault_irq_o;
	localparam signed [31:0] ADDR_SHIFT = (PAGE_GRANULARITY ? 12 : 2);
	localparam signed [31:0] COMP_WIDTH = MAX_ADDRESS_WIDTH - ADDR_SHIFT;
	wire [15:0] local_awaddr = s_axil_awaddr[15:0];
	wire [15:0] local_araddr = s_axil_araddr[15:0];
	wire [3:0] aw_slot_idx = (local_awaddr - 16'h1000) >> 12;
	wire [3:0] ar_slot_idx = (local_araddr - 16'h1000) >> 12;
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
	reg soft_reset_reg;
	reg user_design_loaded_reg;
	reg com_active_q;
	reg [NUM_SLOTS - 1:0] dec_req_reg;
	reg [NUM_SLOTS - 1:0] dec_force_reg;
	reg [NUM_SLOTS - 1:0] pmp_r_flag_reg;
	reg [NUM_SLOTS - 1:0] pmp_w_flag_reg;
	reg [NUM_SLOTS - 1:0] pmp_g_en_reg;
	reg [NUM_SLOTS - 1:0] wb_s_enable_reg;
	reg [NUM_SLOTS - 1:0] wb_m_enable_reg;
	reg [(NUM_SLOTS * 32) - 1:0] slot_o_top_reg;
	reg [NUM_SLOTS - 1:0] wdog_en_dm;
	reg [NUM_SLOTS - 1:0] wdog_en_cs;
	reg [NUM_SLOTS - 1:0] wdog_en_ds;
	reg [NUM_SLOTS - 1:0] wdog_en_cm;
	reg [NUM_SLOTS - 1:0] wdog_dm_pr_flag;
	reg [NUM_SLOTS - 1:0] wdog_dm_to_flag;
	reg [NUM_SLOTS - 1:0] wdog_cs_pr_flag;
	reg [NUM_SLOTS - 1:0] wdog_cs_to_flag;
	reg [NUM_SLOTS - 1:0] wdog_soc_flag;
	reg [((NUM_SLOTS * NUM_REGIONS) * COMP_WIDTH) - 1:0] pmp_base_addr_reg;
	reg [((NUM_SLOTS * NUM_REGIONS) * 2) - 1:0] pmp_base_cfg_reg;
	reg [((NUM_SLOTS * NUM_REGIONS) * COMP_WIDTH) - 1:0] pmp_limit_addr_reg;
	reg [((NUM_SLOTS * NUM_REGIONS) * 2) - 1:0] pmp_limit_cfg_reg;
	assign efpga_soft_reset_o = soft_reset_reg;
	assign slot_o_top_o = slot_o_top_reg;
	assign decoupler_req_o = dec_req_reg;
	assign pmp_g_en_o = pmp_g_en_reg;
	assign wb_s_enable_o = wb_s_enable_reg;
	assign wb_m_enable_o = wb_m_enable_reg;
	reg [NUM_SLOTS - 1:0] raw_dm_pr;
	reg [NUM_SLOTS - 1:0] raw_dm_to;
	reg [NUM_SLOTS - 1:0] raw_cs_pr;
	reg [NUM_SLOTS - 1:0] raw_cs_to;
	reg [NUM_SLOTS - 1:0] raw_soc;
	always @(*) begin
		if (_sv2v_0)
			;
		begin : sv2v_autoblock_1
			reg signed [31:0] j;
			for (j = 0; j < NUM_SLOTS; j = j + 1)
				begin
					raw_dm_pr[j] = (slot_wdog_dm_pr_w_i[j] | slot_wdog_dm_pr_r_i[j]) & wdog_en_dm[j];
					raw_dm_to[j] = (slot_wdog_dm_to_w_i[j] | slot_wdog_dm_to_r_i[j]) & wdog_en_dm[j];
					raw_cs_pr[j] = (slot_wdog_cs_pr_w_i[j] | slot_wdog_cs_pr_r_i[j]) & wdog_en_cs[j];
					raw_cs_to[j] = (slot_wdog_cs_to_w_i[j] | slot_wdog_cs_to_r_i[j]) & wdog_en_cs[j];
					raw_soc[j] = ((((slot_wdog_cm_to_w_i[j] | slot_wdog_cm_to_r_i[j]) | slot_wdog_cm_pr_w_i[j]) | slot_wdog_cm_pr_r_i[j]) & wdog_en_cm[j]) | ((((slot_wdog_ds_to_w_i[j] | slot_wdog_ds_to_r_i[j]) | slot_wdog_ds_pr_w_i[j]) | slot_wdog_ds_pr_r_i[j]) & wdog_en_ds[j]);
				end
		end
	end
	genvar _gv_i_1;
	genvar _gv_r_1;
	generate
		for (_gv_i_1 = 0; _gv_i_1 < NUM_SLOTS; _gv_i_1 = _gv_i_1 + 1) begin : gen_pmp_out
			localparam i = _gv_i_1;
			for (_gv_r_1 = 0; _gv_r_1 < NUM_REGIONS; _gv_r_1 = _gv_r_1 + 1) begin : gen_pmp_out_r
				localparam r = _gv_r_1;
				assign pmp_base_o[((i * NUM_REGIONS) + r) * 32+:32] = {{32 - MAX_ADDRESS_WIDTH {1'b0}}, pmp_base_addr_reg[((i * NUM_REGIONS) + r) * COMP_WIDTH+:COMP_WIDTH], {ADDR_SHIFT - 2 {1'b0}}, pmp_base_cfg_reg[((i * NUM_REGIONS) + r) * 2+:2]};
				assign pmp_limit_o[((i * NUM_REGIONS) + r) * 32+:32] = {{32 - MAX_ADDRESS_WIDTH {1'b0}}, pmp_limit_addr_reg[((i * NUM_REGIONS) + r) * COMP_WIDTH+:COMP_WIDTH], {ADDR_SHIFT - 2 {1'b0}}, pmp_limit_cfg_reg[((i * NUM_REGIONS) + r) * 2+:2]};
			end
			assign decoupler_force_o[i] = (((((((((((((dec_force_reg[i] | raw_dm_pr[i]) | raw_dm_to[i]) | raw_cs_pr[i]) | raw_cs_to[i]) | raw_soc[i]) | wdog_dm_pr_flag[i]) | wdog_dm_to_flag[i]) | wdog_cs_pr_flag[i]) | wdog_cs_to_flag[i]) | wdog_soc_flag[i]) | slot_pmp_r_violation_i[i]) | pmp_r_flag_reg[i]) | slot_pmp_w_violation_i[i]) | pmp_w_flag_reg[i];
			assign slot_fault_irq_o[i] = (((((pmp_r_flag_reg[i] | pmp_w_flag_reg[i]) | wdog_dm_to_flag[i]) | wdog_dm_pr_flag[i]) | wdog_cs_to_flag[i]) | wdog_cs_pr_flag[i]) | wdog_soc_flag[i];
		end
	endgenerate
	wire axi_write_en = (((s_axil_awvalid && s_axil_wvalid) && !axi_awready) && !axi_wready) && !axi_bvalid;
	reg [NUM_SLOTS - 1:0] clr_pmp_r;
	reg [NUM_SLOTS - 1:0] clr_pmp_w;
	reg [NUM_SLOTS - 1:0] clr_dm_pr;
	reg [NUM_SLOTS - 1:0] clr_dm_to;
	reg [NUM_SLOTS - 1:0] clr_cs_pr;
	reg [NUM_SLOTS - 1:0] clr_cs_to;
	reg [NUM_SLOTS - 1:0] clr_soc;
	always @(*) begin
		if (_sv2v_0)
			;
		clr_pmp_r = 1'sb0;
		clr_pmp_w = 1'sb0;
		clr_dm_pr = 1'sb0;
		clr_dm_to = 1'sb0;
		clr_cs_pr = 1'sb0;
		clr_cs_to = 1'sb0;
		clr_soc = 1'sb0;
		if ((axi_write_en && (local_awaddr >= 16'h1000)) && (aw_slot_idx < NUM_SLOTS)) begin
			if ((local_awaddr[11:0] & 12'hffc) == 12'h008) begin
				if (s_axil_wstrb[1] && s_axil_wdata[8])
					clr_pmp_r[aw_slot_idx] = 1'b1;
				if (s_axil_wstrb[1] && s_axil_wdata[9])
					clr_pmp_w[aw_slot_idx] = 1'b1;
				if (s_axil_wstrb[2] && s_axil_wdata[16])
					clr_dm_pr[aw_slot_idx] = 1'b1;
				if (s_axil_wstrb[2] && s_axil_wdata[17])
					clr_dm_to[aw_slot_idx] = 1'b1;
				if (s_axil_wstrb[2] && s_axil_wdata[18])
					clr_cs_pr[aw_slot_idx] = 1'b1;
				if (s_axil_wstrb[2] && s_axil_wdata[19])
					clr_cs_to[aw_slot_idx] = 1'b1;
				if (s_axil_wstrb[2] && s_axil_wdata[20])
					clr_soc[aw_slot_idx] = 1'b1;
			end
		end
	end
	wire [11:0] pmp_aw_offset = (local_awaddr[11:0] & 12'hffc) - 12'h014;
	wire [7:0] pmp_aw_region_idx = pmp_aw_offset[10:3];
	wire [11:0] pmp_ar_offset = (local_araddr[11:0] & 12'hffc) - 12'h014;
	wire [7:0] pmp_ar_region_idx = pmp_ar_offset[10:3];
	reg [31:0] pmp_w_curr_val;
	reg [31:0] pmp_w_next_val;
	always @(*) begin
		if (_sv2v_0)
			;
		pmp_w_curr_val = 32'b00000000000000000000000000000000;
		if ((ENABLE_PMP && (aw_slot_idx < NUM_SLOTS)) && (pmp_aw_region_idx < NUM_REGIONS))
			pmp_w_curr_val = (pmp_aw_offset[2] == 1'b0 ? pmp_base_o[((aw_slot_idx * NUM_REGIONS) + pmp_aw_region_idx) * 32+:32] : pmp_limit_o[((aw_slot_idx * NUM_REGIONS) + pmp_aw_region_idx) * 32+:32]);
		pmp_w_next_val[7:0] = (s_axil_wstrb[0] ? s_axil_wdata[7:0] : pmp_w_curr_val[7:0]);
		pmp_w_next_val[15:8] = (s_axil_wstrb[1] ? s_axil_wdata[15:8] : pmp_w_curr_val[15:8]);
		pmp_w_next_val[23:16] = (s_axil_wstrb[2] ? s_axil_wdata[23:16] : pmp_w_curr_val[23:16]);
		pmp_w_next_val[31:24] = (s_axil_wstrb[3] ? s_axil_wdata[31:24] : pmp_w_curr_val[31:24]);
	end
	always @(posedge clk_i or negedge rstn_i)
		if (!rstn_i) begin
			axi_awready <= 1'b0;
			axi_wready <= 1'b0;
			axi_bvalid <= 1'b0;
			config_count_reg <= 1'sb0;
			efpga_config_data_o <= 1'sb0;
			efpga_config_we_o <= 1'b0;
			soft_reset_reg <= 1'b0;
			user_design_loaded_reg <= 1'b0;
			com_active_q <= 1'b0;
			dec_req_reg <= 1'sb1;
			dec_force_reg <= 1'sb0;
			pmp_r_flag_reg <= 1'sb0;
			pmp_w_flag_reg <= 1'sb0;
			pmp_g_en_reg <= 1'sb0;
			slot_o_top_reg <= 1'sb0;
			wb_s_enable_reg <= 1'sb0;
			wb_m_enable_reg <= 1'sb0;
			pmp_base_addr_reg <= 1'sb0;
			pmp_base_cfg_reg <= 1'sb0;
			pmp_limit_addr_reg <= 1'sb0;
			pmp_limit_cfg_reg <= 1'sb0;
			wdog_en_dm <= (ENABLE_WDOG_DMA_MASTER ? {NUM_SLOTS {1'sb1}} : {NUM_SLOTS {1'sb0}});
			wdog_en_cs <= (ENABLE_WDOG_CTRL_SLAVE ? {NUM_SLOTS {1'sb1}} : {NUM_SLOTS {1'sb0}});
			wdog_en_ds <= (ENABLE_WDOG_DMA_SLAVE ? {NUM_SLOTS {1'sb1}} : {NUM_SLOTS {1'sb0}});
			wdog_en_cm <= (ENABLE_WDOG_CTRL_MASTER ? {NUM_SLOTS {1'sb1}} : {NUM_SLOTS {1'sb0}});
			wdog_dm_pr_flag <= 1'sb0;
			wdog_dm_to_flag <= 1'sb0;
			wdog_cs_pr_flag <= 1'sb0;
			wdog_cs_to_flag <= 1'sb0;
			wdog_soc_flag <= 1'sb0;
		end
		else begin
			efpga_config_we_o <= 1'b0;
			com_active_q <= efpga_com_active_i;
			begin : sv2v_autoblock_2
				reg signed [31:0] j;
				for (j = 0; j < NUM_SLOTS; j = j + 1)
					begin
						if (raw_dm_pr[j])
							wdog_dm_pr_flag[j] <= 1'b1;
						else if (clr_dm_pr[j])
							wdog_dm_pr_flag[j] <= 1'b0;
						if (raw_dm_to[j])
							wdog_dm_to_flag[j] <= 1'b1;
						else if (clr_dm_to[j])
							wdog_dm_to_flag[j] <= 1'b0;
						if (raw_cs_pr[j])
							wdog_cs_pr_flag[j] <= 1'b1;
						else if (clr_cs_pr[j])
							wdog_cs_pr_flag[j] <= 1'b0;
						if (raw_cs_to[j])
							wdog_cs_to_flag[j] <= 1'b1;
						else if (clr_cs_to[j])
							wdog_cs_to_flag[j] <= 1'b0;
						if (raw_soc[j])
							wdog_soc_flag[j] <= 1'b1;
						else if (clr_soc[j])
							wdog_soc_flag[j] <= 1'b0;
						if (slot_pmp_r_violation_i[j])
							pmp_r_flag_reg[j] <= 1'b1;
						else if (clr_pmp_r[j])
							pmp_r_flag_reg[j] <= 1'b0;
						if (slot_pmp_w_violation_i[j])
							pmp_w_flag_reg[j] <= 1'b1;
						else if (clr_pmp_w[j])
							pmp_w_flag_reg[j] <= 1'b0;
					end
			end
			if (axi_write_en) begin
				axi_awready <= 1'b1;
				axi_wready <= 1'b1;
				axi_bvalid <= 1'b1;
				if (local_awaddr < 16'h1000)
					case (local_awaddr[11:0] & 12'hffc)
						12'h004:
							if (s_axil_wstrb[0]) begin
								soft_reset_reg <= s_axil_wdata[0];
								user_design_loaded_reg <= s_axil_wdata[2];
							end
						12'h008: begin
							config_count_reg <= config_count_reg + 1;
							efpga_config_data_o <= s_axil_wdata;
							efpga_config_we_o <= 1'b1;
							user_design_loaded_reg <= 1'b1;
						end
						default:
							;
					endcase
				else if (aw_slot_idx < NUM_SLOTS) begin
					if ((local_awaddr[11:0] & 12'hffc) < 12'h014)
						case (local_awaddr[11:0] & 12'hffc)
							12'h000: begin
								if (s_axil_wstrb[0]) begin
									dec_req_reg[aw_slot_idx] <= s_axil_wdata[0];
									dec_force_reg[aw_slot_idx] <= s_axil_wdata[1];
								end
								if (s_axil_wstrb[1]) begin
									if (ENABLE_PMP)
										pmp_g_en_reg[aw_slot_idx] <= s_axil_wdata[8];
								end
								if (s_axil_wstrb[2]) begin
									if (ENABLE_WDOG_DMA_MASTER)
										wdog_en_dm[aw_slot_idx] <= s_axil_wdata[16];
									if (ENABLE_WDOG_CTRL_SLAVE)
										wdog_en_cs[aw_slot_idx] <= s_axil_wdata[17];
									if (ENABLE_WDOG_DMA_SLAVE)
										wdog_en_ds[aw_slot_idx] <= s_axil_wdata[18];
									if (ENABLE_WDOG_CTRL_MASTER)
										wdog_en_cm[aw_slot_idx] <= s_axil_wdata[19];
								end
								if (s_axil_wstrb[3]) begin
									if (ENABLE_BRIDGE_CTRL)
										wb_s_enable_reg[aw_slot_idx] <= s_axil_wdata[24];
									if (ENABLE_BRIDGE_DMA)
										wb_m_enable_reg[aw_slot_idx] <= s_axil_wdata[25];
								end
							end
							12'h00c: begin
								if (s_axil_wstrb[0])
									slot_o_top_reg[(aw_slot_idx * 32) + 7-:8] <= s_axil_wdata[7:0];
								if (s_axil_wstrb[1])
									slot_o_top_reg[(aw_slot_idx * 32) + 15-:8] <= s_axil_wdata[15:8];
								if (s_axil_wstrb[2])
									slot_o_top_reg[(aw_slot_idx * 32) + 23-:8] <= s_axil_wdata[23:16];
								if (s_axil_wstrb[3])
									slot_o_top_reg[(aw_slot_idx * 32) + 31-:8] <= s_axil_wdata[31:24];
							end
							default:
								;
						endcase
					else if (decoupler_is_decoupled_i[aw_slot_idx] && ENABLE_PMP) begin
						if (pmp_aw_region_idx < NUM_REGIONS) begin
							if (pmp_aw_offset[2] == 1'b0) begin
								pmp_base_addr_reg[((aw_slot_idx * NUM_REGIONS) + pmp_aw_region_idx) * COMP_WIDTH+:COMP_WIDTH] <= pmp_w_next_val[MAX_ADDRESS_WIDTH - 1:ADDR_SHIFT];
								pmp_base_cfg_reg[((aw_slot_idx * NUM_REGIONS) + pmp_aw_region_idx) * 2+:2] <= pmp_w_next_val[1:0];
							end
							else begin
								pmp_limit_addr_reg[((aw_slot_idx * NUM_REGIONS) + pmp_aw_region_idx) * COMP_WIDTH+:COMP_WIDTH] <= pmp_w_next_val[MAX_ADDRESS_WIDTH - 1:ADDR_SHIFT];
								pmp_limit_cfg_reg[((aw_slot_idx * NUM_REGIONS) + pmp_aw_region_idx) * 2+:2] <= pmp_w_next_val[1:0];
							end
						end
					end
				end
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
					12'h004: axi_rdata <= {29'd0, user_design_loaded_reg, efpga_com_active_i, soft_reset_reg};
					12'h008: axi_rdata <= 32'h00000000;
					12'h00c: axi_rdata <= config_count_reg;
					default: axi_rdata <= 32'hbad00000;
				endcase
			else if (ar_slot_idx < NUM_SLOTS) begin
				if ((local_araddr[11:0] & 12'hffc) < 12'h014)
					case (local_araddr[11:0] & 12'hffc)
						12'h000: axi_rdata <= {6'd0, wb_m_enable_reg[ar_slot_idx], wb_s_enable_reg[ar_slot_idx], 4'd0, wdog_en_cm[ar_slot_idx], wdog_en_ds[ar_slot_idx], wdog_en_cs[ar_slot_idx], wdog_en_dm[ar_slot_idx], 7'd0, pmp_g_en_reg[ar_slot_idx], 6'd0, dec_force_reg[ar_slot_idx], dec_req_reg[ar_slot_idx]};
						12'h004: axi_rdata <= {11'd0, wdog_soc_flag[ar_slot_idx], wdog_cs_to_flag[ar_slot_idx], wdog_cs_pr_flag[ar_slot_idx], wdog_dm_to_flag[ar_slot_idx], wdog_dm_pr_flag[ar_slot_idx], 6'd0, pmp_w_flag_reg[ar_slot_idx], pmp_r_flag_reg[ar_slot_idx], 5'd0, decoupler_dma_act_i[ar_slot_idx], decoupler_host_act_i[ar_slot_idx], decoupler_is_decoupled_i[ar_slot_idx]};
						12'h008: axi_rdata <= 32'h00000000;
						12'h00c: axi_rdata <= slot_o_top_reg[ar_slot_idx * 32+:32];
						12'h010: axi_rdata <= slot_i_top_i[ar_slot_idx * 32+:32];
						default: axi_rdata <= 32'hbad00001;
					endcase
				else if (ENABLE_PMP) begin
					if (pmp_ar_region_idx < NUM_REGIONS) begin
						if (pmp_ar_offset[2] == 1'b0)
							axi_rdata <= pmp_base_o[((ar_slot_idx * NUM_REGIONS) + pmp_ar_region_idx) * 32+:32];
						else
							axi_rdata <= pmp_limit_o[((ar_slot_idx * NUM_REGIONS) + pmp_ar_region_idx) * 32+:32];
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
