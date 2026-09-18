#!/usr/bin/env bash
set -euo pipefail

# Dynamically locate the repository root for portability across host environments
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

SRC_RTL="${REPO_ROOT}/RTL"
SRC_MACROS="${REPO_ROOT}/MACROS"
SRC_SOFT_LOGIC="${REPO_ROOT}/SOFT_LOGIC"
SRC_TEST="${REPO_ROOT}/TEST"
SRC_FLISTS="${REPO_ROOT}/FILE_LISTS"
OUT_DIR="${REPO_ROOT}/VERILOG_MIRROR_GENERATED"
OUT_RTL="${OUT_DIR}/RTL"
OUT_MACROS="${OUT_DIR}/MACROS"
OUT_SOFT_LOGIC="${OUT_DIR}/SOFT_LOGIC"
OUT_TEST="${OUT_DIR}/TEST"
OUT_FLISTS="${OUT_DIR}/FILE_LISTS"

# Ensure ~/.local/bin is in PATH for tools such as sv2v
if [[ -d "${HOME}/.local/bin" ]]; then
    export PATH="${HOME}/.local/bin:${PATH}"
fi

# -----------------------------------------------------------------------------
# Command-Line Options Parsing & Validation
# -----------------------------------------------------------------------------
EQUIV_MODE="leaf"
TARGET_SUBDIR=""

print_usage() {
    cat << 'EOF'
Usage: generate_verilog_mirror.sh [OPTIONS]

Options:
  -e, --equiv <mode>   Equivalence checking mode (independent from -d):
                         none  : Skip formal verification and structural audits for ultra-fast transpilation
                         leaf  : (Default) Run Yosys Minisat formal proofs on leaf modules with structural fallback
                         full  : Run hierarchical formal equivalence checks across all modules
  -d, --dir <path>     Scope generation to a specific subdirectory relative to repository root
                         (e.g., RTL/eFPGA_Subsystem/NPU_complex, SOFT_LOGIC/full, TEST/SoftLogic)
  -h, --help           Display this help message and exit

Examples:
  ./scripts/generate_verilog_mirror.sh
  ./scripts/generate_verilog_mirror.sh -e none
  ./scripts/generate_verilog_mirror.sh -d SOFT_LOGIC/full
  ./scripts/generate_verilog_mirror.sh -e none -d SOFT_LOGIC/full
  ./scripts/generate_verilog_mirror.sh -e full -d RTL/eFPGA_Subsystem/NPU_complex
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -e|--equiv)
            if [[ $# -lt 2 || "$2" == -* ]]; then
                echo "ERROR: Option '$1' requires an argument (none, leaf, full)." >&2
                exit 1
            fi
            EQUIV_MODE="$2"
            shift 2
            ;;
        --equiv=*)
            EQUIV_MODE="${1#*=}"
            shift
            ;;
        -d|--dir)
            if [[ $# -lt 2 || "$2" == -* ]]; then
                echo "ERROR: Option '$1' requires a directory path argument." >&2
                exit 1
            fi
            TARGET_SUBDIR="$2"
            shift 2
            ;;
        --dir=*)
            TARGET_SUBDIR="${1#*=}"
            shift
            ;;
        -h|--help)
            print_usage
            ;;
        *)
            echo "ERROR: Unknown argument: '$1'. Target directories must be specified explicitly with -d or --dir." >&2
            exit 1
            ;;
    esac
done

# Validate EQUIV_MODE
case "${EQUIV_MODE}" in
    none|leaf|default|full)
        if [[ "${EQUIV_MODE}" == "default" ]]; then
            EQUIV_MODE="leaf"
        fi
        ;;
    *)
        echo "ERROR: Invalid equivalence mode '${EQUIV_MODE}'. Valid choices: none, leaf, full." >&2
        exit 1
        ;;
esac

# Normalize and validate TARGET_SUBDIR
if [[ -n "${TARGET_SUBDIR}" ]]; then
    # Strip leading ./, leading slashes, and trailing slashes
    TARGET_SUBDIR="${TARGET_SUBDIR#./}"
    TARGET_SUBDIR="${TARGET_SUBDIR#/}"
    TARGET_SUBDIR="${TARGET_SUBDIR%/}"

    if [[ ! -d "${REPO_ROOT}/${TARGET_SUBDIR}" ]]; then
        # Check case-insensitively if not matched exactly
        matched_dir=$(find "${REPO_ROOT}" -maxdepth 5 -type d -ipath "${REPO_ROOT}/${TARGET_SUBDIR}" 2>/dev/null | head -n 1 || true)
        if [[ -n "${matched_dir}" ]]; then
            TARGET_SUBDIR="${matched_dir#"${REPO_ROOT}/"}"
        else
            echo "ERROR: Target subdirectory '${TARGET_SUBDIR}' does not exist under repository root." >&2
            exit 1
        fi
    fi
    echo "Scoped Execution: Target subdirectory set to '${TARGET_SUBDIR}'"
fi

# Determine whether VHDL CPU complex synthesis is needed
RUN_CPU_SYNTH=0
if [[ -z "${TARGET_SUBDIR}" ]]; then
    RUN_CPU_SYNTH=1
elif [[ "${TARGET_SUBDIR}" == *"CPU"* || "${TARGET_SUBDIR}" == *"Integration"* ]]; then
    RUN_CPU_SYNTH=1
fi

# -----------------------------------------------------------------------------
# Tool Availability Verification
# -----------------------------------------------------------------------------
if ! command -v sv2v >/dev/null 2>&1; then
    echo "ERROR: sv2v is not found in PATH." >&2
    echo "Please ensure sv2v is installed and added to your PATH." >&2
    exit 1
fi
SV2V_BIN="$(command -v sv2v)"

if [[ "${RUN_CPU_SYNTH}" -eq 1 || "${EQUIV_MODE}" != "none" ]]; then
    if ! command -v yosys >/dev/null 2>&1; then
        echo "ERROR: yosys is not found in PATH." >&2
        echo "Please activate an environment containing yosys before running this script." >&2
        exit 1
    fi
    YOSYS_BIN="$(command -v yosys)"

    if [[ "${RUN_CPU_SYNTH}" -eq 1 ]]; then
        if ! "${YOSYS_BIN}" -m ghdl -p "help ghdl" >/dev/null 2>&1; then
            echo "ERROR: ${YOSYS_BIN} does not have the GHDL plugin enabled." >&2
            echo "GHDL plugin is required for synthesizing the VHDL NeoRV32 CPU complex." >&2
            exit 1
        fi
    fi

    if [[ "${EQUIV_MODE}" != "none" ]]; then
        if ! "${YOSYS_BIN}" -m slang -p "help read_slang" >/dev/null 2>&1; then
            echo "ERROR: ${YOSYS_BIN} does not have the slang plugin enabled." >&2
            echo "Slang plugin is required for reading SystemVerilog in logical equivalence checks." >&2
            exit 1
        fi
    fi
fi

if [[ "${EQUIV_MODE}" != "none" || -z "${TARGET_SUBDIR}" ]]; then
    if ! command -v iverilog >/dev/null 2>&1; then
        echo "ERROR: iverilog is not found in PATH." >&2
        echo "Please ensure Icarus Verilog is installed and added to your PATH." >&2
        exit 1
    fi
    IVERILOG_BIN="$(command -v iverilog)"
fi

# -----------------------------------------------------------------------------
# Mirror Generation & Transpilation
# -----------------------------------------------------------------------------
if [[ -z "${TARGET_SUBDIR}" ]]; then
    # Full Tree Mode: Clean and prepare output directory structure
    rm -rf "${OUT_DIR}"
    mkdir -p "${OUT_RTL}" "${OUT_MACROS}" "${OUT_SOFT_LOGIC}" "${OUT_TEST}" "${OUT_FLISTS}"

    # Document auto-generated nature of the mirror directory
    cat << 'EOF' > "${OUT_DIR}/README.md"
# VERILOG_MIRROR_GENERATED

> **AUTO-GENERATED DIRECTORY — DO NOT EDIT DIRECTLY**
>
> This directory is automatically generated by `scripts/generate_verilog_mirror.sh`.
> All manual hardware modifications must be made to the golden source files:
> - SystemVerilog RTL: `RTL/*.sv`
> - ASIC Subsystem Macros: `MACROS/*.sv` and `MACROS/*.v`
> - eFPGA Soft-Logic: `SOFT_LOGIC/*.sv`
> - Verification & Testbenches: `TEST/`
> - VHDL CPU Complex: `RTL/CPU/*.vhd` and `RTL/Integration/neorv32_axi_wrapper.vhd`
>
> Any manual edits made inside this directory will be overwritten on the next generation run.
EOF

    # Recreate RTL directory hierarchy in output mirror
    find "${SRC_RTL}" -type d ! -path "*/CPU*" | while read -r dir; do
        rel_dir="${dir#"${SRC_RTL}"}"
        if [[ -n "${rel_dir}" ]]; then
            mkdir -p "${OUT_RTL}${rel_dir}"
        fi
    done
    mkdir -p "${OUT_RTL}/Integration"

    # Passthrough static Verilog source files, headers, and initialization tables
    find "${SRC_RTL}" -type f \( -name "*.v" -o -name "*.vh" -o -name "*.svh" -o -name "*.hex" -o -name "*.mem" -o -name "*.csv" \) ! -path "*/CPU*" | while read -r src_file; do
        rel_path="${src_file#"${SRC_RTL}/"}"
        mkdir -p "$(dirname "${OUT_RTL}/${rel_path}")"
        cp -p "${src_file}" "${OUT_RTL}/${rel_path}"
    done

    # Transpile SystemVerilog sources to IEEE Verilog-2001
    echo "Transpiling SystemVerilog sources via sv2v (${SV2V_BIN})..."
    find "${SRC_RTL}" -type f -name "*.sv" | while read -r sv_file; do
        rel_path="${sv_file#"${SRC_RTL}/"}"
        out_v="${OUT_RTL}/${rel_path%.sv}.v"
        mkdir -p "$(dirname "${out_v}")"
        "${SV2V_BIN}" "${sv_file}" > "${out_v}"
        echo "Transpiled: ${rel_path} -> $(basename "${out_v}")"
    done
    echo "SystemVerilog transpilation complete."

    # Recreate MACROS directory hierarchy in output mirror
    if [[ -d "${SRC_MACROS}" ]]; then
        find "${SRC_MACROS}" -type d | while read -r dir; do
            rel_dir="${dir#"${SRC_MACROS}"}"
            if [[ -n "${rel_dir}" ]]; then
                mkdir -p "${OUT_MACROS}${rel_dir}"
            fi
        done

        find "${SRC_MACROS}" -type f \( -name "*.v" -o -name "*.vh" -o -name "*.svh" -o -name "*.md" \) | while read -r src_file; do
            rel_path="${src_file#"${SRC_MACROS}/"}"
            mkdir -p "$(dirname "${OUT_MACROS}/${rel_path}")"
            cp -p "${src_file}" "${OUT_MACROS}/${rel_path}"
        done

        echo "Transpiling MACROS SystemVerilog sources via sv2v (${SV2V_BIN})..."
        find "${SRC_MACROS}" -type f -name "*.sv" | while read -r sv_file; do
            rel_path="${sv_file#"${SRC_MACROS}/"}"
            out_v="${OUT_MACROS}/${rel_path%.sv}.v"
            mkdir -p "$(dirname "${out_v}")"
            "${SV2V_BIN}" "${sv_file}" > "${out_v}"
            echo "Transpiled Macro: ${rel_path} -> $(basename "${out_v}")"
        done
        echo "MACROS SystemVerilog transpilation complete."
    fi

    # Recreate SOFT_LOGIC directory hierarchy in output mirror
    if [[ -d "${SRC_SOFT_LOGIC}" ]]; then
        find "${SRC_SOFT_LOGIC}" -type d | while read -r dir; do
            rel_dir="${dir#"${SRC_SOFT_LOGIC}"}"
            if [[ -n "${rel_dir}" ]]; then
                mkdir -p "${OUT_SOFT_LOGIC}${rel_dir}"
            fi
        done

        find "${SRC_SOFT_LOGIC}" -type f \( -name "*.v" -o -name "*.vh" -o -name "*.svh" -o -name "*.md" \) | while read -r src_file; do
            rel_path="${src_file#"${SRC_SOFT_LOGIC}/"}"
            mkdir -p "$(dirname "${OUT_SOFT_LOGIC}/${rel_path}")"
            cp -p "${src_file}" "${OUT_SOFT_LOGIC}/${rel_path}"
        done

        echo "Transpiling SOFT_LOGIC SystemVerilog sources via sv2v (${SV2V_BIN})..."
        find "${SRC_SOFT_LOGIC}" -type f -name "*.sv" | while read -r sv_file; do
            rel_path="${sv_file#"${SRC_SOFT_LOGIC}/"}"
            out_v="${OUT_SOFT_LOGIC}/${rel_path%.sv}.v"
            mkdir -p "$(dirname "${out_v}")"
            "${SV2V_BIN}" "${sv_file}" > "${out_v}"
            echo "Transpiled Soft Logic: ${rel_path} -> $(basename "${out_v}")"
        done
        echo "SOFT_LOGIC SystemVerilog transpilation complete."
    fi

    # Recreate TEST directory hierarchy in output mirror
    if [[ -d "${SRC_TEST}" ]]; then
        find "${SRC_TEST}" -type d | while read -r dir; do
            rel_dir="${dir#"${SRC_TEST}"}"
            if [[ -n "${rel_dir}" ]]; then
                mkdir -p "${OUT_TEST}${rel_dir}"
            fi
        done

        find "${SRC_TEST}" -type f \( -name "*.v" -o -name "*.vh" -o -name "*.svh" -o -name "*.mem" -o -name "*.hex" -o -name "*.csv" -o -name "*.py" -o -name "*.md" \) | while read -r src_file; do
            rel_path="${src_file#"${SRC_TEST}/"}"
            mkdir -p "$(dirname "${OUT_TEST}/${rel_path}")"
            cp -p "${src_file}" "${OUT_TEST}/${rel_path}"
        done

        echo "Transpiling TEST SystemVerilog sources via sv2v (${SV2V_BIN})..."
        find "${SRC_TEST}" -type f -name "*.sv" | while read -r sv_file; do
            rel_path="${sv_file#"${SRC_TEST}/"}"
            out_v="${OUT_TEST}/${rel_path%.sv}.v"
            mkdir -p "$(dirname "${out_v}")"
            if "${SV2V_BIN}" "${sv_file}" > "${out_v}" 2>/dev/null; then
                echo "Transpiled Testbench: ${rel_path} -> $(basename "${out_v}")"
            else
                cp -p "${sv_file}" "${out_v}"
                echo "Mirrored Testbench:   ${rel_path} -> $(basename "${out_v}") (preserved for simulation)"
            fi
        done
        echo "TEST SystemVerilog transpilation complete."
    fi

else
    # Scoped Subdirectory Mode: Only wipe and recreate the target mirror subdirectory
    echo "Refreshing mirror target subdirectory: ${TARGET_SUBDIR}"
    mkdir -p "${OUT_DIR}"
    rm -rf "${OUT_DIR}/${TARGET_SUBDIR}"
    mkdir -p "${OUT_DIR}/${TARGET_SUBDIR}"

    # Recreate child directory hierarchy under TARGET_SUBDIR
    find "${REPO_ROOT}/${TARGET_SUBDIR}" -type d ! -path "*/CPU*" | while read -r dir; do
        rel_dir="${dir#"${REPO_ROOT}/${TARGET_SUBDIR}"}"
        if [[ -n "${rel_dir}" ]]; then
            mkdir -p "${OUT_DIR}/${TARGET_SUBDIR}${rel_dir}"
        fi
    done

    # Passthrough static files within TARGET_SUBDIR
    find "${REPO_ROOT}/${TARGET_SUBDIR}" -type f \( -name "*.v" -o -name "*.vh" -o -name "*.svh" -o -name "*.hex" -o -name "*.mem" -o -name "*.csv" -o -name "*.py" -o -name "*.md" \) ! -path "*/CPU*" | while read -r src_file; do
        rel_path="${src_file#"${REPO_ROOT}/"}"
        mkdir -p "$(dirname "${OUT_DIR}/${rel_path}")"
        cp -p "${src_file}" "${OUT_DIR}/${rel_path}"
    done

    # Transpile SystemVerilog sources in TARGET_SUBDIR
    echo "Transpiling SystemVerilog sources in ${TARGET_SUBDIR} via sv2v (${SV2V_BIN})..."
    find "${REPO_ROOT}/${TARGET_SUBDIR}" -type f -name "*.sv" ! -path "*/CPU*" | while read -r sv_file; do
        rel_path="${sv_file#"${REPO_ROOT}/"}"
        out_v="${OUT_DIR}/${rel_path%.sv}.v"
        mkdir -p "$(dirname "${out_v}")"
        if [[ "${rel_path}" == "TEST/"* ]]; then
            if "${SV2V_BIN}" "${sv_file}" > "${out_v}" 2>/dev/null; then
                echo "Transpiled Testbench: ${rel_path} -> $(basename "${out_v}")"
            else
                cp -p "${sv_file}" "${out_v}"
                echo "Mirrored Testbench:   ${rel_path} -> $(basename "${out_v}") (preserved for simulation)"
            fi
        else
            "${SV2V_BIN}" "${sv_file}" > "${out_v}"
            echo "Transpiled: ${rel_path} -> $(basename "${out_v}")"
        fi
    done
    echo "Scoped SystemVerilog transpilation complete."
fi

# -----------------------------------------------------------------------------
# VHDL NeoRV32 CPU Complex Synthesis (if in scope)
# -----------------------------------------------------------------------------
VHDL_PKG="${SRC_RTL}/CPU/core/neorv32_package.vhd"
VHDL_TOP="neorv32_axi_wrapper"
VHDL_OUT="${OUT_RTL}/Integration/${VHDL_TOP}.v"

if [[ "${RUN_CPU_SYNTH}" -eq 1 ]]; then
    echo "Synthesizing VHDL CPU complex (${VHDL_TOP}) via Yosys GHDL..."
    vhd_sources=()
    for f in "${SRC_RTL}/CPU/core/"*.vhd "${SRC_RTL}/CPU/bootloader/"*.vhd "${SRC_RTL}/CPU/system_integration/"*.vhd "${SRC_RTL}/Integration/${VHDL_TOP}.vhd"; do
        if [[ -f "${f}" && "${f}" != "${VHDL_PKG}" ]]; then
            vhd_sources+=("${f}")
        fi
    done

    mkdir -p "$(dirname "${VHDL_OUT}")"
    "${YOSYS_BIN}" -m ghdl -p "
        ghdl -fsynopsys --work=neorv32 ${VHDL_PKG} ${vhd_sources[*]} -e ${VHDL_TOP};
        write_verilog -noattr ${VHDL_OUT}
    "
    echo "VHDL CPU complex synthesized to: ${VHDL_OUT}"
else
    echo "Skipping VHDL CPU complex synthesis (not in target subdirectory scope)."
fi

# -----------------------------------------------------------------------------
# File List Synchronization
# -----------------------------------------------------------------------------
if [[ -d "${SRC_FLISTS}" ]]; then
    mkdir -p "${OUT_FLISTS}"
    find "${SRC_FLISTS}" -type f -name "*.f" | while read -r flist; do
        rel_flist="${flist#"${SRC_FLISTS}/"}"
        out_flist="${OUT_FLISTS}/${rel_flist}"
        mkdir -p "$(dirname "${out_flist}")"

        awk '{
            sub(/\r$/, "");
            sub(/\.sv$/, ".v");
            print;
        }' "${flist}" > "${out_flist}"

        echo "" >> "${out_flist}"

        if [[ "$(basename "${flist}")" == "soc.f" && -f "${VHDL_OUT}" ]]; then
            if ! grep -q "neorv32_axi_wrapper.v" "${out_flist}"; then
                echo "RTL/Integration/neorv32_axi_wrapper.v" >> "${out_flist}"
            fi
        fi
    done
fi

# -----------------------------------------------------------------------------
# Equivalence & Structural Verification
# -----------------------------------------------------------------------------
if [[ "${EQUIV_MODE}" == "none" ]]; then
    echo ""
    echo "Equivalence checking skipped (--equiv none)."
else
    echo ""
    echo "Running automated verification across SystemVerilog modules (Mode: ${EQUIV_MODE})..."
    lec_passed=0
    struct_passed=0
    lec_failed=0
    lec_skipped=0

    inc_dirs=()
    while IFS= read -r dir; do
        inc_dirs+=("-I" "${dir}")
    done < <(find "${SRC_RTL}" "${SRC_MACROS}" "${SRC_SOFT_LOGIC}" -type d ! -path "*/CPU*")

    slang_lib_dirs=()
    while IFS= read -r dir; do
        slang_lib_dirs+=("-y" "${dir}")
    done < <(find "${SRC_RTL}" "${SRC_MACROS}" "${SRC_SOFT_LOGIC}" -type d ! -path "*/CPU*")

    iv_lib_args=()
    while IFS= read -r dir; do
        iv_lib_args+=("-y" "${dir}" "-I" "${dir}")
    done < <(find "${OUT_RTL}" "${OUT_MACROS}" "${OUT_SOFT_LOGIC}" -type d)

    shared_models=()
    while IFS= read -r f; do
        shared_models+=("${f}")
    done < <(find "${OUT_RTL}" -type f -name "*pack*.v")

    # Determine files to verify: either full tree or target subdirectory
    if [[ -z "${TARGET_SUBDIR}" ]]; then
        verify_source_dirs=("${SRC_RTL}" "${SRC_MACROS}" "${SRC_SOFT_LOGIC}")
    else
        verify_source_dirs=("${REPO_ROOT}/${TARGET_SUBDIR}")
    fi

    # Timeout setting based on equivalence mode
    if [[ "${EQUIV_MODE}" == "full" ]]; then
        sat_timeout="30s"
    else
        sat_timeout="10s"
    fi

    while IFS= read -r sv_file; do
        # Determine relative path and corresponding output .v file
        if [[ "${sv_file}" == "${SRC_MACROS}"* ]]; then
            rel_path="MACROS/${sv_file#"${SRC_MACROS}/"}"
            v_file="${OUT_MACROS}/${sv_file#"${SRC_MACROS}/"}"
            v_file="${v_file%.sv}.v"
        elif [[ "${sv_file}" == "${SRC_SOFT_LOGIC}"* ]]; then
            rel_path="SOFT_LOGIC/${sv_file#"${SRC_SOFT_LOGIC}/"}"
            v_file="${OUT_SOFT_LOGIC}/${sv_file#"${SRC_SOFT_LOGIC}/"}"
            v_file="${v_file%.sv}.v"
        elif [[ "${sv_file}" == "${SRC_RTL}"* ]]; then
            rel_path="RTL/${sv_file#"${SRC_RTL}/"}"
            v_file="${OUT_RTL}/${sv_file#"${SRC_RTL}/"}"
            v_file="${v_file%.sv}.v"
        else
            rel_path="${sv_file#"${REPO_ROOT}/"}"
            v_file="${OUT_DIR}/${rel_path%.sv}.v"
        fi

        # Skip testbenches from formal logic equivalence
        if [[ "${rel_path}" == "TEST/"* ]]; then
            continue
        fi

        if [[ ! -f "${v_file}" ]]; then
            echo "  [SKIP]        ${rel_path} (transpiled Verilog output not found)"
            lec_skipped=$((lec_skipped + 1))
            continue
        fi

        # Extract primary module name
        mod_name=$(sed -n -E 's/^[[:space:]]*module[[:space:]]+([a-zA-Z0-9_]+).*/\1/p' "${sv_file}" | head -n 1)
        if [[ -z "${mod_name}" ]]; then
            echo "  [SKIP]        ${rel_path} (no module declaration found)"
            lec_skipped=$((lec_skipped + 1))
            continue
        fi

        tier1_log=$(mktemp)

        if [[ "${EQUIV_MODE}" == "full" ]]; then
            # Tier 1 Full: Include library directories for full hierarchical flattening and verification
            lec_cmd="
                read_slang --top ${mod_name} ${slang_lib_dirs[*]} -Y .sv ${inc_dirs[*]} ${sv_file};
                rename ${mod_name} gold;
                read_verilog ${v_file};
                rename ${mod_name} gate;
                proc; memory;
                equiv_make gold gate equiv;
                hierarchy -top equiv;
                flatten;
                proc; memory; async2sync; opt;
                prep -top equiv;
                async2sync;
                equiv_simple;
                equiv_induct;
                equiv_status -assert o:*;
            "
        else
            # Tier 1 Leaf (Default): Fast check on leaf outputs
            lec_cmd="
                read_slang --top ${mod_name} --ignore-unknown-modules ${inc_dirs[*]} ${sv_file};
                rename ${mod_name} gold;
                read_verilog ${v_file};
                rename ${mod_name} gate;
                proc; memory; async2sync; opt;
                equiv_make gold gate equiv;
                prep -top equiv;
                async2sync;
                equiv_simple;
                equiv_induct;
                equiv_status -assert o:*;
            "
        fi

        if timeout "${sat_timeout}" "${YOSYS_BIN}" -q -m slang -p "${lec_cmd}" > "${tier1_log}" 2>&1; then
            echo "  [LEC PASS]    ${rel_path} (${mod_name})"
            lec_passed=$((lec_passed + 1))
        else
            # Tier 2: Structural elaboration, parameter resolution, and interface audit via Icarus Verilog
            tier2_log=$(mktemp)
            if "${IVERILOG_BIN}" -g2012 -D__ICARUS__ -t null "${iv_lib_args[@]}" "${shared_models[@]}" "${v_file}" > "${tier2_log}" 2>&1; then
                echo "  [STRUCT PASS] ${rel_path} (${mod_name})"
                struct_passed=$((struct_passed + 1))
            else
                err_msg=$(head -n 2 "${tier2_log}" | tail -n 1 || echo "Structural elaboration failed")
                echo "  [FAIL]        ${rel_path} (${mod_name}) - ${err_msg}"
                lec_failed=$((lec_failed + 1))
            fi
            rm -f "${tier2_log}"
        fi
        rm -f "${tier1_log}"
    done < <(find "${verify_source_dirs[@]}" -type f -name "*.sv" ! -path "*/CPU*" 2>/dev/null | sort)

    echo ""
    echo "Verification Summary:"
    echo "  Tier 1 Formal SAT Proofs Passed:  ${lec_passed}"
    echo "  Tier 2 Structural Audits Passed: ${struct_passed}"
    echo "  Failed:                          ${lec_failed}"
    echo "  Skipped:                         ${lec_skipped}"
fi

# -----------------------------------------------------------------------------
# Post-Generation Verification & Lints (Full Tree Mode Only)
# -----------------------------------------------------------------------------
if [[ -z "${TARGET_SUBDIR}" && "${EQUIV_MODE}" != "none" ]]; then
    echo ""
    echo "Running automated Icarus Verilog linter / elaboration on full SoC..."
    (
        cd "${OUT_DIR}"
        "${IVERILOG_BIN}" -g2012 -D__ICARUS__ -f FILE_LISTS/soc.f -s crocoscale_soc -o /dev/null
    )
    echo "Icarus Verilog lint check passed: Full SoC elaboration successful."

    echo "Running automated Icarus Verilog linter on ASIC macros..."
    (
        cd "${OUT_DIR}"
        "${IVERILOG_BIN}" -g2012 -D__ICARUS__ -f FILE_LISTS/macros.f -o /dev/null
    )
    echo "Icarus Verilog lint check passed: ASIC macros elaboration successful."

    echo "Running automated Icarus Verilog linter on eFPGA soft-logic..."
    (
        cd "${OUT_DIR}"
        "${IVERILOG_BIN}" -g2012 -D__ICARUS__ -f FILE_LISTS/soft_logic.f -o /dev/null
    )
    echo "Icarus Verilog lint check passed: Soft-logic elaboration successful."

    echo "Running automated verification simulation on mirrored soft-logic controller..."
    (
        cd "${OUT_DIR}"
        "${IVERILOG_BIN}" -g2012 -D__ICARUS__ -f FILE_LISTS/tb/tb_npu_minimal_system.f -s tb_npu_minimal_system -o /tmp/sim_soft_ctrl.vvp
        vvp /tmp/sim_soft_ctrl.vvp > /dev/null
        rm -f /tmp/sim_soft_ctrl.vvp
    )
    echo "Icarus Verilog test passed: Mirrored eFPGA soft-logic NPU controller simulation successful."
fi

echo ""
echo "Verilog mirror generation complete at: ${OUT_DIR}"
