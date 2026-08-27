// CHIP-8 machine core — pure C. No I/O, no Metal, no globals.
// Stage CHIP8-01: machine state.
//
// The CHIP-8 is a small virtual machine that originally ran on the
// Cosmac VIP microcomputer. Its entire state is small: 4 KiB of RAM,
// sixteen 8-bit general-purpose registers V0..VF, a program counter, an
// index register, a 12-deep call stack, two 8-bit timers, a 16-key keypad,
// and a 64x32 one-bit logical framebuffer (stored as one byte per pixel
// in the teaching struct).

#ifndef CHIP8_H
#define CHIP8_H

#include <stdbool.h>
#include <stdint.h>

typedef struct {
    // V0..VF: sixteen general-purpose 8-bit registers.
    uint8_t V[16];

    // Program counter: address of the next 16-bit opcode to execute.
    // Power-on: 0x0200 (course VM program-entry convention — first byte of
    // the program area after the reserved 0x000-0x1FF region).
    uint16_t PC;

    // Index register: memory address used by font/sprite instructions.
    uint16_t I;

    // Timers: 8-bit, decremented once per tick (60 Hz), independent of
    // the CPU instruction rate. (wired up in stage CHIP8-08)
    uint8_t delay_timer;
    uint8_t sound_timer;

    // Call stack: one 16-bit return address per nested call.
    // Depth 12 for this course (see STAGE.md). SP is 0..12.
    uint16_t stack[12];

    // Stack pointer: number of valid entries currently on the stack.
    uint8_t SP;

    // RAM: 4096 bytes, addresses 0x000-0xFFF.
    // 0x000-0x1FF reserved/interpreter/font (font sprites loaded in stage 2);
    // 0x200-0xFFF program area. Programs load at 0x0200.
    uint8_t memory[4096];

    // 16-key keypad, keys 0x0..0xF. true = key pressed. (stage CHIP8-09)
    bool keypad[16];

    // Framebuffer: 64 px wide x 32 px tall, 1 bit logical (black/white).
    // Teaching representation is one byte per pixel so tests can use
    // framebuffer[y][x] directly (2048 bytes). Logical size is 256 bytes.
    // Row-major: framebuffer[y][x], y = 0..31 (top row first), x = 0..63.
    // 1 = lit pixel, 0 = dark. (drawn in stage CHIP8-10)
    uint8_t framebuffer[32][64];
} chip8;

// Reset the machine to its power-on state (reset values in STAGE.md).
// Must reinitialize completely from any dirty state.
void chip8_init(chip8 *m);

// Stage CHIP8-01 challenge: deterministic 32-bit checksum of the full
// machine state. The exact byte order is specified in STAGE.md.
uint32_t chip8_state_checksum(const chip8 *m);

#endif // CHIP8_H
