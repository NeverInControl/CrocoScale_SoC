`timescale 1ns / 1ps

module watchdog_timer #(
    parameter integer WATCHDOG_LIMIT = 512
)(
    input  wire clk_i,
    input  wire rstn_i,

    // Control Path (Crossbar Side)
    input  wire ctrl_awvalid_i, input  wire ctrl_awready_i,
    input  wire ctrl_wvalid_i,  input  wire ctrl_wready_i,
    input  wire ctrl_bvalid_i,  input  wire ctrl_bready_i,
    input  wire ctrl_arvalid_i, input  wire ctrl_arready_i,
    input  wire ctrl_rvalid_i,  input  wire ctrl_rready_i,

    // DMA Path (Crossbar Side)
    input  wire dma_awvalid_i, input  wire dma_awready_i,
    input  wire dma_wvalid_i,  input  wire dma_wready_i,  input wire dma_wlast_i,
    input  wire dma_bvalid_i,  input  wire dma_bready_i,
    input  wire dma_arvalid_i, input  wire dma_arready_i,
    input  wire dma_rvalid_i,  input  wire dma_rready_i,  input wire dma_rlast_i,

    output wire timeout_o
);
    
    // ===================================================================
    // AUTOMATIC TIMER SIZING
    // ===================================================================
    // $clog2 calculates the minimum bits needed to store WATCHDOG_LIMIT.
    // e.g., LIMIT = 256 requires $clog2(257) = 9 bits instead of 16.
    localparam TIMER_W = $clog2(WATCHDOG_LIMIT + 1);

    // ===================================================================
    // 1. CTRL WRITE DOMAIN (Fabric is SLAVE)
    // ===================================================================
    reg [7:0] ctrl_b_owed;
    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) ctrl_b_owed <= 0;
        else case ({(ctrl_awvalid_i & ctrl_awready_i & ctrl_wvalid_i & ctrl_wready_i), (ctrl_bvalid_i & ctrl_bready_i)})
            2'b10: ctrl_b_owed <= ctrl_b_owed + 1;
            2'b01: if (ctrl_b_owed > 0) ctrl_b_owed <= ctrl_b_owed - 1;
            default: ;
        endcase
    end

    // Fabric is at fault if: Host wants to send address/data but Fabric refuses, 
    // OR Fabric has the data but refuses to send the B-channel response.
    wire ctrl_w_fabric_stall = (ctrl_awvalid_i & ~ctrl_awready_i) |
                               (ctrl_wvalid_i  & ~ctrl_wready_i)  |
                               ((ctrl_b_owed > 0) & ~ctrl_bvalid_i);

    reg [TIMER_W:0] ctrl_w_timer;
    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) ctrl_w_timer <= 0;
        else if (ctrl_w_fabric_stall) begin
            if (ctrl_w_timer <= WATCHDOG_LIMIT) ctrl_w_timer <= ctrl_w_timer + 1;
        end else ctrl_w_timer <= 0;
    end

    // ===================================================================
    // 2. CTRL READ DOMAIN (Fabric is SLAVE)
    // ===================================================================
    reg [7:0] ctrl_r_owed;
    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) ctrl_r_owed <= 0;
        else case ({(ctrl_arvalid_i & ctrl_arready_i), (ctrl_rvalid_i & ctrl_rready_i)})
            2'b10: ctrl_r_owed <= ctrl_r_owed + 1;
            2'b01: if (ctrl_r_owed > 0) ctrl_r_owed <= ctrl_r_owed - 1;
            default: ;
        endcase
    end

    // Fabric is at fault if: Host wants to send address but Fabric refuses,
    // OR Fabric owes data to the Host but refuses to send it.
    wire ctrl_r_fabric_stall = (ctrl_arvalid_i & ~ctrl_arready_i) |
                               ((ctrl_r_owed > 0) & ~ctrl_rvalid_i);

    reg [TIMER_W:0] ctrl_r_timer;
    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) ctrl_r_timer <= 0;
        else if (ctrl_r_fabric_stall) begin
            if (ctrl_r_timer <= WATCHDOG_LIMIT) ctrl_r_timer <= ctrl_r_timer + 1;
        end else ctrl_r_timer <= 0;
    end

    // ===================================================================
    // 3. DMA WRITE DOMAIN (Fabric is MASTER)
    // ===================================================================
    // Catches mid-burst aborts: Stays high if W beats start but WLAST never fires
    reg dma_w_in_flight;
    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) dma_w_in_flight <= 0;
        else if (dma_wvalid_i && dma_wready_i) begin
            if (dma_wlast_i) dma_w_in_flight <= 0;
            else dma_w_in_flight <= 1;
        end
    end

    // Fabric is at fault if: It started a burst but refuses to send the next beat,
    // OR the Crossbar gave a B-channel response but the Fabric refuses to acknowledge it.
    // (Notice we DO NOT penalize if AWVALID=1 and AWREADY=0, because that is the RAM's fault).
    wire dma_w_fabric_stall = (dma_w_in_flight & ~dma_wvalid_i) | 
                              (dma_bvalid_i & ~dma_bready_i);

    reg [TIMER_W:0] dma_w_timer;
    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) dma_w_timer <= 0;
        else if (dma_w_fabric_stall) begin
            if (dma_w_timer <= WATCHDOG_LIMIT) dma_w_timer <= dma_w_timer + 1;
        end else dma_w_timer <= 0;
    end

    // ===================================================================
    // 4. DMA READ DOMAIN (Fabric is MASTER)
    // ===================================================================
    // Fabric is at fault if: The Crossbar is trying to send R-channel data,
    // but the Fabric drops RREADY to 0. (This is exactly your scenario!).
    // (Notice we DO NOT penalize if ARVALID=1 and ARREADY=0, because that is the RAM's fault).
    wire dma_r_fabric_stall = (dma_rvalid_i & ~dma_rready_i);

    reg [TIMER_W:0] dma_r_timer;
    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) dma_r_timer <= 0;
        else if (dma_r_fabric_stall) begin
            if (dma_r_timer <= WATCHDOG_LIMIT) dma_r_timer <= dma_r_timer + 1;
        end else dma_r_timer <= 0;
    end

    // ===================================================================
    // TIMEOUT AGGREGATION
    // ===================================================================
    assign timeout_o = (ctrl_w_timer >= WATCHDOG_LIMIT) | 
                       (ctrl_r_timer >= WATCHDOG_LIMIT) |
                       (dma_w_timer  >= WATCHDOG_LIMIT) | 
                       (dma_r_timer  >= WATCHDOG_LIMIT);

endmodule