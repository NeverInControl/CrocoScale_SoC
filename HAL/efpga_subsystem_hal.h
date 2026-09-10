#ifndef EFPGA_SUBSYSTEM_HAL_H
#define EFPGA_SUBSYSTEM_HAL_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ===============================================================================================
 * eFPGA Subsystem Manager Register Offsets & Bitfields (efpga_manager.sv)
 * =============================================================================================== */

/* Global Management Registers (0x0000 - 0x0FFF) */
#define EFPGA_SUBSYSTEM_REG_HW_VERSION        0x0000U
#define EFPGA_SUBSYSTEM_REG_GLOBAL_CTRL       0x0004U
#define EFPGA_SUBSYSTEM_REG_CONFIG_DATA       0x0008U
#define EFPGA_SUBSYSTEM_REG_CONFIG_COUNT      0x000CU

/* Hardware Discovery & Identification */
#define EFPGA_SUBSYSTEM_HW_VERSION_MASK       0xFFF00000U
#define EFPGA_SUBSYSTEM_HW_VERSION_MAGIC      0xFAB00000U

/* Global Control Register Bitfields */
#define EFPGA_SUBSYSTEM_GLOBAL_CTRL_SOFT_RESET       (1U << 0)
#define EFPGA_SUBSYSTEM_GLOBAL_CTRL_COM_ACTIVE       (1U << 1)
#define EFPGA_SUBSYSTEM_GLOBAL_CTRL_DESIGN_LOADED    (1U << 2)

/* Per-Slot Register Offsets (Base = 0x1000 + (slot * 0x1000)) */
#define EFPGA_SUBSYSTEM_SLOT_OFFSET(slot)            (0x1000U + ((uint32_t)(slot) * 0x1000U))
#define EFPGA_SUBSYSTEM_REG_SLOT_CTRL(slot)          (EFPGA_SUBSYSTEM_SLOT_OFFSET(slot) + 0x0000U)
#define EFPGA_SUBSYSTEM_REG_SLOT_STATUS(slot)        (EFPGA_SUBSYSTEM_SLOT_OFFSET(slot) + 0x0004U)
#define EFPGA_SUBSYSTEM_REG_FAULT_CLEAR(slot)        (EFPGA_SUBSYSTEM_SLOT_OFFSET(slot) + 0x0008U)
#define EFPGA_SUBSYSTEM_REG_DEBUG_OUT(slot)          (EFPGA_SUBSYSTEM_SLOT_OFFSET(slot) + 0x000CU)
#define EFPGA_SUBSYSTEM_REG_DEBUG_IN(slot)           (EFPGA_SUBSYSTEM_SLOT_OFFSET(slot) + 0x0010U)

/* Slot Control Register Bitfields (SLOT_CTRL @ 0x000) */
#define EFPGA_SUBSYSTEM_SLOT_CTRL_DECOUPLE_REQ       (1U << 0)
#define EFPGA_SUBSYSTEM_SLOT_CTRL_DECOUPLE_FORCE     (1U << 1)
#define EFPGA_SUBSYSTEM_SLOT_CTRL_PMP_EN             (1U << 8)
#define EFPGA_SUBSYSTEM_SLOT_CTRL_WDOG_DM_EN         (1U << 16)
#define EFPGA_SUBSYSTEM_SLOT_CTRL_WDOG_CS_EN         (1U << 17)
#define EFPGA_SUBSYSTEM_SLOT_CTRL_WDOG_DS_EN         (1U << 18)
#define EFPGA_SUBSYSTEM_SLOT_CTRL_WDOG_CM_EN         (1U << 19)
#define EFPGA_SUBSYSTEM_SLOT_CTRL_WB_SLAVE_EN        (1U << 24)
#define EFPGA_SUBSYSTEM_SLOT_CTRL_WB_MASTER_EN       (1U << 25)

/* Slot Status Register Bitfields (SLOT_STATUS @ 0x004) */
#define EFPGA_SUBSYSTEM_SLOT_STATUS_IS_DECOUPLED     (1U << 0)
#define EFPGA_SUBSYSTEM_SLOT_STATUS_HOST_ACT         (1U << 1)
#define EFPGA_SUBSYSTEM_SLOT_STATUS_DMA_ACT          (1U << 2)
#define EFPGA_SUBSYSTEM_SLOT_STATUS_PMP_R_FAULT      (1U << 8)
#define EFPGA_SUBSYSTEM_SLOT_STATUS_PMP_W_FAULT      (1U << 9)
#define EFPGA_SUBSYSTEM_SLOT_STATUS_WDOG_DM_PR       (1U << 16)
#define EFPGA_SUBSYSTEM_SLOT_STATUS_WDOG_DM_TO       (1U << 17)
#define EFPGA_SUBSYSTEM_SLOT_STATUS_WDOG_CS_PR       (1U << 18)
#define EFPGA_SUBSYSTEM_SLOT_STATUS_WDOG_CS_TO       (1U << 19)
#define EFPGA_SUBSYSTEM_SLOT_STATUS_WDOG_SOC         (1U << 20)
#define EFPGA_SUBSYSTEM_SLOT_STATUS_WDOG_ALL_MASK    (0x1FU << 16)

/* Parametric Physical Memory Protection Registers (Base = 0x1000 + (slot * 0x1000) + 0x014 + r * 8) */
#define EFPGA_SUBSYSTEM_REG_PMP_BASE(slot, r)        (EFPGA_SUBSYSTEM_SLOT_OFFSET(slot) + 0x0014U + ((uint32_t)(r) * 0x08U))
#define EFPGA_SUBSYSTEM_REG_PMP_LIMIT(slot, r)       (EFPGA_SUBSYSTEM_SLOT_OFFSET(slot) + 0x0018U + ((uint32_t)(r) * 0x08U))

/* PMP Configuration Bitfields within BASE and LIMIT Registers */
#define EFPGA_SUBSYSTEM_PMP_BASE_READ_EN             (1U << 0)
#define EFPGA_SUBSYSTEM_PMP_BASE_WRITE_EN            (1U << 1)
#define EFPGA_SUBSYSTEM_PMP_LIMIT_PRIV_REQ           (1U << 0)
#define EFPGA_SUBSYSTEM_PMP_LIMIT_SEC_REQ            (1U << 1)

/* ===============================================================================================
 * Data Structures
 * =============================================================================================== */

/**
 * @brief Memory buffer fragment for scatter-gather bitstream streaming.
 */
typedef struct {
    const uint8_t *data;
    size_t bin_size;
} efpga_subsystem_fragment_t;

/**
 * @brief Synthesized subsystem hardware features discovered at runtime.
 */
typedef struct {
    bool has_pmp;
    bool has_wb_slave;
    bool has_wb_master;
    bool has_wdog_dma_master;
    bool has_wdog_ctrl_slave;
    bool has_wdog_dma_slave;
    bool has_wdog_ctrl_master;
    uint8_t num_pmp_regions;
} efpga_subsystem_capabilities_t;

/**
 * @brief Slot runtime status snapshot.
 */
typedef struct {
    bool is_decoupled;
    bool host_active;
    bool dma_active;
    bool pmp_read_fault;
    bool pmp_write_fault;
    bool wdog_fault;
} efpga_subsystem_slot_state_t;

/* ===============================================================================================
 * HAL API Functions
 * =============================================================================================== */

/**
 * @brief Initialize the eFPGA Subsystem driver and verify hardware presence.
 * @param base_addr Memory-mapped base address of the eFPGA Subsystem manager peripheral.
 * @return Hardware version ID on success, or 0 on communication failure.
 */
uint32_t efpga_subsystem_init(uintptr_t base_addr);

/**
 * @brief Dynamically probe synthesized hardware features for a specific slot.
 * @param base_addr Memory-mapped base address of the eFPGA Subsystem manager.
 * @param slot Slot index.
 * @param caps Output capabilities structure.
 * @return 0 on success, negative error code on invalid parameters.
 */
int efpga_subsystem_get_capabilities(uintptr_t base_addr, uint32_t slot, efpga_subsystem_capabilities_t *caps);

/**
 * @brief Decouple an eFPGA Subsystem slot from the SoC interconnect.
 * @param base_addr Memory-mapped base address of the eFPGA Subsystem manager.
 * @param slot Slot index.
 * @param force Force decoupling immediately without waiting for pending transactions.
 * @param timeout_cycles Maximum spin iterations waiting for in-flight bus transactions to conclude.
 * @return 0 on success, -1 on timeout.
 */
int efpga_subsystem_decouple(uintptr_t base_addr, uint32_t slot, bool force, uint32_t timeout_cycles);

/**
 * @brief Re-couple an eFPGA Subsystem slot to the SoC interconnect after configuration.
 * @param base_addr Memory-mapped base address of the eFPGA Subsystem manager.
 * @param slot Slot index.
 */
void efpga_subsystem_recouple(uintptr_t base_addr, uint32_t slot);

/**
 * @brief Stream a contiguous binary bitstream into configuration memory.
 * @param base_addr Memory-mapped base address of the eFPGA Subsystem manager.
 * @param slot Slot index to isolate during programming.
 * @param bitstream_bytes Pointer to raw bitstream bytes.
 * @param byte_count Total size of the bitstream in bytes.
 * @return 0 on success, negative error code on failure.
 */
int efpga_subsystem_load_bitstream(uintptr_t base_addr, uint32_t slot, const uint8_t *bitstream_bytes, size_t byte_count);

/**
 * @brief Scatter-gather bitstream streaming for fragmented memory buffers.
 * @param base_addr Memory-mapped base address of the eFPGA Subsystem manager.
 * @param slot Slot index.
 * @param fragments Array of bitstream fragments.
 * @param num_fragments Number of fragments in the array.
 * @return 0 on success, negative error code on failure.
 */
int efpga_subsystem_load_fragments(uintptr_t base_addr, uint32_t slot,
                                   const efpga_subsystem_fragment_t *fragments,
                                   size_t num_fragments);

/**
 * @brief Assert or release the fabric soft reset line.
 * @param base_addr Memory-mapped base address of the eFPGA Subsystem manager.
 * @param assert_reset True to hold in reset, False to release reset.
 */
void efpga_subsystem_set_soft_reset(uintptr_t base_addr, bool assert_reset);

/**
 * @brief Read slot status snapshot (decoupling state, bus activity, fault flags).
 * @param base_addr Memory-mapped base address of the eFPGA Subsystem manager.
 * @param slot Slot index.
 * @param state Output slot state structure.
 * @return 0 on success, negative error code on invalid parameters.
 */
int efpga_subsystem_get_slot_state(uintptr_t base_addr, uint32_t slot, efpga_subsystem_slot_state_t *state);

/**
 * @brief Clear latched fault flags (watchdog timeouts, PMP violations).
 * @param base_addr Memory-mapped base address of the eFPGA Subsystem manager.
 * @param slot Slot index.
 * @param clear_pmp_r Clear PMP read violations.
 * @param clear_pmp_w Clear PMP write violations.
 * @param clear_wdog Clear all watchdog timeouts.
 */
void efpga_subsystem_clear_faults(uintptr_t base_addr, uint32_t slot,
                                  bool clear_pmp_r, bool clear_pmp_w, bool clear_wdog);

/**
 * @brief Configure a Physical Memory Protection (PMP) region for a subsystem slot.
 * @param base_addr Memory-mapped base address of the eFPGA Subsystem manager.
 * @param slot Slot index.
 * @param region Region index (0..NUM_REGIONS-1).
 * @param start_addr Base physical address (4-byte aligned).
 * @param end_addr Limit physical address (strictly greater than start_addr).
 * @param read_en Allow fabric reads.
 * @param write_en Allow fabric writes.
 * @param req_priv Require privileged AXI access.
 * @param req_sec Require secure AXI access.
 * @return 0 on success, negative error code on invalid parameters.
 */
int efpga_subsystem_set_pmp_region(uintptr_t base_addr, uint32_t slot, uint32_t region,
                                   uint32_t start_addr, uint32_t end_addr,
                                   bool read_en, bool write_en, bool req_priv, bool req_sec);

/**
 * @brief Write to the slot's static debug output register.
 */
void efpga_subsystem_write_debug_io(uintptr_t base_addr, uint32_t slot, uint32_t val);

/**
 * @brief Read from the slot's static debug input register.
 */
uint32_t efpga_subsystem_read_debug_io(uintptr_t base_addr, uint32_t slot);

#ifdef __cplusplus
}
#endif

#endif /* EFPGA_SUBSYSTEM_HAL_H */

