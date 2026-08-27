# Console Blueprint 06 — SNES

## Purpose

Learn a more complex bus, 65C816 concepts, DMA/HDMA, layered graphics, color math, Mode 7, and a separate audio subsystem.

## Prerequisite

GBA certification complete.

## New Concepts

- 65C816 execution modes
- richer memory mapping
- DMA and HDMA
- multiple background layers
- priority composition
- color math
- Mode 7 affine transform
- SPC700/APU architecture

## Stages

1. 65C816 state model
2. core addressing modes
3. instruction groups
4. emulation/native mode behavior
5. interrupts
6. bus and cartridge mapping
7. PPU register interface
8. VRAM/CGRAM/OAM
9. tile backgrounds
10. multiple BG layers
11. sprite system
12. priority composition
13. windows
14. color math
15. DMA
16. HDMA
17. Mode 7
18. frame scheduler
19. SPC700 introduction
20. audio command path
21. debugger and layer viewers
22. compatibility work

## Metal Track

Teach:

- layered composition
- 2D transforms
- matrix math
- batching
- render-target composition

Mode 7 is the formal introduction to affine matrix mathematics.

## Challenges

- implement a DMA mode from docs
- debug layer priority
- implement Mode 7 transform math
- reproduce CPU Mode 7 output with a Metal path

## Completion Gate

- CPU/bus tests pass
- DMA/HDMA behavior works
- major PPU modes work
- Mode 7 works
- debugger exposes layers/VRAM/OAM
- Metal rendering agrees with reference output
