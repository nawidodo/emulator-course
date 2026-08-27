# Console Blueprint 05 — Game Boy Advance

## Purpose

Introduce ARM7TDMI, ARM/Thumb execution, DMA, a more capable 2D PPU, affine transforms, blending, and compute-shader use cases.

## Prerequisite

NES certification complete.

## New Concepts

- ARM register model
- ARM condition codes
- pipeline-visible PC behavior
- Thumb decoding
- exceptions
- BIOS/memory regions
- DMA
- affine backgrounds
- bitmap modes
- blending/windowing

## Stages

1. ARM register/state model
2. ARM decoder
3. data processing
4. shifts and condition flags
5. branches
6. load/store
7. multiply
8. exceptions
9. Thumb decoder
10. Thumb ALU/control
11. memory map
12. BIOS interactions
13. interrupts
14. timers
15. DMA
16. keypad
17. VRAM/palette/OAM
18. tiled backgrounds
19. sprites
20. bitmap modes
21. affine backgrounds
22. windows
23. alpha/brightness effects
24. scheduler
25. test ROMs
26. debugger

## Metal Track

Teach:

- hardware blending concepts
- intermediate targets
- compute shaders
- resource hazards and synchronization

Required compute exercise:

Convert an emulated pixel buffer into host RGBA using a Metal compute kernel and compare with a CPU implementation.

## Challenges

- implement a subset of Thumb from documentation
- debug DMA timing
- implement one affine background mode
- write the compute conversion kernel independently

## Completion Gate

- ARM/Thumb tests pass
- DMA/timer tests pass
- major video modes work
- representative homebrew/test ROMs run
- CPU and Metal conversion outputs match
