# CrocoScale SoC — Physical Floorplan & NPU Macro Architecture

This document specifies the physical floorplan, macro layout, and container macro boundaries for the **CrocoScale SoC** edge AI accelerator (IHP 130nm CMOS5L).

---

## 1. Top-Level Floorplan Map


**SIZING NOT TO SCALE!**
```
+---------------+---------------------------------------------------------------------------------------------+---------------+--------------------------+
|               | NORTH THIN ROUTING CHANNEL (Above Slices 2 & 3)                                             |               |                          |
|               | [<-- West: Into Top of Slice 1]                             [East: Into Top of Slice 4 -->] |               |                          |
|               +---------------------------------------------------+-----------------------------------------+               |                          |
| SLICE 1       | SLICE 2                                           | SLICE 3                                 | SLICE 4       | SLICE 5                  |
|               |                                                   |                                         |               |                          |
|               | eFPGA FABRIC (MACRO)                              | 8x ACT RAM CONTAINERS (MACROS)          | FLAT NPU      | 8x PSUM REQUANT          |
| AXI CONNECTOR | (FABulous 9x16 Grid, 144 CLBs)                    |                                         | LOGIC &       | CONTAINERS (MACROS)      |
| & FIREWALL    |                                                   | +-------------------------------------+ | ROUTING       |                          |
|               | * West Edge: AXI_M_BEL & AXIL_S_BEL               | | act_ram_container [0]               | |               | +----------------------+ |
| * efpga_      | * North Edge: PMOD, NPU Cfg, PSum Bank A          | +-------------------------------------+ | * 8-to-8      | |psum_requant_container| |
|   manager     | * South Edge: Debug Ctrl, PSum Bank B             | | act_ram_container [1]               | |   Crossbar    | |         [0]          | |
| * efpga_      | * East Edge: 8x NPU_SLICE_DATA_SRAM_BEL           | +-------------------------------------+ | * 8x8         | +----------------------+ |
|   connector   |                                                   | | act_ram_container [2]               | |   Systolic    | |psum_requant_container| |
| * Decouplers  |                                                   | +-------------------------------------+ |   Array (PEs) | |         [1]          | |
| * PMP Math    |                                                   | | act_ram_container [3]               | | * 2:1 Compute/| +----------------------+ |
| * Watchdogs   |                                                   | +-------------------------------------+ |   DMA Muxes   | |         ...          | |
| * Bridges     |                                                   | | act_ram_container [4]               | | * Skew &      | +----------------------+ |
|               |                                                   | +-------------------------------------+ |   Pipeline    | |psum_requant_container| |
|               |                                                   | | act_ram_container [5]               | |   Registers   | |         [5]          | |
|               |                                                   | +-------------------------------------+ |               | +----------------------+ |
|               |                                                   | | act_ram_container [6]               | |               | |psum_requant_container| |
|               |                                                   | +-------------------------------------+ |               | |         [6]          | |
|               |                                                   | | act_ram_container [7]               | |               | +----------------------+ |
|               |                                                   | +-------------------------------------+ |               | |psum_requant_container| |
|               +---------------------------------------------------+-----------------------------------------+               | |         [7]          | |
|               | SOUTH ROUTING CHANNEL (Below Slices 2 & 3)                                                  |               | +----------------------+ |
|               | [<-- West: Into Bottom of Slice 1]                       [East: Into Bottom of Slice 4 -->] |               |                          |
+---------------+---------------------------------------------------------------------------------------------+---------------+--------------------------+
```
**SIZING NOT TO SCALE!**



---

## 2. Container Macro: `act_ram_container` (Slice 3)

8 identical macro instances stacked vertically in **Slice 3**. Each container macro wraps 1× IHP SG13G2 512×8 single-port SRAM hard macro ($R90$ orientation) along with standard-cell feedthrough channels connecting the FPGA East edge directly to the Flat NPU (Slice 4).


**SIZING NOT TO SCALE!**
```
+---------------------------------------------------------------------------------------------------+
| CONTAINER MACRO: act_ram_container                                                                |
| (Physical Slice 3 Unit: 8 Instances Stacked Vertically)                                           |
+---------------------------------------------------------------------------------------------------+
| WEST PINS (from/to FPGA East Edge)                                       EAST PINS (to/from NPU)  |
|                                                                                                   |
|                                    +--------------------------+                                   |
| act_addr[8:0] -------------------> | [ADDR]                   |                                   |
|                                    |                          |                                   |
| act_we --------------------------> | [WE]                     |                                   |
|                                    |                          |                                   |
| act_wdata[7:0]  -----------------> | [DIN]                    |                                   |
|                                    |                          |                                   |
|                                    |                          |                                   |
|                                    |                          |                                   |
|                                    |                          |                                   |
|                                    |                          |                                   |
|                                    |                          |                                   |
|                                    | RM_IHPSG13_1P_512x8      |                                   |
|                                    | (512x8 Single-Port SRAM) |                                   |
|                                    |                          |                                   |
|                                    | (All ports on left face) |                                   |
|                                    |                          |                                   |
| act_rdata[7:0] <--------+--------- | [DOUT]                   |                                   |
|                         |          +--------------------------+                                   |
|                         |                                                                         |
|                         |                                                                         |
|                         +-----------------------------------------------------------------------> |
|                                                                                                   |
|                                    FEEDTHROUGH CHANNELS (below macro)                             |
| weight_in[7:0]  ==============================================================> weight_in[7:0]    |
| weight_shift_en ==============================================================> weight_shift_en   |
| xbar_sel[3:0]   ==============================================================> xbar_sel[3:0]     |
| out_act[7:0]    <============================================================== out_act[7:0]      |
|                                                                                                   |
+---------------------------------------------------------------------------------------------------+
```
**SIZING NOT TO SCALE!**


---

## 3. Container Macro: `psum_requant_container` (Slice 5)

8 identical composite macro instances stacked vertically in **Slice 5**. Each container macro encapsulates 2× IHP SG13G2 256×32 single-port SRAM hard macros (Bank A and Bank B mirrored $MX$) and 1× standard-cell Requantizer Lane. 

Bank A read data (`rdata`) connects **internally** directly to the Requantizer Lane input, eliminating 256 long global routing wires crossing standard-cell routing channels.


**SIZING NOT TO SCALE!**
```
+---------------------------------------------------------------------------------------------------+
| CONTAINER MACRO: psum_requant_container                                                           |
| (Physical Slice 5 Unit: 8 Instances Stacked Vertically)                                           |
+---------------------------------------------------------------------------------------------------+
| WEST PINS (All 202 Interface Pins Face West at X=0, Facing Slice 4)            EAST (Closed Edge) |
|                                                                                                   |
|                                               +-----------------------------------------------+   |
|                                               | Bank A SRAM: RM_IHPSG13_1P_256x32             |   |
|                                               | [ADDR]     [WE]     [WDATA]       [RDATA]     |   |
|                                               +---+----------+---------+-------------+--------+   |
| (Pins Face DOWN)                                  |          |         |             |            |
| bank_A_addr[7:0] -------------------------------->+          |         |             |            |
| bank_A_we -------------------------------------------------->+         |             |            |
| bank_A_wdata[31:0] --------------------------------------------------->+             |            |
| bank_A_rdata[31:0] <-----------------------------------------------------------------+            |
|                                                       (Direct Internal Wire) --------+            |
|                                                       (Bank A rdata -> psum_in)      v            |
|                       . - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - .       |
| quant_cfg[29:0] ----> :  Requantizer Lane (Standard-Cell Logic — No Hard Macro Box)       :       |
|                       :  Stage 1: Fixed-Point Multiplier (psum_in * scale_m0)             :       |
|                       :  Stage 2: Round-Half-Away-From-Zero / Stochastic LFSR Noise       :       |
| out_act[7:0] <--------:  Stage 3: Arithmetic Right-Shift & Saturation Clamp               :       |
|                       ' - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - '       |
| bank_B_rdata[31:0] <-----------------------------------------------------------------+            |
| bank_B_wdata[31:0] --------------------------------------------------->+             |            |
| bank_B_we -------------------------------------------------->+         |             |            |
| bank_B_addr[7:0] -------------------------------->+          |         |             |            |
|                                                   v          v         v             |            |
|                                               +---+----------+---------+-------------+--------+   |
|                                               | [ADDR]     [WE]     [WDATA]       [RDATA]     |   |
|                                               | Bank B SRAM: RM_IHPSG13_1P_256x32             |   |
|                                               +-----------------------------------------------+   |
|                                                                                                   |
+---------------------------------------------------------------------------------------------------+
```
**SIZING NOT TO SCALE!**