# Console Blueprint 03 — Game Boy DMG

## Purpose

Learn cartridge mapping, interrupts, timers, a scanline-based PPU, tile graphics, sprites, and synchronization between CPU and video hardware.

## Prerequisite

8080 / Space Invaders certification complete.

## New Concepts

- LR35902-style CPU
- memory-mapped hardware registers
- boot process
- cartridge headers
- memory bank controllers
- timer edge behavior
- LCD modes
- tile maps
- OAM sprites
- scanline timing

## Stages

1. CPU register model
2. decoder skeleton
3. loads and addressing
4. ALU and flags
5. control flow
6. CB-prefixed operations
7. interrupts / IME behavior
8. memory bus
9. boot/cartridge mapping
10. cartridge headers
11. MBC1
12. timers
13. joypad
14. PPU timing modes
15. VRAM and tile decoding
16. background rendering
17. scrolling
18. window layer
19. sprite rendering
20. palette behavior
21. VBlank/STAT interaction
22. CPU/PPU scheduler
23. test ROM compatibility
24. debugger: tile/OAM/frame views
25. save RAM and save states

## Metal Track

Teach:

- palette lookup in shaders
- texture atlases
- uniforms/constants
- resource reuse
- synchronization without over-stalling

The CPU/reference PPU output remains the correctness source.

## Challenges

- diagnose LY/STAT timing bug
- implement MBC1 banking from documentation
- fix sprite priority behavior
- implement shader-based DMG palette conversion and compare against reference output

## Completion Gate

- CPU test ROMs pass to a strong level
- timer tests pass
- PPU timing tests pass
- MBC1 works
- representative homebrew/test ROMs run
- tile/OAM debugging works
- Metal output matches reference frames
