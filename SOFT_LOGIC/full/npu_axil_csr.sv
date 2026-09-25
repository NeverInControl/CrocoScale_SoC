`timescale 1ns / 1ps

/* ===============================================================================================
 * File: SOFT_LOGIC/full/npu_axil_csr.sv
 * Module: npu_axil_csr
 * Project: CrocoScale SoC — Full eFPGA NPU Control & Status Registers (AXI4-Lite)
 *
 * Description:
 *   Ultra-lean AXI4-Lite Slave MMIO register block for the full dual-mode NPU controller.
 *   Optimized for tight eFPGA budget: strips unallocated register bits, uses combinational
 *   read-channel multiplexing, and direct single-cycle write commit to eliminate redundant
 *   holding flops.
 * =============================================================================================== */

module npu_axil_csr #(
    parameter int AXI_ADDR_WIDTH = 32,
    parameter int AXI_DATA_WIDTH = 32
)(
    input  wire                      clk_i,
    input  wire                      rst_n,

    // AXI4-Lite Slave Interface
    input  wire [AXI_ADDR_WIDTH-1:0] s_axil_awaddr,
    input  wire [2:0]                s_axil_awprot,
    input  wire                      s_axil_awvalid,
    output logic                     s_axil_awready,

    input  wire [AXI_DATA_WIDTH-1:0] s_axil_wdata,
    input  wire [(AXI_DATA_WIDTH/8)-1:0] s_axil_wstrb,
    input  wire                      s_axil_wvalid,
    output logic                     s_axil_wready,

    output logic [1:0]               s_axil_bresp,
    output logic                     s_axil_bvalid,
    input  wire                      s_axil_bready,

    input  wire [AXI_ADDR_WIDTH-1:0] s_axil_araddr,
    input  wire [2:0]                s_axil_arprot,
    input  wire                      s_axil_arvalid,
    output logic                     s_axil_arready,

    output logic [AXI_DATA_WIDTH-1:0] s_axil_rdata,
    output logic [1:0]               s_axil_rresp,
    output logic                     s_axil_rvalid,
    input  wire                      s_axil_rready,

    // Decoded Control & Configuration Outputs
    output logic                     start_pulse_o,
    output logic                     start_drain_pulse_o,
    output logic                     soft_reset_o,
    output logic [31:0]              config_o,
    output logic [31:0]              act_base_o,
    output logic [31:0]              weight_base_o,
    output logic [31:0]              out_base_o,
    output logic [31:0]              bias_base_o,
    output logic [31:0]              quant_base_o,
    output logic [31:0]              lut_base_o,
    output logic [3:0]               usr_irq_o,

    // Hardware Status & Event Inputs
    input  wire                      fsm_busy_i,
    input  wire                      fsm_done_i,
    input  wire                      irq_pulse_i
);

    // Register Offsets
    localparam [7:0] REG_OFFSET_CTRL        = 8'h00;
    localparam [7:0] REG_OFFSET_STATUS      = 8'h04;
    localparam [7:0] REG_OFFSET_CONFIG      = 8'h08;
    localparam [7:0] REG_OFFSET_IRQ_STATUS  = 8'h0C;
    localparam [7:0] REG_OFFSET_ACT_BASE    = 8'h10;
    localparam [7:0] REG_OFFSET_WEIGHT_BASE = 8'h14;
    localparam [7:0] REG_OFFSET_OUT_BASE    = 8'h18;
    localparam [7:0] REG_OFFSET_BIAS_BASE   = 8'h1C;
    localparam [7:0] REG_OFFSET_QUANT_BASE  = 8'h20;
    localparam [7:0] REG_OFFSET_LUT_BASE    = 8'h24;

    // Lean Storage Registers
    logic        reg_soft_reset;
    logic        reg_auto_drain;
    logic        reg_mode_1x1;
    logic        reg_lut_en;
    logic        reg_pool_en;
    logic [7:0]  reg_total_passes;
    logic        reg_irq_status;
    logic        reg_done;
    logic [31:0] reg_act_base;
    logic [31:0] reg_weight_base;
    logic [31:0] reg_out_base;
    logic [31:0] reg_bias_base;
    logic [31:0] reg_quant_base;
    logic [31:0] reg_lut_base;

    // Continuous Assignments for Decoded Configuration
    assign config_o      = {16'b0, reg_total_passes, 1'b0, reg_pool_en, reg_lut_en, reg_mode_1x1, 3'b0, reg_auto_drain};
    assign act_base_o    = reg_act_base;
    assign weight_base_o = reg_weight_base;
    assign out_base_o    = reg_out_base;
    assign bias_base_o   = reg_bias_base;
    assign quant_base_o  = reg_quant_base;
    assign lut_base_o    = reg_lut_base;
    assign soft_reset_o  = reg_soft_reset;
    assign usr_irq_o     = {3'b000, irq_pulse_i};

    // AXI-Lite Write Channel Handshake & Single-Cycle Commit
    wire write_req = s_axil_awvalid && s_axil_wvalid;
    assign s_axil_awready = !s_axil_bvalid;
    assign s_axil_wready  = !s_axil_bvalid;
    assign s_axil_bresp   = 2'b00;

    always_ff @(posedge clk_i) begin
        if (!rst_n) begin
            s_axil_bvalid       <= 1'b0;
            start_pulse_o       <= 1'b0;
            start_drain_pulse_o <= 1'b0;
            reg_soft_reset      <= 1'b0;
            reg_auto_drain      <= 1'b1;
            reg_mode_1x1        <= 1'b0;
            reg_lut_en          <= 1'b0;
            reg_pool_en         <= 1'b0;
            reg_total_passes    <= 8'd0;
            reg_irq_status      <= 1'b0;
            reg_done            <= 1'b0;
            reg_act_base        <= 32'h0000_1000;
            reg_weight_base     <= 32'h0000_2000;
            reg_out_base        <= 32'h0000_3000;
            reg_bias_base       <= 32'h0000_4000;
            reg_quant_base      <= 32'h0000_5000;
            reg_lut_base        <= 32'h0000_6000;
        end else begin
            start_pulse_o       <= 1'b0;
            start_drain_pulse_o <= 1'b0;

            // Sticky Done and IRQ flags
            if (fsm_done_i)  reg_done       <= 1'b1;
            if (irq_pulse_i) reg_irq_status <= 1'b1;

            if (write_req && !s_axil_bvalid) begin
                s_axil_bvalid <= 1'b1;
                case (s_axil_awaddr[7:0])
                    REG_OFFSET_CTRL: begin
                        if (s_axil_wdata[0]) begin
                            start_pulse_o <= 1'b1;
                            reg_done      <= 1'b0;
                        end
                        if (s_axil_wdata[1]) begin
                            reg_soft_reset <= 1'b1;
                            reg_done       <= 1'b0;
                        end else begin
                            reg_soft_reset <= 1'b0;
                        end
                        if (s_axil_wdata[2]) begin
                            start_drain_pulse_o <= 1'b1;
                            reg_done            <= 1'b0;
                        end
                    end
                    REG_OFFSET_CONFIG: begin
                        reg_auto_drain   <= s_axil_wdata[0];
                        reg_mode_1x1     <= s_axil_wdata[4];
                        reg_lut_en       <= s_axil_wdata[5];
                        reg_pool_en      <= s_axil_wdata[6];
                        reg_total_passes <= s_axil_wdata[15:8];
                    end
                    REG_OFFSET_IRQ_STATUS: begin
                        if (s_axil_wdata[0]) reg_irq_status <= 1'b0;
                    end
                    REG_OFFSET_ACT_BASE:    reg_act_base    <= s_axil_wdata;
                    REG_OFFSET_WEIGHT_BASE: reg_weight_base <= s_axil_wdata;
                    REG_OFFSET_OUT_BASE:    reg_out_base    <= s_axil_wdata;
                    REG_OFFSET_BIAS_BASE:   reg_bias_base   <= s_axil_wdata;
                    REG_OFFSET_QUANT_BASE:  reg_quant_base  <= s_axil_wdata;
                    REG_OFFSET_LUT_BASE:    reg_lut_base    <= s_axil_wdata;
                    default: ;
                endcase
            end else if (s_axil_bvalid && s_axil_bready) begin
                s_axil_bvalid <= 1'b0;
            end
        end
    end

    // Combinational Read Channel Multiplexing (Pruned readback of write-only base pointers)
    logic [31:0] rdata_comb;
    always_comb begin
        case (s_axil_araddr[7:0])
            REG_OFFSET_CTRL:       rdata_comb = {30'b0, reg_soft_reset, 1'b0};
            REG_OFFSET_STATUS:     rdata_comb = {30'b0, reg_done, fsm_busy_i};
            REG_OFFSET_CONFIG:     rdata_comb = {16'b0, reg_total_passes, 1'b0, reg_pool_en, reg_lut_en, reg_mode_1x1, 3'b0, reg_auto_drain};
            REG_OFFSET_IRQ_STATUS: rdata_comb = {31'b0, reg_irq_status};
            default:               rdata_comb = 32'd0;
        endcase
    end

    assign s_axil_rdata   = rdata_comb;
    assign s_axil_rresp   = 2'b00;
    assign s_axil_arready = !s_axil_rvalid;

    always_ff @(posedge clk_i) begin
        if (!rst_n) begin
            s_axil_rvalid <= 1'b0;
        end else begin
            if (s_axil_arvalid && s_axil_arready) begin
                s_axil_rvalid <= 1'b1;
            end else if (s_axil_rvalid && s_axil_rready) begin
                s_axil_rvalid <= 1'b0;
            end
        end
    end

endmodule

