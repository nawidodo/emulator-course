# Console Blueprint 04 — NES

## Purpose

Learn tighter cycle relationships, a 6502-family CPU, PPU registers, scrolling, sprites, mapper architecture, and CPU/PPU synchronization.

## Prerequisite

Game Boy certification complete.

## New Concepts

- 6502 addressing modes
- page-crossing timing
- CPU/PPU clock ratio
- pattern tables
- nametables
- attribute tables
- sprite zero
- scrolling latches
- mapper abstraction

## Stages

1. CPU registers/status
2. addressing modes
3. load/store instructions
4. ALU and flags
5. branches and timing
6. stack/subroutines
7. interrupts
8. unofficial behavior policy
9. CPU bus
10. cartridge format
11. NROM / Mapper 0
12. PPU register interface
13. pattern tables
14. nametables/attributes
15. palette RAM
16. background pipeline
17. scrolling
18. OAM and sprites
19. sprite priority
20. sprite-zero hit
21. VBlank/NMI timing
22. CPU/PPU scheduler
23. controllers
24. APU architecture introduction
25. debugging and PPU viewer
26. ROM compatibility

## Metal Track

Teach:

- multiple texture resources
- render passes
- offscreen targets
- GPU frame capture
- render resource binding

Metal must not replace correct PPU timing.

## Challenges

- implement one addressing-mode family with reduced scaffolding
- debug sprite-zero timing
- implement palette lookup in a shader
- add a second mapper only after NROM completion

## Completion Gate

- CPU instruction/timing tests pass
- PPU register/timing tests pass
- NROM titles/homebrew work
- scrolling and sprites correct
- debugger exposes nametable/pattern/OAM state
- Metal output passes reference comparisons
