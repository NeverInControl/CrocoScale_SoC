#include "efpga_subsystem_hal.h"

uint32_t efpga_subsystem_init(uintptr_t mgr_base) {
    if (mgr_base == 0) {
        return 0;
    }
    mmio_efpga_manager_t *dev = EFPGA_MGR(mgr_base);
    uint32_t hw_ver = dev->HW_VERSION;
    if ((hw_ver & EFPGA_SUBSYSTEM_HW_VERSION_MASK) != EFPGA_SUBSYSTEM_HW_VERSION_MAGIC) {
        return 0;
    }
    return hw_ver;
}

void efpga_subsystem_set_soft_reset(uintptr_t mgr_base, bool assert_reset) {
    if (mgr_base == 0) {
        return;
    }
    mmio_efpga_manager_t *dev = EFPGA_MGR(mgr_base);
    uint32_t ctrl = dev->GLOBAL_CTRL;
    if (assert_reset) {
        ctrl |= EFPGA_GLOBAL_CTRL_SOFT_RESET;
    } else {
        ctrl &= ~EFPGA_GLOBAL_CTRL_SOFT_RESET;
    }
    dev->GLOBAL_CTRL = ctrl;
}

int efpga_subsystem_decouple(uintptr_t mgr_base, bool force, uint32_t timeout_cycles) {
    if (mgr_base == 0) {
        return -1;
    }
    mmio_efpga_manager_t *dev = EFPGA_MGR(mgr_base);

    uint32_t ctrl = dev->SLOT_CTRL;
    if (force) {
        ctrl |= EFPGA_SLOT_CTRL_DECOUPLE_FORCE;
        ctrl &= ~EFPGA_SLOT_CTRL_DECOUPLE_REQ;
    } else {
        ctrl |= EFPGA_SLOT_CTRL_DECOUPLE_REQ;
        ctrl &= ~EFPGA_SLOT_CTRL_DECOUPLE_FORCE;
    }
    dev->SLOT_CTRL = ctrl;

    while (timeout_cycles > 0) {
        if (dev->SLOT_STATUS & EFPGA_SLOT_STATUS_IS_DECOUPLED) {
            return 0;
        }
        timeout_cycles--;
    }

    return -1;
}

void efpga_subsystem_recouple(uintptr_t mgr_base) {
    if (mgr_base == 0) {
        return;
    }
    mmio_efpga_manager_t *dev = EFPGA_MGR(mgr_base);
    uint32_t ctrl = dev->SLOT_CTRL;
    ctrl &= ~(EFPGA_SLOT_CTRL_DECOUPLE_REQ | EFPGA_SLOT_CTRL_DECOUPLE_FORCE);
    dev->SLOT_CTRL = ctrl;
}

int efpga_subsystem_get_capabilities(uintptr_t mgr_base, efpga_subsystem_capabilities_t *caps) {
    if (!caps || mgr_base == 0) {
        return -1;
    }

    mmio_efpga_manager_t *dev = EFPGA_MGR(mgr_base);
    uint32_t orig_val = dev->SLOT_CTRL;
    uint32_t probe_mask = EFPGA_SLOT_CTRL_PMP_EN | EFPGA_SLOT_CTRL_WB_SLAVE_EN |
                          EFPGA_SLOT_CTRL_WB_MASTER_EN | EFPGA_SLOT_CTRL_WDOG_DM_EN |
                          EFPGA_SLOT_CTRL_WDOG_CS_EN | EFPGA_SLOT_CTRL_WDOG_DS_EN |
                          EFPGA_SLOT_CTRL_WDOG_CM_EN;

    /* Write probe mask to read back synthesizable feature presence */
    dev->SLOT_CTRL = orig_val | probe_mask;
    uint32_t probed = dev->SLOT_CTRL;
    dev->SLOT_CTRL = orig_val;

    caps->has_pmp              = (probed & EFPGA_SLOT_CTRL_PMP_EN) != 0;
    caps->has_wb_slave         = (probed & EFPGA_SLOT_CTRL_WB_SLAVE_EN) != 0;
    caps->has_wb_master        = (probed & EFPGA_SLOT_CTRL_WB_MASTER_EN) != 0;
    caps->has_wdog_dma_master  = (probed & EFPGA_SLOT_CTRL_WDOG_DM_EN) != 0;
    caps->has_wdog_ctrl_slave  = (probed & EFPGA_SLOT_CTRL_WDOG_CS_EN) != 0;
    caps->has_wdog_dma_slave   = (probed & EFPGA_SLOT_CTRL_WDOG_DS_EN) != 0;
    caps->has_wdog_ctrl_master = (probed & EFPGA_SLOT_CTRL_WDOG_CM_EN) != 0;

    caps->num_pmp_regions = 0;
    if (caps->has_pmp) {
        for (uint32_t r = 0; r < EFPGA_PMP_NUM_REGIONS; r++) {
            uint32_t val = dev->PMP[r].BASE;
            if (val == 0xBAD00002) {
                break;
            }
            caps->num_pmp_regions++;
        }
    }

    return 0;
}

int efpga_subsystem_load_bitstream(uintptr_t mgr_base, const uint8_t *bitstream_bytes, size_t byte_count) {
    if (!bitstream_bytes || byte_count == 0 || mgr_base == 0) {
        return -1;
    }

    mmio_efpga_manager_t *dev = EFPGA_MGR(mgr_base);

    /* Isolate fabric from interconnect prior to configuration */
    if (efpga_subsystem_decouple(mgr_base, false, 100000) != 0) {
        return -2;
    }

    /* Hold fabric in soft reset during bitstream loading */
    efpga_subsystem_set_soft_reset(mgr_base, true);

    uint32_t initial_count = dev->CONFIG_COUNT;
    size_t words = (byte_count + 3) / 4;

    /* Stream big-endian 32-bit frames into CONFIG_DATA */
    for (size_t i = 0; i < words; i++) {
        size_t offset = i * 4;
        uint8_t b0 = (offset + 0 < byte_count) ? bitstream_bytes[offset + 0] : 0x00;
        uint8_t b1 = (offset + 1 < byte_count) ? bitstream_bytes[offset + 1] : 0x00;
        uint8_t b2 = (offset + 2 < byte_count) ? bitstream_bytes[offset + 2] : 0x00;
        uint8_t b3 = (offset + 3 < byte_count) ? bitstream_bytes[offset + 3] : 0x00;

        uint32_t word = ((uint32_t)b0 << 24) |
                        ((uint32_t)b1 << 16) |
                        ((uint32_t)b2 << 8)  |
                        ((uint32_t)b3);

        dev->CONFIG_DATA = word;
    }

    /* Verify written word count against hardware monitor */
    uint32_t words_written = dev->CONFIG_COUNT - initial_count;
    if (words_written != words) {
        efpga_subsystem_set_soft_reset(mgr_base, false);
        efpga_subsystem_recouple(mgr_base);
        return -3;
    }

    /* Release reset and recouple fabric to interconnect */
    efpga_subsystem_set_soft_reset(mgr_base, false);
    efpga_subsystem_recouple(mgr_base);

    return 0;
}

int efpga_subsystem_load_fragments(uintptr_t mgr_base,
                                   const efpga_subsystem_fragment_t *fragments,
                                   size_t num_fragments) {
    if (!fragments || num_fragments == 0 || mgr_base == 0) {
        return -1;
    }

    mmio_efpga_manager_t *dev = EFPGA_MGR(mgr_base);

    if (efpga_subsystem_decouple(mgr_base, false, 100000) != 0) {
        return -2;
    }

    efpga_subsystem_set_soft_reset(mgr_base, true);

    uint32_t initial_count = dev->CONFIG_COUNT;
    uint32_t total_words = 0;
    uint32_t staging_word = 0;
    size_t staged_bytes = 0;

    for (size_t f = 0; f < num_fragments; f++) {
        const uint8_t *data = fragments[f].data;
        size_t size = fragments[f].bin_size;
        if (!data || size == 0) {
            continue;
        }

        for (size_t i = 0; i < size; i++) {
            staging_word = (staging_word << 8) | (uint32_t)data[i];
            staged_bytes++;
            if (staged_bytes == 4) {
                dev->CONFIG_DATA = staging_word;
                total_words++;
                staging_word = 0;
                staged_bytes = 0;
            }
        }
    }

    if (staged_bytes > 0) {
        staging_word <<= (8 * (4 - staged_bytes));
        dev->CONFIG_DATA = staging_word;
        total_words++;
    }

    uint32_t words_written = dev->CONFIG_COUNT - initial_count;
    if (words_written != total_words) {
        efpga_subsystem_set_soft_reset(mgr_base, false);
        efpga_subsystem_recouple(mgr_base);
        return -3;
    }

    efpga_subsystem_set_soft_reset(mgr_base, false);
    efpga_subsystem_recouple(mgr_base);

    return 0;
}

int efpga_subsystem_get_slot_state(uintptr_t mgr_base, efpga_subsystem_slot_state_t *state) {
    if (!state || mgr_base == 0) {
        return -1;
    }

    mmio_efpga_manager_t *dev = EFPGA_MGR(mgr_base);
    uint32_t status = dev->SLOT_STATUS;

    state->is_decoupled    = (status & EFPGA_SLOT_STATUS_IS_DECOUPLED) != 0;
    state->host_active     = (status & EFPGA_SLOT_STATUS_HOST_ACT) != 0;
    state->dma_active      = (status & EFPGA_SLOT_STATUS_DMA_ACT) != 0;
    state->pmp_read_fault  = (status & EFPGA_SLOT_STATUS_PMP_R_FAULT) != 0;
    state->pmp_write_fault = (status & EFPGA_SLOT_STATUS_PMP_W_FAULT) != 0;
    state->wdog_fault      = (status & EFPGA_SLOT_STATUS_WDOG_ALL_MASK) != 0;

    return 0;
}

void efpga_subsystem_clear_faults(uintptr_t mgr_base,
                                  bool clear_pmp_r, bool clear_pmp_w, bool clear_wdog) {
    if (mgr_base == 0) {
        return;
    }

    mmio_efpga_manager_t *dev = EFPGA_MGR(mgr_base);
    uint32_t clr_mask = 0;
    if (clear_pmp_r) clr_mask |= (1U << 8);
    if (clear_pmp_w) clr_mask |= (1U << 9);
    if (clear_wdog)  clr_mask |= (0x1FU << 16);

    dev->FAULT_CLEAR = clr_mask;
}

int efpga_subsystem_set_pmp_region(uintptr_t mgr_base, uint32_t region,
                                   uint32_t start_addr, uint32_t end_addr,
                                   bool read_en, bool write_en, bool req_priv, bool req_sec) {
    if (region >= EFPGA_PMP_NUM_REGIONS || start_addr >= end_addr || mgr_base == 0) {
        return -1;
    }

    mmio_efpga_manager_t *dev = EFPGA_MGR(mgr_base);

    /* Hardware security lock: PMP registers drop writes unless slot is actively decoupled */
    if (!(dev->SLOT_STATUS & EFPGA_SLOT_STATUS_IS_DECOUPLED)) {
        return -2;
    }

    /* Hardware stores Page Frame Number (bits [31:12]). Bits [11:2] are discarded by hardware. */
    uint32_t base_cfg = (start_addr & EFPGA_PMP_PAGE_MASK);
    if (read_en)  base_cfg |= EFPGA_PMP_BASE_READ_EN;
    if (write_en) base_cfg |= EFPGA_PMP_BASE_WRITE_EN;

    uint32_t limit_cfg = (end_addr & EFPGA_PMP_PAGE_MASK);
    if (req_priv) limit_cfg |= EFPGA_PMP_LIMIT_PRIV_REQ;
    if (req_sec)  limit_cfg |= EFPGA_PMP_LIMIT_SEC_REQ;

    dev->PMP[region].BASE  = base_cfg;
    dev->PMP[region].LIMIT = limit_cfg;

    return 0;
}

void efpga_subsystem_write_debug_io(uintptr_t mgr_base, uint32_t val) {
    if (mgr_base == 0) {
        return;
    }
    mmio_efpga_manager_t *dev = EFPGA_MGR(mgr_base);
    dev->DEBUG_OUT = val;
}

uint32_t efpga_subsystem_read_debug_io(uintptr_t mgr_base) {
    if (mgr_base == 0) {
        return 0;
    }
    mmio_efpga_manager_t *dev = EFPGA_MGR(mgr_base);
    return dev->DEBUG_IN;
}
