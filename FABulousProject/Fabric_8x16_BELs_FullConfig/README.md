# CrocoScale 8x16 eFPGA Fabric — BEL Specification

The core fabric consists of a matrix of **8 CLBs wide** and **16 CLBs high** (8 columns $\times$ 16 rows, 128 CLBs total).

---

## Fabric BEL Perimeter Diagram

```
                   Col 1           Col 2           Col 3           Col 4           Col 5           Col 6           Col 7           Col 8
              +---------------+---------------+---------------+---------------+---------------+---------------+---------------+---------------+
   NORTH EDGE |          EXT_PMOD_BEL         |       NPU_CTRL_CFG_BEL        |             NPU_ACCUM_SRAM_BEL (Bank A)                       |
              +---------------+---------------+---------------+---------------+---------------+---------------+---------------+---------------+
Row 0         |                                                                                                                               | NPU_SLICE_DATA_SRAM_BEL [0]
Row 1  (AXI_  |                                                                                                                               | (2 rows high)
Row 2   M_    |                                                                                                                               | NPU_SLICE_DATA_SRAM_BEL [1]
Row 3   BEL,  |                                                                                                                               | (2 rows high)
Row 4   10    |                                                                                                                               | NPU_SLICE_DATA_SRAM_BEL [2]
Row 5  rows   |                                       CORE CLB FABRIC                                                                         | (2 rows high)
Row 6  high)  |                                     8 Columns x 16 Rows                                                                       | NPU_SLICE_DATA_SRAM_BEL [3]
Row 7         |                                          (128 CLBs)                                                                           | (2 rows high)
Row 8         |                                                                                                                               | NPU_SLICE_DATA_SRAM_BEL [4]
Row 9         |                                                                                                                               | (2 rows high)
Row 10 (AXIL_ |                                                                                                                               | NPU_SLICE_DATA_SRAM_BEL [5]
Row 11  S_    |                                                                                                                               | (2 rows high)
Row 12  BEL,  |                                                                                                                               | NPU_SLICE_DATA_SRAM_BEL [6]
Row 13  6     |                                                                                                                               | (2 rows high)
Row 14 rows   |                                                                                                                               | NPU_SLICE_DATA_SRAM_BEL [7]
Row 15 high)  |                                                                                                                               | (2 rows high)
              +---------------+---------------+---------------+---------------+---------------+---------------+---------------+---------------+
   SOUTH EDGE | SOC_DEBUG_    | SOC_DEBUG_    | SOC_DEBUG_    | SOC_DEBUG_    |             NPU_ACCUM_SRAM_BEL (Bank B)                       |
              | CTRL_BEL [0]  | CTRL_BEL [1]  | CTRL_BEL [2]  | CTRL_BEL [3]  |                                                               |
              +---------------+---------------+---------------+---------------+---------------+---------------+---------------+---------------+
```

---

## BEL List & Dimensions

| BEL Name | Perimeter Edge | Width | Height | Perimeter Span | Config Bits |
| :--- | :--- | :---: | :---: | :--- | :---: |
| [`AXI_M_BEL`](./AXI_M_BEL.v) | **West** | 1 Col | 10 Rows | Rows 0..9 | **12 bits** |
| [`AXIL_S_BEL`](./AXIL_S_BEL.v) | **West** | 1 Col | 6 Rows | Rows 10..15 | None |
| [`EXT_PMOD_BEL`](./EXT_PMOD_BEL.v) | **North** | 2 Cols | 1 Row | Cols 1..2 | **13 bits** |
| [`NPU_CTRL_CFG_BEL`](./NPU_CTRL_CFG_BEL.v) | **North** | 2 Cols | 1 Row | Cols 3..4 | **1 bit** |
| [`NPU_ACCUM_SRAM_BEL`](./NPU_ACCUM_SRAM_BEL.v) *(2 instances)* | **North** (Bank A) AND **South** (Bank B) | 4 Cols | 1 Row | Cols 5..8 | **8 bits** |
| [`SOC_DEBUG_CTRL_BEL`](./SOC_DEBUG_CTRL_BEL.v) *(4 instances)* | **South** | 1 Col (each) | 1 Row | Cols 1, 2, 3, 4 | **4 bits** |
| [`NPU_SLICE_DATA_SRAM_BEL`](./NPU_SLICE_DATA_SRAM_BEL.v) *(8 instances)* | **East** | 1 Col | 2 Rows (each) | Rows 0..15 | **3 bits** |
