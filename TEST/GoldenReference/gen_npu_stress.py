#!/usr/bin/env python3
"""
CrocoScale SoC — 5-Layer Chained Weird-Dimension Network Golden Generator
Generates an end-to-end 5-layer heterogeneous CNN (alternating 3x3 and 1x1
convolutions, odd/even pass counts, multi-group Cout=16 concatenation,
channel slicing, and all 4 drain modes: Linear, Mish LUT, MaxPool, Mish+MaxPool)
where only Layer 1's input is loaded from the testbench and Layers 1->2->3->4->5
feed directly into one another in RAM using power-of-two strip strides.

Network Architecture:
  - L1 (3x3 Conv, Mode A Linear):
      52x76x5  -> 52x76x16 (4x5=20 tiles, 2 Cout groups of 8, 6 passes/tile)
  - L2 (1x1 Conv, Mode B Mish LUT):
      52x76x11 -> 52x76x8  (4x5=20 tiles, 3 passes/tile [odd], slices 11 of 16 ch)
  - L3 (3x3 Conv, Mode D Mish LUT + 2x2 MaxPool):
      52x76x6  -> 26x38x16 (4x5=20 tiles, 2 Cout groups of 8, 7 passes/tile [odd], slices 6 of 8 ch)
  - L4 (1x1 Conv, Mode C Linear + 2x2 MaxPool):
      26x38x13 -> 13x19x8  (2x3=6 tiles, 4 passes/tile, slices 13 of 16 ch)
  - L5 (3x3 Conv, Mode B Mish LUT):
      13x19x7  -> 13x19x8  (1x2=2 tiles, 8 passes/tile, slices 7 of 8 ch, odd 13x19 input)
"""

import os
import numpy as np
import torch
import torch.nn.functional as F

target_dir = os.path.dirname(os.path.abspath(__file__))
torch.manual_seed(1337)
np.random.seed(1337)

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

def apply_lut(tensor_int8, lut_table):
    arr = tensor_int8.cpu().numpy()
    out = lut_table[arr.astype(np.uint8)]
    return torch.from_numpy(out.astype(np.int8))

def apply_maxpool_nhwc(tensor_nhwc):
    nchw = tensor_nhwc.permute(2, 0, 1).unsqueeze(0).to(torch.float32)
    pooled = F.max_pool2d(nchw, kernel_size=2, stride=2)
    return pooled.squeeze(0).permute(1, 2, 0).to(torch.int8)

def pack_3x3_weights(w_tensor):
    """
    Packs [Cout, Cin, 3, 3] weights into [Cout//8, 3, 3, Cin, 8] so each
    8-channel output group is contiguous in memory in [ky, kx, cin, cout_sub] order.
    """
    cout, cin, ky, kx = w_tensor.shape
    assert cout % 8 == 0
    w_grouped = w_tensor.view(cout // 8, 8, cin, ky, kx)
    return w_grouped.permute(0, 3, 4, 2, 1).contiguous()

def pack_1x1_weights(w_tensor):
    """
    Packs [Cout, Cin, 1, 1] weights into [Cout//8, Cin, 8] so each 8-channel
    output group is contiguous in memory in [cin, cout_sub] order.
    """
    cout, cin, _, _ = w_tensor.shape
    assert cout % 8 == 0
    w_grouped = w_tensor.squeeze(-1).squeeze(-1).view(cout // 8, 8, cin)
    return w_grouped.permute(0, 2, 1).contiguous()

def make_cfg_tensor(cout, m0, shift_n, zero_pt=0):
    word = (m0 & 0xFFFF) | ((shift_n & 0x3F) << 16) | ((zero_pt & 0xFF) << 22)
    return torch.tensor([word for _ in range(cout)], dtype=torch.int32)

def export_flat_mem(filename, tensor, hex_digits):
    filepath = os.path.join(target_dir, filename)
    flat_data = tensor.cpu().numpy().flatten()
    mask = (1 << (hex_digits * 4)) - 1
    with open(filepath, "w") as f:
        for val in flat_data:
            f.write(f"{(int(val) & mask):0{hex_digits}X}\n")
    vmin, vmax = int(flat_data.min()), int(flat_data.max())
    nz = int(np.count_nonzero(flat_data))
    print(f"  [EXPORT] {filename:<24} | Shape: {str(list(tensor.shape)):<18} | Elems: {len(flat_data):>6} | Range: [{vmin:>4}, {vmax:>4}] | NonZero: {nz:>6}")

print("=======================================================================")
print(" >>> CrocoScale SoC: 5-Layer Chained Weird-Dimension Stress Net     <<<")
print("=======================================================================")

# -----------------------------------------------------------------------------
# Mish Activation Look-Up Table (256 Entries)
# -----------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# Layer 1: 3x3 Conv, Mode A (Linear)
#   52x76x5 -> 52x76x16 (4x5=20 tiles, 2 Cout groups of 8, 6 passes/tile)
# -----------------------------------------------------------------------------
print("\n--- Layer 1: 3x3 Conv (52x76x5 -> 52x76x16, Mode A Linear) ---")
L1_H, L1_W, L1_CIN, L1_COUT = 52, 76, 5, 16
L1_M0, L1_SHIFT = 16384, 17  # Scale = 0.125

l1_in_nchw = torch.randint(-24, 25, size=(1, L1_CIN, L1_H, L1_W), dtype=torch.int8)
l1_w       = torch.randint(-8, 9, size=(L1_COUT, L1_CIN, 3, 3), dtype=torch.int8)
l1_b       = torch.randint(-60, 61, size=(L1_COUT,), dtype=torch.int32)

l1_raw_nchw = F.conv2d(l1_in_nchw.to(torch.int32), l1_w.to(torch.int32), bias=l1_b, stride=1, padding=1)
l1_raw_nhwc = l1_raw_nchw.squeeze(0).permute(1, 2, 0).contiguous()
l1_in_nhwc  = l1_in_nchw.squeeze(0).permute(1, 2, 0).contiguous()
l1_out_nhwc = hw_requantize(l1_raw_nhwc, L1_M0, L1_SHIFT, 0)

export_flat_mem("stress_l1_in_act.mem", l1_in_nhwc, 2)
export_flat_mem("stress_l1_w.mem",      pack_3x3_weights(l1_w), 2)
export_flat_mem("stress_l1_b.mem",      l1_b, 8)
export_flat_mem("stress_l1_cfg.mem",    make_cfg_tensor(L1_COUT, L1_M0, L1_SHIFT), 8)
export_flat_mem("stress_l1_out.mem",    l1_out_nhwc, 2)

# -----------------------------------------------------------------------------
# Layer 2: 1x1 Conv, Mode B (Mish LUT)
#   52x76x11 -> 52x76x8 (4x5=20 tiles, 3 passes/tile [odd], slices 11 of L1's 16 ch)
# -----------------------------------------------------------------------------
print("\n--- Layer 2: 1x1 Conv (52x76x11 -> 52x76x8, Mode B Mish LUT) ---")
L2_H, L2_W, L2_CIN, L2_COUT = 52, 76, 11, 8
L2_M0, L2_SHIFT = 16384, 16  # Scale = 0.25

l2_in_nhwc  = l1_out_nhwc[:, :, :L2_CIN].contiguous()
l2_in_nchw  = l2_in_nhwc.permute(2, 0, 1).unsqueeze(0).contiguous()
l2_w        = torch.randint(-8, 9, size=(L2_COUT, L2_CIN, 1, 1), dtype=torch.int8)
l2_b        = torch.randint(-40, 41, size=(L2_COUT,), dtype=torch.int32)

l2_raw_nchw = F.conv2d(l2_in_nchw.to(torch.int32), l2_w.to(torch.int32), bias=l2_b, stride=1, padding=0)
l2_raw_nhwc = l2_raw_nchw.squeeze(0).permute(1, 2, 0).contiguous()
l2_req_nhwc = hw_requantize(l2_raw_nhwc, L2_M0, L2_SHIFT, 0)
l2_out_nhwc = apply_lut(l2_req_nhwc, lut_mish_table)

export_flat_mem("stress_l2_w.mem",   pack_1x1_weights(l2_w), 2)
export_flat_mem("stress_l2_b.mem",   l2_b, 8)
export_flat_mem("stress_l2_cfg.mem", make_cfg_tensor(L2_COUT, L2_M0, L2_SHIFT), 8)
export_flat_mem("stress_l2_out.mem", l2_out_nhwc, 2)

# -----------------------------------------------------------------------------
# Layer 3: 3x3 Conv, Mode D (Mish LUT + 2x2 MaxPool)
#   52x76x6 -> 26x38x16 (4x5=20 tiles, 2 Cout groups of 8, 7 passes/tile [odd], slices 6 of L2's 8 ch)
# -----------------------------------------------------------------------------
print("\n--- Layer 3: 3x3 Conv (52x76x6 -> 26x38x16, Mode D Mish LUT + 2x2 MaxPool) ---")
L3_H, L3_W, L3_CIN, L3_COUT = 52, 76, 6, 16
L3_M0, L3_SHIFT = 16384, 16  # Scale = 0.25

l3_in_nhwc   = l2_out_nhwc[:, :, :L3_CIN].contiguous()
l3_in_nchw   = l3_in_nhwc.permute(2, 0, 1).unsqueeze(0).contiguous()
l3_w         = torch.randint(-8, 9, size=(L3_COUT, L3_CIN, 3, 3), dtype=torch.int8)
l3_b         = torch.randint(-40, 41, size=(L3_COUT,), dtype=torch.int32)

l3_raw_nchw  = F.conv2d(l3_in_nchw.to(torch.int32), l3_w.to(torch.int32), bias=l3_b, stride=1, padding=1)
l3_raw_nhwc  = l3_raw_nchw.squeeze(0).permute(1, 2, 0).contiguous()
l3_req_nhwc  = hw_requantize(l3_raw_nhwc, L3_M0, L3_SHIFT, 0)
l3_mish_nhwc = apply_lut(l3_req_nhwc, lut_mish_table)
l3_out_nhwc  = apply_maxpool_nhwc(l3_mish_nhwc)

export_flat_mem("stress_l3_w.mem",   pack_3x3_weights(l3_w), 2)
export_flat_mem("stress_l3_b.mem",   l3_b, 8)
export_flat_mem("stress_l3_cfg.mem", make_cfg_tensor(L3_COUT, L3_M0, L3_SHIFT), 8)
export_flat_mem("stress_l3_out.mem", l3_out_nhwc, 2)

# -----------------------------------------------------------------------------
# Layer 4: 1x1 Conv, Mode C (Linear + 2x2 MaxPool)
#   26x38x13 -> 13x19x8 (2x3=6 tiles, 4 passes/tile, slices 13 of L3's 16 ch)
# -----------------------------------------------------------------------------
print("\n--- Layer 4: 1x1 Conv (26x38x13 -> 13x19x8, Mode C Linear + 2x2 MaxPool) ---")
L4_H, L4_W, L4_CIN, L4_COUT = 26, 38, 13, 8
L4_M0, L4_SHIFT = 16384, 16  # Scale = 0.25

l4_in_nhwc  = l3_out_nhwc[:, :, :L4_CIN].contiguous()
l4_in_nchw  = l4_in_nhwc.permute(2, 0, 1).unsqueeze(0).contiguous()
l4_w        = torch.randint(-8, 9, size=(L4_COUT, L4_CIN, 1, 1), dtype=torch.int8)
l4_b        = torch.randint(-30, 31, size=(L4_COUT,), dtype=torch.int32)

l4_raw_nchw = F.conv2d(l4_in_nchw.to(torch.int32), l4_w.to(torch.int32), bias=l4_b, stride=1, padding=0)
l4_raw_nhwc = l4_raw_nchw.squeeze(0).permute(1, 2, 0).contiguous()
l4_req_nhwc = hw_requantize(l4_raw_nhwc, L4_M0, L4_SHIFT, 0)
l4_out_nhwc = apply_maxpool_nhwc(l4_req_nhwc)

export_flat_mem("stress_l4_w.mem",   pack_1x1_weights(l4_w), 2)
export_flat_mem("stress_l4_b.mem",   l4_b, 8)
export_flat_mem("stress_l4_cfg.mem", make_cfg_tensor(L4_COUT, L4_M0, L4_SHIFT), 8)
export_flat_mem("stress_l4_out.mem", l4_out_nhwc, 2)

# -----------------------------------------------------------------------------
# Layer 5: 3x3 Conv, Mode B (Mish LUT)
#   13x19x7 -> 13x19x8 (1x2=2 tiles, 8 passes/tile, slices 7 of L4's 8 ch, odd 13x19 input)
# -----------------------------------------------------------------------------
print("\n--- Layer 5: 3x3 Conv (13x19x7 -> 13x19x8, Mode B Mish LUT) ---")
L5_H, L5_W, L5_CIN, L5_COUT = 13, 19, 7, 8
L5_M0, L5_SHIFT = 16384, 16  # Scale = 0.25

l5_in_nhwc  = l4_out_nhwc[:, :, :L5_CIN].contiguous()
l5_in_nchw  = l5_in_nhwc.permute(2, 0, 1).unsqueeze(0).contiguous()
l5_w        = torch.randint(-8, 9, size=(L5_COUT, L5_CIN, 3, 3), dtype=torch.int8)
l5_b        = torch.randint(-30, 31, size=(L5_COUT,), dtype=torch.int32)

l5_raw_nchw = F.conv2d(l5_in_nchw.to(torch.int32), l5_w.to(torch.int32), bias=l5_b, stride=1, padding=1)
l5_raw_nhwc = l5_raw_nchw.squeeze(0).permute(1, 2, 0).contiguous()
l5_req_nhwc = hw_requantize(l5_raw_nhwc, L5_M0, L5_SHIFT, 0)
l5_out_nhwc = apply_lut(l5_req_nhwc, lut_mish_table)

export_flat_mem("stress_l5_w.mem",   pack_3x3_weights(l5_w), 2)
export_flat_mem("stress_l5_b.mem",   l5_b, 8)
export_flat_mem("stress_l5_cfg.mem", make_cfg_tensor(L5_COUT, L5_M0, L5_SHIFT), 8)
export_flat_mem("stress_l5_out.mem", l5_out_nhwc, 2)

print("\n>>> SUCCESS: 5-Layer Chained Weird-Dimension Stress Net generated! <<<\n")
