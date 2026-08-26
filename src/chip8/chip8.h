// CHIP-8 machine core — pure C. No I/O, no Metal, no globals.
// Stage CHIP8-01: machine state.
//
// The CHIP-8 is a small virtual machine that originally ran on the
// Cosmac ELF microcomputer. Its entire state is small: 4 KiB of RAM,
// sixteen 8-bit general-purpose registers, a program counter, an index
// register, a 13-deep call stack, two 8-bit timers, a 16-key keypad,
// and a 64x32 one-bit framebuffer.

#ifndef CHIP8_H
#define CHIP8_H

#include <stdbool.h>
#include <stdint.h>

typedef struct {
    // V0..VE: sixteen general-purpose 8-bit registers.
    uint8_t V[16];

    // Program counter: address of the next 16-bit opcode to execute.
    uint16_t PC;

    // Index register: memory address used by font/sprite instructions.
    uint16_t I;

    // Timers: 8-bit, decremented once per tick (60 Hz), independent of
    // the CPU instruction rate. (wired up in stage CHIP8-08)
    uint8_t delay_timer;
    uint8_t sound_timer;

    // Call stack: one 16-bit return address per nested call.
    // TODO(CHIP8-01): depth — see the hardware facts table in STAGE.md.
    uint16_t stack[12];

    // Stack pointer: number of valid entries currently on the stack.
    uint8_t SP;

    // RAM. Programs load at 0x0200; font sprites occupy 0x000-0x1FF
    // (loaded by the emulator in stage CHIP8-02).
    // TODO(CHIP8-01): size in bytes.
    uint8_t memory[0xfff];

    // 16-key keypad, keys 0x0..0xF. true = key pressed. (stage CHIP8-09)
    bool keypad[16];

    // One-bit framebuffer: 64 px wide x 32 px tall. Row-major:
    // framebuffer[y][x], y = 0..31 (top row first), x = 0..63.
    // 1 = lit pixel, 0 = dark. (drawn in stage CHIP8-10)
    // TODO(CHIP8-01): rows, then columns.
    uint8_t framebuffer[32][64];
} chip8;

// Reset the machine to its power-on state (reset values in STAGE.md).
// Must reinitialize completely from any dirty state.
void chip8_init(chip8 *m);

// Stage CHIP8-01 challenge: deterministic 32-bit checksum of the full
// machine state. The exact byte order is specified in STAGE.md.
uint32_t chip8_state_checksum(const chip8 *m);

#endif // CHIP8_H
