`timescale 1ns / 1ps

module npu_top #(
    parameter int ARRAY_HEIGHT     = 8,
    parameter int ARRAY_WIDTH      = 8,
    parameter int TILE_SIZE        = 16,
    parameter int ACT_HALO_PAD     = 2,
    parameter int ACTIVATION_WIDTH = 8,
    parameter int WEIGHT_WIDTH     = 8,
    parameter int PSUM_WIDTH       = 32,
    parameter int SCALE_WIDTH      = 16,
    parameter bit ENABLE_LFSR      = 0,
    parameter int WEIGHT_SPLIT     = 2,
    
    localparam int PSUM_WORDS      = TILE_SIZE * TILE_SIZE,
    localparam int ACT_WORDS       = (TILE_SIZE * TILE_SIZE) * ACT_HALO_PAD,
    localparam int PSUM_ADDR_WIDTH = $clog2(PSUM_WORDS),
    localparam int ACT_ADDR_WIDTH  = $clog2(ACT_WORDS),
    localparam int NUM_ACT_BANKS   = ARRAY_HEIGHT,
    localparam int NUM_PSUM_BANKS  = ARRAY_WIDTH * 2,
    localparam int XBAR_SEL_WIDTH  = $clog2(ARRAY_HEIGHT) + 1,
    localparam int PROD_WIDTH      = PSUM_WIDTH + SCALE_WIDTH,
    localparam int SHIFT_WIDTH     = $clog2(PROD_WIDTH),
    localparam int QUANT_CFG_WIDTH = SCALE_WIDTH + SHIFT_WIDTH + ACTIVATION_WIDTH
)(
    input  wire                                                          clk_i,
    input  wire                                                          rst_n,

    // Core Execution Controls
    input  wire                                                          array_en,
    input  wire                                                          psum_systolic_en,
    input  wire                                                          psum_lut_en,

    // Crossbar Routing
    input  wire        [ARRAY_HEIGHT-1:0][XBAR_SEL_WIDTH-1:0]            crossbar_sel,

    // Parameterized Weight Interface
    input  wire signed [ARRAY_HEIGHT-1:0][WEIGHT_WIDTH-1:0]              weight_shift_in,
    input  wire        [WEIGHT_SPLIT-1:0]                                weight_shift_en,
    input  wire                                                          swap_weights,

    // Quantizer Configuration Interface
    input  wire        [QUANT_CFG_WIDTH-1:0]                             quant_shift_in,
    input  wire                                                          quant_shift_en,
    input  wire                                                          stochastic_round_en,
    output wire        [SCALE_WIDTH-1:0]                                 lfsr_data_out,

    // PSum Datapath & Mode Controls
    input  wire                                                          psum_skew_en,
    input  wire                                                          compute_bank_swap,

    // Fabric PSum Port A Interface
    input  wire        [PSUM_ADDR_WIDTH-1:0]                             psum_A_addr,
    input  wire        [ARRAY_WIDTH-1:0]                                 psum_A_we,
    input  wire signed [PSUM_WIDTH-1:0]                                  psum_A_wdata,
    input  wire        [$clog2(ARRAY_WIDTH)-1:0]                         psum_A_read_bank_sel,
    output wire signed [PSUM_WIDTH-1:0]                                  psum_A_rdata,

    // Fabric PSum Port B Interface
    input  wire        [PSUM_ADDR_WIDTH-1:0]                             psum_B_addr,
    input  wire        [ARRAY_WIDTH-1:0]                                 psum_B_we,
    input  wire signed [PSUM_WIDTH-1:0]                                  psum_B_wdata,
    input  wire        [$clog2(ARRAY_WIDTH)-1:0]                         psum_B_read_bank_sel,
    output wire signed [PSUM_WIDTH-1:0]                                  psum_B_rdata,

    // Physical SRAM Interfaces
    input  wire signed [NUM_ACT_BANKS-1:0][ACTIVATION_WIDTH-1:0]         act_sram_rdata,

    input  wire signed [NUM_PSUM_BANKS-1:0][PSUM_WIDTH-1:0]             psum_sram_rdata,
    output logic       [NUM_PSUM_BANKS-1:0]                              psum_sram_we,
    output logic       [NUM_PSUM_BANKS-1:0][PSUM_ADDR_WIDTH-1:0]         psum_sram_addr,
    output logic signed [NUM_PSUM_BANKS-1:0][PSUM_WIDTH-1:0]            psum_sram_wdata,

    // Final Quantized Streaming Output
    output wire signed [ARRAY_WIDTH-1:0][ACTIVATION_WIDTH-1:0]           out_act
);

    // =========================================================================
    // 1. Crossbar Pipeline & Instance
    // =========================================================================
    // 1-Cycle Pipeline Register for Crossbar Selection
    // Aligns routing with the 1-cycle SRAM read latency and improves FPGA I/O timing.
    logic [ARRAY_HEIGHT-1:0][XBAR_SEL_WIDTH-1:0] crossbar_sel_pipe;

    always_ff @(posedge clk_i or negedge rst_n) begin
        if (!rst_n) begin
            for (int r = 0; r < ARRAY_HEIGHT; r++) begin
                // Default to "Force Zero" state (MSB = 1)
                crossbar_sel_pipe[r] <= {1'b1, {(XBAR_SEL_WIDTH-1){1'b0}}};
            end
        end else begin
            crossbar_sel_pipe <= crossbar_sel;
        end
    end

    wire signed [ARRAY_HEIGHT-1:0][ACTIVATION_WIDTH-1:0] xbar_out;

    npu_crossbar #(
        .ARRAY_HEIGHT    (ARRAY_HEIGHT),
        .ACTIVATION_WIDTH(ACTIVATION_WIDTH)
    ) xbar_inst (
        .in_data     (act_sram_rdata),
        .crossbar_sel(crossbar_sel_pipe), // <-- Drive with pipelined signal
        .out_data    (xbar_out)
    );

    // 2. Systolic Array Core
    logic signed [ARRAY_WIDTH-1:0][PSUM_WIDTH-1:0] array_psum_in;
    wire  signed [ARRAY_WIDTH-1:0][PSUM_WIDTH-1:0] array_psum_out;

    systolic_array #(
        .ARRAY_HEIGHT    (ARRAY_HEIGHT),
        .ARRAY_WIDTH     (ARRAY_WIDTH),
        .ACTIVATION_WIDTH(ACTIVATION_WIDTH),
        .WEIGHT_WIDTH    (WEIGHT_WIDTH),
        .PSUM_WIDTH      (PSUM_WIDTH),
        .WEIGHT_SPLIT    (WEIGHT_SPLIT)
    ) array_inst (
        .clk_i          (clk_i),
        .rst_n          (rst_n),
        .array_en       (array_en),
        .act_in         (xbar_out),
        .psum_in        (array_psum_in),
        .psum_out       (array_psum_out),
        .weight_shift_in(weight_shift_in),
        .weight_shift_en(weight_shift_en),
        .swap_weights   (swap_weights)
    );

    // 3. Address & Bank Swap Daisy-Chain Shift Registers
    logic [PSUM_ADDR_WIDTH-1:0] psum_A_addr_col [ARRAY_WIDTH];
    logic [PSUM_ADDR_WIDTH-1:0] psum_B_addr_col [ARRAY_WIDTH];
    logic                       bank_swap_col   [ARRAY_WIDTH];

    reg   [PSUM_ADDR_WIDTH-1:0] pipe_A_addr     [1:ARRAY_WIDTH-1];
    reg   [PSUM_ADDR_WIDTH-1:0] pipe_B_addr     [1:ARRAY_WIDTH-1];
    reg                         pipe_bank_swap  [1:ARRAY_WIDTH-1];

    assign psum_A_addr_col[0] = psum_A_addr;
    assign psum_B_addr_col[0] = psum_B_addr;
    assign bank_swap_col[0]   = compute_bank_swap;

    always_ff @(posedge clk_i or negedge rst_n) begin
        if (!rst_n) begin
            for (int col = 1; col < ARRAY_WIDTH; col++) begin
                pipe_A_addr[col]    <= '0;
                pipe_B_addr[col]    <= '0;
                pipe_bank_swap[col] <= 1'b0;
            end
        end else begin
            pipe_A_addr[1]    <= psum_A_addr_col[0];
            pipe_B_addr[1]    <= psum_B_addr_col[0];
            pipe_bank_swap[1] <= bank_swap_col[0];

            for (int col = 2; col < ARRAY_WIDTH; col++) begin
                pipe_A_addr[col]    <= psum_A_addr_col[col-1];
                pipe_B_addr[col]    <= psum_B_addr_col[col-1];
                pipe_bank_swap[col] <= bank_swap_col[col-1];
            end
        end
    end

    genvar col;
    generate
        for (col = 1; col < ARRAY_WIDTH; col++) begin : gen_col_skew_mux
            assign psum_A_addr_col[col] = psum_skew_en ? pipe_A_addr[col]    : psum_A_addr;
            assign psum_B_addr_col[col] = psum_skew_en ? pipe_B_addr[col]    : psum_B_addr;
            assign bank_swap_col[col]   = psum_skew_en ? pipe_bank_swap[col] : compute_bank_swap;
        end
    endgenerate

    // 4. Memory Routing Logic
    wire signed [ARRAY_WIDTH-1:0][ACTIVATION_WIDTH-1:0] quant_direct_act;

    always_comb begin : blk_mem_routing
        int b_a;
        int b_b;

        for (int i = 0; i < ARRAY_WIDTH; i++) begin
            b_a = i;
            b_b = i + ARRAY_WIDTH;

            array_psum_in[i] = (!bank_swap_col[i]) ? psum_sram_rdata[b_a] : psum_sram_rdata[b_b];

            if (psum_systolic_en) begin
                if (!bank_swap_col[i]) begin
                    psum_sram_addr[b_a]  = psum_A_addr_col[i];
                    psum_sram_we[b_a]    = psum_A_we[i];
                    psum_sram_wdata[b_a] = psum_A_wdata;

                    psum_sram_addr[b_b]  = psum_B_addr_col[i];
                    psum_sram_we[b_b]    = psum_B_we[i];
                    psum_sram_wdata[b_b] = array_psum_out[i];
                end else begin
                    psum_sram_addr[b_b]  = psum_B_addr_col[i];
                    psum_sram_we[b_b]    = psum_B_we[i];
                    psum_sram_wdata[b_b] = psum_B_wdata;

                    psum_sram_addr[b_a]  = psum_A_addr_col[i];
                    psum_sram_we[b_a]    = psum_A_we[i];
                    psum_sram_wdata[b_a] = array_psum_out[i];
                end
            end else if (psum_lut_en) begin
                psum_sram_addr[b_a]  = psum_A_addr_col[i];
                psum_sram_we[b_a]    = psum_A_we[i];
                psum_sram_wdata[b_a] = psum_A_wdata;

                psum_sram_addr[b_b] = $unsigned(quant_direct_act[i]);
                psum_sram_we[b_b]    = 1'b0;
                psum_sram_wdata[b_b] = psum_B_wdata;
            end else begin
                psum_sram_addr[b_a]  = psum_A_addr_col[i];
                psum_sram_we[b_a]    = psum_A_we[i];
                psum_sram_wdata[b_a] = psum_A_wdata;

                psum_sram_addr[b_b]  = psum_B_addr_col[i];
                psum_sram_we[b_b]    = psum_B_we[i];
                psum_sram_wdata[b_b] = psum_B_wdata;
            end
        end
    end

    // 5. Requantizer Core
    wire signed [ARRAY_WIDTH-1:0][PSUM_WIDTH-1:0] drain_psum_data;

    genvar ch;
    generate
        for (ch = 0; ch < ARRAY_WIDTH; ch++) begin : gen_requant_source
            assign drain_psum_data[ch] = psum_sram_rdata[ch];
        end
    endgenerate

    npu_requantizer #(
        .CHANNELS        (ARRAY_WIDTH),
        .PSUM_WIDTH      (PSUM_WIDTH),
        .SCALE_WIDTH     (SCALE_WIDTH),
        .ACTIVATION_WIDTH(ACTIVATION_WIDTH),
        .ENABLE_LFSR     (ENABLE_LFSR)
    ) requant_inst (
        .clk_i              (clk_i),
        .rst_n              (rst_n),
        .psum_in            (drain_psum_data),
        .quant_shift_in     (quant_shift_in),
        .quant_shift_en     (quant_shift_en),
        .stochastic_round_en(stochastic_round_en),
        .lfsr_data_out      (lfsr_data_out),
        .act_out            (quant_direct_act)
    );

    // 6. Direct Outputs
    assign psum_A_rdata = psum_sram_rdata[psum_A_read_bank_sel];
    assign psum_B_rdata = psum_sram_rdata[psum_B_read_bank_sel + ARRAY_WIDTH];

    generate
        for (ch = 0; ch < ARRAY_WIDTH; ch++) begin : gen_act_out
            assign out_act[ch] = psum_lut_en ? psum_sram_rdata[ch + ARRAY_WIDTH][ACTIVATION_WIDTH-1:0]
                                             : quant_direct_act[ch];
        end
    endgenerate

endmodule