// CHIP-8 machine core — Stage CHIP8-01 STARTER.
//
// Everything between BEGIN/END STUDENT markers is yours to implement.
// Do NOT add includes beyond <string.h>; do not use globals; do not call
// sleep/clock functions anywhere — the core is deterministic from explicit
// inputs (blueprint v1.2.0 §4, §5).

#include "chip8.h"
#include <string.h>

// Canonical font sprites for hex 0-F, 5 bytes each (hardware fact — provided;
// wiring them into the power-on state IS part of your task, see STAGE.md).
static const uint8_t font[80] = {
    0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
    0x20, 0x60, 0x20, 0x20, 0x70, // 1
    0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
    0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
    0x90, 0x90, 0xF0, 0x10, 0x10, // 4
    0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
    0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
    0xF0, 0x10, 0x20, 0x40, 0x40, // 7
    0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
    0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
    0xF0, 0x90, 0xF0, 0x90, 0x90, // A
    0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
    0xF0, 0x80, 0x80, 0x80, 0xF0, // C
    0xE0, 0x90, 0x90, 0x90, 0xE0, // D
    0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
    0xF0, 0x80, 0xF0, 0x80, 0x80  // F
};

// ------------------------------------------------------------------
// BEGIN STUDENT CODE (stage CHIP8-01)
// ------------------------------------------------------------------

// Reset the machine to its complete canonical power-on state.
//
// Required result (see STAGE.md "Hardware facts"):
//   memory      zeroed EXCEPT the 80 font bytes copied to 0x050..0x09F
//   V           all 16 registers zeroed
//   PC          0x0200 (program-entry convention)
//   I           0x0000
//   delay_timer 0        (sound/delay are part of power-on state!)
//   sound_timer 0
//   rng_state   CHIP8_RNG_SEED
//   stack       zeroed, SP = 0 (empty)
//   keypad      every key released
//   framebuffer every pixel dark
//
// It must recover this exact state even from arbitrarily dirty input.
void chip8_init(chip8 *m) {
    (void)m;    // silence unused-parameter while the body is yours to write
    (void)font; // TODO(CHIP8-01): implement the full deterministic reset.
}

// Challenge: deterministic FNV-1a 32-bit fingerprint over the complete
// Stage-01 Fingerprint Schema V1 state, in the exact byte order documented in
// STAGE.md. Every V1 field must be included — omitting even one register lets
// undetected bugs through.
//
// Return 0u until you implement it; tests then fail loudly instead of lying.
uint32_t chip8_state_checksum(const chip8 *m) {
    (void)m; // TODO(CHIP8-01 challenge): hash h = (h ^ b) * 16777619 ...
    return 0u;
}

// ------------------------------------------------------------------
// END STUDENT CODE (stage CHIP8-01)
// ------------------------------------------------------------------
