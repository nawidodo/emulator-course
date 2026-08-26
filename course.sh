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

# Visible tests: every stage at or before the active stage that has tests.
run_visible() {
  local ACTIVE active_i i stage d t rc=0
  ACTIVE=$(active_stage)
  active_i=$(stage_index "$ACTIVE")
  for i in "${!STAGES[@]}"; do
    if (( i > active_i )); then
      continue
    fi
    stage="${STAGES[$i]}"
    d="$SCRIPT_DIR/tests/$CONSOLE/$stage"
    [[ -d "$d" ]] || continue
    for t in "$d"/test_*.c; do
      [[ -e "$t" ]] || continue
      echo "== [visible] $stage $(basename "$t")"
      build_one "$t" || rc=1
    done
  done
  return $rc
}

run_dir() { # $1 = label, $2 = directory of test sources
  local rc=0 t
  for t in "$2"/test_*.c; do
    [[ -e "$t" ]] || continue
    echo "== [$1] $(basename "$t")"
    build_one "$t" || rc=1
  done
  return $rc
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
  echo "  make start      course status"
  echo "  make stage      active stage brief"
  echo "  make test       visible tests"
  echo "  make challenge  active stage challenge"
  echo "  make submit     certify stage (visible + challenge + hidden)"
  echo "  make progress   stage progress"
  echo "  make next       advance to next unlocked stage"
  echo ""
  echo "Start with: make stage"
}

cmd_stage() {
  state_init
  local ACTIVE md
  ACTIVE=$(active_stage)
  md="$SCRIPT_DIR/course/$CONSOLE/$ACTIVE/STAGE.md"
  if [[ ! -f "$md" ]]; then
    echo "Stage $ACTIVE materials are not generated yet."
    echo "Ask the agent: create stage $ACTIVE for $CONSOLE_TITLE."
    return 1
  fi
  cat "$md"
}

cmd_test() {
  state_init
  echo "Running visible tests ($CONSOLE_TITLE)..."
  local rc=0
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
  d="$SCRIPT_DIR/tests/challenge/$CONSOLE/$ACTIVE"
  if [[ ! -d "$d" ]]; then
    echo "No challenge defined for $ACTIVE yet."
    return 0
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
  d="$SCRIPT_DIR/tests/hidden/$CONSOLE/$ACTIVE"
  if [[ ! -d "$d" ]]; then
    echo "No hidden certification tests for $ACTIVE yet."
    return 0
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

case "${1:-start}" in
  start)     cmd_start ;;
  stage)     cmd_stage ;;
  test)      cmd_test ;;
  challenge) cmd_challenge ;;
  submit)    cmd_submit ;;
  progress)  cmd_progress ;;
  next)      cmd_next ;;
  *)
    echo "usage: course.sh {start|stage|test|challenge|submit|progress|next}"
    exit 2
    ;;
esac
