module axil_decoupler_bidir (
	clk_i,
	rstn_i,
	decouple_req_i,
	force_decouple_i,
	is_decoupled_o,
	host_active_o,
	dma_active_o,
	h2f_s_axil_awaddr,
	h2f_s_axil_awprot,
	h2f_s_axil_awvalid,
	h2f_s_axil_awready,
	h2f_s_axil_wdata,
	h2f_s_axil_wstrb,
	h2f_s_axil_wvalid,
	h2f_s_axil_wready,
	h2f_s_axil_bresp,
	h2f_s_axil_bvalid,
	h2f_s_axil_bready,
	h2f_s_axil_araddr,
	h2f_s_axil_arprot,
	h2f_s_axil_arvalid,
	h2f_s_axil_arready,
	h2f_s_axil_rdata,
	h2f_s_axil_rresp,
	h2f_s_axil_rvalid,
	h2f_s_axil_rready,
	h2f_m_axil_awaddr,
	h2f_m_axil_awprot,
	h2f_m_axil_awvalid,
	h2f_m_axil_awready,
	h2f_m_axil_wdata,
	h2f_m_axil_wstrb,
	h2f_m_axil_wvalid,
	h2f_m_axil_wready,
	h2f_m_axil_bresp,
	h2f_m_axil_bvalid,
	h2f_m_axil_bready,
	h2f_m_axil_araddr,
	h2f_m_axil_arprot,
	h2f_m_axil_arvalid,
	h2f_m_axil_arready,
	h2f_m_axil_rdata,
	h2f_m_axil_rresp,
	h2f_m_axil_rvalid,
	h2f_m_axil_rready,
	f2h_s_axil_awaddr,
	f2h_s_axil_awprot,
	f2h_s_axil_awvalid,
	f2h_s_axil_awready,
	f2h_s_axil_wdata,
	f2h_s_axil_wstrb,
	f2h_s_axil_wvalid,
	f2h_s_axil_wready,
	f2h_s_axil_bresp,
	f2h_s_axil_bvalid,
	f2h_s_axil_bready,
	f2h_s_axil_araddr,
	f2h_s_axil_arprot,
	f2h_s_axil_arvalid,
	f2h_s_axil_arready,
	f2h_s_axil_rdata,
	f2h_s_axil_rresp,
	f2h_s_axil_rvalid,
	f2h_s_axil_rready,
	f2h_m_axil_awaddr,
	f2h_m_axil_awprot,
	f2h_m_axil_awvalid,
	f2h_m_axil_awready,
	f2h_m_axil_wdata,
	f2h_m_axil_wstrb,
	f2h_m_axil_wvalid,
	f2h_m_axil_wready,
	f2h_m_axil_bresp,
	f2h_m_axil_bvalid,
	f2h_m_axil_bready,
	f2h_m_axil_araddr,
	f2h_m_axil_arprot,
	f2h_m_axil_arvalid,
	f2h_m_axil_arready,
	f2h_m_axil_rdata,
	f2h_m_axil_rresp,
	f2h_m_axil_rvalid,
	f2h_m_axil_rready
);
	input wire clk_i;
	input wire rstn_i;
	input wire decouple_req_i;
	input wire force_decouple_i;
	output wire is_decoupled_o;
	output wire host_active_o;
	output wire dma_active_o;
	input wire [31:0] h2f_s_axil_awaddr;
	input wire [2:0] h2f_s_axil_awprot;
	input wire h2f_s_axil_awvalid;
	output wire h2f_s_axil_awready;
	input wire [31:0] h2f_s_axil_wdata;
	input wire [3:0] h2f_s_axil_wstrb;
	input wire h2f_s_axil_wvalid;
	output wire h2f_s_axil_wready;
	output wire [1:0] h2f_s_axil_bresp;
	output wire h2f_s_axil_bvalid;
	input wire h2f_s_axil_bready;
	input wire [31:0] h2f_s_axil_araddr;
	input wire [2:0] h2f_s_axil_arprot;
	input wire h2f_s_axil_arvalid;
	output wire h2f_s_axil_arready;
	output wire [31:0] h2f_s_axil_rdata;
	output wire [1:0] h2f_s_axil_rresp;
	output wire h2f_s_axil_rvalid;
	input wire h2f_s_axil_rready;
	output wire [31:0] h2f_m_axil_awaddr;
	output wire [2:0] h2f_m_axil_awprot;
	output wire h2f_m_axil_awvalid;
	input wire h2f_m_axil_awready;
	output wire [31:0] h2f_m_axil_wdata;
	output wire [3:0] h2f_m_axil_wstrb;
	output wire h2f_m_axil_wvalid;
	input wire h2f_m_axil_wready;
	input wire [1:0] h2f_m_axil_bresp;
	input wire h2f_m_axil_bvalid;
	output wire h2f_m_axil_bready;
	output wire [31:0] h2f_m_axil_araddr;
	output wire [2:0] h2f_m_axil_arprot;
	output wire h2f_m_axil_arvalid;
	input wire h2f_m_axil_arready;
	input wire [31:0] h2f_m_axil_rdata;
	input wire [1:0] h2f_m_axil_rresp;
	input wire h2f_m_axil_rvalid;
	output wire h2f_m_axil_rready;
	input wire [31:0] f2h_s_axil_awaddr;
	input wire [2:0] f2h_s_axil_awprot;
	input wire f2h_s_axil_awvalid;
	output wire f2h_s_axil_awready;
	input wire [31:0] f2h_s_axil_wdata;
	input wire [3:0] f2h_s_axil_wstrb;
	input wire f2h_s_axil_wvalid;
	output wire f2h_s_axil_wready;
	output wire [1:0] f2h_s_axil_bresp;
	output wire f2h_s_axil_bvalid;
	input wire f2h_s_axil_bready;
	input wire [31:0] f2h_s_axil_araddr;
	input wire [2:0] f2h_s_axil_arprot;
	input wire f2h_s_axil_arvalid;
	output wire f2h_s_axil_arready;
	output wire [31:0] f2h_s_axil_rdata;
	output wire [1:0] f2h_s_axil_rresp;
	output wire f2h_s_axil_rvalid;
	input wire f2h_s_axil_rready;
	output wire [31:0] f2h_m_axil_awaddr;
	output wire [2:0] f2h_m_axil_awprot;
	output wire f2h_m_axil_awvalid;
	input wire f2h_m_axil_awready;
	output wire [31:0] f2h_m_axil_wdata;
	output wire [3:0] f2h_m_axil_wstrb;
	output wire f2h_m_axil_wvalid;
	input wire f2h_m_axil_wready;
	input wire [1:0] f2h_m_axil_bresp;
	input wire f2h_m_axil_bvalid;
	output wire f2h_m_axil_bready;
	output wire [31:0] f2h_m_axil_araddr;
	output wire [2:0] f2h_m_axil_arprot;
	output wire f2h_m_axil_arvalid;
	input wire f2h_m_axil_arready;
	input wire [31:0] f2h_m_axil_rdata;
	input wire [1:0] f2h_m_axil_rresp;
	input wire f2h_m_axil_rvalid;
	output wire f2h_m_axil_rready;
	reg decoupled_reg;
	assign is_decoupled_o = decoupled_reg;
	reg h2f_b_pending;
	reg h2f_r_pending;
	reg f2h_b_pending;
	reg f2h_r_pending;
	always @(posedge clk_i or negedge rstn_i)
		if (!rstn_i) begin
			h2f_b_pending <= 1'b0;
			h2f_r_pending <= 1'b0;
			f2h_b_pending <= 1'b0;
			f2h_r_pending <= 1'b0;
		end
		else begin
			case ({h2f_s_axil_awvalid & h2f_s_axil_awready, h2f_s_axil_bvalid & h2f_s_axil_bready})
				2'b10: h2f_b_pending <= 1'b1;
				2'b01: h2f_b_pending <= 1'b0;
				2'b11: h2f_b_pending <= 1'b1;
				default:
					;
			endcase
			case ({h2f_s_axil_arvalid & h2f_s_axil_arready, h2f_s_axil_rvalid & h2f_s_axil_rready})
				2'b10: h2f_r_pending <= 1'b1;
				2'b01: h2f_r_pending <= 1'b0;
				2'b11: h2f_r_pending <= 1'b1;
				default:
					;
			endcase
			case ({f2h_s_axil_awvalid & f2h_s_axil_awready, f2h_s_axil_bvalid & f2h_s_axil_bready})
				2'b10: f2h_b_pending <= 1'b1;
				2'b01: f2h_b_pending <= 1'b0;
				2'b11: f2h_b_pending <= 1'b1;
				default:
					;
			endcase
			case ({f2h_s_axil_arvalid & f2h_s_axil_arready, f2h_s_axil_rvalid & f2h_s_axil_rready})
				2'b10: f2h_r_pending <= 1'b1;
				2'b01: f2h_r_pending <= 1'b0;
				2'b11: f2h_r_pending <= 1'b1;
				default:
					;
			endcase
		end
	assign host_active_o = ((h2f_b_pending | h2f_r_pending) | h2f_s_axil_awvalid) | h2f_s_axil_arvalid;
	assign dma_active_o = ((f2h_b_pending | f2h_r_pending) | f2h_s_axil_awvalid) | f2h_s_axil_arvalid;
	wire is_safe = ~host_active_o & ~dma_active_o;
	always @(posedge clk_i or negedge rstn_i)
		if (!rstn_i)
			decoupled_reg <= 1'b0;
		else if (force_decouple_i)
			decoupled_reg <= 1'b1;
		else if (decouple_req_i) begin
			if (is_safe)
				decoupled_reg <= 1'b1;
		end
		else
			decoupled_reg <= 1'b0;
	assign h2f_m_axil_awaddr = (decoupled_reg ? 32'b00000000000000000000000000000000 : h2f_s_axil_awaddr);
	assign h2f_m_axil_awprot = (decoupled_reg ? 3'b000 : h2f_s_axil_awprot);
	assign h2f_m_axil_awvalid = (decoupled_reg ? 1'b0 : h2f_s_axil_awvalid);
	assign h2f_m_axil_wdata = (decoupled_reg ? 32'b00000000000000000000000000000000 : h2f_s_axil_wdata);
	assign h2f_m_axil_wstrb = (decoupled_reg ? 4'b0000 : h2f_s_axil_wstrb);
	assign h2f_m_axil_wvalid = (decoupled_reg ? 1'b0 : h2f_s_axil_wvalid);
	assign h2f_m_axil_bready = (decoupled_reg ? 1'b0 : h2f_s_axil_bready);
	assign h2f_m_axil_araddr = (decoupled_reg ? 32'b00000000000000000000000000000000 : h2f_s_axil_araddr);
	assign h2f_m_axil_arprot = (decoupled_reg ? 3'b000 : h2f_s_axil_arprot);
	assign h2f_m_axil_arvalid = (decoupled_reg ? 1'b0 : h2f_s_axil_arvalid);
	assign h2f_m_axil_rready = (decoupled_reg ? 1'b0 : h2f_s_axil_rready);
	assign h2f_s_axil_awready = (decoupled_reg ? ~h2f_b_pending : h2f_m_axil_awready);
	assign h2f_s_axil_wready = (decoupled_reg ? ~h2f_b_pending : h2f_m_axil_wready);
	assign h2f_s_axil_bresp = (decoupled_reg ? 2'b10 : h2f_m_axil_bresp);
	assign h2f_s_axil_bvalid = (decoupled_reg ? h2f_b_pending : h2f_m_axil_bvalid);
	assign h2f_s_axil_arready = (decoupled_reg ? ~h2f_r_pending : h2f_m_axil_arready);
	assign h2f_s_axil_rdata = (decoupled_reg ? 32'hdeadbeef : h2f_m_axil_rdata);
	assign h2f_s_axil_rresp = (decoupled_reg ? 2'b10 : h2f_m_axil_rresp);
	assign h2f_s_axil_rvalid = (decoupled_reg ? h2f_r_pending : h2f_m_axil_rvalid);
	assign f2h_m_axil_awaddr = (decoupled_reg ? 32'b00000000000000000000000000000000 : f2h_s_axil_awaddr);
	assign f2h_m_axil_awprot = (decoupled_reg ? 3'b000 : f2h_s_axil_awprot);
	assign f2h_m_axil_awvalid = (decoupled_reg ? 1'b0 : f2h_s_axil_awvalid);
	assign f2h_m_axil_wdata = (decoupled_reg ? 32'b00000000000000000000000000000000 : f2h_s_axil_wdata);
	assign f2h_m_axil_wstrb = (decoupled_reg ? 4'b0000 : f2h_s_axil_wstrb);
	assign f2h_m_axil_wvalid = (decoupled_reg ? 1'b0 : f2h_s_axil_wvalid);
	assign f2h_m_axil_bready = (decoupled_reg ? 1'b0 : f2h_s_axil_bready);
	assign f2h_m_axil_araddr = (decoupled_reg ? 32'b00000000000000000000000000000000 : f2h_s_axil_araddr);
	assign f2h_m_axil_arprot = (decoupled_reg ? 3'b000 : f2h_s_axil_arprot);
	assign f2h_m_axil_arvalid = (decoupled_reg ? 1'b0 : f2h_s_axil_arvalid);
	assign f2h_m_axil_rready = (decoupled_reg ? 1'b0 : f2h_s_axil_rready);
	assign f2h_s_axil_awready = (decoupled_reg ? 1'b0 : f2h_m_axil_awready);
	assign f2h_s_axil_wready = (decoupled_reg ? 1'b0 : f2h_m_axil_wready);
	assign f2h_s_axil_bresp = (decoupled_reg ? 2'b00 : f2h_m_axil_bresp);
	assign f2h_s_axil_bvalid = (decoupled_reg ? 1'b0 : f2h_m_axil_bvalid);
	assign f2h_s_axil_arready = (decoupled_reg ? 1'b0 : f2h_m_axil_arready);
	assign f2h_s_axil_rdata = (decoupled_reg ? 32'b00000000000000000000000000000000 : f2h_m_axil_rdata);
	assign f2h_s_axil_rresp = (decoupled_reg ? 2'b00 : f2h_m_axil_rresp);
	assign f2h_s_axil_rvalid = (decoupled_reg ? 1'b0 : f2h_m_axil_rvalid);
endmodule
