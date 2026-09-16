module npu_full_regs (
	clk_i,
	rst_n,
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
	start_pulse_o,
	soft_reset_o,
	config_o,
	act_base_o,
	weight_base_o,
	out_base_o,
	bias_base_o,
	quant_base_o,
	lut_base_o,
	usr_irq_o,
	fsm_busy_i,
	fsm_done_i,
	irq_pulse_i
);
	parameter signed [31:0] AXI_ADDR_WIDTH = 32;
	parameter signed [31:0] AXI_DATA_WIDTH = 32;
	input wire clk_i;
	input wire rst_n;
	input wire [AXI_ADDR_WIDTH - 1:0] s_axil_awaddr;
	input wire [2:0] s_axil_awprot;
	input wire s_axil_awvalid;
	output reg s_axil_awready;
	input wire [AXI_DATA_WIDTH - 1:0] s_axil_wdata;
	input wire [(AXI_DATA_WIDTH / 8) - 1:0] s_axil_wstrb;
	input wire s_axil_wvalid;
	output reg s_axil_wready;
	output reg [1:0] s_axil_bresp;
	output reg s_axil_bvalid;
	input wire s_axil_bready;
	input wire [AXI_ADDR_WIDTH - 1:0] s_axil_araddr;
	input wire [2:0] s_axil_arprot;
	input wire s_axil_arvalid;
	output reg s_axil_arready;
	output reg [AXI_DATA_WIDTH - 1:0] s_axil_rdata;
	output reg [1:0] s_axil_rresp;
	output reg s_axil_rvalid;
	input wire s_axil_rready;
	output reg start_pulse_o;
	output wire soft_reset_o;
	output wire [31:0] config_o;
	output wire [31:0] act_base_o;
	output wire [31:0] weight_base_o;
	output wire [31:0] out_base_o;
	output wire [31:0] bias_base_o;
	output wire [31:0] quant_base_o;
	output wire [31:0] lut_base_o;
	output wire [3:0] usr_irq_o;
	input wire fsm_busy_i;
	input wire fsm_done_i;
	input wire irq_pulse_i;
	localparam [7:0] REG_OFFSET_CTRL = 8'h00;
	localparam [7:0] REG_OFFSET_STATUS = 8'h04;
	localparam [7:0] REG_OFFSET_CONFIG = 8'h08;
	localparam [7:0] REG_OFFSET_IRQ_STATUS = 8'h0c;
	localparam [7:0] REG_OFFSET_ACT_BASE = 8'h10;
	localparam [7:0] REG_OFFSET_WEIGHT_BASE = 8'h14;
	localparam [7:0] REG_OFFSET_OUT_BASE = 8'h18;
	localparam [7:0] REG_OFFSET_BIAS_BASE = 8'h1c;
	localparam [7:0] REG_OFFSET_QUANT_BASE = 8'h20;
	localparam [7:0] REG_OFFSET_LUT_BASE = 8'h24;
	reg [31:0] reg_ctrl;
	reg [31:0] reg_config;
	reg reg_irq_status;
	reg [31:0] reg_act_base;
	reg [31:0] reg_weight_base;
	reg [31:0] reg_out_base;
	reg [31:0] reg_bias_base;
	reg [31:0] reg_quant_base;
	reg [31:0] reg_lut_base;
	reg reg_done;
	assign config_o = reg_config;
	assign act_base_o = reg_act_base;
	assign weight_base_o = reg_weight_base;
	assign out_base_o = reg_out_base;
	assign bias_base_o = reg_bias_base;
	assign quant_base_o = reg_quant_base;
	assign lut_base_o = reg_lut_base;
	assign soft_reset_o = reg_ctrl[1];
	assign usr_irq_o = {3'b000, irq_pulse_i};
	wire [31:0] reg_status = {30'b000000000000000000000000000000, reg_done, fsm_busy_i};
	reg aw_done;
	reg w_done;
	reg [7:0] latched_waddr;
	reg [31:0] latched_wdata;
	always @(posedge clk_i or negedge rst_n)
		if (!rst_n) begin
			s_axil_awready <= 1'b1;
			s_axil_wready <= 1'b1;
			s_axil_bvalid <= 1'b0;
			s_axil_bresp <= 2'b00;
			aw_done <= 1'b0;
			w_done <= 1'b0;
			latched_waddr <= 8'h00;
			latched_wdata <= 32'h00000000;
			start_pulse_o <= 1'b0;
			reg_ctrl <= 32'h00000000;
			reg_config <= 32'h00000001;
			reg_irq_status <= 1'b0;
			reg_act_base <= 32'h00001000;
			reg_weight_base <= 32'h00002000;
			reg_out_base <= 32'h00003000;
			reg_bias_base <= 32'h00004000;
			reg_quant_base <= 32'h00005000;
			reg_lut_base <= 32'h00006000;
			reg_done <= 1'b0;
		end
		else begin
			start_pulse_o <= 1'b0;
			if (reg_ctrl[0]) begin
				reg_ctrl[0] <= 1'b0;
				reg_done <= 1'b0;
			end
			if (reg_ctrl[1])
				reg_done <= 1'b0;
			if (fsm_done_i)
				reg_done <= 1'b1;
			if (irq_pulse_i)
				reg_irq_status <= 1'b1;
			if (s_axil_awvalid && s_axil_awready) begin
				latched_waddr <= s_axil_awaddr[7:0];
				aw_done <= 1'b1;
				s_axil_awready <= 1'b0;
			end
			if (s_axil_wvalid && s_axil_wready) begin
				latched_wdata <= s_axil_wdata;
				w_done <= 1'b1;
				s_axil_wready <= 1'b0;
			end
			if (((aw_done || (s_axil_awvalid && s_axil_awready)) && (w_done || (s_axil_wvalid && s_axil_wready))) && !s_axil_bvalid) begin : sv2v_autoblock_1
				reg [7:0] target_addr;
				reg [31:0] target_data;
				target_addr = (s_axil_awvalid && s_axil_awready ? s_axil_awaddr[7:0] : latched_waddr);
				target_data = (s_axil_wvalid && s_axil_wready ? s_axil_wdata : latched_wdata);
				case (target_addr)
					REG_OFFSET_CTRL: begin
						reg_ctrl <= target_data;
						if (target_data[0])
							start_pulse_o <= 1'b1;
					end
					REG_OFFSET_CONFIG: reg_config <= target_data;
					REG_OFFSET_IRQ_STATUS:
						if (target_data[0])
							reg_irq_status <= 1'b0;
					REG_OFFSET_ACT_BASE: reg_act_base <= target_data;
					REG_OFFSET_WEIGHT_BASE: reg_weight_base <= target_data;
					REG_OFFSET_OUT_BASE: reg_out_base <= target_data;
					REG_OFFSET_BIAS_BASE: reg_bias_base <= target_data;
					REG_OFFSET_QUANT_BASE: reg_quant_base <= target_data;
					REG_OFFSET_LUT_BASE: reg_lut_base <= target_data;
					default:
						;
				endcase
				s_axil_bvalid <= 1'b1;
				s_axil_bresp <= 2'b00;
				aw_done <= 1'b0;
				w_done <= 1'b0;
			end
			if (s_axil_bvalid && s_axil_bready) begin
				s_axil_bvalid <= 1'b0;
				s_axil_awready <= 1'b1;
				s_axil_wready <= 1'b1;
			end
		end
	always @(posedge clk_i or negedge rst_n)
		if (!rst_n) begin
			s_axil_arready <= 1'b1;
			s_axil_rvalid <= 1'b0;
			s_axil_rresp <= 2'b00;
			s_axil_rdata <= 32'h00000000;
		end
		else if (s_axil_arvalid && s_axil_arready) begin
			s_axil_arready <= 1'b0;
			s_axil_rvalid <= 1'b1;
			s_axil_rresp <= 2'b00;
			case (s_axil_araddr[7:0])
				REG_OFFSET_CTRL: s_axil_rdata <= reg_ctrl;
				REG_OFFSET_STATUS: s_axil_rdata <= reg_status;
				REG_OFFSET_CONFIG: s_axil_rdata <= reg_config;
				REG_OFFSET_IRQ_STATUS: s_axil_rdata <= {31'b0000000000000000000000000000000, reg_irq_status};
				REG_OFFSET_ACT_BASE: s_axil_rdata <= reg_act_base;
				REG_OFFSET_WEIGHT_BASE: s_axil_rdata <= reg_weight_base;
				REG_OFFSET_OUT_BASE: s_axil_rdata <= reg_out_base;
				REG_OFFSET_BIAS_BASE: s_axil_rdata <= reg_bias_base;
				REG_OFFSET_QUANT_BASE: s_axil_rdata <= reg_quant_base;
				REG_OFFSET_LUT_BASE: s_axil_rdata <= reg_lut_base;
				default: s_axil_rdata <= 32'hbad00001;
			endcase
		end
		else if (s_axil_rvalid && s_axil_rready) begin
			s_axil_rvalid <= 1'b0;
			s_axil_arready <= 1'b1;
		end
endmodule
