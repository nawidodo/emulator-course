# Console Blueprint 02 — Intel 8080 + Space Invaders

## Purpose

Move from a tiny virtual machine to a real historical CPU with flags, interrupts, I/O ports, machine timing, and an actual arcade board.

## Prerequisite

CHIP-8 certification complete.

## New Concepts

- real CPU instruction set
- condition flags
- instruction cycle counts
- hardware interrupts
- I/O ports
- memory-mapped video RAM
- machine-specific peripherals

## Stages

1. 8080 register file and flags
2. memory model and reset state
3. fetch/decode infrastructure
4. MOV/MVI/LXI families
5. arithmetic instructions
6. flag correctness
7. branches/calls/returns
8. stack behavior
9. rotate/logical instructions
10. remaining data movement
11. interrupt mechanism
12. I/O instructions
13. diagnostic ROM runner
14. Space Invaders memory map
15. shift-register peripheral
16. input ports
17. video RAM conversion
18. frame/interrupt scheduling
19. sound event interface
20. playable Space Invaders-class board

## Metal Milestone

Render the monochrome video RAM through Metal.

Teach:

- texture format conversion
- texture orientation
- efficient repeated texture upload
- separating emulator framebuffer orientation from host presentation

## Challenges

- fix an intentionally broken auxiliary-carry case
- implement an undocumented/edge-case instruction family from CPU docs
- diagnose interrupt timing failure
- implement the Space Invaders shift-register peripheral from documentation

## Completion Gate

- diagnostic CPU tests pass
- interrupt tests pass
- I/O tests pass
- Space Invaders board timing is stable
- video output correct
- game is playable with legal/user-provided ROMs
- Metal display backend passes comparison tests
