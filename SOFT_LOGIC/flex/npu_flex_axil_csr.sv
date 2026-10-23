// =============================================================================
// File: SOFT_LOGIC/flex/npu_flex_axil_csr.sv
// Module: npu_flex_axil_csr
// Project: CrocoScale SoC — 8-Bank (4x2) eFPGA NPU Control & Status Registers
//
// Description:
//   Ultra-lean AXI4-Lite Slave MMIO register block for the 8-bank (4x2)
//   soft-logic NPU controller.
//
//   Register Map (Byte Offset / Word Index addr[5:2]):
//     0x00 (0): REG_CTRL        [0]=START (W1P), [1]=SOFT_RESET, [2]=START_DRAIN (W1P)
//     0x04 (1): REG_STATUS      [0]=BUSY (RO), [1]=DONE (RO, sticky)
//     0x08 (2): REG_CONFIG      [0]=AUTO_DRAIN, [4]=MODE_1X1, [5]=LUT_EN,
//                               [6]=POOL_EN, [15:8]=TOTAL_PASSES
//     0x0C (3): REG_IRQ_STATUS  [0]=IRQ_STATUS (R/W1C)
//     0x10 (4): REG_ACT_BASE    Activation tensor base address (word-aligned)
//     0x14 (5): REG_WEIGHT_BASE Weight tensor base address (word-aligned)
//     0x18 (6): REG_OUT_BASE    Output tensor base address (word-aligned)
//     0x1C (7): REG_BIAS_BASE   Bias vector base address (word-aligned)
//     0x20 (8): REG_QUANT_BASE  Quantizer config base address (word-aligned)
//     0x24 (9): REG_LUT_BASE    Non-linear LUT table base address (word-aligned)
//     0x28(10): REG_GEOM        [3:0]=TILE_X, [7:4]=TILE_Y, [15:8]=IMG_W,
//                               [23:16]=IMG_H, [31:24]=CFG_CIN
// =============================================================================

`timescale 1ns / 1ps

module npu_flex_axil_csr #(
    parameter int AXI_ADDR_WIDTH = 10,
    parameter int AXI_DATA_WIDTH = 32,
    parameter int DEFAULT_H      = 32,
    parameter int DEFAULT_W      = 32,
    parameter int DEFAULT_CIN    = 128
) (
    input  wire                          clk_i,
    input  wire                          rst_n,

    // AXI4-Lite Slave Interface
    input  wire [AXI_ADDR_WIDTH-1:0]     s_axil_awaddr,
    input  wire [2:0]                    s_axil_awprot,
    input  wire                          s_axil_awvalid,
    output logic                         s_axil_awready,

    input  wire [AXI_DATA_WIDTH-1:0]     s_axil_wdata,
    input  wire [(AXI_DATA_WIDTH/8)-1:0] s_axil_wstrb,
    input  wire                          s_axil_wvalid,
    output logic                         s_axil_wready,

    output logic [1:0]                   s_axil_bresp,
    output logic                         s_axil_bvalid,
    input  wire                          s_axil_bready,

    input  wire [AXI_ADDR_WIDTH-1:0]     s_axil_araddr,
    input  wire [2:0]                    s_axil_arprot,
    input  wire                          s_axil_arvalid,
    output logic                         s_axil_arready,

    output logic [AXI_DATA_WIDTH-1:0]     s_axil_rdata,
    output logic [1:0]                   s_axil_rresp,
    output logic                         s_axil_rvalid,
    input  wire                          s_axil_rready,

    // Decoded Control & Configuration Outputs
    output logic                         start_pulse_o,
    output logic                         start_drain_pulse_o,
    output logic                         soft_reset_o,
    output logic                         auto_drain_o,
    output logic                         mode_1x1_o,
    output logic                         lut_en_o,
    output logic                         pool_en_o,
    output logic [7:0]                   total_passes_o,
    output logic [3:0]                   tile_x_o,
    output logic [3:0]                   tile_y_o,
    output logic [7:0]                   img_w_o,
    output logic [7:0]                   img_h_o,
    output logic [7:0]                   cfg_cin_o,
    output logic [31:0]                  act_base_o,
    output logic [31:0]                  weight_base_o,
    output logic [31:0]                  out_base_o,
    output logic [31:0]                  bias_base_o,
    output logic [31:0]                  quant_base_o,
    output logic [31:0]                  lut_base_o,
    output logic [3:0]                   usr_irq_o,

    // Hardware Status & Event Inputs
    input  wire                          fsm_busy_i,
    input  wire                          fsm_done_i
);

    localparam logic [3:0] REG_IDX_CTRL        = 4'd0;
    localparam logic [3:0] REG_IDX_STATUS      = 4'd1;
    localparam logic [3:0] REG_IDX_CONFIG      = 4'd2;
    localparam logic [3:0] REG_IDX_IRQ_STATUS  = 4'd3;
    localparam logic [3:0] REG_IDX_ACT_BASE    = 4'd4;
    localparam logic [3:0] REG_IDX_WEIGHT_BASE = 4'd5;
    localparam logic [3:0] REG_IDX_OUT_BASE    = 4'd6;
    localparam logic [3:0] REG_IDX_BIAS_BASE   = 4'd7;
    localparam logic [3:0] REG_IDX_QUANT_BASE  = 4'd8;
    localparam logic [3:0] REG_IDX_LUT_BASE    = 4'd9;
    localparam logic [3:0] REG_IDX_GEOM        = 4'd10;

    // Lean Storage Registers (word-aligned base pointers omit bits [1:0])
    logic        reg_soft_reset;
    logic        reg_auto_drain;
    logic        reg_mode_1x1;
    logic        reg_lut_en;
    logic        reg_pool_en;
    logic [7:0]  reg_total_passes;
    logic        reg_irq_status;
    logic        reg_done;

    logic [3:0]  reg_tile_x;
    logic [3:0]  reg_tile_y;
    logic [7:0]  reg_img_w;
    logic [7:0]  reg_img_h;
    logic [7:0]  reg_cfg_cin;

    logic [11:0] reg_ram_base_high;
    logic [19:2] reg_act_base;
    logic [19:2] reg_weight_base;
    logic [19:2] reg_out_base;
    logic [19:2] reg_bias_base;
    logic [19:2] reg_quant_base;
    logic [19:2] reg_lut_base;

    assign soft_reset_o   = reg_soft_reset;
    assign auto_drain_o   = reg_auto_drain;
    assign mode_1x1_o     = reg_mode_1x1;
    assign lut_en_o       = reg_lut_en;
    assign pool_en_o      = reg_pool_en;
    assign total_passes_o = reg_total_passes;

    assign tile_x_o       = reg_tile_x;
    assign tile_y_o       = reg_tile_y;
    assign img_w_o        = reg_img_w;
    assign img_h_o        = reg_img_h;
    assign cfg_cin_o      = reg_cfg_cin;

    assign act_base_o     = {reg_ram_base_high, reg_act_base,    2'b00};
    assign weight_base_o  = {reg_ram_base_high, reg_weight_base, 2'b00};
    assign out_base_o     = {reg_ram_base_high, reg_out_base,    2'b00};
    assign bias_base_o    = {reg_ram_base_high, reg_bias_base,   2'b00};
    assign quant_base_o   = {reg_ram_base_high, reg_quant_base,  2'b00};
    assign lut_base_o     = {reg_ram_base_high, reg_lut_base,    2'b00};
    assign usr_irq_o      = {3'b000, fsm_done_i};

    // AXI-Lite Write Channel Handshake & Single-Cycle Commit
    wire write_req = s_axil_awvalid && s_axil_wvalid && !s_axil_bvalid;
    assign s_axil_awready = write_req;
    assign s_axil_wready  = write_req;
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
            reg_tile_x          <= 4'd0;
            reg_tile_y          <= 4'd0;
            reg_img_w           <= 8'(DEFAULT_W);
            reg_img_h           <= 8'(DEFAULT_H);
            reg_cfg_cin         <= 8'(DEFAULT_CIN);
            reg_ram_base_high   <= 12'h000;
            reg_act_base        <= 18'h0_0000;
            reg_weight_base     <= 18'h0_8000;
            reg_out_base        <= 18'h1_0000;
            reg_bias_base       <= 18'h0_C000;
            reg_quant_base      <= 18'h0_C400;
            reg_lut_base        <= 18'h0_C800;
        end else begin
            start_pulse_o       <= 1'b0;
            start_drain_pulse_o <= 1'b0;

            if (fsm_done_i) begin
                reg_done       <= 1'b1;
                reg_irq_status <= 1'b1;
            end

            if (write_req && !s_axil_bvalid) begin
                s_axil_bvalid <= 1'b1;
                case (s_axil_awaddr[5:2])
                    REG_IDX_CTRL: begin
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
                    REG_IDX_CONFIG: begin
                        reg_auto_drain   <= s_axil_wdata[0];
                        reg_mode_1x1     <= s_axil_wdata[4];
                        reg_lut_en       <= s_axil_wdata[5];
                        reg_pool_en      <= s_axil_wdata[6];
                        reg_total_passes <= s_axil_wdata[15:8];
                    end
                    REG_IDX_IRQ_STATUS: begin
                        if (s_axil_wdata[0]) reg_irq_status <= 1'b0;
                    end
                    REG_IDX_ACT_BASE: begin
                        reg_ram_base_high <= s_axil_wdata[31:20];
                        reg_act_base      <= s_axil_wdata[19:2];
                    end
                    REG_IDX_WEIGHT_BASE: begin
                        reg_ram_base_high <= s_axil_wdata[31:20];
                        reg_weight_base   <= s_axil_wdata[19:2];
                    end
                    REG_IDX_OUT_BASE: begin
                        reg_ram_base_high <= s_axil_wdata[31:20];
                        reg_out_base      <= s_axil_wdata[19:2];
                    end
                    REG_IDX_BIAS_BASE: begin
                        reg_ram_base_high <= s_axil_wdata[31:20];
                        reg_bias_base     <= s_axil_wdata[19:2];
                    end
                    REG_IDX_QUANT_BASE: begin
                        reg_ram_base_high <= s_axil_wdata[31:20];
                        reg_quant_base    <= s_axil_wdata[19:2];
                    end
                    REG_IDX_LUT_BASE: begin
                        reg_ram_base_high <= s_axil_wdata[31:20];
                        reg_lut_base      <= s_axil_wdata[19:2];
                    end
                    REG_IDX_GEOM: begin
                        reg_tile_x  <= s_axil_wdata[3:0];
                        reg_tile_y  <= s_axil_wdata[7:4];
                        reg_img_w   <= s_axil_wdata[15:8];
                        reg_img_h   <= s_axil_wdata[23:16];
                        reg_cfg_cin <= s_axil_wdata[31:24];
                    end
                    default: ;
                endcase
            end else if (s_axil_bvalid && s_axil_bready) begin
                s_axil_bvalid <= 1'b0;
            end
        end
    end

    // Combinational Read Channel Multiplexing
    always_comb begin
        case (s_axil_araddr[5:2])
            REG_IDX_CTRL:       s_axil_rdata = {30'b0, reg_soft_reset, 1'b0};
            REG_IDX_STATUS:     s_axil_rdata = {30'b0, reg_done, fsm_busy_i};
            REG_IDX_CONFIG:     s_axil_rdata = {16'b0, reg_total_passes, 1'b0, reg_pool_en, reg_lut_en, reg_mode_1x1, 3'b0, reg_auto_drain};
            REG_IDX_IRQ_STATUS: s_axil_rdata = {31'b0, reg_irq_status};
            REG_IDX_GEOM:       s_axil_rdata = {reg_cfg_cin, reg_img_h, reg_img_w, reg_tile_y, reg_tile_x};
            default:            s_axil_rdata = 32'd0;
        endcase
    end

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

