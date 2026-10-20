#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# CrocoScale SoC — Mirror Generation & Dual-Target Export Wrapper
#
# Runs the complete 2-step export sequence for both required downstream packages:
#   1. Regenerates and verifies the Verilog-2001 mirror (VERILOG_MIRROR_GENERATED/)
#   2. Exports the Icarus Simulation Verilog package (exports/efpga_subsystem_simulation_v/)
#      - Flow: simulation (FILE_LISTS/efpga_subsystem.f)
#      - Format: v (Pure Verilog-2001)
#      - Includes: Simulation RTL + Testbenches + Golden Vectors + C HAL Drivers
#      - External AXI_LIB stays decoupled (pass via -y <path/to/axi_lib>)
#   3. Exports the Macro-Backend SystemVerilog package (exports/efpga_subsystem_asic_sv/)
#      - Flow: asic (FILE_LISTS/asic/efpga_subsystem_asic.f)
#      - Format: sv (SystemVerilog)
#      - Includes: ASIC RTL + All MACROS/ + AXI_LIB + Testbenches + Golden Vectors
#
# Usage:
#   ./scripts/export_all.sh [MIRROR_OPTIONS]
#   ./scripts/export_all.sh -e none   # Fast run without formal SAT proofs
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "================================================================================"
echo "[1/3] Running Verilog Mirror Generation & Verification..."
echo "================================================================================"
"${SCRIPT_DIR}/generate_verilog_mirror.sh" "$@"

echo ""
echo "================================================================================"
echo "[2/3] Exporting Icarus Simulation Package (exports/efpga_subsystem_simulation_v/)..."
echo "================================================================================"
python3 "${SCRIPT_DIR}/export_subsystem.py" \
    --target efpga_subsystem \
    --flow simulation \
    --format v \
    --include-tb \
    --include-hal

echo ""
echo "================================================================================"
echo "[3/3] Exporting Macro-Backend ASIC Package (exports/efpga_subsystem_asic_sv/)..."
echo "================================================================================"
python3 "${SCRIPT_DIR}/export_subsystem.py" \
    --target efpga_subsystem \
    --flow asic \
    --format sv \
    --include-tb \
    --include-lib \
    --include-macros

echo ""
echo "================================================================================"
echo "All exports complete:"
echo "  - Icarus Simulation (Verilog-2001, TBs, HAL):  ${REPO_ROOT}/exports/efpga_subsystem_simulation_v/"
echo "  - Macro-Backend Flow (SV, Macros, Lib, TBs):   ${REPO_ROOT}/exports/efpga_subsystem_asic_sv/"
echo "  - Vivado Emulation: Uses original RTL/ + VIVADO/ tree directly (or run with --flow vivado)."
echo "================================================================================"
