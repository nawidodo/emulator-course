#include "chip8.h"
#include <string.h>

// Reset the machine to its power-on state (see STAGE.md hardware facts).
// Power-on: memory and V0..VF zeroed, I=0, timers 0, stack empty (SP=0),
// keys released, framebuffer cleared, PC=0x0200 (program-entry convention).
void chip8_init(chip8 *m) {
    memset(m->memory, 0, sizeof(m->memory));
    memset(m->V, 0, sizeof(m->V));
    m->PC = 0x0200;
    m->I = 0;
    m->delay_timer = 0;
    m->sound_timer = 0;
    memset(m->stack, 0, sizeof(m->stack));
    m->SP = 0;
    memset(m->keypad, 0, sizeof(m->keypad));
    memset(m->framebuffer, 0, sizeof(m->framebuffer));
}

static uint32_t fnv1a_update(uint32_t hash, const void *state, size_t size) {
    uint32_t prime = 16777619;
    uint32_t checksum = hash;
    const uint8_t *data = (const uint8_t *)state;
    for (size_t i = 0; i < size; i++) {
        checksum ^= data[i];
        checksum *= prime;
    }
    return checksum;
}

// TODO(CHIP8-01 challenge): compute the FNV-1a checksum of the full
// machine state. The exact byte order is specified in STAGE.md.
uint32_t chip8_state_checksum(const chip8 *m) {
    uint32_t hash = 2166136261;

    uint8_t pc_hi = (m->PC >> 8) & 0xFF;
    uint8_t pc_lo = m->PC & 0xFF;
    uint8_t i_hi = (m->I >> 8) & 0xFF;
    uint8_t i_lo = m->I & 0xFF;

    hash = fnv1a_update(hash, m->memory, sizeof(m->memory));
    hash = fnv1a_update(hash, m->V, sizeof(m->V));
    hash = fnv1a_update(hash, &pc_hi, 1);
    hash = fnv1a_update(hash, &pc_lo, 1);
    hash = fnv1a_update(hash, &i_hi, 1);
    hash = fnv1a_update(hash, &i_lo, 1);
    hash = fnv1a_update(hash, &m->SP, 1);
    for (int idx = 0; idx < 16; idx++) {
        uint8_t hi = (m->stack[idx] >> 8) & 0xFF;
        uint8_t lo = m->stack[idx] & 0xFF;
        hash = fnv1a_update(hash, &hi, 1);
        hash = fnv1a_update(hash, &lo, 1);
    }
    hash = fnv1a_update(hash, &m->delay_timer, 1);
    hash = fnv1a_update(hash, &m->sound_timer, 1);
    for (int k = 0; k < 16; k++) {
        uint8_t v = m->keypad[k] ? 1 : 0;
        hash = fnv1a_update(hash, &v, 1);
    }
    for (int y = 0; y < 32; y++) {
        for (int x = 0; x < 64; x++) {
            uint8_t v = m->framebuffer[y][x] ? 1 : 0;
            hash = fnv1a_update(hash, &v, 1);
        }
    }
    return hash;
}
