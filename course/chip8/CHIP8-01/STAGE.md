# Stage CHIP8-01 — Machine State

## Objective

Define the complete power-on state of the CHIP-8 and implement
`chip8_init`. After this stage you can explain every field of the machine:
what it is, how big it is, and what it holds at power-on.

## Hardware facts

Treat this table as the spec. The code is filled in from it.

| Field | Size | Power-on value |
|---|---|---|
| RAM | 4096 bytes, addresses 0x000-0xFFF | 0x00 everywhere |
| V0..VE | 16 x 8-bit registers | 0x00 |
| PC | 16-bit address | 0x0200 |
| I | 16-bit address | 0x0000 |
| delay_timer | 8-bit | 0x00 |
| sound_timer | 8-bit | 0x00 |
| stack | 13 x 16-bit return addresses | empty |
| SP | 0..13 | 0 |
| keypad | 16 keys, 0x0-0xF | all released |
| framebuffer | 64 px wide x 32 px tall, 1 bit | all 0 (black) |

Memory map (used from stage CHIP8-02 onward):

    0x000-0x1FF   font sprites (loaded by the emulator; stage 2)
    0x200-0xFFF   program (ROM)

That is why PC resets to 0x0200: a freshly loaded program always starts at
the first byte of the program area.

## Why these sizes

- 4 KiB of RAM was the entire address space of the original machine (the
  Cosmac ELF). The 16-bit PC and I address it directly.
- The call stack is only 13 levels deep: CHIP-8 programs are small and
  rarely nest deep.
- The framebuffer is 64*32 = 2048 bits = 256 bytes, a quarter of the RAM.
  One bit per pixel: the display is black and white.
- The timers are 8-bit (0-255) and tick at 60 Hz, so the longest delay is
  about 4.2 seconds.

## Tasks

1. `src/chip8/chip8.h`
   The build currently fails at the `?` TODO markers. Fill in the three
   sizes from the table above (stack depth, memory size, framebuffer
   rows x columns).

2. `src/chip8/chip8.c`
   Implement `chip8_init`. The skeleton with the full reset list is there.

3. `make test`
   All visible tests must pass.

4. Challenge (below). `make challenge` must pass.

5. `make submit` — certification.

## Debugging hints

- A build failure points at the exact TODO line: read the first error
  message.
- Sizes are in bytes: `printf("%zu\n", sizeof(m.stack));` — 13 entries of
  2 bytes each is 26, not 13.
- A test failure prints the failing expression and the test name: map it
  back to a row of the hardware facts table.
- If the challenge checksum never matches, check two things: the field
  order (the spec lists bytes, not fields, in a specific sequence) and the
  32-bit wraparound (use unsigned 32-bit arithmetic; do not print as a
  signed integer while comparing).

## Challenge — deterministic state checksum

Implement `chip8_state_checksum(const chip8 *m)` in `src/chip8/chip8.c`
(prototype already in `chip8.h`).

Compute the FNV-1a 32-bit hash over the entire machine state:

    h = 2166136261
    for each byte b, in the order below:
        h = (h ^ b) * 16777619      (all arithmetic wraps at 32 bits)

The byte order is exactly:

    1.  memory[0..4095]
    2.  V[0..15]
    3.  PC high byte, PC low byte
    4.  I high byte, I low byte
    5.  SP
    6.  for i in 0..12: stack[i] high byte, stack[i] low byte
    7.  delay_timer
    8.  sound_timer
    9.  keypad[0..15], each as 0x00 (released) or 0x01 (pressed)
    10. framebuffer: rows y = 0..31, and within each row x = 0..63

Implement it from this spec — not by working backwards from the constants
in the test file. Verify with `make challenge`; the expected constants are
there so you can tell when you are right.

## Boundaries

- Do not read `tests/hidden/`. It runs only at certification time.
- Do not write stage CHIP8-02 code.

## Done when

    make test       → PASS
    make challenge  → PASS
    make submit     → CERTIFIED
