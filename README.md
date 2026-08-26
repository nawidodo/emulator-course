# Zero to Expert — Emulator Engineering Course

A Codecrafters-style course in building emulators from first principles:
read the hardware spec, implement the machine, prove it with tests.
The AI is the instructor and reviewer; you write the emulator.

**Console 1: CHIP-8** — 14 core stages in C, then a 7-stage Metal track.

## Commands

    make start      course status + command list
    make stage      active stage brief
    make test       visible tests for all unlocked stages
    make challenge  challenge test for the active stage
    make submit     certify stage (visible + challenge + hidden)
    make progress   per-stage progress
    make next       advance to the next unlocked stage
    make clean      remove build artifacts

## The loop, per stage

1. `make stage` — read the objective, hardware facts, and TODOs
2. implement the TODOs in `src/chip8/`
3. `make test` — must pass
4. `make challenge` — must pass
5. `make submit` — certifies and unlocks the next stage
6. `make next`

## Layout

    src/chip8/        emulator core (pure C, no I/O, no Metal)
    tests/chip8/      visible per-stage tests
    tests/challenge/  per-stage challenge tests
    tests/hidden/     certification tests — do not read while working
    tools/            shared test framework (test.h)
    course/           per-stage briefs
    .progress/        local course state
    01_CHIP8/         course blueprints (read-only reference)

## Rules

- One stage at a time. Later stage material is generated only after the
  current stage is certified.
- The CPU/reference path is the correctness oracle. Metal is added only
  once reference output is known correct, and is compared against it.
- Stuck? Escalate hints in this order: concept → subsystem → debugging
  experiment → pseudocode → small fragment → full function.
- No network, no git, no CI. Everything runs locally.
