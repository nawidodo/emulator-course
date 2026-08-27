#include "chip8.h"
#include <string.h>

// Reset the machine to its power-on state (see STAGE.md hardware facts).
// Power-on: memory and V0..VF zeroed, I=0, timers 0, stack empty (SP=0),
// keys released, framebuffer cleared, PC=0x0200 (program-entry convention).
void chip8_init(chip8 *m) {
    // TODO(CHIP8-01): implement. Must handle dirty state.
    // Hint: memset for arrays, explicit assignment for scalars.
    (void)m;
}

// TODO(CHIP8-01 challenge): compute the FNV-1a checksum of the full
// machine state. The exact byte order is specified in STAGE.md.
uint32_t chip8_state_checksum(const chip8 *m) {
    (void)m;
    return 0; // TODO(CHIP8-01 challenge)
}
