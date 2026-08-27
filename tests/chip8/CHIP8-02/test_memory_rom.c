// Stage CHIP8-02 — visible tests: font and ROM loading

#include <stdio.h>
#include <string.h>
#include <stdint.h>

#include "chip8/chip8.h"
#include "test.h"

static const uint8_t font[80] = {
    0xF0, 0x90, 0x90, 0x90, 0xF0, 0x20, 0x60, 0x20, 0x20, 0x70,
    0xF0, 0x10, 0xF0, 0x80, 0xF0, 0xF0, 0x10, 0xF0, 0x10, 0xF0,
    0x90, 0x90, 0xF0, 0x10, 0x10, 0xF0, 0x80, 0xF0, 0x10, 0xF0,
    0xF0, 0x80, 0xF0, 0x90, 0xF0, 0xF0, 0x10, 0x20, 0x40, 0x40,
    0xF0, 0x90, 0xF0, 0x90, 0xF0, 0xF0, 0x90, 0xF0, 0x10, 0xF0,
    0xF0, 0x90, 0xF0, 0x90, 0x90, 0xE0, 0x90, 0xE0, 0x90, 0xE0,
    0xF0, 0x80, 0x80, 0x80, 0xF0, 0xE0, 0x90, 0x90, 0x90, 0xE0,
    0xF0, 0x80, 0xF0, 0x80, 0xF0, 0xF0, 0x80, 0xF0, 0x80, 0x80
};

static void test_font_loaded_by_init(void) {
    chip8 m;
    chip8_init(&m);
    for (int i = 0; i < 80; i++) {
        CHECK_EQ(m.memory[0x050 + i], font[i]);
    }
    // font area outside should be zero
    CHECK_EQ(m.memory[0x04F], 0);
    CHECK_EQ(m.memory[0x0A0], 0);
}

static void test_load_font_idempotent(void) {
    chip8 m;
    chip8_init(&m);
    m.memory[0x200] = 0xAB;
    chip8_load_font(&m);
    CHECK_EQ(m.memory[0x200], 0xAB); // ROM area untouched
    for (int i = 0; i < 80; i++) CHECK_EQ(m.memory[0x050 + i], font[i]);
}

static void test_load_rom_success(void) {
    chip8 m;
    chip8_init(&m);
    uint8_t rom[3] = {0x12, 0x34, 0x56};
    bool ok = chip8_load_rom(&m, rom, 3);
    CHECK_EQ(ok, 1);
    CHECK_EQ(m.memory[0x200], 0x12);
    CHECK_EQ(m.memory[0x201], 0x34);
    CHECK_EQ(m.memory[0x202], 0x56);
    CHECK_EQ(m.memory[0x203], 0); // next byte still zero
    // font still intact
    CHECK_EQ(m.memory[0x050], 0xF0);
}

static void test_load_rom_bounds(void) {
    chip8 m;
    chip8_init(&m);
    uint8_t rom[4] = {0xAA, 0xBB, 0xCC, 0xDD};
    // null data
    CHECK_EQ(chip8_load_rom(&m, NULL, 3), 0);
    // zero size
    CHECK_EQ(chip8_load_rom(&m, rom, 0), 0);
    // exact fit: 3584 bytes at 0x200 -> 0xFFF inclusive
    uint8_t big[3584];
    memset(big, 0xAB, sizeof(big));
    chip8_init(&m);
    CHECK_EQ(chip8_load_rom(&m, big, 3584), 1);
    CHECK_EQ(m.memory[0xFFF], 0xAB);
    // overflow by one
    chip8_init(&m);
    CHECK_EQ(chip8_load_rom(&m, big, 3585), 0);
    CHECK_EQ(m.memory[0x200], 0);
    // failed load leaves machine unchanged
    m.memory[0x200] = 0x11;
    CHECK_EQ(chip8_load_rom(&m, NULL, 1), 0);
    CHECK_EQ(m.memory[0x200], 0x11);
}

int main(void) {
    RUN(test_font_loaded_by_init);
    RUN(test_load_font_idempotent);
    RUN(test_load_rom_success);
    RUN(test_load_rom_bounds);
    return summary("chip8/CHIP8-02/memory-rom");
}
