// Stage CHIP8-01 — visible tests: timer/sound machine state + determinism.
//
// Blueprint v1.2.0 makes delay_timer / sound_timer first-class machine
// state long before anything ticks them: pin their widths, independence,
// power-on silence, and that chip8_init alone restores them from chaos.
// These are the only tests besides machine_state you may read while working.

#include <limits.h>
#include <string.h>

#include "chip8/chip8.h"
#include "test.h"

// Timers are two INDEPENDENT single-byte registers (later decremented by one
// shared 60 Hz tick in stage 08 — so aliasing here would corrupt sound).
static void test_timer_registers_are_independent_bytes(void) {
    CHECK_EQ(sizeof(((chip8 *)0)->delay_timer), 1);
    CHECK_EQ(sizeof(((chip8 *)0)->sound_timer), 1);
}

// Full-range values stick, and lowering one never disturbs the other:
// the register files must be physically separate storage.
static void test_timers_hold_full_range_without_coupling(void) {
    chip8 m;
    memset(&m, 0, sizeof(m));

    m.delay_timer = UINT8_MAX;
    m.sound_timer = UINT8_MAX;
    CHECK_EQ(m.delay_timer, 255);
    CHECK_EQ(m.sound_timer, 255);

    m.delay_timer = 7;
    CHECK_EQ(m.delay_timer, 7);
    CHECK_EQ(m.sound_timer, 255); // untouched by the DT edit

    m.delay_timer = UINT8_MAX;
    m.sound_timer = 3;
    CHECK_EQ(m.delay_timer, 255); // and vice versa
    CHECK_EQ(m.sound_timer, 3);
}

// Power-on: machine is silent and input-empty — both timers 0 (gate OFF,
// pacing stopped), keypad fully released.
static void test_power_on_timer_and_keypad_silence(void) {
    chip8 m;
    chip8_init(&m);
    unsigned i;
    CHECK_EQ(m.delay_timer, 0);
    CHECK_EQ(m.sound_timer, 0);
    for (i = 0; i < 16; i++)
        CHECK_EQ(m.keypad[i], 0);
}

// Core restart property, timers edition (blueprint §19, no fingerprints
// needed — pure field checks): maximum-value dirty timers across MANY
// rounds must always come back to exact zero after chip8_init.
static void test_reset_restores_silence_from_max_dirty_rounds(void) {
    unsigned r;
    chip8 m;

    for (r = 0; r < 6; r++) {
        memset(&m, (int)(0xF0 + r), sizeof(m)); // different dirt each round
        m.delay_timer = UINT8_MAX;
        m.sound_timer = UINT8_MAX;
        m.keypad[r % 16] = 1;
        m.keypad[(r + 7) % 16] = 1;
        chip8_init(&m);
        CHECK_EQ(m.delay_timer, 0);
        CHECK_EQ(m.sound_timer, 0);
        CHECK_EQ(m.keypad[r % 16], 0);
        CHECK_EQ(m.keypad[(r + 7) % 16], 0);
    }
}

// Idempotence sentinels without any absolute answer constants: init twice
// from opposite extreme dirt patterns and both must land on the SAME
// canonical state (spot-checked across every subsystem).
static void test_double_init_from_opposite_dirt_agrees_everywhere(void) {
    chip8 ones, zeros;

    memset(&ones, 0xFF, sizeof(ones));
    chip8_init(&ones);
    chip8_init(&ones); // second call changes nothing further

    memset(&zeros, 0x00, sizeof(zeros));
    chip8_init(&zeros);

    CHECK_EQ(ones.PC, zeros.PC);
    CHECK_EQ(ones.I, zeros.I);
    CHECK_EQ(ones.SP, zeros.SP);
    CHECK_EQ(ones.delay_timer, zeros.delay_timer);
    CHECK_EQ(ones.sound_timer, zeros.sound_timer);
    CHECK_EQ(ones.V[0], zeros.V[0]);
    CHECK_EQ(ones.V[15], zeros.V[15]);
    CHECK_EQ(ones.stack[15], zeros.stack[15]);
    CHECK_EQ(ones.keypad[3], zeros.keypad[3]);
    CHECK_EQ(ones.framebuffer[31][63], zeros.framebuffer[31][63]);
    CHECK_EQ(ones.memory[0x000], zeros.memory[0x000]); // reserved zone zero
    CHECK_EQ(ones.memory[0x050], zeros.memory[0x050]); // font byte installed
    CHECK_EQ(ones.memory[0x09F], zeros.memory[0x09F]); // last font byte
    CHECK_EQ(ones.memory[0x200], zeros.memory[0x200]); // program area zero
}

int main(void) {
    RUN(test_timer_registers_are_independent_bytes);
    RUN(test_timers_hold_full_range_without_coupling);
    RUN(test_power_on_timer_and_keypad_silence);
    RUN(test_reset_restores_silence_from_max_dirty_rounds);
    RUN(test_double_init_from_opposite_dirt_agrees_everywhere);
    return summary("chip8/CHIP8-01/timers-sound-state");
}
