#ifndef EFPGA_SUBSYSTEM_HAL_H
#define EFPGA_SUBSYSTEM_HAL_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ===============================================================================================
 * Subsystem Interconnect Memory Map Overview
 *
 * 1. Subsystem Manager Port (s_axil_mgr @ mgr_base):
 *    --------------------------------------------------------------------------------------------
 *    Offset Range     | Region Name            | Description
 *    --------------------------------------------------------------------------------------------
 *    0x0000 - 0x000C  | Global Management      | Identification, soft reset, bitstream streaming
 *    0x0010 - 0x0FFF  | Reserved Gap           | Unused (padding to slot boundary)
 *    0x1000 - 0x1010  | Slot Control & Status  | Decoupling, status flags, fault clears, debug I/O
 *    0x1014 - 0x1023  | PMP Regions 0..1       | 2 Base/Limit pairs (8 bytes per region, 16B total)
 *                       - Region 0 Base        : mgr_base + 0x1014 (PFN [31:12], bits [11:2] trunc)
 *                       - Region 0 Limit       : mgr_base + 0x1018 (PFN [31:12], bits [11:2] trunc)
 *                       - Region 1 Base        : mgr_base + 0x101C (PFN [31:12], bits [11:2] trunc)
 *                       - Region 1 Limit       : mgr_base + 0x1020 (PFN [31:12], bits [11:2] trunc)
 *    0x1024+          | Unmapped PMP           | Reads return 0xBAD00002
 *
 *    [!] PMP Security Lock:
 *        PMP registers are hardware write-protected. Writes are ignored unless the slot is
 *        actively decoupled via efpga_subsystem_decouple().
 *
 *    [!] 4KB Page Alignment & Address Truncation:
 *        Hardware enforces 4KB page granularity (PAGE_GRANULARITY = 1). When programming BASE
 *        and LIMIT, the hardware comparator stores only the upper 20 bits (Page Frame Number,
 *        address[31:12]) and the lower 2 control bits [1:0]. Bits [11:2] are discarded by
 *        hardware and read back as zero.
 *
 * 2. Fabric User Port (s_axil_ctrl @ fabric_base):
 *    --------------------------------------------------------------------------------------------
 *    Offset Range     | Region Name            | Description
 *    --------------------------------------------------------------------------------------------
 *    0x0000 - 0xFFFF  | User Fabric Design     | Direct MMIO access to accelerator inside eFPGA
 * =============================================================================================== */

/* ===============================================================================================
 * Hardware Configuration Constants
 * =============================================================================================== */

#define EFPGA_SUBSYSTEM_HW_VERSION_MASK       0xFFF00000U
#define EFPGA_SUBSYSTEM_HW_VERSION_MAGIC      0xFAB00000U
#define EFPGA_PMP_NUM_REGIONS                 2U
#define EFPGA_PMP_PAGE_SIZE                   4096U
#define EFPGA_PMP_PAGE_MASK                   (~(uint32_t)(EFPGA_PMP_PAGE_SIZE - 1U))

/* ===============================================================================================
 * Register Offset Definitions (Relative to mgr_base)
 * =============================================================================================== */

/* Global Management Registers (0x0000 - 0x000C) */
#define EFPGA_REG_HW_VERSION                  0x0000U  /**< Hardware version ID & magic (RO) */
#define EFPGA_REG_GLOBAL_CTRL                 0x0004U  /**< Global control & soft reset (RW) */
#define EFPGA_REG_CONFIG_DATA                 0x0008U  /**< Bitstream stream FIFO data port (WO) */
#define EFPGA_REG_CONFIG_COUNT                0x000CU  /**< Bitstream word count monitor (RO) */

/* Slot Control & Status Registers (0x1000 - 0x1010) */
#define EFPGA_REG_SLOT_CTRL                   0x1000U  /**< Slot isolation & module enables (RW) */
#define EFPGA_REG_SLOT_STATUS                 0x1004U  /**< Slot activity & fault flags (RO) */
#define EFPGA_REG_FAULT_CLEAR                 0x1008U  /**< Latched fault clear strobe (WO) */
#define EFPGA_REG_DEBUG_OUT                   0x100CU  /**< Static debug output to fabric (RW) */
#define EFPGA_REG_DEBUG_IN                    0x1010U  /**< Static debug input from fabric (RO) */

/* Physical Memory Protection (PMP) Region Offsets (0x1014 - 0x1020) */
#define EFPGA_REG_PMP_BASE(region)            (0x1014U + ((uint32_t)(region) * 0x08U))
#define EFPGA_REG_PMP_LIMIT(region)           (0x1018U + ((uint32_t)(region) * 0x08U))

/* ===============================================================================================
 * Memory-Mapped Register Layout (Unified MMIO Struct)
 * =============================================================================================== */

/**
 * @brief Complete eFPGA Subsystem Manager Memory-Mapped Register Map.
 * Provides direct struct-based access with explicit hardware address offsets.
 */
typedef volatile struct __attribute__((packed, aligned(4))) {
    /* Global Management Registers (0x0000 - 0x000C) */
    uint32_t HW_VERSION;            /* mgr_base + 0x0000: Hardware Version ID & Magic (RO) */
    uint32_t GLOBAL_CTRL;           /* mgr_base + 0x0004: Global Control & Soft Reset (RW) */
    uint32_t CONFIG_DATA;           /* mgr_base + 0x0008: Bitstream Stream FIFO Data (WO) */
    uint32_t CONFIG_COUNT;          /* mgr_base + 0x000C: Bitstream Word Counter (RO) */

    /* Reserved Gap to Slot 0 (0x0010 - 0x0FFF) */
    const uint32_t __res0[1020];    /* mgr_base + 0x0010: 4,080 bytes padding to 0x1000 */

    /* Slot Control & Status (0x1000 - 0x1010) */
    uint32_t SLOT_CTRL;             /* mgr_base + 0x1000: Slot Control & Feature Enables (RW) */
    uint32_t SLOT_STATUS;           /* mgr_base + 0x1004: Slot Status & Activity Flags (RO) */
    uint32_t FAULT_CLEAR;           /* mgr_base + 0x1008: Fault Clear Strobe (WO) */
    uint32_t DEBUG_OUT;             /* mgr_base + 0x100C: Static Debug Output to Fabric (RW) */
    uint32_t DEBUG_IN;              /* mgr_base + 0x1010: Static Debug Input from Fabric (RO) */

    /* Physical Memory Protection (PMP) Regions 0..1 (0x1014 - 0x1023) */
    struct {
        uint32_t BASE;              /* mgr_base + 0x1014 + (r * 8): Base 4KB PFN [31:12] & Flags [1:0] */
        uint32_t LIMIT;             /* mgr_base + 0x1018 + (r * 8): Limit 4KB PFN [31:12] & Security [1:0] */
    } PMP[EFPGA_PMP_NUM_REGIONS];
} mmio_efpga_manager_t;

/* ===============================================================================================
 * Hardware Handles & Port Accessors
 * =============================================================================================== */

/**
 * @brief Obtain a typed pointer to the eFPGA Manager registers at the given interconnect base address.
 */
#define EFPGA_MGR(base_addr) ((mmio_efpga_manager_t *)(uintptr_t)(base_addr))

/**
 * @brief Obtain a pointer to the eFPGA Fabric User Port (s_axil_ctrl) at the given interconnect base address.
 * Use this pointer to exchange data directly with user accelerators instantiated in the fabric.
 */
#define EFPGA_FABRIC_PORT(fabric_base_addr) ((volatile uint32_t *)(uintptr_t)(fabric_base_addr))

/* ===============================================================================================
 * Register Bitfield Definitions
 * =============================================================================================== */

/**
 * @brief GLOBAL_CTRL register bit positions (mgr_base + 0x0004).
 */
enum efpga_global_ctrl_bits {
    EFPGA_GLOBAL_CTRL_SOFT_RESET       = (1U << 0),
    EFPGA_GLOBAL_CTRL_COM_ACTIVE       = (1U << 1),
    EFPGA_GLOBAL_CTRL_DESIGN_LOADED    = (1U << 2)
};

/**
 * @brief SLOT_CTRL register bit positions (mgr_base + 0x1000).
 */
enum efpga_slot_ctrl_bits {
    EFPGA_SLOT_CTRL_DECOUPLE_REQ       = (1U << 0),
    EFPGA_SLOT_CTRL_DECOUPLE_FORCE     = (1U << 1),
    EFPGA_SLOT_CTRL_PMP_EN             = (1U << 8),
    EFPGA_SLOT_CTRL_WDOG_DM_EN         = (1U << 16),
    EFPGA_SLOT_CTRL_WDOG_CS_EN         = (1U << 17),
    EFPGA_SLOT_CTRL_WDOG_DS_EN         = (1U << 18),
    EFPGA_SLOT_CTRL_WDOG_CM_EN         = (1U << 19),
    EFPGA_SLOT_CTRL_WB_SLAVE_EN        = (1U << 24),
    EFPGA_SLOT_CTRL_WB_MASTER_EN       = (1U << 25)
};

/**
 * @brief SLOT_STATUS register bit positions (mgr_base + 0x1004).
 */
enum efpga_slot_status_bits {
    EFPGA_SLOT_STATUS_IS_DECOUPLED     = (1U << 0),
    EFPGA_SLOT_STATUS_HOST_ACT         = (1U << 1),
    EFPGA_SLOT_STATUS_DMA_ACT          = (1U << 2),
    EFPGA_SLOT_STATUS_PMP_R_FAULT      = (1U << 8),
    EFPGA_SLOT_STATUS_PMP_W_FAULT      = (1U << 9),
    EFPGA_SLOT_STATUS_WDOG_DM_PR       = (1U << 16),
    EFPGA_SLOT_STATUS_WDOG_DM_TO       = (1U << 17),
    EFPGA_SLOT_STATUS_WDOG_CS_PR       = (1U << 18),
    EFPGA_SLOT_STATUS_WDOG_CS_TO       = (1U << 19),
    EFPGA_SLOT_STATUS_WDOG_SOC         = (1U << 20),
    EFPGA_SLOT_STATUS_WDOG_ALL_MASK    = (0x1FU << 16)
};

/**
 * @brief Physical Memory Protection permission and attribute bits (stored in bits [1:0]).
 */
enum efpga_pmp_cfg_bits {
    EFPGA_PMP_BASE_READ_EN             = (1U << 0),  /**< In BASE[0]: Enable fabric DMA reads */
    EFPGA_PMP_BASE_WRITE_EN            = (1U << 1),  /**< In BASE[1]: Enable fabric DMA writes */
    EFPGA_PMP_LIMIT_PRIV_REQ           = (1U << 0),  /**< In LIMIT[0]: Require privileged AXI transfer */
    EFPGA_PMP_LIMIT_SEC_REQ            = (1U << 1)   /**< In LIMIT[1]: Require secure AXI transfer */
};

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
 * @brief Synthesized subsystem hardware features discovered dynamically at runtime.
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
 * @brief Runtime slot status snapshot.
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
 * Driver API Functions
 * =============================================================================================== */

/**
 * @brief Initialize the eFPGA Subsystem driver and verify hardware presence.
 * @param mgr_base Interconnect base address of the eFPGA Subsystem Manager.
 * @return Hardware version ID on success, or 0 on communication failure.
 */
uint32_t efpga_subsystem_init(uintptr_t mgr_base);

/**
 * @brief Dynamically probe synthesized hardware features.
 * @param mgr_base Interconnect base address of the eFPGA Subsystem Manager.
 * @param caps Output capabilities structure.
 * @return 0 on success, negative error code on invalid parameters.
 */
int efpga_subsystem_get_capabilities(uintptr_t mgr_base, efpga_subsystem_capabilities_t *caps);

/**
 * @brief Decouple the eFPGA fabric from the system interconnect.
 * Must be asserted prior to configuring PMP regions or streaming bitstreams.
 * @param mgr_base Interconnect base address of the eFPGA Subsystem Manager.
 * @param force Force immediate isolation without waiting for pending in-flight transactions.
 * @param timeout_cycles Maximum polling iterations waiting for bus transactions to complete.
 * @return 0 on success, -1 on timeout.
 */
int efpga_subsystem_decouple(uintptr_t mgr_base, bool force, uint32_t timeout_cycles);

/**
 * @brief Re-couple the eFPGA fabric to the system interconnect following configuration.
 * @param mgr_base Interconnect base address of the eFPGA Subsystem Manager.
 */
void efpga_subsystem_recouple(uintptr_t mgr_base);

/**
 * @brief Stream a contiguous binary bitstream into configuration memory.
 * Isolates the fabric, asserts soft reset, streams the configuration words, and restores coupling.
 * @param mgr_base Interconnect base address of the eFPGA Subsystem Manager.
 * @param bitstream_bytes Pointer to raw bitstream bytes.
 * @param byte_count Total size of the bitstream in bytes.
 * @return 0 on success, negative error code on failure.
 */
int efpga_subsystem_load_bitstream(uintptr_t mgr_base, const uint8_t *bitstream_bytes, size_t byte_count);

/**
 * @brief Scatter-gather bitstream streaming for fragmented memory buffers.
 * @param mgr_base Interconnect base address of the eFPGA Subsystem Manager.
 * @param fragments Array of bitstream fragments.
 * @param num_fragments Number of fragments in the array.
 * @return 0 on success, negative error code on failure.
 */
int efpga_subsystem_load_fragments(uintptr_t mgr_base,
                                   const efpga_subsystem_fragment_t *fragments,
                                   size_t num_fragments);

/**
 * @brief Assert or release the fabric soft reset line.
 * @param mgr_base Interconnect base address of the eFPGA Subsystem Manager.
 * @param assert_reset True to hold fabric in reset, False to release reset.
 */
void efpga_subsystem_set_soft_reset(uintptr_t mgr_base, bool assert_reset);

/**
 * @brief Read runtime slot status snapshot (decoupling state, bus activity, fault flags).
 * @param mgr_base Interconnect base address of the eFPGA Subsystem Manager.
 * @param state Output slot state structure.
 * @return 0 on success, negative error code on invalid parameters.
 */
int efpga_subsystem_get_slot_state(uintptr_t mgr_base, efpga_subsystem_slot_state_t *state);

/**
 * @brief Clear latched fault flags (watchdog timeouts, PMP violations).
 * @param mgr_base Interconnect base address of the eFPGA Subsystem Manager.
 * @param clear_pmp_r Clear PMP read violations.
 * @param clear_pmp_w Clear PMP write violations.
 * @param clear_wdog Clear all watchdog timeouts.
 */
void efpga_subsystem_clear_faults(uintptr_t mgr_base,
                                  bool clear_pmp_r, bool clear_pmp_w, bool clear_wdog);

/**
 * @brief Configure a Physical Memory Protection (PMP) region.
 *
 * Requirements & Constraints:
 * 1. The slot MUST be actively decoupled before calling this function (hardware security lock).
 * 2. Addresses must be 4KB page-aligned. Hardware comparator operates on Page Frame Numbers
 *    (bits [31:12]). In-page offset bits [11:2] are truncated by hardware and read back as zero.
 *
 * @param mgr_base Interconnect base address of the eFPGA Subsystem Manager.
 * @param region Region index (0 or 1).
 * @param start_addr Base physical address (automatically masked to 4KB page boundary).
 * @param end_addr Limit physical address (automatically masked to 4KB page boundary).
 * @param read_en Allow fabric DMA reads.
 * @param write_en Allow fabric DMA writes.
 * @param req_priv Require privileged AXI access.
 * @param req_sec Require secure AXI access.
 * @return 0 on success, -1 on invalid parameters, -2 if slot is not decoupled (security lock).
 */
int efpga_subsystem_set_pmp_region(uintptr_t mgr_base, uint32_t region,
                                   uint32_t start_addr, uint32_t end_addr,
                                   bool read_en, bool write_en, bool req_priv, bool req_sec);

/**
 * @brief Write to the static debug output register.
 * @param mgr_base Interconnect base address of the eFPGA Subsystem Manager.
 * @param val 32-bit value driven to the fabric debug input wires.
 */
void efpga_subsystem_write_debug_io(uintptr_t mgr_base, uint32_t val);

/**
 * @brief Read from the static debug input register.
 * @param mgr_base Interconnect base address of the eFPGA Subsystem Manager.
 * @return 32-bit value captured from the fabric debug output wires.
 */
uint32_t efpga_subsystem_read_debug_io(uintptr_t mgr_base);

#ifdef __cplusplus
}
#endif

#endif /* EFPGA_SUBSYSTEM_HAL_H */
