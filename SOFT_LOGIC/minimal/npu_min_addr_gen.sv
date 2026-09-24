`timescale 1ns / 1ps

/* ===============================================================================================
 * File: SOFT_LOGIC/minimal/npu_min_addr_gen.sv
 * Module: npu_min_addr_gen
 * Project: CrocoScale SoC -- eFPGA Minimal NPU Address Scheduler
 *
 * Description:
 *   Ultra-low area systolic activation SRAM address scheduler:
 *   - Only Row 0 computes/steps the memory address incrementally.
 *   - Rows 1..7 directly shift Row r-1's address by 1 cycle (systolic skew chain).
 *   - Eliminates 7 parallel multiplier/subtractor blocks for minimum LUT footprint.
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
        // 1x1 Mode: Row 0 addresses linear pixel (comp_k_i), Rows 1..7 shift
        always_ff @(posedge clk_i) begin
            if (!rst_n) begin
                act_sram_addr_o <= '0;
            end else begin
                act_sram_addr_o[0] <= (comp_k_i < 9'd256) ? (ACT_ADDR_WIDTH)'(comp_k_i) : '0;
                for (int r = 1; r < ARRAY_HEIGHT; r++) begin
                    act_sram_addr_o[r] <= act_sram_addr_o[r-1];
                end
            end
        end
    end else begin : gen_3x3
        // 3x3 Mode: Incremental coordinate stepper for Row 0, Rows 1..7 shift
        logic [ACT_ADDR_WIDTH-1:0] pass_start_addr;
        logic [ACT_ADDR_WIDTH-1:0] next_row0_addr;
        logic [3:0]                col_cnt_reg;

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

        assign next_row0_addr = (comp_k_i == 9'd0) ? pass_start_addr :
                                (act_sram_addr_o[0] + {7'd0, (&col_cnt_reg), 1'b1});

        always_ff @(posedge clk_i) begin
            if (!rst_n) begin
                col_cnt_reg     <= '0;
                act_sram_addr_o <= '0;
            end else begin
                if (comp_k_i == 9'd0) begin
                    col_cnt_reg <= 4'd0;
                end else if (comp_k_i < 9'd256) begin
                    col_cnt_reg <= col_cnt_reg + 1'b1;
                end

                act_sram_addr_o[0] <= (comp_k_i < 9'd256) ? next_row0_addr : '0;
                for (int r = 1; r < ARRAY_HEIGHT; r++) begin
                    act_sram_addr_o[r] <= act_sram_addr_o[r-1];
                end
            end
        end
    end
endgenerate

endmodule
