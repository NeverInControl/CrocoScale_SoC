module watchdog_timer (
	clk_i,
	rstn_i,
	ctrl_awvalid_i,
	ctrl_awready_i,
	ctrl_wvalid_i,
	ctrl_wready_i,
	ctrl_bvalid_i,
	ctrl_bready_i,
	ctrl_arvalid_i,
	ctrl_arready_i,
	ctrl_rvalid_i,
	ctrl_rready_i,
	dma_awvalid_i,
	dma_awready_i,
	dma_wvalid_i,
	dma_wready_i,
	dma_wlast_i,
	dma_bvalid_i,
	dma_bready_i,
	dma_arvalid_i,
	dma_arready_i,
	dma_rvalid_i,
	dma_rready_i,
	dma_rlast_i,
	timeout_o
);
	parameter integer WATCHDOG_LIMIT = 512;
	input wire clk_i;
	input wire rstn_i;
	input wire ctrl_awvalid_i;
	input wire ctrl_awready_i;
	input wire ctrl_wvalid_i;
	input wire ctrl_wready_i;
	input wire ctrl_bvalid_i;
	input wire ctrl_bready_i;
	input wire ctrl_arvalid_i;
	input wire ctrl_arready_i;
	input wire ctrl_rvalid_i;
	input wire ctrl_rready_i;
	input wire dma_awvalid_i;
	input wire dma_awready_i;
	input wire dma_wvalid_i;
	input wire dma_wready_i;
	input wire dma_wlast_i;
	input wire dma_bvalid_i;
	input wire dma_bready_i;
	input wire dma_arvalid_i;
	input wire dma_arready_i;
	input wire dma_rvalid_i;
	input wire dma_rready_i;
	input wire dma_rlast_i;
	output wire timeout_o;
	localparam TIMER_W = $clog2(WATCHDOG_LIMIT + 1);
	reg [7:0] ctrl_b_owed;
	always @(posedge clk_i or negedge rstn_i)
		if (!rstn_i)
			ctrl_b_owed <= 0;
		else
			case ({((ctrl_awvalid_i & ctrl_awready_i) & ctrl_wvalid_i) & ctrl_wready_i, ctrl_bvalid_i & ctrl_bready_i})
				2'b10: ctrl_b_owed <= ctrl_b_owed + 1;
				2'b01:
					if (ctrl_b_owed > 0)
						ctrl_b_owed <= ctrl_b_owed - 1;
				default:
					;
			endcase
	wire ctrl_w_fabric_stall = ((ctrl_awvalid_i & ~ctrl_awready_i) | (ctrl_wvalid_i & ~ctrl_wready_i)) | ((ctrl_b_owed > 0) & ~ctrl_bvalid_i);
	reg [TIMER_W:0] ctrl_w_timer;
	always @(posedge clk_i or negedge rstn_i)
		if (!rstn_i)
			ctrl_w_timer <= 0;
		else if (ctrl_w_fabric_stall) begin
			if (ctrl_w_timer <= WATCHDOG_LIMIT)
				ctrl_w_timer <= ctrl_w_timer + 1;
		end
		else
			ctrl_w_timer <= 0;
	reg [7:0] ctrl_r_owed;
	always @(posedge clk_i or negedge rstn_i)
		if (!rstn_i)
			ctrl_r_owed <= 0;
		else
			case ({ctrl_arvalid_i & ctrl_arready_i, ctrl_rvalid_i & ctrl_rready_i})
				2'b10: ctrl_r_owed <= ctrl_r_owed + 1;
				2'b01:
					if (ctrl_r_owed > 0)
						ctrl_r_owed <= ctrl_r_owed - 1;
				default:
					;
			endcase
	wire ctrl_r_fabric_stall = (ctrl_arvalid_i & ~ctrl_arready_i) | ((ctrl_r_owed > 0) & ~ctrl_rvalid_i);
	reg [TIMER_W:0] ctrl_r_timer;
	always @(posedge clk_i or negedge rstn_i)
		if (!rstn_i)
			ctrl_r_timer <= 0;
		else if (ctrl_r_fabric_stall) begin
			if (ctrl_r_timer <= WATCHDOG_LIMIT)
				ctrl_r_timer <= ctrl_r_timer + 1;
		end
		else
			ctrl_r_timer <= 0;
	reg dma_w_in_flight;
	always @(posedge clk_i or negedge rstn_i)
		if (!rstn_i)
			dma_w_in_flight <= 0;
		else if (dma_wvalid_i && dma_wready_i) begin
			if (dma_wlast_i)
				dma_w_in_flight <= 0;
			else
				dma_w_in_flight <= 1;
		end
	wire dma_w_fabric_stall = (dma_w_in_flight & ~dma_wvalid_i) | (dma_bvalid_i & ~dma_bready_i);
	reg [TIMER_W:0] dma_w_timer;
	always @(posedge clk_i or negedge rstn_i)
		if (!rstn_i)
			dma_w_timer <= 0;
		else if (dma_w_fabric_stall) begin
			if (dma_w_timer <= WATCHDOG_LIMIT)
				dma_w_timer <= dma_w_timer + 1;
		end
		else
			dma_w_timer <= 0;
	wire dma_r_fabric_stall = dma_rvalid_i & ~dma_rready_i;
	reg [TIMER_W:0] dma_r_timer;
	always @(posedge clk_i or negedge rstn_i)
		if (!rstn_i)
			dma_r_timer <= 0;
		else if (dma_r_fabric_stall) begin
			if (dma_r_timer <= WATCHDOG_LIMIT)
				dma_r_timer <= dma_r_timer + 1;
		end
		else
			dma_r_timer <= 0;
	assign timeout_o = (((ctrl_w_timer >= WATCHDOG_LIMIT) | (ctrl_r_timer >= WATCHDOG_LIMIT)) | (dma_w_timer >= WATCHDOG_LIMIT)) | (dma_r_timer >= WATCHDOG_LIMIT);
endmodule
