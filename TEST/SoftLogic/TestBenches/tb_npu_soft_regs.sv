`timescale 1ns / 1ps

/* ===============================================================================================
 * tb_npu_soft_regs.sv
 *
 * Standalone Unit Testbench for npu_soft_regs (AXI4-Lite CSR Block)
 * =============================================================================================== */

module tb_npu_soft_regs;

    logic clk;
    logic rst_n;

    // AXI-Lite signals
    logic [31:0] s_axil_awaddr;
    logic [2:0]  s_axil_awprot;
    logic        s_axil_awvalid;
    wire         s_axil_awready;

    logic [31:0] s_axil_wdata;
    logic [3:0]  s_axil_wstrb;
    logic        s_axil_wvalid;
    wire         s_axil_wready;

    wire  [1:0]  s_axil_bresp;
    wire         s_axil_bvalid;
    logic        s_axil_bready;

    logic [31:0] s_axil_araddr;
    logic [2:0]  s_axil_arprot;
    logic        s_axil_arvalid;
    wire         s_axil_arready;

    wire  [31:0] s_axil_rdata;
    wire  [1:0]  s_axil_rresp;
    wire         s_axil_rvalid;
    logic        s_axil_rready;

    // Decoded outputs
    wire         start_pulse_o;
    wire         soft_reset_o;
    wire  [31:0] act_base_o;
    wire  [31:0] weight_base_o;
    wire  [31:0] out_base_o;
    wire  [31:0] bias_base_o;
    wire  [31:0] quant_param_o;
    wire  [31:0] config_o;
    wire  [3:0]  usr_irq_o;

    // Status inputs
    logic        fsm_busy_i;
    logic        fsm_done_i;
    logic        irq_pulse_i;

    // Clock generator: 100MHz (10ns)
    initial clk = 0;
    always #5 clk = ~clk;

    // DUT Instance
    npu_soft_regs dut (
        .clk_i          (clk),
        .rst_n          (rst_n),
        .s_axil_awaddr  (s_axil_awaddr),
        .s_axil_awprot  (s_axil_awprot),
        .s_axil_awvalid (s_axil_awvalid),
        .s_axil_awready (s_axil_awready),
        .s_axil_wdata   (s_axil_wdata),
        .s_axil_wstrb   (s_axil_wstrb),
        .s_axil_wvalid  (s_axil_wvalid),
        .s_axil_wready  (s_axil_wready),
        .s_axil_bresp   (s_axil_bresp),
        .s_axil_bvalid  (s_axil_bvalid),
        .s_axil_bready  (s_axil_bready),
        .s_axil_araddr  (s_axil_araddr),
        .s_axil_arprot  (s_axil_arprot),
        .s_axil_arvalid (s_axil_arvalid),
        .s_axil_arready (s_axil_arready),
        .s_axil_rdata   (s_axil_rdata),
        .s_axil_rresp   (s_axil_rresp),
        .s_axil_rvalid  (s_axil_rvalid),
        .s_axil_rready  (s_axil_rready),
        .start_pulse_o  (start_pulse_o),
        .soft_reset_o   (soft_reset_o),
        .act_base_o     (act_base_o),
        .weight_base_o  (weight_base_o),
        .out_base_o     (out_base_o),
        .bias_base_o    (bias_base_o),
        .quant_param_o  (quant_param_o),
        .config_o       (config_o),
        .usr_irq_o      (usr_irq_o),
        .fsm_busy_i     (fsm_busy_i),
        .fsm_done_i     (fsm_done_i),
        .irq_pulse_i    (irq_pulse_i)
    );

    // AXI-Lite Driver Tasks
    task automatic axil_write(input logic [31:0] addr, input logic [31:0] data);
        @(posedge clk);
        #1;
        s_axil_awaddr  = addr;
        s_axil_awvalid = 1'b1;
        s_axil_wdata   = data;
        s_axil_wstrb   = 4'hF;
        s_axil_wvalid  = 1'b1;
        s_axil_bready  = 1'b1;

        fork
            begin
                while (!s_axil_awready) @(posedge clk);
                #1;
                s_axil_awvalid = 1'b0;
            end
            begin
                while (!s_axil_wready) @(posedge clk);
                #1;
                s_axil_wvalid = 1'b0;
            end
        join

        while (!s_axil_bvalid) @(posedge clk);
        @(posedge clk);
        #1;
        s_axil_bready = 1'b0;
    endtask

    task automatic axil_read(input logic [31:0] addr, output logic [31:0] data);
        @(posedge clk);
        #1;
        s_axil_araddr  = addr;
        s_axil_arvalid = 1'b1;
        s_axil_rready  = 1'b0;

        while (!s_axil_arready) @(posedge clk);
        #1;
        s_axil_arvalid = 1'b0;

        while (!s_axil_rvalid) @(posedge clk);
        #1;
        data = s_axil_rdata;
        s_axil_rready = 1'b1;
        @(posedge clk);
        #1;
        s_axil_rready = 1'b0;
    endtask

    int errors = 0;
    logic [31:0] rdata;

    initial begin
        $display("\n==========================================================");
        $display(">>> Starting Unit Test: npu_soft_regs (AXI-Lite CSR) <<<");
        $display("==========================================================");

        // Reset
        rst_n          = 0;
        s_axil_awaddr  = '0;
        s_axil_awprot  = '0;
        s_axil_awvalid = '0;
        s_axil_wdata   = '0;
        s_axil_wstrb   = '0;
        s_axil_wvalid  = '0;
        s_axil_bready  = '0;
        s_axil_araddr  = '0;
        s_axil_arprot  = '0;
        s_axil_arvalid = '0;
        s_axil_rready  = '0;
        fsm_busy_i     = '0;
        fsm_done_i     = '0;
        irq_pulse_i    = '0;

        #30;
        @(negedge clk);
        rst_n = 1;
        #30;

        // Test 1: Check Reset Defaults
        $display("[Test 1] Checking reset defaults...");
        axil_read(32'h08, rdata);
        if (rdata !== 32'h0000_1000) begin
            $display("   [ERROR] ACT_BASE expected 0x00001000, got 0x%08X", rdata);
            errors++;
        end

        axil_read(32'h04, rdata);
        if (rdata !== 32'h0000_0000) begin
            $display("   [ERROR] STATUS expected 0x0, got 0x%08X", rdata);
            errors++;
        end

        // Test 2: Write & Readback CSRs
        $display("[Test 2] Testing MMIO register write and readback...");
        axil_write(32'h08, 32'hA000_1234);
        axil_read(32'h08, rdata);
        if (rdata !== 32'hA000_1234 || act_base_o !== 32'hA000_1234) begin
            $display("   [ERROR] ACT_BASE write/read mismatch: 0x%08X", rdata);
            errors++;
        end

        axil_write(32'h0C, 32'hB000_5678);
        axil_read(32'h0C, rdata);
        if (rdata !== 32'hB000_5678 || weight_base_o !== 32'hB000_5678) begin
            $display("   [ERROR] WEIGHT_BASE write/read mismatch: 0x%08X", rdata);
            errors++;
        end

        axil_write(32'h10, 32'hC000_9ABC);
        axil_read(32'h10, rdata);
        if (rdata !== 32'hC000_9ABC || out_base_o !== 32'hC000_9ABC) begin
            $display("   [ERROR] OUT_BASE write/read mismatch: 0x%08X", rdata);
            errors++;
        end

        axil_write(32'h14, 32'hD000_1357);
        axil_read(32'h14, rdata);
        if (rdata !== 32'hD000_1357 || bias_base_o !== 32'hD000_1357) begin
            $display("   [ERROR] BIAS_BASE write/read mismatch: 0x%08X", rdata);
            errors++;
        end

        axil_write(32'h18, 32'h400F_0001);
        axil_read(32'h18, rdata);
        if (rdata !== 32'h400F_0001 || quant_param_o !== 32'h400F_0001) begin
            $display("   [ERROR] QUANT_PARAM write/read mismatch: 0x%08X", rdata);
            errors++;
        end

        axil_write(32'h1C, 32'h0000_0001);
        axil_read(32'h1C, rdata);
        if (rdata !== 32'h0000_0001 || config_o !== 32'h0000_0001) begin
            $display("   [ERROR] CONFIG write/read mismatch: 0x%08X", rdata);
            errors++;
        end

        // Test 3: Start Trigger & Self-Clearing
        $display("[Test 3] Testing START pulse generation and self-clearing...");
        axil_write(32'h00, 32'h0000_0001);
        axil_read(32'h00, rdata);
        if (rdata[0] !== 1'b0) begin
            $display("   [ERROR] CTRL[0] (START) did not self-clear! Value: 0x%08X", rdata);
            errors++;
        end

        // Test 4: Status Flags Tracking
        $display("[Test 4] Testing hardware status tracking...");
        fsm_busy_i = 1'b1;
        fsm_done_i = 1'b0;
        #10;
        axil_read(32'h04, rdata);
        if (rdata !== 32'h0000_0001) begin
            $display("   [ERROR] STATUS expected busy=1, done=0 (0x1), got 0x%08X", rdata);
            errors++;
        end

        fsm_busy_i = 1'b0;
        fsm_done_i = 1'b1;
        #10;
        axil_read(32'h04, rdata);
        if (rdata !== 32'h0000_0002) begin
            $display("   [ERROR] STATUS expected busy=0, done=1 (0x2), got 0x%08X", rdata);
            errors++;
        end

        // Test 5: Sticky Interrupt Latching & W1C
        $display("[Test 5] Testing sticky IRQ latching and Write-1-to-Clear...");
        @(posedge clk);
        irq_pulse_i <= 1'b1;
        @(posedge clk);
        irq_pulse_i <= 1'b0;
        #20;

        axil_read(32'h20, rdata);
        if (rdata[0] !== 1'b1) begin
            $display("   [ERROR] IRQ_STATUS expected 1 after pulse, got %0d", rdata[0]);
            errors++;
        end

        // Write 1 to clear
        axil_write(32'h20, 32'h0000_0001);
        axil_read(32'h20, rdata);
        if (rdata[0] !== 1'b0) begin
            $display("   [ERROR] IRQ_STATUS did not clear on W1C, got %0d", rdata[0]);
            errors++;
        end

        $display("----------------------------------------------------------");
        if (errors == 0) begin
            $display(">>> SUCCESS: npu_soft_regs Unit Test Passed 100%%! <<<");
        end else begin
            $display(">>> FAILURE: %0d Errors Detected in npu_soft_regs! <<<", errors);
        end
        $display("==========================================================\n");

        #50;
        $finish;
    end

endmodule

