#!/usr/bin/env python3
"""
Step 1 of 3 — Tiny-YOLOv2 Input Image Preprocessor (1_prepare_image.py)

Reads an input image (default: TEST/GoldenReference/yolo_tiny/input_image.{png,jpg,jpeg,bmp,ppm}),
resizes it to 416x416x3 RGB, and writes:
  - TEST/GoldenReference/yolo_tiny/input_416x416.rgb        (raw 416x416x3 uint8 RGB tensor)
  - TEST/GoldenReference/yolo_tiny/input_416x416_preview.png (visual preview of the 416x416 input)

Usage:
  python3 TEST/GoldenReference/yolo_tiny/1_prepare_image.py
  python3 TEST/GoldenReference/yolo_tiny/1_prepare_image.py --input path/to/my_photo.png
  python3 TEST/GoldenReference/yolo_tiny/1_prepare_image.py --letterbox
"""

import argparse
import os
import struct
import zlib
import numpy as np


def save_png(path, rgb):
    """
    Zero-dependency PNG writer using standard library struct + zlib.
    """
    h, w, _ = rgb.shape
    raw = np.empty((h, w * 3 + 1), dtype=np.uint8)
    raw[:, 0] = 0
    raw[:, 1:] = rgb.reshape(h, w * 3)

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)
    idat = zlib.compress(raw.tobytes(), 9)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", idat) + chunk(b"IEND", b""))


def load_png_pure(path):
    """
    Zero-dependency 8-bit RGB/RGBA PNG reader fallback using struct + zlib.
    """
    with open(path, "rb") as f:
        data = f.read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"Not a valid PNG file: {path}")
    pos = 8
    w = h = color_type = 0
    idat_chunks = []
    while pos < len(data):
        length = struct.unpack(">I", data[pos:pos + 4])[0]
        tag = data[pos + 4:pos + 8]
        chunk_data = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if tag == b"IHDR":
            w, h, bit_depth, color_type, _, _, _ = struct.unpack(">IIBBBBB", chunk_data)
            if bit_depth != 8 or color_type not in (2, 6):
                raise ValueError("Pure-Python PNG fallback supports 8-bit RGB/RGBA; install Pillow for other formats.")
        elif tag == b"IDAT":
            idat_chunks.append(chunk_data)
        elif tag == b"IEND":
            break
    bpp = 3 if color_type == 2 else 4
    stride = w * bpp
    raw = bytearray(zlib.decompress(b"".join(idat_chunks)))
    recon = np.zeros((h, stride), dtype=np.uint8)
    idx = 0
    for r in range(h):
        ftype = raw[idx]
        idx += 1
        row = np.frombuffer(raw[idx:idx + stride], dtype=np.uint8).copy()
        idx += stride
        if ftype == 0:
            recon[r] = row
        elif ftype == 1:
            for i in range(bpp, stride):
                row[i] = (int(row[i]) + int(row[i - bpp])) & 0xFF
            recon[r] = row
        elif ftype == 2:
            up = recon[r - 1] if r > 0 else np.zeros(stride, dtype=np.uint8)
            recon[r] = (row.astype(np.uint16) + up.astype(np.uint16)).astype(np.uint8)
        elif ftype == 3:
            up = recon[r - 1] if r > 0 else np.zeros(stride, dtype=np.uint8)
            for i in range(stride):
                a = int(row[i - bpp]) if i >= bpp else 0
                b = int(up[i])
                row[i] = (int(row[i]) + ((a + b) >> 1)) & 0xFF
            recon[r] = row
        elif ftype == 4:
            up = recon[r - 1] if r > 0 else np.zeros(stride, dtype=np.uint8)
            for i in range(stride):
                a = int(row[i - bpp]) if i >= bpp else 0
                b = int(up[i])
                c = int(up[i - bpp]) if (r > 0 and i >= bpp) else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                row[i] = (int(row[i]) + pr) & 0xFF
            recon[r] = row
    img = recon.reshape(h, w, bpp)
    return img[:, :, :3].copy()


def load_image_rgb(path):
    """
    Loads an image file (.png, .jpg, .jpeg, .bmp, .ppm, or .rgb) as an HxWx3 uint8 RGB array.
    """
    ext = os.path.splitext(path)[1].lower()
    if ext == ".rgb":
        raw = np.fromfile(path, dtype=np.uint8)
        side = int(np.round(np.sqrt(raw.size // 3)))
        return raw.reshape(side, side, 3)

    try:
        from PIL import Image
        with Image.open(path) as im:
            return np.array(im.convert("RGB"), dtype=np.uint8)
    except ImportError:
        if ext == ".png":
            return load_png_pure(path)
        raise RuntimeError(f"Pillow (PIL) is required to load '{ext}' files, or convert the input image to .png.")


def resize_bilinear_rgb(img_rgb, target_h=416, target_w=416, letterbox=False):
    """
    Resizes an HxWx3 uint8 RGB image to target_h x target_w x 3 using high-quality
    resampling (or pure-NumPy bilinear interpolation fallback).
    """
    src_h, src_w, _ = img_rgb.shape
    if src_h == target_h and src_w == target_w:
        return img_rgb.copy()

    def _interp(arr, new_h, new_w):
        try:
            from PIL import Image
            resample = getattr(Image, "Resampling", Image).BILINEAR
            return np.array(Image.fromarray(arr).resize((new_w, new_h), resample), dtype=np.uint8)
        except ImportError:
            y_idx = np.linspace(0, arr.shape[0] - 1, new_h)
            x_idx = np.linspace(0, arr.shape[1] - 1, new_w)
            y0 = np.floor(y_idx).astype(np.int32)
            x0 = np.floor(x_idx).astype(np.int32)
            y1 = np.minimum(y0 + 1, arr.shape[0] - 1)
            x1 = np.minimum(x0 + 1, arr.shape[1] - 1)
            wy = (y_idx - y0)[:, None, None]
            wx = (x_idx - x0)[None, :, None]
            top = arr[y0][:, x0] * (1.0 - wx) + arr[y0][:, x1] * wx
            bot = arr[y1][:, x0] * (1.0 - wx) + arr[y1][:, x1] * wx
            return np.clip(np.round(top * (1.0 - wy) + bot * wy), 0, 255).astype(np.uint8)

    if not letterbox:
        return _interp(img_rgb, target_h, target_w)

    scale = min(target_w / float(src_w), target_h / float(src_h))
    new_w = max(1, int(round(src_w * scale)))
    new_h = max(1, int(round(src_h * scale)))
    resized = _interp(img_rgb, new_h, new_w)
    canvas = np.full((target_h, target_w, 3), 128, dtype=np.uint8)
    pad_y = (target_h - new_h) // 2
    pad_x = (target_w - new_w) // 2
    canvas[pad_y:pad_y + new_h, pad_x:pad_x + new_w] = resized
    return canvas


def find_default_input(base_dir):
    candidates = [
        "input_image.png",
        "input_image.jpg",
        "input_image.jpeg",
        "input_image.bmp",
        "input_image.ppm",
        "input_416x416.rgb",
    ]
    for name in candidates:
        p = os.path.join(base_dir, name)
        if os.path.isfile(p):
            return p
    raise FileNotFoundError(
        f"No input image found in {base_dir}. Place 'input_image.png' (or .jpg/.bmp) in {base_dir} or pass --input <path>."
    )


def main():
    base_dir = os.path.dirname(os.path.abspath(__file__))
    parser = argparse.ArgumentParser(description="Step 1: Prepare 416x416x3 RGB image for Tiny-YOLOv2")
    parser.add_argument("--input", type=str, default=None,
                        help="Path to input image (.png, .jpg, .bmp, .ppm). Defaults to input_image.* in yolo_tiny/")
    parser.add_argument("--output-rgb", type=str, default=os.path.join(base_dir, "input_416x416.rgb"),
                        help="Output raw 416x416x3 RGB file path")
    parser.add_argument("--preview-png", type=str, default=os.path.join(base_dir, "input_416x416_preview.png"),
                        help="Output 416x416 PNG preview path")
    parser.add_argument("--letterbox", action="store_true",
                        help="Preserve aspect ratio with neutral gray (128) letterbox bars instead of direct 416x416 stretch")
    args = parser.parse_args()

    in_path = args.input if args.input else find_default_input(base_dir)
    img_raw = load_image_rgb(in_path)
    orig_h, orig_w = img_raw.shape[:2]

    img_416 = resize_bilinear_rgb(img_raw, 416, 416, letterbox=args.letterbox)
    img_416.tofile(args.output_rgb)
    save_png(args.preview_png, img_416)

    print("=" * 80)
    print("  [STEP 1/3] TINY-YOLOv2 IMAGE PREPROCESSOR COMPLETE")
    print("=" * 80)
    print(f"  Source Image    : {in_path} ({orig_w}x{orig_h} RGB)")
    print(f"  Resize Mode     : {'Letterbox (aspect-ratio preserved)' if args.letterbox else 'Direct 416x416 bilinear resize'}")
    print(f"  Output RGB File : {args.output_rgb} (416x416x3 = {img_416.size:,} bytes)")
    print(f"  Preview PNG     : {args.preview_png}")
    print("=" * 80)


if __name__ == "__main__":
    main()

