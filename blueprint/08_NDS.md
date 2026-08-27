# Console Blueprint 08 — Nintendo DS

## Purpose

Final advanced course covering two CPUs, shared hardware, IPC, VRAM mapping, 2D engines, a 3D engine, dual screens, and multi-processor scheduling.

## Prerequisite

PS1 certification complete.

## New Concepts

- ARM9 + ARM7 coordination
- shared memory
- IPC
- multi-processor event scheduling
- VRAM bank mapping
- multiple 2D engines
- hardware 3D pipeline
- dual displays

## Phases

### ARM9

1. ARM9 state and instruction differences
2. exception behavior
3. memory/control integration

### ARM7

4. ARM7 subsystem adaptation
5. device ownership

### Shared System

6. shared memory
7. IPC FIFO/sync
8. interrupts
9. timers
10. DMA
11. cartridge interface
12. input/touch abstraction
13. scheduler

### Video Memory

14. VRAM bank model
15. bank mapping rules
16. palette/OAM systems

### 2D Engines

17. engine A architecture
18. engine B architecture
19. tiled backgrounds
20. sprites
21. affine/extended backgrounds
22. windows/blending
23. display capture basics

### 3D Engine

24. command submission
25. vertex state
26. matrices
27. primitive assembly
28. clipping
29. texture sampling
30. depth
31. alpha/blending
32. viewport
33. integration with 2D output

### Audio / Remaining Devices

34. audio architecture
35. cartridge timing refinement
36. save hardware abstraction

## Metal Track

Teach and require practical use of:

- indexed geometry
- vertex transforms
- projection matrices
- depth buffers
- texture sampling
- multiple render targets where appropriate
- CPU/GPU synchronization
- profiling complex frame workloads

Maintain differential/reference paths for subsystems where feasible.

## Debugger Requirements

- independent ARM9/ARM7 traces
- scheduler/event trace
- IPC trace
- VRAM bank inspector
- 2D layer inspector
- 3D command stream inspector
- texture viewer

## Challenges

- implement an IPC behavior from documentation
- debug a scheduler race/order issue
- implement one VRAM mapping mode
- implement one 3D pipeline stage with minimal scaffolding

## Completion Gate

- ARM9/ARM7 tests pass
- IPC/shared-memory tests pass
- scheduler stable
- VRAM mappings work
- both 2D engines display correctly
- meaningful portion of 3D pipeline works
- Metal backend is validated against available references
- debugger tooling is sufficient to investigate multi-processor/video issues
