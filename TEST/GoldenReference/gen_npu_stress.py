#!/usr/bin/env python3
"""
CrocoScale SoC — SoftLogic Weird-Dimension Stress Reference Generator
- Cloned from gen_npu_functional.py with irregular non-power-of-two,
  non-multiple-of-16, non-multiple-of-4 spatial and channel dimensions:
    * 3x3 Stress Layer: H=54, W=78, Cin=6, Cout=8 (4x5 = 20 tiles, 7 passes/tile)
      - H=54: 4 tile rows (bottom tile has 6 rows: 1 full strip + 1 half strip + 2 empty strips)
      - W=78: 5 tile cols (rightmost tile has 14 cols unpooled, 7 cols pooled)
      - Pooled output: 27x39x8 (odd H_out=27 -> 27%4=3; odd W_out=39 -> 39%8=7)
      - Cin=6: 54 kernel taps -> 7 passes (odd pass count, final pass has 6 active rows)
    * 1x1 Stress Layer: H=38, W=50, Cin=19, Cout=8 (3x4 = 12 tiles, 5 passes/tile)
      - H=38: 3 tile rows (bottom tile has 6 rows unpooled, 3 rows pooled)
      - W=50: 4 tile cols (rightmost tile has 2 cols unpooled, 1 col single-beat burst pooled)
      - Pooled output: 19x25x8 (odd H_out=19 -> 19%4=3; odd W_out=25 -> 25%8=1)
      - Cin=19: 5 passes (odd pass count, final pass has 3 active channels)
- Evaluates all 4 AXI DMA output drain modes (Linear, Mish LUT, MaxPool, Mish+MaxPool).
"""

import os
import math
import numpy as np
import torch
import torch.nn.functional as F

target_dir = os.path.dirname(os.path.abspath(__file__))
torch.manual_seed(1337)
np.random.seed(1337)

# Hardware Quantization Constants
SCALE_M0_1X1  = 16384  # Q15 = 0.5
SHIFT_1X1     = 14
ZERO_PT       = 0

SCALE_M0_3X3  = 16384
SHIFT_3X3     = 14

def hw_requantize(psum_tensor, m0, shift_n, zero_point=0):
    prod = psum_tensor.to(torch.int64) * m0
    if shift_n > 0:
        half = 1 << (shift_n - 1)
        is_neg = (prod < 0).to(torch.int64)
        round_offset = half - is_neg
    else:
        round_offset = 0
    rounded = (prod + round_offset) >> shift_n
    offset = rounded + zero_point
    return torch.clamp(offset, -128, 127).to(torch.int8)

def export_flat_mem(filename, tensor, hex_digits):
    filepath = os.path.join(target_dir, filename)
    flat_data = tensor.cpu().numpy().flatten()
    mask = (1 << (hex_digits * 4)) - 1
    with open(filepath, "w") as f:
        for val in flat_data:
            f.write(f"{(int(val) & mask):0{hex_digits}X}\n")
    print(f"  [EXPORT] {filename:<32} | Shape: {str(list(tensor.shape)):<18} | Elements: {len(flat_data):>8}")

print("=======================================================================")
print(" >>> CrocoScale SoC: Weird-Dimension Stress Dataset Generator       <<<")
print("=======================================================================")

# =============================================================================
# 1. 256-ENTRY MISH ACTIVATION LOOKUP TABLE
# =============================================================================
print("\n--- Generating Mish Activation Look-Up Table ---")
lut_mish_table = np.zeros(256, dtype=np.int8)
scale_in, scale_out = 0.05, 0.05
for addr in range(256):
    signed_val = addr if addr < 128 else (addr - 256)
    x_float = torch.tensor(signed_val * scale_in, dtype=torch.float32)
    mish_float = F.mish(x_float)
    quant_mish = torch.round(mish_float / scale_out)
    lut_mish_table[addr] = torch.clamp(quant_mish, -128, 127).to(torch.int8).item()

export_flat_mem("stress_lut_mish.mem", torch.from_numpy(lut_mish_table), 2)

# =============================================================================
# 2. 1x1 CONVOLUTION (38x50, Cin=19, Cout=8, 3x4 Tiles, 5 Passes/Tile)
# =============================================================================
print("\n--- Generating 1x1 Stress Dataset (38x50, Cin=19, Cout=8, 12 Tiles, 5 Passes) ---")
C1_H, C1_W, C1_CIN, C1_COUT = 38, 50, 19, 8

# Input: [1, Cin, H, W]
c1_in = torch.randint(-8, 9, size=(1, C1_CIN, C1_H, C1_W), dtype=torch.int8)
# Weights: [Cout, Cin, 1, 1]
c1_w = torch.randint(-8, 9, size=(C1_COUT, C1_CIN, 1, 1), dtype=torch.int8)
# Bias: [Cout]
c1_b = torch.randint(-50, 51, size=(C1_COUT,), dtype=torch.int32)

# Compute exact Conv2D
c1_out_raw = F.conv2d(c1_in.to(torch.int32), c1_w.to(torch.int32), bias=c1_b, stride=1, padding=0)
c1_out_nhwc = c1_out_raw.squeeze(0).permute(1, 2, 0) # [38, 50, 8]
c1_in_nhwc  = c1_in.squeeze(0).permute(1, 2, 0)       # [38, 50, 19]

# Drain Mode A: Linear Requantized INT8
c1_out_linear = hw_requantize(c1_out_nhwc, SCALE_M0_1X1, SHIFT_1X1, ZERO_PT)

# Drain Mode B: Requantized + Mish LUT INT8
c1_out_mish = np.zeros_like(c1_out_linear.numpy(), dtype=np.int8)
for y in range(C1_H):
    for x in range(C1_W):
        for c in range(C1_COUT):
            q_val = int(c1_out_linear[y, x, c].item())
            c1_out_mish[y, x, c] = lut_mish_table[q_val & 0xFF]
c1_out_mish_tensor = torch.from_numpy(c1_out_mish)

# Drain Mode C: Linear + 2x2 MaxPool INT8 (shape: 19x25x8)
c1_pool_in = c1_out_linear.permute(2, 0, 1).unsqueeze(0).to(torch.float32)
c1_out_pool = F.max_pool2d(c1_pool_in, kernel_size=2, stride=2).squeeze(0).permute(1, 2, 0).to(torch.int8)

# Drain Mode D: Mish LUT + 2x2 MaxPool INT8 (shape: 19x25x8)
c1_mish_pool_in = c1_out_mish_tensor.permute(2, 0, 1).unsqueeze(0).to(torch.float32)
c1_out_mish_pool = F.max_pool2d(c1_mish_pool_in, kernel_size=2, stride=2).squeeze(0).permute(1, 2, 0).to(torch.int8)

# 1x1 Weights format: [Cin, Cout] -> [19, 8]
c1_w_flat = c1_w.squeeze(-1).squeeze(-1).permute(1, 0)

# 1x1 Quant config words
c1_cfg = [( (SCALE_M0_1X1 & 0xFFFF) | ((SHIFT_1X1 & 0x3F) << 16) | ((ZERO_PT & 0xFF) << 22) ) for _ in range(C1_COUT)]

export_flat_mem("stress_1x1_act.mem",            c1_in_nhwc,         2)
export_flat_mem("stress_1x1_w.mem",              c1_w_flat,          2)
export_flat_mem("stress_1x1_b.mem",              c1_b,               8)
export_flat_mem("stress_1x1_cfg.mem",            torch.tensor(c1_cfg, dtype=torch.int32), 8)
export_flat_mem("stress_1x1_raw.mem",            c1_out_nhwc,        8)
export_flat_mem("stress_1x1_out_linear.mem",     c1_out_linear,      2)
export_flat_mem("stress_1x1_out_mish.mem",       c1_out_mish_tensor, 2)
export_flat_mem("stress_1x1_out_pool.mem",       c1_out_pool,        2)
export_flat_mem("stress_1x1_out_mish_pool.mem",  c1_out_mish_pool,   2)

# =============================================================================
# 3. 3x3 HALO CONVOLUTION (54x78, Cin=6, Cout=8, 4x5 Tiles, 7 Passes/Tile)
# =============================================================================
print("\n--- Generating 3x3 Multi-Tile Halo Stress Dataset (54x78, Cin=6, Cout=8, 20 Tiles, 7 Passes) ---")
C3_H, C3_W, C3_CIN, C3_COUT = 54, 78, 6, 8

# Input: [1, Cin, H, W]
c3_in = torch.randint(-8, 9, size=(1, C3_CIN, C3_H, C3_W), dtype=torch.int8)
# Weights: [Cout, Cin, 3, 3]
c3_w = torch.randint(-8, 9, size=(C3_COUT, C3_CIN, 3, 3), dtype=torch.int8)
# Bias: [Cout]
c3_b = torch.randint(-50, 51, size=(C3_COUT,), dtype=torch.int32)

# Compute exact Conv2D with SAME padding (pad=1)
c3_out_raw = F.conv2d(c3_in.to(torch.int32), c3_w.to(torch.int32), bias=c3_b, stride=1, padding=1)
c3_out_nhwc = c3_out_raw.squeeze(0).permute(1, 2, 0) # [54, 78, 8]
c3_in_nhwc  = c3_in.squeeze(0).permute(1, 2, 0)       # [54, 78, 6]

# Drain Mode A: Linear Requantized INT8
c3_out_linear = hw_requantize(c3_out_nhwc, SCALE_M0_3X3, SHIFT_3X3, ZERO_PT)

# Drain Mode B: Requantized + Mish LUT INT8
c3_out_mish = np.zeros_like(c3_out_linear.numpy(), dtype=np.int8)
for y in range(C3_H):
    for x in range(C3_W):
        for c in range(C3_COUT):
            q_val = int(c3_out_linear[y, x, c].item())
            c3_out_mish[y, x, c] = lut_mish_table[q_val & 0xFF]
c3_out_mish_tensor = torch.from_numpy(c3_out_mish)

# Drain Mode C: Linear + 2x2 MaxPool INT8 (shape: 27x39x8)
c3_pool_in = c3_out_linear.permute(2, 0, 1).unsqueeze(0).to(torch.float32)
c3_out_pool = F.max_pool2d(c3_pool_in, kernel_size=2, stride=2).squeeze(0).permute(1, 2, 0).to(torch.int8)

# Drain Mode D: Mish LUT + 2x2 MaxPool INT8 (shape: 27x39x8)
c3_mish_pool_in = c3_out_mish_tensor.permute(2, 0, 1).unsqueeze(0).to(torch.float32)
c3_out_mish_pool = F.max_pool2d(c3_mish_pool_in, kernel_size=2, stride=2).squeeze(0).permute(1, 2, 0).to(torch.int8)

# 3x3 Weights format: [ky, kx, cin, cout] -> [3, 3, 6, 8]
c3_w_nhwc = c3_w.permute(2, 3, 1, 0)

c3_cfg = [( (SCALE_M0_3X3 & 0xFFFF) | ((SHIFT_3X3 & 0x3F) << 16) | ((ZERO_PT & 0xFF) << 22) ) for _ in range(C3_COUT)]

export_flat_mem("stress_3x3_act.mem",            c3_in_nhwc,         2)
export_flat_mem("stress_3x3_w.mem",              c3_w_nhwc,          2)
export_flat_mem("stress_3x3_b.mem",              c3_b,               8)
export_flat_mem("stress_3x3_cfg.mem",            torch.tensor(c3_cfg, dtype=torch.int32), 8)
export_flat_mem("stress_3x3_raw.mem",            c3_out_nhwc,        8)
export_flat_mem("stress_3x3_out_linear.mem",     c3_out_linear,      2)
export_flat_mem("stress_3x3_out_mish.mem",       c3_out_mish_tensor, 2)
export_flat_mem("stress_3x3_out_pool.mem",       c3_out_pool,        2)
export_flat_mem("stress_3x3_out_mish_pool.mem",  c3_out_mish_pool,   2)

print("\n>>> SUCCESS: Weird-dimension stress datasets generated successfully! <<<\n")

