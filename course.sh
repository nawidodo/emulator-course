#!/usr/bin/env bash
# Emulator course runner: stage management, test execution, progress.
# Local only: no network, no git, no CI. State lives in .progress/state.
# Compatible with bash 3.2 (macOS system bash).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PROGRESS_DIR="$SCRIPT_DIR/.progress"
STATE_FILE="$PROGRESS_DIR/state"
BUILD_DIR="$SCRIPT_DIR/build"

CONSOLE="chip8"
CONSOLE_TITLE="CHIP-8"
CFLAGS="-std=c11 -Wall -Wextra -Werror -O1 -g"

# ---------------------------------------------------------------- config ---
# Prefer data files in config/ when present, but keep hardcoded fallback
# so the course remains runnable if config is missing (verified by
# make verify-course).
STAGES=(
  CHIP8-01 CHIP8-02 CHIP8-03 CHIP8-04 CHIP8-05 CHIP8-06 CHIP8-07
  CHIP8-08 CHIP8-09 CHIP8-10 CHIP8-11 CHIP8-12 CHIP8-13 CHIP8-14
  MTL-00 MTL-01 MTL-02 MTL-03 MTL-04 MTL-05 MTL-06 MTL-07
)

STAGE_NAMES=(
  "Machine State"
  "Memory and ROM Loading"
  "Fetch / Decode / Execute Loop"
  "Control and Immediate Instructions"
  "ALU"
  "Conditional Flow"
  "Stack and Subroutines"
  "Timers"
  "Input"
  "Graphics"
  "Scheduler"
  "ROM Compatibility"
  "Debugger"
  "Save States"
  "GPU Mental Model"
  "Metal Setup"
  "First Triangle"
  "Buffers"
  "Textures"
  "CHIP-8 Framebuffer Upload"
  "Pixel-Perfect Scaling"
  "Frame Synchronization"
)

# If config/course.json exists, validate it matches hardcoded stages
# (non-fatal; verify-course will report mismatch).
if [[ -f "$SCRIPT_DIR/config/course.json" ]] && command -v python3 >/dev/null 2>&1; then
  _cfg_stages=$(python3 -c "import json,sys;print(' '.join(json.load(open('config/course.json'))['stages']))" 2>/dev/null || true)
  if [[ -n "$_cfg_stages" ]]; then
    # Compare counts as sanity check; don't override hardcoded silently
    _hardcoded_count=${#STAGES[@]}
    _cfg_count=$(echo "$_cfg_stages" | wc -w | tr -d ' ')
    if [[ "$_hardcoded_count" != "$_cfg_count" ]]; then
      echo "warning: config/course.json stages count ($_cfg_count) differs from hardcoded ($_hardcoded_count)" >&2
    fi
  fi
fi

# ---------------------------------------------------------------- state ---

stage_index() { # $1 = stage id -> prints index
  local i
  for i in "${!STAGES[@]}"; do
    if [[ "${STAGES[$i]}" == "$1" ]]; then
      echo "$i"
      return 0
    fi
  done
  return 1
}

next_stage_id() { # $1 = stage id -> prints next stage id or nothing
  local i
  i=$(stage_index "$1") || return 0
  if (( i + 1 < ${#STAGES[@]} )); then
    echo "${STAGES[$((i + 1))]}"
  fi
}

state_init() {
  mkdir -p "$PROGRESS_DIR"
  if [[ -f "$STATE_FILE" ]]; then
    return 0
  fi
  local s
  {
    echo "active=${STAGES[0]}"
    for s in "${STAGES[@]}"; do
      if [[ "$s" == "${STAGES[0]}" ]]; then
        echo "$s=active"
      else
        echo "$s=pending"
      fi
    done
  } > "$STATE_FILE"
}

stage_status() { grep -m1 "^$1=" "$STATE_FILE" | cut -d= -f2-; }
active_stage() { grep -m1 '^active=' "$STATE_FILE" | cut -d= -f2-; }

set_stage_status() { # $1 = stage id, $2 = status
  local tmp="$STATE_FILE.tmp"
  local line key
  : > "$tmp"
  while IFS= read -r line; do
    key="${line%%=*}"
    if [[ "$key" == "$1" ]]; then
      echo "$1=$2" >> "$tmp"
    else
      echo "$line" >> "$tmp"
    fi
  done < "$STATE_FILE"
  mv "$tmp" "$STATE_FILE"
}

set_active() { # $1 = stage id
  local tmp="$STATE_FILE.tmp"
  local line key
  : > "$tmp"
  while IFS= read -r line; do
    key="${line%%=*}"
    if [[ "$key" == "active" ]]; then
      echo "active=$1" >> "$tmp"
    else
      echo "$line" >> "$tmp"
    fi
  done < "$STATE_FILE"
  mv "$tmp" "$STATE_FILE"
}

# ------------------------------------------------------------- building ---

# Compile one test file against the core sources and run the binary.
# Returns 0 on pass, 1 on build or test failure.
build_one() { # $1 = test source path
  local src="$1"
  local out="$BUILD_DIR/$(basename "$src" .c).bin"
  local core=()
  local f
  mkdir -p "$BUILD_DIR"
  for f in "$SCRIPT_DIR/src/$CONSOLE"/*.c; do
    [[ -e "$f" ]] && core+=("$f")
  done
  if [[ ${#core[@]} -eq 0 ]]; then
    echo "  BUILD FAIL: no core sources in src/$CONSOLE/"
    return 1
  fi
  if ! cc $CFLAGS -I"$SCRIPT_DIR/src" -I"$SCRIPT_DIR/tools" \
      "$src" "${core[@]}" -o "$out" 2> "$out.err"; then
    echo "  BUILD FAIL: $(basename "$src")"
    sed 's/^/    /' "$out.err"
    rm -f "$out.err"
    return 1
  fi
  rm -f "$out.err"
  if ! "$out"; then
    return 1
  fi
  return 0
}

# Visible tests: every stage at or before the active stage.
# Fail-closed: missing directory or empty test set is infrastructure error.
run_visible() {
  local ACTIVE active_i i stage d t rc=0 found=0
  ACTIVE=$(active_stage)
  active_i=$(stage_index "$ACTIVE")
  for i in "${!STAGES[@]}"; do
    if (( i > active_i )); then
      continue
    fi
    stage="${STAGES[$i]}"
    d="$SCRIPT_DIR/tests/$CONSOLE/$stage"
    if [[ ! -d "$d" ]]; then
      echo "COURSE INFRASTRUCTURE ERROR: missing visible tests for $stage ($d)" >&2
      return 1
    fi
    local has_test=0
    for t in "$d"/test_*.c; do
      [[ -e "$t" ]] || continue
      has_test=1
      found=1
      echo "== [visible] $stage $(basename "$t")"
      build_one "$t" || rc=1
    done
    if [[ $has_test -eq 0 ]]; then
      echo "COURSE INFRASTRUCTURE ERROR: no test_*.c in $d" >&2
      return 1
    fi
  done
  if [[ $found -eq 0 ]]; then
    echo "COURSE INFRASTRUCTURE ERROR: no visible tests found up to $ACTIVE" >&2
    return 1
  fi
  return $rc
}

run_dir() { # $1 = label, $2 = directory of test sources
  local label="$1" dir="$2"
  if [[ ! -d "$dir" ]]; then
    echo "COURSE INFRASTRUCTURE ERROR: missing $label tests directory ($dir)" >&2
    return 1
  fi
  local rc=0 t found=0
  for t in "$dir"/test_*.c; do
    [[ -e "$t" ]] || continue
    found=1
    echo "== [$label] $(basename "$t")"
    build_one "$t" || rc=1
  done
  if [[ $found -eq 0 ]]; then
    echo "COURSE INFRASTRUCTURE ERROR: no test_*.c in $dir" >&2
    return 1
  fi
  return $rc
}

# Helpers for fail-closed validation of stage assets
require_stage_manifest() {
  local ACTIVE="$1"
  local mf="$SCRIPT_DIR/course/$CONSOLE/$ACTIVE/manifest.json"
  if [[ ! -f "$mf" ]]; then
    echo "COURSE INFRASTRUCTURE ERROR: missing stage manifest ($mf)" >&2
    return 1
  fi
  if command -v python3 >/dev/null 2>&1; then
    if ! python3 -c "import json,sys; json.load(open('$mf'))" 2>/dev/null; then
      echo "COURSE INFRASTRUCTURE ERROR: invalid stage manifest JSON ($mf)" >&2
      return 1
    fi
  fi
  return 0
}

require_starter_files() {
  local ACTIVE="$1"
  # For CHIP8-01: src/chip8/chip8.h and .c must exist
  local f
  for f in "$SCRIPT_DIR/src/$CONSOLE/chip8.h" "$SCRIPT_DIR/src/$CONSOLE/chip8.c"; do
    if [[ ! -f "$f" ]]; then
      echo "COURSE INFRASTRUCTURE ERROR: missing required starter file ($f)" >&2
      return 1
    fi
  done
  return 0
}

# ------------------------------------------------------------- commands ---

cmd_start() {
  state_init
  local ACTIVE i
  ACTIVE=$(active_stage)
  i=$(stage_index "$ACTIVE")
  echo "Zero to Expert — Emulator Course"
  echo "Console: $CONSOLE_TITLE"
  echo "Active stage: $ACTIVE (${STAGE_NAMES[$i]})"
  echo ""
  echo "Commands:"
  echo "  make start          course status"
  echo "  make stage          active stage brief"
  echo "  make test           visible tests"
  echo "  make challenge      active stage challenge"
  echo "  make submit         certify stage (visible + challenge + hidden)"
  echo "  make progress       stage progress"
  echo "  make next           advance to next unlocked stage"
  echo "  make doctor         validate dev environment"
  echo "  make verify-course  validate course material integrity"
  echo "  make reset          safe progress reset (keeps src/)"
  echo ""
  echo "Start with: make stage"
}

cmd_stage() {
  state_init
  local ACTIVE md
  ACTIVE=$(active_stage)
  md="$SCRIPT_DIR/course/$CONSOLE/$ACTIVE/STAGE.md"
  if [[ ! -f "$md" ]]; then
    echo "COURSE INFRASTRUCTURE ERROR: missing STAGE.md for $ACTIVE ($md)" >&2
    return 1
  fi
  cat "$md"
}

cmd_test() {
  state_init
  local ACTIVE
  ACTIVE=$(active_stage)
  # fail-closed pre-checks
  local rc=0
  require_stage_manifest "$ACTIVE" || rc=1
  require_starter_files "$ACTIVE" || rc=1
  if [[ $rc -ne 0 ]]; then
    echo "COURSE INFRASTRUCTURE ERROR: stage $ACTIVE is incomplete" >&2
    echo "VISIBLE TESTS: FAIL"
    return 1
  fi
  echo "Running visible tests ($CONSOLE_TITLE)..."
  rc=0
  run_visible || rc=1
  echo ""
  if [[ $rc -eq 0 ]]; then
    echo "VISIBLE TESTS: PASS"
  else
    echo "VISIBLE TESTS: FAIL (see above)"
  fi
  return $rc
}

cmd_challenge() {
  state_init
  local ACTIVE d rc
  ACTIVE=$(active_stage)
  require_stage_manifest "$ACTIVE" || { echo "CHALLENGE: FAIL"; return 1; }
  d="$SCRIPT_DIR/tests/challenge/$CONSOLE/$ACTIVE"
  if [[ ! -d "$d" ]]; then
    echo "COURSE INFRASTRUCTURE ERROR: missing challenge tests for $ACTIVE ($d)" >&2
    echo "CHALLENGE: FAIL"
    return 1
  fi
  local has_test=0
  for t in "$d"/test_*.c; do [[ -e "$t" ]] && has_test=1; done
  if [[ $has_test -eq 0 ]]; then
    echo "COURSE INFRASTRUCTURE ERROR: no test_*.c in $d" >&2
    echo "CHALLENGE: FAIL"
    return 1
  fi
  echo "Running challenge ($CONSOLE_TITLE $ACTIVE)..."
  rc=0
  run_dir "challenge" "$d" || rc=1
  echo ""
  if [[ $rc -eq 0 ]]; then
    echo "CHALLENGE: PASS"
  else
    echo "CHALLENGE: FAIL (see above)"
  fi
  return $rc
}

cmd_hidden() {
  state_init
  local ACTIVE d rc
  ACTIVE=$(active_stage)
  require_stage_manifest "$ACTIVE" || { echo "HIDDEN TESTS: FAIL"; return 1; }
  d="$SCRIPT_DIR/tests/hidden/$CONSOLE/$ACTIVE"
  if [[ ! -d "$d" ]]; then
    echo "COURSE INFRASTRUCTURE ERROR: missing certification tests for $ACTIVE ($d)" >&2
    echo "HIDDEN TESTS: FAIL"
    return 1
  fi
  local has_test=0
  for t in "$d"/test_*.c; do [[ -e "$t" ]] && has_test=1; done
  if [[ $has_test -eq 0 ]]; then
    echo "COURSE INFRASTRUCTURE ERROR: no test_*.c in $d" >&2
    echo "HIDDEN TESTS: FAIL"
    return 1
  fi
  echo "Running hidden certification tests ($CONSOLE_TITLE $ACTIVE)..."
  rc=0
  run_dir "hidden" "$d" || rc=1
  echo ""
  if [[ $rc -eq 0 ]]; then
    echo "HIDDEN TESTS: PASS"
  else
    echo "HIDDEN TESTS: FAIL (see above)"
  fi
  return $rc
}

cmd_submit() {
  state_init
  local ACTIVE next rc=0
  ACTIVE=$(active_stage)
  echo "SUBMIT: $CONSOLE_TITLE $ACTIVE"
  echo ""
  cmd_test || rc=1
  echo ""
  cmd_challenge || rc=1
  echo ""
  cmd_hidden || rc=1
  echo ""
  if [[ $rc -eq 0 ]]; then
    set_stage_status "$ACTIVE" "certified"
    next=$(next_stage_id "$ACTIVE")
    if [[ -n "$next" ]]; then
      set_stage_status "$next" "unlocked"
    fi
    echo "CERTIFIED: $ACTIVE"
    if [[ -n "$next" ]]; then
      echo "Unlocked: $next"
      echo "Run: make next"
    else
      echo "All stages of $CONSOLE_TITLE are certified."
    fi
  else
    echo "NOT CERTIFIED: fix the failures above, then re-run: make submit"
  fi
  return $rc
}

cmd_progress() {
  state_init
  local ACTIVE i stage st marker
  ACTIVE=$(active_stage)
  echo "$CONSOLE_TITLE — progress"
  echo ""
  for i in "${!STAGES[@]}"; do
    stage="${STAGES[$i]}"
    st=$(stage_status "$stage")
    marker=" "
    if [[ "$stage" == "$ACTIVE" ]]; then
      marker="*"
    fi
    printf "  %s %s  %-30s %s\n" "$marker" "$stage" "${STAGE_NAMES[$i]}" "$st"
  done
}

cmd_next() {
  state_init
  local ACTIVE next st md
  ACTIVE=$(active_stage)
  next=$(next_stage_id "$ACTIVE")
  if [[ -z "$next" ]]; then
    echo "No more stages."
    return 0
  fi
  st=$(stage_status "$next")
  if [[ "$st" != "unlocked" && "$st" != "active" ]]; then
    echo "$next is locked. Certify $ACTIVE first: make submit"
    return 1
  fi
  md="$SCRIPT_DIR/course/$CONSOLE/$next/STAGE.md"
  if [[ ! -f "$md" ]]; then
    echo "$next is unlocked, but its materials are not generated yet."
    echo "Ask the agent: create stage $next for $CONSOLE_TITLE."
    return 1
  fi
  set_active "$next"
  set_stage_status "$next" "active"
  echo "Active stage: $next"
  echo "Run: make stage"
}

cmd_doctor() {
  if [[ -f "$SCRIPT_DIR/tools/doctor.py" ]]; then
    python3 "$SCRIPT_DIR/tools/doctor.py"
    return $?
  fi
  # Fallback inline checks
  local ok=0
  echo "doctor: checking required tools (fallback)"
  for t in cc make bash python3; do
    if command -v "$t" >/dev/null 2>&1; then
      echo "  ok: $t ($("$t" --version 2>&1 | head -n1))"
    else
      echo "  missing: $t" >&2
      ok=1
    fi
  done
  return $ok
}

cmd_verify_course() {
  if [[ -f "$SCRIPT_DIR/tools/verify_course.py" ]]; then
    python3 "$SCRIPT_DIR/tools/verify_course.py"
    return $?
  fi
  echo "COURSE INFRASTRUCTURE ERROR: missing tools/verify_course.py" >&2
  return 1
}

cmd_reset() {
  echo "Resetting course progress (keeps src/, course/, tests/ intact)..."
  if [[ -f "$STATE_FILE" ]]; then
    echo "  removing $STATE_FILE"
    rm -f "$STATE_FILE"
  fi
  # Remove build artifacts, keep source
  if [[ -d "$BUILD_DIR" ]]; then
    echo "  removing $BUILD_DIR/"
    rm -rf "$BUILD_DIR"
  fi
  state_init
  echo "Progress reset. Active stage: $(active_stage)"
  echo "Student source in src/ was not touched."
}

case "${1:-start}" in
  start)          cmd_start ;;
  stage)          cmd_stage ;;
  test)           cmd_test ;;
  challenge)      cmd_challenge ;;
  hidden)         cmd_hidden ;;
  submit)         cmd_submit ;;
  progress)       cmd_progress ;;
  next)           cmd_next ;;
  doctor)         cmd_doctor ;;
  verify-course)  cmd_verify_course ;;
  verify_course)  cmd_verify_course ;;
  reset)          cmd_reset ;;
  reset-progress) cmd_reset ;;
  *)
    echo "usage: course.sh {start|stage|test|challenge|hidden|submit|progress|next|doctor|verify-course|reset}" >&2
    exit 2
    ;;
esac
