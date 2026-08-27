// Stage CHIP8-01 — challenge B: fingerprint mutation matrix.
//
// Proves the state model is COMPLETE and RESET RESTORES IT EXACTLY,
// using only relative comparisons: no absolute answer constants appear
// here, so you learn nothing by reading this file except the method.
//
// Method (blueprint v1.2.0 §19 property tests, adapted to stage 01):
//   baseline = fingerprint(init(machine))
//   for each probe: mutate exactly one piece of state
//       fingerprint(baseline minus mutation) != fingerprint(mutated)
//   then chip8_init back -> fingerprint equals baseline again.
//
// If ANY field is forgotten by chip8_init, some probe below catches it:
// mutating a never-reset field flips the fingerprint but the "restore"
// half of the pair then FAILS, because init did not bring it back.

#include <string.h>

#include "chip8/chip8.h"
#include "test.h"

typedef void (*probe_fn)(chip8 *m);

static void probe_index_register(chip8 *m)  { m->I = 0x05A3; }
static void probe_rng_state(chip8 *m)      { m->rng_state ^= 0x01020304u; }
static void probe_late_stack_entry(chip8 *m){ m->SP = 12; m->stack[11] = 0x02AA; }
static void probe_last_register(chip8 *m)   { m->V[15] = 0xC7; } // VF flag reg
static void probe_program_counter(chip8 *m) { m->PC = 0x02FA; }
static void probe_low_memory_byte(chip8 *m) { m->memory[0x0100] = 0x5A; }
static void probe_high_memory_byte(chip8 *m){ m->memory[0x0FEF] = 0xA5; }
static void probe_first_key(chip8 *m)       { m->keypad[0] = 1; }
static void probe_last_key(chip8 *m)        { m->keypad[15] = 1; }
static void probe_framebuffer_origin(chip8 *m){ m->framebuffer[0][0] = 1; }
static void probe_framebuffer_corner(chip8 *m){ m->framebuffer[31][63] = 1; }

// Timer probes: on the SOUND timer a nonzero register later means an audible
// gate — here it must simply move the fingerprint and then reset away.
static void probe_sound_timer(chip8 *m)     { m->sound_timer = 0xB4; }
static void probe_delay_timer(chip8 *m)     { m->delay_timer = 0x7D; }

static const probe_fn PROBES[] = {
    probe_index_register,
    probe_rng_state,
    probe_late_stack_entry,
    probe_last_register,
    probe_program_counter,
    probe_low_memory_byte,
    probe_high_memory_byte,
    probe_first_key,
    probe_last_key,
    probe_framebuffer_origin,
    probe_framebuffer_corner,
    probe_sound_timer,
    probe_delay_timer,
};
#define PROBE_COUNT (sizeof(PROBES) / sizeof(PROBES[0]))

static void test_every_probe_moves_the_fingerprint_and_resets_back(void) {
    size_t p;
    chip8 m;
    uint32_t baseline;

    chip8_init(&m);
    baseline = chip8_state_checksum(&m);

    for (p = 0; p < PROBE_COUNT; p++) {
        PROBES[p](&m);
        CHECK_NE(chip8_state_checksum(&m), baseline);
        chip8_init(&m);
        CHECK_EQ(chip8_state_checksum(&m), baseline);
    }
}

// Max-value dirtying in ONE shot: every byte becomes 0xFF including timers,
// stack, keypad bitmap; then reset must reproduce the pristine fingerprint.
static void test_full_dirty_then_restore_round_trip(void) {
    chip8 m;
    uint32_t baseline, dirty;

    chip8_init(&m);
    baseline = chip8_state_checksum(&m);

    memset(&m, 0xFF, sizeof(m));
    dirty = chip8_state_checksum(&m);
    CHECK_NE(dirty, baseline); // sanity: fingerprint really notices garbage

    chip8_init(&m);
    CHECK_EQ(chip8_state_checksum(&m), baseline);
}

int main(void) {
    RUN(test_every_probe_moves_the_fingerprint_and_resets_back);
    RUN(test_full_dirty_then_restore_round_trip);
    return summary("chip8/CHIP8-01/fingerprint-challenge");
}