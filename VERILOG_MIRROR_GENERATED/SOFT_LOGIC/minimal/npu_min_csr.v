module npu_min_csr (
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
	act_base_o,
	weight_base_o,
	out_base_o,
	bias_base_o,
	quant_param_o,
	config_o,
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
	output wire s_axil_awready;
	input wire [AXI_DATA_WIDTH - 1:0] s_axil_wdata;
	input wire [(AXI_DATA_WIDTH / 8) - 1:0] s_axil_wstrb;
	input wire s_axil_wvalid;
	output wire s_axil_wready;
	output reg [1:0] s_axil_bresp;
	output reg s_axil_bvalid;
	input wire s_axil_bready;
	input wire [AXI_ADDR_WIDTH - 1:0] s_axil_araddr;
	input wire [2:0] s_axil_arprot;
	input wire s_axil_arvalid;
	output wire s_axil_arready;
	output reg [AXI_DATA_WIDTH - 1:0] s_axil_rdata;
	output reg [1:0] s_axil_rresp;
	output reg s_axil_rvalid;
	input wire s_axil_rready;
	output reg start_pulse_o;
	output reg soft_reset_o;
	output wire [31:0] act_base_o;
	output wire [31:0] weight_base_o;
	output wire [31:0] out_base_o;
	output wire [31:0] bias_base_o;
	output wire [31:0] quant_param_o;
	output wire [31:0] config_o;
	output wire [3:0] usr_irq_o;
	input wire fsm_busy_i;
	input wire fsm_done_i;
	input wire irq_pulse_i;
	reg [31:0] reg_act_base;
	reg [31:0] reg_weight_base;
	reg [31:0] reg_out_base;
	reg [31:0] reg_bias_base;
	reg [29:0] reg_quant_param;
	reg reg_auto_drain;
	reg reg_irq_status;
	reg reg_done;
	assign act_base_o = reg_act_base;
	assign weight_base_o = reg_weight_base;
	assign out_base_o = reg_out_base;
	assign bias_base_o = reg_bias_base;
	assign quant_param_o = {2'b00, reg_quant_param};
	assign config_o = {31'b0000000000000000000000000000000, reg_auto_drain};
	assign usr_irq_o = {3'b000, irq_pulse_i};
	assign s_axil_awready = !s_axil_bvalid;
	assign s_axil_wready = !s_axil_bvalid;
	always @(posedge clk_i)
		if (!rst_n) begin
			s_axil_bvalid <= 1'b0;
			s_axil_bresp <= 2'b00;
			start_pulse_o <= 1'b0;
			soft_reset_o <= 1'b0;
			reg_act_base <= 32'h00001000;
			reg_weight_base <= 32'h00002000;
			reg_out_base <= 32'h00003000;
			reg_bias_base <= 32'h00004000;
			reg_quant_param <= 30'h000f4000;
			reg_auto_drain <= 1'b1;
			reg_irq_status <= 1'b0;
			reg_done <= 1'b0;
		end
		else begin
			start_pulse_o <= 1'b0;
			soft_reset_o <= 1'b0;
			if (fsm_done_i)
				reg_done <= 1'b1;
			if (irq_pulse_i)
				reg_irq_status <= 1'b1;
			if ((s_axil_awvalid && s_axil_wvalid) && !s_axil_bvalid) begin
				s_axil_bvalid <= 1'b1;
				case (s_axil_awaddr[5:2])
					4'h0: begin
						if (s_axil_wdata[0]) begin
							start_pulse_o <= 1'b1;
							reg_done <= 1'b0;
						end
						if (s_axil_wdata[1]) begin
							soft_reset_o <= 1'b1;
							reg_done <= 1'b0;
						end
					end
					4'h2: reg_act_base <= s_axil_wdata;
					4'h3: reg_weight_base <= s_axil_wdata;
					4'h4: reg_out_base <= s_axil_wdata;
					4'h5: reg_bias_base <= s_axil_wdata;
					4'h6: reg_quant_param <= s_axil_wdata[29:0];
					4'h7: reg_auto_drain <= s_axil_wdata[0];
					4'h8:
						if (s_axil_wdata[0])
							reg_irq_status <= 1'b0;
					default:
						;
				endcase
			end
			else if (s_axil_bvalid && s_axil_bready)
				s_axil_bvalid <= 1'b0;
		end
	assign s_axil_arready = !s_axil_rvalid;
	always @(posedge clk_i)
		if (!rst_n) begin
			s_axil_rvalid <= 1'b0;
			s_axil_rresp <= 2'b00;
			s_axil_rdata <= 32'h00000000;
		end
		else if (s_axil_arvalid && !s_axil_rvalid) begin
			s_axil_rvalid <= 1'b1;
			if (s_axil_araddr[5:2] == 4'h8)
				s_axil_rdata <= {31'b0000000000000000000000000000000, reg_irq_status};
			else
				s_axil_rdata <= {30'b000000000000000000000000000000, reg_done, fsm_busy_i};
		end
		else if (s_axil_rvalid && s_axil_rready)
			s_axil_rvalid <= 1'b0;
endmodule
