#!/usr/bin/env python3
"""
NPU Golden Reference Generator: Inline 2x2 Max Pooling (Stride 2)
Project: CrocoScale SoC

Generates reference test vectors for:
1. Linear INT8 Activations -> 2x2 MaxPool (Stride 2) -> 8x8x8 Output Tensor
2. Non-Linear SiLU LUT Activations -> 2x2 MaxPool (Stride 2) -> 8x8x8 Output Tensor
3. End-to-end 3x3 Conv -> Requantize -> 2x2 MaxPool

Exports two's-complement hex (.mem) files for Verilog testbench verification.
"""

import os
import torch
import torch.nn.functional as F
import numpy as np

torch.manual_seed(42)
np.random.seed(42)

# Dimensions for a standard 16x16 NPU Tile
TILE_H = 16
TILE_W = 16
CHANNELS = 8

POOL_H = TILE_H // 2  # 8
POOL_W = TILE_W // 2  # 8

def export_flat_mem(filename, tensor_data, hex_digits=2):
    """Exports tensor data to flat hex .mem format (one hex word per line)."""
    if isinstance(tensor_data, torch.Tensor):
        flat_data = tensor_data.cpu().numpy().flatten()
    else:
        flat_data = np.asarray(tensor_data).flatten()

    mask = (1 << (hex_digits * 4)) - 1
    with open(filename, "w") as f:
        for val in flat_data:
            f.write(f"{(int(val) & mask):0{hex_digits}X}\n")
    print(f"  [EXPORT] {os.path.basename(filename):<32} | Elements: {len(flat_data):>6}")

print("=======================================================================")
print(" >>> GENERATING INLINE 2x2 MAX POOLING GOLDEN REFERENCES <<<")
print("=======================================================================")

# ------------------------------------------------------------------------------
# 1. SiLU Lookup Table (Same as used in NPU core)
# ------------------------------------------------------------------------------
lut_silu_table = np.zeros(256, dtype=np.int8)
scale_in, scale_out = 0.05, 0.05
for addr in range(256):
    signed_val = addr if addr < 128 else (addr - 256)
    x_float = torch.tensor(signed_val * scale_in, dtype=torch.float32)
    silu_float = F.silu(x_float)
    quant_silu = torch.round(silu_float / scale_out)
    lut_silu_table[addr] = torch.clamp(quant_silu, -128, 127).to(torch.int8).item()

# ------------------------------------------------------------------------------
# 2. Test Input Tensor: 16x16 Tile across 8 Channels (Signed INT8: -128 to 127)
# ------------------------------------------------------------------------------
# Shape: (H, W, C) -> (16, 16, 8)
act_16x16_linear = torch.randint(-100, 101, size=(TILE_H, TILE_W, CHANNELS), dtype=torch.int8)

# Transform through SiLU LUT for the non-linear test case
act_16x16_silu = np.zeros((TILE_H, TILE_W, CHANNELS), dtype=np.int8)
for y in range(TILE_H):
    for x in range(TILE_W):
        for c in range(CHANNELS):
            q_val = int(act_16x16_linear[y, x, c].item())
            act_16x16_silu[y, x, c] = lut_silu_table[q_val & 0xFF]
act_16x16_silu_torch = torch.from_numpy(act_16x16_silu)

# ------------------------------------------------------------------------------
# 3. PyTorch 2x2 Max Pooling with Stride 2
# ------------------------------------------------------------------------------
# PyTorch max_pool2d expects (N, C, H, W). Permute from (H, W, C) to (1, C, H, W)
linear_nchw = act_16x16_linear.permute(2, 0, 1).unsqueeze(0).to(torch.float32)
silu_nchw   = act_16x16_silu_torch.permute(2, 0, 1).unsqueeze(0).to(torch.float32)

# MaxPool2d (kernel_size=2, stride=2)
pooled_linear_nchw = F.max_pool2d(linear_nchw, kernel_size=2, stride=2).to(torch.int8)
pooled_silu_nchw   = F.max_pool2d(silu_nchw,   kernel_size=2, stride=2).to(torch.int8)

# Permute back to hardware-native NHWC: (8, 8, 8)
pooled_linear_nhwc = pooled_linear_nchw.squeeze(0).permute(1, 2, 0)
pooled_silu_nhwc   = pooled_silu_nchw.squeeze(0).permute(1, 2, 0)

# Verify manual calculation matches PyTorch
for py in range(POOL_H):
    for px in range(POOL_W):
        for c in range(CHANNELS):
            # Quad: (2*py, 2*px), (2*py, 2*px+1), (2*py+1, 2*px), (2*py+1, 2*px+1)
            quad_linear = [
                act_16x16_linear[2 * py + 0, 2 * px + 0, c].item(),
                act_16x16_linear[2 * py + 0, 2 * px + 1, c].item(),
                act_16x16_linear[2 * py + 1, 2 * px + 0, c].item(),
                act_16x16_linear[2 * py + 1, 2 * px + 1, c].item()
            ]
            manual_max_lin = max(quad_linear)
            assert manual_max_lin == pooled_linear_nhwc[py, px, c].item(), "Mismatch in linear MaxPool"

            quad_silu = [
                act_16x16_silu[2 * py + 0, 2 * px + 0, c],
                act_16x16_silu[2 * py + 0, 2 * px + 1, c],
                act_16x16_silu[2 * py + 1, 2 * px + 0, c],
                act_16x16_silu[2 * py + 1, 2 * px + 1, c]
            ]
            manual_max_silu = max(quad_silu)
            assert manual_max_silu == pooled_silu_nhwc[py, px, c].item(), "Mismatch in SiLU MaxPool"

print("  [CHECK] PyTorch F.max_pool2d matches exact manual signed INT8 quad reduction: OK")

# ------------------------------------------------------------------------------
# 4. Export .mem files
# ------------------------------------------------------------------------------
target_dir = os.path.dirname(os.path.abspath(__file__))

export_flat_mem(os.path.join(target_dir, "gen_maxpool_in_act.mem"),     act_16x16_linear,   2)
export_flat_mem(os.path.join(target_dir, "gen_maxpool_in_silu.mem"),    act_16x16_silu_torch, 2)
export_flat_mem(os.path.join(target_dir, "gen_maxpool_linear_gold.mem"), pooled_linear_nhwc, 2)
export_flat_mem(os.path.join(target_dir, "gen_maxpool_silu_gold.mem"),   pooled_silu_nhwc,   2)

print("\n>>> SUCCESS: Golden MaxPool reference files generated! <<<\n")

