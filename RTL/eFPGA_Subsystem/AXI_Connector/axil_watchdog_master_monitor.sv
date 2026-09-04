`timescale 1ns / 1ps

module axil_watchdog_master_monitor #(
    parameter bit ENABLE_TIMEOUT              = 1'b1, 
    parameter bit ENABLE_PROTOCOL_CHECK       = 1'b1,
    parameter bit ENABLE_STRICT_PAYLOAD_CHECK = 1'b1,
    parameter int WATCHDOG_LIMIT              = 512
)(
    input  wire clk_i, 
    input  wire rstn_i,
    
    input  wire awvalid, input  wire awready, input wire [31:0] awaddr, input wire [2:0] awprot,
    input  wire wvalid,  input  wire wready,  input wire [31:0] wdata,  input wire [3:0] wstrb,
    input  wire bvalid,  input  wire bready,
    input  wire arvalid, input  wire arready, input wire [31:0] araddr, input wire [2:0] arprot,
    input  wire rvalid,  input  wire rready,
    
    output wire timeout_w_fault_o,
    output wire timeout_r_fault_o,
    output wire protocol_w_fault_o,
    output wire protocol_r_fault_o
);
    localparam TIMER_W = $clog2(WATCHDOG_LIMIT + 1);

    // ===================================================================
    // 1. TIMEOUT LOGIC
    // ===================================================================
    wire w_stall = (bvalid & ~bready);
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
    wire [34:0] aw_payload = {awaddr, awprot};
    wire [35:0] w_payload  = {wdata, wstrb};
    wire [34:0] ar_payload = {araddr, arprot};

    reg awvalid_q, wvalid_q, arvalid_q, awready_q, wready_q, arready_q;
    reg [34:0] aw_payload_q, ar_payload_q;
    reg [35:0] w_payload_q;

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

    // Strict: Payload changed while VALID=1, READY=0
    wire aw_unstable = awvalid_q & ~awready_q & awvalid & (aw_payload != aw_payload_q);
    wire w_unstable  = wvalid_q  & ~wready_q  & wvalid  & (w_payload  != w_payload_q);
    wire ar_unstable = arvalid_q & ~arready_q & arvalid & (ar_payload != ar_payload_q);

    assign protocol_w_fault_o = ENABLE_PROTOCOL_CHECK & (aw_dropped | w_dropped | (ENABLE_STRICT_PAYLOAD_CHECK & (aw_unstable | w_unstable)));
    assign protocol_r_fault_o = ENABLE_PROTOCOL_CHECK & (ar_dropped | (ENABLE_STRICT_PAYLOAD_CHECK & ar_unstable));

endmodule