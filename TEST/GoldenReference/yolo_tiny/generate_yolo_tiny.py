#!/usr/bin/env python3
"""
Generates hardware-exact INT8 test vectors and pre-packed 32-bit AXI4 memory
streams for the 100% Full, Unpruned 9-Layer Tiny-YOLOv2 Cat Detection Testbench
(tb_npu_flex_yolo_tiny.sv).

Source Model:
  Official ONNX Model Zoo Pascal VOC Tiny-YOLOv2 (tinyyolov2-8.onnx, 20 classes)
  with BatchNorm folded into Conv weights/biases and all 9 layers at full
  unpruned channel counts ([16, 32, 64, 128, 256, 512, 1024, 1024, 125]),
  including Layer 6's 2x2 stride-1 asymmetric MaxPool (pool_s1_en=1) and
  up to 1,152 passes per output group (Cin=1024).

Source Image:
  Public COCO val2017 image 000000039769.jpg at full 416x416x3 resolution.
"""

import os
import struct
import numpy as np

VOC_CLASSES = [
    "aeroplane", "bicycle", "bird", "boat", "bottle",
    "bus", "car", "cat", "chair", "cow",
    "diningtable", "dog", "horse", "motorbike", "person",
    "pottedplant", "sheep", "sofa", "train", "tvmonitor"
]

ANCHORS = np.array([
    [1.08, 1.19], [3.42, 4.41], [6.63, 11.38], [9.42, 5.11], [16.62, 10.52]
], dtype=np.float32)


def fast_savetxt_hex32(path, arr_u32):
    """
    Fast C-speed writer for 32-bit hex .mem files (%08x with Unix LF).
    """
    hex_bytes = np.frombuffer(
        arr_u32.astype(">u4").tobytes().hex().encode("ascii"), dtype=np.uint8
    ).reshape(-1, 8)
    out = np.empty((hex_bytes.shape[0], 9), dtype=np.uint8)
    out[:, :8] = hex_bytes
    out[:, 8] = ord("\n")
    out.tofile(path)


def read_varint(buf, pos):
    result = 0
    shift = 0
    while True:
        b = buf[pos]
        pos += 1
        result |= (b & 0x7F) << shift
        if not (b & 0x80):
            return result, pos
        shift += 7


def parse_onnx_initializers(onnx_path):
    with open(onnx_path, "rb") as f:
        data = f.read()

    tensors = {}

    def parse_tensor_proto(buf):
        pos = 0
        end = len(buf)
        dims = []
        data_type = 0
        name = ""
        raw_data = None
        float_data = []
        while pos < end:
            tag, pos = read_varint(buf, pos)
            field_num = tag >> 3
            wire_type = tag & 0x7
            if wire_type == 0:
                val, pos = read_varint(buf, pos)
                if field_num == 1:
                    dims.append(val)
                elif field_num == 2:
                    data_type = val
            elif wire_type == 2:
                length, pos = read_varint(buf, pos)
                sub = buf[pos:pos + length]
                pos += length
                if field_num == 1:
                    p2 = 0
                    while p2 < len(sub):
                        d, p2 = read_varint(sub, p2)
                        dims.append(d)
                elif field_num == 4:
                    cnt = len(sub) // 4
                    float_data.extend(struct.unpack(f"<{cnt}f", sub))
                elif field_num == 8:
                    name = sub.decode("utf-8", errors="replace")
                elif field_num == 9:
                    raw_data = sub
            elif wire_type == 5:
                if field_num == 4:
                    float_data.append(struct.unpack("<f", buf[pos:pos + 4])[0])
                pos += 4
            elif wire_type == 1:
                pos += 8
        if data_type == 1:
            if raw_data is not None:
                arr = np.frombuffer(raw_data, dtype=np.float32).copy()
            elif float_data:
                arr = np.array(float_data, dtype=np.float32)
            else:
                return
            if dims:
                arr = arr.reshape(dims)
            tensors[name] = arr

    def parse_graph_proto(buf):
        pos = 0
        end = len(buf)
        while pos < end:
            tag, pos = read_varint(buf, pos)
            field_num = tag >> 3
            wire_type = tag & 0x7
            if wire_type == 0:
                _, pos = read_varint(buf, pos)
            elif wire_type == 2:
                length, pos = read_varint(buf, pos)
                sub = buf[pos:pos + length]
                pos += length
                if field_num == 5:
                    parse_tensor_proto(sub)
            elif wire_type == 5:
                pos += 4
            elif wire_type == 1:
                pos += 8

    pos = 0
    end = len(data)
    while pos < end:
        tag, pos = read_varint(data, pos)
        field_num = tag >> 3
        wire_type = tag & 0x7
        if wire_type == 0:
            _, pos = read_varint(data, pos)
        elif wire_type == 2:
            length, pos = read_varint(data, pos)
            sub = data[pos:pos + length]
            pos += length
            if field_num == 7:
                parse_graph_proto(sub)
        elif wire_type == 5:
            pos += 4
        elif wire_type == 1:
            pos += 8

    return tensors


def conv2d_np(x, w, b=None):
    c_out, c_in, kh, kw = w.shape
    _, h, width = x.shape
    if kh == 1:
        out = (w.reshape(c_out, c_in) @ x.reshape(c_in, -1)).reshape(c_out, h, width)
    else:
        x_pad = np.pad(x, ((0, 0), (1, 1), (1, 1)), mode="constant")
        shape = (c_in, kh, kw, h, width)
        strides = (x_pad.strides[0], x_pad.strides[1], x_pad.strides[2], x_pad.strides[1], x_pad.strides[2])
        cols = np.lib.stride_tricks.as_strided(x_pad, shape=shape, strides=strides)
        out = (w.reshape(c_out, c_in * kh * kw) @ cols.reshape(c_in * kh * kw, h * width)).reshape(c_out, h, width)
    if b is not None:
        out = out + b[:, None, None]
    return out


def maxpool2x2_s2(x):
    c, h, w = x.shape
    h2, w2 = h // 2, w // 2
    return x[:, :h2 * 2, :w2 * 2].reshape(c, h2, 2, w2, 2).max(axis=(2, 4))


def maxpool2x2_s1(x):
    """
    2x2 stride-1 asymmetric MaxPool with clamped right/bottom boundary
    (mathematically identical to Darknet's -inf right/bottom padding and
    hardware's pool_s1_en_i clamped coordinate generator in npu_flex_psum.sv).
    """
    x_pad = np.pad(x, ((0, 0), (0, 1), (0, 1)), mode="edge")
    return np.maximum(
        np.maximum(x_pad[:, :-1, :-1], x_pad[:, :-1, 1:]),
        np.maximum(x_pad[:, 1:, :-1], x_pad[:, 1:, 1:])
    )


def softmax(x, axis=0):
    e = np.exp(x - np.max(x, axis=axis, keepdims=True))
    return e / np.sum(e, axis=axis, keepdims=True)


def sigmoid(x):
    return 1.0 / (1.0 + np.exp(-np.clip(x, -50, 50)))


def decode_yolo_output(grid_out):
    _, gh, gw = grid_out.shape
    preds = grid_out[:125].reshape(5, 25, gh, gw)
    obj = sigmoid(preds[:, 4, :, :])
    cls_logits = preds[:, 5:25, :, :]
    cls_probs = softmax(cls_logits, axis=1)
    scores = obj[:, None, :, :] * cls_probs
    best_flat = int(np.argmax(scores))
    a, c, gy, gx = np.unravel_index(best_flat, scores.shape)
    top_score = float(scores[a, c, gy, gx])
    cls_max = scores.max(axis=(0, 2, 3))
    return int(c), VOC_CLASSES[c], top_score, (int(a), int(gy), int(gx)), cls_max, preds


def get_w_stride(w_dim):
    if w_dim <= 16:
        return 16
    elif w_dim <= 32:
        return 32
    elif w_dim <= 64:
        return 64
    elif w_dim <= 128:
        return 128
    elif w_dim <= 256:
        return 256
    else:
        return 512


def pack_3x3_weights_axi(w_out_in_kh_kw):
    """
    Vectorized packing of 3x3 weights [C_out_padded, C_in, 3, 3] (int8) into
    32-bit AXI burst words matching npu_flex_axi_reader RD_WEIGHT_R:
      For each Cout group g in 0 .. (C_out_padded/8 - 1):
        For each pass p in 0 .. ceil(C_in * 9 / 8) - 1:
          16 words (64 bytes):
            b = 0..7 (col = 7 - b):
              word[b]   = {r3, r2, r1, r0}
              word[8+b] = {r7, r6, r5, r4}
    """
    c_out_pad, c_in, _, _ = w_out_in_kh_kw.shape
    groups = c_out_pad // 8
    num_passes = (c_in * 9 + 7) // 8
    w_flat = w_out_in_kh_kw.view(np.uint8).reshape(c_out_pad, c_in * 9)
    w_pad = np.zeros((c_out_pad, num_passes * 8), dtype=np.uint8)
    w_pad[:, :c_in * 9] = w_flat
    w_grp = w_pad.reshape(groups, 8, num_passes, 8)
    w_gpbr = w_grp[:, ::-1, :, :].transpose(0, 2, 1, 3).astype(np.uint32)
    w_lo = (w_gpbr[:, :, :, 3] << 24) | (w_gpbr[:, :, :, 2] << 16) | (w_gpbr[:, :, :, 1] << 8) | w_gpbr[:, :, :, 0]
    w_hi = (w_gpbr[:, :, :, 7] << 24) | (w_gpbr[:, :, :, 6] << 16) | (w_gpbr[:, :, :, 5] << 8) | w_gpbr[:, :, :, 4]
    return np.concatenate([w_lo, w_hi], axis=2).reshape(-1)


def pack_1x1_weights_axi(w_out_in_1_1):
    """
    Vectorized packing of 1x1 weights [C_out_padded, C_in, 1, 1] (int8) into
    32-bit AXI burst words matching npu_flex_axi_reader RD_WEIGHT_R (mode_1x1=1):
      For each Cout group g in 0 .. (C_out_padded/8 - 1):
        For each pass p in 0 .. ceil(C_in / 4) - 1:
          8 words (32 bytes):
            b = 0..7 (col = 7 - b):
              word[b] = {r3, r2, r1, r0} where cin = p * 4 + r.
    """
    c_out_pad, c_in, _, _ = w_out_in_1_1.shape
    groups = c_out_pad // 8
    num_passes = (c_in + 3) // 4
    w_flat = w_out_in_1_1.view(np.uint8).reshape(c_out_pad, c_in)
    w_pad = np.zeros((c_out_pad, num_passes * 4), dtype=np.uint8)
    w_pad[:, :c_in] = w_flat
    w_grp = w_pad.reshape(groups, 8, num_passes, 4)
    w_gpbr = w_grp[:, ::-1, :, :].transpose(0, 2, 1, 3).astype(np.uint32)
    words = (w_gpbr[:, :, :, 3] << 24) | (w_gpbr[:, :, :, 2] << 16) | (w_gpbr[:, :, :, 1] << 8) | w_gpbr[:, :, :, 0]
    return words.reshape(-1)


def pack_act_strips_axi(act_c_h_w):
    """
    Vectorized packing of activation tensor [C, H, W] (int8) into 32-bit words
    of shape [C, ceil(H/4), W_stride] in System RAM layout:
      word = {row3, row2, row1, row0}
    """
    c_dim, h_dim, w_dim = act_c_h_w.shape
    num_strips = (h_dim + 3) // 4
    w_stride = get_w_stride(w_dim)
    pad = np.zeros((c_dim, num_strips * 4, w_stride), dtype=np.uint8)
    pad[:, :h_dim, :w_dim] = act_c_h_w.view(np.uint8)
    pad = pad.reshape(c_dim, num_strips, 4, w_stride).astype(np.uint32)
    words = (pad[:, :, 3, :] << 24) | (pad[:, :, 2, :] << 16) | (pad[:, :, 1, :] << 8) | pad[:, :, 0, :]
    return words.reshape(-1)


def main():
    out_dir = "TEST/GoldenReference/yolo_tiny"
    os.makedirs(out_dir, exist_ok=True)

    tensors = parse_onnx_initializers("/tmp/tinyyolov2-8.onnx")
    layers = []
    for i in range(8):
        sfx = "" if i == 0 else str(i)
        W = tensors[f"convolution{sfx}_W"]
        scale = tensors[f"BatchNormalization_scale{sfx}"]
        B = tensors[f"BatchNormalization_B{sfx}"]
        mean = tensors[f"BatchNormalization_mean{sfx}"]
        var = tensors[f"BatchNormalization_variance{sfx}"]
        factor = scale / np.sqrt(var + 1e-5)
        W_f = W * factor[:, None, None, None]
        B_f = B - mean * factor
        layers.append((W_f.astype(np.float32), B_f.astype(np.float32), 3))
    W8 = tensors["convolution8_W"].astype(np.float32)
    B8 = tensors["convolution8_B"].astype(np.float32)
    layers.append((W8, B8, 1))

    # Load full 416x416x3 tabby cat image from COCO val2017 000000039769.jpg
    full_416 = np.fromfile("gemini_workspace/cat1_416.rgb", dtype=np.uint8).reshape(416, 416, 3)
    full_416.tofile(os.path.join(out_dir, "cat_full_416x416.rgb"))
    x_fp = full_416.transpose(2, 0, 1).astype(np.float32) / 255.0

    # Build 256-entry LeakyReLU(0.1) LUT
    leaky_lut = np.zeros(256, dtype=np.int8)
    for u in range(256):
        s = u if u < 128 else (u - 256)
        leaky_lut[u] = s if s >= 0 else int(np.round(0.1 * s))

    lut_words = []
    for w in range(64):
        b0 = int(leaky_lut[w * 4 + 0]) & 0xFF
        b1 = int(leaky_lut[w * 4 + 1]) & 0xFF
        b2 = int(leaky_lut[w * 4 + 2]) & 0xFF
        b3 = int(leaky_lut[w * 4 + 3]) & 0xFF
        lut_words.append((b3 << 24) | (b2 << 16) | (b1 << 8) | b0)
    fast_savetxt_hex32(os.path.join(out_dir, "yolo_lut_axi.mem"), np.array(lut_words, dtype=np.uint32))

    def hw_requantize_layer(psum_3d, m0_arr, shift_arr, use_lut=True):
        """
        Vectorized per-channel hardware-exact requantization across [C, H, W].
        """
        c_dim = psum_3d.shape[0]
        out = np.zeros_like(psum_3d, dtype=np.int8)
        for c in range(c_dim):
            prod = psum_3d[c].astype(np.int64) * int(m0_arr[c])
            shift_n = int(shift_arr[c])
            if shift_n > 0:
                half = 1 << (shift_n - 1)
                round_off = np.where(prod < 0, half - 1, half)
                shifted = (prod + round_off) >> shift_n
            else:
                shifted = prod
            val = np.clip(shifted, -128, 127).astype(np.int8)
            if use_lut:
                val = leaky_lut[val.view(np.uint8)]
            out[c] = val
        return out

    def quantize_multiplier(real_mult):
        if real_mult <= 0:
            return 1, 20
        shift_n = 15
        while shift_n < 46 and real_mult * (1 << (shift_n + 1)) < 32767.0:
            shift_n += 1
        while shift_n > 0 and real_mult * (1 << shift_n) >= 32767.5:
            shift_n -= 1
        m0 = int(np.clip(np.round(real_mult * (1 << shift_n)), 1, 32767))
        return m0, shift_n

    # Quantize input image to INT8 [3, 416, 416]
    curr_q = np.clip(np.round(x_fp * 127.0), -128, 127).astype(np.int8)
    s_in = 1.0 / 127.0

    l1_in_words = pack_act_strips_axi(curr_q)
    fast_savetxt_hex32(os.path.join(out_dir, "yolo_l1_in_axi.mem"), l1_in_words)
    print(f"L1 Input [3x416x416] packed: {len(l1_in_words)} words ({len(l1_in_words)*4/1024:.1f} KB)")

    all_w_words = []
    all_b_words = []
    all_q_words = []

    w_word_offset = 0
    b_word_offset = 0
    q_word_offset = 0

    for idx, (W, B, k) in enumerate(layers):
        c_out, c_in, kh, kw = W.shape
        c_out_pad = ((c_out + 7) // 8) * 8
        groups = c_out_pad // 8
        num_passes = ((c_in + 3) // 4) if k == 1 else ((c_in * 9 + 7) // 8)

        w_q_pad = np.zeros((c_out_pad, c_in, kh, kw), dtype=np.int8)
        b_q_pad = np.zeros(c_out_pad, dtype=np.int32)
        s_w_pad = np.ones(c_out_pad, dtype=np.float64)
        q_cfg_pad = np.zeros(c_out_pad, dtype=np.uint32)
        m0_arr = np.ones(c_out_pad, dtype=np.int32)
        shift_arr = np.full(c_out_pad, 20, dtype=np.int32)

        for c in range(c_out_pad):
            if c < c_out:
                w_c = W[c]
                s_w = max(float(np.max(np.abs(w_c))) / 127.0, 1e-8)
                w_q = np.clip(np.round(w_c / s_w), -128, 127).astype(np.int8)
                b_q = int(np.round(B[c] / (s_in * s_w)))
                s_w_pad[c] = s_w
            else:
                w_q = np.zeros((c_in, kh, kw), dtype=np.int8)
                b_q = 0
                s_w_pad[c] = 1e-6

            w_q_pad[c] = w_q
            b_q_pad[c] = b_q

        # Exact integer convolution across all c_out_pad channels via float64 BLAS GEMM (53-bit exact integer mantissa)
        psum_all = conv2d_np(curr_q.astype(np.float64), w_q_pad.astype(np.float64)).astype(np.int64) + b_q_pad[:, None, None].astype(np.int64)

        # Sequential 99.90% percentile activation scale calibration on valid channels
        fp_pre = psum_all[:c_out].astype(np.float64) * (s_in * s_w_pad[:c_out, None, None])
        if idx < 8:
            max_abs_out = float(np.percentile(np.abs(fp_pre), 99.90))
        else:
            max_abs_out = float(np.max(np.abs(fp_pre)))
        s_out = max(max_abs_out / 126.0, 1e-6)

        for c in range(c_out_pad):
            if c < c_out:
                m0, shift_n = quantize_multiplier((s_in * s_w_pad[c]) / s_out)
            else:
                m0, shift_n = 1, 20
            m0_arr[c] = m0
            shift_arr[c] = shift_n
            # quant_cfg: [15:0]=m0, [21:16]=shift_n, [29:22]=zp(0)
            q_cfg_pad[c] = ((shift_n & 0x3F) << 16) | (m0 & 0xFFFF)

        out_q = hw_requantize_layer(psum_all, m0_arr, shift_arr, use_lut=(idx < 8))

        if idx < 5:
            out_q = maxpool2x2_s2(out_q)
        elif idx == 5:
            out_q = maxpool2x2_s1(out_q)

        # Pack weights, biases, and quant configs (reversed per group of 8 for shift chain!)
        w_words = pack_1x1_weights_axi(w_q_pad) if k == 1 else pack_3x3_weights_axi(w_q_pad)
        b_words = b_q_pad.view(np.uint32)
        q_words = np.zeros(c_out_pad, dtype=np.uint32)
        for g in range(groups):
            for c in range(8):
                q_words[g * 8 + c] = q_cfg_pad[g * 8 + (7 - c)]

        # Save golden output in System RAM strip format [C_out_pad, ceil(H_out/4), W_stride]
        out_strip_words = pack_act_strips_axi(out_q)
        fast_savetxt_hex32(os.path.join(out_dir, f"yolo_l{idx+1}_out_axi.mem"), out_strip_words)

        pool_str = "s2" if idx < 5 else ("s1" if idx == 5 else "--")
        print(f"L{idx+1} ({k}x{k} pool={pool_str}): Cin={c_in:4d} Cout={c_out:4d}(pad {c_out_pad:4d}) | "
              f"H_out={out_q.shape[1]:3d} W_out={out_q.shape[2]:3d} | "
              f"Groups={groups:3d} Passes={num_passes:4d} | "
              f"W_off=0x{w_word_offset*4:08x} ({len(w_words):7d} words) "
              f"B_off=0x{b_word_offset*4:04x} Q_off=0x{q_word_offset*4:04x} "
              f"Out_words={len(out_strip_words)}")

        all_w_words.append(w_words)
        all_b_words.append(b_words)
        all_q_words.append(q_words)

        w_word_offset += len(w_words)
        b_word_offset += len(b_words)
        q_word_offset += len(q_words)

        # Next layer consumes only the valid c_out channels
        curr_q = out_q[:c_out]
        s_in = s_out

    all_w_arr = np.concatenate(all_w_words)
    all_b_arr = np.concatenate(all_b_words)
    all_q_arr = np.concatenate(all_q_words)

    fast_savetxt_hex32(os.path.join(out_dir, "yolo_weights_axi.mem"), all_w_arr)
    fast_savetxt_hex32(os.path.join(out_dir, "yolo_bias_axi.mem"), all_b_arr)
    fast_savetxt_hex32(os.path.join(out_dir, "yolo_quant_axi.mem"), all_q_arr)

    print(f"\nTotal Weight Words: {len(all_w_arr)} ({len(all_w_arr)*4/(1024*1024):.2f} MB)")
    print(f"Total Bias Words:   {len(all_b_arr)}")
    print(f"Total Quant Words:  {len(all_q_arr)}")
    print(f"Final L9 Output Scale s_out = {s_in:.6f}")

    # Decode final L9 output (13x13x125)
    grid_dequant = curr_q.astype(np.float32) * s_in
    cls_id, cls_name, top_score, loc, cls_max, preds_int8 = decode_yolo_output(grid_dequant)
    print(f"\n=== FINAL HARDWARE-EXACT INT8 FULL TINY-YOLOv2 (416x416) DETECTION RESULT ===")
    print(f"Top-1 Predicted Class: #{cls_id} '{cls_name.upper()}' (Confidence = {top_score:.4f} at Anchor={loc[0]}, GridY={loc[1]}, GridX={loc[2]})")
    ranked = np.argsort(cls_max)[::-1]
    for rank, cid in enumerate(ranked[:5], 1):
        print(f"  Rank {rank}: class #{cid:2d} ({VOC_CLASSES[cid]:11s}) score = {cls_max[cid]:.4f}")

    # Print raw INT8 logits at the winning anchor/cell
    a_win, gy_win, gx_win = loc
    raw_cell = curr_q[:125].reshape(5, 25, 13, 13)[a_win, :, gy_win, gx_win]
    print(f"\nWinning Cell (Anchor={a_win}, Y={gy_win}, X={gx_win}) Raw INT8 Attributes:")
    print(f"  tx={int(raw_cell[0])}, ty={int(raw_cell[1])}, tw={int(raw_cell[2])}, th={int(raw_cell[3])}, obj_logit={int(raw_cell[4])}")
    cls_int8_scores = raw_cell[5:25]
    for cid in ranked[:5]:
        print(f"  Class #{cid:2d} ({VOC_CLASSES[cid]:11s}): raw_int8_logit = {int(cls_int8_scores[cid]):+4d}")


if __name__ == "__main__":
    main()
