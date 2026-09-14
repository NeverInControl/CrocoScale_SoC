#!/usr/bin/env python3
"""
NPU Whole-Network Golden Reference Generator (Keras / TFLite)
- 5-Layer Backbone with Resolution Downsampling (Stride-2):
    L1: 3x3 Conv (16 -> 24), Stride 1, SAME, 64x64 -> 64x64, ReLU
    L2: 1x1 Conv (24 -> 24), Stride 1, SAME, 64x64 -> 64x64, ReLU
    L3: 3x3 Conv (24 -> 24), Stride 2, SAME, 64x64 -> 32x32, ReLU
    L4: 1x1 Conv (24 -> 16), Stride 1, SAME, 32x32 -> 32x32, ReLU
    L5: 3x3 Conv (16 -> 16), Stride 1, SAME, 32x32 -> 32x32, Native Keras SiLU
- Total Compute: 24.58 Million MACs
"""

import math
import numpy as np
import tensorflow as tf

np.random.seed(42)
tf.random.set_seed(42)

# Problem Dimensions
H_IN, W_IN = 64, 64
H_OUT, W_OUT = 32, 32
C0, C1, C2, C3, C4, C5 = 16, 24, 24, 24, 16, 16

# ------------------------------------------------------------------------------
# 1. Build Canonical Keras Model with Strided Downsampling
# ------------------------------------------------------------------------------
inputs = tf.keras.Input(shape=(H_IN, W_IN, C0), batch_size=1, name="net_in")

x1 = tf.keras.layers.Conv2D(C1, (3, 3), strides=(1, 1), padding='same', activation='relu', use_bias=True, name="conv1")(inputs)
x2 = tf.keras.layers.Conv2D(C2, (1, 1), strides=(1, 1), padding='same', activation='relu', use_bias=True, name="conv2")(x1)
# Layer 3: Downsamples 64x64 -> 32x32 via Stride 2
x3 = tf.keras.layers.Conv2D(C3, (3, 3), strides=(2, 2), padding='same', activation='relu', use_bias=True, name="conv3")(x2)
x4 = tf.keras.layers.Conv2D(C4, (1, 1), strides=(1, 1), padding='same', activation='relu', use_bias=True, name="conv4")(x3)

x5_conv = tf.keras.layers.Conv2D(C5, (3, 3), strides=(1, 1), padding='same', activation=None, use_bias=True, name="conv5_conv")(x4)
x5_silu = tf.keras.layers.Activation(tf.nn.silu, name="conv5_silu")(x5_conv)

model = tf.keras.Model(inputs=inputs, outputs=[x1, x2, x3, x4, x5_conv, x5_silu])

# ------------------------------------------------------------------------------
# 2. TFLite INT8 Quantization
# ------------------------------------------------------------------------------
def representative_dataset_gen():
    for _ in range(50):
        data = np.random.uniform(-1.0, 1.0, size=(1, H_IN, W_IN, C0)).astype(np.float32)
        yield [data]

converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.representative_dataset = representative_dataset_gen
converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
converter.inference_input_type = tf.int8
converter.inference_output_type = tf.int8

tflite_quant_model = converter.convert()

interpreter = tf.lite.Interpreter(model_content=tflite_quant_model)
interpreter.allocate_tensors()

input_details  = interpreter.get_input_details()
output_details = interpreter.get_output_details()
tensor_details = interpreter.get_tensor_details()
tensor_dict    = {t['index']: t for t in tensor_details}

test_input = np.random.randint(-16, 16, size=(1, H_IN, W_IN, C0), dtype=np.int8)
interpreter.set_tensor(input_details[0]['index'], test_input)
interpreter.invoke()

# ------------------------------------------------------------------------------
# 3. Topologically Ordered Tensor Extraction
# ------------------------------------------------------------------------------
ops = interpreter._get_ops_details()
conv_ops = [op for op in ops if 'CONV' in op['op_name'].upper()]
assert len(conv_ops) == 5, f"Expected 5 Conv ops, found {len(conv_ops)}"

w_indices   = [op['inputs'][1] for op in conv_ops]
b_indices   = [op['inputs'][2] for op in conv_ops]
out_indices = [op['outputs'][0] for op in conv_ops]

expected_w_shapes = [
    (C1, 3, 3, C0),  # L1: (24, 3, 3, 16)
    (C2, 1, 1, C1),  # L2: (24, 1, 1, 24)
    (C3, 3, 3, C2),  # L3: (24, 3, 3, 24)
    (C4, 1, 1, C3),  # L4: (16, 1, 1, 24)
    (C5, 3, 3, C4)   # L5: (16, 3, 3, 16)
]
for i in range(5):
    w_shape = tuple(interpreter.get_tensor(w_indices[i]).shape)
    assert w_shape == expected_w_shapes[i], f"Layer {i+1} weight shape mismatch: {w_shape} vs {expected_w_shapes[i]}"

out_indices_set = set(out_indices)
silu_output_entries = [t for t in output_details if t['index'] not in out_indices_set]
assert len(silu_output_entries) == 1, f"Expected 1 final SiLU output, found {len(silu_output_entries)}"
out5_silu_idx = silu_output_entries[0]['index']

# ------------------------------------------------------------------------------
# 4. Golden Activations & Scale Multipliers
# ------------------------------------------------------------------------------
gold_l1      = interpreter.get_tensor(out_indices[0]).squeeze(0)
gold_l2      = interpreter.get_tensor(out_indices[1]).squeeze(0)
gold_l3      = interpreter.get_tensor(out_indices[2]).squeeze(0)
gold_l4      = interpreter.get_tensor(out_indices[3]).squeeze(0)
gold_l5_conv = interpreter.get_tensor(out_indices[4]).squeeze(0)
gold_l5_silu = interpreter.get_tensor(out5_silu_idx).squeeze(0)

s_in  = float(np.ravel(input_details[0]['quantization_parameters']['scales'])[0])
zp_in = int(np.ravel(input_details[0]['quantization_parameters']['zero_points'])[0])

s_l1  = float(np.ravel(tensor_dict[out_indices[0]]['quantization_parameters']['scales'])[0])
zp_l1 = int(np.ravel(tensor_dict[out_indices[0]]['quantization_parameters']['zero_points'])[0])

s_l2  = float(np.ravel(tensor_dict[out_indices[1]]['quantization_parameters']['scales'])[0])
zp_l2 = int(np.ravel(tensor_dict[out_indices[1]]['quantization_parameters']['zero_points'])[0])

s_l3  = float(np.ravel(tensor_dict[out_indices[2]]['quantization_parameters']['scales'])[0])
zp_l3 = int(np.ravel(tensor_dict[out_indices[2]]['quantization_parameters']['zero_points'])[0])

s_l4  = float(np.ravel(tensor_dict[out_indices[3]]['quantization_parameters']['scales'])[0])
zp_l4 = int(np.ravel(tensor_dict[out_indices[3]]['quantization_parameters']['zero_points'])[0])

s_l5_conv  = float(np.ravel(tensor_dict[out_indices[4]]['quantization_parameters']['scales'])[0])
zp_l5_conv = int(np.ravel(tensor_dict[out_indices[4]]['quantization_parameters']['zero_points'])[0])

s_l5_silu  = float(np.ravel(tensor_dict[out5_silu_idx]['quantization_parameters']['scales'])[0])
zp_l5_silu = int(np.ravel(tensor_dict[out5_silu_idx]['quantization_parameters']['zero_points'])[0])

# Weights & Folded Biases
w1_hw = interpreter.get_tensor(w_indices[0]).transpose(1, 2, 3, 0)
b1_f  = interpreter.get_tensor(b_indices[0]) - (zp_in * np.sum(w1_hw.astype(np.int32), axis=(0, 1, 2)))
s_w1  = np.ravel(tensor_dict[w_indices[0]]['quantization_parameters']['scales'])

w2_hw = interpreter.get_tensor(w_indices[1]).transpose(1, 2, 3, 0)
b2_f  = interpreter.get_tensor(b_indices[1]) - (zp_l1 * np.sum(w2_hw.astype(np.int32), axis=(0, 1, 2)))
s_w2  = np.ravel(tensor_dict[w_indices[1]]['quantization_parameters']['scales'])

w3_hw = interpreter.get_tensor(w_indices[2]).transpose(1, 2, 3, 0)
b3_f  = interpreter.get_tensor(b_indices[2]) - (zp_l2 * np.sum(w3_hw.astype(np.int32), axis=(0, 1, 2)))
s_w3  = np.ravel(tensor_dict[w_indices[2]]['quantization_parameters']['scales'])

w4_hw = interpreter.get_tensor(w_indices[3]).transpose(1, 2, 3, 0)
b4_f  = interpreter.get_tensor(b_indices[3]) - (zp_l3 * np.sum(w4_hw.astype(np.int32), axis=(0, 1, 2)))
s_w4  = np.ravel(tensor_dict[w_indices[3]]['quantization_parameters']['scales'])

w5_hw = interpreter.get_tensor(w_indices[4]).transpose(1, 2, 3, 0)
b5_f  = interpreter.get_tensor(b_indices[4]) - (zp_l4 * np.sum(w5_hw.astype(np.int32), axis=(0, 1, 2)))
s_w5  = np.ravel(tensor_dict[w_indices[4]]['quantization_parameters']['scales'])

def compute_q15_params(s_in_val, s_w_arr, s_out_val):
    m0_list, shift_list = [], []
    for s_w in s_w_arr:
        M = (s_in_val * s_w) / s_out_val
        sig, exp = math.frexp(M)
        m0 = int(round(sig * (1 << 15)))
        if m0 == (1 << 15):
            m0 = m0 // 2
            exp += 1
        shift = -exp + 15
        m0_list.append(m0)
        shift_list.append(shift)
    return np.array(m0_list, dtype=np.int32), np.array(shift_list, dtype=np.int32)

m0_l1, shift_l1 = compute_q15_params(s_in,  s_w1, s_l1)
m0_l2, shift_l2 = compute_q15_params(s_l1,  s_w2, s_l2)
m0_l3, shift_l3 = compute_q15_params(s_l2,  s_w3, s_l3)
m0_l4, shift_l4 = compute_q15_params(s_l3,  s_w4, s_l4)
m0_l5, shift_l5 = compute_q15_params(s_l4,  s_w5, s_l5_conv)

# Hardware Bank B SiLU LUT Table
lut_silu_table = np.zeros(256, dtype=np.int8)
for addr in range(256):
    signed_val = addr if addr < 128 else (addr - 256)
    real_x = (signed_val - zp_l5_conv) * s_l5_conv
    real_silu = tf.nn.silu(tf.constant(real_x, dtype=tf.float32)).numpy()
    q_silu = int(round(real_silu / s_l5_silu)) + zp_l5_silu
    lut_silu_table[addr] = np.clip(q_silu, -128, 127)

def export_mem(filename, arr, hex_digits):
    data = arr.flatten()
    mask = (1 << (hex_digits * 4)) - 1
    with open(filename, "w") as f:
        for v in data:
            f.write(f"{(int(v) & mask):0{hex_digits}X}\n")
    print(f"  [EXPORT] {filename:<28} | Elements: {len(data):>8}")

def export_cfg_q15(filename, m0_arr, shift_arr, zp, total_ch):
    with open(filename, "w") as f:
        for c in range(total_ch):
            packed = (((zp & 0xFF) << 22) | ((int(shift_arr[c]) & 0x3F) << 16) | (int(m0_arr[c]) & 0xFFFF))
            f.write(f"{packed:08X}\n")
    print(f"  [EXPORT] {filename:<28} | Elements: {total_ch:>8}")

print("=======================================================================")
print(" >>> EXPORTING STRIDED 64x64 -> 32x32 DATASET (24.58 MMACS) <<<")
print("=======================================================================")
export_mem("wholenet_in.mem", test_input.squeeze(0), 2)

export_mem("wholenet_l1_w.mem", w1_hw, 2)
export_mem("wholenet_l1_b.mem", b1_f, 8)
export_cfg_q15("wholenet_l1_cfg.mem", m0_l1, shift_l1, zp_l1, C1)
export_mem("wholenet_l1_gold.mem", gold_l1, 2)

export_mem("wholenet_l2_w.mem", w2_hw, 2)
export_mem("wholenet_l2_b.mem", b2_f, 8)
export_cfg_q15("wholenet_l2_cfg.mem", m0_l2, shift_l2, zp_l2, C2)
export_mem("wholenet_l2_gold.mem", gold_l2, 2)

export_mem("wholenet_l3_w.mem", w3_hw, 2)
export_mem("wholenet_l3_b.mem", b3_f, 8)
export_cfg_q15("wholenet_l3_cfg.mem", m0_l3, shift_l3, zp_l3, C3)
export_mem("wholenet_l3_gold.mem", gold_l3, 2)

export_mem("wholenet_l4_w.mem", w4_hw, 2)
export_mem("wholenet_l4_b.mem", b4_f, 8)
export_cfg_q15("wholenet_l4_cfg.mem", m0_l4, shift_l4, zp_l4, C4)
export_mem("wholenet_l4_gold.mem", gold_l4, 2)

export_mem("wholenet_l5_w.mem", w5_hw, 2)
export_mem("wholenet_l5_b.mem", b5_f, 8)
export_cfg_q15("wholenet_l5_cfg.mem", m0_l5, shift_l5, zp_l5_conv, C5)
export_mem("wholenet_l5_lut.mem", lut_silu_table, 2)
export_mem("wholenet_l5_gold.mem", gold_l5_silu, 2)
print("\n>>> SUCCESS: All strided whole-network vectors generated! <<<\n")