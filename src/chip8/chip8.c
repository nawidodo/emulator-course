#include "chip8.h"

// TODO(CHIP8-01): reset the machine to its power-on state:
//   - all memory zeroed
//   - V0..VE = 0, I = 0
//   - delay_timer = 0, sound_timer = 0
//   - stack empty: SP = 0
//   - all keys released
//   - framebuffer cleared
//   - PC = the program load address (see STAGE.md, memory map)
void chip8_init(chip8 *m) {
    (void)m; // TODO(CHIP8-01)
}

// TODO(CHIP8-01 challenge): compute the FNV-1a checksum of the full
// machine state. The exact byte order is specified in STAGE.md.
uint32_t chip8_state_checksum(const chip8 *m) {
    (void)m;
    return 0; // TODO(CHIP8-01 challenge)
}
