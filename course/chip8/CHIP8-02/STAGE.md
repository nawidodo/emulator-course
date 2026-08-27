# Stage CHIP8-02 — Memory and ROM Loading

## Objective

Make the memory map real: font sprites in the interpreter area and ROM bytes
in the program area. After this stage `chip8_init` leaves fonts intact and
you can load any ROM that fits in `0x200-0xFFF` with bounds checks.

## Hardware facts

The CHIP-8 address space is `0x000-0xFFF` (4096 bytes). Austin Morlan and
CaffeineViking (`chip-8/doc/specification.md`, based on Cowgod) agree:

```
0x000-0x1FF  512 B  reserved — interpreter (never written by programs)
0x050-0x0A0   80 B  font sprites, 16 chars × 5 bytes, stored by emulator at init
0x200-0xFFF 3584 B  program (ROM) — first instruction at 0x200
```

Font sprites (hex `0-F`), 5 bytes each, as used by `LD F, Vx`:

```
0xF0 0x90 0x90 0x90 0xF0  // 0
0x20 0x60 0x20 0x20 0x70  // 1
0xF0 0x10 0xF0 0x80 0xF0  // 2
0xF0 0x10 0xF0 0x10 0xF0  // 3
0x90 0x90 0xF0 0x10 0x10  // 4
0xF0 0x80 0xF0 0x10 0xF0  // 5
0xF0 0x80 0xF0 0x90 0xF0  // 6
0xF0 0x10 0x20 0x40 0x40  // 7
0xF0 0x90 0xF0 0x90 0xF0  // 8
0xF0 0x90 0xF0 0x10 0xF0  // 9
0xF0 0x90 0xF0 0x90 0x90  // A
0xE0 0x90 0xE0 0x90 0xE0  // B
0xF0 0x80 0x80 0x80 0xF0  // C
0xE0 0x90 0x90 0x90 0xE0  // D
0xF0 0x80 0xF0 0x80 0xF0  // E
0xF0 0x80 0xF0 0x80 0x80  // F
```

At offset `0x050 + c*5`.

`PC` still resets to `0x200`. `I`, `SP`, timers etc. unchanged from CHIP8-01
(16-level stack `stack[16]`, `SP 0..16`).

## API

Add to `src/chip8/chip8.h` (already declared, you implement):

```c
void chip8_load_font(chip8 *m);
bool chip8_load_rom(chip8 *m, const uint8_t *data, size_t size);
```

* `chip8_load_font` — copy the 80 font bytes above to `memory[0x050..0x09F]`. Must be idempotent and must not touch `memory[0x200..]` or registers.
* `chip8_load_rom` — copy `size` bytes from `data` to `memory[0x200..0x200+size-1]`. Return `false` and leave machine unchanged if `data==NULL`, `size==0`, or `0x200+size > 0x1000` (would overflow `0xFFF`). On success return `true`.

`chip8_init` must be updated to **call `chip8_load_font`** after clearing state so a fresh machine already has fonts. It must still zero `V`, `I`, `SP`, `stack`, timers, keypad, framebuffer and set `PC=0x200`.

## Tasks

1. `src/chip8/chip8.h` — add the two declarations above if missing (already stubbed).
2. `src/chip8/chip8.c` — implement `chip8_load_font`, `chip8_load_rom`, and update `chip8_init` to load fonts. Bounds checks must be exact.
3. `make test` — visible tests for font + ROM bounds must pass (also still checks CHIP8-01 state).
4. `make challenge` — deterministic memory checksum after font+ROM.
5. `make submit` — certification.

## Debugging hints

* `printf("%02X ", m.memory[0x050+i]);` — first 5 should be `F0 90 90 90 F0`.
* `chip8_load_rom` must not write past `0xFFF`: `if (size > 0xFFF - 0x200 + 1) return false;`
* `chip8_load_rom` with `size==0` or `NULL` is `false` — not a crash.
* If fonts disappear after `chip8_init`, you cleared memory *after* loading fonts (wrong order).

## Challenge — font + ROM checksum

`tests/challenge/...` loads fonts, then a 3-byte ROM `0x12 0x34 0x56` at `0x200` and checks `chip8_state_checksum` equals a golden constant (computed from the 16-level spec). Implement from spec, not by hardcoding the constant.

## Boundaries

* Do not read `tests/hidden/`.
* Do not write CHIP8-03 code.

## Done when

    make test       → PASS
    make challenge  → PASS
    make submit     → CERTIFIED
