`timescale 1ns / 1ps

module axi_watchdog_master_monitor #(
    parameter bit ENABLE_TIMEOUT              = 1'b1,
    parameter bit ENABLE_PROTOCOL_CHECK       = 1'b1,
    parameter bit ENABLE_STRICT_PAYLOAD_CHECK = 1'b1,
    parameter int WATCHDOG_LIMIT              = 512,
    parameter int AXI_ID_WIDTH                = 8
)(
    input  wire clk_i, 
    input  wire rstn_i,
    
    // AXI4-Full Master Interface signals
    input  wire awvalid, input  wire awready, 
    input  wire [AXI_ID_WIDTH-1:0] awid, input wire [31:0] awaddr, input wire [7:0] awlen, input wire [2:0] awsize, input wire [1:0] awburst, input wire awlock, input wire [3:0] awcache, input wire [2:0] awprot,
    
    input  wire wvalid,  input  wire wready,  input wire wlast,
    input  wire [31:0] wdata, input wire [3:0] wstrb,
    
    input  wire bvalid,  input  wire bready,
    
    input  wire arvalid, input  wire arready,
    input  wire [AXI_ID_WIDTH-1:0] arid, input wire [31:0] araddr, input wire [7:0] arlen, input wire [2:0] arsize, input wire [1:0] arburst, input wire arlock, input wire [3:0] arcache, input wire [2:0] arprot,
    
    input  wire rvalid,  input  wire rready,  input wire rlast,
    
    output wire timeout_w_fault_o,
    output wire timeout_r_fault_o,
    output wire protocol_w_fault_o,
    output wire protocol_r_fault_o
);
    localparam TIMER_W = $clog2(WATCHDOG_LIMIT + 1);

    // ===================================================================
    // 1. TIMEOUT LOGIC
    // ===================================================================
    reg w_in_flight;
    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) w_in_flight <= 0;
        else if (wvalid & wready) w_in_flight <= ~wlast;
    end

    wire w_stall = (w_in_flight & ~wvalid) | (bvalid & ~bready);
    wire r_stall = (rvalid & ~rready);
    
    reg [TIMER_W:0] w_timer, r_timer;
    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin w_timer <= 0; r_timer <= 0; end
        else begin
            w_timer <= (w_stall && ENABLE_TIMEOUT) ? (w_timer > WATCHDOG_LIMIT ? w_timer : w_timer + 1) : 0;
            r_timer <= (r_stall && ENABLE_TIMEOUT) ? (r_timer > WATCHDOG_LIMIT ? r_timer : r_timer + 1) : 0;
        end
    end
    assign timeout_w_fault_o = (w_timer >= WATCHDOG_LIMIT);
    assign timeout_r_fault_o = (r_timer >= WATCHDOG_LIMIT);

    // ===================================================================
    // 2. PROTOCOL & STABILITY LOGIC
    // ===================================================================
    localparam AW_W = AXI_ID_WIDTH + 32 + 8 + 3 + 2 + 1 + 4 + 3;
    localparam W_W  = 32 + 4 + 1;
    localparam AR_W = AXI_ID_WIDTH + 32 + 8 + 3 + 2 + 1 + 4 + 3;

    wire [AW_W-1:0] aw_payload = {awid, awaddr, awlen, awsize, awburst, awlock, awcache, awprot};
    wire [W_W-1:0]  w_payload  = {wdata, wstrb, wlast};
    wire [AR_W-1:0] ar_payload = {arid, araddr, arlen, arsize, arburst, arlock, arcache, arprot};

    reg awvalid_q, wvalid_q, arvalid_q, awready_q, wready_q, arready_q;
    reg [AW_W-1:0] aw_payload_q;
    reg [W_W-1:0]  w_payload_q;
    reg [AR_W-1:0] ar_payload_q;

    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin
            awvalid_q<=0; wvalid_q<=0; arvalid_q<=0; awready_q<=0; wready_q<=0; arready_q<=0;
            aw_payload_q<=0; w_payload_q<=0; ar_payload_q<=0;
        end else begin
            awvalid_q<=awvalid; wvalid_q<=wvalid; arvalid_q<=arvalid; awready_q<=awready; wready_q<=wready; arready_q<=arready;
            aw_payload_q<=aw_payload; w_payload_q<=w_payload; ar_payload_q<=ar_payload;
        end
    end

    // Basic: Dropped VALID
    wire aw_dropped = awvalid_q & ~awready_q & ~awvalid;
    wire w_dropped  = wvalid_q  & ~wready_q  & ~wvalid;
    wire ar_dropped = arvalid_q & ~arready_q & ~arvalid;

    // Strict: Payload Stability
    wire aw_unstable = awvalid_q & ~awready_q & awvalid & (aw_payload != aw_payload_q);
    wire w_unstable  = wvalid_q  & ~wready_q  & wvalid  & (w_payload  != w_payload_q);
    wire ar_unstable = arvalid_q & ~arready_q & arvalid & (ar_payload != ar_payload_q);

    // ===================================================================
    // 3. EXPENSIVE WLAST TIMING CHECK
    // ===================================================================
    wire wlast_timing_fault;
    
    generate if (ENABLE_STRICT_PAYLOAD_CHECK) begin : gen_wlast_check
        reg [7:0] awlen_fifo [0:15]; // Depth 16 (supports 16 outstanding bursts)
        reg [3:0] awlen_wr_ptr, awlen_rd_ptr;
        reg [4:0] awlen_count;

        always_ff @(posedge clk_i or negedge rstn_i) begin
            if (!rstn_i) begin
                awlen_wr_ptr <= 0; awlen_rd_ptr <= 0; awlen_count <= 0;
            end else begin
                if ((awvalid & awready) && !(wvalid & wready & wlast)) begin
                    awlen_fifo[awlen_wr_ptr] <= awlen;
                    awlen_wr_ptr <= awlen_wr_ptr + 1;
                    awlen_count <= awlen_count + 1;
                end else if (!(awvalid & awready) && (wvalid & wready & wlast)) begin
                    awlen_rd_ptr <= awlen_rd_ptr + 1;
                    awlen_count <= awlen_count - 1;
                end else if ((awvalid & awready) && (wvalid & wready & wlast)) begin
                    awlen_fifo[awlen_wr_ptr] <= awlen;
                    awlen_wr_ptr <= awlen_wr_ptr + 1;
                    awlen_rd_ptr <= awlen_rd_ptr + 1;
                end
            end
        end

        reg [7:0] current_w_beat;
        always_ff @(posedge clk_i or negedge rstn_i) begin
            if (!rstn_i) current_w_beat <= 0;
            else if (wvalid & wready) begin
                if (wlast) current_w_beat <= 0;
                else current_w_beat <= current_w_beat + 1;
            end
        end

        // Fault if WLAST is 1 but beat != expected, or WLAST is 0 but beat == expected.
        assign wlast_timing_fault = (wvalid & wready) & (awlen_count > 0) & 
                                    ((current_w_beat == awlen_fifo[awlen_rd_ptr]) != wlast);
    end else begin : gen_no_wlast_check
        assign wlast_timing_fault = 1'b0;
    end endgenerate

    // Combine Faults
    assign protocol_w_fault_o = ENABLE_PROTOCOL_CHECK & (
        aw_dropped | w_dropped | 
        (ENABLE_STRICT_PAYLOAD_CHECK & (aw_unstable | w_unstable | wlast_timing_fault))
    );
    assign protocol_r_fault_o = ENABLE_PROTOCOL_CHECK & (
        ar_dropped | 
        (ENABLE_STRICT_PAYLOAD_CHECK & ar_unstable)
    );

endmodule