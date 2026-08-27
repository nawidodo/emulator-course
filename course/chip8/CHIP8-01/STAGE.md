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
| V0..VF | 16 x 8-bit registers | 0x00 |
| PC | 16-bit address | 0x0200 |
| I | 16-bit address | 0x0000 |
| delay_timer | 8-bit | 0x00 |
| sound_timer | 8-bit | 0x00 |
| stack | 12 x 16-bit return addresses | empty |
| SP | 0..12 | 0 |
| keypad | 16 keys, 0x0-0xF | all released |
| framebuffer | 64 x 32 pixels, 1 bit per pixel (logical) | all 0 (black) |

Memory map (course VM convention; used from stage CHIP8-02 onward):

    0x000-0x1FF   reserved — interpreter / font region (font sprites
                  loaded by the emulator in stage 2; do not load programs here)
    0x200-0xFFF   program (ROM)

In this course `PC` resets to `0x200` by convention: it is the first
address of the program area, so a freshly loaded program always starts
there.

## Why these sizes

- 4 KiB of RAM was the entire address space of the original machine (the
  Cosmac VIP / Elf family). The 16-bit `PC` and `I` address it directly.
- The call stack is 12 levels deep for this course (original CHIP-8
  interpreters varied between 12 and 16; we fix 12 so every implementation
  is comparable and tests are deterministic). CHIP-8 programs are small and
  rarely nest deep.
- The logical framebuffer is 64*32 = 2048 bits = 256 bytes. That is
  256 / 4096 = 6.25% (1/16) of RAM, not a quarter — one bit per pixel,
  black and white. The starter code in `src/chip8/chip8.h` uses a
  teaching representation `uint8_t framebuffer[32][64]` (one byte per pixel,
  2048 bytes) so tests can address `framebuffer[y][x]` directly; do not
  confuse the two — the logical size is 256 bytes.
- The timers are 8-bit (0-255) and tick at 60 Hz, so the longest delay is
  about 4.2 seconds.

## Tasks

1. `src/chip8/chip8.h`
   Fill in the three sizes from the table above (stack depth, memory size,
   framebuffer rows x columns). The starter header already compiles; your
   job is to make the sizes match the spec so tests pass.

2. `src/chip8/chip8.c`
   Implement `chip8_init`. The skeleton with the full reset list is there.

3. `make test`
   All visible tests must pass.

4. Challenge (below). `make challenge` must pass.

5. `make submit` — certification.

## Debugging hints

- Sizes are in bytes: `printf("%zu\n", sizeof(m.stack));` — 12 entries of
  2 bytes each is 24, not 12.
- A test failure prints the failing expression, file, line, and
  expected-vs-actual values: map it back to a row of the hardware facts
  table.
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
    6.  for i in 0..11: stack[i] high byte, stack[i] low byte
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
