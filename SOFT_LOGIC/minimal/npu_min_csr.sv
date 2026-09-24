`timescale 1ns / 1ps

/* ===============================================================================================
 * File: SOFT_LOGIC/minimal/npu_min_csr.sv
 * Module: npu_min_csr
 * Project: CrocoScale SoC -- eFPGA Minimal NPU Soft-Logic CSR
 *
 * Description:
 *   Lightweight AXI4-Lite Slave MMIO register block for host CPU orchestration.
 *   Single-cycle write commit on simultaneous AW+W handshakes without register bloat.
 *   Provides clean register decoding, self-clearing execution triggers, and status/IRQ reporting.
 *   Streamlined readback logic focused on status polling for ultra-low LUT mapping.
 *   Fully synchronous reset for optimal FPGA/eFPGA mapping.
 * =============================================================================================== */

module npu_min_csr #(
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
    output logic                     soft_reset_o,
    output logic [31:0]              act_base_o,
    output logic [31:0]              weight_base_o,
    output logic [31:0]              out_base_o,
    output logic [31:0]              bias_base_o,
    output logic [31:0]              quant_param_o,
    output logic [31:0]              config_o,
    output logic [3:0]               usr_irq_o,

    // Hardware Status & Event Inputs
    input  wire                      fsm_busy_i,
    input  wire                      fsm_done_i,
    input  wire                      irq_pulse_i
);

    // Register Storage
    logic [31:0] reg_act_base;
    logic [31:0] reg_weight_base;
    logic [31:0] reg_out_base;
    logic [31:0] reg_bias_base;
    logic [29:0] reg_quant_param;
    logic        reg_auto_drain;
    logic        reg_irq_status;
    logic        reg_done;

    assign act_base_o    = reg_act_base;
    assign weight_base_o = reg_weight_base;
    assign out_base_o    = reg_out_base;
    assign bias_base_o   = reg_bias_base;
    assign quant_param_o = {2'b00, reg_quant_param};
    assign config_o      = {31'b0, reg_auto_drain};
    assign usr_irq_o     = {3'b000, irq_pulse_i};

    assign s_axil_awready = !s_axil_bvalid;
    assign s_axil_wready  = !s_axil_bvalid;

    // AXI-Lite Write Engine
    always_ff @(posedge clk_i) begin
        if (!rst_n) begin
            s_axil_bvalid   <= 1'b0;
            s_axil_bresp    <= 2'b00;
            start_pulse_o   <= 1'b0;
            soft_reset_o    <= 1'b0;
            reg_act_base    <= 32'h0000_1000;
            reg_weight_base <= 32'h0000_2000;
            reg_out_base    <= 32'h0000_3000;
            reg_bias_base   <= 32'h0000_4000;
            reg_quant_param <= {8'sd0, 6'd15, 16'sd16384};
            reg_auto_drain  <= 1'b1;
            reg_irq_status  <= 1'b0;
            reg_done        <= 1'b0;
        end else begin
            start_pulse_o <= 1'b0;
            soft_reset_o  <= 1'b0;

            if (fsm_done_i)  reg_done       <= 1'b1;
            if (irq_pulse_i) reg_irq_status <= 1'b1;

            if (s_axil_awvalid && s_axil_wvalid && !s_axil_bvalid) begin
                s_axil_bvalid <= 1'b1;
                case (s_axil_awaddr[5:2])
                    4'h0: begin
                        if (s_axil_wdata[0]) begin
                            start_pulse_o <= 1'b1;
                            reg_done      <= 1'b0;
                        end
                        if (s_axil_wdata[1]) begin
                            soft_reset_o <= 1'b1;
                            reg_done     <= 1'b0;
                        end
                    end
                    4'h2: reg_act_base    <= s_axil_wdata;
                    4'h3: reg_weight_base <= s_axil_wdata;
                    4'h4: reg_out_base    <= s_axil_wdata;
                    4'h5: reg_bias_base   <= s_axil_wdata;
                    4'h6: reg_quant_param <= s_axil_wdata[29:0];
                    4'h7: reg_auto_drain  <= s_axil_wdata[0];
                    4'h8: if (s_axil_wdata[0]) reg_irq_status <= 1'b0;
                    default: ;
                endcase
            end else if (s_axil_bvalid && s_axil_bready) begin
                s_axil_bvalid <= 1'b0;
            end
        end
    end

    // AXI-Lite Read Engine
    assign s_axil_arready = !s_axil_rvalid;

    always_ff @(posedge clk_i) begin
        if (!rst_n) begin
            s_axil_rvalid <= 1'b0;
            s_axil_rresp  <= 2'b00;
            s_axil_rdata  <= 32'h0;
        end else begin
            if (s_axil_arvalid && !s_axil_rvalid) begin
                s_axil_rvalid <= 1'b1;
                if (s_axil_araddr[5:2] == 4'h8) begin
                    s_axil_rdata <= {31'b0, reg_irq_status};
                end else begin
                    s_axil_rdata <= {30'b0, reg_done, fsm_busy_i};
                end
            end else if (s_axil_rvalid && s_axil_rready) begin
                s_axil_rvalid <= 1'b0;
            end
        end
    end

endmodule
