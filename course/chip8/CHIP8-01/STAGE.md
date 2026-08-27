# Stage CHIP8-01 — Machine State (restart edition, blueprint v1.2.0)

## Objective

Define the complete power-on state of the CHIP-8 and implement `chip8_init`
plus a deterministic `chip8_state_checksum`. After this stage you can explain
every field of the machine: what it is, how big it is, and what it holds at
power-on.

## Where instruction steps and sound live in this course

This stage owns the machine state that makes instruction scheduling and sound
behavior possible later. It deliberately implements neither:

```text
Stage 01          delay_timer and sound_timer exist as 8-bit machine state;
                  power-on values are deterministic; nothing ticks them yet.
Stage 03          instruction execution is introduced.
                  One chip8_step() executes one CHIP-8 instruction.
                  The course calls this an instruction step, not a hardware cycle.
                  Hardware/cycle timing is a separate concept covered by the
                  optional COSMAC VIP timing track.
Stage 08          chip8_tick_60hz() decrements BOTH timers once per virtual
                  tick, saturating at zero. Sound gate ON iff ST > 0.
Stage 11          accumulator scheduler derives instruction steps, 60 Hz
                  timer ticks and frame presents from injected virtual time,
                  independent of CPU rate and host refresh rate.
```

Two rules from blueprint v1.2.0 start mattering right now:

1. **Host time never enters the core.** No sleeps, no clock reads, ever.
   Tests inject values or compare states - instant and repeatable.
2. **The core is a bit box.** Keypad booleans in, logical framebuffer and a
   LOGICAL sound gate out. Speakers/windows/Metal come much later and live
   outside `src/chip8/`.

## Hardware facts

Treat this table as the spec. The code is filled in from it.

| Field | Size | Power-on value |
|---|---|---|
| RAM | 4096 bytes, addresses 0x000-0xFFF | 0x00 everywhere, except fonts (below) |
| V0..VF | 16 x 8-bit registers | 0x00 |
| PC | 16-bit address | 0x0200 |
| I | 16-bit address | 0x0000 |
| delay_timer | 8-bit | 0x00 |
| sound_timer | 8-bit | 0x00 |
| stack | 12 x 16-bit return addresses | empty (zeroed) |
| SP | 0..12 valid entries | 0 |
| keypad | 16 keys, 0x0-0xF | all released |
| framebuffer | 64 x 32 pixels, 1 bit/pixel (logical) | all 0 (black) |

Course memory-map convention:

```text
0x000-0x04F   reserved - never touched by the course VM
0x050-0x09F    80 B   font sprites (chars 0-F, 5 bytes each), installed
                     INTO MEMORY BY chip8_init as part of canonical power-on
0x0A0-0x1FF   reserved - interpreter region, programs never load here
0x200-0xFFF   program area (ROM lands here in stage CHIP8-02)
```

Font bytes are provided in `src/chip8/chip8.c`; installing them during reset
is your job. Fonts are part of the canonical power-on state, so the state
checksum covers them too.

## Why these sizes

- 4 KiB of RAM was the entire address space of the original machine family;
  16-bit `PC` and `I` address it directly.
- The call stack is **12 levels deep**, matching the historical COSMAC VIP
  baseline used by the blueprint. The default course profile uses
  `CHIP8_STACK_DEPTH = 12`; tests and later stack stages must use this value.
- The logical framebuffer is 64*32 = 2048 bits = 256 bytes — exactly 1/16 of
  RAM, never more than that share of it. The teaching representation
  `uint8_t framebuffer[32][64]` spends 2048 host bytes (one byte per pixel)
  so tests can index pixels directly; the logical truth is one bit per pixel.
- Timers are 8-bit (0-255) and will tick at 60 Hz, so the longest
  delay/beep is about 4.25 seconds of game time.

## Tasks

1. Read every comment in `src/chip8/chip8.h` — all declarations there are
   final course conventions; your stage makes their RUNTIME content real.
2. `src/chip8/chip8.c` — implement `chip8_init` from the Hardware facts plus
   the memory-map convention, then Challenge A below.
3. `make test` — visible tests (including the new timer/sound state suite)
   must pass.
4. Challenges A and B; `make challenge` must pass both.
5. `make submit` — certification.

## Challenge A — deterministic state checksum

Implement `chip8_state_checksum(const chip8 *m)` — FNV-1a 32-bit:

    h = 2166136261
    for each byte b, in the order below:
        h = (h ^ b) * 16777619      (all arithmetic wraps at 32 bits)

Byte order is exactly:

    1.  memory[0..4095]
    2.  V[0..15]
    3.  PC high byte, PC low byte
    4.  I high byte, I low byte
    5.  SP
    6.  for i in 0..11: stack[i] high byte, stack[i] low byte
    7.  delay_timer
    8.  sound_timer
    9.  keypad[0..15], each as 0x00 (released) or 0x01 (pressed)
    10. framebuffer: rows y = 0..31, within each row x = 0..63, each pixel
        as 0x00 (dark) or 0x01 (lit)

Note steps 7-9: timers and keypad are part of the machine's identity. Save
states, scheduler replays and sound-duration tests later rely on fingerprints
being sensitive to exactly these fields.

Implement from this spec — not by working backwards from test constants.

## Challenge B — mutation matrix

`tests/challenge/chip8/CHIP8-01/test_fingerprint.c` mutates one field at a
time (index register, late stack entry, VF flag register, PC, memory edges,
first/last key, framebuffer corners, and yes — both timers), demands each
mutation moves the fingerprint, then re-inits and demands an EXACT restore.
Forgetting any field lets one probe slip past its restore check. Implement
Challenge A completely and B passes for free — that is the point: B proves
the state model has no holes.

## Debugging hints

- Sizes are bytes: `printf("%zu\n", sizeof(m.stack));` prints 24 for
  12 entries x 2 bytes - the entry COUNT stays 12.
- A failing CHECK prints expression/file/line/expected-vs-actual: map it back
  to a Hardware-facts row.
- Checksum mismatch? Check field ORDER (bytes, not fields) and unsigned
  32-bit wraparound; never print the hash as signed while comparing.
- The visible timer/sound suite needs ONLY chip8_init: it checks state
  fields directly, never fingerprints. Fingerprints live in the challenges.

## Boundaries

- Do not read `tests/hidden/`.
- No `chip8_load_font`/`chip8_load_rom` work (stage CHIP8-02); no tick/step/
  audio function (stages 03/08/11).
- No wall-clock, sleep or random calls anywhere.
  `make verify-course` enforces the host-time portion of this boundary in
  core `.c`/`.h` files; it does not replace the learner's tests.

## Done when

    make test       → PASS (includes timers/sound state suite)
    make challenge  → PASS (both challenges)
    make submit     → CERTIFIED
