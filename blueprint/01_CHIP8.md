# Console Blueprint 01 — CHIP-8 + Metal From Zero

## Purpose

Learn emulator fundamentals with the smallest useful machine, then learn Metal by displaying a known-correct emulator framebuffer.

## Prerequisites

- basic C syntax
- basic command line usage
- no emulator knowledge required
- no graphics knowledge required
- no Metal knowledge required

## Final Deliverable

A functional CHIP-8 emulator with:

- instruction execution
- timers
- keypad input
- 64×32 framebuffer
- reference renderer
- Metal renderer
- trace/debug mode
- save/load state
- compatibility with several legal test/homebrew ROMs

## Stages

### CHIP8-01 — Machine State
Implement registers, PC, I, stack, SP, timers, memory, keypad, framebuffer.

### CHIP8-02 — Memory and ROM Loading
Implement RAM layout, font data, ROM loading, bounds checks.

### CHIP8-03 — Fetch / Decode / Execute Loop
Implement 16-bit opcode fetch and basic dispatch structure.

### CHIP8-04 — Control and Immediate Instructions
Implement clear, jump, call, load immediate, add immediate, set I.

### CHIP8-05 — ALU
Implement register ALU instructions and flag behavior.

### CHIP8-06 — Conditional Flow
Implement skips, returns, indexed jumps.

### CHIP8-07 — Stack and Subroutines
Exercise stack limits and nested calls.

### CHIP8-08 — Timers
Implement delay/sound timers at 60 Hz independent of CPU instruction rate.

### CHIP8-09 — Input
Implement keypad state, wait-for-key, key skip instructions.

### CHIP8-10 — Graphics
Implement DXYN, XOR drawing, VF collision behavior, clipping/wrapping quirks.

### CHIP8-11 — Scheduler
Separate CPU stepping, timers, input, and display cadence.

### CHIP8-12 — ROM Compatibility
Use legal test ROMs and document quirks.

### CHIP8-13 — Debugger
Add CPU trace, register dump, step mode, memory inspection.

### CHIP8-14 — Save States
Serialize and restore full deterministic machine state.

## Metal Track

Begin only after CHIP8-10 produces correct graphical output using the reference path.

### MTL-00 — GPU Mental Model
CPU vs GPU, framebuffer, rasterization, asynchronous execution.

### MTL-01 — Metal Setup
Create a window, `MTLDevice`, command queue, drawable lifecycle.

### MTL-02 — First Triangle
Teach vertex stage, rasterization, fragment stage.

### MTL-03 — Buffers
Vertex buffers, resource lifetime, host/GPU memory concepts.

### MTL-04 — Textures
Texture creation, sampling, UV coordinates.

### MTL-05 — CHIP-8 Framebuffer Upload
Convert the 64×32 logical framebuffer into an `MTLTexture` and render a textured quad.

### MTL-06 — Pixel-Perfect Scaling
Nearest-neighbor filtering, integer scaling, aspect preservation, letterboxing.

### MTL-07 — Frame Synchronization
Avoid unnecessary stalls; understand CPU/GPU synchronization.

## Required Tests

- instruction-state tests
- stack boundary tests
- timer cadence tests
- keypad tests
- framebuffer pixel tests
- ROM regression tests
- save-state determinism
- reference renderer vs Metal framebuffer comparison where practical

## Challenges

- implement one opcode family from documentation with reduced guidance
- diagnose one intentionally broken carry/borrow case
- diagnose one sprite-wrap/clipping bug
- make the Metal renderer pixel-perfect at arbitrary window sizes

## Completion Gate

Do not proceed until:

```text
CPU tests                 PASS
graphics tests            PASS
timer/input tests         PASS
ROM tests                 PASS
debugger                  PASS
save states               PASS
Metal framebuffer         PASS
pixel-perfect scaling     PASS
final hidden challenge    PASS
```

## Knowledge Carried Forward

The next console may assume understanding of:

- machine state
- fetch/decode/execute
- registers and flags
- memory
- stack
- timers
- input
- framebuffer rendering
- basic Metal device/queue/buffer/texture/shader concepts
