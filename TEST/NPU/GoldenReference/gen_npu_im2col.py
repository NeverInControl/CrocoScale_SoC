#!/usr/bin/env python3
"""
NPU Golden Reference Generator: Im2Col (TensorFlow Lite / Keras)
- Computes exact 32-bit Q31 scale multipliers for hardware validation.
- Exports Layer 1 (3x3 Conv) to specific im2col_*.mem files.
"""

import math
import numpy as np
import tensorflow as tf

np.random.seed(42)
tf.random.set_seed(42)

CONV_H, CONV_W = 35, 37
C0, C1, C2, C3 = 16, 20, 24, 16

inputs = tf.keras.Input(shape=(CONV_H, CONV_W, C0), batch_size=1, name="net_input")
x1 = tf.keras.layers.Conv2D(C1, (3, 3), padding='same', activation='relu', use_bias=True, name="conv1")(inputs)
x2 = tf.keras.layers.Conv2D(C2, (1, 1), padding='valid', activation='relu', use_bias=True, name="conv2")(x1)
outputs = tf.keras.layers.Conv2D(C3, (3, 3), padding='same', activation=None, use_bias=True, name="conv3")(x2)

model = tf.keras.Model(inputs=inputs, outputs=[x1, x2, outputs])

def representative_dataset_gen():
    for _ in range(50):
        data = np.random.uniform(-1.0, 1.0, size=(1, CONV_H, CONV_W, C0)).astype(np.float32)
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

test_input = np.random.randint(-16, 16, size=(1, CONV_H, CONV_W, C0), dtype=np.int8)
interpreter.set_tensor(input_details[0]['index'], test_input)
interpreter.invoke()

def find_output_by_shape(shape):
    for out in output_details:
        if list(out['shape']) == list(shape):
            return out
    raise ValueError(f"Output tensor with shape {shape} not found")

def find_tensor_by_shape_and_dtype(shape, dtype):
    for t in tensor_details:
        if list(t['shape']) == list(shape) and t['dtype'] == dtype:
            return t
    raise ValueError(f"Tensor with shape {shape} ({dtype}) not found")

out1_meta = find_output_by_shape([1, CONV_H, CONV_W, C1])
l1_out = interpreter.get_tensor(out1_meta['index'])

w1_meta = find_tensor_by_shape_and_dtype([C1, 3, 3, C0], np.int8)
w1_hw = interpreter.get_tensor(w1_meta['index']).transpose(1, 2, 3, 0)

b1 = interpreter.get_tensor(find_tensor_by_shape_and_dtype([C1], np.int32)['index'])

zp_in = int(np.ravel(input_details[0]['quantization_parameters']['zero_points'])[0])
s_in  = float(np.ravel(input_details[0]['quantization_parameters']['scales'])[0])

zp1   = int(np.ravel(out1_meta['quantization_parameters']['zero_points'])[0])
s_out1= float(np.ravel(out1_meta['quantization_parameters']['scales'])[0])
s_w1  = np.ravel(w1_meta['quantization_parameters']['scales'])

b1_folded = b1 - (zp_in * np.sum(w1_hw.astype(np.int32), axis=(0, 1, 2)))

def compute_npu_scale_params_q31(s_in, s_w_array, s_out):
    m0_list, shift_list = [], []
    for s_w in s_w_array:
        M = (s_in * s_w) / s_out
        sig, exp = math.frexp(M)
        m0 = int(round(sig * (1 << 31)))
        if m0 == (1 << 31):
            m0 = m0 // 2
            exp += 1
        shift = -exp + 31
        m0_list.append(m0)
        shift_list.append(shift)
    return np.array(m0_list, dtype=np.int64), np.array(shift_list, dtype=np.int32)

def compute_npu_scale_params_q15(s_in, s_w_array, s_out):
    m0_list, shift_list = [], []
    for s_w in s_w_array:
        M = (s_in * s_w) / s_out
        sig, exp = math.frexp(M)  # sig in [0.5, 1.0)
        
        # Scale to Q15 (15 fractional bits, values in [0, 32767])
        m0 = int(round(sig * (1 << 15)))
        if m0 == (1 << 15):
            m0 = m0 // 2
            exp += 1
            
        shift = -exp + 15
        m0_list.append(m0)
        shift_list.append(shift)
    return np.array(m0_list, dtype=np.int32), np.array(shift_list, dtype=np.int32)

m0_1, shift_1 = compute_npu_scale_params_q15(s_in, s_w1, s_out1)

def export_mem(filename, numpy_array, hex_digits):
    data = numpy_array.flatten()
    mask = (1 << (hex_digits * 4)) - 1
    with open(filename, "w") as f:
        for val in data:
            f.write(f"{(int(val) & mask):0{hex_digits}X}\n")
    print(f"  [EXPORT] {filename:<30} | Elements: {len(data):>8}")

def export_channel_params_q31(filename, m0_arr, shift_arr, zp, total_ch):
  with open(filename, "w") as f:
    for c in range(total_ch):
      packed = (((zp & 0xFF) << 38) | ((int(shift_arr[c]) & 0x3F) << 32) | (int(m0_arr[c]) & 0xFFFFFFFF))
      f.write(f"{packed:016X}\n")
  print(f"  [EXPORT] {filename:<30} | Elements: {total_ch:>8}")

def export_channel_params_q15(filename, m0_arr, shift_arr, zp, total_ch):
    with open(filename, "w") as f:
        for c in range(total_ch):
            # [29:22] = ZP (8b), [21:16] = Shift (6b), [15:0] = M0 (16b)
            packed = (((zp & 0xFF) << 22) | 
                      ((int(shift_arr[c]) & 0x3F) << 16) | 
                      (int(m0_arr[c]) & 0xFFFF))
            f.write(f"{packed:08X}\n")  # 8 hex chars (32-bit word)
    print(f"  [EXPORT] {filename:<30} | Elements: {total_ch:>8}")

print("=======================================================================")
print(" >>> GENERATING TFLITE IM2COL DATASETS (3x3 Layer 1) <<<")
print("=======================================================================")
export_mem("im2col_conv3x3_act.mem", test_input.squeeze(0), 2)
export_mem("im2col_conv3x3_w.mem", w1_hw, 2)
export_mem("im2col_conv3x3_b.mem", b1_folded, 8)
export_channel_params_q15("im2col_conv3x3_cfg.mem", m0_1, shift_1, zp1, C1)
export_mem("im2col_conv3x3_out_quant.mem", l1_out.squeeze(0), 2)
print("\n>>> SUCCESS: Im2Col reference datasets exported! <<<\n")