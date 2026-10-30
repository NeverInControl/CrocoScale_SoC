#!/usr/bin/env bash
# =============================================================================
# File: TEST/GoldenReference/yolo_tiny/run_yolo_pipeline.sh
# Description:
#   Runs the complete 3-step Tiny-YOLOv2 Golden Reference & Visualization Flow:
#     Step 1: 1_prepare_image.py    (input_image.* -> input_416x416.rgb)
#     Step 2: 2_generate_yolo_mem.py (input_416x416.rgb -> yolo_*_axi.mem + yolo_meta.mem)
#     Step 3: 3_render_detections.py (yolo_l9*_out_axi.mem -> output_detections.png)
#
# Usage:
#   ./TEST/GoldenReference/yolo_tiny/run_yolo_pipeline.sh [optional args for Step 3]
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

python3 "$SCRIPT_DIR/1_prepare_image.py"
python3 "$SCRIPT_DIR/2_generate_yolo_mem.py"
python3 "$SCRIPT_DIR/3_render_detections.py" "$@"

