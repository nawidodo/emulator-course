// Stage CHIP8-01 — visible tests: power-on machine state.
//
// These are the only tests you may read while working.

#include <stdio.h>
#include <string.h>

#include "chip8/chip8.h"
#include "test.h"

static void test_size(void) {
    chip8 m;
    CHECK_EQ(sizeof(m.memory), 4096);   // 4 KiB of RAM
    CHECK_EQ(sizeof(m.V), 16);          // V0..VE
    CHECK_EQ(sizeof(m.framebuffer), 64 * 32); // 2048 one-bit pixels
    CHECK_EQ(sizeof(m.stack), 13 * 2);  // 13 return addresses, 16-bit each
}

static void test_power_on_state(void) {
    chip8 m;
    chip8_init(&m);
    unsigned i;
    for (i = 0; i < sizeof(m.memory); i++)
        CHECK_EQ(m.memory[i], 0);
    for (i = 0; i < 16; i++) {
        CHECK_EQ(m.V[i], 0);
        CHECK_EQ(m.keypad[i], 0);
    }
    CHECK_EQ(m.PC, 0x0200);
    CHECK_EQ(m.I, 0);
    CHECK_EQ(m.SP, 0);
    CHECK_EQ(m.delay_timer, 0);
    CHECK_EQ(m.sound_timer, 0);
    for (i = 0; i < 2048; i++)
        CHECK_EQ(m.framebuffer[i / 64][i % 64], 0);
}

static void test_reinit_clears_dirty_state(void) {
    chip8 m;
    chip8_init(&m);
    // dirtify every field
    memset(&m, 0xAB, sizeof(m));
    m.V[5] = 0x42;
    m.PC = 0x05AA;
    m.I = 0x00C0;
    m.SP = 7;
    m.stack[7] = 0x0555;
    m.delay_timer = 0x7F;
    m.sound_timer = 0x7F;
    m.keypad[9] = 1;
    m.framebuffer[0][0] = 1;
    chip8_init(&m);
    // back to power-on
    CHECK_EQ(m.V[5], 0);
    CHECK_EQ(m.PC, 0x0200);
    CHECK_EQ(m.I, 0);
    CHECK_EQ(m.SP, 0);
    CHECK_EQ(m.stack[7], 0);
    CHECK_EQ(m.delay_timer, 0);
    CHECK_EQ(m.sound_timer, 0);
    CHECK_EQ(m.keypad[9], 0);
    CHECK_EQ(m.framebuffer[0][0], 0);
    unsigned i;
    for (i = 0; i < sizeof(m.memory); i++)
        CHECK_EQ(m.memory[i], 0);
}

int main(void) {
    RUN(test_size);
    RUN(test_power_on_state);
    RUN(test_reinit_clears_dirty_state);
    return summary("chip8/CHIP8-01/machine-state");
}
