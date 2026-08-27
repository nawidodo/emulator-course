// Stage CHIP8-01 — challenge: deterministic state checksum.
//
// Implement chip8_state_checksum in src/chip8/chip8.c from the spec in
// STAGE.md (FNV-1a over the full machine state). This file only checks
// two states: a canonical power-on state and one modified state, with
// expected constants computed from the reference implementation.

#include <stdio.h>
#include <string.h>

#include "chip8/chip8.h"
#include "test.h"

// FNV-1a of the canonical power-on state (stack depth 16, per Austin Morlan, with fonts at 0x050):
// memory zeroed except font at 0x050, V = 0, PC = 0x0200, I = 0, SP = 0, stack = 0,
// timers = 0, keys released, framebuffer black.
#define EXPECT_POWER_ON 0xA87B82ADu

// FNV-1a of a modified state (with fonts):
//   memory[0x200] = 0x12
//   V[3] = 0x2A
//   PC = 0x0200
//   I = 0x0050
//   SP = 0, stack = 0
//   delay_timer = 0x7F, sound_timer = 0
//   keys released
//   framebuffer: pixel (10, 5) set, everything else 0
#define EXPECT_MODIFIED 0x90FC4373u

static void make_modified(chip8 *m) {
    chip8_init(m);
    m->memory[0x200] = 0x12;
    m->V[3] = 0x2A;
    m->I = 0x0050;
    m->delay_timer = 0x7F;
    m->framebuffer[5][10] = 1;
}

static void test_checksum_power_on(void) {
    chip8 m;
    chip8_init(&m);
    CHECK_EQ(chip8_state_checksum(&m), EXPECT_POWER_ON);
}

static void test_checksum_modified(void) {
    chip8 m;
    make_modified(&m);
    CHECK_EQ(chip8_state_checksum(&m), EXPECT_MODIFIED);
}

int main(void) {
    RUN(test_checksum_power_on);
    RUN(test_checksum_modified);
    return summary("chip8/CHIP8-01/checksum-challenge");
}
