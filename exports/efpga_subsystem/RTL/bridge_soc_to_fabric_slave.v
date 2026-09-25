module bridge_soc_to_fabric_slave (
	clk,
	resetn,
	cfg_wb_enable,
	soc_awaddr,
	soc_awprot,
	soc_awvalid,
	soc_awready,
	soc_wdata,
	soc_wstrb,
	soc_wvalid,
	soc_wready,
	soc_bresp,
	soc_bvalid,
	soc_bready,
	soc_araddr,
	soc_arprot,
	soc_arvalid,
	soc_arready,
	soc_rdata,
	soc_rresp,
	soc_rvalid,
	soc_rready,
	fab_awaddr,
	fab_awprot,
	fab_awvalid,
	fab_awready,
	fab_wdata,
	fab_wstrb,
	fab_wvalid,
	fab_wready,
	fab_bresp,
	fab_bvalid,
	fab_bready,
	fab_araddr,
	fab_arprot,
	fab_arvalid,
	fab_arready,
	fab_rdata,
	fab_rresp,
	fab_rvalid,
	fab_rready
);
	input wire clk;
	input wire resetn;
	input wire cfg_wb_enable;
	input wire [31:0] soc_awaddr;
	input wire [2:0] soc_awprot;
	input wire soc_awvalid;
	output wire soc_awready;
	input wire [31:0] soc_wdata;
	input wire [3:0] soc_wstrb;
	input wire soc_wvalid;
	output wire soc_wready;
	output wire [1:0] soc_bresp;
	output wire soc_bvalid;
	input wire soc_bready;
	input wire [31:0] soc_araddr;
	input wire [2:0] soc_arprot;
	input wire soc_arvalid;
	output wire soc_arready;
	output wire [31:0] soc_rdata;
	output wire [1:0] soc_rresp;
	output wire soc_rvalid;
	input wire soc_rready;
	output wire [31:0] fab_awaddr;
	output wire [2:0] fab_awprot;
	output wire fab_awvalid;
	input wire fab_awready;
	output wire [31:0] fab_wdata;
	output wire [3:0] fab_wstrb;
	output wire fab_wvalid;
	input wire fab_wready;
	input wire [1:0] fab_bresp;
	input wire fab_bvalid;
	output wire fab_bready;
	output wire [31:0] fab_araddr;
	output wire [2:0] fab_arprot;
	output wire fab_arvalid;
	input wire fab_arready;
	input wire [31:0] fab_rdata;
	input wire [1:0] fab_rresp;
	input wire fab_rvalid;
	output wire fab_rready;
	reg [1:0] state;
	reg [31:0] wb_addr_reg;
	reg [31:0] wb_data_reg;
	reg [31:0] wb_rdata_reg;
	reg [3:0] wb_sel_reg;
	reg wb_we_reg;
	reg wb_err_reg;
	reg int_soc_awready;
	reg int_soc_wready;
	reg int_soc_arready;
	reg int_soc_bvalid;
	reg int_soc_rvalid;
	always @(posedge clk or negedge resetn)
		if (!resetn) begin
			state <= 2'd0;
			int_soc_awready <= 0;
			int_soc_wready <= 0;
			int_soc_arready <= 0;
			int_soc_bvalid <= 0;
			int_soc_rvalid <= 0;
		end
		else begin
			int_soc_awready <= 0;
			int_soc_wready <= 0;
			int_soc_arready <= 0;
			case (state)
				2'd0:
					if (cfg_wb_enable) begin
						if (soc_awvalid && soc_wvalid) begin
							wb_addr_reg <= soc_awaddr;
							wb_data_reg <= soc_wdata;
							wb_sel_reg <= soc_wstrb;
							wb_we_reg <= 1'b1;
							int_soc_awready <= 1'b1;
							int_soc_wready <= 1'b1;
							state <= 2'd1;
						end
						else if (soc_arvalid) begin
							wb_addr_reg <= soc_araddr;
							wb_we_reg <= 1'b0;
							int_soc_arready <= 1'b1;
							state <= 2'd2;
						end
					end
				2'd1, 2'd2:
					if (fab_awready) begin
						wb_rdata_reg <= fab_rdata;
						wb_err_reg <= fab_bresp[0];
						state <= 2'd3;
					end
				2'd3:
					if (wb_we_reg) begin
						int_soc_bvalid <= 1'b1;
						if (soc_bready && int_soc_bvalid) begin
							int_soc_bvalid <= 1'b0;
							state <= 2'd0;
						end
					end
					else begin
						int_soc_rvalid <= 1'b1;
						if (soc_rready && int_soc_rvalid) begin
							int_soc_rvalid <= 1'b0;
							state <= 2'd0;
						end
					end
				default:
					;
			endcase
		end
	assign fab_awaddr = (cfg_wb_enable ? wb_addr_reg : soc_awaddr);
	assign fab_awprot = (cfg_wb_enable ? {2'b00, wb_we_reg} : soc_awprot);
	assign fab_awvalid = (cfg_wb_enable ? (state == 2'd1) || (state == 2'd2) : soc_awvalid);
	assign fab_wdata = (cfg_wb_enable ? wb_data_reg : soc_wdata);
	assign fab_wstrb = (cfg_wb_enable ? wb_sel_reg : soc_wstrb);
	assign fab_wvalid = (cfg_wb_enable ? (state == 2'd1) || (state == 2'd2) : soc_wvalid);
	assign fab_araddr = (cfg_wb_enable ? wb_addr_reg : soc_araddr);
	assign fab_arprot = (cfg_wb_enable ? 3'b000 : soc_arprot);
	assign fab_arvalid = (cfg_wb_enable ? 1'b0 : soc_arvalid);
	assign fab_bready = (cfg_wb_enable ? 1'b0 : soc_bready);
	assign fab_rready = (cfg_wb_enable ? 1'b0 : soc_rready);
	assign soc_awready = (cfg_wb_enable ? int_soc_awready : fab_awready);
	assign soc_wready = (cfg_wb_enable ? int_soc_wready : fab_wready);
	assign soc_arready = (cfg_wb_enable ? int_soc_arready : fab_arready);
	assign soc_bvalid = (cfg_wb_enable ? int_soc_bvalid : fab_bvalid);
	assign soc_rvalid = (cfg_wb_enable ? int_soc_rvalid : fab_rvalid);
	assign soc_bresp = (cfg_wb_enable ? {wb_err_reg, 1'b0} : fab_bresp);
	assign soc_rresp = (cfg_wb_enable ? {wb_err_reg, 1'b0} : fab_rresp);
	assign soc_rdata = (cfg_wb_enable ? wb_rdata_reg : fab_rdata);
endmodule
