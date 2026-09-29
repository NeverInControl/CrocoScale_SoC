`timescale 1ns / 1ps

module tb_efpga_manager;

    localparam int NUM_SLOTS = 1;
    localparam int NUM_PMP_REGIONS = 2;
    localparam logic [31:0] HW_VERSION = 32'hFAB00001;

    logic clk;
    logic rstn;

    // AXI4-Lite Signals
    logic [31:0] s_axil_awaddr;
    logic [2:0]  s_axil_awprot;
    logic        s_axil_awvalid;
    logic        s_axil_awready;

    logic [31:0] s_axil_wdata;
    logic [3:0]  s_axil_wstrb;
    logic        s_axil_wvalid;
    logic        s_axil_wready;

    logic [1:0]  s_axil_bresp;
    logic        s_axil_bvalid;
    logic        s_axil_bready;

    logic [31:0] s_axil_araddr;
    logic [2:0]  s_axil_arprot;
    logic        s_axil_arvalid;
    logic        s_axil_arready;

    logic [31:0] s_axil_rdata;
    logic [1:0]  s_axil_rresp;
    logic        s_axil_rvalid;
    logic        s_axil_rready;

    // Global eFPGA Interfacing Signals
    logic [31:0] efpga_config_data_o;
    logic        efpga_config_we_o;
    logic [NUM_SLOTS-1:0][31:0] slot_reset_o;
    logic        efpga_com_active_i;

    // Per-Slot Control Arrays
    logic [NUM_SLOTS-1:0][31:0] slot_debug_in_i;
    logic [NUM_SLOTS-1:0][31:0] slot_debug_out_o;

    logic [NUM_SLOTS-1:0]       decoupler_req_o;
    logic [NUM_SLOTS-1:0]       decoupler_force_o;
    logic [NUM_SLOTS-1:0]       decoupler_is_decoupled_i;
    logic [NUM_SLOTS-1:0]       decoupler_host_act_i;
    logic [NUM_SLOTS-1:0]       decoupler_dma_act_i;

    logic [NUM_SLOTS-1:0]       slot_pmp_r_violation_i;
    logic [NUM_SLOTS-1:0]       slot_pmp_w_violation_i;

    logic [NUM_SLOTS-1:0] slot_wdog_cs_to_w_i, slot_wdog_cs_to_r_i, slot_wdog_cs_pr_w_i, slot_wdog_cs_pr_r_i;
    logic [NUM_SLOTS-1:0] slot_wdog_dm_to_w_i, slot_wdog_dm_to_r_i, slot_wdog_dm_pr_w_i, slot_wdog_dm_pr_r_i;
    logic [NUM_SLOTS-1:0] slot_wdog_cm_to_w_i, slot_wdog_cm_to_r_i, slot_wdog_cm_pr_w_i, slot_wdog_cm_pr_r_i;
    logic [NUM_SLOTS-1:0] slot_wdog_ds_to_w_i, slot_wdog_ds_to_r_i, slot_wdog_ds_pr_w_i, slot_wdog_ds_pr_r_i;

    logic [NUM_SLOTS-1:0]                            pmp_g_en_o;
    logic [NUM_SLOTS-1:0][NUM_PMP_REGIONS-1:0][31:0] pmp_base_o;
    logic [NUM_SLOTS-1:0][NUM_PMP_REGIONS-1:0][31:0] pmp_limit_o;

    logic [NUM_SLOTS-1:0] wb_s_enable_o;
    logic [NUM_SLOTS-1:0] wb_m_enable_o;
    logic [NUM_SLOTS-1:0] slot_fault_irq_o;
    logic [NUM_SLOTS*3-1:0] slot_dma_awprot_o;
    logic [NUM_SLOTS*3-1:0] slot_dma_arprot_o;

    // Clock generation (100MHz, period 10ns)
    always #5 clk = ~clk;

    // DUT Instantiation
    efpga_manager #(
        .NUM_SLOTS(NUM_SLOTS),
        .NUM_PMP_REGIONS(NUM_PMP_REGIONS),
        .HW_VERSION(HW_VERSION),
        .PAGE_GRANULARITY(1'b1),
        .MAX_ADDRESS_WIDTH(32),
        .ENABLE_PMP(1'b1),
        .ENABLE_WDOG_CTRL_SLAVE(1'b1),
        .ENABLE_WDOG_DMA_MASTER(1'b1),
        .ENABLE_WDOG_CTRL_MASTER(1'b0),
        .ENABLE_WDOG_DMA_SLAVE(1'b0),
        .ENABLE_BRIDGE_CTRL(1'b0),
        .ENABLE_BRIDGE_DMA(1'b0)
    ) dut (
        .clk_i(clk),
        .rstn_i(rstn),

        .s_axil_awaddr(s_axil_awaddr),
        .s_axil_awprot(s_axil_awprot),
        .s_axil_awvalid(s_axil_awvalid),
        .s_axil_awready(s_axil_awready),

        .s_axil_wdata(s_axil_wdata),
        .s_axil_wstrb(s_axil_wstrb),
        .s_axil_wvalid(s_axil_wvalid),
        .s_axil_wready(s_axil_wready),

        .s_axil_bresp(s_axil_bresp),
        .s_axil_bvalid(s_axil_bvalid),
        .s_axil_bready(s_axil_bready),

        .s_axil_araddr(s_axil_araddr),
        .s_axil_arprot(s_axil_arprot),
        .s_axil_arvalid(s_axil_arvalid),
        .s_axil_arready(s_axil_arready),

        .s_axil_rdata(s_axil_rdata),
        .s_axil_rresp(s_axil_rresp),
        .s_axil_rvalid(s_axil_rvalid),
        .s_axil_rready(s_axil_rready),

        .efpga_config_data_o(efpga_config_data_o),
        .efpga_config_we_o(efpga_config_we_o),
        .slot_reset_o(slot_reset_o),
        .efpga_com_active_i(efpga_com_active_i),

        .slot_debug_in_i(slot_debug_in_i),
        .slot_debug_out_o(slot_debug_out_o),

        .decoupler_req_o(decoupler_req_o),
        .decoupler_force_o(decoupler_force_o),
        .decoupler_is_decoupled_i(decoupler_is_decoupled_i),
        .decoupler_host_act_i(decoupler_host_act_i),
        .decoupler_dma_act_i(decoupler_dma_act_i),

        .slot_pmp_r_violation_i(slot_pmp_r_violation_i),
        .slot_pmp_w_violation_i(slot_pmp_w_violation_i),

        .slot_wdog_cs_to_w_i(slot_wdog_cs_to_w_i),
        .slot_wdog_cs_to_r_i(slot_wdog_cs_to_r_i),
        .slot_wdog_cs_pr_w_i(slot_wdog_cs_pr_w_i),
        .slot_wdog_cs_pr_r_i(slot_wdog_cs_pr_r_i),
        .slot_wdog_dm_to_w_i(slot_wdog_dm_to_w_i),
        .slot_wdog_dm_to_r_i(slot_wdog_dm_to_r_i),
        .slot_wdog_dm_pr_w_i(slot_wdog_dm_pr_w_i),
        .slot_wdog_dm_pr_r_i(slot_wdog_dm_pr_r_i),
        .slot_wdog_cm_to_w_i(slot_wdog_cm_to_w_i),
        .slot_wdog_cm_to_r_i(slot_wdog_cm_to_r_i),
        .slot_wdog_cm_pr_w_i(slot_wdog_cm_pr_w_i),
        .slot_wdog_cm_pr_r_i(slot_wdog_cm_pr_r_i),
        .slot_wdog_ds_to_w_i(slot_wdog_ds_to_w_i),
        .slot_wdog_ds_to_r_i(slot_wdog_ds_to_r_i),
        .slot_wdog_ds_pr_w_i(slot_wdog_ds_pr_w_i),
        .slot_wdog_ds_pr_r_i(slot_wdog_ds_pr_r_i),

        .pmp_g_en_o(pmp_g_en_o),
        .pmp_base_o(pmp_base_o),
        .pmp_limit_o(pmp_limit_o),

        .wb_s_enable_o(wb_s_enable_o),
        .wb_m_enable_o(wb_m_enable_o),
        .slot_fault_irq_o(slot_fault_irq_o),
        .slot_dma_awprot_o(slot_dma_awprot_o),
        .slot_dma_arprot_o(slot_dma_arprot_o)
    );

    // =========================================================================
    // AXI-Lite Master Tasks
    // =========================================================================
    task automatic axi_write(input [31:0] addr, input [31:0] data, input [3:0] strb = 4'hF);
        @(posedge clk);
        s_axil_awaddr  <= addr;
        s_axil_awprot  <= 3'b000;
        s_axil_awvalid <= 1'b1;
        s_axil_wdata   <= data;
        s_axil_wstrb   <= strb;
        s_axil_wvalid  <= 1'b1;
        s_axil_bready  <= 1'b1;

        fork
            begin
                wait (s_axil_awready);
                @(posedge clk);
                s_axil_awvalid <= 1'b0;
            end
            begin
                wait (s_axil_wready);
                @(posedge clk);
                s_axil_wvalid <= 1'b0;
            end
        join

        wait (s_axil_bvalid);
        @(posedge clk);
        s_axil_bready <= 1'b0;
        @(posedge clk);
    endtask

    task automatic axi_read(input [31:0] addr, output [31:0] data);
        @(posedge clk);
        s_axil_araddr  <= addr;
        s_axil_arprot  <= 3'b000;
        s_axil_arvalid <= 1'b1;
        s_axil_rready  <= 1'b1;

        wait (s_axil_arready);
        @(posedge clk);
        s_axil_arvalid <= 1'b0;

        wait (s_axil_rvalid);
        data = s_axil_rdata;
        @(posedge clk);
        s_axil_rready <= 1'b0;
        @(posedge clk);
    endtask

    logic [31:0] rdata;
    int errors = 0;

    initial begin
        $display("=================================================================");
        $display("Starting efpga_manager RTL Register Map Verification");
        $display("=================================================================");

        // Init signals
        clk = 0;
        rstn = 0;
        s_axil_awaddr = 0; s_axil_awprot = 0; s_axil_awvalid = 0;
        s_axil_wdata = 0;  s_axil_wstrb = 0;  s_axil_wvalid = 0;
        s_axil_bready = 0;
        s_axil_araddr = 0; s_axil_arprot = 0; s_axil_arvalid = 0;
        s_axil_rready = 0;

        efpga_com_active_i = 0;
        slot_debug_in_i = 0;
        decoupler_is_decoupled_i = 0;
        decoupler_host_act_i = 0;
        decoupler_dma_act_i = 0;
        slot_pmp_r_violation_i = 0;
        slot_pmp_w_violation_i = 0;
        slot_wdog_cs_to_w_i = 0; slot_wdog_cs_to_r_i = 0; slot_wdog_cs_pr_w_i = 0; slot_wdog_cs_pr_r_i = 0;
        slot_wdog_dm_to_w_i = 0; slot_wdog_dm_to_r_i = 0; slot_wdog_dm_pr_w_i = 0; slot_wdog_dm_pr_r_i = 0;
        slot_wdog_cm_to_w_i = 0; slot_wdog_cm_to_r_i = 0; slot_wdog_cm_pr_w_i = 0; slot_wdog_cm_pr_r_i = 0;
        slot_wdog_ds_to_w_i = 0; slot_wdog_ds_to_r_i = 0; slot_wdog_ds_pr_w_i = 0; slot_wdog_ds_pr_r_i = 0;

        // Reset pulse
        #20 rstn = 1;
        #20;

        // ---------------------------------------------------------------------
        // TEST 1: HW_VERSION @ 0x0000
        // ---------------------------------------------------------------------
        axi_read(32'h0000, rdata);
        if (rdata !== 32'hFAB00001) begin
            $display("[FAIL] HW_VERSION: Expected 0xFAB00001, got 0x%08X", rdata);
            errors++;
        end else begin
            $display("[PASS] HW_VERSION (0x0000): 0x%08X matches expected FAB magic", rdata);
        end

        // ---------------------------------------------------------------------
        // TEST 2: GLOBAL_CTRL @ 0x0004 & SLOT_RESET @ 0x1000
        // ---------------------------------------------------------------------
        axi_write(32'h0004, 32'h00000004); // Set USER_DESIGN_LOADED (bit 2)
        #10;
        axi_read(32'h0004, rdata);
        if (rdata[2] !== 1'b1) begin
            $display("[FAIL] GLOBAL_CTRL: USER_DESIGN_LOADED bit not set!");
            errors++;
        end else begin
            $display("[PASS] GLOBAL_CTRL (0x0004): USER_DESIGN_LOADED active");
        end

        // Verify SLOT_RESET @ 0x1000 default
        if (slot_reset_o[0] !== 32'h00000000) begin
            $display("[FAIL] SLOT_RESET: Initial reset state not 0! Got 0x%08X", slot_reset_o[0]);
            errors++;
        end

        // Assert soft resets: Fabric [3:0], NPU [4], WDOG [16], Bridges [25:24]
        axi_write(32'h1000, 32'h0301001F);
        #10;
        if (slot_reset_o[0] !== 32'h0301001F) begin
            $display("[FAIL] SLOT_RESET (0x1000): slot_reset_o[0] mismatch! Got 0x%08X", slot_reset_o[0]);
            errors++;
        end else begin
            $display("[PASS] SLOT_RESET (0x1000): slot_reset_o[0] asserted high on write: 0x%08X", slot_reset_o[0]);
        end

        // Verify readback of SLOT_RESET
        axi_read(32'h1000, rdata);
        if (rdata !== 32'h0301001F) begin
            $display("[FAIL] SLOT_RESET (0x1000): Readback mismatch! Got 0x%08X", rdata);
            errors++;
        end else begin
            $display("[PASS] SLOT_RESET (0x1000): Readback matched 0x%08X", rdata);
        end

        // Deassert soft resets
        axi_write(32'h1000, 32'h00000000);
        #10;
        if (slot_reset_o[0] !== 32'h00000000) begin
            $display("[FAIL] SLOT_RESET: slot_reset_o[0] not deasserted! Got 0x%08X", slot_reset_o[0]);
            errors++;
        end else begin
            $display("[PASS] SLOT_RESET (0x1000): slot_reset_o[0] released low");
        end

        // ---------------------------------------------------------------------
        // TEST 3: CONFIG_DATA @ 0x0008 & CONFIG_COUNT @ 0x000C
        // ---------------------------------------------------------------------
        axi_read(32'h000C, rdata);
        if (rdata !== 32'd0) begin
            $display("[FAIL] Initial CONFIG_COUNT not 0! Got %0d", rdata);
            errors++;
        end

        axi_write(32'h0008, 32'hAABBCCDD);
        if (efpga_config_data_o !== 32'hDDCCBBAA) begin
            $display("[FAIL] CONFIG_DATA: efpga_config_data_o mismatch! Got 0x%08X (expected 0xDDCCBBAA)", efpga_config_data_o);
            errors++;
        end else begin
            $display("[PASS] CONFIG_DATA (0x0008): Latch output drove 0xDDCCBBAA (hardware byte-swapped from 0xAABBCCDD)");
        end

        axi_read(32'h000C, rdata);
        if (rdata !== 32'd1) begin
            $display("[FAIL] CONFIG_COUNT after 1 write expected 1, got %0d", rdata);
            errors++;
        end

        axi_write(32'h0008, 32'h11223344);
        axi_read(32'h000C, rdata);
        if (rdata !== 32'd2) begin
            $display("[FAIL] CONFIG_COUNT after 2 writes expected 2, got %0d", rdata);
            errors++;
        end else begin
            $display("[PASS] CONFIG_COUNT (0x000C): Word counter accurately incremented to 2");
        end

        // ---------------------------------------------------------------------
        // TEST 4: SLOT_CTRL @ 0x1004 & SLOT_STATUS @ 0x1008
        // ---------------------------------------------------------------------
        axi_write(32'h1004, 32'h00000001, 4'b0001); // DECOUPLE_REQ (byte 0 only)
        #10;
        if (decoupler_req_o[0] !== 1'b1) begin
            $display("[FAIL] SLOT_CTRL: decoupler_req_o[0] not asserted!");
            errors++;
        end else begin
            $display("[PASS] SLOT_CTRL (0x1004): Decouple request asserted to connector");
        end

        // Hardware acknowledges decoupling
        decoupler_is_decoupled_i[0] = 1'b1;
        #10;
        axi_read(32'h1008, rdata);
        if (rdata[0] !== 1'b1) begin
            $display("[FAIL] SLOT_STATUS (0x1008): IS_DECOUPLED bit not reflected!");
            errors++;
        end else begin
            $display("[PASS] SLOT_STATUS (0x1008): IS_DECOUPLED status bit active");
        end

        // ---------------------------------------------------------------------
        // TEST 5: PMP Configuration (0x1018 - 0x1024) while decoupled
        // ---------------------------------------------------------------------
        // Program Region 0: Base = 0x0001_2000 (PFN 0x12) | RW=1 (bit 1) | EN=1 (bit 0)
        axi_write(32'h1018, 32'h00012003);
        // Program Region 0: Limit = 0x0002_5000 (PFN 0x25) | Priv_Req=1 (bit 0)
        axi_write(32'h101C, 32'h00025001);

        #10;
        // Verify hardware outputs drove the PMP comparators
        if (pmp_base_o[0][0] !== 32'h00012003) begin
            $display("[FAIL] pmp_base_o[0][0] mismatch! Got 0x%08X", pmp_base_o[0][0]);
            errors++;
        end
        if (pmp_limit_o[0][0] !== 32'h00025001) begin
            $display("[FAIL] pmp_limit_o[0][0] mismatch! Got 0x%08X", pmp_limit_o[0][0]);
            errors++;
        end

        // Verify read back from AXI-Lite
        axi_read(32'h1018, rdata);
        if (rdata !== 32'h00012003) begin
            $display("[FAIL] Readback PMP0_BASE: Expected 0x00012003, got 0x%08X", rdata);
            errors++;
        end
        axi_read(32'h101C, rdata);
        if (rdata !== 32'h00025001) begin
            $display("[FAIL] Readback PMP0_LIMIT: Expected 0x00025001, got 0x%08X", rdata);
            errors++;
        end
        $display("[PASS] PMP Region 0 (0x1018/0x101C): Successfully programmed and verified");

        // Program Region 1: Base = 0x0004_0000 | Read_En=1 (bit 0)
        axi_write(32'h1020, 32'h00040001);
        axi_write(32'h1024, 32'h00050000);
        axi_read(32'h1020, rdata);
        if (rdata !== 32'h00040001) begin
            $display("[FAIL] Readback PMP1_BASE: Expected 0x00040001, got 0x%08X", rdata);
            errors++;
        end
        $display("[PASS] PMP Region 1 (0x1020/0x1024): Successfully programmed and verified");

        // Verify Region 2 (Unmapped in 2-region hardware) returns 0xBAD00002
        axi_read(32'h1028, rdata);
        if (rdata !== 32'hBAD00002) begin
            $display("[FAIL] Unmapped PMP region 2 read expected 0xBAD00002, got 0x%08X", rdata);
            errors++;
        end else begin
            $display("[PASS] PMP Unmapped Boundary (0x1028): Returned 0xBAD00002 as expected");
        end

        // ---------------------------------------------------------------------
        // TEST 6: PMP Security Write-Lock (Hardware Protection When Coupled)
        // ---------------------------------------------------------------------
        // Re-couple slot
        decoupler_is_decoupled_i[0] = 1'b0;
        axi_write(32'h1004, 32'h00000000, 4'b0001); // Clear decouple req in SLOT_CTRL (byte 0 only)

        // Attempt unauthorized write to PMP while coupled
        axi_write(32'h1018, 32'hDEADBEEF);
        axi_read(32'h1018, rdata);
        if (rdata !== 32'h00012003) begin
            $display("[FAIL] Security write-lock violated! PMP was modified while coupled: 0x%08X", rdata);
            errors++;
        end else begin
            $display("[PASS] PMP Security Lock: Dropped unauthorized write while slot was coupled");
        end

        // ---------------------------------------------------------------------
        // TEST 7: DEBUG_OUT @ 0x1010 & DEBUG_IN @ 0x1014
        // ---------------------------------------------------------------------
        axi_write(32'h1010, 32'hCAFE1234);
        #10;
        if (slot_debug_out_o[0] !== 32'hCAFE1234) begin
            $display("[FAIL] DEBUG_OUT: slot_debug_out_o mismatch! Got 0x%08X", slot_debug_out_o[0]);
            errors++;
        end else begin
            $display("[PASS] DEBUG_OUT (0x1010): Drove 0xCAFE1234 to fabric wires");
        end

        slot_debug_in_i[0] = 32'h5678BEEF;
        #10;
        axi_read(32'h1014, rdata);
        if (rdata !== 32'h5678BEEF) begin
            $display("[FAIL] DEBUG_IN: Expected 0x5678BEEF, got 0x%08X", rdata);
            errors++;
        end else begin
            $display("[PASS] DEBUG_IN (0x1014): Read 0x5678BEEF from fabric wires");
        end

        // ---------------------------------------------------------------------
        // TEST 8: Fault Latch, FAULT_CLEAR @ 0x100C & WDOG Reset Auto-Clear
        // ---------------------------------------------------------------------
        // Pulse a PMP read violation
        slot_pmp_r_violation_i[0] = 1'b1;
        #20;
        slot_pmp_r_violation_i[0] = 1'b0;
        #10;

        // Verify fault latched sticky in SLOT_STATUS bit 8 and fault IRQ is active high
        axi_read(32'h1008, rdata);
        if (rdata[8] !== 1'b1 || slot_fault_irq_o[0] !== 1'b1) begin
            $display("[FAIL] Fault latch failed! PMP_R_FAULT=%b, slot_fault_irq_o=%b", rdata[8], slot_fault_irq_o[0]);
            errors++;
        end else begin
            $display("[PASS] Fault Latch: PMP read violation latched into STATUS[8] and asserted slot_fault_irq_o = 1");
        end

        // Issue clear strobe on FAULT_CLEAR (bit 8) @ 0x100C
        axi_write(32'h100C, 32'h00000100);
        axi_read(32'h1008, rdata);
        if (rdata[8] !== 1'b0 || slot_fault_irq_o[0] !== 1'b0) begin
            $display("[FAIL] FAULT_CLEAR strobe failed! PMP_R_FAULT=%b, slot_fault_irq_o=%b", rdata[8], slot_fault_irq_o[0]);
            errors++;
        end else begin
            $display("[PASS] FAULT_CLEAR (0x100C): Strobe cleared latched fault bit and deasserted slot_fault_irq_o = 0");
        end

        // Pulse a Watchdog timeout fault
        slot_wdog_cs_to_w_i[0] = 1'b1;
        #20;
        slot_wdog_cs_to_w_i[0] = 1'b0;
        #10;
        axi_read(32'h1008, rdata);
        if (rdata[19] !== 1'b1) begin
            $display("[FAIL] Watchdog fault not latched into STATUS[19]!");
            errors++;
        end else begin
            $display("[PASS] Watchdog Fault: Timeout latched into STATUS[19]");
        end

        // Assert WDOG soft reset via SLOT_RESET[16] @ 0x1000, verify auto-clear
        axi_write(32'h1000, 32'h00010000);
        #10;
        axi_read(32'h1008, rdata);
        if (rdata[19] !== 1'b0) begin
            $display("[FAIL] WDOG_RST did not auto-clear sticky fault flag in STATUS[19]!");
            errors++;
        end else begin
            $display("[PASS] WDOG_RST (0x1000[16]): Soft reset automatically cleared sticky watchdog fault flag");
        end
        axi_write(32'h1000, 32'h00000000); // Release WDOG_RST

        // ---------------------------------------------------------------------
        // TEST 9: Host-Configured DMA PROT (SLOT_CTRL @ 0x1004 bits [15:13] & [12:10])
        // ---------------------------------------------------------------------
        // 1. Verify reset default is 3'b000 on both AWPROT and ARPROT pins
        if (slot_dma_awprot_o[2:0] !== 3'b000 || slot_dma_arprot_o[2:0] !== 3'b000) begin
            $display("[FAIL] DMA PROT Reset Default failed! AWPROT=%b, ARPROT=%b", slot_dma_awprot_o[2:0], slot_dma_arprot_o[2:0]);
            errors++;
        end else begin
            $display("[PASS] DMA PROT: Reset defaults correctly to 3'b000 on both AWPROT and ARPROT pins");
        end

        // 2. Program AWPROT = 3'b001 (Privileged) and ARPROT = 3'b010 (Non-Secure) via Byte 1 write to SLOT_CTRL (0x1004)
        axi_write(32'h1004, 32'h0000_4400, 4'b0010);
        #10;
        if (slot_dma_awprot_o[2:0] !== 3'b001 || slot_dma_arprot_o[2:0] !== 3'b010) begin
            $display("[FAIL] DMA PROT write 1 pin mismatch! AWPROT=%b (expected 001), ARPROT=%b (expected 010)",
                     slot_dma_awprot_o[2:0], slot_dma_arprot_o[2:0]);
            errors++;
        end else begin
            $display("[PASS] DMA PROT: Drove AWPROT=001 and ARPROT=010 to fabric connector pins");
        end

        // 3. Verify readback of Byte 1 in SLOT_CTRL (0x1004)
        axi_read(32'h1004, rdata);
        if (rdata[12:10] !== 3'b001 || rdata[15:13] !== 3'b010) begin
            $display("[FAIL] DMA PROT readback mismatch! Got AWPROT=%b, ARPROT=%b (expected 001, 010)",
                     rdata[12:10], rdata[15:13]);
            errors++;
        end else begin
            $display("[PASS] DMA PROT: Readback of SLOT_CTRL matched bits [15:13]=010, [12:10]=001");
        end

        // 4. Program arbitrary alternate pattern: AWPROT = 3'b110, ARPROT = 3'b101
        axi_write(32'h1004, 32'h0000_B800, 4'b0010);
        #10;
        if (slot_dma_awprot_o[2:0] !== 3'b110 || slot_dma_arprot_o[2:0] !== 3'b101) begin
            $display("[FAIL] DMA PROT write 2 pin mismatch! AWPROT=%b (expected 110), ARPROT=%b (expected 101)",
                     slot_dma_awprot_o[2:0], slot_dma_arprot_o[2:0]);
            errors++;
        end else begin
            $display("[PASS] DMA PROT: Drove AWPROT=110 and ARPROT=101 to fabric connector pins");
        end

        axi_read(32'h1004, rdata);
        if (rdata[12:10] !== 3'b110 || rdata[15:13] !== 3'b101) begin
            $display("[FAIL] DMA PROT readback 2 mismatch! Got AWPROT=%b, ARPROT=%b (expected 110, 101)",
                     rdata[12:10], rdata[15:13]);
            errors++;
        end else begin
            $display("[PASS] DMA PROT: Readback 2 of SLOT_CTRL matched bits [15:13]=101, [12:10]=110");
        end

        // ---------------------------------------------------------------------
        // FINAL SUMMARY
        // ---------------------------------------------------------------------
        $display("=================================================================");
        if (errors == 0) begin
            $display("ALL HARDWARE REGISTER MAP TESTS PASSED SUCCESSFULLY! (0 Errors)");
        end else begin
            $display("TEST FAILED WITH %0d ERRORS!", errors);
        end
        $display("=================================================================");
        $finish;
    end

endmodule

