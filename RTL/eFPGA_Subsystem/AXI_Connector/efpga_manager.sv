`timescale 1ns / 1ps

/* ===============================================================================================
 * eFPGA Manager Register Map
 * ===============================================================================================
 * Total Address Space: 64 KB
 *
 * 1. GLOBAL REGISTERS (Base Address: 0x0000)
 * -----------------------------------------------------------------------------------------------
 * Offset | Register Name  | R/W | Description / Bit Mapping
 * -------|----------------|-----|----------------------------------------------------------------
 * 0x000  | HW_VERSION     | R   | [31:0]: Hardware Version ID (Returns HW_VERSION parameter)
 * 0x004  | GLOBAL_CTRL    | R/W | [2]: User Design Loaded (R/W) | [1]: Com Active (R) | [0]: Soft Reset (R/W)
 * 0x008  | CONFIG_DATA    | W   | [31:0]: Config Payload (Writing here pulses config WE)
 * 0x00C  | CONFIG_COUNT   | R   | [31:0]: Number of words written to CONFIG_DATA
 *
 * 2. PER-SLOT REGISTERS (Base Address: 0x1000 + (Slot_Index * 0x1000))
 *    Example: Slot 0 starts at 0x1000, Slot 1 starts at 0x2000.
 * -----------------------------------------------------------------------------------------------
 * Offset | Register Name  | R/W | Description / Bit Mapping
 * -------|----------------|-----|----------------------------------------------------------------
 * 0x000  | SLOT_CTRL      | R/W | [25:24]: WB M/S En | [19:16]: Wdog Mod En [CM, DS, CS, DM] | [8]: PMP En | [1:0]: Decouple Frc/Req
 * 0x004  | SLOT_STATUS    | R   | [20:16]: Wdog Faults [SoC, C-TO, C-PR, D-TO, D-PR] | [9:8]: PMP W/R Faults | [2:0]: Act/Dec Status
 * 0x008  | FAULT_CLEAR    | W   | [20:16]: Clear Wdogs [SoC, C-TO, C-PR, D-TO, D-PR] | [9:8]: Clear PMP W/R
 * 0x00C  | DEBUG_OUT      | R/W | [31:0]: Static output wires driven to the eFPGA fabric
 * 0x010  | DEBUG_IN       | R   | [31:0]: Static input wires read from the eFPGA fabric
 *
 * 3. DYNAMIC PMP REGISTERS (Base Address: 0x1000 + (Slot_Index * 0x1000) + 0x014)
 *    [!] Security Lock: PMP registers are READ-ONLY unless the slot is actively decoupled.
 * -----------------------------------------------------------------------------------------------
 * Offset | Register Name  | R/W | Description / Bit Mapping
 * -------|----------------|-----|----------------------------------------------------------------
 * 0x014  | PMP_BASE_0     | R/W*| [31:0]: Base address for PMP Region 0
 * 0x018  | PMP_LIMIT_0    | R/W*| [31:0]: Limit address for PMP Region 0 (Lower bits overloaded for PROT)
 * 0x01C  | PMP_BASE_1     | R/W*| [31:0]: Base address for PMP Region 1
 * 0x020  | PMP_LIMIT_1    | R/W*| [31:0]: Limit address for PMP Region 1 (Lower bits overloaded for PROT)
 *  ...   | ...            | ... | Pattern repeats for NUM_REGIONS...
 * =============================================================================================== */

module efpga_manager #(
    parameter int NUM_SLOTS = 1,
    parameter int NUM_REGIONS = 2,
    parameter logic [31:0] HW_VERSION = 32'hFAB00001,
    parameter bit PAGE_GRANULARITY = 1'b1,
    parameter int MAX_ADDRESS_WIDTH = 32,
    
    // --- Hardware Discovery Parameters ---
    parameter bit ENABLE_PMP              = 1'b1,
    parameter bit ENABLE_WDOG_CTRL_SLAVE  = 1'b1,
    parameter bit ENABLE_WDOG_DMA_MASTER  = 1'b1,
    parameter bit ENABLE_WDOG_CTRL_MASTER = 1'b0,
    parameter bit ENABLE_WDOG_DMA_SLAVE   = 1'b0,
    parameter bit ENABLE_BRIDGE_CTRL      = 1'b0,
    parameter bit ENABLE_BRIDGE_DMA       = 1'b0
) (
    input  logic        clk_i,
    input  logic        rstn_i,
    
    // --- AXI4-Lite Slave Interface ---
    input  logic [31:0] s_axil_awaddr, input  logic [2:0]  s_axil_awprot, input  logic        s_axil_awvalid, output logic        s_axil_awready,
    input  logic [31:0] s_axil_wdata,  input  logic [3:0]  s_axil_wstrb,  input  logic        s_axil_wvalid,  output logic        s_axil_wready,
    output logic [1:0]  s_axil_bresp,  output logic        s_axil_bvalid, input  logic        s_axil_bready,
    input  logic [31:0] s_axil_araddr, input  logic [2:0]  s_axil_arprot, input  logic        s_axil_arvalid, output logic        s_axil_arready,
    output logic [31:0] s_axil_rdata,  output logic [1:0]  s_axil_rresp,  output logic        s_axil_rvalid,  input  logic        s_axil_rready,
    
    // --- Global eFPGA Interfacing ---
    output logic [31:0] efpga_config_data_o, output logic efpga_config_we_o, output logic efpga_soft_reset_o, input logic efpga_com_active_i,
    
    // --- Per-Slot Control Arrays ---
    input  logic [NUM_SLOTS-1:0][31:0] slot_i_top_i,
    output logic [NUM_SLOTS-1:0][31:0] slot_o_top_o,
    
    output logic [NUM_SLOTS-1:0]       decoupler_req_o,
    output logic [NUM_SLOTS-1:0]       decoupler_force_o,
    input  logic [NUM_SLOTS-1:0]       decoupler_is_decoupled_i,
    input  logic [NUM_SLOTS-1:0]       decoupler_host_act_i,
    input  logic [NUM_SLOTS-1:0]       decoupler_dma_act_i,

    input  logic [NUM_SLOTS-1:0]       slot_pmp_r_violation_i,
    input  logic [NUM_SLOTS-1:0]       slot_pmp_w_violation_i,
    
    // Watchdog Inputs
    input  logic [NUM_SLOTS-1:0] slot_wdog_cs_to_w_i, input logic [NUM_SLOTS-1:0] slot_wdog_cs_to_r_i, input logic [NUM_SLOTS-1:0] slot_wdog_cs_pr_w_i, input logic [NUM_SLOTS-1:0] slot_wdog_cs_pr_r_i,
    input  logic [NUM_SLOTS-1:0] slot_wdog_dm_to_w_i, input logic [NUM_SLOTS-1:0] slot_wdog_dm_to_r_i, input logic [NUM_SLOTS-1:0] slot_wdog_dm_pr_w_i, input logic [NUM_SLOTS-1:0] slot_wdog_dm_pr_r_i,
    input  logic [NUM_SLOTS-1:0] slot_wdog_cm_to_w_i, input logic [NUM_SLOTS-1:0] slot_wdog_cm_to_r_i, input logic [NUM_SLOTS-1:0] slot_wdog_cm_pr_w_i, input logic [NUM_SLOTS-1:0] slot_wdog_cm_pr_r_i,
    input  logic [NUM_SLOTS-1:0] slot_wdog_ds_to_w_i, input logic [NUM_SLOTS-1:0] slot_wdog_ds_to_r_i, input logic [NUM_SLOTS-1:0] slot_wdog_ds_pr_w_i, input logic [NUM_SLOTS-1:0] slot_wdog_ds_pr_r_i,
    
    // --- PMP Outputs (Parametric Array) ---
    output logic [NUM_SLOTS-1:0]                               pmp_g_en_o,
    output logic [NUM_SLOTS-1:0][NUM_REGIONS-1:0][31:0]        pmp_base_o,
    output logic [NUM_SLOTS-1:0][NUM_REGIONS-1:0][31:0]        pmp_limit_o,
    
    // --- Wishbone Bridge Enables ---
    output logic [NUM_SLOTS-1:0] wb_s_enable_o,
    output logic [NUM_SLOTS-1:0] wb_m_enable_o,

    // --- Fault Interrupt Line ---
    output logic [NUM_SLOTS-1:0] slot_fault_irq_o
);

    localparam int ADDR_SHIFT = PAGE_GRANULARITY ? 12 : 2;
    localparam int COMP_WIDTH = MAX_ADDRESS_WIDTH - ADDR_SHIFT;

    wire [15:0] local_awaddr = s_axil_awaddr[15:0];
    wire [15:0] local_araddr = s_axil_araddr[15:0];
    wire [3:0]  aw_slot_idx  = (local_awaddr - 16'h1000) >> 12;
    wire [3:0]  ar_slot_idx  = (local_araddr - 16'h1000) >> 12;

    // AXI Registers
    logic axi_awready, axi_wready, axi_bvalid, axi_arready, axi_rvalid;
    logic [31:0] axi_rdata;

    assign s_axil_awready = axi_awready; assign s_axil_wready = axi_wready; assign s_axil_bvalid = axi_bvalid; assign s_axil_bresp = 2'b00; 
    assign s_axil_arready = axi_arready; assign s_axil_rvalid = axi_rvalid; assign s_axil_rdata  = axi_rdata;  assign s_axil_rresp = 2'b00; 

    // Global Registers
    logic [31:0] config_count_reg;
    logic soft_reset_reg, user_design_loaded_reg, com_active_q; 
    
    // Per-Slot Registers
    logic [NUM_SLOTS-1:0]       dec_req_reg, dec_force_reg;
    logic [NUM_SLOTS-1:0]       pmp_r_flag_reg, pmp_w_flag_reg, pmp_g_en_reg;
    logic [NUM_SLOTS-1:0]       wb_s_enable_reg, wb_m_enable_reg;
    logic [NUM_SLOTS-1:0][31:0] slot_o_top_reg;
    
    // Watchdog MODULE Enables [19:16]
    logic [NUM_SLOTS-1:0] wdog_en_dm, wdog_en_cs, wdog_en_ds, wdog_en_cm;
    // Watchdog FAULT Status Flags [20:16]
    logic [NUM_SLOTS-1:0] wdog_dm_pr_flag, wdog_dm_to_flag, wdog_cs_pr_flag, wdog_cs_to_flag, wdog_soc_flag;
    
    // TRIMMED PMP STORAGE REGISTERS
    logic [NUM_SLOTS-1:0][NUM_REGIONS-1:0][COMP_WIDTH-1:0] pmp_base_addr_reg;
    logic [NUM_SLOTS-1:0][NUM_REGIONS-1:0][1:0]            pmp_base_cfg_reg;
    logic [NUM_SLOTS-1:0][NUM_REGIONS-1:0][COMP_WIDTH-1:0] pmp_limit_addr_reg;
    logic [NUM_SLOTS-1:0][NUM_REGIONS-1:0][1:0]            pmp_limit_cfg_reg;

    assign efpga_soft_reset_o = soft_reset_reg;
    assign slot_o_top_o       = slot_o_top_reg;
    assign decoupler_req_o    = dec_req_reg;
    assign pmp_g_en_o         = pmp_g_en_reg;
    assign wb_s_enable_o      = wb_s_enable_reg;
    assign wb_m_enable_o      = wb_m_enable_reg;
    
    // Watchdog MASKED Combinational Aggregation
    logic [NUM_SLOTS-1:0] raw_dm_pr, raw_dm_to, raw_cs_pr, raw_cs_to, raw_soc;
    always_comb begin
        for (int j = 0; j < NUM_SLOTS; j++) begin
            raw_dm_pr[j] = (slot_wdog_dm_pr_w_i[j] | slot_wdog_dm_pr_r_i[j]) & wdog_en_dm[j];
            raw_dm_to[j] = (slot_wdog_dm_to_w_i[j] | slot_wdog_dm_to_r_i[j]) & wdog_en_dm[j];
            
            raw_cs_pr[j] = (slot_wdog_cs_pr_w_i[j] | slot_wdog_cs_pr_r_i[j]) & wdog_en_cs[j];
            raw_cs_to[j] = (slot_wdog_cs_to_w_i[j] | slot_wdog_cs_to_r_i[j]) & wdog_en_cs[j];
            
            raw_soc[j]   = ((slot_wdog_cm_to_w_i[j] | slot_wdog_cm_to_r_i[j] | slot_wdog_cm_pr_w_i[j] | slot_wdog_cm_pr_r_i[j]) & wdog_en_cm[j]) |
                           ((slot_wdog_ds_to_w_i[j] | slot_wdog_ds_to_r_i[j] | slot_wdog_ds_pr_w_i[j] | slot_wdog_ds_pr_r_i[j]) & wdog_en_ds[j]);
        end
    end

    genvar i, r;
    generate
        for (i = 0; i < NUM_SLOTS; i++) begin : gen_pmp_out
            for (r = 0; r < NUM_REGIONS; r++) begin : gen_pmp_out_r
                assign pmp_base_o[i][r]  = { {(32-MAX_ADDRESS_WIDTH){1'b0}}, pmp_base_addr_reg[i][r], {(ADDR_SHIFT-2){1'b0}}, pmp_base_cfg_reg[i][r] };
                assign pmp_limit_o[i][r] = { {(32-MAX_ADDRESS_WIDTH){1'b0}}, pmp_limit_addr_reg[i][r], {(ADDR_SHIFT-2){1'b0}}, pmp_limit_cfg_reg[i][r] };
            end
            
            assign decoupler_force_o[i] = dec_force_reg[i] | 
                                          raw_dm_pr[i] | raw_dm_to[i] | raw_cs_pr[i] | raw_cs_to[i] | raw_soc[i] |
                                          wdog_dm_pr_flag[i] | wdog_dm_to_flag[i] | wdog_cs_pr_flag[i] | wdog_cs_to_flag[i] | wdog_soc_flag[i] |
                                          slot_pmp_r_violation_i[i] | pmp_r_flag_reg[i] |
                                          slot_pmp_w_violation_i[i] | pmp_w_flag_reg[i];

            assign slot_fault_irq_o[i]   = pmp_r_flag_reg[i]  | pmp_w_flag_reg[i]  |
                                          wdog_dm_to_flag[i] | wdog_dm_pr_flag[i] |
                                          wdog_cs_to_flag[i] | wdog_cs_pr_flag[i] | wdog_soc_flag[i];
        end
    endgenerate

    wire axi_write_en = (s_axil_awvalid && s_axil_wvalid && !axi_awready && !axi_wready && !axi_bvalid);
    
    // Clear Pulses
    logic [NUM_SLOTS-1:0] clr_pmp_r, clr_pmp_w, clr_dm_pr, clr_dm_to, clr_cs_pr, clr_cs_to, clr_soc;
    always_comb begin
        clr_pmp_r = '0; clr_pmp_w = '0; clr_dm_pr = '0; clr_dm_to = '0; clr_cs_pr = '0; clr_cs_to = '0; clr_soc = '0;
        if (axi_write_en && (local_awaddr >= 16'h1000) && aw_slot_idx < NUM_SLOTS) begin
            if ((local_awaddr[11:0] & 12'hFFC) == 12'h008) begin // FAULT_CLEAR
                if (s_axil_wstrb[1] && s_axil_wdata[8])  clr_pmp_r[aw_slot_idx] = 1'b1;
                if (s_axil_wstrb[1] && s_axil_wdata[9])  clr_pmp_w[aw_slot_idx] = 1'b1;
                if (s_axil_wstrb[2] && s_axil_wdata[16]) clr_dm_pr[aw_slot_idx] = 1'b1;
                if (s_axil_wstrb[2] && s_axil_wdata[17]) clr_dm_to[aw_slot_idx] = 1'b1;
                if (s_axil_wstrb[2] && s_axil_wdata[18]) clr_cs_pr[aw_slot_idx] = 1'b1;
                if (s_axil_wstrb[2] && s_axil_wdata[19]) clr_cs_to[aw_slot_idx] = 1'b1;
                if (s_axil_wstrb[2] && s_axil_wdata[20]) clr_soc[aw_slot_idx]   = 1'b1;
            end
        end
    end

    // PMP Register Address Decoding & Write Byte-Strobe Staging
    wire [11:0] pmp_aw_offset     = (local_awaddr[11:0] & 12'hFFC) - 12'h014;
    wire [7:0]  pmp_aw_region_idx = pmp_aw_offset[10:3];

    wire [11:0] pmp_ar_offset     = (local_araddr[11:0] & 12'hFFC) - 12'h014;
    wire [7:0]  pmp_ar_region_idx = pmp_ar_offset[10:3];

    logic [31:0] pmp_w_curr_val;
    logic [31:0] pmp_w_next_val;

    always_comb begin
        pmp_w_curr_val = 32'b0;
        if (ENABLE_PMP && (aw_slot_idx < NUM_SLOTS) && (pmp_aw_region_idx < NUM_REGIONS)) begin
            pmp_w_curr_val = (pmp_aw_offset[2] == 1'b0) ? pmp_base_o[aw_slot_idx][pmp_aw_region_idx]
                                                        : pmp_limit_o[aw_slot_idx][pmp_aw_region_idx];
        end
        pmp_w_next_val[7:0]   = s_axil_wstrb[0] ? s_axil_wdata[7:0]   : pmp_w_curr_val[7:0];
        pmp_w_next_val[15:8]  = s_axil_wstrb[1] ? s_axil_wdata[15:8]  : pmp_w_curr_val[15:8];
        pmp_w_next_val[23:16] = s_axil_wstrb[2] ? s_axil_wdata[23:16] : pmp_w_curr_val[23:16];
        pmp_w_next_val[31:24] = s_axil_wstrb[3] ? s_axil_wdata[31:24] : pmp_w_curr_val[31:24];
    end

    // AXI WRITE State Machine
    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin
            axi_awready <= 1'b0; axi_wready <= 1'b0; axi_bvalid <= 1'b0;
            config_count_reg <= '0; efpga_config_data_o <= '0;
            efpga_config_we_o <= 1'b0; soft_reset_reg <= 1'b0; user_design_loaded_reg <= 1'b0; com_active_q <= 1'b0;
            dec_req_reg <= '1; dec_force_reg <= '0; 
            pmp_r_flag_reg <= '0; pmp_w_flag_reg <= '0; pmp_g_en_reg <= '0; slot_o_top_reg <= '0;
            wb_s_enable_reg <= '0; wb_m_enable_reg <= '0; 
            pmp_base_addr_reg <= '0; pmp_base_cfg_reg <= '0; pmp_limit_addr_reg <= '0; pmp_limit_cfg_reg <= '0;
            
            // HARDWARE DISCOVERY: Uninstantiated MODULES reset to 0 and remain un-writable!
            wdog_en_dm <= ENABLE_WDOG_DMA_MASTER ? '1 : '0; 
            wdog_en_cs <= ENABLE_WDOG_CTRL_SLAVE ? '1 : '0; 
            wdog_en_ds <= ENABLE_WDOG_DMA_SLAVE  ? '1 : '0;
            wdog_en_cm <= ENABLE_WDOG_CTRL_MASTER? '1 : '0;
            
            wdog_dm_pr_flag <= '0; wdog_dm_to_flag <= '0; wdog_cs_pr_flag <= '0; wdog_cs_to_flag <= '0; wdog_soc_flag <= '0;
        end else begin
            efpga_config_we_o <= 1'b0; com_active_q <= efpga_com_active_i;
            
            // Fault Status Flags (Sticky Registers)
            for (int j = 0; j < NUM_SLOTS; j++) begin
                if (raw_dm_pr[j]) wdog_dm_pr_flag[j] <= 1'b1; else if (clr_dm_pr[j]) wdog_dm_pr_flag[j] <= 1'b0;
                if (raw_dm_to[j]) wdog_dm_to_flag[j] <= 1'b1; else if (clr_dm_to[j]) wdog_dm_to_flag[j] <= 1'b0;
                if (raw_cs_pr[j]) wdog_cs_pr_flag[j] <= 1'b1; else if (clr_cs_pr[j]) wdog_cs_pr_flag[j] <= 1'b0;
                if (raw_cs_to[j]) wdog_cs_to_flag[j] <= 1'b1; else if (clr_cs_to[j]) wdog_cs_to_flag[j] <= 1'b0;
                if (raw_soc[j])   wdog_soc_flag[j]   <= 1'b1; else if (clr_soc[j])   wdog_soc_flag[j]   <= 1'b0;
                
                if (slot_pmp_r_violation_i[j]) pmp_r_flag_reg[j] <= 1'b1; else if (clr_pmp_r[j]) pmp_r_flag_reg[j] <= 1'b0;
                if (slot_pmp_w_violation_i[j]) pmp_w_flag_reg[j] <= 1'b1; else if (clr_pmp_w[j]) pmp_w_flag_reg[j] <= 1'b0;
            end

            if (axi_write_en) begin
                axi_awready <= 1'b1; axi_wready <= 1'b1; axi_bvalid <= 1'b1;
                
                if (local_awaddr < 16'h1000) begin
                    case (local_awaddr[11:0] & 12'hFFC) 
                        12'h004: if (s_axil_wstrb[0]) begin soft_reset_reg <= s_axil_wdata[0]; user_design_loaded_reg <= s_axil_wdata[2]; end
                        12'h008: begin config_count_reg <= config_count_reg + 1; efpga_config_data_o <= s_axil_wdata; efpga_config_we_o <= 1'b1; user_design_loaded_reg <= 1'b1; end
                        default: ;
                    endcase
                end else begin
                    if (aw_slot_idx < NUM_SLOTS) begin
                        if ((local_awaddr[11:0] & 12'hFFC) < 12'h014) begin
                            case (local_awaddr[11:0] & 12'hFFC)
                                12'h000: begin 
                                     if (s_axil_wstrb[0]) begin dec_req_reg[aw_slot_idx] <= s_axil_wdata[0]; dec_force_reg[aw_slot_idx] <= s_axil_wdata[1]; end
                                     if (s_axil_wstrb[1]) begin
                                         if (ENABLE_PMP) pmp_g_en_reg[aw_slot_idx] <= s_axil_wdata[8];
                                     end
                                     // Hardware Discovery: MODULE Enables
                                     if (s_axil_wstrb[2]) begin 
                                         if (ENABLE_WDOG_DMA_MASTER)  wdog_en_dm[aw_slot_idx] <= s_axil_wdata[16];
                                         if (ENABLE_WDOG_CTRL_SLAVE)  wdog_en_cs[aw_slot_idx] <= s_axil_wdata[17];
                                         if (ENABLE_WDOG_DMA_SLAVE)   wdog_en_ds[aw_slot_idx] <= s_axil_wdata[18];
                                         if (ENABLE_WDOG_CTRL_MASTER) wdog_en_cm[aw_slot_idx] <= s_axil_wdata[19];
                                     end
                                     if (s_axil_wstrb[3]) begin 
                                         if (ENABLE_BRIDGE_CTRL) wb_s_enable_reg[aw_slot_idx] <= s_axil_wdata[24]; 
                                         if (ENABLE_BRIDGE_DMA)  wb_m_enable_reg[aw_slot_idx] <= s_axil_wdata[25]; 
                                     end
                                end
                                12'h00C: begin 
                                     if (s_axil_wstrb[0]) slot_o_top_reg[aw_slot_idx][7:0]   <= s_axil_wdata[7:0];
                                     if (s_axil_wstrb[1]) slot_o_top_reg[aw_slot_idx][15:8]  <= s_axil_wdata[15:8];
                                     if (s_axil_wstrb[2]) slot_o_top_reg[aw_slot_idx][23:16] <= s_axil_wdata[23:16];
                                     if (s_axil_wstrb[3]) slot_o_top_reg[aw_slot_idx][31:24] <= s_axil_wdata[31:24];
                                end
                                default: ;
                            endcase
                        end else if (decoupler_is_decoupled_i[aw_slot_idx] && ENABLE_PMP) begin
                            if (pmp_aw_region_idx < NUM_REGIONS) begin
                                if (pmp_aw_offset[2] == 1'b0) begin
                                    pmp_base_addr_reg[aw_slot_idx][pmp_aw_region_idx] <= pmp_w_next_val[MAX_ADDRESS_WIDTH-1 : ADDR_SHIFT];
                                    pmp_base_cfg_reg[aw_slot_idx][pmp_aw_region_idx]  <= pmp_w_next_val[1:0];
                                end else begin
                                    pmp_limit_addr_reg[aw_slot_idx][pmp_aw_region_idx] <= pmp_w_next_val[MAX_ADDRESS_WIDTH-1 : ADDR_SHIFT];
                                    pmp_limit_cfg_reg[aw_slot_idx][pmp_aw_region_idx]  <= pmp_w_next_val[1:0];
                                end
                            end
                        end
                    end
                end
            end else begin
                axi_awready <= 1'b0; axi_wready  <= 1'b0;
            end
            if (s_axil_bready && axi_bvalid) axi_bvalid <= 1'b0; 
        end
    end

    // AXI READ State Machine
    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin
            axi_arready <= 1'b0; axi_rvalid  <= 1'b0; axi_rdata  <= 32'h00000000;
        end else begin
            if (s_axil_arvalid && !axi_arready && !axi_rvalid) begin
                axi_arready <= 1'b1; axi_rvalid  <= 1'b1; 
                
                if (local_araddr < 16'h1000) begin
                    case (local_araddr[11:0] & 12'hFFC)
                        12'h000: axi_rdata <= HW_VERSION;
                        12'h004: axi_rdata <= {29'd0, user_design_loaded_reg, efpga_com_active_i, soft_reset_reg};
                        12'h008: axi_rdata <= 32'h00000000;
                        12'h00C: axi_rdata <= config_count_reg;
                        default: axi_rdata <= 32'hBAD00000;
                    endcase
                end else begin
                    if (ar_slot_idx < NUM_SLOTS) begin
                        if ((local_araddr[11:0] & 12'hFFC) < 12'h014) begin
                            case (local_araddr[11:0] & 12'hFFC)
                                12'h000: axi_rdata <= { 
                                    6'd0, wb_m_enable_reg[ar_slot_idx], wb_s_enable_reg[ar_slot_idx], 
                                    4'd0, wdog_en_cm[ar_slot_idx], wdog_en_ds[ar_slot_idx], wdog_en_cs[ar_slot_idx], wdog_en_dm[ar_slot_idx],
                                    7'd0, pmp_g_en_reg[ar_slot_idx],                                   
                                    6'd0, dec_force_reg[ar_slot_idx], dec_req_reg[ar_slot_idx]        
                                };
                                12'h004: axi_rdata <= {
                                    11'd0, wdog_soc_flag[ar_slot_idx], wdog_cs_to_flag[ar_slot_idx], wdog_cs_pr_flag[ar_slot_idx], wdog_dm_to_flag[ar_slot_idx], wdog_dm_pr_flag[ar_slot_idx], 
                                    6'd0, pmp_w_flag_reg[ar_slot_idx], pmp_r_flag_reg[ar_slot_idx], 
                                    5'd0, decoupler_dma_act_i[ar_slot_idx], decoupler_host_act_i[ar_slot_idx], decoupler_is_decoupled_i[ar_slot_idx]
                                };
                                12'h008: axi_rdata <= 32'h00000000; // FAULT_CLEAR is WO
                                12'h00C: axi_rdata <= slot_o_top_reg[ar_slot_idx]; // DEBUG_OUT
                                12'h010: axi_rdata <= slot_i_top_i[ar_slot_idx];   // DEBUG_IN
                                default: axi_rdata <= 32'hBAD00001; 
                            endcase
                        end else if (ENABLE_PMP) begin
                            if (pmp_ar_region_idx < NUM_REGIONS) begin
                                if (pmp_ar_offset[2] == 1'b0) axi_rdata <= pmp_base_o[ar_slot_idx][pmp_ar_region_idx];
                                else                          axi_rdata <= pmp_limit_o[ar_slot_idx][pmp_ar_region_idx];
                            end else begin
                                axi_rdata <= 32'hBAD00002;
                            end
                        end else begin
                            axi_rdata <= 32'h00000000;
                        end
                    end else axi_rdata <= 32'hBAD00003;
                end
            end else begin
                axi_arready <= 1'b0;
                if (s_axil_rready && axi_rvalid) axi_rvalid <= 1'b0;
            end
        end
    end

endmodule