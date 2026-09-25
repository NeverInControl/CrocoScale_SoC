module bridge_fabric_master_to_soc (
	clk,
	resetn,
	cfg_wb_enable,
	fab_awid,
	fab_awaddr,
	fab_awlen,
	fab_awsize,
	fab_awburst,
	fab_awlock,
	fab_awcache,
	fab_awprot,
	fab_awvalid,
	fab_awready,
	fab_wdata,
	fab_wstrb,
	fab_wlast,
	fab_wvalid,
	fab_wready,
	fab_bid,
	fab_bresp,
	fab_bvalid,
	fab_bready,
	fab_arid,
	fab_araddr,
	fab_arlen,
	fab_arsize,
	fab_arburst,
	fab_arlock,
	fab_arcache,
	fab_arprot,
	fab_arvalid,
	fab_arready,
	fab_rid,
	fab_rdata,
	fab_rresp,
	fab_rlast,
	fab_rvalid,
	fab_rready,
	soc_awid,
	soc_awaddr,
	soc_awlen,
	soc_awsize,
	soc_awburst,
	soc_awlock,
	soc_awcache,
	soc_awprot,
	soc_awvalid,
	soc_awready,
	soc_wdata,
	soc_wstrb,
	soc_wlast,
	soc_wvalid,
	soc_wready,
	soc_bid,
	soc_bresp,
	soc_bvalid,
	soc_bready,
	soc_arid,
	soc_araddr,
	soc_arlen,
	soc_arsize,
	soc_arburst,
	soc_arlock,
	soc_arcache,
	soc_arprot,
	soc_arvalid,
	soc_arready,
	soc_rid,
	soc_rdata,
	soc_rresp,
	soc_rlast,
	soc_rvalid,
	soc_rready
);
	parameter signed [31:0] AXI_ID_WIDTH = 8;
	input wire clk;
	input wire resetn;
	input wire cfg_wb_enable;
	input wire [AXI_ID_WIDTH - 1:0] fab_awid;
	input wire [31:0] fab_awaddr;
	input wire [7:0] fab_awlen;
	input wire [2:0] fab_awsize;
	input wire [1:0] fab_awburst;
	input wire fab_awlock;
	input wire [3:0] fab_awcache;
	input wire [2:0] fab_awprot;
	input wire fab_awvalid;
	output wire fab_awready;
	input wire [31:0] fab_wdata;
	input wire [3:0] fab_wstrb;
	input wire fab_wlast;
	input wire fab_wvalid;
	output wire fab_wready;
	output wire [AXI_ID_WIDTH - 1:0] fab_bid;
	output wire [1:0] fab_bresp;
	output wire fab_bvalid;
	input wire fab_bready;
	input wire [AXI_ID_WIDTH - 1:0] fab_arid;
	input wire [31:0] fab_araddr;
	input wire [7:0] fab_arlen;
	input wire [2:0] fab_arsize;
	input wire [1:0] fab_arburst;
	input wire fab_arlock;
	input wire [3:0] fab_arcache;
	input wire [2:0] fab_arprot;
	input wire fab_arvalid;
	output wire fab_arready;
	output wire [AXI_ID_WIDTH - 1:0] fab_rid;
	output wire [31:0] fab_rdata;
	output wire [1:0] fab_rresp;
	output wire fab_rlast;
	output wire fab_rvalid;
	input wire fab_rready;
	output wire [AXI_ID_WIDTH - 1:0] soc_awid;
	output wire [31:0] soc_awaddr;
	output wire [7:0] soc_awlen;
	output wire [2:0] soc_awsize;
	output wire [1:0] soc_awburst;
	output wire soc_awlock;
	output wire [3:0] soc_awcache;
	output wire [2:0] soc_awprot;
	output wire soc_awvalid;
	input wire soc_awready;
	output wire [31:0] soc_wdata;
	output wire [3:0] soc_wstrb;
	output wire soc_wlast;
	output wire soc_wvalid;
	input wire soc_wready;
	input wire [AXI_ID_WIDTH - 1:0] soc_bid;
	input wire [1:0] soc_bresp;
	input wire soc_bvalid;
	output wire soc_bready;
	output wire [AXI_ID_WIDTH - 1:0] soc_arid;
	output wire [31:0] soc_araddr;
	output wire [7:0] soc_arlen;
	output wire [2:0] soc_arsize;
	output wire [1:0] soc_arburst;
	output wire soc_arlock;
	output wire [3:0] soc_arcache;
	output wire [2:0] soc_arprot;
	output wire soc_arvalid;
	input wire soc_arready;
	input wire [AXI_ID_WIDTH - 1:0] soc_rid;
	input wire [31:0] soc_rdata;
	input wire [1:0] soc_rresp;
	input wire soc_rlast;
	input wire soc_rvalid;
	output wire soc_rready;
	reg [1:0] m_state;
	reg aw_done;
	reg w_done;
	wire wb_stall;
	reg wb_ack;
	wire incoming_req;
	reg [31:0] int_soc_awaddr;
	reg [31:0] int_soc_wdata;
	reg [31:0] int_soc_araddr;
	reg [3:0] int_soc_wstrb;
	reg int_soc_awvalid;
	reg int_soc_wvalid;
	reg int_soc_arvalid;
	always @(posedge clk or negedge resetn)
		if (!resetn) begin
			m_state <= 2'd0;
			int_soc_awvalid <= 0;
			int_soc_wvalid <= 0;
			int_soc_arvalid <= 0;
			aw_done <= 0;
			w_done <= 0;
			wb_ack <= 0;
		end
		else begin
			wb_ack <= 0;
			case (m_state)
				2'd0: begin
					aw_done <= 0;
					w_done <= 0;
					if ((cfg_wb_enable && fab_awvalid) && fab_wvalid) begin
						if (fab_awlock) begin
							int_soc_awaddr <= fab_awaddr;
							int_soc_wdata <= fab_wdata;
							int_soc_wstrb <= fab_wstrb;
							int_soc_awvalid <= 1'b1;
							int_soc_wvalid <= 1'b1;
							m_state <= 2'd1;
						end
						else begin
							int_soc_araddr <= fab_awaddr;
							int_soc_arvalid <= 1'b1;
							m_state <= 2'd2;
						end
					end
				end
				2'd1: begin
					if (soc_awready) begin
						int_soc_awvalid <= 1'b0;
						aw_done <= 1'b1;
					end
					if (soc_wready) begin
						int_soc_wvalid <= 1'b0;
						w_done <= 1'b1;
					end
					if ((soc_awready || aw_done) && (soc_wready || w_done)) begin
						if (soc_bvalid) begin
							wb_ack <= 1'b1;
							m_state <= 2'd0;
						end
					end
				end
				2'd2: begin
					if (soc_arready)
						int_soc_arvalid <= 1'b0;
					if (soc_rvalid) begin
						wb_ack <= 1'b1;
						m_state <= 2'd0;
					end
				end
				default:
					;
			endcase
		end
	assign incoming_req = (cfg_wb_enable && fab_awvalid) && fab_wvalid;
	assign wb_stall = (m_state != 2'd0) || incoming_req;
	assign soc_awid = fab_awid;
	assign soc_arid = fab_arid;
	assign fab_bid = soc_bid;
	assign fab_rid = soc_rid;
	assign fab_rdata = soc_rdata;
	assign fab_rlast = soc_rlast;
	assign soc_awaddr = (cfg_wb_enable ? int_soc_awaddr : fab_awaddr);
	assign soc_awlen = (cfg_wb_enable ? 8'h00 : fab_awlen);
	assign soc_awsize = (cfg_wb_enable ? 3'b010 : fab_awsize);
	assign soc_awburst = (cfg_wb_enable ? 2'b01 : fab_awburst);
	assign soc_awlock = (cfg_wb_enable ? 1'b0 : fab_awlock);
	assign soc_awcache = (cfg_wb_enable ? 4'b0011 : fab_awcache);
	assign soc_awprot = (cfg_wb_enable ? 3'b000 : fab_awprot);
	assign soc_awvalid = (cfg_wb_enable ? int_soc_awvalid : fab_awvalid);
	assign soc_wdata = (cfg_wb_enable ? int_soc_wdata : fab_wdata);
	assign soc_wstrb = (cfg_wb_enable ? int_soc_wstrb : fab_wstrb);
	assign soc_wlast = (cfg_wb_enable ? 1'b1 : fab_wlast);
	assign soc_wvalid = (cfg_wb_enable ? int_soc_wvalid : fab_wvalid);
	assign soc_bready = (cfg_wb_enable ? 1'b1 : fab_bready);
	assign soc_araddr = (cfg_wb_enable ? int_soc_araddr : fab_araddr);
	assign soc_arlen = (cfg_wb_enable ? 8'h00 : fab_arlen);
	assign soc_arsize = (cfg_wb_enable ? 3'b010 : fab_arsize);
	assign soc_arburst = (cfg_wb_enable ? 2'b01 : fab_arburst);
	assign soc_arlock = (cfg_wb_enable ? 1'b0 : fab_arlock);
	assign soc_arcache = (cfg_wb_enable ? 4'b0011 : fab_arcache);
	assign soc_arprot = (cfg_wb_enable ? 3'b000 : fab_arprot);
	assign soc_arvalid = (cfg_wb_enable ? int_soc_arvalid : fab_arvalid);
	assign soc_rready = (cfg_wb_enable ? 1'b1 : fab_rready);
	assign fab_awready = (cfg_wb_enable ? wb_ack : soc_awready);
	assign fab_wready = (cfg_wb_enable ? wb_stall : soc_wready);
	assign fab_arready = (cfg_wb_enable ? 1'b0 : soc_arready);
	assign fab_bvalid = (cfg_wb_enable ? 1'b0 : soc_bvalid);
	assign fab_rvalid = (cfg_wb_enable ? 1'b0 : soc_rvalid);
	assign fab_bresp = (cfg_wb_enable ? {1'b0, soc_bresp[1]} : soc_bresp);
	assign fab_rresp = (cfg_wb_enable ? {1'b0, soc_rresp[1]} : soc_rresp);
endmodule
