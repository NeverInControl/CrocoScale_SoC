`timescale 1ns / 1ps

/* ===============================================================================================
 * tb_npu_soft_controller.sv
 *
 * Standalone Verification Testbench for eFPGA NPU Soft-Logic Controller
 *
 * Verification Topology:
 * Testbench (CPU Model) -> AXI-Lite -> Soft-Logic Controller -> npu_wrapper (NPU Complex)
 *                                            |
 *                                           AXI4
 *                                            |
 *                                         axi_ram
 *
 * Loads golden reference data directly from:
 *   TEST/NPU/GoldenReference/gen_conv3x3_halo_act.mem
 *   TEST/NPU/GoldenReference/gen_conv3x3_halo_w.mem
 * Tests bias preloading into Address 0, 9-pass systolic execution, and automated draining.
 * =============================================================================================== */

module tb_npu_soft_controller;

    // Clock and Reset
    logic clk;
    logic rst_n;

    // AXI-Lite Slave Interface (CPU -> Soft Controller)
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

    // AXI4 Master Interface (Soft Controller -> AXI RAM)
    wire  [31:0] m_axi_awaddr;
    wire  [7:0]  m_axi_awlen;
    wire  [2:0]  m_axi_awsize;
    wire  [1:0]  m_axi_awburst;
    wire         m_axi_awvalid;
    wire         m_axi_awready;

    wire  [31:0] m_axi_wdata;
    wire  [3:0]  m_axi_wstrb;
    wire         m_axi_wlast;
    wire         m_axi_wvalid;
    wire         m_axi_wready;

    wire  [1:0]  m_axi_bresp;
    wire         m_axi_bvalid;
    wire         m_axi_bready;

    wire  [31:0] m_axi_araddr;
    wire  [7:0]  m_axi_arlen;
    wire  [2:0]  m_axi_arsize;
    wire  [1:0]  m_axi_arburst;
    wire         m_axi_arvalid;
    wire         m_axi_arready;

    wire  [31:0] m_axi_rdata;
    wire  [1:0]  m_axi_rresp;
    wire         m_axi_rlast;
    wire         m_axi_rvalid;
    wire         m_axi_rready;

    // NPU Dedicated Interface Wires
    wire         npu_array_en;
    wire         npu_psum_systolic_en;
    wire         npu_psum_lut_en;
    wire         npu_psum_skew_en;
    wire         npu_compute_bank_swap;
    wire  [7:0][3:0] npu_crossbar_sel;

    wire signed [7:0][7:0] npu_weight_shift_in;
    wire  [1:0]  npu_weight_shift_en;
    wire         npu_swap_weights;

    wire  [29:0] npu_quant_shift_in;
    wire         npu_quant_shift_en;
    wire         npu_stochastic_round_en;
    wire  [15:0] npu_lfsr_data_out;

    wire  [7:0]  npu_psum_A_addr;
    wire  [7:0]  npu_psum_A_we;
    wire signed [31:0] npu_psum_A_wdata;
    wire  [2:0]  npu_psum_A_read_bank_sel;
    wire signed [31:0] npu_psum_A_rdata;

    wire  [7:0]  npu_psum_B_addr;
    wire  [7:0]  npu_psum_B_we;
    wire signed [31:0] npu_psum_B_wdata;
    wire  [2:0]  npu_psum_B_read_bank_sel;
    wire signed [31:0] npu_psum_B_rdata;

    wire  [7:0]  npu_ext_act_sram_we;
    wire  [7:0][8:0] npu_ext_act_sram_addr;
    wire signed [7:0][7:0] npu_ext_act_sram_wdata;
    wire signed [7:0][7:0] npu_act_sram_rdata;

    wire signed [7:0][7:0] npu_out_act;
    wire  [3:0]  efpga_usr_irq_o;

    // Clock Generation: 100 MHz (10ns period)
    initial clk = 0;
    always #5 clk = ~clk;

    // =========================================================================
    // 1. AXI RAM Instance (Alex Forencich AXI4 Model)
    // =========================================================================
    localparam int MEM_ADDR_WIDTH = 16; // 64 KB
    localparam [31:0] ACT_BASE_ADDR    = 32'h0000_1000;
    localparam [31:0] WEIGHT_BASE_ADDR = 32'h0000_2000;
    localparam [31:0] OUT_BASE_ADDR    = 32'h0000_3000;
    localparam [31:0] BIAS_BASE_ADDR   = 32'h0000_4000;

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

    // =========================================================================
    // 2. NPU Complex Instance (npu_wrapper)
    // =========================================================================
    npu_wrapper #(
        .ARRAY_HEIGHT    (8),
        .ARRAY_WIDTH     (8),
        .TILE_SIZE       (16),
        .ACTIVATION_WIDTH(8),
        .WEIGHT_WIDTH    (8),
        .PSUM_WIDTH      (32),
        .SCALE_WIDTH     (16),
        .WEIGHT_SPLIT    (2)
    ) npu_wrapper_inst (
        .clk_i              (clk),
        .rst_n              (rst_n),

        .array_en           (npu_array_en),
        .psum_systolic_en   (npu_psum_systolic_en),
        .psum_lut_en        (npu_psum_lut_en),
        .crossbar_sel       (npu_crossbar_sel),

        .weight_shift_in    (npu_weight_shift_in),
        .weight_shift_en    (npu_weight_shift_en),
        .swap_weights       (npu_swap_weights),

        .quant_shift_in     (npu_quant_shift_in),
        .quant_shift_en     (npu_quant_shift_en),
        .stochastic_round_en(npu_stochastic_round_en),
        .lfsr_data_out      (npu_lfsr_data_out),

        .psum_skew_en       (npu_psum_skew_en),
        .compute_bank_swap  (npu_compute_bank_swap),

        .psum_A_addr        (npu_psum_A_addr),
        .psum_A_we          (npu_psum_A_we),
        .psum_A_wdata       (npu_psum_A_wdata),
        .psum_A_read_bank_sel(npu_psum_A_read_bank_sel),
        .psum_A_rdata       (npu_psum_A_rdata),

        .psum_B_addr        (npu_psum_B_addr),
        .psum_B_we          (npu_psum_B_we),
        .psum_B_wdata       (npu_psum_B_wdata),
        .psum_B_read_bank_sel(npu_psum_B_read_bank_sel),
        .psum_B_rdata       (npu_psum_B_rdata),

        .ext_act_sram_we    (npu_ext_act_sram_we),
        .ext_act_sram_addr  (npu_ext_act_sram_addr),
        .ext_act_sram_wdata (npu_ext_act_sram_wdata),
        .act_sram_rdata     (npu_act_sram_rdata),

        .out_act            (npu_out_act)
    );

    // =========================================================================
    // 3. eFPGA NPU Soft-Logic Controller Instance (DUT)
    // =========================================================================
    npu_soft_controller #(
        .ARRAY_HEIGHT    (8),
        .ARRAY_WIDTH     (8),
        .TILE_SIZE       (16),
        .ACTIVATION_WIDTH(8),
        .WEIGHT_WIDTH    (8),
        .PSUM_WIDTH      (32),
        .SCALE_WIDTH     (16),
        .WEIGHT_SPLIT    (2),
        .AXI_ADDR_WIDTH  (32),
        .AXI_DATA_WIDTH  (32)
    ) dut_inst (
        .clk_i              (clk),
        .rst_n              (rst_n),

        // AXI-Lite Slave
        .s_axil_awaddr      (s_axil_awaddr),
        .s_axil_awprot      (s_axil_awprot),
        .s_axil_awvalid     (s_axil_awvalid),
        .s_axil_awready     (s_axil_awready),
        .s_axil_wdata       (s_axil_wdata),
        .s_axil_wstrb       (s_axil_wstrb),
        .s_axil_wvalid      (s_axil_wvalid),
        .s_axil_wready      (s_axil_wready),
        .s_axil_bresp       (s_axil_bresp),
        .s_axil_bvalid      (s_axil_bvalid),
        .s_axil_bready      (s_axil_bready),
        .s_axil_araddr      (s_axil_araddr),
        .s_axil_arprot      (s_axil_arprot),
        .s_axil_arvalid     (s_axil_arvalid),
        .s_axil_arready     (s_axil_arready),
        .s_axil_rdata       (s_axil_rdata),
        .s_axil_rresp       (s_axil_rresp),
        .s_axil_rvalid      (s_axil_rvalid),
        .s_axil_rready      (s_axil_rready),

        // AXI4 Master
        .m_axi_awaddr       (m_axi_awaddr),
        .m_axi_awlen        (m_axi_awlen),
        .m_axi_awsize       (m_axi_awsize),
        .m_axi_awburst      (m_axi_awburst),
        .m_axi_awvalid      (m_axi_awvalid),
        .m_axi_awready      (m_axi_awready),
        .m_axi_wdata        (m_axi_wdata),
        .m_axi_wstrb        (m_axi_wstrb),
        .m_axi_wlast        (m_axi_wlast),
        .m_axi_wvalid       (m_axi_wvalid),
        .m_axi_wready       (m_axi_wready),
        .m_axi_bresp        (m_axi_bresp),
        .m_axi_bvalid       (m_axi_bvalid),
        .m_axi_bready       (m_axi_bready),
        .m_axi_araddr       (m_axi_araddr),
        .m_axi_arlen        (m_axi_arlen),
        .m_axi_arsize       (m_axi_arsize),
        .m_axi_arburst      (m_axi_arburst),
        .m_axi_arvalid      (m_axi_arvalid),
        .m_axi_arready      (m_axi_arready),
        .m_axi_rdata        (m_axi_rdata),
        .m_axi_rresp        (m_axi_rresp),
        .m_axi_rlast        (m_axi_rlast),
        .m_axi_rvalid       (m_axi_rvalid),
        .m_axi_rready       (m_axi_rready),

        // NPU Dedicated Interfaces
        .npu_array_en           (npu_array_en),
        .npu_psum_systolic_en   (npu_psum_systolic_en),
        .npu_psum_lut_en        (npu_psum_lut_en),
        .npu_psum_skew_en       (npu_psum_skew_en),
        .npu_compute_bank_swap  (npu_compute_bank_swap),
        .npu_crossbar_sel       (npu_crossbar_sel),

        .npu_weight_shift_in    (npu_weight_shift_in),
        .npu_weight_shift_en    (npu_weight_shift_en),
        .npu_swap_weights       (npu_swap_weights),

        .npu_quant_shift_in     (npu_quant_shift_in),
        .npu_quant_shift_en     (npu_quant_shift_en),
        .npu_stochastic_round_en(npu_stochastic_round_en),

        .npu_psum_A_addr        (npu_psum_A_addr),
        .npu_psum_A_we          (npu_psum_A_we),
        .npu_psum_A_wdata       (npu_psum_A_wdata),
        .npu_psum_A_read_bank_sel(npu_psum_A_read_bank_sel),
        .npu_psum_A_rdata       (npu_psum_A_rdata),

        .npu_psum_B_addr        (npu_psum_B_addr),
        .npu_psum_B_we          (npu_psum_B_we),
        .npu_psum_B_wdata       (npu_psum_B_wdata),
        .npu_psum_B_read_bank_sel(npu_psum_B_read_bank_sel),
        .npu_psum_B_rdata       (npu_psum_B_rdata),

        .npu_ext_act_sram_we    (npu_ext_act_sram_we),
        .npu_ext_act_sram_addr  (npu_ext_act_sram_addr),
        .npu_ext_act_sram_wdata (npu_ext_act_sram_wdata),
        .npu_act_sram_rdata     (npu_act_sram_rdata),

        .npu_out_act            (npu_out_act),
        .efpga_usr_irq_o        (efpga_usr_irq_o)
    );

    // =========================================================================
    // AXI-Lite Master Helper Tasks
    // =========================================================================
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
        #1;
        s_axil_bready = 1'b0;
        @(posedge clk);
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

    // Direct AXI RAM byte-level access task
    task automatic ram_write_byte(input int addr, input logic signed [7:0] val);
        int word_addr = addr >> 2;
        int byte_lane = addr & 2'd3;
        case (byte_lane)
            2'd0: axi_ram_inst.mem[word_addr][7:0]   = val;
            2'd1: axi_ram_inst.mem[word_addr][15:8]  = val;
            2'd2: axi_ram_inst.mem[word_addr][23:16] = val;
            2'd3: axi_ram_inst.mem[word_addr][31:24] = val;
        endcase
    endtask

    task automatic ram_write_word(input int addr, input logic [31:0] val);
        int word_addr = addr >> 2;
        axi_ram_inst.mem[word_addr] = val;
    endtask

    task automatic ram_read_byte(input int addr, output logic signed [7:0] val);
        int word_addr = addr >> 2;
        int byte_lane = addr & 2'd3;
        case (byte_lane)
            2'd0: val = $signed(axi_ram_inst.mem[word_addr][7:0]);
            2'd1: val = $signed(axi_ram_inst.mem[word_addr][15:8]);
            2'd2: val = $signed(axi_ram_inst.mem[word_addr][23:16]);
            2'd3: val = $signed(axi_ram_inst.mem[word_addr][31:24]);
        endcase
    endtask

    // =========================================================================
    // Golden Reference Model Storage
    // =========================================================================
    logic signed [7:0] raw_act_mem [0:24604];
    logic signed [7:0] raw_w_mem   [0:3590];

    logic signed [7:0]  test_act   [18][18][8];  // [Y][X][Cin]
    logic signed [7:0]  test_w     [3][3][8][8]; // [Ky][Kx][Cin][Cout]
    logic signed [31:0] test_bias  [8];          // [Cout]
    logic signed [31:0] golden_acc [16][16][8];  // [Oy][Ox][Cout]
    logic signed [7:0]  golden_out [16][16][8];

    // Clamping helper
    function automatic logic signed [7:0] sat_int8(input logic signed [31:0] val);
        if (val > 32'sd127)       return 8'sd127;
        else if (val < -32'sd128) return -8'sd128;
        else                      return val[7:0];
    endfunction

    function automatic [127:0] get_state_name(input [3:0] st);
        case (st)
            4'd0:  return "IDLE";
            4'd2:  return "LOAD_QUANT";
            4'd3:  return "DMA_BIAS";
            4'd4:  return "DMA_ACT";
            4'd6:  return "DMA_WEIGHT";
            4'd7:  return "SWAP_PAUSE";
            4'd8:  return "COMPUTE_STEP";
            4'd10: return "DMA_DRAIN";
            default: return "UNKNOWN";
        endcase
    endfunction

    // Interrupt monitoring
    logic irq_pulse_seen;
    initial irq_pulse_seen = 0;
    always @(posedge clk) begin
        if (efpga_usr_irq_o[0]) irq_pulse_seen <= 1'b1;
    end

    // State definitions for cycle-accurate hardware efficiency profiling
    localparam [3:0] SEQ_ST_IDLE       = 4'd0;
    localparam [3:0] SEQ_ST_LOAD_QUANT = 4'd1;
    localparam [3:0] SEQ_ST_DMA_BIAS   = 4'd2;
    localparam [3:0] SEQ_ST_DMA_ACT    = 4'd3;
    localparam [3:0] SEQ_ST_DMA_WEIGHT = 4'd4;
    localparam [3:0] SEQ_ST_SWAP_PAUSE = 4'd5;
    localparam [3:0] SEQ_ST_COMPUTE    = 4'd6;
    localparam [3:0] SEQ_ST_DMA_DRAIN  = 4'd7;

    localparam [3:0] DMA_ST_ACT_AR     = 4'd3;
    localparam [3:0] DMA_ST_ACT_R      = 4'd4;
    localparam [3:0] DMA_ST_WEIGHT_AR  = 4'd5;
    localparam [3:0] DMA_ST_WEIGHT_R   = 4'd6;
    localparam [3:0] DMA_ST_DRAIN_AW   = 4'd7;

    // Cycle breakdown counters
    int cyc_busy_total   = 0;
    int cyc_quant        = 0;
    int cyc_bias         = 0;
    int cyc_act_total    = 0;
    int cyc_act_ar       = 0;
    int cyc_act_r        = 0;
    int cyc_weight_total = 0;
    int cyc_weight_ar    = 0;
    int cyc_weight_r     = 0;
    int cyc_swap_pause   = 0;
    int cyc_comp_total   = 0;
    int cyc_comp_core    = 0;
    int cyc_comp_skew    = 0;
    int cyc_drain_total  = 0;
    int cyc_drain_aw     = 0;
    int cyc_drain_pipe   = 0;
    int cyc_drain_w      = 0;
    int cyc_drain_b      = 0;

    always @(posedge clk) begin
        if (rst_n && dut_inst.busy_sig) begin
            cyc_busy_total++;
            case (dut_inst.seq_inst.state)
                SEQ_ST_LOAD_QUANT: cyc_quant++;
                SEQ_ST_DMA_BIAS:   cyc_bias++;
                SEQ_ST_DMA_ACT: begin
                    cyc_act_total++;
                    if (dut_inst.dma_inst.state == DMA_ST_ACT_AR) cyc_act_ar++;
                    else if (dut_inst.dma_inst.state == DMA_ST_ACT_R) cyc_act_r++;
                end
                SEQ_ST_DMA_WEIGHT: begin
                    cyc_weight_total++;
                    if (dut_inst.dma_inst.state == DMA_ST_WEIGHT_AR) cyc_weight_ar++;
                    else if (dut_inst.dma_inst.state == DMA_ST_WEIGHT_R) cyc_weight_r++;
                end
                SEQ_ST_SWAP_PAUSE: cyc_swap_pause++;
                SEQ_ST_COMPUTE: begin
                    cyc_comp_total++;
                    if (dut_inst.comp_k < 256) cyc_comp_core++;
                    else cyc_comp_skew++;
                end
                SEQ_ST_DMA_DRAIN: begin
                    cyc_drain_total++;
                    if (dut_inst.dma_inst.state == DMA_ST_DRAIN_AW) cyc_drain_aw++;
                    else if (dut_inst.dma_inst.state >= 4'd8 && dut_inst.dma_inst.state <= 4'd11) cyc_drain_pipe++;
                    else if (dut_inst.dma_inst.state == 4'd12) cyc_drain_w++;
                    else if (dut_inst.dma_inst.state == 4'd13) cyc_drain_b++;
                end
                default: ;
            endcase
        end
    end

    // Watchdog Timer (cancels simulation if hung)
    initial begin
        #300_000; // 300us = 30,000 cycles
        $display("\n[ERROR] Simulation Watchdog Timeout (30,000 cycles reached)!");
        $display("        DUT State: %-16s (code %0d) | Pass: %0d | Comp_K: %0d | Out Pixel: %0d",
                 get_state_name(dut_inst.state_reg), dut_inst.state_reg, dut_inst.pass_idx,
                 dut_inst.comp_k, dut_inst.out_pixel_cnt);
        $fflush();
        $finish;
    end

    // =========================================================================
    // Test Scenario Execution
    // =========================================================================
    initial begin
        int y, x, ky, kx, ci, co, oy, ox, p, s;
        int gy, gx;
        int mem_addr;
        logic [31:0] read_status;
        longint start_cycle, total_cycles;
        int error_count;
        logic signed [31:0] acc;
        logic signed [47:0] prod;
        logic signed [47:0] round_prod;
        logic signed [31:0] scaled;
        int out_addr;
        logic signed [7:0] actual_val;
        logic signed [7:0] expect_val;

        $display("\n=====================================================================================");
        $display(">>> Starting Verification of eFPGA NPU Soft-Logic Controller <<<");
        $display("=====================================================================================");

        error_count    = 0;
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

        // Reset sequence
        #50;
        @(negedge clk);
        rst_n = 1;
        #50;

        // ---------------------------------------------------------------------
        // 1. Load Reference Mem Files & Prepare Tile Data in AXI RAM
        // ---------------------------------------------------------------------
        $display("[1/4] Loading Project .mem Files (TEST/NPU/GoldenReference/)...");
        $readmemh("TEST/NPU/GoldenReference/gen_conv3x3_halo_act.mem", raw_act_mem);
        $readmemh("TEST/NPU/GoldenReference/gen_conv3x3_halo_w.mem",   raw_w_mem);
        $display("      gen_conv3x3_halo_act.mem and gen_conv3x3_halo_w.mem loaded successfully.");

        // Extract Tile (0,0) Activations (18x18x8) and populate AXI RAM
        for (y = 0; y < 18; y++) begin
            for (x = 0; x < 18; x++) begin
                gy = y - 1;
                gx = x - 1;
                for (ci = 0; ci < 8; ci++) begin
                    if (gy >= 0 && gy < 35 && gx >= 0 && gx < 37 && ci < 19)
                        test_act[y][x][ci] = raw_act_mem[(gy * 37 * 19) + (gx * 19) + ci];
                    else
                        test_act[y][x][ci] = 8'sd0;
                    mem_addr = ACT_BASE_ADDR + ((y * 18 + x) * 8) + ci;
                    ram_write_byte(mem_addr, test_act[y][x][ci]);
                end
            end
        end

        // Extract Tile (0,0) Weights (9 passes x 8x8) and populate AXI RAM in shift-step order
        for (ky = 0; ky < 3; ky++) begin
            for (kx = 0; kx < 3; kx++) begin
                p = (ky * 3) + kx;
                for (ci = 0; ci < 8; ci++) begin
                    for (co = 0; co < 8; co++) begin
                        if (ci < 19 && co < 21)
                            test_w[ky][kx][ci][co] = raw_w_mem[(ky * 3 * 19 * 21) + (kx * 19 * 21) + (ci * 21) + co];
                        else
                            test_w[ky][kx][ci][co] = 8'sd0;
                    end
                end

                for (s = 0; s < 8; s++) begin
                    for (ci = 0; ci < 8; ci++) begin
                        mem_addr = WEIGHT_BASE_ADDR + (p * 64) + (s * 8) + ci;
                        ram_write_byte(mem_addr, test_w[ky][kx][ci][7 - s]);
                    end
                end
            end
        end

        // Define 8-Channel 32-bit Biases and populate AXI RAM
        test_bias[0] = 32'sd25;
        test_bias[1] = -32'sd40;
        test_bias[2] = 32'sd15;
        test_bias[3] = 32'sd0;
        test_bias[4] = -32'sd12;
        test_bias[5] = 32'sd60;
        test_bias[6] = -32'sd33;
        test_bias[7] = 32'sd8;

        for (co = 0; co < 8; co++) begin
            ram_write_word(BIAS_BASE_ADDR + (co * 4), test_bias[co]);
        end

        // Compute Golden Reference Outputs with Biases
        for (oy = 0; oy < 16; oy++) begin
            for (ox = 0; ox < 16; ox++) begin
                for (co = 0; co < 8; co++) begin
                    acc = test_bias[co];
                    for (ky = 0; ky < 3; ky++) begin
                        for (kx = 0; kx < 3; kx++) begin
                            for (ci = 0; ci < 8; ci++) begin
                                acc += $signed(test_act[oy + ky][ox + kx][ci]) * $signed(test_w[ky][kx][ci][co]);
                            end
                        end
                    end
                    golden_acc[oy][ox][co] = acc;

                    // Requantization: M0 = 16384, Shift = 15, ZP = 0
                    prod = $signed(acc) * 48'sd16384;
                    round_prod = prod + (48'sd1 <<< 14) - (prod[47] ? 48'sd1 : 48'sd0);
                    scaled = 32'(round_prod >>> 15);
                    golden_out[oy][ox][co] = sat_int8(scaled);
                end
            end
        end

        $display("      Data loaded into AXI RAM. Golden outputs calculated.");

        // ---------------------------------------------------------------------
        // 2. Program Soft-Logic Controller Registers via AXI-Lite
        // ---------------------------------------------------------------------
        $display("[2/4] Programming NPU Soft Controller via AXI-Lite MMIO...");
        $fflush();
        axil_write(32'h08, ACT_BASE_ADDR);
        axil_write(32'h0C, WEIGHT_BASE_ADDR);
        axil_write(32'h10, OUT_BASE_ADDR);
        axil_write(32'h14, BIAS_BASE_ADDR);
        axil_write(32'h18, {2'b00, 8'sd0, 6'd15, 16'sd16384});
        axil_write(32'h1C, 32'h0000_0001); // Bit 0: AUTO_DRAIN_OUT

        // ---------------------------------------------------------------------
        // 3. Trigger Computation & Await Completion
        // ---------------------------------------------------------------------
        $display("[3/4] Triggering START command (REG_CTRL[0] = 1)...");
        $fflush();
        start_cycle = $time;
        axil_write(32'h00, 32'h0000_0001); // Pulse START
        $display("      START command acknowledged. Entering status poll loop...");
        $fflush();

        // Poll for completion
        read_status = 32'h0;
        begin : poll_loop
            int last_pass;
            last_pass = -1;
            while (!read_status[1]) begin
                #100;
                axil_read(32'h04, read_status);
                if (dut_inst.pass_idx != last_pass && dut_inst.state_reg == 4'd8) begin
                    last_pass = dut_inst.pass_idx;
                    $display("      [HW Progress] Pass %0d/9 (ky=%0d, kx=%0d) | State: %-16s | Elapsed: %6d cycles",
                             dut_inst.pass_idx + 1, dut_inst.ky, dut_inst.kx,
                             get_state_name(dut_inst.state_reg), ($time - start_cycle) / 10);
                    $fflush();
                end
            end
        end

        total_cycles = ($time - start_cycle) / 10;
        $display("\n[4/4] Hardware Execution Completed in %0d clock cycles!", total_cycles);
        $fflush();

        // Verify Interrupt Vector
        if (!irq_pulse_seen) begin
            $display("[FAIL] efpga_usr_irq_o[0] did not pulse!");
            error_count++;
        end else if (efpga_usr_irq_o[3:1] !== 3'b000) begin
            $display("[FAIL] efpga_usr_irq_o[3:1] not tied to 0! Value: %b", efpga_usr_irq_o[3:1]);
            error_count++;
        end else begin
            $display("      [OK] Interrupt line pulsed correctly (efpga_usr_irq_o[0]=1, [3:1]=0).");
        end

        // ---------------------------------------------------------------------
        // 4. Verify Output Tensor in AXI RAM vs Golden Reference Model
        // ---------------------------------------------------------------------
        $display("      Verifying 16x16x8 Output Tensor (2048 activations) against Golden Model...");
        $fflush();

        for (oy = 0; oy < 16; oy++) begin
            for (ox = 0; ox < 16; ox++) begin
                for (co = 0; co < 8; co++) begin
                    out_addr = OUT_BASE_ADDR + ((oy * 16 + ox) * 8) + co;
                    ram_read_byte(out_addr, actual_val);
                    expect_val = golden_out[oy][ox][co];

                    if (actual_val !== expect_val) begin
                        if (error_count < 10) begin
                            $display("      [MISMATCH] Pixel (%0d,%0d) Cout %0d | Addr 0x%04X | Actual: %0d (0x%02X) | Expected: %0d (0x%02X) | Acc: %0d | Bias: %0d",
                                     oy, ox, co, out_addr, actual_val, actual_val, expect_val, expect_val, golden_acc[oy][ox][co], test_bias[co]);
                        end
                        error_count++;
                    end
                end
            end
        end

        $display("-------------------------------------------------------------------------------------");
        if (error_count == 0) begin
            $display(">>> TEST PASSED: 100%% Bit-Exact Match on Real .mem Data with Bias Preload! <<<");
            $display("    Total Validated Activations: 2048");
            $display("    Execution Latency:           %0d clock cycles", total_cycles);
            $display("    Throughput:                  %0.2f MACs/cycle", (16*16*8*9*8.0) / total_cycles);
        end else begin
            $display(">>> TEST FAILED: %0d / 2048 Activation Mismatches Encountered <<<", error_count);
        end
        $display("=====================================================================================");

        // =====================================================================
        // Hardware Efficiency & Latency Breakdown Report
        // =====================================================================
        $display("\n=========================================================================================================");
        $display(">>> DETAILED HARDWARE LATENCY & EFFICIENCY BREAKDOWN <<<");
        $display("=========================================================================================================");
        $display("  %-33s | %12s | %10s | %s", "Phase / Execution Sub-Component", "Clock Cycles", "% of Total", "Detailed Analysis / Sub-Components");
        $display("  ----------------------------------+--------------+------------+----------------------------------------");
        $display("  1. Quantization Parameter Shift   | %12d | %9.2f%% | 8-cycle lane shift (shift-in into requantizer)",
                 cyc_quant, (cyc_quant * 100.0) / cyc_busy_total);
        $display("  2. Channel Bias Preload DMA       | %12d | %9.2f%% | 8 words (Addr 0 preload into Bank A/B)",
                 cyc_bias, (cyc_bias * 100.0) / cyc_busy_total);
        $display("  3. Activation Tensor Fetch DMA    | %12d | %9.2f%% | 648 words across 41 AXI bursts (AR: %0d, Data: %0d)",
                 cyc_act_total, (cyc_act_total * 100.0) / cyc_busy_total, cyc_act_ar, cyc_act_r);
        $display("  4. Weight Fetch DMA (9 passes)    | %12d | %9.2f%% | 144 words (16/pass) direct stream (AR: %0d, Data: %0d)",
                 cyc_weight_total, (cyc_weight_total * 100.0) / cyc_busy_total, cyc_weight_ar, cyc_weight_r);
        $display("  5. Weight Swap Wavefront Pauses   | %12d | %9.2f%% | 1 cycle dead-cycle x 9 passes",
                 cyc_swap_pause, (cyc_swap_pause * 100.0) / cyc_busy_total);
        $display("  6. Systolic Array Computation     | %12d | %9.2f%% | Active MAC: %0d cyc, Wavefront Skew/Flush: %0d cyc",
                 cyc_comp_total, (cyc_comp_total * 100.0) / cyc_busy_total, cyc_comp_core, cyc_comp_skew);
        $display("  7. Output Tensor Drain DMA        | %12d | %9.2f%% | 512 words (AW: %0d, Pipe: %0d, W: %0d, B: %0d)",
                 cyc_drain_total, (cyc_drain_total * 100.0) / cyc_busy_total,
                 cyc_drain_aw, cyc_drain_pipe, cyc_drain_w, cyc_drain_b);
        $display("  ----------------------------------+--------------+------------+----------------------------------------");
        $display("  TOTAL BUSY HARDWARE TIME          | %12d |    100.00%% |", cyc_busy_total);
        $display("=========================================================================================================");
        $display("  WHERE DO WE LOSE EFFICIENCY?");
        $display("  -------------------------------------------------------------------------------------------------------");
        $display("  [A] Pure Compute vs Overhead Split:");
        $display("      - Active Systolic MAC Stepping:   %5d cycles (%5.2f%%) --> PURE WORK (9 x 256 pixels)",
                 cyc_comp_core, (cyc_comp_core * 100.0) / cyc_busy_total);
        $display("      - Systolic 2D Spatial Skew/Flush: %5d cycles (%5.2f%%) --> Array boundary fill & drain overhead",
                 cyc_comp_skew, (cyc_comp_skew * 100.0) / cyc_busy_total);
        $display("      - Total Systolic Compute Window:  %5d cycles (%5.2f%%)",
                 cyc_comp_total, (cyc_comp_total * 100.0) / cyc_busy_total);
        $display("      - Non-Compute Overhead (DMA+Wait):%5d cycles (%5.2f%%)",
                 cyc_busy_total - cyc_comp_total, ((cyc_busy_total - cyc_comp_total) * 100.0) / cyc_busy_total);
        $display("");
        $display("  [B] Memory & Transfer Bottleneck Breakdown (Total Non-Compute = %0d cycles):",
                 cyc_busy_total - cyc_comp_total);
        $display("      - Activation Fetch:               %5d cycles (%5.2f%% of total) [41 separate bursts]",
                 cyc_act_total, (cyc_act_total * 100.0) / cyc_busy_total);
        $display("      - Output Drain Store:             %5d cycles (%5.2f%% of total) [32 separate bursts]",
                 cyc_drain_total, (cyc_drain_total * 100.0) / cyc_busy_total);
        $display("      - Weight Streaming:               %5d cycles (%5.2f%% of total) [9 separate bursts]",
                 cyc_weight_total, (cyc_weight_total * 100.0) / cyc_busy_total);
        $display("      - Channel Bias Preload:           %5d cycles (%5.2f%% of total)",
                 cyc_bias, (cyc_bias * 100.0) / cyc_busy_total);
        $display("      - Config & Swap Transitions:      %5d cycles (%5.2f%% of total)",
                 cyc_quant + cyc_swap_pause, ((cyc_quant + cyc_swap_pause) * 100.0) / cyc_busy_total);
        $display("");
        $display("  [C] Utilization Metrics:");
        $display("      - Array Efficiency during Compute: %5.2f%% (active pixels / compute window)",
                 (cyc_comp_core * 100.0) / cyc_comp_total);
        $display("      - Overall Tile MAC Utilization:    %5.2f%% (sustained MACs / 64 peak MACs/cycle)",
                 ((16*16*8*9*8.0) / cyc_busy_total / 64.0) * 100.0);
        $display("=========================================================================================================\n");
        $fflush();

        #100;
        $finish;
    end

endmodule
