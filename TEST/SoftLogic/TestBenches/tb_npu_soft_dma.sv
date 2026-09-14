`timescale 1ns / 1ps

/* ===============================================================================================
 * tb_npu_soft_dma.sv
 *
 * Standalone Unit Testbench for npu_soft_dma (AXI4 Master Burst DMA Engine)
 * =============================================================================================== */

module tb_npu_soft_dma;

    logic clk;
    logic rst_n;

    // AXI4 Master Interface
    wire [31:0] m_axi_awaddr;
    wire [7:0]  m_axi_awlen;
    wire [2:0]  m_axi_awsize;
    wire [1:0]  m_axi_awburst;
    wire        m_axi_awvalid;
    wire        m_axi_awready;

    wire [31:0] m_axi_wdata;
    wire [3:0]  m_axi_wstrb;
    wire        m_axi_wlast;
    wire        m_axi_wvalid;
    wire        m_axi_wready;

    wire [1:0]  m_axi_bresp;
    wire        m_axi_bvalid;
    wire        m_axi_bready;

    wire [31:0] m_axi_araddr;
    wire [7:0]  m_axi_arlen;
    wire [2:0]  m_axi_arsize;
    wire [1:0]  m_axi_arburst;
    wire        m_axi_arvalid;
    wire        m_axi_arready;

    wire [31:0] m_axi_rdata;
    wire [1:0]  m_axi_rresp;
    wire        m_axi_rlast;
    wire        m_axi_rvalid;
    wire        m_axi_rready;

    // DMA Control & Status
    logic [31:0] act_base;
    logic [31:0] weight_base;
    logic [31:0] out_base;

    logic        start_act;
    wire         act_done;

    logic        start_weight;
    logic [3:0]  weight_pass_idx;
    wire         weight_done;
    wire signed [7:0][7:0] weight_shift_in;
    wire [1:0]             weight_shift_en;

    logic        start_drain;
    wire         drain_done;
    wire  [7:0]  drain_psum_addr;
    logic signed [7:0][7:0] npu_out_act;

    wire  [7:0]  ext_act_sram_we;
    wire  [7:0][8:0] ext_act_sram_addr;
    wire signed [7:0][7:0] ext_act_sram_wdata;

    // Clock generator: 100MHz (10ns)
    initial clk = 0;
    always #5 clk = ~clk;

    // AXI RAM Instance
    localparam int MEM_ADDR_WIDTH = 16;
    axi_ram #(
        .DATA_WIDTH     (32),
        .ADDR_WIDTH     (MEM_ADDR_WIDTH),
        .ID_WIDTH       (1),
        .PIPELINE_OUTPUT(0)
    ) axi_ram_inst (
        .clk            (clk),
        .rst            (~rst_n),
        .s_axi_awid     (1'b0),
        .s_axi_awaddr   (m_axi_awaddr[MEM_ADDR_WIDTH-1:0]),
        .s_axi_awlen    (m_axi_awlen),
        .s_axi_awsize   (m_axi_awsize),
        .s_axi_awburst  (m_axi_awburst),
        .s_axi_awlock   (1'b0),
        .s_axi_awcache  (4'b0011),
        .s_axi_awprot   (3'b000),
        .s_axi_awvalid  (m_axi_awvalid),
        .s_axi_awready  (m_axi_awready),
        .s_axi_wdata    (m_axi_wdata),
        .s_axi_wstrb    (m_axi_wstrb),
        .s_axi_wlast    (m_axi_wlast),
        .s_axi_wvalid   (m_axi_wvalid),
        .s_axi_wready   (m_axi_wready),
        .s_axi_bid      (),
        .s_axi_bresp    (m_axi_bresp),
        .s_axi_bvalid   (m_axi_bvalid),
        .s_axi_bready   (m_axi_bready),
        .s_axi_arid     (1'b0),
        .s_axi_araddr   (m_axi_araddr[MEM_ADDR_WIDTH-1:0]),
        .s_axi_arlen    (m_axi_arlen),
        .s_axi_arsize   (m_axi_arsize),
        .s_axi_arburst  (m_axi_arburst),
        .s_axi_arlock   (1'b0),
        .s_axi_arcache  (4'b0011),
        .s_axi_arprot   (3'b000),
        .s_axi_arvalid  (m_axi_arvalid),
        .s_axi_arready  (m_axi_arready),
        .s_axi_rid      (),
        .s_axi_rdata    (m_axi_rdata),
        .s_axi_rresp    (m_axi_rresp),
        .s_axi_rlast    (m_axi_rlast),
        .s_axi_rvalid   (m_axi_rvalid),
        .s_axi_rready   (m_axi_rready)
    );

    // DUT Instance
    npu_soft_dma #(
        .ARRAY_HEIGHT    (8),
        .ARRAY_WIDTH     (8),
        .TILE_SIZE       (16),
        .ACT_HALO_PAD    (2),
        .ACTIVATION_WIDTH(8),
        .WEIGHT_WIDTH    (8),
        .AXI_ADDR_WIDTH  (32),
        .AXI_DATA_WIDTH  (32)
    ) dut (
        .clk_i               (clk),
        .rst_n               (rst_n),
        .m_axi_awaddr        (m_axi_awaddr),
        .m_axi_awlen         (m_axi_awlen),
        .m_axi_awsize        (m_axi_awsize),
        .m_axi_awburst       (m_axi_awburst),
        .m_axi_awvalid       (m_axi_awvalid),
        .m_axi_awready       (m_axi_awready),
        .m_axi_wdata         (m_axi_wdata),
        .m_axi_wstrb         (m_axi_wstrb),
        .m_axi_wlast         (m_axi_wlast),
        .m_axi_wvalid        (m_axi_wvalid),
        .m_axi_wready        (m_axi_wready),
        .m_axi_bresp         (m_axi_bresp),
        .m_axi_bvalid        (m_axi_bvalid),
        .m_axi_bready        (m_axi_bready),
        .m_axi_araddr        (m_axi_araddr),
        .m_axi_arlen         (m_axi_arlen),
        .m_axi_arsize        (m_axi_arsize),
        .m_axi_arburst       (m_axi_arburst),
        .m_axi_arvalid       (m_axi_arvalid),
        .m_axi_arready       (m_axi_arready),
        .m_axi_rdata         (m_axi_rdata),
        .m_axi_rresp         (m_axi_rresp),
        .m_axi_rlast         (m_axi_rlast),
        .m_axi_rvalid        (m_axi_rvalid),
        .m_axi_rready        (m_axi_rready),
        .act_base_i          (act_base),
        .weight_base_i       (weight_base),
        .out_base_i          (out_base),
        .start_act_i         (start_act),
        .act_done_o          (act_done),
        .start_weight_i      (start_weight),
        .weight_pass_idx_i   (weight_pass_idx),
        .weight_done_o       (weight_done),
        .weight_shift_in_o   (weight_shift_in),
        .weight_shift_en_o   (weight_shift_en),
        .start_drain_i       (start_drain),
        .drain_done_o        (drain_done),
        .drain_psum_addr_o   (drain_psum_addr),
        .npu_out_act_i       (npu_out_act),
        .ext_act_sram_we_o   (ext_act_sram_we),
        .ext_act_sram_addr_o (ext_act_sram_addr),
        .ext_act_sram_wdata_o(ext_act_sram_wdata)
    );

    // Mock NPU Requantizer Pipeline (2-cycle latency model for drain test)
    logic [7:0] drain_addr_d1, drain_addr_d2;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            drain_addr_d1 <= '0;
            drain_addr_d2 <= '0;
            npu_out_act   <= '0;
        end else begin
            drain_addr_d1 <= drain_psum_addr;
            drain_addr_d2 <= drain_addr_d1;
            for (int c = 0; c < 8; c++) begin
                npu_out_act[c] <= $signed(8'(drain_addr_d2 * 8 + c));
            end
        end
    end

    // Direct RAM write helper
    task automatic ram_write_byte(input int addr, input logic [7:0] val);
        int word_addr = addr >> 2;
        int byte_lane = addr & 2'd3;
        case (byte_lane)
            2'd0: axi_ram_inst.mem[word_addr][7:0]   = val;
            2'd1: axi_ram_inst.mem[word_addr][15:8]  = val;
            2'd2: axi_ram_inst.mem[word_addr][23:16] = val;
            2'd3: axi_ram_inst.mem[word_addr][31:24] = val;
        endcase
    endtask

    task automatic ram_read_byte(input int addr, output logic [7:0] val);
        int word_addr;
        int byte_lane;
        word_addr = addr >> 2;
        byte_lane = addr & 2'd3;
        case (byte_lane)
            2'd0: val = axi_ram_inst.mem[word_addr][7:0];
            2'd1: val = axi_ram_inst.mem[word_addr][15:8];
            2'd2: val = axi_ram_inst.mem[word_addr][23:16];
            2'd3: val = axi_ram_inst.mem[word_addr][31:24];
        endcase
    endtask

    // Simulated Activation SRAM storage to verify DMA writes
    logic signed [7:0] mock_sram [8][512];
    always_ff @(posedge clk) begin
        for (int b = 0; b < 8; b++) begin
            if (ext_act_sram_we[b]) begin
                mock_sram[b][ext_act_sram_addr[b]] <= ext_act_sram_wdata[b];
            end
        end
    end

    // Mock Systolic Array Shadow Registers to verify DMA direct streaming
    logic signed [7:0] mock_pe_shadow [8][8];
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int r_idx = 0; r_idx < 8; r_idx++) begin
                for (int c_idx = 0; c_idx < 8; c_idx++) begin
                    mock_pe_shadow[r_idx][c_idx] <= '0;
                end
            end
        end else begin
            for (int r_idx = 0; r_idx < 8; r_idx++) begin
                if (r_idx < 4 ? weight_shift_en[0] : weight_shift_en[1]) begin
                    mock_pe_shadow[r_idx][0] <= weight_shift_in[r_idx];
                    for (int c_idx = 1; c_idx < 8; c_idx++) begin
                        mock_pe_shadow[r_idx][c_idx] <= mock_pe_shadow[r_idx][c_idx-1];
                    end
                end
            end
        end
    end

    int errors = 0;

    initial begin
        int i, p, ch, r, c;
        logic signed [7:0] expected_w;
        logic signed [7:0] expected_act;
        logic [7:0] expected_out;
        logic [7:0] actual_out;

        $display("\n==========================================================");
        $display(">>> Starting Unit Test: npu_soft_dma (AXI4 Burst DMA) <<<");
        $display("==========================================================");

        // Reset
        rst_n           = 0;
        act_base        = 32'h0000_1000;
        weight_base     = 32'h0000_2000;
        out_base        = 32'h0000_3000;
        start_act       = 0;
        start_weight    = 0;
        weight_pass_idx = 0;
        start_drain     = 0;

        #30;
        @(negedge clk);
        rst_n = 1;
        #30;

        // -------------------------------------------------------------
        // Test 1: Weight Fetch Burst Transfer
        // -------------------------------------------------------------
        $display("[Test 1] Testing Weight Fetch (16-beat INCR burst direct streaming)...");
        for (int s = 0; s < 8; s++) begin
            for (int r_idx = 0; r_idx < 8; r_idx++) begin
                ram_write_byte(weight_base + (s * 8) + r_idx, 8'((r_idx * 8 + (7 - s)) + 10));
            end
        end

        @(posedge clk);
        start_weight    <= 1'b1;
        weight_pass_idx <= 4'd0;
        @(posedge clk);
        start_weight    <= 1'b0;

        while (!weight_done) @(posedge clk);
        $display("   Weight DMA completed. Verifying shadow registers...");

        for (r = 0; r < 8; r++) begin
            for (c = 0; c < 8; c++) begin
                expected_w = $signed(8'((r * 8 + c) + 10));
                if (mock_pe_shadow[r][c] !== expected_w) begin
                    $display("   [ERROR] mock_pe_shadow[%0d][%0d] expected %0d, got %0d",
                             r, c, expected_w, mock_pe_shadow[r][c]);
                    errors++;
                end
            end
        end

        // -------------------------------------------------------------
        // Test 2: Activation Fetch (648 words, multiple 16-beat bursts)
        // -------------------------------------------------------------
        $display("[Test 2] Testing Activation Fetch (648 words across 41 bursts)...");
        for (p = 0; p < 324; p++) begin
            for (ch = 0; ch < 8; ch++) begin
                ram_write_byte(act_base + (p * 8) + ch, 8'((p * 7 + ch * 3) % 256));
            end
        end

        @(posedge clk);
        start_act <= 1'b1;
        @(posedge clk);
        start_act <= 1'b0;

        while (!act_done) @(posedge clk);
        $display("   Activation DMA completed. Verifying SRAM write integrity...");

        for (p = 0; p < 324; p++) begin
            for (ch = 0; ch < 8; ch++) begin
                expected_act = $signed(8'((p * 7 + ch * 3) % 256));
                if (mock_sram[ch][p] !== expected_act) begin
                    $display("   [ERROR] mock_sram[%0d][%0d] expected %0d, got %0d",
                             ch, p, expected_act, mock_sram[ch][p]);
                    errors++;
                end
            end
        end

        // -------------------------------------------------------------
        // Test 3: Output Drain Burst Store (32 bursts x 16 beats = 512 words)
        // -------------------------------------------------------------
        $display("[Test 3] Testing Output Drain Store (32 bursts x 16 beats)...");
        @(posedge clk);
        start_drain <= 1'b1;
        @(posedge clk);
        start_drain <= 1'b0;

        while (!drain_done) @(posedge clk);
        $display("   Drain DMA completed. Verifying AXI RAM output tensor...");

        for (p = 0; p < 256; p++) begin
            for (ch = 0; ch < 8; ch++) begin
                expected_out = 8'(p * 8 + ch);
                ram_read_byte(out_base + (p * 8) + ch, actual_out);
                if (actual_out !== expected_out) begin
                    $display("   [ERROR] out_ram pixel %0d ch %0d expected 0x%02X, got 0x%02X",
                             p, ch, expected_out, actual_out);
                    errors++;
                end
            end
        end

        $display("----------------------------------------------------------");
        if (errors == 0) begin
            $display(">>> SUCCESS: npu_soft_dma Unit Test Passed 100%%! <<<");
        end else begin
            $display(">>> FAILURE: %0d Errors Detected in npu_soft_dma! <<<", errors);
        end
        $display("==========================================================\n");

        #50;
        $finish;
    end

endmodule
