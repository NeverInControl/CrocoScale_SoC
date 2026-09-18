#!/usr/bin/env python3
"""
CrocoScale SoC — NPU Performance Benchmark Reference Generator: 3x3 Im2Col + MaxPool2D
- Evaluates 48x48 Feature Map, Cin=128, Cout=32 (100% Hardware Grid Aligned).
- Adds standard Keras MaxPool2D layer (2x2, stride 2).
- Zero custom math: Standard Keras layers and TFLite INT8 post-training quantization.
- Computes 16-bit Q15 scale parameters packed into 32-bit hex configuration words.
- Exports golden reference memory files for full workload and drain verification.
"""

import os
import math
import numpy as np
import tensorflow as tf

target_dir = os.path.dirname(os.path.abspath(__file__))

np.random.seed(42)
tf.random.set_seed(42)

# Problem dimensions
CONV_H, CONV_W = 48, 48
Cin, Cout      = 128, 32

print("=======================================================================")
print(" >>> CrocoScale SoC: 3x3 Benchmark Generator (Conv2D + MaxPool2D) <<<")
print("=======================================================================")

# Build aligned Keras model: Conv2D followed by MaxPool2D
inputs = tf.keras.Input(shape=(CONV_H, CONV_W, Cin), batch_size=1, name="net_input")
conv_out = tf.keras.layers.Conv2D(Cout, (3, 3), padding='same', activation=None, use_bias=True, name="conv3x3_aligned")(inputs)
pool_out = tf.keras.layers.MaxPool2D(pool_size=(2, 2), strides=(2, 2), padding='same', name="maxpool2d")(conv_out)
model = tf.keras.Model(inputs=inputs, outputs=pool_out)

# Standard TFLite INT8 Quantization
def representative_dataset_gen():
    for _ in range(50):
        data = np.random.uniform(-1.0, 1.0, size=(1, CONV_H, CONV_W, Cin)).astype(np.float32)
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

test_input = np.random.randint(-16, 16, size=(1, CONV_H, CONV_W, Cin), dtype=np.int8)
interpreter.set_tensor(input_details[0]['index'], test_input)
interpreter.invoke()

out_meta = output_details[0]
out_quant = interpreter.get_tensor(out_meta['index'])

def find_tensor_by_shape_and_dtype(shape, dtype):
    for t in tensor_details:
        if list(t['shape']) == list(shape) and t['dtype'] == dtype:
            return t
    raise ValueError(f"Tensor with shape {shape} ({dtype}) not found")

w_meta = find_tensor_by_shape_and_dtype([Cout, 3, 3, Cin], np.int8)
w_hw = interpreter.get_tensor(w_meta['index']).transpose(1, 2, 3, 0) # [3, 3, Cin, Cout]
b_raw = interpreter.get_tensor(find_tensor_by_shape_and_dtype([Cout], np.int32)['index'])

zp_in = int(np.ravel(input_details[0]['quantization_parameters']['zero_points'])[0])
s_in  = float(np.ravel(input_details[0]['quantization_parameters']['scales'])[0])

zp_out = int(np.ravel(out_meta['quantization_parameters']['zero_points'])[0])
s_out  = float(np.ravel(out_meta['quantization_parameters']['scales'])[0])
s_w    = np.ravel(w_meta['quantization_parameters']['scales'])

b_folded = b_raw - (zp_in * np.sum(w_hw.astype(np.int32), axis=(0, 1, 2)))

def compute_npu_scale_params_q15(s_in, s_w_array, s_out):
    m0_list, shift_list = [], []
    for s_w_val in s_w_array:
        M = (s_in * s_w_val) / s_out
        sig, exp = math.frexp(M)  # sig in [0.5, 1.0)
        
        # Scale to Q15 (15 fractional bits, unsigned magnitude in [0, 32767])
        m0 = int(round(sig * (1 << 15)))
        if m0 == (1 << 15):
            m0 = m0 // 2
            exp += 1
            
        shift = -exp + 15
        m0_list.append(m0)
        shift_list.append(shift)
    return np.array(m0_list, dtype=np.int32), np.array(shift_list, dtype=np.int32)

m0_arr, shift_arr = compute_npu_scale_params_q15(s_in, s_w, s_out)

def export_mem(filename, numpy_array, hex_digits):
    filepath = os.path.join(target_dir, filename)
    data = numpy_array.flatten()
    mask = (1 << (hex_digits * 4)) - 1
    with open(filepath, "w") as f:
        for val in data:
            f.write(f"{(int(val) & mask):0{hex_digits}X}\n")
    print(f"  [EXPORT] {filename:<32} | Shape: {str(list(numpy_array.shape)):<18} | Elements: {len(data):>8}")

def export_channel_params_q15(filename, m0_arr, shift_arr, zp, total_ch):
    filepath = os.path.join(target_dir, filename)
    with open(filepath, "w") as f:
        for c in range(total_ch):
            # [29:22] = ZP (8b), [21:16] = Shift (6b), [15:0] = M0 (16b)
            # Fits in 30 bits; exported as an 8-character hex word (32-bit width)
            packed = (((zp & 0xFF) << 22) | 
                      ((int(shift_arr[c]) & 0x3F) << 16) | 
                      (int(m0_arr[c]) & 0xFFFF))
            f.write(f"{packed:08X}\n")
    print(f"  [EXPORT] {filename:<32} | Elements: {total_ch:>8}")

export_mem("bench_im2col_act.mem", test_input.squeeze(0), 2)
export_mem("bench_im2col_w.mem", w_hw, 2)
export_mem("bench_im2col_b.mem", b_folded, 8)
export_channel_params_q15("bench_im2col_cfg.mem", m0_arr, shift_arr, zp_out, Cout)
export_mem("bench_im2col_out_pooled.mem", out_quant.squeeze(0), 2)

print("\n>>> SUCCESS: Scaled Q15 Conv2D + MaxPool2D benchmark dataset exported! <<<\n")

