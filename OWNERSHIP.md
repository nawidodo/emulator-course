# Ownership Model

This repository distinguishes who owns what so progress is machine-verifiable
and AI assistance cannot silently certify or complete student work.

Keywords checked by `make verify-course`: `student-owned`, `agent-owned`, `grader-owned`.

The path lists below are a human-readable mirror of the active-stage
manifest's `ownership` object. The manifest is the sole machine-readable
authority; update it first when ownership changes.

## Student-Owned (learner's implementation)
```
src/**
platform/**
renderer/**
```

- The learner's emulator core and any platform/renderer work.
- The tutor may read, inspect, and suggest experiments, pseudocode, or small
  fragments, but must not silently edit these files.
- Direct edits only in `RESCUE MODE` when the learner explicitly requests an
  override.

## Agent / Course-Author-Owned

```
.github/workflows/**
.gitignore
Makefile
OWNERSHIP.md
README.md
blueprint/**
config/**
course/**
course.sh
tests/chip8/**
tests/challenge/**
tools/doctor.py
tools/test.h
tools/verify_course.py
```

- Stage specifications, visible and challenge tests, manifests, and authoring
  tooling.
- Generated from the course data model; the tutor may read but must not
  complete student tasks.

## Grader-Owned (certification authority)

```
tests/hidden/**
tools/reference/**
```

- Certification tests and any reference implementations or golden traces.
- The tutor must treat these as opaque at test time; only `make submit`
  (which runs the grader) has certification authority.
- Hidden tests are not meaningfully hidden merely by living in `hidden/` —
  the architecture reserves a trust boundary so certification can later live
  outside the tutor-visible workspace without a redesign.

## Trust Boundary

```
COURSE AUTHOR
     │
     ├── stage specification
     ├── starter
     ├── visible tests
     ├── challenge
     └── certification grader  ──► sealed stage

STUDENT ──► implements src/**

TUTOR AGENT
     ├── reads STAGE.md, manifest
     ├── reads student source
     ├── reads visible/challenge failures
     └── NO certification answer access
```

AI statements have **zero certification authority**. Only `grader success ==
certification` (i.e., `make submit` → all suites PASS) advances progress.

## Rescue Mode

Normal tutor hints escalate:

```
Level 1 — concept hint
Level 2 — subsystem hint
Level 3 — debugging experiment
Level 4 — pseudocode
Level 5 — small code fragment
```

Direct modification of `src/**` occurs only when the learner explicitly
requests:

```
RESCUE MODE
```

## Metadata Authority

`config/course.json` is authoritative for the console catalog and active
console. Its referenced console config is authoritative for console title,
stage order, stage titles, and which stages have generated material. Every
implemented stage has `course/<console>/<stage>/manifest.json`; that manifest
is authoritative for prerequisites, required files, test-suite paths, stage
directory, and ownership partitions. `course.sh` only orchestrates values
loaded through `tools/verify_course.py`.

## Verification

```
make verify-course   # is this stage itself valid as course material?
make doctor          # is the dev environment valid?
```

Both must pass before stage content is considered publishable.
See `tools/verify_course.py` and `tools/doctor.py` for the checks.
