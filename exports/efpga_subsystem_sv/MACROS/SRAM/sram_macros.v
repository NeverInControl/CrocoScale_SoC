`timescale 1ns / 1ps

/* ===============================================================================================
 * IHP SG13G2 Single-Port SRAM Hard Macro Blackbox Models
 * Process: IHP 130nm CMOS5L / SG13G2
 * =============================================================================================== */

/* 512x8 SRAM Macro (Activation Memory) */
module RM_IHPSG13_1P_512x8_c3_bm_bist (
    input  wire        A_CLK,
    input  wire        A_MEN,
    input  wire        A_WEN,
    input  wire        A_REN,
    input  wire [8:0]  A_ADDR,
    input  wire [7:0]  A_DIN,
    input  wire        A_DLY,
    output reg  [7:0]  A_DOUT,
    input  wire [7:0]  A_BM,

    input  wire        A_BIST_CLK,
    input  wire        A_BIST_EN,
    input  wire        A_BIST_MEN,
    input  wire        A_BIST_WEN,
    input  wire        A_BIST_REN,
    input  wire [8:0]  A_BIST_ADDR,
    input  wire [7:0]  A_BIST_DIN,
    input  wire [7:0]  A_BIST_BM
);

    reg [7:0] mem [0:511];

    always @(posedge A_CLK) begin
        if (A_MEN && A_WEN) begin
            mem[A_ADDR] <= (A_DIN & A_BM) | (mem[A_ADDR] & ~A_BM);
        end
        if (A_MEN && A_REN) begin
            A_DOUT <= mem[A_ADDR];
        end
    end

endmodule

/* 256x32 SRAM Macro (Partial Sum Memory) */
module RM_IHPSG13_1P_256x32_c2_bm_bist (
    input  wire        A_CLK,
    input  wire        A_MEN,
    input  wire        A_WEN,
    input  wire        A_REN,
    input  wire [7:0]  A_ADDR,
    input  wire [31:0] A_DIN,
    input  wire        A_DLY,
    output reg  [31:0] A_DOUT,
    input  wire [31:0] A_BM,

    input  wire        A_BIST_CLK,
    input  wire        A_BIST_EN,
    input  wire        A_BIST_MEN,
    input  wire        A_BIST_WEN,
    input  wire        A_BIST_REN,
    input  wire [7:0]  A_BIST_ADDR,
    input  wire [31:0] A_BIST_DIN,
    input  wire [31:0] A_BIST_BM
);

    reg [31:0] mem [0:255];

    always @(posedge A_CLK) begin
        if (A_MEN && A_WEN) begin
            mem[A_ADDR] <= (A_DIN & A_BM) | (mem[A_ADDR] & ~A_BM);
        end
        if (A_MEN && A_REN) begin
            A_DOUT <= mem[A_ADDR];
        end
    end

endmodule

