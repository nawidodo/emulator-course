# Master Blueprint — Emulator Engineering Course

## Mission

Teach emulator engineering from first principles by building complete working systems in increasing complexity.

The student must become capable of reading hardware documentation, implementing devices, building debuggers and tests, and reasoning about timing and rendering independently.

## Teaching Style

The course must behave like Codecrafters rather than a normal tutorial.

Each stage must contain:

- objective
- minimal theory
- starter code
- TODO-marked implementation points
- visible tests
- debugging hints
- a less-guided challenge
- local hidden/certification tests

The AI is an instructor, test author, debugger, and reviewer.

The AI must not eagerly generate the finished emulator.

## Local-Only Tooling

Preferred:

```text
C
Bash
Python
Make
```

Metal platform glue may use:

```text
Objective-C
Objective-C++
Metal Shading Language
```

Do not require Git, GitHub, remote CI, cloud services, databases, or web dashboards.

## Expected Commands

Prefer a consistent interface:

```bash
make start
make stage
make test
make challenge
make submit
make progress
make next
```

## Stage Rules

Authoring and learner progression are separate gates:

- Do not author stage N+1 until stage N course material is structurally
  validated and frozen.
- Only objective certification may unlock or activate the next stage for the
  learner.
- Future authored files do not grant learner access or count as certification.
- The agent must not generate later-stage learner solutions in advance.

Each stage should ideally focus on one new hardware idea.

## Hint Escalation

When the student is stuck:

1. explain the failing concept
2. identify the relevant subsystem
3. suggest an observation/debugging experiment
4. provide pseudocode
5. provide a small fragment
6. provide the full function only as a last resort

## Correctness Before Performance

Use:

```text
correct
  ↓
tested
  ↓
observable
  ↓
profiled
  ↓
optimized
```

## Emulator Architecture

Keep emulation and presentation separate.

```text
Machine
├── CPU
├── Bus / Memory
├── Timers
├── Interrupts
├── Input
├── Audio
└── Video Hardware
       ↓
Logical framebuffer / primitive stream
       ↓
Renderer backend
```

## Renderer Rule

For every machine with non-trivial graphics, keep a simple reference renderer whenever practical.

```text
same emulated state
   ├── reference CPU renderer
   └── Metal renderer
```

Use differential testing to compare them.

## Metal Rule

Assume zero Metal knowledge.

Teach Metal only when the student already has some correct graphical output to display.

The learning order is:

```text
GPU concept
Metal device / queue / command buffer
triangle
vertex + fragment shaders
buffers
textures
framebuffer upload
sampling / scaling
render passes
blending
synchronization
compute
profiling
advanced emulator GPU backends
```

Every Metal lesson should eventually solve an emulator problem.

## Debugging Requirements

Every emulator should gradually gain:

- CPU trace
- register dump
- memory dump
- breakpoints
- watchpoints where useful
- device trace
- framebuffer/VRAM inspection

Later machines should include specialized tools such as tile viewers, GPU command logs, texture viewers, and DMA traces.

## Testing Layers

Use:

- unit tests
- machine-state tests
- instruction tests
- trace tests
- timing tests
- ROM tests
- property tests
- differential tests
- framebuffer/image tests
- regression tests

## ROM Policy

Do not redistribute copyrighted commercial ROMs or proprietary firmware.

Use open-source test ROMs, homebrew, synthetic ROMs, or student-owned dumps where legally appropriate.

## Completion Gate

A console is complete only when:

- major CPU tests pass
- memory-map behavior passes
- interrupts/timers pass
- renderer output passes
- representative test/homebrew software works
- debugger/trace tooling exists
- regressions pass
- the console's required Metal milestone passes

## Guidance Reduction

Approximate guidance level:

```text
CHIP-8          80–90%
8080            70%
Game Boy        60%
NES             50%
GBA             40%
SNES            35%
PS1             25%
NDS             15%
```

The final goal is independent hardware research, not merely possession of emulator source code.
