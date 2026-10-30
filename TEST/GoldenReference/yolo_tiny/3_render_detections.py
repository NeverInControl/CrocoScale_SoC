#!/usr/bin/env python3
"""
Step 3 of 3 — Tiny-YOLOv2 Bounding-Box & Statistics Renderer (3_render_detections.py)

Decodes the Layer 9 [128][4][16][4] System RAM strip output (.mem file from
Vivado xsim hardware simulation or Step 2 golden reference), applies configurable
confidence thresholding and Non-Maximum Suppression (NMS), and renders a
two-panel detection + statistics dashboard PNG using a zero-dependency
pure-NumPy + zlib PNG rasterizer.

Usage Examples:
  # Default (10% confidence cutoff, up to 5 boxes, NMS IoU = 0.35):
  python3 TEST/GoldenReference/yolo_tiny/3_render_detections.py

  # Only draw high-confidence boxes (>= 30%):
  python3 TEST/GoldenReference/yolo_tiny/3_render_detections.py --conf-thresh 0.30

  # Limit to Top-2 bounding boxes only:
  python3 TEST/GoldenReference/yolo_tiny/3_render_detections.py --max-boxes 2

  # Lower confidence cutoff to 5% and allow up to 6 boxes:
  python3 TEST/GoldenReference/yolo_tiny/3_render_detections.py --conf-thresh 0.05 --max-boxes 6
"""

import argparse
import os
import struct
import zlib
import numpy as np

VOC_CLASSES = [
    "aeroplane", "bicycle", "bird", "boat", "bottle",
    "bus", "car", "cat", "chair", "cow",
    "diningtable", "dog", "horse", "motorbike", "person",
    "pottedplant", "sheep", "sofa", "train", "tvmonitor"
]

ANCHORS = np.array([
    [1.08, 1.19],
    [3.42, 4.41],
    [6.63, 11.38],
    [9.42, 5.11],
    [16.62, 10.52],
], dtype=np.float32)

BOX_PALETTE = [
    [0, 230, 118],    # #1 Emerald Green
    [0, 190, 255],    # #2 Vivid Cyan-Blue
    [255, 170, 0],    # #3 Amber Gold
    [255, 82, 168],   # #4 Magenta Pink
    [179, 136, 255],  # #5 Soft Purple
    [255, 234, 0],    # #6 Bright Yellow
    [100, 255, 218],  # #7 Mint Teal
    [255, 110, 64],   # #8 Coral Orange
]

FONT_5X7 = {
    " ": [0, 0, 0, 0, 0, 0, 0],
    "A": [14, 17, 17, 31, 17, 17, 17],
    "B": [30, 17, 17, 30, 17, 17, 30],
    "C": [14, 17, 16, 16, 16, 17, 14],
    "D": [28, 18, 17, 17, 17, 18, 28],
    "E": [31, 16, 16, 30, 16, 16, 31],
    "F": [31, 16, 16, 30, 16, 16, 16],
    "G": [14, 17, 16, 23, 17, 17, 15],
    "H": [17, 17, 17, 31, 17, 17, 17],
    "I": [14, 4, 4, 4, 4, 4, 14],
    "J": [7, 2, 2, 2, 2, 18, 12],
    "K": [17, 18, 20, 24, 20, 18, 17],
    "L": [16, 16, 16, 16, 16, 16, 31],
    "M": [17, 27, 21, 21, 17, 17, 17],
    "N": [17, 25, 21, 19, 17, 17, 17],
    "O": [14, 17, 17, 17, 17, 17, 14],
    "P": [30, 17, 17, 30, 16, 16, 16],
    "Q": [14, 17, 17, 17, 21, 18, 13],
    "R": [30, 17, 17, 30, 20, 18, 17],
    "S": [15, 16, 16, 14, 1, 1, 30],
    "T": [31, 4, 4, 4, 4, 4, 4],
    "U": [17, 17, 17, 17, 17, 17, 14],
    "V": [17, 17, 17, 17, 17, 10, 4],
    "W": [17, 17, 17, 21, 21, 27, 17],
    "X": [17, 17, 10, 4, 10, 17, 17],
    "Y": [17, 17, 10, 4, 4, 4, 4],
    "Z": [31, 1, 2, 4, 8, 16, 31],
    "0": [14, 17, 19, 21, 25, 17, 14],
    "1": [4, 12, 4, 4, 4, 4, 14],
    "2": [14, 17, 1, 2, 4, 8, 31],
    "3": [30, 1, 1, 14, 1, 1, 30],
    "4": [2, 6, 10, 18, 31, 2, 2],
    "5": [31, 16, 30, 1, 1, 17, 14],
    "6": [6, 8, 16, 30, 17, 17, 14],
    "7": [31, 1, 2, 4, 8, 8, 8],
    "8": [14, 17, 17, 14, 17, 17, 14],
    "9": [14, 17, 17, 15, 1, 2, 12],
    ".": [0, 0, 0, 0, 0, 12, 12],
    ",": [0, 0, 0, 0, 0, 4, 8],
    ":": [0, 12, 12, 0, 12, 12, 0],
    "-": [0, 0, 0, 31, 0, 0, 0],
    "+": [0, 4, 4, 31, 4, 4, 0],
    "#": [10, 31, 10, 10, 31, 10, 0],
    "%": [25, 25, 2, 4, 8, 19, 19],
    "(": [2, 4, 8, 8, 8, 4, 2],
    ")": [8, 4, 2, 2, 2, 4, 8],
    "[": [14, 8, 8, 8, 8, 8, 14],
    "]": [14, 2, 2, 2, 2, 2, 14],
    "=": [0, 0, 31, 0, 31, 0, 0],
    "|": [4, 4, 4, 4, 4, 4, 4],
    "/": [1, 2, 2, 4, 8, 8, 16],
    ">": [16, 8, 4, 2, 4, 8, 16],
    "<": [2, 4, 8, 16, 8, 4, 2],
}


def draw_text(img, x, y, text, color, scale=1):
    h, w, _ = img.shape
    cx = x
    for ch in text.upper():
        rows = FONT_5X7.get(ch, FONT_5X7[" "])
        for r_idx, row_bits in enumerate(rows):
            for c_idx in range(5):
                if (row_bits >> (4 - c_idx)) & 1:
                    py0 = y + r_idx * scale
                    px0 = cx + c_idx * scale
                    img[max(0, py0):min(h, py0 + scale), max(0, px0):min(w, px0 + scale)] = color
        cx += 6 * scale


def save_png(path, rgb):
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


def load_scale_from_meta(meta_path, default_scale=0.119910):
    if os.path.isfile(meta_path):
        with open(meta_path, "r") as f:
            lines = [line.strip() for line in f if line.strip() and not line.startswith("//")]
        if lines:
            return int(lines[0], 16) / 1_000_000.0
    return default_scale


def unpack_l9_axi_mem(mem_path, c_out=125, h_out=13, w_out=13, w_stride=16):
    """
    Unpacks 32-bit hex words from yolo_l9*_out_axi.mem into signed INT8 tensor
    of shape [c_out, h_out, w_out].
    """
    with open(mem_path, "r") as f:
        lines = [ln.strip() for ln in f if ln.strip() and not ln.strip().startswith("//")]
    words = np.array([int(x, 16) for x in lines], dtype=np.uint32)
    num_strips = (h_out + 3) // 4
    c_pad = ((c_out + 7) // 8) * 8
    words_3d = words[:c_pad * num_strips * w_stride].reshape(c_pad, num_strips, w_stride)

    tensor = np.zeros((c_pad, num_strips * 4, w_stride), dtype=np.int8)
    for r_sub in range(4):
        tensor[:, r_sub::4, :] = ((words_3d >> (r_sub * 8)) & 0xFF).astype(np.uint8).view(np.int8)

    return tensor[:c_out, :h_out, :w_out]


def compute_iou_and_containment(box_a, box_b):
    x0 = max(box_a["x0"], box_b["x0"])
    y0 = max(box_a["y0"], box_b["y0"])
    x1 = min(box_a["x1"], box_b["x1"])
    y1 = min(box_a["y1"], box_b["y1"])
    inter = max(0.0, x1 - x0) * max(0.0, y1 - y0)
    area_a = max(1.0, (box_a["x1"] - box_a["x0"]) * (box_a["y1"] - box_a["y0"]))
    area_b = max(1.0, (box_b["x1"] - box_b["x0"]) * (box_b["y1"] - box_b["y0"]))
    iou = inter / (area_a + area_b - inter)
    iomin = inter / min(area_a, area_b)
    return iou, iomin


def decode_and_filter_boxes(l9_int8, s_out=0.119910, img_size=416, conf_thresh=0.10, nms_iou=0.35, max_boxes=5, class_agnostic_nms=False):
    _, gh, gw = l9_int8.shape
    raw_5d = l9_int8.reshape(5, 25, gh, gw)
    deq = raw_5d.astype(np.float32) * s_out

    sig_tx = 1.0 / (1.0 + np.exp(-np.clip(deq[:, 0], -50, 50)))
    sig_ty = 1.0 / (1.0 + np.exp(-np.clip(deq[:, 1], -50, 50)))
    obj_prob = 1.0 / (1.0 + np.exp(-np.clip(deq[:, 4], -50, 50)))

    cls_logits = deq[:, 5:25]
    e_cls = np.exp(cls_logits - np.max(cls_logits, axis=1, keepdims=True))
    cls_probs = e_cls / np.sum(e_cls, axis=1, keepdims=True)

    scores = obj_prob[:, None, :, :] * cls_probs
    cls_max_global = scores.max(axis=(0, 2, 3))

    candidates = []
    for a in range(5):
        pw, ph = ANCHORS[a]
        for gy in range(gh):
            for gx in range(gw):
                best_c = int(np.argmax(scores[a, :, gy, gx]))
                conf = float(scores[a, best_c, gy, gx])
                if conf >= conf_thresh:
                    cx = (gx + float(sig_tx[a, gy, gx])) / gw * img_size
                    cy = (gy + float(sig_ty[a, gy, gx])) / gh * img_size
                    bw = (pw * float(np.exp(np.clip(deq[a, 2, gy, gx], -10, 10)))) / gw * img_size
                    bh = (ph * float(np.exp(np.clip(deq[a, 3, gy, gx], -10, 10)))) / gh * img_size
                    x0 = float(np.clip(cx - bw / 2.0, 0, img_size - 1))
                    y0 = float(np.clip(cy - bh / 2.0, 0, img_size - 1))
                    x1 = float(np.clip(cx + bw / 2.0, 0, img_size - 1))
                    y1 = float(np.clip(cy + bh / 2.0, 0, img_size - 1))
                    candidates.append({
                        "cls_id": best_c,
                        "cls_name": VOC_CLASSES[best_c],
                        "conf": conf,
                        "obj_prob": float(obj_prob[a, gy, gx]),
                        "cls_prob": float(cls_probs[a, best_c, gy, gx]),
                        "anchor": a,
                        "gy": gy,
                        "gx": gx,
                        "x0": x0,
                        "y0": y0,
                        "x1": x1,
                        "y1": y1,
                        "raw_tx": int(raw_5d[a, 0, gy, gx]),
                        "raw_ty": int(raw_5d[a, 1, gy, gx]),
                        "raw_tw": int(raw_5d[a, 2, gy, gx]),
                        "raw_th": int(raw_5d[a, 3, gy, gx]),
                        "raw_obj": int(raw_5d[a, 4, gy, gx]),
                        "raw_cls": int(raw_5d[a, 5 + best_c, gy, gx]),
                    })

    candidates.sort(key=lambda d: d["conf"], reverse=True)

    kept = []
    for cand in candidates:
        suppress = False
        for k in kept:
            same_category = True if class_agnostic_nms else (cand["cls_id"] == k["cls_id"])
            if same_category:
                iou, iomin = compute_iou_and_containment(cand, k)
                if iou > nms_iou or iomin > 0.65:
                    suppress = True
                    break
        if not suppress:
            kept.append(cand)
            if len(kept) >= max_boxes:
                break

    return kept, len(candidates), cls_max_global


def render_dashboard(img_rgb, kept_boxes, total_cands, cls_max_global, conf_thresh, nms_iou, max_boxes, show_grid=True):
    vis = img_rgb.copy()
    h_img, w_img, _ = vis.shape

    if show_grid:
        for g in range(1, 13):
            p = int(round(g * w_img / 13.0))
            vis[p, :, :] = (vis[p, :, :].astype(np.uint16) * 3 + np.array([70, 90, 110])) // 4
            vis[:, p, :] = (vis[:, p, :].astype(np.uint16) * 3 + np.array([70, 90, 110])) // 4

    for idx in range(len(kept_boxes) - 1, -1, -1):
        b = kept_boxes[idx]
        color = BOX_PALETTE[idx % len(BOX_PALETTE)]

        gx0, gx1 = int(b["gx"] * w_img / 13.0), int((b["gx"] + 1) * w_img / 13.0)
        gy0, gy1 = int(b["gy"] * h_img / 13.0), int((b["gy"] + 1) * h_img / 13.0)
        vis[gy0:gy0+2, gx0:gx1] = color
        vis[gy1-2:gy1, gx0:gx1] = color
        vis[gy0:gy1, gx0:gx0+2] = color
        vis[gy0:gy1, gx1-2:gx1] = color

        x0, y0 = int(max(3, b["x0"])), int(max(22, b["y0"]))
        x1, y1 = int(min(w_img - 4, b["x1"])), int(min(h_img - 4, b["y1"]))
        vis[y0:y0+3, x0:x1] = color
        vis[y1-3:y1, x0:x1] = color
        vis[y0:y1, x0:x0+3] = color
        vis[y0:y1, x1-3:x1] = color

    placed_banners = []
    for idx, b in enumerate(kept_boxes):
        color = BOX_PALETTE[idx % len(BOX_PALETTE)]
        x0, y0 = int(max(3, b["x0"])), int(max(22, b["y0"]))
        tag = f"#{idx+1} {b['cls_name'].upper()} {b['conf']*100:.1f}%"
        tag_w = min(w_img - 6, len(tag) * 6 + 10)
        tag_h = 18

        bx0 = min(x0, w_img - tag_w - 3)
        by0 = y0 - tag_h
        for pb in placed_banners:
            if not (bx0 + tag_w < pb[0] or bx0 > pb[2] or by0 + tag_h < pb[1] or by0 > pb[3]):
                by0 = pb[3] + 4
                if by0 + tag_h > h_img - 4:
                    by0 = max(4, pb[1] - tag_h - 4)
        placed_banners.append((bx0, by0, bx0 + tag_w, by0 + tag_h))
        vis[by0:by0+tag_h, bx0:bx0+tag_w] = color
        draw_text(vis, bx0 + 5, by0 + 5, tag, [10, 15, 20], scale=1)

    W_CANVAS, H_CANVAS = 1040, 488
    canvas = np.full((H_CANVAS, W_CANVAS, 3), [18, 22, 31], dtype=np.uint8)
    canvas[36:36+416, 24:24+416] = vis
    canvas[35, 23:25+416] = [80, 100, 130]
    canvas[36+416, 23:25+416] = [80, 100, 130]

    rx = 462
    draw_text(canvas, rx, 28, "CROCSCALE NPU - TINY-YOLOV2 POST-PROCESSOR", [235, 242, 250], scale=2)
    draw_text(canvas, rx, 52, f"FILTERS: CONF >= {conf_thresh*100:.1f}% | NMS IOU <= {nms_iou:.2f} | MAX BOXES = {max_boxes}", [0, 230, 118], scale=1)
    draw_text(canvas, rx, 66, f"CANDIDATES ABOVE THRESHOLD: {total_cands} / 845 -> KEPT AFTER NMS: {len(kept_boxes)}", [160, 185, 215], scale=1)

    canvas[82, rx:1016] = [55, 70, 95]
    draw_text(canvas, rx, 92, "DETECTED BOUNDING BOXES (SORTED BY CONFIDENCE):", [255, 215, 0], scale=1)

    y_row = 110
    for idx, b in enumerate(kept_boxes[:6]):
        color = BOX_PALETTE[idx % len(BOX_PALETTE)]
        canvas[y_row:y_row+12, rx:rx+12] = color
        line1 = (f"#{idx+1} {b['cls_name'].upper():10s} {b['conf']*100:5.1f}% | "
                 f"CELL({b['gy']:2d},{b['gx']:2d}) A{b['anchor']} | "
                 f"BOX[{int(b['x0']):3d},{int(b['y0']):3d},{int(b['x1']):3d},{int(b['y1']):3d}]")
        line2 = (f"   INT8 LOGITS: TX={b['raw_tx']:+3d} TY={b['raw_ty']:+3d} "
                 f"TW={b['raw_tw']:+3d} TH={b['raw_th']:+3d} OBJ={b['raw_obj']:+4d} CLS={b['raw_cls']:+4d}")
        draw_text(canvas, rx + 18, y_row + 2, line1, [235, 240, 248], scale=1)
        draw_text(canvas, rx + 18, y_row + 14, line2, [150, 175, 205], scale=1)
        y_row += 30

    y_bars = max(296, y_row + 8)
    canvas[y_bars - 8, rx:1016] = [55, 70, 95]
    draw_text(canvas, rx, y_bars, "TOP-5 PASCAL VOC GLOBAL CLASS SCORES (ACROSS 13X13 GRID):", [215, 225, 240], scale=1)
    y_bars += 18

    ranked_cls = np.argsort(cls_max_global)[::-1][:5]
    for r_idx, cid in enumerate(ranked_cls):
        sc = float(cls_max_global[cid])
        cname = f"#{cid:2d} {VOC_CLASSES[cid].upper()}"
        draw_text(canvas, rx, y_bars + 5, f"{cname:14s}", [230, 235, 245], scale=1)
        bx = rx + 96
        canvas[y_bars:y_bars+18, bx:bx+260] = [32, 40, 56]
        bw_px = max(3, int(sc * 400))
        bar_col = [0, 230, 118] if r_idx == 0 else [75, 150, 245]
        canvas[y_bars:y_bars+18, bx:bx+min(260, bw_px)] = bar_col
        draw_text(canvas, bx + 270, y_bars + 5, f"{sc*100:5.2f}%", [220, 230, 242], scale=1)
        y_bars += 26

    return canvas


def main():
    base_dir = os.path.dirname(os.path.abspath(__file__))
    hw_mem_default = os.path.join(base_dir, "yolo_l9_hw_out_axi.mem")
    gold_mem_default = os.path.join(base_dir, "yolo_l9_out_axi.mem")
    default_mem = hw_mem_default if os.path.isfile(hw_mem_default) else gold_mem_default

    parser = argparse.ArgumentParser(description="Step 3: Render CrocoScale NPU Tiny-YOLOv2 (13x13x125) detections & statistics.")
    parser.add_argument("--mem", default=default_mem,
                        help="Path to Layer 9 packed AXI4 output .mem file (defaults to yolo_l9_hw_out_axi.mem if present, else yolo_l9_out_axi.mem)")
    parser.add_argument("--rgb", default=os.path.join(base_dir, "input_416x416.rgb"),
                        help="Path to 416x416x3 raw RGB input image from Step 1")
    parser.add_argument("--meta", default=os.path.join(base_dir, "yolo_meta.mem"),
                        help="Path to yolo_meta.mem from Step 2 (contains Layer 9 dequantization scale s_out)")
    parser.add_argument("--out", default=os.path.join(base_dir, "output_detections.png"),
                        help="Output PNG path (default: TEST/GoldenReference/yolo_tiny/output_detections.png)")
    parser.add_argument("--conf-thresh", type=float, default=0.10,
                        help="Minimum confidence threshold (0.0 to 1.0, default: 0.10 = 10%%)")
    parser.add_argument("--nms-iou", type=float, default=0.35,
                        help="Non-Maximum Suppression IoU threshold (default: 0.35)")
    parser.add_argument("--max-boxes", type=int, default=5,
                        help="Maximum number of bounding boxes to draw (default: 5)")
    parser.add_argument("--scale", type=float, default=None,
                        help="Optional override for Layer 9 INT8 dequantization scale s_out")
    parser.add_argument("--agnostic-nms", action="store_true",
                        help="Apply class-agnostic NMS across all classes")
    parser.add_argument("--no-grid", action="store_true",
                        help="Disable drawing the 13x13 spatial grid overlay")
    args = parser.parse_args()

    s_out = args.scale if args.scale is not None else load_scale_from_meta(args.meta)
    img_rgb = np.fromfile(args.rgb, dtype=np.uint8).reshape(416, 416, 3)
    l9_int8 = unpack_l9_axi_mem(args.mem)

    kept, total_cands, cls_max_global = decode_and_filter_boxes(
        l9_int8,
        s_out=s_out,
        img_size=416,
        conf_thresh=args.conf_thresh,
        nms_iou=args.nms_iou,
        max_boxes=args.max_boxes,
        class_agnostic_nms=args.agnostic_nms,
    )

    print("=" * 92)
    print("  [STEP 3/3] CROCSCALE NPU — TINY-YOLOv2 (416x416) POST-PROCESSOR & BOUNDING BOX REPORT")
    print("=" * 92)
    print(f"  Input Tensor : {args.mem} (13x13x125 INT8, s_out={s_out:.6f})")
    print(f"  Input Image  : {args.rgb} (416x416x3 RGB)")
    print(f"  Filter Config: conf_thresh >= {args.conf_thresh*100:.1f}%, nms_iou <= {args.nms_iou:.2f}, max_boxes = {args.max_boxes}")
    print(f"  Candidates   : {total_cands} / 845 anchor boxes above threshold -> {len(kept)} boxes after NMS")
    print("-" * 92)
    for idx, b in enumerate(kept, 1):
        print(f"  Box #{idx}: class=#{b['cls_id']:2d} ({b['cls_name']:11s}) | conf={b['conf']*100:5.2f}% "
              f"(obj={b['obj_prob']*100:4.1f}%, cls={b['cls_prob']*100:4.1f}%) | "
              f"cell=(Y={b['gy']:2d}, X={b['gx']:2d}, A={b['anchor']}) | "
              f"bbox=[{int(b['x0']):3d}, {int(b['y0']):3d}, {int(b['x1']):3d}, {int(b['y1']):3d}] | "
              f"INT8=(tx={b['raw_tx']:+d}, ty={b['raw_ty']:+d}, tw={b['raw_tw']:+d}, th={b['raw_th']:+d}, obj={b['raw_obj']:+d}, cls={b['raw_cls']:+d})")
    print("=" * 92)

    canvas = render_dashboard(
        img_rgb, kept, total_cands, cls_max_global,
        args.conf_thresh, args.nms_iou, args.max_boxes, show_grid=(not args.no_grid)
    )
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    save_png(args.out, canvas)
    print(f"[OK] Saved annotated detection dashboard to: {args.out}")


if __name__ == "__main__":
    main()

