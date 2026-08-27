# Local Deviations from Installed Blueprints

This file records deliberate local policy choices that override specifics of
an installed console blueprint. Future agents generating or certifying stages
MUST apply these overrides alongside `blueprint/<console>.md`.

## Deviation D1 — CHIP-8 stack depth: 16 entries (overrides blueprint's 12)

**Applies to:** `blueprint/01_CHIP8.md` (v1.2.0), sections:
- §3 Historical Facts ("original COSMAC VIP CHIP-8 supported 12 stack entries")
- §6 Final Required Deliverable ("12-entry course stack model")
- §8 CHIP8-07 Required Course Stack Depth ("12 entries")

**Local policy:** This repository uses a **16-level call stack**
(`uint16_t stack[16]`, 8-bit `SP`, valid range `0..16`).

**Rationale:** Deliberately aligned to the widely-used Austin Morlan
CHIP-8 reference (austinmorlan.com/posts/chip8_emulator) and CaffeineViking's
spec so every learner implementation matches the classic tutorial limit.
Decided during CHIP8-01 (see commits `9e55e16`, `423e503`); the 16-level model
is locked in by certified material: `course/chip8/CHIP8-0{1,2}/STAGE.md`,
`tests/chip8/CHIP8-01/test_machine_state.c`, and both hidden certification
suites (`FNV-1a power-on constant 0xA87B82AD`).

**Consequences for future stage generation:**
- CHIP8-07 stack-boundary tests must use deepest-legal-nesting = 16,
  overflow attempt at SP == 16, underflow attempt at SP == 0.
- Any deterministic state checksum/save-state fingerprints must continue to
  serialize 16 stack entries in the established byte order
  (`course/chip8/CHIP8-01/STAGE.md`, challenge section).
- Everything else in blueprint v1.2.0 applies unmodified, including timer
  semantics, scheduler CPU-independence, host-independent sound gate, and the
  accuracy-model claims (Level A ≠ COSMAC VIP cycle accuracy).
