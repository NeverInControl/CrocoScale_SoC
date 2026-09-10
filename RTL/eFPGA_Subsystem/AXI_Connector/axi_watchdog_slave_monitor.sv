`timescale 1ns / 1ps

module axi_watchdog_slave_monitor #(
    parameter bit ENABLE_TIMEOUT              = 1'b1, 
    parameter bit ENABLE_PROTOCOL_CHECK       = 1'b1,
    parameter bit ENABLE_STRICT_PAYLOAD_CHECK = 1'b1,
    parameter int WATCHDOG_LIMIT              = 512,
    parameter int AXI_ID_WIDTH                = 8
)(
    input  wire clk_i, 
    input  wire rstn_i,
    
    input  wire awvalid, input  wire awready,
    input  wire wvalid,  input  wire wready,  input wire wlast,
    
    input  wire bvalid,  input  wire bready,  
    input  wire [AXI_ID_WIDTH-1:0] bid, input wire [1:0] bresp,
    
    input  wire arvalid, input  wire arready,
    
    input  wire rvalid,  input  wire rready,  input wire rlast,
    input  wire [AXI_ID_WIDTH-1:0] rid, input wire [31:0] rdata, input wire [1:0] rresp,
    
    output wire timeout_w_fault_o,
    output wire timeout_r_fault_o,
    output wire protocol_w_fault_o,
    output wire protocol_r_fault_o
);
    localparam TIMER_W = $clog2(WATCHDOG_LIMIT + 1);

    // ===================================================================
    // 1. TIMEOUT LOGIC
    // ===================================================================
    reg [7:0] b_owed, r_owed;
    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin b_owed <= 0; r_owed <= 0; end
        else begin
            case ({(awvalid & awready), (bvalid & bready)})
                2'b10: b_owed <= b_owed + 1;
                2'b01: if (b_owed > 0) b_owed <= b_owed - 1;
                default: ;
            endcase
            case ({(arvalid & arready), (rvalid & rready & rlast)})
                2'b10: r_owed <= r_owed + 1;
                2'b01: if (r_owed > 0) r_owed <= r_owed - 1;
                default: ;
            endcase
        end
    end

    wire w_stall = (awvalid & ~awready) | (wvalid & ~wready) | ((b_owed > 0) & ~bvalid);
    wire r_stall = (arvalid & ~arready) | ((r_owed > 0) & ~rvalid); 
    
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
    localparam B_W = AXI_ID_WIDTH + 2;
    localparam R_W = AXI_ID_WIDTH + 32 + 2 + 1;

    wire [B_W-1:0] b_payload = {bid, bresp};
    wire [R_W-1:0] r_payload = {rid, rdata, rresp, rlast};

    reg bvalid_q, rvalid_q, bready_q, rready_q;
    reg [B_W-1:0] b_payload_q;
    reg [R_W-1:0] r_payload_q;

    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin 
            bvalid_q<=0; rvalid_q<=0; bready_q<=0; rready_q<=0; 
            b_payload_q<=0; r_payload_q<=0;
        end else begin 
            bvalid_q<=bvalid; rvalid_q<=rvalid; bready_q<=bready; rready_q<=rready; 
            b_payload_q<=b_payload; r_payload_q<=r_payload;
        end
    end

    // Basic: Dropped VALID
    wire b_dropped = bvalid_q & ~bready_q & ~bvalid;
    wire r_dropped = rvalid_q & ~rready_q & ~rvalid;

    // Strict: Payload Stability
    wire b_unstable = bvalid_q & ~bready_q & bvalid & (b_payload != b_payload_q);
    wire r_unstable = rvalid_q & ~rready_q & rvalid & (r_payload != r_payload_q);

    assign protocol_w_fault_o = ENABLE_PROTOCOL_CHECK & (b_dropped | (ENABLE_STRICT_PAYLOAD_CHECK & b_unstable));
    assign protocol_r_fault_o = ENABLE_PROTOCOL_CHECK & (r_dropped | (ENABLE_STRICT_PAYLOAD_CHECK & r_unstable));

endmodule