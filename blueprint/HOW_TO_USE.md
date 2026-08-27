# How to Use These Blueprints

## Goal

Run the curriculum one console at a time, Codecrafters-style, with the AI acting as instructor and reviewer rather than writing the whole emulator for you.

## Rule 1 — Never Give the Agent Every Console at Once

For the current console, give the agent only:

```text
MASTER_BLUEPRINT.md
HOW_TO_USE.md
AGENT_START_PROMPT.md
<current-console>.md
```

Example for the beginning:

```text
MASTER_BLUEPRINT.md
HOW_TO_USE.md
AGENT_START_PROMPT.md
01_CHIP8.md
```

Do not give it `02_8080_SPACE_INVADERS.md` until CHIP-8 is certified complete.

## Rule 2 - One Stage at a Time

Authoring and learner progression are separate gates:

- Authoring rule: Do not author CHIP8-N+1 until CHIP8-N course material is
  structurally validated and frozen.
- Learner rule: the learner must not activate or access the next stage until
  certification succeeds.
- Future stage files may exist for authoring and validation; their presence
  does not unlock the learner.
- Never generate later-stage learner solutions in advance.

The intended loop is:

```text
agent introduces stage
        |
you implement TODOs
        |
run visible tests
        |
you debug
        |
agent gives hints only when needed
        |
visible tests pass
        |
challenge
        |
hidden/local certification test
        |
next stage is unlocked, then activated
```

## Rule 3 — Your Repository Should Evolve Naturally

Start with:

```text
emulator-course/
├── Makefile
├── README.md
├── course.sh
├── .progress/
├── tools/
├── src/
├── tests/
└── course/
```

The agent may adapt this layout as the project grows, but the emulator code should remain separate from course/test infrastructure.

## Rule 4 — Use a Fresh Conversation or Agent Session Per Console

Recommended:

- one long-running session for CHIP-8
- a fresh session for 8080
- a fresh session for Game Boy
- etc.

At the start of the next console, provide:

1. `MASTER_BLUEPRINT.md`
2. `HOW_TO_USE.md`
3. `AGENT_START_PROMPT.md`
4. the new console blueprint
5. a short `COMPLETION_SUMMARY.md` from the previous console

The completion summary should state only what you actually implemented and learned.

## Rule 5 — Do Not Skip Certification

Before moving to the next console, require:

```text
unit tests          PASS
integration tests   PASS
challenge           PASS
hidden tests        PASS
representative ROMs PASS
debug tooling       PASS
renderer tests      PASS
Metal milestone     PASS when required
```

## Rule 6 — When You Get Stuck

Ask the agent for help in this order:

1. explain the concept
2. point to the relevant subsystem
3. give a debugging experiment
4. give pseudocode
5. show a small fragment
6. only then show the full solution to the specific function

Do not ask for the whole stage implementation unless you intentionally want to stop the learning exercise.

## Rule 7 — Keep Metal Separate From Correctness

For graphical systems:

```text
emulated hardware
      ↓
reference software renderer
      ↓
known-correct output
```

Then:

```text
same emulated state
   ├── CPU/reference renderer
   └── Metal renderer
```

Compare outputs.

Do not use Metal to hide a wrong PPU/GPU implementation.

## Rule 8 — When to Move to the Next Console

Only advance after the current blueprint's completion gate passes.

Recommended progression:

```text
CHIP-8
  ↓
8080 / Space Invaders
  ↓
Game Boy
  ↓
NES
  ↓
GBA
  ↓
SNES
  ↓
PS1
  ↓
NDS
```

## Suggested First Action

Create a new empty directory and start the AI agent there.

Give it:

```text
MASTER_BLUEPRINT.md
HOW_TO_USE.md
AGENT_START_PROMPT.md
01_CHIP8.md
```

Then say:

```text
Start the course. Implement only the course infrastructure and CHIP-8 Stage 01. Do not generate later stages yet.
```

Complete Stage 01 yourself before asking for Stage 02.
