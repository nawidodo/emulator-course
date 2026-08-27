# Local Deviations from Installed Blueprints

This file records deliberate local policy choices that override specifics of
an installed console blueprint. Future agents generating or certifying stages
MUST apply these overrides alongside `blueprint/<console>.md`.

## Current CHIP-8 stack policy

The default course profile uses a **12-entry call stack**:
`CHIP8_STACK_DEPTH = 12` (`uint16_t stack[12]`, 8-bit `SP`, valid range
`0..12`). This matches the historical COSMAC VIP baseline in
`blueprint/01_CHIP8.md`.

No local stack-depth deviation is active. Future stack, checksum, and save-state
material must use the same 12-entry serialization defined by the current stage
specification. Everything else in blueprint v1.2.0 applies unmodified,
including timer semantics, scheduler CPU-independence, host-independent sound
gate, and the accuracy-model claims (Level A is not COSMAC VIP cycle accuracy).
