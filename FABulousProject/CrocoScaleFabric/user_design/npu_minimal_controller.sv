`timescale 1ns / 1ps

/* ===============================================================================================
 * File: SOFT_LOGIC/minimal_3x3/npu_minimal_controller.sv
 * Description:
 *   Ultra-minimal, routable 3x3 TPU systolic controller for CrocoScale SoC eFPGA.
 *   Target: < 500 LUT4s (Budget: 800 LUT4s total).
 *
 * Verification & Test Scope:
 *   - AXI4-Lite Slave CSR: Host MMIO (start, status, addresses, result checksum)
 *   - AXI4 Master: Single-beat 32-bit DMA read from System RAM and writeback
 *   - Crossbar: Hardcoded straight-through routing (sel[i] = i)
 *   - TPU Systolic 3x3: Weight shift preload, activation stream, systolic accumulation
 *   - PSUM Port: Addressable readback of accumulated partial sums
 *   - Fully synchronous reset: Compatible with FABulous LUT4c_frame_config_dffesr DFFs
 * =============================================================================================== */

module npu_minimal_controller (
    input  wire        clk_i,
    input  wire        rst_n,

    // =========================================================================
    // 1. AXI4-Lite Slave CSR (Host CPU MMIO)
    // =========================================================================
    input  wire [31:0] s_axil_awaddr,
    input  wire [2:0]  s_axil_awprot,
    input  wire        s_axil_awvalid,
    output reg         s_axil_awready,

    input  wire [31:0] s_axil_wdata,
    input  wire [3:0]  s_axil_wstrb,
    input  wire        s_axil_wvalid,
    output reg         s_axil_wready,

    output reg  [1:0]  s_axil_bresp,
    output reg         s_axil_bvalid,
    input  wire        s_axil_bready,

    input  wire [31:0] s_axil_araddr,
    input  wire [2:0]  s_axil_arprot,
    input  wire        s_axil_arvalid,
    output reg         s_axil_arready,

    output reg  [31:0] s_axil_rdata,
    output reg  [1:0]  s_axil_rresp,
    output reg         s_axil_rvalid,
    input  wire        s_axil_rready,

    // =========================================================================
    // 2. AXI4 Master (AXI-Lite Style Single-Beat DMA)
    // =========================================================================
    output reg  [31:0] m_axi_awaddr,
    output wire [7:0]  m_axi_awlen,
    output wire [2:0]  m_axi_awsize,
    output wire [1:0]  m_axi_awburst,
    output reg         m_axi_awvalid,
    input  wire        m_axi_awready,

    output reg  [31:0] m_axi_wdata,
    output wire [3:0]  m_axi_wstrb,
    output wire        m_axi_wlast,
    output reg         m_axi_wvalid,
    input  wire        m_axi_wready,

    input  wire [1:0]  m_axi_bresp,
    input  wire        m_axi_bvalid,
    output wire        m_axi_bready,

    output reg  [31:0] m_axi_araddr,
    output wire [7:0]  m_axi_arlen,
    output wire [2:0]  m_axi_arsize,
    output wire [1:0]  m_axi_arburst,
    output reg         m_axi_arvalid,
    input  wire        m_axi_arready,

    input  wire [31:0] m_axi_rdata,
    input  wire [1:0]  m_axi_rresp,
    input  wire        m_axi_rlast,
    input  wire        m_axi_rvalid,
    output wire        m_axi_rready,

    // =========================================================================
    // 3. NPU Array Control Flags
    // =========================================================================
    output reg         npu_array_en,
    output reg         npu_psum_systolic_en,
    output reg         npu_psum_lut_en,
    output wire        npu_psum_skew_en,
    output wire        npu_compute_bank_swap,
    output wire [7:0][3:0] npu_crossbar_sel,
    output reg  [1:0]  npu_weight_shift_en,
    output reg         npu_swap_weights,
    output wire        npu_stochastic_round_en,

    // =========================================================================
    // 4. Weight & Activation SRAM Interface (8 rows)
    // =========================================================================
    output reg  [7:0][7:0] npu_weight_shift_in,
    output reg  [7:0]      npu_ext_act_sram_we,
    output reg  [7:0][8:0] npu_ext_act_sram_addr,

    // =========================================================================
    // 5. PSUM Ports A & B
    // =========================================================================
    output reg  [7:0]  npu_psum_A_addr,
    output reg  [7:0]  npu_psum_A_we,
    output reg  [31:0] npu_psum_A_wdata,
    output reg  [2:0]  npu_psum_A_read_bank_sel,
    input  wire [31:0] npu_psum_A_rdata,

    output wire [7:0]  npu_psum_B_addr,
    output wire [7:0]  npu_psum_B_we,
    output wire [31:0] npu_psum_B_wdata,
    output wire [2:0]  npu_psum_B_read_bank_sel,
    input  wire [31:0] npu_psum_B_rdata,

    // =========================================================================
    // 6. Requantizer Shift & Streamed Output
    // =========================================================================
    output wire [29:0] npu_quant_shift_in,
    output wire        npu_quant_shift_en,
    input  wire [63:0] npu_out_act,

    // =========================================================================
    // 7. Status & Interrupt Out
    // =========================================================================
    output reg  [3:0]  efpga_usr_irq_o
);

    // =========================================================================
    // AXI Master Tie-Offs (Single-Beat 32-bit Transfers)
    // =========================================================================
    assign m_axi_awlen           = 8'd0;       // 1 beat
    assign m_axi_awsize          = 3'b010;     // 4 bytes (32-bit)
    assign m_axi_awburst         = 2'b01;      // INCR
    assign m_axi_wstrb           = 4'hF;
    assign m_axi_wlast           = 1'b1;       // Single beat is always last
    assign m_axi_bready          = 1'b1;
    assign m_axi_arlen           = 8'd0;
    assign m_axi_arsize          = 3'b010;
    assign m_axi_arburst         = 2'b01;
    assign m_axi_rready          = 1'b1;

    // Hardcoded Straight-Through Crossbar: Row i -> Col i
    assign npu_crossbar_sel[0]   = 4'd0;
    assign npu_crossbar_sel[1]   = 4'd1;
    assign npu_crossbar_sel[2]   = 4'd2;
    assign npu_crossbar_sel[3]   = 4'd3;
    assign npu_crossbar_sel[4]   = 4'd4;
    assign npu_crossbar_sel[5]   = 4'd5;
    assign npu_crossbar_sel[6]   = 4'd6;
    assign npu_crossbar_sel[7]   = 4'd7;

    assign npu_psum_skew_en      = 1'b0;
    assign npu_compute_bank_swap = 1'b0;
    assign npu_stochastic_round_en = 1'b0;

    // PSUM Port B unused in minimal test
    assign npu_psum_B_addr       = 8'd0;
    assign npu_psum_B_we         = 8'd0;
    assign npu_psum_B_wdata      = 32'd0;
    assign npu_psum_B_read_bank_sel = 3'd0;

    // Quantizer pass-through
    assign npu_quant_shift_in    = 30'd0;
    assign npu_quant_shift_en    = 1'b0;


    // =========================================================================
    // CSR Registers (MMIO)
    //   0x00: CTRL    [0]=start, [1]=soft_reset, [2]=irq_clear
    //   0x04: STATUS  [0]=busy,  [1]=done, [3:2]=error
    //   0x08: SRC_ADR (System RAM address to read test data from)
    //   0x0C: DST_ADR (System RAM address to write result back to)
    //   0x10: RESULT  (Readback checksum of PSUM result)
    //   0x14: CYCLES  (Execution cycle counter)
    // =========================================================================
    reg [31:0] reg_src_addr;
    reg [31:0] reg_dst_addr;
    reg [31:0] reg_result;
    reg [31:0] reg_cycles;
    reg        fsm_start;
    reg        fsm_busy;
    reg        fsm_done;

    // AXI-Lite Slave Write (Fully Synchronous Reset)
    always @(posedge clk_i) begin
        if (!rst_n) begin
            s_axil_awready <= 1'b0;
            s_axil_wready  <= 1'b0;
            s_axil_bvalid  <= 1'b0;
            s_axil_bresp   <= 2'b00;
            fsm_start      <= 1'b0;
            reg_src_addr   <= 32'h1000_0000;
            reg_dst_addr   <= 32'h1000_0100;
        end else begin
            fsm_start <= 1'b0; // Single-cycle pulse

            if (s_axil_bvalid && s_axil_bready)
                s_axil_bvalid <= 1'b0;

            if (s_axil_awvalid && s_axil_wvalid && !s_axil_bvalid) begin
                s_axil_awready <= 1'b1;
                s_axil_wready  <= 1'b1;
                s_axil_bvalid  <= 1'b1;
                s_axil_bresp   <= 2'b00; // OKAY

                case (s_axil_awaddr[4:2])
                    3'd0: begin // 0x00 CTRL
                        if (s_axil_wdata[0]) fsm_start <= 1'b1;
                    end
                    3'd2: reg_src_addr <= s_axil_wdata; // 0x08
                    3'd3: reg_dst_addr <= s_axil_wdata; // 0x0C
                    default: ;
                endcase
            end else begin
                s_axil_awready <= 1'b0;
                s_axil_wready  <= 1'b0;
            end
        end
    end

    // AXI-Lite Slave Read (Fully Synchronous Reset)
    always @(posedge clk_i) begin
        if (!rst_n) begin
            s_axil_arready <= 1'b0;
            s_axil_rvalid  <= 1'b0;
            s_axil_rdata   <= 32'd0;
            s_axil_rresp   <= 2'b00;
        end else begin
            if (s_axil_rvalid && s_axil_rready)
                s_axil_rvalid <= 1'b0;

            if (s_axil_arvalid && !s_axil_rvalid) begin
                s_axil_arready <= 1'b1;
                s_axil_rvalid  <= 1'b1;
                s_axil_rresp   <= 2'b00;

                case (s_axil_araddr[4:2])
                    3'd0: s_axil_rdata <= {31'b0, fsm_start};
                    3'd1: s_axil_rdata <= {30'b0, fsm_done, fsm_busy};
                    3'd2: s_axil_rdata <= reg_src_addr;
                    3'd3: s_axil_rdata <= reg_dst_addr;
                    3'd4: s_axil_rdata <= reg_result;
                    3'd5: s_axil_rdata <= reg_cycles;
                    default: s_axil_rdata <= 32'hDEAD_BEEF;
                endcase
            end else begin
                s_axil_arready <= 1'b0;
            end
        end
    end


    // =========================================================================
    // Central 3x3 TPU Execution Sequencer FSM
    // =========================================================================
    localparam S_IDLE          = 3'd0;
    localparam S_DMA_READ      = 3'd1; // AXI-M read from system RAM
    localparam S_WEIGHT_LOAD   = 3'd2; // Shift 3x3 weights into array
    localparam S_ACT_WRITE     = 3'd3; // Preload SRAM with input activations
    localparam S_SYSTOLIC_RUN  = 3'd4; // Stream activations & accumulate
    localparam S_PSUM_DRAIN    = 3'd5; // Read partial sum accumulator
    localparam S_DMA_WRITE     = 3'd6; // AXI-M write result back to RAM
    localparam S_DONE          = 3'd7;

    reg [2:0] state;
    reg [4:0] step_cnt;
    reg [7:0] dma_test_byte;

    always @(posedge clk_i) begin
        if (!rst_n) begin
            state                   <= S_IDLE;
            step_cnt                <= 5'd0;
            fsm_busy                <= 1'b0;
            fsm_done                <= 1'b0;
            efpga_usr_irq_o         <= 4'd0;
            reg_result              <= 32'd0;
            reg_cycles              <= 32'd0;
            dma_test_byte           <= 8'h01;

            // Bus defaults during reset
            m_axi_arvalid           <= 1'b0;
            m_axi_araddr            <= 32'd0;
            m_axi_awvalid           <= 1'b0;
            m_axi_awaddr            <= 32'd0;
            m_axi_wvalid            <= 1'b0;
            m_axi_wdata             <= 32'd0;

            npu_array_en            <= 1'b0;
            npu_psum_systolic_en    <= 1'b0;
            npu_psum_lut_en         <= 1'b0;
            npu_weight_shift_en     <= 2'b00;
            npu_swap_weights        <= 1'b0;
            npu_weight_shift_in     <= '0;

            npu_ext_act_sram_we     <= 8'd0;
            npu_ext_act_sram_addr   <= '0;

            npu_psum_A_addr         <= 8'd0;
            npu_psum_A_we           <= 8'd0;
            npu_psum_A_wdata        <= 32'd0;
            npu_psum_A_read_bank_sel<= 3'd0;
        end else begin
            // Single-cycle pulses
            npu_swap_weights <= 1'b0;

            if (fsm_busy) begin
                reg_cycles <= reg_cycles + 32'd1;
            end

            case (state)
                S_IDLE: begin
                    fsm_busy <= 1'b0;
                    if (fsm_start) begin
                        fsm_busy        <= 1'b1;
                        fsm_done        <= 1'b0;
                        efpga_usr_irq_o <= 4'd0;
                        reg_cycles      <= 32'd0;
                        step_cnt        <= 5'd0;
                        state           <= S_DMA_READ;
                    end
                end

                // Step 1: Verify AXI Master Read (1 beat from system RAM)
                S_DMA_READ: begin
                    if (!m_axi_arvalid) begin
                        m_axi_arvalid <= 1'b1;
                        m_axi_araddr  <= reg_src_addr;
                    end else if (m_axi_arready) begin
                        m_axi_arvalid <= 1'b0;
                    end

                    if (m_axi_rvalid) begin
                        dma_test_byte <= m_axi_rdata[7:0]; // Capture test byte
                        state         <= S_WEIGHT_LOAD;
                        step_cnt      <= 5'd0;
                    end
                end

                // Step 2: Shift 3x3 Weights into Rows 0..2
                S_WEIGHT_LOAD: begin
                    npu_weight_shift_en <= 2'b01; // Enable Rows 0..3 shift
                    step_cnt            <= step_cnt + 5'd1;

                    // Shift in 3 columns of 3x3 matrix: W[row] per cycle
                    case (step_cnt)
                        5'd0: begin
                            npu_weight_shift_in[0] <= dma_test_byte;
                            npu_weight_shift_in[1] <= 8'd0;
                            npu_weight_shift_in[2] <= 8'd0;
                        end
                        5'd1: begin
                            npu_weight_shift_in[0] <= 8'd0;
                            npu_weight_shift_in[1] <= dma_test_byte;
                            npu_weight_shift_in[2] <= 8'd0;
                        end
                        5'd2: begin
                            npu_weight_shift_in[0] <= 8'd0;
                            npu_weight_shift_in[1] <= 8'd0;
                            npu_weight_shift_in[2] <= dma_test_byte;
                        end
                        5'd3: begin
                            npu_weight_shift_en <= 2'b00;
                            npu_swap_weights    <= 1'b1; // Latch weights into active systolic registers
                            step_cnt            <= 5'd0;
                            state               <= S_ACT_WRITE;
                        end
                        default: ;
                    endcase
                end

                // Step 3: Write test activations into Row SRAMs 0..2
                S_ACT_WRITE: begin
                    step_cnt <= step_cnt + 5'd1;
                    case (step_cnt)
                        5'd0: begin
                            npu_ext_act_sram_we    <= 8'b0000_0111; // Enable Rows 0, 1, 2
                            npu_ext_act_sram_addr[0] <= 9'd0;
                            npu_ext_act_sram_addr[1] <= 9'd0;
                            npu_ext_act_sram_addr[2] <= 9'd0;
                        end
                        5'd1: begin
                            npu_ext_act_sram_addr[0] <= 9'd1;
                            npu_ext_act_sram_addr[1] <= 9'd1;
                            npu_ext_act_sram_addr[2] <= 9'd1;
                        end
                        5'd2: begin
                            npu_ext_act_sram_addr[0] <= 9'd2;
                            npu_ext_act_sram_addr[1] <= 9'd2;
                            npu_ext_act_sram_addr[2] <= 9'd2;
                        end
                        5'd3: begin
                            npu_ext_act_sram_we <= 8'd0;
                            step_cnt            <= 5'd0;
                            state               <= S_SYSTOLIC_RUN;
                        end
                        default: ;
                    endcase
                end

                // Step 4: Run Systolic Compute (Skewed Stream for 3x3)
                S_SYSTOLIC_RUN: begin
                    npu_array_en         <= 1'b1;
                    npu_psum_systolic_en <= 1'b1;
                    step_cnt             <= step_cnt + 5'd1;

                    // Standard TPU systolic skew across Rows 0, 1, 2:
                    // Cycle 0: Row 0 addr 0
                    // Cycle 1: Row 0 addr 1, Row 1 addr 0
                    // Cycle 2: Row 0 addr 2, Row 1 addr 1, Row 2 addr 0
                    // Cycle 3: Row 1 addr 2, Row 2 addr 1
                    // Cycle 4: Row 2 addr 2
                    npu_ext_act_sram_addr[0] <= (step_cnt <= 5'd2) ? {4'd0, step_cnt} : 9'd0;
                    npu_ext_act_sram_addr[1] <= (step_cnt >= 5'd1 && step_cnt <= 5'd3) ? {4'd0, (step_cnt - 5'd1)} : 9'd0;
                    npu_ext_act_sram_addr[2] <= (step_cnt >= 5'd2 && step_cnt <= 5'd4) ? {4'd0, (step_cnt - 5'd2)} : 9'd0;

                    // Total compute latency: 3 skew + 3 compute = 6 cycles
                    if (step_cnt == 5'd7) begin
                        npu_array_en         <= 1'b0;
                        npu_psum_systolic_en <= 1'b0;
                        step_cnt             <= 5'd0;
                        state                <= S_PSUM_DRAIN;
                    end
                end

                // Step 5: Read Partial Sum Accumulator (Bank 0, Addr 0)
                S_PSUM_DRAIN: begin
                    npu_psum_A_read_bank_sel <= 3'd0;
                    npu_psum_A_addr          <= 8'd0;
                    step_cnt                 <= step_cnt + 5'd1;

                    if (step_cnt == 5'd2) begin
                        reg_result <= npu_psum_A_rdata; // Latch result
                        step_cnt   <= 5'd0;
                        state      <= S_DMA_WRITE;
                    end
                end

                // Step 6: Verify AXI Master Write (Write result back to system RAM)
                S_DMA_WRITE: begin
                    if (!m_axi_awvalid) begin
                        m_axi_awvalid <= 1'b1;
                        m_axi_awaddr  <= reg_dst_addr;
                        m_axi_wvalid  <= 1'b1;
                        m_axi_wdata   <= reg_result;
                    end else begin
                        if (m_axi_awready) m_axi_awvalid <= 1'b0;
                        if (m_axi_wready)  m_axi_wvalid  <= 1'b0;
                    end

                    if (m_axi_bvalid) begin
                        state <= S_DONE;
                    end
                end

                // Step 7: Done & Interrupt
                S_DONE: begin
                    fsm_busy        <= 1'b0;
                    fsm_done        <= 1'b1;
                    efpga_usr_irq_o <= 4'b0001; // Raise interrupt 0 to SoC
                    if (fsm_start) begin
                        state <= S_IDLE;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
