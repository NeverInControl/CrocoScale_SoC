`timescale 1ns / 1ps

/* ===============================================================================================
 * File: SOFT_LOGIC/npu_axi_read_master.sv
 * Module: npu_axi_read_master
 * Project: CrocoScale SoC — Shared AXI4 Read Master Engine
 *
 * Description:
 *   Shared, reusable AXI4 burst read engine. Converts command requests (address, length)
 *   into standard AXI AR transactions and streams read words directly to clients with
 *   bidirectional backpressure and completion signaling.
 * =============================================================================================== */

module npu_axi_read_master #(
    parameter int AXI_ADDR_WIDTH = 32,
    parameter int AXI_DATA_WIDTH = 32
) (
    input  wire                       clk_i,
    input  wire                       rst_n,

    // Command Request Interface (Client Side)
    input  wire                       req_valid_i,
    input  wire [AXI_ADDR_WIDTH-1:0]  req_addr_i,
    input  wire [7:0]                 req_len_i,
    output logic                      req_ready_o,

    // Data Response Stream (Client Side)
    output wire [AXI_DATA_WIDTH-1:0]  rdata_o,
    output wire                       rvalid_o,
    output wire                       rlast_o,
    input  wire                       rready_i,

    // AXI4 Master AR Channel
    output logic [AXI_ADDR_WIDTH-1:0] m_axi_araddr,
    output logic [7:0]                m_axi_arlen,
    output logic [2:0]                m_axi_arsize,
    output logic [1:0]                m_axi_arburst,
    output logic                      m_axi_arvalid,
    input  wire                       m_axi_arready,

    // AXI4 Master R Channel
    input  wire [AXI_DATA_WIDTH-1:0]  m_axi_rdata,
    input  wire [1:0]                 m_axi_rresp,
    input  wire                       m_axi_rlast,
    input  wire                       m_axi_rvalid,
    output logic                      m_axi_rready
);

    typedef enum logic [1:0] {
        IDLE    = 2'd0,
        SEND_AR = 2'd1,
        READ_R  = 2'd2
    } state_t;

    state_t state;

    assign m_axi_arsize  = 3'b010; // 4 bytes (32 bits)
    assign m_axi_arburst = 2'b01;  // INCR

    assign rdata_o       = m_axi_rdata;
    assign rvalid_o      = (state == READ_R) ? m_axi_rvalid : 1'b0;
    assign rlast_o       = (state == READ_R) ? m_axi_rlast  : 1'b0;
    assign m_axi_rready  = (state == READ_R) ? rready_i     : 1'b0;

    always_ff @(posedge clk_i or negedge rst_n) begin
        if (!rst_n) begin
            state         <= IDLE;
            m_axi_araddr  <= '0;
            m_axi_arlen   <= '0;
            m_axi_arvalid <= 1'b0;
            req_ready_o   <= 1'b1;
        end else begin
            case (state)
                IDLE: begin
                    req_ready_o <= 1'b1;
                    if (req_valid_i) begin
                        m_axi_araddr  <= req_addr_i;
                        m_axi_arlen   <= req_len_i;
                        m_axi_arvalid <= 1'b1;
                        req_ready_o   <= 1'b0;
                        state         <= SEND_AR;
                    end
                end

                SEND_AR: begin
                    if (m_axi_arready) begin
                        m_axi_arvalid <= 1'b0;
                        state         <= READ_R;
                    end
                end

                READ_R: begin
                    if (m_axi_rvalid && rready_i && m_axi_rlast) begin
                        req_ready_o <= 1'b1;
                        state       <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule

