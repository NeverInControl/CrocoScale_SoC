module axi_watchdog_slave_monitor (
	clk_i,
	rstn_i,
	awvalid,
	awready,
	wvalid,
	wready,
	wlast,
	bvalid,
	bready,
	bid,
	bresp,
	arvalid,
	arready,
	rvalid,
	rready,
	rlast,
	rid,
	rdata,
	rresp,
	timeout_w_fault_o,
	timeout_r_fault_o,
	protocol_w_fault_o,
	protocol_r_fault_o
);
	parameter [0:0] ENABLE_TIMEOUT = 1'b1;
	parameter [0:0] ENABLE_PROTOCOL_CHECK = 1'b1;
	parameter [0:0] ENABLE_STRICT_PAYLOAD_CHECK = 1'b1;
	parameter signed [31:0] WATCHDOG_LIMIT = 512;
	parameter signed [31:0] AXI_ID_WIDTH = 8;
	input wire clk_i;
	input wire rstn_i;
	input wire awvalid;
	input wire awready;
	input wire wvalid;
	input wire wready;
	input wire wlast;
	input wire bvalid;
	input wire bready;
	input wire [AXI_ID_WIDTH - 1:0] bid;
	input wire [1:0] bresp;
	input wire arvalid;
	input wire arready;
	input wire rvalid;
	input wire rready;
	input wire rlast;
	input wire [AXI_ID_WIDTH - 1:0] rid;
	input wire [31:0] rdata;
	input wire [1:0] rresp;
	output wire timeout_w_fault_o;
	output wire timeout_r_fault_o;
	output wire protocol_w_fault_o;
	output wire protocol_r_fault_o;
	localparam TIMER_W = $clog2(WATCHDOG_LIMIT + 1);
	function automatic signed [((TIMER_W + 0) >= 0 ? TIMER_W + 1 : 1 - (TIMER_W + 0)) - 1:0] sv2v_cast_B8BED_signed;
		input reg signed [((TIMER_W + 0) >= 0 ? TIMER_W + 1 : 1 - (TIMER_W + 0)) - 1:0] inp;
		sv2v_cast_B8BED_signed = inp;
	endfunction
	localparam [TIMER_W:0] LIMIT_VAL = sv2v_cast_B8BED_signed(WATCHDOG_LIMIT);
	localparam [TIMER_W:0] TIMER_ONE = sv2v_cast_B8BED_signed(1);
	reg [7:0] b_owed;
	reg [7:0] r_owed;
	always @(posedge clk_i or negedge rstn_i)
		if (!rstn_i) begin
			b_owed <= 1'sb0;
			r_owed <= 1'sb0;
		end
		else begin
			case ({awvalid & awready, bvalid & bready})
				2'b10: b_owed <= b_owed + 8'd1;
				2'b01:
					if (b_owed > 8'd0)
						b_owed <= b_owed - 8'd1;
				default:
					;
			endcase
			case ({arvalid & arready, (rvalid & rready) & rlast})
				2'b10: r_owed <= r_owed + 8'd1;
				2'b01:
					if (r_owed > 8'd0)
						r_owed <= r_owed - 8'd1;
				default:
					;
			endcase
		end
	wire w_stall = ((awvalid & ~awready) | (wvalid & ~wready)) | ((b_owed > 8'd0) & ~bvalid);
	wire r_stall = (arvalid & ~arready) | ((r_owed > 8'd0) & ~rvalid);
	reg [TIMER_W:0] w_timer;
	reg [TIMER_W:0] r_timer;
	always @(posedge clk_i or negedge rstn_i)
		if (!rstn_i) begin
			w_timer <= 1'sb0;
			r_timer <= 1'sb0;
		end
		else begin
			w_timer <= (w_stall && ENABLE_TIMEOUT ? (w_timer >= LIMIT_VAL ? w_timer : w_timer + TIMER_ONE) : {(TIMER_W >= 0 ? TIMER_W + 1 : 1 - TIMER_W) {1'sb0}});
			r_timer <= (r_stall && ENABLE_TIMEOUT ? (r_timer >= LIMIT_VAL ? r_timer : r_timer + TIMER_ONE) : {(TIMER_W >= 0 ? TIMER_W + 1 : 1 - TIMER_W) {1'sb0}});
		end
	assign timeout_w_fault_o = w_timer >= LIMIT_VAL;
	assign timeout_r_fault_o = r_timer >= LIMIT_VAL;
	localparam B_W = AXI_ID_WIDTH + 2;
	localparam R_W = AXI_ID_WIDTH + 35;
	wire [B_W - 1:0] b_payload = {bid, bresp};
	wire [R_W - 1:0] r_payload = {rid, rdata, rresp, rlast};
	reg bvalid_q;
	reg rvalid_q;
	reg bready_q;
	reg rready_q;
	reg [B_W - 1:0] b_payload_q;
	reg [R_W - 1:0] r_payload_q;
	always @(posedge clk_i or negedge rstn_i)
		if (!rstn_i) begin
			bvalid_q <= 0;
			rvalid_q <= 0;
			bready_q <= 0;
			rready_q <= 0;
			b_payload_q <= 0;
			r_payload_q <= 0;
		end
		else begin
			bvalid_q <= bvalid;
			rvalid_q <= rvalid;
			bready_q <= bready;
			rready_q <= rready;
			b_payload_q <= b_payload;
			r_payload_q <= r_payload;
		end
	wire b_dropped = (bvalid_q & ~bready_q) & ~bvalid;
	wire r_dropped = (rvalid_q & ~rready_q) & ~rvalid;
	wire b_unstable = ((bvalid_q & ~bready_q) & bvalid) & (b_payload != b_payload_q);
	wire r_unstable = ((rvalid_q & ~rready_q) & rvalid) & (r_payload != r_payload_q);
	assign protocol_w_fault_o = ENABLE_PROTOCOL_CHECK & (b_dropped | (ENABLE_STRICT_PAYLOAD_CHECK & b_unstable));
	assign protocol_r_fault_o = ENABLE_PROTOCOL_CHECK & (r_dropped | (ENABLE_STRICT_PAYLOAD_CHECK & r_unstable));
endmodule
