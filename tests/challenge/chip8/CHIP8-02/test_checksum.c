// Stage CHIP8-02 — challenge: font + ROM checksum

#include <stdio.h>
#include <string.h>
#include <stdint.h>

#include "chip8/chip8.h"
#include "test.h"

// FNV-1a of power-on with fonts (80 bytes at 0x050)
#define EXPECT_POWER_ON 0xA87B82ADu

// FNV-1a after fonts + 3-byte ROM 0x12 0x34 0x56 at 0x200
#define EXPECT_WITH_ROM 0xB4F3F075u

static void test_power_on_with_font(void) {
    chip8 m;
    chip8_init(&m);
    CHECK_EQ(chip8_state_checksum(&m), EXPECT_POWER_ON);
}

static void test_with_rom(void) {
    chip8 m;
    chip8_init(&m);
    uint8_t rom[3] = {0x12, 0x34, 0x56};
    chip8_load_rom(&m, rom, 3);
    CHECK_EQ(chip8_state_checksum(&m), EXPECT_WITH_ROM);
}

int main(void) {
    RUN(test_power_on_with_font);
    RUN(test_with_rom);
    return summary("chip8/CHIP8-02/checksum-challenge");
}
