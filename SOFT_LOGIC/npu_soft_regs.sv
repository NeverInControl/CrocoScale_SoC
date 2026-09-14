`timescale 1ns / 1ps

/* ===============================================================================================
 * npu_soft_regs.sv
 *
 * eFPGA NPU Soft-Logic Controller - AXI4-Lite Register & Control Block
 *
 * Exposes memory-mapped control, status, base addresses, and quantization parameters.
 * Provides clean handshake isolation and self-clearing execution triggers.
 * =============================================================================================== */

module npu_soft_regs #(
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

    // Register Offsets
    localparam [7:0] REG_OFFSET_CTRL        = 8'h00;
    localparam [7:0] REG_OFFSET_STATUS      = 8'h04;
    localparam [7:0] REG_OFFSET_ACT_BASE    = 8'h08;
    localparam [7:0] REG_OFFSET_WEIGHT_BASE = 8'h0C;
    localparam [7:0] REG_OFFSET_OUT_BASE    = 8'h10;
    localparam [7:0] REG_OFFSET_BIAS_BASE   = 8'h14;
    localparam [7:0] REG_OFFSET_QUANT_PARAM = 8'h18;
    localparam [7:0] REG_OFFSET_CONFIG      = 8'h1C;
    localparam [7:0] REG_OFFSET_IRQ_STATUS  = 8'h20;

    // Storage Registers
    logic [31:0] reg_ctrl;
    logic [31:0] reg_act_base;
    logic [31:0] reg_weight_base;
    logic [31:0] reg_out_base;
    logic [31:0] reg_bias_base;
    logic [31:0] reg_quant_param;
    logic [31:0] reg_config;
    logic        reg_irq_status;
    logic        reg_done;

    // Continuous Assignments for Decoded Configuration
    assign act_base_o    = reg_act_base;
    assign weight_base_o = reg_weight_base;
    assign out_base_o    = reg_out_base;
    assign bias_base_o   = reg_bias_base;
    assign quant_param_o = reg_quant_param;
    assign config_o      = reg_config;
    assign soft_reset_o  = reg_ctrl[1];
    assign usr_irq_o     = {3'b000, irq_pulse_i};

    wire [31:0] reg_status = {30'b0, reg_done, fsm_busy_i};

    // AXI-Lite Write Channels
    logic aw_done, w_done;
    logic [7:0]  latched_waddr;
    logic [31:0] latched_wdata;

    always_ff @(posedge clk_i or negedge rst_n) begin
        if (!rst_n) begin
            s_axil_awready  <= 1'b1;
            s_axil_wready   <= 1'b1;
            s_axil_bvalid   <= 1'b0;
            s_axil_bresp    <= 2'b00;
            aw_done         <= 1'b0;
            w_done          <= 1'b0;
            latched_waddr   <= 8'h0;
            latched_wdata   <= 32'h0;
            start_pulse_o   <= 1'b0;

            reg_ctrl        <= 32'h0;
            reg_act_base    <= 32'h0000_1000;
            reg_weight_base <= 32'h0000_2000;
            reg_out_base    <= 32'h0000_3000;
            reg_bias_base   <= 32'h0000_4000;
            reg_quant_param <= {2'b00, 8'sd0, 6'd15, 16'sd16384};
            reg_config      <= 32'h0000_0001; // Bit 0: AUTO_DRAIN_OUT
            reg_irq_status  <= 1'b0;
            reg_done        <= 1'b0;
        end else begin
            // Single-cycle self-clearing pulses
            start_pulse_o <= 1'b0;
            if (reg_ctrl[0]) begin
                reg_ctrl[0] <= 1'b0;
                reg_done    <= 1'b0;
            end
            if (reg_ctrl[1]) reg_done <= 1'b0;

            // Sticky Done and IRQ flags
            if (fsm_done_i)  reg_done       <= 1'b1;
            if (irq_pulse_i) reg_irq_status <= 1'b1;

            // Address write handshake (decoupled from W channel)
            if (s_axil_awvalid && s_axil_awready) begin
                latched_waddr  <= s_axil_awaddr[7:0];
                aw_done        <= 1'b1;
                s_axil_awready <= 1'b0;
            end

            // Data write handshake (decoupled from AW channel)
            if (s_axil_wvalid && s_axil_wready) begin
                latched_wdata <= s_axil_wdata;
                w_done        <= 1'b1;
                s_axil_wready <= 1'b0;
            end

            // Register write commit when both address and data handshakes are satisfied
            if ((aw_done || (s_axil_awvalid && s_axil_awready)) && 
                (w_done  || (s_axil_wvalid && s_axil_wready)) && !s_axil_bvalid) begin
                
                logic [7:0]  target_addr;
                logic [31:0] target_data;
                target_addr = (s_axil_awvalid && s_axil_awready) ? s_axil_awaddr[7:0] : latched_waddr;
                target_data = (s_axil_wvalid && s_axil_wready)   ? s_axil_wdata        : latched_wdata;

                case (target_addr)
                    REG_OFFSET_CTRL: begin
                        reg_ctrl <= target_data;
                        if (target_data[0]) start_pulse_o <= 1'b1;
                    end
                    REG_OFFSET_ACT_BASE:    reg_act_base    <= target_data;
                    REG_OFFSET_WEIGHT_BASE: reg_weight_base <= target_data;
                    REG_OFFSET_OUT_BASE:    reg_out_base    <= target_data;
                    REG_OFFSET_BIAS_BASE:   reg_bias_base   <= target_data;
                    REG_OFFSET_QUANT_PARAM: reg_quant_param <= target_data;
                    REG_OFFSET_CONFIG:      reg_config      <= target_data;
                    REG_OFFSET_IRQ_STATUS:  if (target_data[0]) reg_irq_status <= 1'b0;
                    default: ;
                endcase

                s_axil_bvalid <= 1'b1;
                s_axil_bresp  <= 2'b00;
                aw_done       <= 1'b0;
                w_done        <= 1'b0;
            end

            // Write response completion
            if (s_axil_bvalid && s_axil_bready) begin
                s_axil_bvalid  <= 1'b0;
                s_axil_awready <= 1'b1;
                s_axil_wready  <= 1'b1;
            end
        end
    end

    // AXI-Lite Read Channels
    always_ff @(posedge clk_i or negedge rst_n) begin
        if (!rst_n) begin
            s_axil_arready <= 1'b1;
            s_axil_rvalid  <= 1'b0;
            s_axil_rresp   <= 2'b00;
            s_axil_rdata   <= 32'h0;
        end else begin
            // Address read handshake & data generation
            if (s_axil_arvalid && s_axil_arready) begin
                s_axil_arready <= 1'b0;
                s_axil_rvalid  <= 1'b1;
                s_axil_rresp   <= 2'b00;
                case (s_axil_araddr[7:0])
                    REG_OFFSET_CTRL:        s_axil_rdata <= reg_ctrl;
                    REG_OFFSET_STATUS:      s_axil_rdata <= reg_status;
                    REG_OFFSET_ACT_BASE:    s_axil_rdata <= reg_act_base;
                    REG_OFFSET_WEIGHT_BASE: s_axil_rdata <= reg_weight_base;
                    REG_OFFSET_OUT_BASE:    s_axil_rdata <= reg_out_base;
                    REG_OFFSET_BIAS_BASE:   s_axil_rdata <= reg_bias_base;
                    REG_OFFSET_QUANT_PARAM: s_axil_rdata <= reg_quant_param;
                    REG_OFFSET_CONFIG:      s_axil_rdata <= reg_config;
                    REG_OFFSET_IRQ_STATUS:  s_axil_rdata <= {31'b0, reg_irq_status};
                    default:                s_axil_rdata <= 32'hBAD00001;
                endcase
            end else if (s_axil_rvalid && s_axil_rready) begin
                s_axil_rvalid  <= 1'b0;
                s_axil_arready <= 1'b1;
            end
        end
    end

endmodule
