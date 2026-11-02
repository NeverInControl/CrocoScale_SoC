#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# CrocoScale SoC — Mirror Generation & Multi-Tier Export Wrapper
#
# Runs the complete export sequence:
#   - Auto-generates unified compiler-directive switches (UNIFIED_GENERATED/) & filelists
#   - Regenerates and verifies the Verilog-2001 mirror (VERILOG_MIRROR_GENERATED/)
#   - Exports the Icarus Simulation Verilog package (exports/efpga_subsystem_simulation_v/)
#   - Exports Tier-1 ASIC Container Macros:
#     * exports/act_bank_container_asic_sv/ (with SRAM macros)
#     * exports/psum_requant_container_asic_sv/ (with SRAM macros + requantizer lane)
#   - Exports Tier-2 ASIC eFPGA Subsystem Macro (exports/efpga_subsystem_asic_sv/)
#     * Uses the hardened Tier-1 container blackboxes + eFPGA_top blackbox + AXI_LIB
#   - Exports Unified Compiler-Directive Packages:
#     * exports/efpga_subsystem_unified_sv/ (SystemVerilog + pure Verilog UNIFIED/ switches)
#     * exports/efpga_subsystem_unified_v/  (Pure Verilog-2001 + pure Verilog UNIFIED/ switches)
#
# Usage:
#   ./scripts/export_all.sh [MIRROR_OPTIONS]
#   ./scripts/export_all.sh -e none   # Fast run without formal SAT proofs
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

print_usage() {
    cat << 'EOF'
Usage: ./scripts/export_all.sh [MIRROR_OPTIONS]

One-command pipeline that builds the unified switches, regenerates the pure
Verilog-2001 mirror, and exports all 6 standalone IP packages into exports/.

Pipeline Steps:
  [1/8] scripts/generate_unified_switches.py  -> UNIFIED_GENERATED/ & FILE_LISTS/unified/
  [2/8] scripts/generate_verilog_mirror.sh    -> VERILOG_MIRROR_GENERATED/
  [3/8] exports/efpga_subsystem_simulation_v/ (Simulation flow, Verilog-2001, TBs, HAL)
  [4/8] exports/act_bank_container_asic_sv/   (Tier-1 ASIC Container, SystemVerilog)
  [5/8] exports/psum_requant_container_asic_sv/ (Tier-1 ASIC Container, SystemVerilog)
  [6/8] exports/efpga_subsystem_asic_sv/      (Tier-2 ASIC Subsystem, SystemVerilog, TBs, AXI_LIB)
  [7/8] exports/efpga_subsystem_unified_sv/   (Unified +define+ flow, SystemVerilog, TBs, HAL, AXI_LIB)
  [8/8] exports/efpga_subsystem_unified_v/    (Unified +define+ flow, Verilog-2001, TBs, HAL, AXI_LIB)

Options (passed through to generate_verilog_mirror.sh):
  -e, --equiv <mode>   Formal equivalence checking mode during Step [2/8]:
                         leaf : (Default) Run Yosys formal SAT proofs on leaf modules
                         none : Fast mode — skip formal SAT proofs and lint checks
                         full : Full hierarchical formal equivalence checking
  -h, --help           Show this help message and exit

Examples:
  # Full production export with formal SAT equivalence proofs (requires pyenv Yosys):
  source ~/custom_functions/custom_functions.sh && pyenv Yosys
  ./scripts/export_all.sh

  # Fast export (skips formal SAT proofs, ~10 seconds):
  ./scripts/export_all.sh -e none
EOF
    exit 0
}

for arg in "$@"; do
    case "$arg" in
        -h|--help)
            print_usage
            ;;
    esac
done

echo "================================================================================"
echo "[1/8] Auto-Generating Unified Multi-Target Switches & Filelists..."
echo "================================================================================"
python3 "${SCRIPT_DIR}/generate_unified_switches.py"

echo ""
echo "================================================================================"
echo "[2/8] Running Verilog Mirror Generation & Verification..."
echo "================================================================================"
"${SCRIPT_DIR}/generate_verilog_mirror.sh" "$@"

echo ""
echo "================================================================================"
echo "[3/8] Exporting Icarus Simulation Package (exports/efpga_subsystem_simulation_v/)..."
echo "================================================================================"
python3 "${SCRIPT_DIR}/export_subsystem.py" \
    --target efpga_subsystem \
    --flow simulation \
    --format v \
    --include-tb \
    --include-hal

echo ""
echo "================================================================================"
echo "[4/8] Exporting Tier-1 ASIC Container Macro: act_bank_container_asic_sv..."
echo "================================================================================"
python3 "${SCRIPT_DIR}/export_subsystem.py" \
    --target act_bank_container \
    --flow asic \
    --format sv

echo ""
echo "================================================================================"
echo "[5/8] Exporting Tier-1 ASIC Container Macro: psum_requant_container_asic_sv..."
echo "================================================================================"
python3 "${SCRIPT_DIR}/export_subsystem.py" \
    --target psum_requant_container \
    --flow asic \
    --format sv

echo ""
echo "================================================================================"
echo "[6/8] Exporting Tier-2 ASIC eFPGA Subsystem Package (exports/efpga_subsystem_asic_sv/)..."
echo "================================================================================"
python3 "${SCRIPT_DIR}/export_subsystem.py" \
    --target efpga_subsystem \
    --flow asic \
    --format sv \
    --include-tb \
    --include-lib

echo ""
echo "================================================================================"
echo "[7/8] Exporting Unified Multi-Target Package (exports/efpga_subsystem_unified_sv/)..."
echo "================================================================================"
python3 "${SCRIPT_DIR}/export_subsystem.py" \
    --target efpga_subsystem \
    --flow unified \
    --format sv \
    --include-tb \
    --include-hal \
    --include-lib

echo ""
echo "================================================================================"
echo "[8/8] Exporting Unified Multi-Target Package (exports/efpga_subsystem_unified_v/)..."
echo "================================================================================"
python3 "${SCRIPT_DIR}/export_subsystem.py" \
    --target efpga_subsystem \
    --flow unified \
    --format v \
    --include-tb \
    --include-hal \
    --include-lib

echo ""
echo "================================================================================"
echo "All exports complete:"
echo "  - Icarus Simulation (Verilog-2001, TBs, HAL):  ${REPO_ROOT}/exports/efpga_subsystem_simulation_v/"
echo "  - ASIC Tier-1 Container (Activation Bank):     ${REPO_ROOT}/exports/act_bank_container_asic_sv/"
echo "  - ASIC Tier-1 Container (PSUM + Requantizer):  ${REPO_ROOT}/exports/psum_requant_container_asic_sv/"
echo "  - ASIC Tier-2 Subsystem (eFPGA + NPU + Lib):   ${REPO_ROOT}/exports/efpga_subsystem_asic_sv/"
echo "  - Unified All-Flows Package (SystemVerilog):   ${REPO_ROOT}/exports/efpga_subsystem_unified_sv/"
echo "  - Unified All-Flows Package (Verilog-2001):    ${REPO_ROOT}/exports/efpga_subsystem_unified_v/"
echo "  - Vivado Emulation: Uses original RTL/ + VIVADO/ tree directly."
echo "================================================================================"
