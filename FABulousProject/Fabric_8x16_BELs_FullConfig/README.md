# CrocoScale 9x16 eFPGA Fabric — BEL Specification

The core fabric consists of a matrix of **9 CLBs wide** and **16 CLBs high** (9 columns $\times$ 16 rows, 144 CLBs total).

---

## Fabric BEL Perimeter Diagram (Graded Corner Relief)

```
                   Col 1           Col 2           Col 3           Col 4           Col 5           Col 6           Col 7           Col 8           Col 9
              +---------------+---------------+---------------+---------------+---------------+---------------+---------------+---------------+---------------+
   NORTH EDGE |          EXT_PMOD_BEL         |       NPU_CTRL_CFG_BEL        |                             NPU_ACCUM_SRAM_BEL (Bank A)                       |
              |            (2 Cols)           |           (2 Cols)            |                 (5 Cols - Stretched, Graded: Dense Center, Light Corner)      |
              |               |               |               |               |  [Dense Mid]  |  [Dense Mid]  |  [Dense Mid]  |   [Medium]    | [Light Corner]|
              +---------------+---------------+---------------+---------------+---------------+---------------+---------------+---------------+---------------+
Row 0 [Light] |                                                                                                                                               | NPU_SLICE_DATA_SRAM_BEL [0]
Row 1         |                                                                                                                                               | (2 rows high)
Row 2  (AXI_  |                                                                                                                                               | NPU_SLICE_DATA_SRAM_BEL [1]
Row 3   M_    |                                                                                                                                               | (2 rows high)
Row 4   BEL,  |                                                                                                                                               | NPU_SLICE_DATA_SRAM_BEL [2]
Row 5  10     |                                       CORE CLB FABRIC                                                                                         | (2 rows high)
Row 6  rows   |                                     9 Columns x 16 Rows                                                                                       | NPU_SLICE_DATA_SRAM_BEL [3]
Row 7  high)  |                                          (144 CLBs)                                                                                           | (2 rows high)
Row 8         |                                                                                                                                               | NPU_SLICE_DATA_SRAM_BEL [4]
Row 9 [Dense] |                                                                                                                                               | (2 rows high)
Row 10[Dense] |                                                                                                                                               | NPU_SLICE_DATA_SRAM_BEL [5]
Row 11 (AXIL_ |                                                                                                                                               | (2 rows high)
Row 12  S_    |                                                                                                                                               | NPU_SLICE_DATA_SRAM_BEL [6]
Row 13  BEL,  |                                                                                                                                               | (2 rows high)
Row 14  6     |                                                                                                                                               | NPU_SLICE_DATA_SRAM_BEL [7]
Row 15[Light] |                                                                                                                                               | (2 rows high)
              +---------------+---------------+---------------+---------------+---------------+---------------+---------------+---------------+---------------+
   SOUTH EDGE | SOC_DEBUG_    | SOC_DEBUG_    | SOC_DEBUG_    | SOC_DEBUG_    |                             NPU_ACCUM_SRAM_BEL (Bank B)                       |
              | CTRL_BEL [0]  | CTRL_BEL [1]  | CTRL_BEL [2]  | CTRL_BEL [3]  |                 (5 Cols - Stretched, Graded: Dense Center, Light Corner)      |
              |               |               |               |               |  [Dense Mid]  |  [Dense Mid]  |  [Dense Mid]  |   [Medium]    | [Light Corner]|
              +---------------+---------------+---------------+---------------+---------------+---------------+---------------+---------------+---------------+
```

---

## Graded Density & Corner Routing Relief Strategy

Corner switch matrices have only 2 escape directions instead of 4, making them severe routing bottlenecks. The 9x16 floorplan implements intentional **graded pin densities** to eliminate track competition at all four die corners:

1. **North-West (NW) Relief (Row 0, Col 1)**:
   - **`EXT_PMOD_BEL`** occupies **Cols 1..2** (2 cols). Col 1 is assigned a light pin allocation to avoid congesting the corner.
   - **`AXI_M_BEL`** applies a slight vertical density gradient, keeping Row 0 light (~12 pins) and placing heavier channel multiplexing in Rows 4..9.
   - **Result**: NW corner switch matrix avoids track starvation between PMOD and AXI Master.

2. **South-West (SW) Relief (Row 15, Col 1)**:
   - **`SOC_DEBUG_CTRL_BEL[0]`** in **Col 1** is lightly loaded.
   - **`AXIL_S_BEL`** keeps Row 15 light (~12 pins), placing the bulk of register control in Rows 10..13.
   - **Result**: SW corner switch matrix maintains clean routing escape for CPU control and debug IRQ lines.

3. **North-East (NE) Relief (Row 0, Col 9)**:
   - **`NPU_ACCUM_SRAM_BEL` (Bank A)** is stretched across **5 columns (Cols 5..9)** with a center-dense distribution:
     - **Cols 5, 6 & 7 (Center)**: Carry the wide 32-bit `WDATA` and 32-bit `RDATA` buses (~20–22 pins/col), where 4-way routing tracks into the CLB core are fully available.
     - **Col 8 (Mid-Edge)**: Carries `WE[7:0]` and control (~14–16 pins).
     - **Col 9 (Corner)**: Kept light (~10–11 pins: `ADDR[7:0]` + `READ_BANK_SEL[2:0]`).
   - **Result**: Pin density drops from 20.75 down to **16.6 pins/col** on average, and frees $\approx 75\%$ of Col 9's horizontal routing tracks. This allows the 47 pins of East Slice 0 (`NPU_SLICE_DATA_SRAM_BEL[0]`) to route directly westward into the fabric without colliding with PSUM wires.

4. **South-East (SE) Relief (Row 15, Col 9)**:
   - **`NPU_ACCUM_SRAM_BEL` (Bank B)** mirrors Bank A identically across **Cols 5..9** (stretched across 5 cols, center-dense, Col 9 light).
   - **Result**: Frees $\approx 75\%$ of Col 9's horizontal tracks for East Slice 7 (`NPU_SLICE_DATA_SRAM_BEL[7]`).

---

## BEL List & Dimensions

| BEL Name | Perimeter Edge | Width | Height | Perimeter Span | Config Bits | Average Pin Density |
| :--- | :--- | :---: | :---: | :--- | :---: | :---: |
| [`AXI_M_BEL`](./AXI_M_BEL.v) | **West** | 1 Col | 10 Rows | Rows 0..9 | **12 bits** | **18.4 pins/row** (Slight gradient: lighter at Row 0) |
| [`AXIL_S_BEL`](./AXIL_S_BEL.v) | **West** | 1 Col | 6 Rows | Rows 10..15 | None | **18.0 pins/row** (Slight gradient: lighter at Row 15) |
| [`EXT_PMOD_BEL`](./EXT_PMOD_BEL.v) | **North** | 2 Cols | 1 Row | Cols 1..2 | **13 bits** | **12.0 pins/col** (Lighter at Col 1) |
| [`NPU_CTRL_CFG_BEL`](./NPU_CTRL_CFG_BEL.v) | **North** | 2 Cols | 1 Row | Cols 3..4 | **1 bit** | **18.5 pins/col** |
| [`NPU_ACCUM_SRAM_BEL`](./NPU_ACCUM_SRAM_BEL.v) *(2 instances)* | **North** *(Bank A)* AND **South** *(Bank B)* | **5 Cols** | 1 Row | **Cols 5..9** | **8 bits** | **16.6 pins/col** (Graded: ~20-22 in Cols 5-7, ~10-11 in Col 9) |
| [`SOC_DEBUG_CTRL_BEL`](./SOC_DEBUG_CTRL_BEL.v) *(4 instances)* | **South** | 1 Col (each) | 1 Row | Cols 1, 2, 3, 4 | **4 bits** | **18.0 pins/col** (Lighter at Col 1) |
| [`NPU_SLICE_DATA_SRAM_BEL`](./NPU_SLICE_DATA_SRAM_BEL.v) *(8 instances)* | **East** | 1 Col | 2 Rows (each) | Rows 0..15 | **6 bits** | **23.5 pins/row** (47 pins per 2-row supertile) |
