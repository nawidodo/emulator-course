# Zero to Expert — Emulator Engineering Course

A Codecrafters-style course in building emulators from first principles:
read the hardware spec, implement the machine, prove it with tests.
The AI is the instructor and reviewer; you write the emulator.

**Console 1: CHIP-8** — 14 core stages in C, then a 7-stage Metal track.

## Commands

    make start          course status + command list
    make stage          show the active stage brief (STAGE.md)
    make test           visible tests for all unlocked stages
    make challenge      challenge test for the active stage
    make submit         certify stage (visible + challenge + hidden)
    make progress       per-stage progress
    make next           advance to the next unlocked stage
    make doctor         validate dev environment (cc, make, bash, python3)
    make verify-course  validate course material integrity
    make reset          safe progress reset (keeps src/)
    make clean          remove build artifacts

## What each command means

- **`make test`** — runs `tests/chip8/<stage>/test_*.c` for every stage at or
  before the active one. These are the *visible* tests you may read while
  working.
- **`make challenge`** — runs `tests/challenge/<stage>/test_*.c` for the
  active stage. Less-guided, deterministic checksum / integration check.
- **`make submit`** — runs visible + challenge + `tests/hidden/<stage>/`
  certification tests. Only `make submit` has **certification authority**:
  AI opinion (`"looks correct"`) never certifies; only `grader success ==
  certification`. On PASS the stage is marked `certified` and the next stage
  is `unlocked`; run `make next` to activate it.
- **`make doctor`** — checks `cc`, `make`, `bash`, `python3` and a C11
  compile self-test. Extensible for future Metal (`xcrun`, `xcodebuild`).
- **`make verify-course`** — answers *is this stage itself valid as course
  material?* Checks: `STAGE.md` exists, `manifest.json` exists and parses,
  visible/challenge/certification suites exist, starter files exist, tests
  compile, ownership partitions are consistent, config data matches.
  Missing assets are **fail-closed**: `COURSE INFRASTRUCTURE ERROR → FAIL`,
  never `PASS`.
- **`make reset`** — resets `.progress/state` and `build/` so you can replay
  the course. It **never** deletes `src/`, `course/`, or `tests/`.

## The loop, per stage

1. `make stage` — read the objective, hardware facts, and TODOs
2. implement the TODOs in `src/chip8/`
3. `make test` — must pass
4. `make challenge` — must pass
5. `make submit` — certifies and unlocks the next stage
6. `make next`

## Stage lifecycle

```
pending → active → certified → next stage unlocked → active
```

State lives in `.progress/state` (local, git-ignored). `make reset` returns
to `CHIP8-01=active`.

Every generated stage has `course/<console>/<stage>/manifest.json`:

```json
{
  "stage": "CHIP8-01",
  "console": "chip8",
  "prerequisites": [],
  "required_files": ["src/chip8/chip8.h", "src/chip8/chip8.c"],
  "visible_tests": "tests/chip8/CHIP8-01",
  "challenge_tests": "tests/challenge/chip8/CHIP8-01",
  "certification_tests": "tests/hidden/chip8/CHIP8-01",
  "ownership": { "student_owned": [...], "agent_owned": [...], "grader_owned": [...] }
}
```

`config/course.json` and `config/consoles/chip8.json` hold the canonical
console/stage catalog. `course.sh` prefers those files when present and
`make verify-course` checks they stay consistent with the hardcoded fallback.

## Layout

    src/chip8/               emulator core (pure C, no I/O, no Metal) — student-owned
    tests/chip8/             visible per-stage tests — agent-owned
    tests/challenge/         per-stage challenge tests — agent-owned
    tests/hidden/            certification tests — grader-owned (do not read while working)
    tools/test.h             shared test framework (improved diagnostics)
    tools/verify_course.py   course-material validator
    tools/doctor.py          environment validator
    course/                  per-stage briefs + manifests — agent-owned
    config/course.json       canonical stage list
    config/consoles/chip8.json  per-console stage metadata
    OWNERSHIP.md             ownership & trust-boundary contract
    .progress/state          local course state (git-ignored)
    build/                   compiled test binaries (git-ignored)

## Ownership & trust boundary

See `OWNERSHIP.md` for the contract. Summary:

- **Student-owned:** `src/**`, `platform/**`, `renderer/**`
- **Agent-owned:** `course/**`, `tests/chip8/**`, `tests/challenge/**`,
  `config/**`, `tools/verify_course.py`, manifests
- **Grader-owned:** `tests/hidden/**` (future: reference impls, golden traces)

```
COURSE AUTHOR → stage spec, starter, visible, challenge, grader → sealed stage
STUDENT       → implements src/**
TUTOR AGENT   → reads STAGE.md, manifest, student source, visible/challenge failures
                NO certification answer access
```

Hidden tests are not meaningfully hidden merely by living in `hidden/`; the
architecture reserves a trust boundary so certification can later live outside
the tutor-visible workspace (local separated grader) without redesign.

## Tutor limitations & rescue mode

During normal operation the tutor may:

- read/inspect student source
- run tests and explain failures
- suggest debugging experiments and pseudocode

It must not:

- silently edit `src/**`
- complete TODOs
- solve future stages

If you want the agent to edit `src/**` directly, explicitly request:

```
RESCUE MODE
```

The tutor then escalates hints: `concept → subsystem → debugging experiment →
pseudocode → small fragment → full function` (last resort).

## Adding a future stage (for course authors)

1. Add the stage id and title to `config/course.json` and
   `config/consoles/chip8.json`.
2. Create `course/chip8/<STAGE>/STAGE.md` and `manifest.json`.
3. Add `tests/chip8/<STAGE>/test_*.c`, `tests/challenge/...`, `tests/hidden/...`.
4. Run `make verify-course` and `make doctor` — both must pass.
5. Run negative tests: temporarily remove each required asset and confirm
   `COURSE INFRASTRUCTURE ERROR → FAIL`.
6. Do not generate future stages until the current one is certified.

## Rules

- One stage at a time. Later stage material is generated only after the
  current stage is certified.
- The CPU/reference path is the correctness oracle. Metal is added only
  once reference output is known correct, and is compared against it.
- Keep dependencies minimal: Bash, Make, Python stdlib, C11.
- No network, no git, no CI. Everything runs locally.
