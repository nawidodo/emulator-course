// Stage CHIP8-01 — hidden certification tests: machine state.
//
// These run only at certification time (make submit). Do not read this
// file while working; the state definitions and constants are the
// answer key for the challenge.

#include <stdio.h>
#include <string.h>

#include "chip8/chip8.h"
#include "test.h"

// FNV-1a of the canonical power-on state (stack depth 12, with fonts).
#define EXPECT_INITIAL 0x3DF9EE0Du

// FNV-1a of a hidden state (with fonts):
//   memory[4095] = 0xFF
//   V[0] = 0x01
//   PC = 0x0200, I = 0, SP = 0, stack = 0
//   delay_timer = 0, sound_timer = 0x3C
//   keys released, framebuffer black
#define EXPECT_HIDDEN_STATE 0x7461E26Du

static void make_hidden_state(chip8 *m) {
    chip8_init(m);
    m->memory[4095] = 0xFF;
    m->V[0] = 0x01;
    m->sound_timer = 0x3C;
}

static void test_checksum_initial(void) {
    chip8 m;
    chip8_init(&m);
    CHECK_EQ(chip8_state_checksum(&m), EXPECT_INITIAL);
}

static void test_checksum_hidden_state(void) {
    chip8 m;
    make_hidden_state(&m);
    CHECK_EQ(chip8_state_checksum(&m), EXPECT_HIDDEN_STATE);
}

static void test_checksum_sensitivity(void) {
    // Any change to any field must change the checksum: flip one pixel.
    chip8 a, b;
    chip8_init(&a);
    b = a;
    b.framebuffer[31][63] = 1; // last pixel
    CHECK_NE(chip8_state_checksum(&a), chip8_state_checksum(&b));
    // and one bit of memory
    b = a;
    b.memory[0x100] = 0x80;
    CHECK_NE(chip8_state_checksum(&a), chip8_state_checksum(&b));
    // and the high byte of a stack entry
    b = a;
    b.SP = 1;
    b.stack[0] = 0x0200;
    CHECK_NE(chip8_state_checksum(&a), chip8_state_checksum(&b));
    // and a key press
    b = a;
    b.keypad[0] = 1;
    CHECK_NE(chip8_state_checksum(&a), chip8_state_checksum(&b));
}

static void test_reset_is_idempotent_and_deterministic(void) {
    chip8 a, b;
    chip8_init(&a);
    memset(&a, 0x5A, sizeof(a)); // dirtify completely
    chip8_init(&a);
    chip8_init(&b);
    CHECK_EQ(chip8_state_checksum(&a), chip8_state_checksum(&b));
}

int main(void) {
    RUN(test_checksum_initial);
    RUN(test_checksum_hidden_state);
    RUN(test_checksum_sensitivity);
    RUN(test_reset_is_idempotent_and_deterministic);
    return summary("chip8/CHIP8-01/hidden-certification");
}
