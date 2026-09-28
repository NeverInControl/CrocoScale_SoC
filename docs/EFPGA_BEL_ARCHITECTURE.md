# CrocoScale 8x16 eFPGA Fabric — Custom BEL Library Specification

This document specifies the decoupled, orientation-agnostic Boundary Element (BEL) library for the $8 \times 16$ CLB eFPGA soft-fabric.

---

## 1. Complete Redone BEL Library (7 Generic BELs)

Organized under the 4 standard domain prefixes (`AXI`/`AXIL`, `EXT`, `SOC`, `NPU`):

| Domain | BEL File Name | Module Name | Internal Latency | Function | Primary Instantiating Tiles |
| :--- | :--- | :--- | :---: | :--- | :--- |
| **`AXI_`** | `AXI_M_BEL.v` | `AXI_M_BEL` | **0 cycles** (Async) | 32-bit AXI4 DMA Master to SoC Crossbar | `AXI_M_IO_W` (West, Rows 0..9) |
| **`AXIL_`** | `AXIL_S_BEL.v` | `AXIL_S_BEL` | **0 cycles** (Async) | 32-bit AXI4-Lite Control Slave from CPU / Manager | `AXIL_S_IO_W` (West, Rows 10..15) |
| **`EXT_`** | `EXT_PMOD_BEL.v` | `EXT_PMOD_BEL` | **Registered** (`UserCLK`) | Bidirectional 8-bit PMOD external padring | `PMOD_IO_N` (North, Cols 1..2) |
| **`SOC_`** | `SOC_DEBUG_CTRL_BEL.v` | `SOC_DEBUG_CTRL_BEL` | **Registered** (`UserCLK`) | Slot debug I/O, SoC user interrupts, and soft resets | `DEBUG_IO_S_0` .. `_3` (South, Cols 1..4) |
| **`NPU_`** | `NPU_SLICE_DATA_SRAM_BEL.v` | `NPU_SLICE_DATA_SRAM_BEL` | **Registered** (`UserCLK`) | Row $i$ Slice: Data/Act SRAM R/W, row weights, per-row shift enable, crossbar select, and output activations | `ACT_RAM_IO_E` (East, 8 $\times$ 2-row supertiles) |
| **`NPU_`** | `NPU_ACCUM_SRAM_BEL.v` | `NPU_ACCUM_SRAM_BEL` | **Registered** (`UserCLK`) | 32-bit Accumulator / Non-Linear LUT SRAM Port ($256 \times 32$) | `PSUM_PORT_N` (North Bank A, Cols 5..8)<br>`PSUM_PORT_S` (South Bank B, Cols 5..8) |
| **`NPU_`** | `NPU_CTRL_CFG_BEL.v` | `NPU_CTRL_CFG_BEL` | **Registered** (`UserCLK`) | Global array execution controls & Requantizer serial configuration chain | `REQUANT_AUX_N` (North, Cols 3..4) |

---

## 2. Fabric Tile Perimeter Allocation & Density Table

```
                  Col 1    Col 2    Col 3    Col 4    Col 5    Col 6    Col 7    Col 8
                 +--------+--------+--------+--------+--------+--------+--------+--------+
      NORTH EDGE |  PMOD_IO (2 Cols) | REQUANT_AUX(2) |     PSUM_PORT Bank A (4 Cols)  |
                 +--------+--------+--------+--------+--------+--------+--------+--------+
Row 0   (AXI-M)  |                                                                       | ACT_RAM_IO_0 (2 Rows)
Row 1   (AXI-M)  |                                                                       |
Row 2   (AXI-M)  |                                                                       | ACT_RAM_IO_1 (2 Rows)
Row 3   (AXI-M)  |                                                                       |
Row 4   (AXI-M)  |                                                                       | ACT_RAM_IO_2 (2 Rows)
Row 5   (AXI-M)  |                                                                       |
Row 6   (AXI-M)  |                        CORE CLB FABRIC                                | ACT_RAM_IO_3 (2 Rows)
Row 7   (AXI-M)  |                      8 COLS x 16 ROWS                                 |
Row 8   (AXI-M)  |                         (128 CLBs)                                    | ACT_RAM_IO_4 (2 Rows)
Row 9   (AXI-M)  |                                                                       |
Row 10  (AXIL-S) |                                                                       | ACT_RAM_IO_5 (2 Rows)
Row 11  (AXIL-S) |                                                                       |
Row 12  (AXIL-S) |                                                                       | ACT_RAM_IO_6 (2 Rows)
Row 13  (AXIL-S) |                                                                       |
Row 14  (AXIL-S) |                                                                       | ACT_RAM_IO_7 (2 Rows)
Row 15  (AXIL-S) |                                                                       |
                 +--------+--------+--------+--------+--------+--------+--------+--------+
      SOUTH EDGE | DEBUG0 | DEBUG1 | DEBUG2 | DEBUG3 |     PSUM_PORT Bank B (4 Cols)  |
                 | (1Col) | (1Col) | (1Col) | (1Col) |                                 |
                 +--------+--------+--------+--------+--------+--------+--------+--------+
```

| Tile Name | Perimeter Edge | Tile Span | Associated BEL | Total Pins | Density (Pins/Tile) | Latency Contract |
| :--- | :--- | :---: | :--- | :---: | :---: | :--- |
| `AXI_M_IO_W` | **West** | Rows 0..9 (10 Rows) | `AXI_M_BEL` | 184 | **18.4** | 0 cycles (Asynchronous at fabric boundary) |
| `AXIL_S_IO_W` | **West** | Rows 10..15 (6 Rows) | `AXIL_S_BEL` | 108 | **18.0** | 0 cycles (Asynchronous at fabric boundary) |
| `ACT_RAM_IO_E` $\times 8$ | **East** | Rows 0..15 (8 $\times$ 2-row supertiles) | `NPU_SLICE_DATA_SRAM_BEL` | 47 / supertile (376 total) | **23.5** | **Registered** (+1 launch, 3-cycle round-trip SRAM read) |
| `PMOD_IO_N` | **North** | Cols 1..2 (2 Cols) | `EXT_PMOD_BEL` | 24 | **12.0** | **Registered** (+1 clk in/out) |
| `REQUANT_AUX_N` | **North** | Cols 3..4 (2 Cols) | `NPU_CTRL_CFG_BEL` | 38 | **19.0** | **Registered** (+1 clk out; +2 clk on `compute_bank_swap`) |
| `PSUM_PORT_N` | **North** | Cols 5..8 (4 Cols) | `NPU_ACCUM_SRAM_BEL` (Bank A) | 83 | **20.75** | **Registered** (+1 launch, 3-cycle round-trip SRAM read) |
| **`DEBUG_IO_S_0`** (Slot 0) | **South** | Col 1 (1 Col, single-tile) | `SOC_DEBUG_CTRL_BEL` | 18 | **18.0** | **Registered** (+1 clk in/out) |
| **`DEBUG_IO_S_1`** (Slot 1) | **South** | Col 2 (1 Col, single-tile) | `SOC_DEBUG_CTRL_BEL` | 18 | **18.0** | **Registered** (+1 clk in/out) |
| **`DEBUG_IO_S_2`** (Slot 2) | **South** | Col 3 (1 Col, single-tile) | `SOC_DEBUG_CTRL_BEL` | 18 | **18.0** | **Registered** (+1 clk in/out) |
| **`DEBUG_IO_S_3`** (Slot 3) | **South** | Col 4 (1 Col, single-tile) | `SOC_DEBUG_CTRL_BEL` | 18 | **18.0** | **Registered** (+1 clk in/out) |
| `PSUM_PORT_S` | **South** | Cols 5..8 (4 Cols) | `NPU_ACCUM_SRAM_BEL` (Bank B) | 83 | **20.75** | **Registered** (+1 launch, 3-cycle round-trip SRAM read) |
