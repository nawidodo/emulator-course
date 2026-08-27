# Console Blueprint 01 — CHIP-8 + Deterministic Timing + Sound + Metal

**Blueprint Version:** `v1.2.0`  
**Date:** 2026-08-27  
**Audience:** Human learner, course author, AI tutor, AI course-generation agent  
**Replaces:** earlier `blueprint/01_CHIP8.md`

---

# 0. Agent Directive

This document is the authoritative curriculum blueprint for the CHIP-8 portion of the emulator course.

When generating stages from this blueprint:

- generate **one stage at a time**
- do not implement future stages early
- do not solve learner-owned TODOs
- preserve the repository ownership rules
- preserve fail-closed certification
- keep emulator correctness separate from host presentation
- do not claim the main CHIP-8 implementation is COSMAC VIP cycle-accurate
- do not couple the CHIP-8 core to Metal, Cocoa, CoreAudio, AudioToolbox, or wall-clock APIs
- use deterministic tests rather than real sleeps
- keep timer, scheduler, audio-gate, renderer, and host-audio concerns separate
- only unlock the next stage after the current stage is objectively certified

The AI tutor is an instructor and reviewer.

It is not the certification authority.

```text
AI says "correct"
!=
course certification
```

Only grader success may certify a stage.

---

# 1. Purpose

Learn emulator engineering from the smallest useful virtual machine while establishing habits that scale to:

```text
8080
Game Boy
NES
GBA
SNES
PS1
NDS
```

The CHIP-8 curriculum must teach:

- explicit machine state
- memory mapping
- fetch/decode/execute
- instruction semantics
- flags
- stack behavior
- deterministic timing
- independent 60 Hz timers
- sound timer semantics
- host-independent sound gating
- input
- framebuffer rendering
- compatibility quirks
- deterministic scheduling
- debugging by trace
- save states
- reference-vs-host rendering
- basic Metal
- the distinction between interpreter accuracy and hardware cycle accuracy

CHIP-8 is used as a teaching VM.

It must not accidentally teach bad architecture that becomes painful on later consoles.

---

# 2. Accuracy Model

The curriculum has two explicit accuracy levels.

## Level A — Required Main Curriculum

The required CHIP-8 implementation is a deterministic high-level interpreter.

It must accurately implement:

```text
instruction semantics
machine state
60 Hz delay timer
60 Hz sound timer
sound activation duration
input semantics
display semantics
compatibility-profile quirks
deterministic scheduling
```

It must **not** claim:

```text
exact original CDP1802 execution timing
exact original COSMAC VIP instruction cycle timing
exact original analog oscillator frequency
```

The CPU instruction rate is a configurable host-side scheduling parameter.

It is not treated as a universal CHIP-8 hardware clock.

---

## Level B — Optional Advanced Accuracy Track

After the normal CHIP-8 curriculum is complete, an optional advanced stage may implement:

```text
CHIP8-ADV-01 — COSMAC VIP Timing
```

This stage studies the original interpreter running on the RCA CDP1802 and introduces:

- opcode-dependent interpreter timing
- display interrupt timing
- vertical blank interaction
- DXYN wait behavior
- sound-timer historical behavior
- original-interpreter timing tables
- HLE timing approximation vs full CDP1802 emulation

Only this advanced path may use terms such as:

```text
VIP timing-accurate
cycle-aware VIP compatibility
```

and even then the exact claim must match what was actually implemented.

If the implementation merely assigns measured timing costs to CHIP-8 opcodes, call it:

```text
HLE VIP-timing model
```

Do not call it:

```text
full COSMAC VIP emulation
```

unless an actual CDP1802 + VIP hardware model executes the original interpreter.

---

# 3. Historical Facts the Course Must Preserve

For the original CHIP-8 family baseline:

- 16 8-bit registers are `V0` through `VF`
- `VF` is used as a flag by multiple instructions
- original COSMAC VIP CHIP-8 supported 12 stack entries
- CHIP-8 programs conventionally begin at `0x200`
- the original interpreter occupied the low memory region
- delay and sound timers decrement at 60 Hz
- the original `DXYN` waited for the display interrupt / vertical blank period
- original COSMAC VIP sound hardware did not audibly respond to sound-timer value `1`

The course main profile does not need to reproduce every historical quirk from Stage 01.

Quirks should be introduced deliberately in the compatibility stage rather than hidden in unrelated code.

---

# 4. Core Architectural Rule

The emulator core must remain platform-independent.

Required conceptual architecture:

```text
                    ┌────────────────────┐
                    │      CHIP-8 VM     │
                    │                    │
                    │ CPU / registers    │
                    │ memory             │
                    │ timers             │
                    │ keypad             │
                    │ framebuffer        │
                    │ compatibility      │
                    └─────────┬──────────┘
                              │
          ┌───────────────────┼─────────────────────┐
          │                   │                     │
          ▼                   ▼                     ▼
   logical framebuffer   sound gate/event      trace/state
          │                   │                     │
          ▼                   ▼                     ▼
   reference renderer     host audio            debugger
          │                backend
          ▼
      Metal backend
```

Forbidden architecture:

```text
chip8_step()
    ├── calls Metal
    ├── sleeps
    ├── reads system clock
    ├── writes directly to speaker
    └── polls Cocoa events
```

The CHIP-8 core should be deterministic from explicit inputs.

---

# 5. Host Time Must Not Enter the Core

The core must not call:

```text
sleep()
usleep()
nanosleep()
mach_absolute_time()
CFAbsoluteTimeGetCurrent()
clock_gettime()
```

during instruction execution or timer semantics.

Instead the platform/scheduler layer owns elapsed time.

Example conceptual API:

```c
void chip8_step(chip8_t *vm);
void chip8_tick_60hz(chip8_t *vm);
bool chip8_sound_active(const chip8_t *vm);
```

A scheduler decides when these functions run.

This makes tests deterministic.

---

# 6. Final Required Deliverable

A completed required CHIP-8 course produces a functional emulator with:

- correct machine initialization
- safe ROM loading
- complete required CHIP-8 instruction execution
- 12-entry course stack model
- delay timer
- sound timer
- timer cadence at 60 Hz
- audible host beep
- host-independent sound gate
- keypad input
- 64×32 logical framebuffer
- reference renderer
- Metal renderer
- deterministic scheduler
- compatibility profiles / documented quirks
- trace/debug mode
- save/load state
- ROM regression tests
- scheduler tests using virtual time
- sound-duration tests
- reference-renderer vs Metal validation where practical

The normal course does not require full COSMAC VIP/CDP1802 cycle accuracy.

---

# 7. Recommended Machine-State Boundary

The deterministic CHIP-8 machine state includes at minimum:

```text
V0..VF
I
PC
stack
SP
delay timer
sound timer
memory
keypad state
framebuffer
wait-for-key state if modeled
compatibility/profile state if it changes execution semantics
```

Do not store transient host presentation state inside the VM.

Examples that are **not** machine state:

```text
MTLDevice
MTLTexture
window size
audio output device
audio sample position
host wall-clock timestamp
drawable
command queue
```

Scheduler accumulators should normally belong to the runtime/platform layer unless the course explicitly chooses to serialize them as emulator-runtime state.

The save-state stage must clearly distinguish:

```text
machine state
vs
host runtime state
```

---

# 8. Stage Sequence

---

## CHIP8-01 — Machine State

### Goal

Model the VM before executing instructions.

### Learner Implements

- `V0..VF`
- `I`
- `PC`
- stack
- `SP`
- delay timer
- sound timer
- memory
- keypad
- framebuffer
- deterministic reset/initialization

### Required Course Conventions

- 16 registers: `V0..VF`
- stack depth: `12`
- program-entry convention: `PC = 0x200`
- `0x000–0x1FF`: reserved/interpreter/font area in the course model
- `0x200+`: program area
- logical framebuffer: `64 × 32 × 1 bit`
- teaching representation may use one byte per pixel

If using:

```c
uint8_t framebuffer[32][64];
```

documentation must explicitly state that it consumes 2048 host bytes even though the logical framebuffer is 256 bytes.

### Required Tests

- clean initialization
- dirty-state reset
- exact register count
- exact stack depth
- exact RAM size
- exact framebuffer dimensions
- initial timer values
- initial keypad state
- deterministic state fingerprint/challenge where already defined

### Timing

No scheduling yet.

Do not add wall-clock code.

---

## CHIP8-02 — Memory and ROM Loading

### Goal

Learn memory ownership, bounds, fonts, and safe external input.

### Learner Implements

- RAM layout
- selected font location
- font loading
- ROM loading
- bounds checking
- maximum ROM size handling
- reset-before-load semantics

### Required Tests

- empty ROM
- valid ROM
- maximum legal ROM
- oversized ROM rejected
- program copied to correct address
- reserved region preserved
- font data preserved
- repeated load deterministic

### Agent Rule

Do not introduce opcode execution yet.

---

## CHIP8-03 — Fetch / Decode / Execute Skeleton

### Goal

Build the instruction pipeline without prematurely implementing all semantics.

### Learner Implements

- 16-bit opcode fetch
- big-endian opcode construction
- `PC` advancement model
- decode structure
- invalid/unsupported opcode handling
- one-step API

### Required Design

`chip8_step()` executes exactly one CHIP-8 instruction.

It must not:

- sleep
- tick 60 Hz timers automatically
- render
- poll input
- generate audio samples
- use host time

### Required Tests

- opcode fetch
- correct byte order
- PC progression
- dispatch family selection
- invalid opcode behavior
- one step means one instruction

---

## CHIP8-04 — Control and Immediate Instructions

### Goal

Implement first real instruction families.

### Representative Instructions

- `00E0`
- `1NNN`
- `2NNN`
- `6XNN`
- `7XNN`
- `ANNN`

Only include instructions appropriate to the stage's intended progression.

### Required Tests

- exact before/after machine state
- PC semantics
- jump behavior
- immediate register writes
- `I` load
- screen clear behavior if introduced here

Do not test timing in wall-clock seconds.

---

## CHIP8-05 — ALU

### Goal

Learn arithmetic, bitwise logic, flags, and compatibility-sensitive behavior.

### Learner Implements

Relevant `8XY*` operations.

### Required Tests

- carry
- no carry
- borrow
- no borrow
- equality edge cases
- shift behavior
- `VF` behavior
- source/destination aliasing cases such as `X == Y`

### Compatibility Preparation

Shift semantics differ across CHIP-8 variants.

The implementation should be architected so Stage 12 can select quirk behavior without rewriting the CPU.

Do not silently bake undocumented variant assumptions into tests.

---

## CHIP8-06 — Conditional Flow and Indexed Behavior

### Goal

Implement skips and remaining basic flow behavior.

### Required Tests

Include both taken and not-taken paths.

Test PC changes explicitly.

Compatibility-sensitive indexed-jump behavior should be documented and deferred/configurable where needed.

---

## CHIP8-07 — Stack and Subroutines

### Goal

Understand bounded guest stacks and nested control flow.

### Required Course Stack Depth

```text
12 entries
```

### Required Tests

- first call
- nested calls
- return order
- deepest legal nesting
- overflow attempt
- underflow attempt

Do not allow host memory corruption when guest stack limits are exceeded.

The course must define deterministic error behavior.

---

## CHIP8-08 — Timers and Sound Semantics

### Goal

Teach timer hardware semantics separately from CPU instruction rate and host audio playback.

This stage is mandatory.

### Learner Implements

- `FX07`
- `FX15`
- `FX18`
- delay-timer decrement
- sound-timer decrement
- 60 Hz timer tick function
- sound-active query/gate

### Required Core API Shape

Exact names may differ, but the architectural separation should resemble:

```c
void chip8_tick_60hz(chip8_t *vm);
bool chip8_sound_active(const chip8_t *vm);
```

### Required Timer Semantics

On one 60 Hz tick:

```text
if delay_timer > 0:
    delay_timer -= 1

if sound_timer > 0:
    sound_timer -= 1
```

Timers saturate at zero.

They must not underflow.

### Required Independence

Timer decrement frequency must not depend on how many CPU instructions execute.

These must all produce exactly 60 timer ticks during one simulated second:

```text
CPU target = 500 instructions/sec
CPU target = 700 instructions/sec
CPU target = 1000 instructions/sec
```

### Required Sound Semantics — Main Profile

For the normal course profile:

```text
sound_timer > 0
→ sound gate active
```

```text
sound_timer == 0
→ sound gate inactive
```

The CHIP-8 core outputs only the logical sound state.

It does not generate speaker samples.

### Historical Compatibility Note

Original COSMAC VIP hardware did not audibly respond to a timer value of `1`.

Do not force this quirk into the beginner main profile.

Record it for Stage 12 / `CHIP8-ADV-01`.

### Required Tests

- `DT = 0` remains zero
- `DT = 1` becomes zero after one tick
- `DT = 255` decrements correctly
- `ST = 0` means inactive
- `ST > 0` means active in main profile
- `ST` reaches zero and sound gate turns off
- `FX18` overwrites any existing sound-timer value
- repeated 60 Hz ticks are deterministic
- exactly 60 ticks per simulated second
- no real sleeping in tests

### Example Deterministic Test

```text
ST = 3

initial:
ST = 3
sound = ON

tick:
ST = 2
sound = ON

tick:
ST = 1
sound = ON

tick:
ST = 0
sound = OFF
```

---

## CHIP8-09 — Input

### Goal

Implement deterministic keypad semantics.

### Learner Implements

- key state
- skip-if-key
- skip-if-not-key
- wait-for-key

### Required Tests

- press
- release
- multiple keys
- invalid host mapping ignored safely
- wait-for-key blocks guest instruction completion according to the chosen model
- input state itself remains independent of host UI framework

### Historical Note

Original VIP input behavior interacted with sound/debounce logic.

That historical behavior is not mandatory for the main compatibility profile.

It belongs in the advanced historical track if implemented.

---

## CHIP8-10 — Graphics

### Goal

Implement deterministic logical graphics before Metal.

### Learner Implements

- `DXYN`
- XOR sprite drawing
- collision flag
- edge behavior
- display clear if not already completed

### Required Reference Path

The course must provide a CPU/reference path whose correctness can be tested without Metal.

### Required Tests

- single sprite
- collision
- draw twice restores pixels under XOR
- exact pixel locations
- right edge
- bottom edge
- clipping/wrapping behavior according to selected profile
- zero/empty sprite edge cases

### Compatibility Requirement

Graphics behavior must support documented variant configuration.

At minimum prepare for:

```text
clip vs wrap
DXYN vertical-blank wait
```

Do not make Metal the correctness oracle.

---

## CHIP8-11 — Deterministic Scheduler and Host Audio

### Goal

Combine independent emulator domains without losing determinism.

This stage is mandatory and is the main timing architecture lesson.

### Scheduler Domains

Conceptually:

```text
                 elapsed host time
                        │
        ┌───────────────┼────────────────┐
        ▼               ▼                ▼
 CPU accumulator   timer accumulator   display accumulator
        │               │                │
        ▼               ▼                ▼
 chip8_step()      tick_60hz()       present frame
 configurable         exactly 60 Hz       target cadence
```

Input event collection may run in the platform loop but guest key state must remain explicit.

### CPU Rate

The main HLE interpreter uses a configurable CPU instruction target.

Example default:

```text
700 instructions/second
```

The exact default is a course/runtime policy, not a statement that all historical CHIP-8 hardware ran at exactly 700 CHIP-8 opcodes per second.

The value must be configurable.

### Required Scheduler Property

Over simulated time, event counts must be derived from accumulated virtual elapsed time.

Do not use:

```text
if now - last >= interval:
    do one tick only
```

if doing so loses accumulated events after a delayed frame.

The scheduler must handle catch-up deterministically, with an explicit safety cap if desired.

### Recommended Arithmetic

Use either:

- integer nanoseconds, or
- rational/integer accumulators

Avoid relying on repeated floating-point equality checks.

### No Real-Time Unit Tests

Tests should inject elapsed time:

```text
advance(1 second)
```

rather than sleeping for one second.

### Required Scheduler Tests

For simulated 1 second:

```text
timer ticks = 60
```

regardless of CPU target.

Examples:

```text
CPU 500 Hz  → 500 CPU steps + 60 timer ticks
CPU 700 Hz  → 700 CPU steps + 60 timer ticks
CPU 1000 Hz →1000 CPU steps + 60 timer ticks
```

Allow only explicitly documented scheduler boundary conventions if exact step count at time zero creates an off-by-one policy.

Tests and docs must use one consistent convention.

### Long-Run Drift Tests

Simulate at least:

```text
10 seconds
60 seconds
```

and verify the timer count does not drift.

### Host Audio Architecture

The logical sound gate from the VM drives a host audio backend:

```text
sound_timer
     ↓
chip8_sound_active()
     ↓
audio gate
     ↓
oscillator
     ↓
host audio API
```

### Required Audible Output

By the end of this stage, the emulator must produce an audible tone while the main-profile sound gate is active.

### Host Audio Constraints

- no external audio dependency required
- prefer a native macOS C-compatible API such as AudioToolbox/CoreAudio
- host audio code lives outside the CHIP-8 VM core
- turning sound off must not require destroying/recreating the entire audio subsystem each timer tick
- audio callback must not mutate CHIP-8 guest state
- audio thread synchronization must be explicit and minimal

### Tone Choice

The main curriculum may use a simple fixed-frequency tone, for example:

```text
440 Hz square wave
```

The exact host frequency/waveform is a presentation decision.

Do not describe it as an exact CHIP-8 hardware requirement.

### Required Audio Tests

Core tests:

- correct sound gate duration
- gate on/off transition
- `FX18 = 0` stops logical sound
- overwrite of active `ST`
- no underflow

Host-audio tests:

- oscillator produces non-zero samples when enabled
- oscillator produces silence when disabled
- deterministic offline sample-generation test where practical

Do not require microphone/speaker capture in certification.

---

## CHIP8-12 — ROM Compatibility and Quirk Profiles

### Goal

Teach that "CHIP-8" is a family of interpreter behaviors, not one perfectly uniform specification.

### Learner Implements

A small explicit compatibility/profile structure.

Possible quirk flags include:

```text
shift source behavior
FX55/FX65 I behavior
BNNN behavior
sprite clipping/wrapping
DXYN vblank behavior
sound ST=1 historical behavior
```

Only add flags that are supported by documented evidence and relevant ROMs.

Avoid a giant speculative flag system.

### Required Profiles

At minimum define a course default profile.

Optionally add:

```text
COSMAC_VIP
MODERN
```

if enough behavior has been implemented and tested.

### Sound Compatibility

For an original VIP-oriented profile, support/document:

```text
ST = 1
→ timer logically nonzero
→ original physical speaker may not produce an audible response
```

This quirk belongs in compatibility/presentation policy, not in generic timer decrement logic.

### Graphics Compatibility

Original VIP `DXYN` waits for vertical blank before drawing.

If the course profile models this, test the scheduling-visible behavior explicitly.

### Required ROM Testing

Use only legal/public test ROMs and homebrew ROMs appropriate for redistribution/use.

Record:

```text
ROM
profile
expected result
actual result
```

Do not accept "looks okay" as certification.

---

## CHIP8-13 — Debugger and Trace

### Goal

Teach emulator debugging techniques that scale to real consoles.

### Learner Implements

- instruction trace
- PC
- opcode
- register dump/delta
- `I`
- `SP`
- timer state where useful
- step mode
- memory inspection

### Recommended Trace Shape

```text
PC=0200 OP=6105 V1:00->05
PC=0202 OP=6207 V2:00->07
...
```

### Timing Trace

Include optional scheduler events such as:

```text
TIMER_TICK DT:03->02 ST:02->01
SOUND ON
SOUND OFF
```

Do not mix host wall-clock timestamps into golden deterministic traces unless explicitly normalized.

### Required Tests

Golden trace comparisons should be deterministic.

---

## CHIP8-14 — Save States and Determinism

### Goal

Serialize full guest machine state and prove deterministic restoration.

### Required Behavior

```text
save
→ execute/mutate
→ load
→ exact guest state restored
```

### Required Tests

- round-trip
- dirty state
- framebuffer
- keypad
- timers
- stack
- memory
- compatibility-profile state if execution semantics depend on it
- deterministic state fingerprint

### Sound Restore Rule

Restoring `sound_timer` restores the logical sound state.

The host audio backend must react to the restored gate.

Do not serialize:

```text
audio device handle
Metal objects
window
host clock timestamps
```

---

# 9. Metal Track

Begin only after CHIP8-10 produces known-correct logical framebuffer output through the reference path.

There are **8 Metal stages**, `MTL-00` through `MTL-07`.

---

## MTL-00 — GPU Mental Model

Teach:

- CPU vs GPU
- framebuffer
- command submission
- rasterization
- asynchronous execution
- resource ownership

---

## MTL-01 — Metal Setup

Create:

- window
- `MTLDevice`
- command queue
- drawable lifecycle

Do not move emulator state into Metal objects.

---

## MTL-02 — First Triangle

Teach:

- vertex stage
- rasterization
- fragment stage

This is a graphics learning stage, not emulator functionality.

---

## MTL-03 — Buffers

Teach:

- vertex buffers
- resource lifetime
- CPU/GPU memory concepts
- synchronization basics

---

## MTL-04 — Textures

Teach:

- texture creation
- pixel format
- sampling
- UV coordinates
- nearest vs linear filtering

---

## MTL-05 — CHIP-8 Framebuffer Upload

Convert the logical 64×32 framebuffer to a host texture representation.

Recommended validation flow:

```text
CHIP-8 reference framebuffer
        ↓
known CPU image
        ↓
Metal upload
        ↓
offscreen texture / drawable
```

Do not change CHIP-8 graphics semantics to make Metal easier.

---

## MTL-06 — Pixel-Perfect Scaling

Teach:

- nearest-neighbor filtering
- integer scaling
- aspect preservation
- letterboxing
- Retina-aware drawable sizing

---

## MTL-07 — Frame Synchronization

Teach:

- CPU/GPU synchronization
- drawable pacing
- avoiding unnecessary stalls
- frame presentation vs guest timer cadence

Critical rule:

```text
display refresh rate
!=
CHIP-8 timer rate
```

A 120 Hz host display must not cause 120 CHIP-8 timer ticks per second.

---

# 10. Required Timing Tests

The final required CHIP-8 curriculum must contain deterministic timing tests.

At minimum:

## Timer Unit Tests

```text
DT decrements at 60 Hz
ST decrements at 60 Hz
timers stop at zero
```

## CPU Independence

One simulated second:

```text
500 CPU Hz:
60 timer ticks

700 CPU Hz:
60 timer ticks

1000 CPU Hz:
60 timer ticks
```

## Long-Run Stability

Simulated:

```text
10 sec
60 sec
```

must not accumulate timer drift beyond the scheduler's explicitly defined integer boundary model.

## Catch-Up

If the host loop reports a large elapsed interval, required timer events must not simply disappear.

Example:

```text
elapsed = 50 ms
```

corresponds to approximately three 60 Hz intervals.

The scheduler must process the appropriate number according to its accumulator arithmetic.

## Host Refresh Independence

Changing presentation cadence:

```text
30 Hz
60 Hz
120 Hz
```

must not change the number of guest timer ticks over the same simulated duration.

---

# 11. Required Sound Tests

The final required CHIP-8 course must certify both guest sound semantics and host presentation architecture.

## Guest/Core

Test:

- `FX18`
- `ST = 0`
- `ST = 1`
- `ST = 2`
- `ST = 255`
- overwrite while active
- timer saturation at zero
- gate transitions
- save/load interaction

## Scheduler

Verify sound duration is driven by 60 Hz timer ticks rather than CPU steps.

Example:

```text
ST = 60
```

must represent approximately one second of logical sound under the main course model, independent of whether CPU target is:

```text
500
700
1000
```

instructions/sec.

## Host Audio

At least one offline/unit-testable oscillator or sample-generator test should prove:

```text
enabled → non-silent samples
disabled → silent samples
```

Certification should not depend on recording the physical speaker.

---

# 12. Required Instruction Tests

The final curriculum must include:

- instruction-state tests
- PC behavior
- register behavior
- `I`
- `VF`
- boundary values
- aliasing cases
- stack boundary tests
- invalid opcode behavior
- profile-specific quirk tests

For compatibility-sensitive opcodes, tests must state which profile they target.

---

# 13. Required Graphics Tests

Include:

- framebuffer clear
- basic sprite
- XOR
- collision
- repeated draw
- clipping
- wrapping where profile requires it
- vblank behavior where profile requires it
- reference-renderer output

Metal comparison should use deterministic offscreen/readback validation where practical rather than screenshots from a composited desktop window.

---

# 14. Optional Advanced Stage

## CHIP8-ADV-01 — COSMAC VIP Timing and Historical Behavior

This stage is optional but strongly recommended before moving into timing-sensitive consoles if the learner wants deeper emulator accuracy training.

### Purpose

Demonstrate why:

```text
one guest instruction
!=
one constant amount of real hardware time
```

### Study Topics

- CHIP-8 as an interpreter running on CDP1802
- interpreter fetch/decode overhead
- opcode-dependent underlying machine cycles
- 60 Hz interrupt
- display refresh/DMA implications
- `DXYN` vertical-blank waiting
- sound timer and Q output
- original `ST=1` physical-speaker quirk
- key-input historical interaction
- distinction between HLE and full-system emulation

### Implementation Choices

#### Option A — HLE VIP-Timing Model

Keep the high-level CHIP-8 interpreter but attach historically derived timing costs.

Call this:

```text
HLE VIP-timing model
```

Do not call it a full VIP emulator.

#### Option B — Full Historical Path

Implement or reuse the learner's later knowledge to build:

```text
CDP1802
+
COSMAC VIP hardware
+
original CHIP-8 interpreter
```

This is a separate machine-emulation project and may be deferred.

### Required Tests

If Option A is implemented:

- opcode-specific timing vectors
- 60 Hz interrupt interaction
- DXYN wait timing
- timer timing under variable opcodes
- historical sound behavior
- trace comparison against documented/reference behavior

---

# 15. Scheduler Design Rules for the AI Agent

When generating CHIP8-11, the AI must not teach an inaccurate frame-coupled loop such as:

```c
while (running) {
    chip8_step(&vm);
    if (frame_ready) {
        tick_timers(&vm);
        render(&vm);
    }
}
```

if `frame_ready` is simply host-vsync driven.

Instead teach independent rate domains.

Acceptable conceptual structure:

```c
while (running) {
    elapsed = host_elapsed_time();

    cpu_accumulator += elapsed;
    timer_accumulator += elapsed;
    display_accumulator += elapsed;

    while (cpu_accumulator >= cpu_period) {
        chip8_step(&vm);
        cpu_accumulator -= cpu_period;
    }

    while (timer_accumulator >= timer_period) {
        chip8_tick_60hz(&vm);
        timer_accumulator -= timer_period;
    }

    if (display_accumulator >= display_period) {
        present_frame();
        reduce_display_accumulator();
    }
}
```

Tests must exercise the scheduler with injected elapsed time rather than an actual host clock.

Implementation may use a different structure if it preserves the same semantics.

---

# 16. Audio Design Rules for the AI Agent

When generating the audio portion, do not place platform audio calls inside:

```text
chip8.c
```

Preferred separation:

```text
src/chip8/
    chip8.c
    chip8.h

platform/macos/
    audio.*
    window.*
    clock.*

renderer/
    reference.*
    metal.*
```

Exact repository paths may differ according to the repository's ownership/config conventions.

The important boundary is conceptual.

The guest VM exports logical audio intent.

The host backend converts that intent into samples.

---

# 17. Course Profiles

Do not create profile complexity before it is needed.

By CHIP8-12, however, compatibility-sensitive behaviors should be explicit rather than scattered `if` statements with unexplained constants.

Conceptual profile:

```c
typedef struct {
    bool shift_uses_vy;
    bool load_store_increment_i;
    bool draw_wrap;
    bool draw_wait_vblank;
    bool vip_sound_timer_one_silent;
} chip8_quirks_t;
```

This is illustrative, not a mandatory API.

Only include fields backed by implemented/tested behavior.

---

# 18. ROM Compatibility Policy

Use ROMs as regression evidence, not as the only correctness oracle.

Correct order:

```text
unit tests
    ↓
property/state tests
    ↓
trace tests
    ↓
ROM regression tests
```

A ROM "looking correct" is insufficient certification.

For each compatibility ROM, record:

```text
ROM name
legal source
expected profile
expected result
test method
```

---

# 19. Property Tests

Recommended deterministic properties:

## Graphics

```text
draw same XOR sprite twice
→ original framebuffer
```

## Save States

```text
save → mutate → load
→ original guest state
```

## Timer

```text
timer reaches zero
→ never becomes 255 through underflow
```

## Reset

```text
arbitrary dirty state → reset
=
fresh initialized state
```

## Scheduler

Equivalent elapsed time split differently should produce equivalent rate-domain counts where ordering semantics do not intentionally differ.

Example:

```text
advance(100 ms)
```

versus:

```text
advance(10 ms) × 10
```

should agree on cumulative 60 Hz tick count.

---

# 20. Completion Gate

Do not consider the required CHIP-8 curriculum complete until:

```text
machine-state tests             PASS
memory/ROM tests                PASS
fetch/decode tests              PASS
instruction tests               PASS
stack boundary tests            PASS
timer semantic tests            PASS
60 Hz cadence tests             PASS
scheduler CPU-independence      PASS
long-run scheduler drift        PASS
sound-gate tests                PASS
audible host-audio backend      PASS
input tests                     PASS
graphics tests                  PASS
compatibility/profile tests     PASS
ROM regression tests            PASS
debugger/trace tests            PASS
save-state determinism          PASS
reference renderer              PASS
Metal framebuffer               PASS
pixel-perfect scaling           PASS
host-refresh independence       PASS
final certification challenge   PASS
```

`CHIP8-ADV-01` is optional and is not required to begin the next console unless the course author explicitly promotes it to mandatory status.

---

# 21. What "Accurate" Means at Course Completion

After the required curriculum, it is valid to say:

> This is a deterministic, compatibility-aware CHIP-8 emulator with correct 60 Hz timer semantics, validated sound duration, audible host sound, and a scheduler independent of CPU and host display rates.

It is **not** valid to say:

> This is a cycle-perfect COSMAC VIP emulator.

unless the advanced historical timing/full-system work actually justifies that statement.

---

# 22. Knowledge Carried Forward

The next console may assume understanding of:

- explicit machine state
- fetch/decode/execute
- registers and flags
- guest vs host state
- memory layout
- stacks
- deterministic unit testing
- timers
- independent clock/rate domains
- accumulator-based scheduling
- host-time injection for tests
- sound-gate vs audio-sample generation
- input abstraction
- framebuffer rendering
- compatibility quirks
- trace debugging
- save states
- reference-vs-accelerated renderers
- Metal device/queue/buffer/texture/shader basics
- the difference between HLE timing and hardware cycle accuracy

These concepts directly prepare the learner for systems where timing becomes much less forgiving.

---

# 23. Stage Generation Rules

For every stage generated from this blueprint, the AI course-author agent must create:

```text
stage brief
starter or TODO boundary
visible tests
challenge
certification coverage
manifest metadata
```

The stage must be rejected by `verify-course` if required assets are absent.

Do not allow:

```text
missing test suite
=
pass
```

The course engine remains fail-closed.

---

# 24. Human vs AI Responsibilities

## Human Learner

Expected to:

- read stage material
- implement learner-owned code
- run tests
- debug
- ask for hints when blocked
- complete challenge
- submit for objective certification

## Tutor AI

May:

- explain architecture
- explain timing
- explain failing tests
- propose experiments
- inspect traces
- provide escalating hints
- provide pseudocode when appropriate

Must not silently:

- solve the stage
- edit learner code
- inspect sealed grader answers
- certify work itself

Direct implementation is reserved for explicit rescue-mode behavior according to repository policy.

---

# 25. Timing/Sound References for Course Authoring

Course-author agents should use authoritative or technically detailed references when generating timing/compatibility stages.

Recommended references:

1. CHIP-8 Extensions and Compatibility  
   `https://chip-8.github.io/extensions/`

2. Laurence Scotford — CHIP-8 on the COSMAC VIP: Sound  
   `https://laurencescotford.net/2020/07/19/chip-8-on-the-cosmac-vip-sound/`

3. Laurence Scotford — CHIP-8 on the COSMAC VIP: General Purpose Timer  
   `https://laurencescotford.net/2020/07/19/chip-8-on-the-cosmac-vip-the-general-purpose-timer/`

4. Tobias V. Langhoff — Guide to making a CHIP-8 emulator  
   `https://tobiasvl.github.io/blog/write-a-chip-8-emulator/`

Use historical timing claims carefully.

If sources disagree, document the compatibility choice rather than silently choosing one.

---

# 26. Versioning

Use Semantic Versioning for this blueprint.

```text
MAJOR
architecture/course-direction incompatibility

MINOR
new stages, accuracy requirements, or substantial curriculum expansion

PATCH
clarifications and factual corrections
```

Current:

```text
v1.2.0
```

This revision adds substantial timing/audio requirements and therefore increments the minor version.

---

# 27. Changelog

## v1.2.0 — 2026-08-27

Major curriculum refinement while preserving the overall CHIP-8 stage progression.

Added:

- explicit required vs advanced accuracy levels
- prohibition on falsely claiming normal HLE CHIP-8 is cycle-accurate
- deterministic scheduler architecture
- injected-time testing requirements
- CPU-rate independence tests
- 60 Hz long-run timer tests
- catch-up semantics
- host-refresh independence
- explicit sound gate
- audible host audio requirement
- host audio architecture
- offline audio testing
- historical COSMAC VIP `ST=1` sound quirk
- DXYN vertical-blank compatibility consideration
- compatibility profiles
- optional `CHIP8-ADV-01 — COSMAC VIP Timing`
- HLE timing vs full CDP1802 distinction
- detailed completion gate
- timing/sound reference list
- stronger stage-generation rules for AI agents

Preserved:

- CHIP8-01 through CHIP8-14 main sequence
- 8-stage Metal track (`MTL-00` through `MTL-07`)
- reference-renderer-before-Metal principle
- human-owned implementation model
- objective grader certification
- fail-closed course generation
