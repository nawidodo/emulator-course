// CHIP-8 machine core — pure C. No I/O, no Metal, no globals.
//
// Stage CHIP8-01 STARTER (v1.2.0 blueprint, restart edition).
//
// The CHIP-8 is a small virtual machine that originally ran on the Cosmac VIP
// microcomputer. Its entire state is small: 4 KiB of RAM, sixteen 8-bit
// general-purpose registers, a program counter, an index register, TWO
// 8-bit TIMERS (delay + sound) that will later be ticked at 60 Hz completely
// independently of CPU instruction rate, a 16-level call stack (course model,
// see blueprint/LOCAL_DEVIATIONS.md D1), a 16-key keypad, and a 64x32
// one-bit logical framebuffer.
//
// YOUR JOB this stage: define the complete, deterministic power-on state and
// a deterministic state checksum. Everything below marked TODO is yours.

#ifndef CHIP8_H
#define CHIP8_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef struct {
    // V0..VF: sixteen general-purpose 8-bit registers. VF doubles as a flag
    // register for several instructions later in the course.
    uint8_t V[16];

    // Program counter: address of the next 16-bit opcode to execute.
    // Power-on convention: programs begin at 0x0200.
    uint16_t PC;

    // Index register: memory address used by font/sprite instructions.
    uint16_t I;

    // Two INDEPENDENT 8-bit hardware timers. They will be decremented by an
    // external 60 Hz tick function in stage CHIP8-08 — never by host wall
    // clock, and never by the instruction step itself. Saturate at zero,
    // never underflow.
    //
    // delay_timer : general purpose countdown (game pacing).
    // sound_timer : while > 0 the logical sound gate is ON; reaching 0
    //               silences it. The core outputs only this LOGICAL gate
    //               state — real audio samples belong to the host backend
    //               in stage CHIP8-11.
    uint8_t delay_timer;
    uint8_t sound_timer;

    // Call stack: one 16-bit return address per nested call.
    // Course model: 16 entries (override of the blueprint's 12-entry model —
    // see blueprint/LOCAL_DEVIATIONS.md, D1). SP counts valid entries (0..16).
    uint16_t stack[16];
    uint8_t SP;

    // RAM: 4096 bytes, addresses 0x000-0xFFF.
    // Course model: 0x000-0x1FF reserved/interpreter area, with the 80-byte
    // font sprite table installed at 0x050-0x09F BY THE RESET ROUTINE;
    // 0x200-0xFFF program area. Programs load at 0x0200 (stage CHIP8-02).
    uint8_t memory[4096];

    // 16-key keypad, keys 0x0..0xF. true = key pressed.
    bool keypad[16];

    // Logical framebuffer: 64 px wide x 32 px tall, 1 bit per pixel LOGICALLY.
    // Teaching representation below stores ONE BYTE PER PIXEL, row-major,
    // top row first: framebuffer[y][x], y = 0..31, x = 0..63, 1 = lit pixel.
    // That costs 2048 host bytes although the logical framebuffer is only
    // 256 bytes (2048 bits) — deliberate convenience for readable tests,
    // documented here so the number never surprises you later.
    uint8_t framebuffer[32][64];
} chip8;

// Reset the machine to its power-on state. Must fully reinitialize every
// field from ANY dirty state: guest-visible result identical every time.
// Fonts are part of the canonical power-on state (installed at 0x050).
void chip8_init(chip8 *m);

// Deterministic 32-bit checksum over the full machine state. Byte order is
// specified in STAGE.md (challenge). Used by tests/graders as a fingerprint.
uint32_t chip8_state_checksum(const chip8 *m);

// ---- Stage CHIP8-02 interface (declared now, inert stubs until then) ----
void chip8_load_font(chip8 *m);
bool chip8_load_rom(chip8 *m, const uint8_t *data, size_t size);

#endif // CHIP8_H
