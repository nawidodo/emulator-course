#!/usr/bin/env bash
# Emulator course runner: stage management, test execution, progress.
# The runner performs no network or git operations. State lives in .progress/state.
# Compatible with bash 3.2 (macOS system bash).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PROGRESS_DIR="$SCRIPT_DIR/.progress"
STATE_FILE="$PROGRESS_DIR/state"
BUILD_DIR="$SCRIPT_DIR/build"
METADATA_TOOL="$SCRIPT_DIR/tools/verify_course.py"
CFLAGS="-std=c11 -Wall -Wextra -Werror -O1 -g"

CONSOLE=""
CONSOLE_TITLE=""
STAGES=()
STAGE_NAMES=()
STAGE_IMPLEMENTED=()

STAGE_DIR=""
VISIBLE_TESTS=""
CHALLENGE_TESTS=""
CERTIFICATION_TESTS=""
REQUIRED_FILES=()

infrastructure_error() {
  echo "COURSE INFRASTRUCTURE ERROR: $*" >&2
}

require_python() {
  if ! command -v python3 >/dev/null 2>&1; then
    infrastructure_error "required executable python3 not found"
    return 1
  fi
  if [[ ! -f "$METADATA_TOOL" ]]; then
    infrastructure_error "missing metadata validator ($METADATA_TOOL)"
    return 1
  fi
}

# config/course.json is authoritative for the active console; the referenced
# console config is authoritative for console title, stage order, and titles.
load_runtime_metadata() {
  require_python || return 1
  local output kind first second third
  if ! output=$(python3 "$METADATA_TOOL" --runtime-metadata); then
    return 1
  fi

  CONSOLE=""
  CONSOLE_TITLE=""
  STAGES=()
  STAGE_NAMES=()
  STAGE_IMPLEMENTED=()
  while IFS=$'\t' read -r kind first second third; do
    case "$kind" in
      CONSOLE)
        CONSOLE="$first"
        CONSOLE_TITLE="$second"
        ;;
      STAGE)
        STAGES+=("$first")
        STAGE_NAMES+=("$second")
        STAGE_IMPLEMENTED+=("$third")
        ;;
      "") ;;
      *)
        infrastructure_error "unexpected metadata record '$kind'"
        return 1
        ;;
    esac
  done <<< "$output"

  if [[ -z "$CONSOLE" || -z "$CONSOLE_TITLE" || ${#STAGES[@]} -eq 0 ]]; then
    infrastructure_error "runtime metadata is incomplete"
    return 1
  fi
}

# The active-stage manifest is authoritative for required files and suite
# paths. The Python helper performs structural and semantic preflight before
# emitting values; stdout is parsed only after validation succeeds.
load_stage_assets() { # $1 = stage id
  local stage="$1" output kind value
  require_python || return 1
  if ! output=$(python3 "$METADATA_TOOL" --stage-assets "$CONSOLE" "$stage"); then
    return 1
  fi

  STAGE_DIR=""
  VISIBLE_TESTS=""
  CHALLENGE_TESTS=""
  CERTIFICATION_TESTS=""
  REQUIRED_FILES=()
  while IFS=$'\t' read -r kind value; do
    case "$kind" in
      TITLE) ;;
      STAGE_DIR) STAGE_DIR="$SCRIPT_DIR/$value" ;;
      REQUIRED_FILE) REQUIRED_FILES+=("$SCRIPT_DIR/$value") ;;
      VISIBLE_TESTS) VISIBLE_TESTS="$SCRIPT_DIR/$value" ;;
      CHALLENGE_TESTS) CHALLENGE_TESTS="$SCRIPT_DIR/$value" ;;
      CERTIFICATION_TESTS) CERTIFICATION_TESTS="$SCRIPT_DIR/$value" ;;
      "") ;;
      *)
        infrastructure_error "unexpected stage-asset record '$kind'"
        return 1
        ;;
    esac
  done <<< "$output"

  if [[ -z "$STAGE_DIR" || -z "$VISIBLE_TESTS" || -z "$CHALLENGE_TESTS" || \
        -z "$CERTIFICATION_TESTS" || ${#REQUIRED_FILES[@]} -eq 0 ]]; then
    infrastructure_error "manifest assets for $stage are incomplete"
    return 1
  fi
}

# Consume manifest.required_files in the runner as a final race-safe check.
require_starter_files() {
  local file
  for file in "${REQUIRED_FILES[@]}"; do
    if [[ ! -f "$file" ]]; then
      infrastructure_error "missing required starter file ($file)"
      return 1
    fi
  done
}

preflight_stage() { # $1 = stage id
  load_stage_assets "$1" || return 1
  require_starter_files || return 1
}

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

stage_is_implemented() { # $1 = stage id
  local i
  i=$(stage_index "$1") || return 1
  [[ "${STAGE_IMPLEMENTED[$i]}" == "1" ]]
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
  local stage
  {
    echo "active=${STAGES[0]}"
    for stage in "${STAGES[@]}"; do
      if [[ "$stage" == "${STAGES[0]}" ]]; then
        echo "$stage=active"
      else
        echo "$stage=pending"
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

build_one() { # $1 = test source path
  local src="$1"
  local out="$BUILD_DIR/$(basename "$src" .c).bin"
  local core=()
  local file
  mkdir -p "$BUILD_DIR"
  if ! command -v cc >/dev/null 2>&1; then
    infrastructure_error "required executable cc not found"
    return 1
  fi
  for file in "$SCRIPT_DIR/src/$CONSOLE"/*.c; do
    [[ -e "$file" ]] && core+=("$file")
  done
  if [[ ${#core[@]} -eq 0 ]]; then
    infrastructure_error "no core sources in src/$CONSOLE/"
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
  "$out"
}

run_dir() { # $1 = label, $2 = manifest-provided test directory
  local label="$1" dir="$2" rc=0 test_source found=0
  if [[ ! -d "$dir" ]]; then
    infrastructure_error "missing $label tests directory ($dir)"
    return 1
  fi
  for test_source in "$dir"/test_*.c; do
    [[ -e "$test_source" ]] || continue
    found=1
    echo "== [$label] $(basename "$test_source")"
    build_one "$test_source" || rc=1
  done
  if [[ $found -eq 0 ]]; then
    infrastructure_error "no test_*.c in $dir"
    return 1
  fi
  return $rc
}

# Visible suite paths come from each implemented stage's manifest. This keeps
# cumulative testing without reconstructing paths in Bash.
run_visible() {
  local active active_index i stage rc=0 found=0
  active=$(active_stage)
  if ! active_index=$(stage_index "$active"); then
    infrastructure_error "progress state references unknown active stage '$active'"
    return 1
  fi
  for i in "${!STAGES[@]}"; do
    if (( i > active_index )); then
      continue
    fi
    stage="${STAGES[$i]}"
    if ! preflight_stage "$stage"; then
      return 1
    fi
    found=1
    echo "== [visible] $stage"
    run_dir "visible" "$VISIBLE_TESTS" || rc=1
  done
  if [[ $found -eq 0 ]]; then
    infrastructure_error "no visible tests found up to $active"
    return 1
  fi
  return $rc
}

# Certification suite paths also come from every manifest through the active
# stage. This preserves earlier hidden invariants as later stages are added.
run_certification() {
  local active active_index i stage rc=0 found=0
  active=$(active_stage)
  if ! active_index=$(stage_index "$active"); then
    infrastructure_error "progress state references unknown active stage '$active'"
    return 1
  fi
  for i in "${!STAGES[@]}"; do
    if (( i > active_index )); then
      continue
    fi
    stage="${STAGES[$i]}"
    if ! preflight_stage "$stage"; then
      return 1
    fi
    found=1
    echo "== [certification] $stage"
    run_dir "certification" "$CERTIFICATION_TESTS" || rc=1
  done
  if [[ $found -eq 0 ]]; then
    infrastructure_error "no certification tests found up to $active"
    return 1
  fi
  return $rc
}

# ------------------------------------------------------------- commands ---

cmd_start() {
  state_init
  local active i
  active=$(active_stage)
  if ! i=$(stage_index "$active"); then
    infrastructure_error "progress state references unknown active stage '$active'"
    return 1
  fi
  echo "Zero to Expert — Emulator Course"
  echo "Console: $CONSOLE_TITLE"
  echo "Active stage: $active (${STAGE_NAMES[$i]})"
  echo ""
  echo "Commands:"
  echo "  make start          course status"
  echo "  make stage          active stage brief"
  echo "  make test           visible tests"
  echo "  make challenge      active stage challenge"
  echo "  make submit         structural preflight + visible + challenge + certification"
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
  local active
  active=$(active_stage)
  preflight_stage "$active" || return 1
  cat "$STAGE_DIR/STAGE.md"
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
  local active rc=0
  active=$(active_stage)
  if ! preflight_stage "$active"; then
    echo "CHALLENGE: FAIL"
    return 1
  fi
  echo "Running challenge ($CONSOLE_TITLE $active)..."
  run_dir "challenge" "$CHALLENGE_TESTS" || rc=1
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
  local active rc=0
  active=$(active_stage)
  echo "Running certification tests ($CONSOLE_TITLE through $active)..."
  run_certification || rc=1
  echo ""
  if [[ $rc -eq 0 ]]; then
    echo "CERTIFICATION TESTS: PASS"
  else
    echo "CERTIFICATION TESTS: FAIL (see above)"
  fi
  return $rc
}

cmd_submit() {
  state_init
  local active next rc=0
  active=$(active_stage)
  echo "SUBMIT: $CONSOLE_TITLE $active"
  echo ""
  echo "Running structural preflight..."
  if ! preflight_stage "$active"; then
    echo "STRUCTURAL PREFLIGHT: FAIL"
    echo "NOT CERTIFIED: course infrastructure is incomplete or invalid"
    return 1
  fi
  echo "STRUCTURAL PREFLIGHT: PASS"
  echo ""

  cmd_test || rc=1
  echo ""
  cmd_challenge || rc=1
  echo ""
  cmd_hidden || rc=1
  echo ""
  if [[ $rc -eq 0 ]]; then
    set_stage_status "$active" "certified"
    next=$(next_stage_id "$active")
    if [[ -n "$next" ]]; then
      set_stage_status "$next" "unlocked"
    fi
    echo "CERTIFIED: $active"
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
  local active i stage status marker
  active=$(active_stage)
  echo "$CONSOLE_TITLE — progress"
  echo ""
  for i in "${!STAGES[@]}"; do
    stage="${STAGES[$i]}"
    status=$(stage_status "$stage")
    marker=" "
    if [[ "$stage" == "$active" ]]; then
      marker="*"
    fi
    printf "  %s %s  %-30s %s\n" "$marker" "$stage" "${STAGE_NAMES[$i]}" "$status"
  done
}

cmd_next() {
  state_init
  local active next status
  active=$(active_stage)
  next=$(next_stage_id "$active")
  if [[ -z "$next" ]]; then
    echo "No more stages."
    return 0
  fi
  status=$(stage_status "$next")
  if [[ "$status" != "unlocked" && "$status" != "active" ]]; then
    echo "$next is locked. Certify $active first: make submit"
    return 1
  fi
  if ! stage_is_implemented "$next"; then
    echo "$next is unlocked, but its materials are not generated yet."
    echo "Ask the agent to create $next for $CONSOLE_TITLE as a separate task."
    return 1
  fi
  preflight_stage "$next" || return 1
  set_active "$next"
  set_stage_status "$next" "active"
  echo "Active stage: $next"
  echo "Run: make stage"
}

cmd_doctor() {
  local doctor="$SCRIPT_DIR/tools/doctor.py"
  require_python || return 1
  if [[ ! -f "$doctor" ]]; then
    infrastructure_error "missing doctor utility ($doctor)"
    return 1
  fi
  python3 "$doctor"
}

cmd_verify_course() {
  require_python || return 1
  python3 "$METADATA_TOOL"
}

cmd_reset() {
  echo "Resetting course progress (keeps src/, course/, tests/ intact)..."
  if [[ -f "$STATE_FILE" ]]; then
    echo "  removing $STATE_FILE"
    rm -f "$STATE_FILE"
  fi
  if [[ -d "$BUILD_DIR" ]]; then
    echo "  removing $BUILD_DIR/"
    rm -rf "$BUILD_DIR"
  fi
  state_init
  echo "Progress reset. Active stage: $(active_stage)"
  echo "Student source in src/ was not touched."
}

load_runtime_metadata || exit 1

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
