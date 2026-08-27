// Stage CHIP8-02 — hidden certification: font + ROM loading

#include <stdio.h>
#include <string.h>
#include <stdint.h>

#include "chip8/chip8.h"
#include "test.h"

#define EXPECT_POWER_ON 0xA87B82ADu
#define EXPECT_HIDDEN 0x16472FBAu

static void make_hidden(chip8 *m) {
    chip8_init(m);
    uint8_t rom[4] = {0xDE, 0xAD, 0xBE, 0xEF};
    chip8_load_rom(m, rom, 4);
    m->V[0] = 0x42;
    m->I = 0x300;
    m->delay_timer = 0x20;
    m->sound_timer = 0x10;
    m->keypad[5] = 1;
    m->framebuffer[10][10] = 1;
}

static void test_power_on(void) {
    chip8 m;
    chip8_init(&m);
    CHECK_EQ(chip8_state_checksum(&m), EXPECT_POWER_ON);
}

static void test_hidden(void) {
    chip8 m;
    make_hidden(&m);
    CHECK_EQ(chip8_state_checksum(&m), EXPECT_HIDDEN);
}

static void test_rom_bounds_enforced(void) {
    chip8 m;
    chip8_init(&m);
    uint8_t big[3585];
    memset(big, 0xFF, sizeof(big));
    CHECK_EQ(chip8_load_rom(&m, big, 3585), 0);
    // memory should remain as after init (fonts only)
    CHECK_EQ(m.memory[0x200], 0);
    CHECK_EQ(m.memory[0x050], 0xF0);
}

int main(void) {
    RUN(test_power_on);
    RUN(test_hidden);
    RUN(test_rom_bounds_enforced);
    return summary("chip8/CHIP8-02/hidden-certification");
}
