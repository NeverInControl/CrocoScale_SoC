`timescale 1ns / 1ps

module pe #(
    parameter int ACTIVATION_WIDTH = 8,
    parameter int WEIGHT_WIDTH     = 8,
    parameter int PSUM_WIDTH       = 32
)(
    input  wire                                clk_i,
    input  wire                                rst_n,
    input  wire                                array_en,
    
    // Explicitly Signed Compute Data Stream
    input  wire signed [ACTIVATION_WIDTH-1:0]  act_in,
    input  wire signed [PSUM_WIDTH-1:0]        psum_in,
    output reg  signed [ACTIVATION_WIDTH-1:0]  act_out,
    output reg  signed [PSUM_WIDTH-1:0]        psum_out,
    
    // Weight Shadow Shift Chain & Swap
    input  wire signed [WEIGHT_WIDTH-1:0]      weight_shift_in,
    output wire signed [WEIGHT_WIDTH-1:0]      weight_shift_out,
    input  wire                                weight_shift_en,
    input  wire                                swap_weights
);

    reg signed [WEIGHT_WIDTH-1:0] shadow_weight;
    reg signed [WEIGHT_WIDTH-1:0] active_weight;

    always_ff @(posedge clk_i or negedge rst_n) begin
        if (!rst_n) begin
            shadow_weight <= '0;
        end else if (weight_shift_en) begin
            shadow_weight <= weight_shift_in;
        end
    end

    assign weight_shift_out = shadow_weight;

    always_ff @(posedge clk_i or negedge rst_n) begin
        if (!rst_n) begin
            active_weight <= '0;
            act_out       <= '0;
            psum_out      <= '0;
        end else begin
            if (swap_weights) begin
                active_weight <= shadow_weight;
            end
            
            if (array_en) begin
                act_out  <= act_in;
                psum_out <= psum_in + (act_in * active_weight);
            end
        end
    end

endmodule