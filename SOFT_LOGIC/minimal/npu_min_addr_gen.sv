`timescale 1ns / 1ps

/* ===============================================================================================
 * File: SOFT_LOGIC/minimal/npu_min_addr_gen.sv
 * Module: npu_min_addr_gen
 * Project: CrocoScale SoC -- eFPGA Minimal NPU Address Scheduler
 *
 * Description:
 *   Schedules activation SRAM read addresses for systolic matrix operations.
 *   Compile-time parameterizable via KERNEL_SIZE:
 *   - KERNEL_SIZE == 1: 1x1 convolution (direct 16x16 linear spatial skew, 0 halo overhead).
 *   - KERNEL_SIZE == 3: 3x3 halo convolution (18x18 halo 2D spatial iteration across 9 passes).
 *   Unused mode logic is completely eliminated at elaboration/synthesis time.
 * =============================================================================================== */

module npu_min_addr_gen #(
    parameter int KERNEL_SIZE    = 3,
    parameter int ARRAY_HEIGHT   = 8,
    parameter int ACT_ADDR_WIDTH = 9
)(
    input  wire                                          clk_i,
    input  wire                                          rst_n,
    input  wire [3:0]                                    pass_idx_i,
    input  wire [8:0]                                    comp_k_i,
    output logic [ARRAY_HEIGHT-1:0][ACT_ADDR_WIDTH-1:0] act_sram_addr_o
);

generate
    if (KERNEL_SIZE == 1) begin : gen_1x1
        // 1x1 Mode: 16x16 Tile (256 pixels), direct linear spatial skew
        always_ff @(posedge clk_i) begin
            if (!rst_n) begin
                act_sram_addr_o <= '0;
            end else begin
                for (int r = 0; r < ARRAY_HEIGHT; r++) begin
                    if ((comp_k_i >= 9'(r)) && ((comp_k_i - 9'(r)) < 9'd256)) begin
                        act_sram_addr_o[r] <= (ACT_ADDR_WIDTH)'(comp_k_i - 9'(r));
                    end else begin
                        act_sram_addr_o[r] <= '0;
                    end
                end
            end
        end
    end else begin : gen_3x3
        // 3x3 Mode: 18x18 Halo Tile, 2D spatial iteration across (ky, kx)
        logic [1:0] ky;
        logic [1:0] kx;

        always_comb begin
            case (pass_idx_i)
                4'd0: begin ky = 2'd0; kx = 2'd0; end
                4'd1: begin ky = 2'd0; kx = 2'd1; end
                4'd2: begin ky = 2'd0; kx = 2'd2; end
                4'd3: begin ky = 2'd1; kx = 2'd0; end
                4'd4: begin ky = 2'd1; kx = 2'd1; end
                4'd5: begin ky = 2'd1; kx = 2'd2; end
                4'd6: begin ky = 2'd2; kx = 2'd0; end
                4'd7: begin ky = 2'd2; kx = 2'd1; end
                4'd8: begin ky = 2'd2; kx = 2'd2; end
                default: begin ky = 2'd0; kx = 2'd0; end
            endcase
        end

        always_ff @(posedge clk_i) begin
            if (!rst_n) begin
                act_sram_addr_o <= '0;
            end else begin
                for (int r = 0; r < ARRAY_HEIGHT; r++) begin
                    if ((comp_k_i >= 9'(r)) && ((comp_k_i - 9'(r)) < 9'd256)) begin
                        logic [4:0] iy;
                        logic [4:0] ix;
                        logic [8:0] p;
                        p  = comp_k_i - 9'(r);
                        iy = (p >> 4) + {3'b0, ky};
                        ix = (p & 9'd15) + {3'b0, kx};
                        act_sram_addr_o[r] <= (ACT_ADDR_WIDTH)'((iy * 18) + ix);
                    end else begin
                        act_sram_addr_o[r] <= '0;
                    end
                end
            end
        end
    end
endgenerate

endmodule
