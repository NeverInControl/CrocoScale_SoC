module npu_axi_read_master (
	clk_i,
	rst_n,
	req_valid_i,
	req_addr_i,
	req_len_i,
	req_ready_o,
	rdata_o,
	rvalid_o,
	rlast_o,
	rready_i,
	m_axi_araddr,
	m_axi_arlen,
	m_axi_arsize,
	m_axi_arburst,
	m_axi_arvalid,
	m_axi_arready,
	m_axi_rdata,
	m_axi_rresp,
	m_axi_rlast,
	m_axi_rvalid,
	m_axi_rready
);
	parameter signed [31:0] AXI_ADDR_WIDTH = 32;
	parameter signed [31:0] AXI_DATA_WIDTH = 32;
	input wire clk_i;
	input wire rst_n;
	input wire req_valid_i;
	input wire [AXI_ADDR_WIDTH - 1:0] req_addr_i;
	input wire [7:0] req_len_i;
	output reg req_ready_o;
	output wire [AXI_DATA_WIDTH - 1:0] rdata_o;
	output wire rvalid_o;
	output wire rlast_o;
	input wire rready_i;
	output reg [AXI_ADDR_WIDTH - 1:0] m_axi_araddr;
	output reg [7:0] m_axi_arlen;
	output wire [2:0] m_axi_arsize;
	output wire [1:0] m_axi_arburst;
	output reg m_axi_arvalid;
	input wire m_axi_arready;
	input wire [AXI_DATA_WIDTH - 1:0] m_axi_rdata;
	input wire [1:0] m_axi_rresp;
	input wire m_axi_rlast;
	input wire m_axi_rvalid;
	output wire m_axi_rready;
	reg [1:0] state;
	assign m_axi_arsize = 3'b010;
	assign m_axi_arburst = 2'b01;
	assign rdata_o = m_axi_rdata;
	assign rvalid_o = (state == 2'd2 ? m_axi_rvalid : 1'b0);
	assign rlast_o = (state == 2'd2 ? m_axi_rlast : 1'b0);
	assign m_axi_rready = (state == 2'd2 ? rready_i : 1'b0);
	always @(posedge clk_i or negedge rst_n)
		if (!rst_n) begin
			state <= 2'd0;
			m_axi_araddr <= 1'sb0;
			m_axi_arlen <= 1'sb0;
			m_axi_arvalid <= 1'b0;
			req_ready_o <= 1'b1;
		end
		else
			case (state)
				2'd0: begin
					req_ready_o <= 1'b1;
					if (req_valid_i) begin
						m_axi_araddr <= req_addr_i;
						m_axi_arlen <= req_len_i;
						m_axi_arvalid <= 1'b1;
						req_ready_o <= 1'b0;
						state <= 2'd1;
					end
				end
				2'd1:
					if (m_axi_arready) begin
						m_axi_arvalid <= 1'b0;
						state <= 2'd2;
					end
				2'd2:
					if ((m_axi_rvalid && rready_i) && m_axi_rlast) begin
						req_ready_o <= 1'b1;
						state <= 2'd0;
					end
				default: state <= 2'd0;
			endcase
endmodule
