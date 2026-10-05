`timescale 1ns / 1ps

/* ===============================================================================================
 * File: SOFT_LOGIC/minimal/npu_min_addr_gen.sv
 * Module: npu_min_addr_gen
 * Project: CrocoScale SoC -- eFPGA Minimal NPU Address Scheduler
 *
 * Description:
 *   Ultra-low area systolic activation SRAM address scheduler:
 *   - Only Row 0 computes/steps the memory address incrementally (1 adder).
 *   - Rows 1..7 directly shift Row r-1's address by 1 cycle (systolic skew chain).
 *   - Gated by comp_active_i to ensure zero address bleed during idle/preload states.
 *   - Pure continuous assign on act_sram_addr_o prevents Icarus Verilog elab crashes.
 * =============================================================================================== */

module npu_min_addr_gen #(
    parameter int KERNEL_SIZE    = 3,
    parameter int ARRAY_HEIGHT   = 8,
    parameter int ACT_ADDR_WIDTH = 9
)(
    input  wire                                          clk_i,
    input  wire                                          rst_n,
    input  wire                                          comp_active_i,
    input  wire [3:0]                                    pass_idx_i,
    input  wire [8:0]                                    comp_k_i,
    output wire [ARRAY_HEIGHT-1:0][ACT_ADDR_WIDTH-1:0]  act_sram_addr_o
);

    logic [ACT_ADDR_WIDTH-1:0] row0_addr;
    logic [ARRAY_HEIGHT-1:1][ACT_ADDR_WIDTH-1:0] shift_reg;

    generate
        if (KERNEL_SIZE == 1) begin : gen_1x1
            assign row0_addr = (comp_active_i && (comp_k_i < 9'd256)) ?
                               (ACT_ADDR_WIDTH)'(comp_k_i) : '0;
        end else begin : gen_3x3
            logic [ACT_ADDR_WIDTH-1:0] pass_start_addr;

            always_comb begin
                case (pass_idx_i)
                    4'd0: pass_start_addr = 9'd0;
                    4'd1: pass_start_addr = 9'd1;
                    4'd2: pass_start_addr = 9'd2;
                    4'd3: pass_start_addr = 9'd18;
                    4'd4: pass_start_addr = 9'd19;
                    4'd5: pass_start_addr = 9'd20;
                    4'd6: pass_start_addr = 9'd36;
                    4'd7: pass_start_addr = 9'd37;
                    4'd8: pass_start_addr = 9'd38;
                    default: pass_start_addr = 9'd0;
                endcase
            end

            assign row0_addr = (comp_active_i && (comp_k_i < 9'd256)) ?
                (ACT_ADDR_WIDTH)'(pass_start_addr + comp_k_i + {3'b0, comp_k_i[7:4], 1'b0}) : '0;
        end
    endgenerate

    assign act_sram_addr_o[0] = row0_addr;
    generate
        for (genvar r = 1; r < ARRAY_HEIGHT; r++) begin : gen_shift_out
            assign act_sram_addr_o[r] = shift_reg[r];
        end
    endgenerate

    always_ff @(posedge clk_i or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= '0;
        end else begin
            shift_reg[1] <= row0_addr;
            for (int r = 2; r < ARRAY_HEIGHT; r++) begin
                shift_reg[r] <= shift_reg[r-1];
            end
        end
    end

endmodule
