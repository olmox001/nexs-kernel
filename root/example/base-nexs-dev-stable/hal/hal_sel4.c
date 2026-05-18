/*
 * hal/hal_sel4.c — HAL for seL4 + Microkit builds
 * ================================================================
 */

#include "include/nexs_hal.h"
#include "include/hal_internal.h"
#include "include/nexs_mmu.h"
#include "include/nexs_timer.h"
#include "../../registry/include/nexs_registry.h"
#include "../../core/include/nexs_value.h"
#include "../../core/include/nexs_alloc.h"

#include <microkit.h>

static void sel4_hal_init(void) {
    /* Microkit initializes low-level hardware; we just print our boot banner */
    microkit_dbg_puts("[NEXS] booting under seL4 + Microkit...\n");
}

static void sel4_hal_putc(char c) {
    char buf[2] = {c, '\0'};
    microkit_dbg_puts(buf);
}

#if defined(__aarch64__)
#define UART_BASE      0x09000000UL
#define UART_DR        ((volatile uint32_t *)(UART_BASE + 0x000))
#define UART_FR        ((volatile uint32_t *)(UART_BASE + 0x018))
#define UART_FR_RXFE   (1U << 4)

static int sel4_hal_getc(void) {
    if (*UART_FR & UART_FR_RXFE) {
        return -1;
    }
    return (int)(*UART_DR & 0xFF);
}
#elif defined(__riscv)
#define UART_BASE      0x10000000UL
#define UART_RBR       ((volatile uint8_t *)(UART_BASE + 0))
#define UART_LSR       ((volatile uint8_t *)(UART_BASE + 5))
#define UART_LSR_DR    (1U << 0)

static int sel4_hal_getc(void) {
    if (!(*UART_LSR & UART_LSR_DR)) {
        return -1;
    }
    return (int)(*UART_RBR);
}
#else
static int sel4_hal_getc(void) {
    return -1; /* Console input not supported on this platform */
}
#endif

static void sel4_hal_memory_map(NexsMemMap *map) {
    if (map) {
        map->entry_point = 0;
        map->ram_base    = 0;
        map->ram_size    = 0;
        map->uart_base   = 0;
    }
}

static void sel4_hal_irq_disable(void) {
    /* No-op under Microkit PD context */
}

static void sel4_hal_irq_enable(void) {
    /* No-op under Microkit PD context */
}

static void sel4_hal_halt(void) __attribute__((noreturn));
static void sel4_hal_halt(void) {
    while (1) {
        /* Spin/Halt under seL4 */
    }
}

void hal_timer_init(TimerCallback cb) {
    g_hal_tick_cb = cb;
}

void hal_timer_set_hz(uint32_t hz) {
    (void)hz;
}

void mmu_worker_sync(void) {
    /* No-op on seL4 */
}

int mm_alloc_page(uint32_t pid, vaddr_t virt, uint32_t flags) {
    void *p = page_alloc(1);
    if (!p) return -1;
    return 0;
}

int mm_free_page(uint32_t pid, vaddr_t virt) {
    page_free((void *)virt, 1);
    return 0;
}

int mm_map_range(uint32_t pid, vaddr_t virt, paddr_t phys, uint32_t pages, uint32_t flags) {
    for (uint32_t i = 0; i < pages; i++) {
        if (mm_alloc_page(pid, virt + i * 4096, flags) != 0) return -1;
    }
    return 0;
}

paddr_t mmu_virt_to_phys(vaddr_t virt) {
    return (paddr_t)virt;
}

void mmu_init(void) {}
int  mmu_map_page(uint32_t pid, vaddr_t virt, paddr_t phys, uint32_t flags) { return 0; }
int  mmu_unmap_page(uint32_t pid, vaddr_t virt) { return 0; }
int  mmu_switch_address_space(uint32_t pid) { return 0; }
void mmu_destroy_address_space(uint32_t pid) {}
paddr_t mmu_create_address_space(uint32_t pid) { return 0; }
void mmu_flush_tlb(vaddr_t virt) {}
void mmu_page_fault(vaddr_t fault_addr, uint64_t err) {}

/* =========================================================
   DRIVER REGISTRATION
   ========================================================= */

static HalDriver s_sel4_driver = {
    .name = "sel4-microkit-console",
    .init = sel4_hal_init,
    .putc = sel4_hal_putc,
    .getc = sel4_hal_getc,
    .halt = sel4_hal_halt,
    .irq_disable = sel4_hal_irq_disable,
    .irq_enable = sel4_hal_irq_enable,
    .memory_map = sel4_hal_memory_map
};

__attribute__((constructor))
static void sel4_register_hal(void) {
    g_hal_driver = &s_sel4_driver;
}
