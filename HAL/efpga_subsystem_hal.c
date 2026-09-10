#include "efpga_subsystem_hal.h"

/* Volatile Memory-Mapped I/O Accessors */
static inline void mmio_write32(uintptr_t addr, uint32_t val) {
    *(volatile uint32_t *)addr = val;
}

static inline uint32_t mmio_read32(uintptr_t addr) {
    return *(volatile uint32_t *)addr;
}

uint32_t efpga_subsystem_init(uintptr_t base_addr) {
    if (base_addr == 0) {
        return 0;
    }
    uint32_t hw_ver = mmio_read32(base_addr + EFPGA_SUBSYSTEM_REG_HW_VERSION);
    if ((hw_ver & EFPGA_SUBSYSTEM_HW_VERSION_MASK) != EFPGA_SUBSYSTEM_HW_VERSION_MAGIC) {
        return 0;
    }
    return hw_ver;
}

void efpga_subsystem_set_soft_reset(uintptr_t base_addr, bool assert_reset) {
    uint32_t ctrl = mmio_read32(base_addr + EFPGA_SUBSYSTEM_REG_GLOBAL_CTRL);
    if (assert_reset) {
        ctrl |= EFPGA_SUBSYSTEM_GLOBAL_CTRL_SOFT_RESET;
    } else {
        ctrl &= ~EFPGA_SUBSYSTEM_GLOBAL_CTRL_SOFT_RESET;
    }
    mmio_write32(base_addr + EFPGA_SUBSYSTEM_REG_GLOBAL_CTRL, ctrl);
}

int efpga_subsystem_decouple(uintptr_t base_addr, uint32_t slot, bool force, uint32_t timeout_cycles) {
    uintptr_t ctrl_addr   = base_addr + EFPGA_SUBSYSTEM_REG_SLOT_CTRL(slot);
    uintptr_t status_addr = base_addr + EFPGA_SUBSYSTEM_REG_SLOT_STATUS(slot);

    uint32_t ctrl = mmio_read32(ctrl_addr);
    if (force) {
        ctrl |= EFPGA_SUBSYSTEM_SLOT_CTRL_DECOUPLE_FORCE;
        ctrl &= ~EFPGA_SUBSYSTEM_SLOT_CTRL_DECOUPLE_REQ;
    } else {
        ctrl |= EFPGA_SUBSYSTEM_SLOT_CTRL_DECOUPLE_REQ;
        ctrl &= ~EFPGA_SUBSYSTEM_SLOT_CTRL_DECOUPLE_FORCE;
    }
    mmio_write32(ctrl_addr, ctrl);

    while (timeout_cycles > 0) {
        uint32_t status = mmio_read32(status_addr);
        if (status & EFPGA_SUBSYSTEM_SLOT_STATUS_IS_DECOUPLED) {
            return 0;
        }
        timeout_cycles--;
    }

    return -1;
}

void efpga_subsystem_recouple(uintptr_t base_addr, uint32_t slot) {
    uintptr_t ctrl_addr = base_addr + EFPGA_SUBSYSTEM_REG_SLOT_CTRL(slot);
    uint32_t ctrl = mmio_read32(ctrl_addr);
    ctrl &= ~(EFPGA_SUBSYSTEM_SLOT_CTRL_DECOUPLE_REQ | EFPGA_SUBSYSTEM_SLOT_CTRL_DECOUPLE_FORCE);
    mmio_write32(ctrl_addr, ctrl);
}

int efpga_subsystem_get_capabilities(uintptr_t base_addr, uint32_t slot, efpga_subsystem_capabilities_t *caps) {
    if (!caps || base_addr == 0) {
        return -1;
    }

    uintptr_t ctrl_addr = base_addr + EFPGA_SUBSYSTEM_REG_SLOT_CTRL(slot);
    uint32_t orig_val = mmio_read32(ctrl_addr);
    uint32_t probe_mask = EFPGA_SUBSYSTEM_SLOT_CTRL_PMP_EN | EFPGA_SUBSYSTEM_SLOT_CTRL_WB_SLAVE_EN |
                          EFPGA_SUBSYSTEM_SLOT_CTRL_WB_MASTER_EN | EFPGA_SUBSYSTEM_SLOT_CTRL_WDOG_DM_EN |
                          EFPGA_SUBSYSTEM_SLOT_CTRL_WDOG_CS_EN | EFPGA_SUBSYSTEM_SLOT_CTRL_WDOG_DS_EN |
                          EFPGA_SUBSYSTEM_SLOT_CTRL_WDOG_CM_EN;

    /* Write probe mask to read back synthesizable feature presence */
    mmio_write32(ctrl_addr, orig_val | probe_mask);
    uint32_t probed = mmio_read32(ctrl_addr);
    mmio_write32(ctrl_addr, orig_val);

    caps->has_pmp              = (probed & EFPGA_SUBSYSTEM_SLOT_CTRL_PMP_EN) != 0;
    caps->has_wb_slave         = (probed & EFPGA_SUBSYSTEM_SLOT_CTRL_WB_SLAVE_EN) != 0;
    caps->has_wb_master        = (probed & EFPGA_SUBSYSTEM_SLOT_CTRL_WB_MASTER_EN) != 0;
    caps->has_wdog_dma_master  = (probed & EFPGA_SUBSYSTEM_SLOT_CTRL_WDOG_DM_EN) != 0;
    caps->has_wdog_ctrl_slave  = (probed & EFPGA_SUBSYSTEM_SLOT_CTRL_WDOG_CS_EN) != 0;
    caps->has_wdog_dma_slave   = (probed & EFPGA_SUBSYSTEM_SLOT_CTRL_WDOG_DS_EN) != 0;
    caps->has_wdog_ctrl_master = (probed & EFPGA_SUBSYSTEM_SLOT_CTRL_WDOG_CM_EN) != 0;

    caps->num_pmp_regions = 0;
    if (caps->has_pmp) {
        for (int r = 0; r < 16; r++) {
            uint32_t val = mmio_read32(base_addr + EFPGA_SUBSYSTEM_REG_PMP_BASE(slot, r));
            if (val == 0xBAD00002) {
                break;
            }
            caps->num_pmp_regions++;
        }
    }

    return 0;
}

int efpga_subsystem_get_slot_state(uintptr_t base_addr, uint32_t slot, efpga_subsystem_slot_state_t *state) {
    if (!state || base_addr == 0) {
        return -1;
    }

    uint32_t status = mmio_read32(base_addr + EFPGA_SUBSYSTEM_REG_SLOT_STATUS(slot));
    state->is_decoupled    = (status & EFPGA_SUBSYSTEM_SLOT_STATUS_IS_DECOUPLED) != 0;
    state->host_active     = (status & EFPGA_SUBSYSTEM_SLOT_STATUS_HOST_ACT) != 0;
    state->dma_active      = (status & EFPGA_SUBSYSTEM_SLOT_STATUS_DMA_ACT) != 0;
    state->pmp_read_fault  = (status & EFPGA_SUBSYSTEM_SLOT_STATUS_PMP_R_FAULT) != 0;
    state->pmp_write_fault = (status & EFPGA_SUBSYSTEM_SLOT_STATUS_PMP_W_FAULT) != 0;
    state->wdog_fault      = (status & EFPGA_SUBSYSTEM_SLOT_STATUS_WDOG_ALL_MASK) != 0;

    return 0;
}

void efpga_subsystem_clear_faults(uintptr_t base_addr, uint32_t slot,
                                  bool clear_pmp_r, bool clear_pmp_w, bool clear_wdog) {
    uint32_t val = 0;
    if (clear_pmp_r) val |= EFPGA_SUBSYSTEM_SLOT_STATUS_PMP_R_FAULT;
    if (clear_pmp_w) val |= EFPGA_SUBSYSTEM_SLOT_STATUS_PMP_W_FAULT;
    if (clear_wdog)  val |= EFPGA_SUBSYSTEM_SLOT_STATUS_WDOG_ALL_MASK;
    mmio_write32(base_addr + EFPGA_SUBSYSTEM_REG_FAULT_CLEAR(slot), val);
}

int efpga_subsystem_set_pmp_region(uintptr_t base_addr, uint32_t slot, uint32_t region,
                                   uint32_t start_addr, uint32_t end_addr,
                                   bool read_en, bool write_en, bool req_priv, bool req_sec) {
    if ((start_addr & 0x3U) != 0 || (end_addr & 0x3U) != 0 || end_addr <= start_addr) {
        return -1;
    }

    uint32_t base_val = (start_addr & ~0x3U) |
                        (write_en ? EFPGA_SUBSYSTEM_PMP_BASE_WRITE_EN : 0U) |
                        (read_en  ? EFPGA_SUBSYSTEM_PMP_BASE_READ_EN  : 0U);

    uint32_t limit_val = (end_addr & ~0x3U) |
                         (req_sec  ? EFPGA_SUBSYSTEM_PMP_LIMIT_SEC_REQ  : 0U) |
                         (req_priv ? EFPGA_SUBSYSTEM_PMP_LIMIT_PRIV_REQ : 0U);

    mmio_write32(base_addr + EFPGA_SUBSYSTEM_REG_PMP_BASE(slot, region), base_val);
    mmio_write32(base_addr + EFPGA_SUBSYSTEM_REG_PMP_LIMIT(slot, region), limit_val);
    return 0;
}

void efpga_subsystem_write_debug_io(uintptr_t base_addr, uint32_t slot, uint32_t val) {
    mmio_write32(base_addr + EFPGA_SUBSYSTEM_REG_DEBUG_OUT(slot), val);
}

uint32_t efpga_subsystem_read_debug_io(uintptr_t base_addr, uint32_t slot) {
    return mmio_read32(base_addr + EFPGA_SUBSYSTEM_REG_DEBUG_IN(slot));
}

int efpga_subsystem_load_fragments(uintptr_t base_addr, uint32_t slot,
                                   const efpga_subsystem_fragment_t *fragments,
                                   size_t num_fragments) {
    if (!fragments || num_fragments == 0 || base_addr == 0) {
        return -1;
    }

    /* Aggregate expected word count across all fragmented segments */
    uint32_t total_words_expected = 0;
    for (size_t f = 0; f < num_fragments; f++) {
        uint32_t words = (uint32_t)(fragments[f].bin_size / 4);
        if (fragments[f].bin_size % 4 != 0) {
            words += 1;
        }
        total_words_expected += words;
    }

    /* Isolate slot interconnect to prevent transaction glitches during reconfiguration */
    if (efpga_subsystem_decouple(base_addr, slot, false, 100000) != 0) {
        return -2;
    }

    /* Assert soft reset throughout the bitstream transfer */
    efpga_subsystem_set_soft_reset(base_addr, true);

    /* Sample baseline word count prior to streaming */
    uint32_t initial_count = mmio_read32(base_addr + EFPGA_SUBSYSTEM_REG_CONFIG_COUNT);
    uintptr_t cfg_data_addr = base_addr + EFPGA_SUBSYSTEM_REG_CONFIG_DATA;

    /* Pack and stream fragment bytes in big-endian order to accommodate little-endian host reads */
    for (size_t f = 0; f < num_fragments; f++) {
        const uint8_t *byte_ptr = fragments[f].data;
        size_t img_size = fragments[f].bin_size;
        uint32_t word_count = (uint32_t)(img_size / 4) + ((img_size % 4 != 0) ? 1 : 0);

        for (uint32_t i = 0; i < word_count; i++) {
            size_t offset = i * 4;
            uint8_t b0 = (offset + 0 < img_size) ? byte_ptr[offset + 0] : 0x00;
            uint8_t b1 = (offset + 1 < img_size) ? byte_ptr[offset + 1] : 0x00;
            uint8_t b2 = (offset + 2 < img_size) ? byte_ptr[offset + 2] : 0x00;
            uint8_t b3 = (offset + 3 < img_size) ? byte_ptr[offset + 3] : 0x00;

            uint32_t word = ((uint32_t)b0 << 24) |
                            ((uint32_t)b1 << 16) |
                            ((uint32_t)b2 << 8)  |
                            (uint32_t)b3;

            mmio_write32(cfg_data_addr, word);
        }
    }

    /* Confirm hardware manager accounted for every transmitted word */
    uint32_t final_count = mmio_read32(base_addr + EFPGA_SUBSYSTEM_REG_CONFIG_COUNT);
    uint32_t words_written = final_count - initial_count;
    if (words_written != total_words_expected) {
        return -3;
    }

    /* Deassert soft reset after programming finishes */
    efpga_subsystem_set_soft_reset(base_addr, false);

    /* Signal completed configuration in global control register */
    uint32_t ctrl = mmio_read32(base_addr + EFPGA_SUBSYSTEM_REG_GLOBAL_CTRL);
    ctrl |= EFPGA_SUBSYSTEM_GLOBAL_CTRL_DESIGN_LOADED;
    mmio_write32(base_addr + EFPGA_SUBSYSTEM_REG_GLOBAL_CTRL, ctrl);

    /* Reconnect fabric to system interconnect */
    efpga_subsystem_recouple(base_addr, slot);
    return 0;
}

int efpga_subsystem_load_bitstream(uintptr_t base_addr, uint32_t slot,
                                   const uint8_t *bitstream_bytes, size_t byte_count) {
    efpga_subsystem_fragment_t fragment;
    fragment.data = bitstream_bytes;
    fragment.bin_size = byte_count;
    return efpga_subsystem_load_fragments(base_addr, slot, &fragment, 1);
}

