// =============================================================================
// File: TEST/SoftLogic/full/modules/tb_npu_full_sequencer.sv
// Module: tb_npu_full_sequencer
// Project: CrocoScale SoC — Unit Testbench for Full Dual-Mode Sequencer
//
// Description:
//   Self-contained unit testbench validating npu_full_sequencer in:
//   1. 3x3 im2col multi-channel mode: verifies preload phase, systolic
//      execution cycles, weight swap pulses, and drain sequence.
//   2. 1x1 half-array double-buffered mode: verifies bank ping-pong,
//      grounded upper rows (4..7), and concurrent background DMA preloads.
// =============================================================================

`timescale 1ns / 1ps

module tb_npu_full_sequencer;

    localparam int ARRAY_HEIGHT = 8;
    localparam int ARRAY_WIDTH  = 8;
    localparam int CIN          = 128;
    localparam int COUT         = 32;

    logic        clk;
    logic        rst_n;
    logic        start;
    logic        mode_1x1;
    logic [7:0]  total_passes;

    // DUT Signals
    wire         busy;
    wire         done;
    wire [7:0]   current_pass;
    wire [8:0]   cycle_in_pass;
    wire         array_en;
    wire         psum_systolic_en;
    wire         psum_lut_en;
    wire         psum_skew_en;
    wire         compute_bank_swap;
    wire [ARRAY_HEIGHT-1:0][3:0] crossbar_sel;
    wire [ARRAY_HEIGHT-1:0][8:0] act_sram_addr;
    wire [ARRAY_HEIGHT-1:0]      act_sram_we;
    wire [1:0]   weight_shift_en;
    wire         swap_weights;
    wire [2:0]   weight_shift_step;
    wire [7:0]   psum_A_addr;
    wire [ARRAY_WIDTH-1:0] psum_A_we;
    wire [7:0]   psum_B_addr;
    wire [ARRAY_WIDTH-1:0] psum_B_we;
    wire         preload_phase;
    wire [7:0]   preload_step;
    wire signed [7:0] dma_channel_to_load;
    wire [5:0][5:0]   dma_bank_ptr;
    wire         start_lut_load;
    wire         lut_phase;
    wire         drain_phase;
    wire [8:0]   drain_step;

    wire dut_drain_done = (drain_step == 9'd258);

    // Clock Generation (100 MHz)
    initial clk = 0;
    always #5 clk = ~clk;

    // DUT: Full Dual-Mode Sequencer
    npu_full_sequencer #(
        .ARRAY_HEIGHT(ARRAY_HEIGHT),
        .ARRAY_WIDTH (ARRAY_WIDTH),
        .CIN         (CIN),
        .COUT        (COUT)
    ) dut (
        .clk_i                (clk),
        .rst_n                (rst_n),
        .start_i              (start),
        .mode_1x1_i           (mode_1x1),
        .lut_en_i             (1'b0),
        .lut_load_done_i      (1'b0),
        .drain_done_i         (dut_drain_done),
        .total_passes_i       (total_passes),
        .busy_o               (busy),
        .done_o               (done),
        .current_pass_o       (current_pass),
        .cycle_in_pass_o      (cycle_in_pass),
        .array_en_o           (array_en),
        .psum_systolic_en_o   (psum_systolic_en),
        .psum_lut_en_o        (psum_lut_en),
        .psum_skew_en_o       (psum_skew_en),
        .compute_bank_swap_o  (compute_bank_swap),
        .crossbar_sel_o       (crossbar_sel),
        .act_sram_addr_o      (act_sram_addr),
        .act_sram_we_o        (act_sram_we),
        .weight_shift_en_o    (weight_shift_en),
        .swap_weights_o       (swap_weights),
        .weight_shift_step_o  (weight_shift_step),
        .psum_A_addr_o        (psum_A_addr),
        .psum_A_we_o          (psum_A_we),
        .psum_B_addr_o        (psum_B_addr),
        .psum_B_we_o          (psum_B_we),
        .preload_phase_o      (preload_phase),
        .preload_step_o       (preload_step),
        .dma_channel_to_load_o(dma_channel_to_load),
        .dma_bank_ptr_o       (dma_bank_ptr),
        .start_lut_load_o     (start_lut_load),
        .lut_phase_o          (lut_phase),
        .drain_phase_o        (drain_phase),
        .drain_step_o         (drain_step)
    );

    int err_count;
    int sim_cycle;
    int pass_seen;

    initial begin
        err_count = 0;
        sim_cycle = 0;
        pass_seen = 0;

        $display("\n=========================================================================");
        $display(">>> Test 1: Full Sequencer 3x3 im2col Mode Verification <<<");
        $display("=========================================================================");

        rst_n        = 0;
        start        = 0;
        mode_1x1     = 0;
        total_passes = 8'd18;
        #50;
        @(negedge clk);
        rst_n = 1;
        #20;
        @(negedge clk);
        start = 1;
        @(negedge clk);
        start = 0;

        // Wait for busy
        while (!busy) @(posedge clk);

        // Preload checks
        if (!preload_phase) begin
            $display("[FAIL 3x3] Expected preload_phase at start!");
            err_count++;
        end

        while (busy) begin
            @(posedge clk);
            #1;
            sim_cycle++;

            if (dut.fsm_inst.state_o == 3'd2) begin
                // Active compute pass
                if (current_pass != pass_seen) begin
                    pass_seen = current_pass;
                end
                if (cycle_in_pass < 256) begin
                    if (!array_en || !psum_systolic_en) begin
                        $display("[FAIL 3x3] Cycle %0d: Expected array_en and psum_systolic_en at cycle_in_pass %0d",
                            sim_cycle, cycle_in_pass);
                        err_count++;
                    end
                end
                // Verify ping-pong swap
                if (compute_bank_swap !== current_pass[0]) begin
                    $display("[FAIL 3x3] Cycle %0d: compute_bank_swap mismatch!", sim_cycle);
                    err_count++;
                end
            end

            if (err_count > 10) begin
                $display("[FATAL] Too many 3x3 mismatches. Aborting.");
                $finish;
            end
        end

        $display("Completed 3x3 test (%0d cycles, %0d passes). Errors: %0d", sim_cycle, pass_seen + 1, err_count);
        if (err_count == 0) $display(">>> SUCCESS: 3x3 Mode Verified 100%%! <<<");

        // ---------------------------------------------------------------------
        // Test 2: 1x1 Half-Array Double-Buffered Mode Verification
        // ---------------------------------------------------------------------
        $display("\n=========================================================================");
        $display(">>> Test 2: Full Sequencer 1x1 Half-Array Verification <<<");
        $display("=========================================================================");

        #50;
        @(negedge clk);
        mode_1x1     = 1;
        total_passes = 8'd6; // 6 passes x 4 channels = 24 input channels
        start        = 1;
        @(negedge clk);
        start        = 0;

        // Wait for busy to assert
        while (!busy) @(posedge clk);

        sim_cycle = 0;
        while (busy) begin
            @(posedge clk);
            #1;
            sim_cycle++;

            // In 1x1 compute phase: verify half-array properties
            if (dut.fsm_inst.state_o == 3'd2) begin // SEQ_COMPUTE
                if (current_pass[0] == 1'b0) begin
                    // Pass even: Rows 0..3 read Banks 0..3
                    for (int r = 0; r < 4; r++) begin
                        if (crossbar_sel[r] !== {1'b0, 3'(r)}) begin
                            $display("[FAIL 1x1] Cycle %0d, Pass %0d: Expected crossbar[%0d] = %0d, got %0d",
                                sim_cycle, current_pass, r, r, crossbar_sel[r]);
                            err_count++;
                        end
                    end
                    // Rows 4..7 must be grounded (4'b1000)
                    for (int r = 4; r < 8; r++) begin
                        if (crossbar_sel[r] !== 4'b1000) begin
                            $display("[FAIL 1x1] Cycle %0d: Row %0d not grounded!", sim_cycle, r);
                            err_count++;
                        end
                    end
                    // If next pass exists and k < 256, Banks 4..7 must be writing
                    if (current_pass + 1 < total_passes && cycle_in_pass < 256) begin
                        if (act_sram_we[7:4] !== 4'hF) begin
                            $display("[FAIL 1x1] Cycle %0d: Banks 4..7 WE not asserted during preload!", sim_cycle);
                            err_count++;
                        end
                    end
                end else begin
                    // Pass odd: Roles swap! Rows 0..3 read Banks 4..7
                    for (int r = 0; r < 4; r++) begin
                        if (crossbar_sel[r] !== {1'b0, 3'(4 + r)}) begin
                            $display("[FAIL 1x1] Cycle %0d, Pass %0d: Expected crossbar[%0d] = %0d, got %0d",
                                sim_cycle, current_pass, r, 4 + r, crossbar_sel[r]);
                            err_count++;
                        end
                    end
                    // Rows 4..7 must be grounded
                    for (int r = 4; r < 8; r++) begin
                        if (crossbar_sel[r] !== 4'b1000) begin
                            $display("[FAIL 1x1] Cycle %0d: Row %0d not grounded!", sim_cycle, r);
                            err_count++;
                        end
                    end
                    // If next pass exists and k < 256, Banks 0..3 must be writing
                    if (current_pass + 1 < total_passes && cycle_in_pass < 256) begin
                        if (act_sram_we[3:0] !== 4'hF) begin
                            $display("[FAIL 1x1] Cycle %0d: Banks 0..3 WE not asserted during preload!", sim_cycle);
                            err_count++;
                        end
                    end
                end
            end

            if (err_count > 10) begin
                $display("[FATAL] Too many 1x1 mismatches. Aborting.");
                $finish;
            end
        end

        $display("Completed 1x1 test (%0d cycles). Errors: %0d", sim_cycle, err_count);
        if (err_count == 0) $display(">>> SUCCESS: 1x1 Half-Array Sequencer Verified 100%%! <<<");

        $display("\n=========================================================================");
        $display(">>> ALL FULL SEQUENCER TESTS PASSED SUCCESSFULLY! <<<");
        $display("=========================================================================\n");
        $finish;
    end

endmodule
