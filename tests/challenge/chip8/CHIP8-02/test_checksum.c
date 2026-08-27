// Stage CHIP8-02 — challenge: font + ROM checksum

#include <stdio.h>
#include <string.h>
#include <stdint.h>

#include "chip8/chip8.h"
#include "test.h"

// FNV-1a of power-on with fonts (80 bytes at 0x050), using the 12-entry stack
#define EXPECT_POWER_ON 0x3DF9EE0Du

// FNV-1a after fonts + 3-byte ROM 0x12 0x34 0x56 at 0x200
#define EXPECT_WITH_ROM 0x18A88AD5u

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
