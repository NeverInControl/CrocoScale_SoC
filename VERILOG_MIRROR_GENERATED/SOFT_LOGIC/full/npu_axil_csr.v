module npu_axil_csr (
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
	start_drain_pulse_o,
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
	reg _sv2v_0;
	parameter signed [31:0] AXI_ADDR_WIDTH = 32;
	parameter signed [31:0] AXI_DATA_WIDTH = 32;
	input wire clk_i;
	input wire rst_n;
	input wire [AXI_ADDR_WIDTH - 1:0] s_axil_awaddr;
	input wire [2:0] s_axil_awprot;
	input wire s_axil_awvalid;
	output wire s_axil_awready;
	input wire [AXI_DATA_WIDTH - 1:0] s_axil_wdata;
	input wire [(AXI_DATA_WIDTH / 8) - 1:0] s_axil_wstrb;
	input wire s_axil_wvalid;
	output wire s_axil_wready;
	output wire [1:0] s_axil_bresp;
	output reg s_axil_bvalid;
	input wire s_axil_bready;
	input wire [AXI_ADDR_WIDTH - 1:0] s_axil_araddr;
	input wire [2:0] s_axil_arprot;
	input wire s_axil_arvalid;
	output wire s_axil_arready;
	output wire [AXI_DATA_WIDTH - 1:0] s_axil_rdata;
	output wire [1:0] s_axil_rresp;
	output reg s_axil_rvalid;
	input wire s_axil_rready;
	output reg start_pulse_o;
	output reg start_drain_pulse_o;
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
	reg reg_soft_reset;
	reg reg_auto_drain;
	reg reg_mode_1x1;
	reg reg_lut_en;
	reg reg_pool_en;
	reg [7:0] reg_total_passes;
	reg reg_irq_status;
	reg reg_done;
	reg [31:0] reg_act_base;
	reg [31:0] reg_weight_base;
	reg [31:0] reg_out_base;
	reg [31:0] reg_bias_base;
	reg [31:0] reg_quant_base;
	reg [31:0] reg_lut_base;
	assign config_o = {16'b0000000000000000, reg_total_passes, 1'b0, reg_pool_en, reg_lut_en, reg_mode_1x1, 3'b000, reg_auto_drain};
	assign act_base_o = reg_act_base;
	assign weight_base_o = reg_weight_base;
	assign out_base_o = reg_out_base;
	assign bias_base_o = reg_bias_base;
	assign quant_base_o = reg_quant_base;
	assign lut_base_o = reg_lut_base;
	assign soft_reset_o = reg_soft_reset;
	assign usr_irq_o = {3'b000, irq_pulse_i};
	wire write_req = s_axil_awvalid && s_axil_wvalid;
	assign s_axil_awready = !s_axil_bvalid;
	assign s_axil_wready = !s_axil_bvalid;
	assign s_axil_bresp = 2'b00;
	always @(posedge clk_i or negedge rst_n)
		if (!rst_n) begin
			s_axil_bvalid <= 1'b0;
			start_pulse_o <= 1'b0;
			start_drain_pulse_o <= 1'b0;
			reg_soft_reset <= 1'b0;
			reg_auto_drain <= 1'b1;
			reg_mode_1x1 <= 1'b0;
			reg_lut_en <= 1'b0;
			reg_pool_en <= 1'b0;
			reg_total_passes <= 8'd0;
			reg_irq_status <= 1'b0;
			reg_done <= 1'b0;
			reg_act_base <= 32'h00001000;
			reg_weight_base <= 32'h00002000;
			reg_out_base <= 32'h00003000;
			reg_bias_base <= 32'h00004000;
			reg_quant_base <= 32'h00005000;
			reg_lut_base <= 32'h00006000;
		end
		else begin
			start_pulse_o <= 1'b0;
			start_drain_pulse_o <= 1'b0;
			if (fsm_done_i)
				reg_done <= 1'b1;
			if (irq_pulse_i)
				reg_irq_status <= 1'b1;
			if (write_req && !s_axil_bvalid) begin
				s_axil_bvalid <= 1'b1;
				case (s_axil_awaddr[7:0])
					REG_OFFSET_CTRL: begin
						if (s_axil_wdata[0]) begin
							start_pulse_o <= 1'b1;
							reg_done <= 1'b0;
						end
						if (s_axil_wdata[1]) begin
							reg_soft_reset <= 1'b1;
							reg_done <= 1'b0;
						end
						else
							reg_soft_reset <= 1'b0;
						if (s_axil_wdata[2]) begin
							start_drain_pulse_o <= 1'b1;
							reg_done <= 1'b0;
						end
					end
					REG_OFFSET_CONFIG: begin
						reg_auto_drain <= s_axil_wdata[0];
						reg_mode_1x1 <= s_axil_wdata[4];
						reg_lut_en <= s_axil_wdata[5];
						reg_pool_en <= s_axil_wdata[6];
						reg_total_passes <= s_axil_wdata[15:8];
					end
					REG_OFFSET_IRQ_STATUS:
						if (s_axil_wdata[0])
							reg_irq_status <= 1'b0;
					REG_OFFSET_ACT_BASE: reg_act_base <= s_axil_wdata;
					REG_OFFSET_WEIGHT_BASE: reg_weight_base <= s_axil_wdata;
					REG_OFFSET_OUT_BASE: reg_out_base <= s_axil_wdata;
					REG_OFFSET_BIAS_BASE: reg_bias_base <= s_axil_wdata;
					REG_OFFSET_QUANT_BASE: reg_quant_base <= s_axil_wdata;
					REG_OFFSET_LUT_BASE: reg_lut_base <= s_axil_wdata;
					default:
						;
				endcase
			end
			else if (s_axil_bvalid && s_axil_bready)
				s_axil_bvalid <= 1'b0;
		end
	reg [31:0] rdata_comb;
	always @(*) begin
		if (_sv2v_0)
			;
		case (s_axil_araddr[7:0])
			REG_OFFSET_CTRL: rdata_comb = {30'b000000000000000000000000000000, reg_soft_reset, 1'b0};
			REG_OFFSET_STATUS: rdata_comb = {30'b000000000000000000000000000000, reg_done, fsm_busy_i};
			REG_OFFSET_CONFIG: rdata_comb = {16'b0000000000000000, reg_total_passes, 1'b0, reg_pool_en, reg_lut_en, reg_mode_1x1, 3'b000, reg_auto_drain};
			REG_OFFSET_IRQ_STATUS: rdata_comb = {31'b0000000000000000000000000000000, reg_irq_status};
			default: rdata_comb = 32'd0;
		endcase
	end
	assign s_axil_rdata = rdata_comb;
	assign s_axil_rresp = 2'b00;
	assign s_axil_arready = !s_axil_rvalid;
	always @(posedge clk_i or negedge rst_n)
		if (!rst_n)
			s_axil_rvalid <= 1'b0;
		else if (s_axil_arvalid && s_axil_arready)
			s_axil_rvalid <= 1'b1;
		else if (s_axil_rvalid && s_axil_rready)
			s_axil_rvalid <= 1'b0;
	initial _sv2v_0 = 0;
endmodule
