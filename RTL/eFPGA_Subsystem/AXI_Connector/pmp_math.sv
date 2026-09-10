`timescale 1ns / 1ps

module pmp_math #(
    parameter int NUM_REGIONS       = 2,
    parameter bit PAGE_GRANULARITY  = 1'b1, // 1 = 4KB Aligned Pages, 0 = Exact Word Granularity
    parameter int MAX_ADDRESS_WIDTH = 32
)(
    input  logic g_en_i,

    // Base & Limit Registers:
    // When PAGE_GRANULARITY == 1: Base/Limit registers store Page Frame Numbers (bits [MAX_ADDRESS_WIDTH-1:12])
    // Control bits: base_i[r][1:0] = {Write_En, Read_En}, limit_i[r][1:0] = {Sec_Req, Priv_Req}
    input  logic [NUM_REGIONS-1:0][31:0] base_i,
    input  logic [NUM_REGIONS-1:0][31:0] limit_i,

    input  logic [31:0] awaddr_i,
    input  logic [7:0]  awlen_i,
    input  logic [2:0]  awsize_i,
    input  logic [2:0]  awprot_i,
    input  logic        awvalid_i,

    input  logic [31:0] araddr_i,
    input  logic [7:0]  arlen_i,
    input  logic [2:0]  arsize_i,
    input  logic [2:0]  arprot_i,
    input  logic        arvalid_i,

    output logic        violation_r_o,
    output logic        violation_w_o
);

    localparam int ADDR_SHIFT = PAGE_GRANULARITY ? 12 : 2;
    localparam int COMP_WIDTH = MAX_ADDRESS_WIDTH - ADDR_SHIFT;

    // Security Flag Extraction (PROT[0]: Privileged, PROT[1]: Non-Secure)
    wire aw_is_priv = awprot_i[0]; 
    wire aw_is_sec  = ~awprot_i[1];
    wire ar_is_priv = arprot_i[0]; 
    wire ar_is_sec  = ~arprot_i[1];

    logic [NUM_REGIONS-1:0] aw_region_ok;
    logic [NUM_REGIONS-1:0] ar_region_ok;
    
    wire aw_malicious_wrap;
    wire ar_malicious_wrap;

    // =========================================================================
    // DUAL-MODE LOGIC IMPLEMENTATION
    // =========================================================================
    generate
        if (PAGE_GRANULARITY == 1) begin : gen_fast_4k_page_math
            // -----------------------------------------------------------------
            // 4KB ALIGNED PAGE MODE
            // -----------------------------------------------------------------
            // Fast 13-bit check: In-page offset [11:0] + burst byte count.
            // AXI bursts must not cross a 4KB boundary.
            wire [12:0] aw_burst_bytes = 13'((13'(awlen_i) + 13'd1) << awsize_i);
            wire [12:0] ar_burst_bytes = 13'((13'(arlen_i) + 13'd1) << arsize_i);

            wire [12:0] aw_offset_sum  = {1'b0, awaddr_i[11:0]} + aw_burst_bytes;
            wire [12:0] ar_offset_sum  = {1'b0, araddr_i[11:0]} + ar_burst_bytes;

            // sum > 4096 triggers a wrap violation
            // (Bit 12 is high and lower 12 bits != 0 means sum is 4097..8191)
            wire aw_overflow = aw_offset_sum[12] && (aw_offset_sum[11:0] != 12'd0);
            wire ar_overflow = ar_offset_sum[12] && (ar_offset_sum[11:0] != 12'd0);

            assign aw_malicious_wrap = aw_overflow;
            assign ar_malicious_wrap = ar_overflow;

            // Page Frame Number (PFN) Start Comparison (Upper 20 bits only)
            wire [COMP_WIDTH-1:0] aw_pfn = awaddr_i[MAX_ADDRESS_WIDTH-1 : 12];
            wire [COMP_WIDTH-1:0] ar_pfn = araddr_i[MAX_ADDRESS_WIDTH-1 : 12];

            for (genvar r = 0; r < NUM_REGIONS; r++) begin : pmp_checks_4k
                wire read_en   = base_i[r][0];
                wire write_en  = base_i[r][1];
                wire req_priv  = limit_i[r][0];
                wire req_sec   = limit_i[r][1];

                wire [COMP_WIDTH-1:0] base_pfn  = base_i[r][MAX_ADDRESS_WIDTH-1 : 12];
                wire [COMP_WIDTH-1:0] limit_pfn = limit_i[r][MAX_ADDRESS_WIDTH-1 : 12];

                // Single PFN comparator per bound (No adders in this path)
                wire aw_in_bounds = (aw_pfn >= base_pfn) && (aw_pfn < limit_pfn);
                wire ar_in_bounds = (ar_pfn >= base_pfn) && (ar_pfn < limit_pfn);

                wire aw_sec_ok = (!req_priv || aw_is_priv) && (!req_sec || aw_is_sec);
                wire ar_sec_ok = (!req_priv || ar_is_priv) && (!req_sec || ar_is_sec);

                assign aw_region_ok[r] = write_en && aw_in_bounds && aw_sec_ok;
                assign ar_region_ok[r] = read_en  && ar_in_bounds && ar_sec_ok;
            end

        end else begin : gen_exact_word_math
            // -----------------------------------------------------------------
            // EXACT WORD GRANULARITY MODE
            // -----------------------------------------------------------------
            // Full 32-bit addition with MSB carry out to catch 4GB address space wrap
            wire [16:0] aw_burst_bytes = 17'((17'(awlen_i) + 17'd1) << awsize_i);
            wire [16:0] ar_burst_bytes = 17'((17'(arlen_i) + 17'd1) << arsize_i);

            wire [MAX_ADDRESS_WIDTH:0] aw_end_addr_full = {1'b0, awaddr_i[MAX_ADDRESS_WIDTH-1:0]} + 33'(aw_burst_bytes) - 33'd1;
            wire [MAX_ADDRESS_WIDTH:0] ar_end_addr_full = {1'b0, araddr_i[MAX_ADDRESS_WIDTH-1:0]} + 33'(ar_burst_bytes) - 33'd1;

            assign aw_malicious_wrap = aw_end_addr_full[MAX_ADDRESS_WIDTH];
            assign ar_malicious_wrap = ar_end_addr_full[MAX_ADDRESS_WIDTH];

            wire [COMP_WIDTH-1:0] aw_start = awaddr_i[MAX_ADDRESS_WIDTH-1 : 2];
            wire [COMP_WIDTH-1:0] aw_end   = aw_end_addr_full[MAX_ADDRESS_WIDTH-1 : 2];
            wire [COMP_WIDTH-1:0] ar_start = araddr_i[MAX_ADDRESS_WIDTH-1 : 2];
            wire [COMP_WIDTH-1:0] ar_end   = ar_end_addr_full[MAX_ADDRESS_WIDTH-1 : 2];

            for (genvar r = 0; r < NUM_REGIONS; r++) begin : pmp_checks_word
                wire read_en   = base_i[r][0];
                wire write_en  = base_i[r][1];
                wire req_priv  = limit_i[r][0];
                wire req_sec   = limit_i[r][1];

                wire [COMP_WIDTH-1:0] base_val  = base_i[r][MAX_ADDRESS_WIDTH-1 : 2];
                wire [COMP_WIDTH-1:0] limit_val = limit_i[r][MAX_ADDRESS_WIDTH-1 : 2];

                // Exact word range check: [Start >= Base] and [End < Limit]
                wire aw_in_bounds = (aw_start >= base_val) && (aw_end < limit_val);
                wire ar_in_bounds = (ar_start >= base_val) && (ar_end < limit_val);

                wire aw_sec_ok = (!req_priv || aw_is_priv) && (!req_sec || aw_is_sec);
                wire ar_sec_ok = (!req_priv || ar_is_priv) && (!req_sec || ar_is_sec);

                assign aw_region_ok[r] = write_en && aw_in_bounds && aw_sec_ok;
                assign ar_region_ok[r] = read_en  && ar_in_bounds && ar_sec_ok;
            end
        end
    endgenerate

    // =========================================================================
    // FINAL VIOLATION FLAGS
    // =========================================================================
    wire aw_allowed = (|aw_region_ok) && ~aw_malicious_wrap;
    wire ar_allowed = (|ar_region_ok) && ~ar_malicious_wrap;

    assign violation_w_o = g_en_i & (awvalid_i & ~aw_allowed);
    assign violation_r_o = g_en_i & (arvalid_i & ~ar_allowed);

endmodule