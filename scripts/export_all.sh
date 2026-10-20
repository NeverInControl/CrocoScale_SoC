#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# CrocoScale SoC — Mirror Generation & Multi-Tier Export Wrapper
#
# Runs the complete export sequence:
#   1. Regenerates and verifies the Verilog-2001 mirror (VERILOG_MIRROR_GENERATED/)
#   2. Exports the Icarus Simulation Verilog package (exports/efpga_subsystem_simulation_v/)
#   3. Exports Tier-1 ASIC Container Macros:
#      - exports/act_bank_container_asic_sv/ (with SRAM macros)
#      - exports/psum_requant_container_asic_sv/ (with SRAM macros + requantizer lane)
#   4. Exports Tier-2 ASIC eFPGA Subsystem Macro (exports/efpga_subsystem_asic_sv/)
#      - Uses the hardened Tier-1 container blackboxes + eFPGA_top blackbox + AXI_LIB
#
# Usage:
#   ./scripts/export_all.sh [MIRROR_OPTIONS]
#   ./scripts/export_all.sh -e none   # Fast run without formal SAT proofs
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "================================================================================"
echo "[1/5] Running Verilog Mirror Generation & Verification..."
echo "================================================================================"
"${SCRIPT_DIR}/generate_verilog_mirror.sh" "$@"

echo ""
echo "================================================================================"
echo "[2/5] Exporting Icarus Simulation Package (exports/efpga_subsystem_simulation_v/)..."
echo "================================================================================"
python3 "${SCRIPT_DIR}/export_subsystem.py" \
    --target efpga_subsystem \
    --flow simulation \
    --format v \
    --include-tb \
    --include-hal

echo ""
echo "================================================================================"
echo "[3/5] Exporting Tier-1 ASIC Container Macro: act_bank_container_asic_sv..."
echo "================================================================================"
python3 "${SCRIPT_DIR}/export_subsystem.py" \
    --target act_bank_container \
    --flow asic \
    --format sv

echo ""
echo "================================================================================"
echo "[4/5] Exporting Tier-1 ASIC Container Macro: psum_requant_container_asic_sv..."
echo "================================================================================"
python3 "${SCRIPT_DIR}/export_subsystem.py" \
    --target psum_requant_container \
    --flow asic \
    --format sv

echo ""
echo "================================================================================"
echo "[5/5] Exporting Tier-2 ASIC eFPGA Subsystem Package (exports/efpga_subsystem_asic_sv/)..."
echo "================================================================================"
python3 "${SCRIPT_DIR}/export_subsystem.py" \
    --target efpga_subsystem \
    --flow asic \
    --format sv \
    --include-tb \
    --include-lib

echo ""
echo "================================================================================"
echo "All exports complete:"
echo "  - Icarus Simulation (Verilog-2001, TBs, HAL):  ${REPO_ROOT}/exports/efpga_subsystem_simulation_v/"
echo "  - ASIC Tier-1 Container (Activation Bank):     ${REPO_ROOT}/exports/act_bank_container_asic_sv/"
echo "  - ASIC Tier-1 Container (PSUM + Requantizer):  ${REPO_ROOT}/exports/psum_requant_container_asic_sv/"
echo "  - ASIC Tier-2 Subsystem (eFPGA + NPU + Lib):   ${REPO_ROOT}/exports/efpga_subsystem_asic_sv/"
echo "  - Vivado Emulation: Uses original RTL/ + VIVADO/ tree directly."
echo "================================================================================"
