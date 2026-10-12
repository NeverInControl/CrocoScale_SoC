module axil_watchdog_slave_monitor (
	clk_i,
	rstn_i,
	awvalid,
	awready,
	wvalid,
	wready,
	bvalid,
	bready,
	bresp,
	arvalid,
	arready,
	rvalid,
	rready,
	rdata,
	rresp,
	fault_timeout_w_o,
	fault_timeout_r_o,
	fault_dropped_valid_w_o,
	fault_dropped_valid_r_o,
	fault_unstable_w_o,
	fault_unstable_r_o
);
	parameter [0:0] ENABLE_TIMEOUT = 1'b1;
	parameter [0:0] ENABLE_DROPPED_VALID = 1'b1;
	parameter [0:0] ENABLE_PAYLOAD_STABILITY = 1'b0;
	parameter signed [31:0] WATCHDOG_LIMIT = 512;
	input wire clk_i;
	input wire rstn_i;
	input wire awvalid;
	input wire awready;
	input wire wvalid;
	input wire wready;
	input wire bvalid;
	input wire bready;
	input wire [1:0] bresp;
	input wire arvalid;
	input wire arready;
	input wire rvalid;
	input wire rready;
	input wire [31:0] rdata;
	input wire [1:0] rresp;
	output wire fault_timeout_w_o;
	output wire fault_timeout_r_o;
	output wire fault_dropped_valid_w_o;
	output wire fault_dropped_valid_r_o;
	output wire fault_unstable_w_o;
	output wire fault_unstable_r_o;
	generate
		if (ENABLE_TIMEOUT) begin : gen_timeout
			localparam TIMER_W = $clog2(WATCHDOG_LIMIT + 1);
			function automatic signed [((TIMER_W + 0) >= 0 ? TIMER_W + 1 : 1 - (TIMER_W + 0)) - 1:0] sv2v_cast_B8BED_signed;
				input reg signed [((TIMER_W + 0) >= 0 ? TIMER_W + 1 : 1 - (TIMER_W + 0)) - 1:0] inp;
				sv2v_cast_B8BED_signed = inp;
			endfunction
			localparam [TIMER_W:0] LIMIT_VAL = sv2v_cast_B8BED_signed(WATCHDOG_LIMIT);
			localparam [TIMER_W:0] TIMER_ONE = sv2v_cast_B8BED_signed(1);
			wire aw_fire = awvalid & awready;
			wire w_fire = wvalid & wready;
			wire b_fire = bvalid & bready;
			reg signed [7:0] aw_w_delta;
			wire aw_ahead = aw_w_delta > 8'sd0;
			wire w_ahead = aw_w_delta < 8'sd0;
			wire wr_tx_completed = ((aw_fire & w_fire) | (aw_fire & w_ahead)) | (w_fire & aw_ahead);
			reg [7:0] b_owed;
			reg [7:0] r_owed;
			always @(posedge clk_i or negedge rstn_i)
				if (!rstn_i) begin
					aw_w_delta <= 8'sd0;
					b_owed <= 8'd0;
					r_owed <= 8'd0;
				end
				else begin
					aw_w_delta <= (aw_w_delta + (aw_fire ? 8'sd1 : 8'sd0)) - (w_fire ? 8'sd1 : 8'sd0);
					case ({wr_tx_completed, b_fire})
						2'b10: b_owed <= b_owed + 8'd1;
						2'b01:
							if (b_owed > 8'd0)
								b_owed <= b_owed - 8'd1;
						default:
							;
					endcase
					case ({arvalid & arready, rvalid & rready})
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
					w_timer <= (w_stall ? (w_timer >= LIMIT_VAL ? w_timer : w_timer + TIMER_ONE) : {(TIMER_W >= 0 ? TIMER_W + 1 : 1 - TIMER_W) {1'sb0}});
					r_timer <= (r_stall ? (r_timer >= LIMIT_VAL ? r_timer : r_timer + TIMER_ONE) : {(TIMER_W >= 0 ? TIMER_W + 1 : 1 - TIMER_W) {1'sb0}});
				end
			assign fault_timeout_w_o = w_timer >= LIMIT_VAL;
			assign fault_timeout_r_o = r_timer >= LIMIT_VAL;
		end
		else begin : gen_no_timeout
			assign fault_timeout_w_o = 1'b0;
			assign fault_timeout_r_o = 1'b0;
		end
		if (ENABLE_DROPPED_VALID || ENABLE_PAYLOAD_STABILITY) begin : gen_handshake_track
			reg bvalid_q;
			reg rvalid_q;
			reg bready_q;
			reg rready_q;
			always @(posedge clk_i or negedge rstn_i)
				if (!rstn_i) begin
					bvalid_q <= 1'b0;
					rvalid_q <= 1'b0;
					bready_q <= 1'b0;
					rready_q <= 1'b0;
				end
				else begin
					bvalid_q <= bvalid;
					rvalid_q <= rvalid;
					bready_q <= bready;
					rready_q <= rready;
				end
			if (ENABLE_DROPPED_VALID) begin : gen_dropped_valid
				assign fault_dropped_valid_w_o = (bvalid_q & ~bready_q) & ~bvalid;
				assign fault_dropped_valid_r_o = (rvalid_q & ~rready_q) & ~rvalid;
			end
			else begin : gen_no_dropped_valid
				assign fault_dropped_valid_w_o = 1'b0;
				assign fault_dropped_valid_r_o = 1'b0;
			end
			if (ENABLE_PAYLOAD_STABILITY) begin : gen_payload_stability
				reg [1:0] bresp_q;
				reg [33:0] r_payload_q;
				wire [33:0] r_payload = {rdata, rresp};
				always @(posedge clk_i or negedge rstn_i)
					if (!rstn_i) begin
						bresp_q <= 1'sb0;
						r_payload_q <= 1'sb0;
					end
					else begin
						bresp_q <= bresp;
						r_payload_q <= r_payload;
					end
				assign fault_unstable_w_o = ((bvalid_q & ~bready_q) & bvalid) & (bresp != bresp_q);
				assign fault_unstable_r_o = ((rvalid_q & ~rready_q) & rvalid) & (r_payload != r_payload_q);
			end
			else begin : gen_no_payload_stability
				assign fault_unstable_w_o = 1'b0;
				assign fault_unstable_r_o = 1'b0;
			end
		end
		else begin : gen_no_handshake_track
			assign fault_dropped_valid_w_o = 1'b0;
			assign fault_dropped_valid_r_o = 1'b0;
			assign fault_unstable_w_o = 1'b0;
			assign fault_unstable_r_o = 1'b0;
		end
	endgenerate
endmodule
