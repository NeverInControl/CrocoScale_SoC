`timescale 1ns / 1ps

// ============================================================================
// Module: npu_prng
// Fully Parameterized Autonomous Galois LFSR (Pseudo-Random Noise Generator).
// ============================================================================

module npu_prng #(
    parameter int                      LFSR_WIDTH = 16,
    parameter bit [LFSR_WIDTH-1:0]     RESET_SEED = '0,
    parameter bit [LFSR_WIDTH-1:0]     POLY       = '0
)(
    input  wire                      clk_i,
    input  wire                      rst_n,
    output wire [LFSR_WIDTH-1:0]     rand_out
);

    // Evaluated at elaboration time using parameter in scope
    function automatic [LFSR_WIDTH-1:0] get_default_poly();
        case (LFSR_WIDTH)
            8:       return 8'hB8;              // x^8 + x^6 + x^5 + x^4 + 1
            16:      return 16'hB400;           // x^16 + x^14 + x^13 + x^11 + 1
            24:      return 24'hE10000;         // x^24 + x^23 + x^22 + x^17 + 1
            32:      return 32'h80000057;       // x^32 + x^22 + x^2 + x^1 + 1
            default: return 16'hB400;
        endcase
    endfunction

    function automatic [LFSR_WIDTH-1:0] get_default_seed();
        case (LFSR_WIDTH)
            8:       return 8'hAC;
            16:      return 16'hACE1;
            24:      return 24'hACE100;
            32:      return 32'hACE12345;
            default: return (LFSR_WIDTH >= 16) ? 16'hACE1 : 8'hAC;
        endcase
    endfunction

    localparam bit [LFSR_WIDTH-1:0] ACTIVE_POLY  = (POLY != '0) ? POLY : get_default_poly();
    localparam bit [LFSR_WIDTH-1:0] DEFAULT_SEED = (RESET_SEED != '0) ? RESET_SEED : get_default_seed();

    reg [LFSR_WIDTH-1:0] lfsr;

    always_ff @(posedge clk_i or negedge rst_n) begin
        if (!rst_n) begin
            lfsr <= (DEFAULT_SEED != '0) ? DEFAULT_SEED : '1;
        end else begin
            lfsr <= {lfsr[LFSR_WIDTH-2:0], 1'b0} ^ (lfsr[LFSR_WIDTH-1] ? ACTIVE_POLY : '0);
        end
    end

    assign rand_out = lfsr;

endmodule