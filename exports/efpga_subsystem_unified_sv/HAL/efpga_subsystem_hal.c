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
    if (assert_reset) {
        dev->SLOT_RESET |= EFPGA_SLOT_RESET_ALL_MASK;
    } else {
        dev->SLOT_RESET &= ~EFPGA_SLOT_RESET_ALL_MASK;
    }
}

void efpga_subsystem_set_slot_reset(uintptr_t mgr_base, uint32_t reset_mask) {
    if (mgr_base == 0) {
        return;
    }
    mmio_efpga_manager_t *dev = EFPGA_MGR(mgr_base);
    dev->SLOT_RESET = reset_mask;
}

uint32_t efpga_subsystem_get_slot_reset(uintptr_t mgr_base) {
    if (mgr_base == 0) {
        return 0;
    }
    mmio_efpga_manager_t *dev = EFPGA_MGR(mgr_base);
    return dev->SLOT_RESET;
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

    /* Stream 32-bit frames directly into CONFIG_DATA: hardware performs automatic byte translation */
    if (((uintptr_t)bitstream_bytes & 0x3) == 0) {
        const uint32_t *word_stream = (const uint32_t *)bitstream_bytes;
        for (size_t i = 0; i < words; i++) {
            dev->CONFIG_DATA = word_stream[i];
        }
    } else {
        for (size_t i = 0; i < words; i++) {
            size_t offset = i * 4;
            uint32_t word = 0;
            size_t rem = (offset + 4 <= byte_count) ? 4 : (byte_count - offset);
            for (size_t b = 0; b < rem; b++) {
                word |= ((uint32_t)bitstream_bytes[offset + b]) << (b * 8);
            }
            dev->CONFIG_DATA = word;
        }
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
            staging_word |= ((uint32_t)data[i]) << (staged_bytes * 8);
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

int efpga_subsystem_set_dma_prot(uintptr_t mgr_base, uint8_t awprot, uint8_t arprot) {
    if (mgr_base == 0) {
        return -1;
    }
    mmio_efpga_manager_t *dev = EFPGA_MGR(mgr_base);
    uint32_t ctrl = dev->SLOT_CTRL;
    ctrl &= ~(EFPGA_SLOT_CTRL_AWPROT_MASK | EFPGA_SLOT_CTRL_ARPROT_MASK);
    ctrl |= (((uint32_t)(awprot & 0x7)) << EFPGA_SLOT_CTRL_AWPROT_SHIFT);
    ctrl |= (((uint32_t)(arprot & 0x7)) << EFPGA_SLOT_CTRL_ARPROT_SHIFT);
    dev->SLOT_CTRL = ctrl;
    return 0;
}

int efpga_subsystem_get_dma_prot(uintptr_t mgr_base, uint8_t *awprot, uint8_t *arprot) {
    if (mgr_base == 0 || !awprot || !arprot) {
        return -1;
    }
    mmio_efpga_manager_t *dev = EFPGA_MGR(mgr_base);
    uint32_t ctrl = dev->SLOT_CTRL;
    *awprot = (uint8_t)((ctrl & EFPGA_SLOT_CTRL_AWPROT_MASK) >> EFPGA_SLOT_CTRL_AWPROT_SHIFT);
    *arprot = (uint8_t)((ctrl & EFPGA_SLOT_CTRL_ARPROT_MASK) >> EFPGA_SLOT_CTRL_ARPROT_SHIFT);
    return 0;
}

