#!/usr/bin/env python3
"""
NPU Golden Reference Generator: General Math (PyTorch)
- Generates 3 Scaled & Unaligned Datasets:
  - GEMM (M=530, K=27, N=22)
  - 1x1 Convolution (35x37 Image, Cin=19, Cout=21)
  - 3x3 Halo Convolution (35x37 Image, Cin=19, Cout=21)
- Exports two's-complement hex (.mem) files for tb_npu_general_math.sv
"""

import torch
import torch.nn.functional as F
import numpy as np

torch.manual_seed(42)
np.random.seed(42)

# ==============================================================================
# CONFIGURABLE UNALIGNED SHAPES
# ==============================================================================
GEMM_M, GEMM_K, GEMM_N = 530, 27, 22
CONV_H, CONV_W         = 35, 37
CONV_CIN, CONV_COUT    = 19, 21

M0_VAL    = 16384
SHIFT_1X1 = 14  # Scale ~ 1.0
SHIFT_3X3 = 15  # Scale ~ 0.5
ZERO_PT   = 0

def hw_requantize(psum_tensor, m0, shift_n, zero_point):
    prod = psum_tensor.to(torch.int64) * m0
    if shift_n > 0:
        # Hardware Round-Half-Away-From-Zero: Subtract 1 if product is negative
        half = 1 << (shift_n - 1)
        is_neg = (prod < 0).to(torch.int64)
        round_offset = half - is_neg
    else:
        round_offset = 0
    rounded = (prod + round_offset) >> shift_n
    offset = rounded + zero_point
    return torch.clamp(offset, -128, 127).to(torch.int8)

def export_flat_mem(filename, tensor, hex_digits):
    flat_data = tensor.cpu().numpy().flatten()
    mask = (1 << (hex_digits * 4)) - 1
    with open(filename, "w") as f:
        for val in flat_data:
            f.write(f"{(int(val) & mask):0{hex_digits}X}\n")
    print(f"  [EXPORT] {filename:<30} | Elements: {len(flat_data):>8}")

print("=======================================================================")
print(" >>> GENERATING GENERAL MATH DATASETS (GEMM, 1x1, 3x3 Halo) <<<")
print("=======================================================================")

# ==============================================================================
# SiLU ACTIVATION LOOKUP TABLE
# ==============================================================================
lut_silu_table = np.zeros(256, dtype=np.int8)
scale_in, scale_out = 0.05, 0.05
for addr in range(256):
    signed_val = addr if addr < 128 else (addr - 256)
    x_float = torch.tensor(signed_val * scale_in, dtype=torch.float32)
    silu_float = F.silu(x_float)
    quant_silu = torch.round(silu_float / scale_out)
    lut_silu_table[addr] = torch.clamp(quant_silu, -128, 127).to(torch.int8).item()

export_flat_mem("gen_lut_silu.mem", torch.from_numpy(lut_silu_table), 2)

# ==============================================================================
# DATASET: GEMM
# ==============================================================================
gemm_a_raw = torch.randint(-4, 5, size=(GEMM_M, GEMM_K), dtype=torch.int8)
gemm_b_raw = torch.randint(-4, 5, size=(GEMM_K, GEMM_N), dtype=torch.int8)
golden_gemm_c = torch.matmul(gemm_a_raw.to(torch.int32), gemm_b_raw.to(torch.int32))

export_flat_mem("gen_gemm_a.mem", gemm_a_raw, 2)
export_flat_mem("gen_gemm_b.mem", gemm_b_raw, 2)
export_flat_mem("gen_gemm_out_raw.mem", golden_gemm_c, 8)

# ==============================================================================
# DATASET: 1x1 CONVOLUTION
# ==============================================================================
conv1x1_in = torch.randint(-4, 5, size=(1, CONV_CIN, CONV_H, CONV_W), dtype=torch.int8)
conv1x1_w  = torch.randint(-4, 5, size=(CONV_COUT, CONV_CIN, 1, 1),   dtype=torch.int8)

conv1x1_out_raw = F.conv2d(conv1x1_in.to(torch.int32), conv1x1_w.to(torch.int32), stride=1, padding=0)
conv1x1_out_nhwc = conv1x1_out_raw.squeeze(0).permute(1, 2, 0)
conv1x1_in_nhwc  = conv1x1_in.squeeze(0).permute(1, 2, 0)
conv1x1_w_flat   = conv1x1_w.squeeze(3).squeeze(2)

golden_conv1x1_quant = hw_requantize(conv1x1_out_nhwc, M0_VAL, SHIFT_1X1, ZERO_PT)
golden_conv1x1_lut = np.zeros_like(golden_conv1x1_quant.numpy(), dtype=np.int8)
for y in range(CONV_H):
    for x in range(CONV_W):
        for co in range(CONV_COUT):
            q_val = int(golden_conv1x1_quant[y, x, co].item())
            golden_conv1x1_lut[y, x, co] = lut_silu_table[q_val & 0xFF]

export_flat_mem("gen_conv1x1_act.mem",       conv1x1_in_nhwc,              2)
export_flat_mem("gen_conv1x1_w.mem",         conv1x1_w_flat.permute(1, 0), 2)
export_flat_mem("gen_conv1x1_out_raw.mem",   conv1x1_out_nhwc,             8)
export_flat_mem("gen_conv1x1_out_quant.mem", golden_conv1x1_quant,         2)
export_flat_mem("gen_conv1x1_out_lut.mem",   torch.from_numpy(golden_conv1x1_lut), 2)

# ==============================================================================
# DATASET: 3x3 HALO CONVOLUTION
# ==============================================================================
conv3x3_halo_in = torch.randint(-3, 4, size=(1, CONV_CIN, CONV_H, CONV_W), dtype=torch.int8)
conv3x3_halo_w  = torch.randint(-3, 4, size=(CONV_COUT, CONV_CIN, 3, 3),   dtype=torch.int8)

conv3x3_halo_out_raw = F.conv2d(conv3x3_halo_in.to(torch.int32), conv3x3_halo_w.to(torch.int32), stride=1, padding=1)
conv3x3_halo_out_nhwc = conv3x3_halo_out_raw.squeeze(0).permute(1, 2, 0)
conv3x3_halo_in_nhwc  = conv3x3_halo_in.squeeze(0).permute(1, 2, 0)

golden_conv3x3_halo_quant = hw_requantize(conv3x3_halo_out_nhwc, M0_VAL, SHIFT_3X3, ZERO_PT)
golden_conv3x3_halo_lut = np.zeros_like(golden_conv3x3_halo_quant.numpy(), dtype=np.int8)
for y in range(CONV_H):
    for x in range(CONV_W):
        for co in range(CONV_COUT):
            q_val = int(golden_conv3x3_halo_quant[y, x, co].item())
            golden_conv3x3_halo_lut[y, x, co] = lut_silu_table[q_val & 0xFF]

conv3x3_halo_w_nhwc = conv3x3_halo_w.permute(2, 3, 1, 0)

export_flat_mem("gen_conv3x3_halo_act.mem",       conv3x3_halo_in_nhwc,                 2)
export_flat_mem("gen_conv3x3_halo_w.mem",         conv3x3_halo_w_nhwc,                  2)
export_flat_mem("gen_conv3x3_halo_out_raw.mem",   conv3x3_halo_out_nhwc,                 8)
export_flat_mem("gen_conv3x3_halo_out_quant.mem", golden_conv3x3_halo_quant,             2)
export_flat_mem("gen_conv3x3_halo_out_lut.mem",   torch.from_numpy(golden_conv3x3_halo_lut), 2)

print("\n>>> SUCCESS: General Math reference datasets exported! <<<\n")