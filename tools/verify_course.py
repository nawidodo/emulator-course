#!/usr/bin/env python3
"""Validate course metadata and stage assets without external packages.

Default mode validates every implemented stage and compiles its tests.
Machine-readable modes are consumed by course.sh:

    --runtime-metadata
    --stage-assets CONSOLE STAGE

All validation is fail-closed. Diagnostics go to stderr in machine-readable
modes so stdout remains parseable by the Bash runner.
"""

import argparse
import glob
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parent.parent
COURSE_CONFIG = Path("config/course.json")
OWNERSHIP_CATEGORIES = ("student_owned", "agent_owned", "grader_owned")


class Reporter:
    def __init__(self, verbose=True):
        self.errors = 0
        self.verbose = verbose

    @staticmethod
    def _display(value):
        text = repr(value)
        return text if len(text) <= 160 else text[:157] + "..."

    def error(self, path, field, expected, actual):
        self.errors += 1
        location = f"{path}: field '{field}'" if field else str(path)
        print(
            "COURSE INFRASTRUCTURE ERROR: "
            f"[FAIL] {location}: expected {expected}; actual {self._display(actual)}",
            file=sys.stderr,
        )

    def fail(self, message):
        self.errors += 1
        print(f"COURSE INFRASTRUCTURE ERROR: [FAIL] {message}", file=sys.stderr)

    def ok(self, message):
        if self.verbose:
            print(f"  [OK] {message}")

    def skip(self, message):
        if self.verbose:
            print(f"  [SKIP] {message}")


def repo_path(path):
    return ROOT / path


def is_safe_relative_path(value):
    if not isinstance(value, str) or not value:
        return False
    path = PurePosixPath(value)
    return not path.is_absolute() and ".." not in path.parts and "\x00" not in value


def read_json(path, reporter):
    full = repo_path(path)
    if not full.is_file():
        reporter.error(path, None, "existing JSON file", "missing")
        return None
    try:
        with full.open(encoding="utf-8") as handle:
            value = json.load(handle)
    except json.JSONDecodeError as exc:
        reporter.error(path, None, "valid JSON", f"{exc.msg} at line {exc.lineno}, column {exc.colno}")
        return None
    except OSError as exc:
        reporter.error(path, None, "readable JSON file", str(exc))
        return None
    if not isinstance(value, dict):
        reporter.error(path, "<root>", "object", type(value).__name__)
        return None
    return value


def require_string(data, field, path, reporter):
    value = data.get(field)
    if not isinstance(value, str) or not value or any(c in value for c in "\t\r\n"):
        reporter.error(path, field, "non-empty string without tabs/newlines", value)
        return None
    return value


def require_bool(data, field, path, reporter):
    value = data.get(field)
    if type(value) is not bool:
        reporter.error(path, field, "boolean", value)
        return None
    return value


def require_string_list(data, field, path, reporter, allow_empty=True):
    value = data.get(field)
    if not isinstance(value, list):
        reporter.error(path, field, "list of strings", value)
        return None
    if not allow_empty and not value:
        reporter.error(path, field, "non-empty list of strings", value)
        return None
    bad = [(index, item) for index, item in enumerate(value) if not isinstance(item, str) or not item]
    if bad:
        index, item = bad[0]
        reporter.error(path, f"{field}[{index}]", "non-empty string", item)
        return None
    return value


def validate_repo_path(data, field, path, reporter):
    value = require_string(data, field, path, reporter)
    if value is not None and not is_safe_relative_path(value):
        reporter.error(path, field, "safe repository-relative path", value)
        return None
    return value


def load_catalog(reporter):
    course = read_json(COURSE_CONFIG, reporter)
    if course is None:
        return None

    active_console = require_string(course, "active_console", COURSE_CONFIG, reporter)
    console_entries = course.get("consoles")
    if not isinstance(console_entries, list) or not console_entries:
        reporter.error(COURSE_CONFIG, "consoles", "non-empty list of console objects", console_entries)
        return None

    consoles = {}
    for index, entry in enumerate(console_entries):
        field = f"consoles[{index}]"
        if not isinstance(entry, dict):
            reporter.error(COURSE_CONFIG, field, "object with id and config", entry)
            continue
        console_id = require_string(entry, "id", f"{COURSE_CONFIG}:{field}", reporter)
        config_path = validate_repo_path(entry, "config", f"{COURSE_CONFIG}:{field}", reporter)
        if console_id is None or config_path is None:
            continue
        if console_id in consoles:
            reporter.error(COURSE_CONFIG, f"{field}.id", "unique console id", console_id)
            continue

        console_config = read_json(Path(config_path), reporter)
        if console_config is None:
            continue
        declared_id = require_string(console_config, "console", config_path, reporter)
        title = require_string(console_config, "title", config_path, reporter)
        if declared_id is not None and declared_id != console_id:
            reporter.error(config_path, "console", repr(console_id), declared_id)

        raw_stages = console_config.get("stages")
        if not isinstance(raw_stages, list) or not raw_stages:
            reporter.error(config_path, "stages", "non-empty ordered list of stage objects", raw_stages)
            raw_stages = []

        stages = []
        seen = set()
        for stage_index, raw_stage in enumerate(raw_stages):
            stage_field = f"stages[{stage_index}]"
            if not isinstance(raw_stage, dict):
                reporter.error(config_path, stage_field, "stage object", raw_stage)
                continue
            stage_id = require_string(raw_stage, "id", f"{config_path}:{stage_field}", reporter)
            stage_title = require_string(raw_stage, "title", f"{config_path}:{stage_field}", reporter)
            implemented = require_bool(raw_stage, "implemented", f"{config_path}:{stage_field}", reporter)
            if stage_id is None or stage_title is None or implemented is None:
                continue
            if stage_id in seen:
                reporter.error(config_path, f"{stage_field}.id", "unique stage id", stage_id)
                continue
            seen.add(stage_id)
            stages.append({"id": stage_id, "title": stage_title, "implemented": implemented})

        consoles[console_id] = {
            "id": console_id,
            "path": config_path,
            "title": title,
            "stages": stages,
            "stage_index": {stage["id"]: i for i, stage in enumerate(stages)},
        }

    if active_console is not None and active_console not in consoles:
        reporter.error(COURSE_CONFIG, "active_console", "id present in consoles", active_console)

    if reporter.errors:
        return None
    reporter.ok(f"course catalog ({COURSE_CONFIG})")
    for console in consoles.values():
        reporter.ok(f"console catalog ({console['path']})")
    return {"active_console": active_console, "consoles": consoles}


def validate_manifest(catalog, console_id, stage_id, reporter, require_assets=True):
    console = catalog["consoles"].get(console_id)
    if console is None:
        reporter.error(COURSE_CONFIG, "active_console", "known console id", console_id)
        return None
    stage_position = console["stage_index"].get(stage_id)
    if stage_position is None:
        reporter.error(console["path"], "stages", "stage id present in ordered catalog", stage_id)
        return None
    stage_meta = console["stages"][stage_position]
    if not stage_meta["implemented"]:
        reporter.error(console["path"], f"stages[{stage_position}].implemented", "true for runnable stage", False)
        return None

    manifest_path = Path(f"course/{console_id}/{stage_id}/manifest.json")
    manifest = read_json(manifest_path, reporter)
    if manifest is None:
        return None

    declared_stage = require_string(manifest, "stage", manifest_path, reporter)
    declared_console = require_string(manifest, "console", manifest_path, reporter)
    title = require_string(manifest, "title", manifest_path, reporter)
    if declared_stage is not None and declared_stage != stage_id:
        reporter.error(manifest_path, "stage", repr(stage_id), declared_stage)
    if declared_console is not None and declared_console != console_id:
        reporter.error(manifest_path, "console", repr(console_id), declared_console)
    if title is not None and title != stage_meta["title"]:
        reporter.error(manifest_path, "title", repr(stage_meta["title"]), title)

    prerequisites = require_string_list(manifest, "prerequisites", manifest_path, reporter)
    required_files = require_string_list(manifest, "required_files", manifest_path, reporter, allow_empty=False)
    path_fields = {}
    for field in ("stage_dir", "visible_tests", "challenge_tests", "certification_tests"):
        path_fields[field] = validate_repo_path(manifest, field, manifest_path, reporter)

    expected_stage_dir = f"course/{console_id}/{stage_id}"
    if path_fields.get("stage_dir") is not None and path_fields["stage_dir"] != expected_stage_dir:
        reporter.error(manifest_path, "stage_dir", repr(expected_stage_dir), path_fields["stage_dir"])

    if required_files is not None:
        for index, value in enumerate(required_files):
            if not is_safe_relative_path(value):
                reporter.error(manifest_path, f"required_files[{index}]", "safe repository-relative path", value)

    if prerequisites is not None:
        for index, prerequisite in enumerate(prerequisites):
            prerequisite_position = console["stage_index"].get(prerequisite)
            if prerequisite_position is None:
                reporter.error(
                    manifest_path,
                    f"prerequisites[{index}]",
                    "stage id present in console catalog",
                    prerequisite,
                )
            elif prerequisite_position >= stage_position:
                reporter.error(
                    manifest_path,
                    f"prerequisites[{index}]",
                    f"stage preceding {stage_id}",
                    prerequisite,
                )

    ownership = manifest.get("ownership")
    ownership_values = {}
    if not isinstance(ownership, dict):
        reporter.error(manifest_path, "ownership", "object", ownership)
    else:
        for category in OWNERSHIP_CATEGORIES:
            ownership_values[category] = require_string_list(
                ownership, category, f"{manifest_path}:ownership", reporter, allow_empty=False
            )
        valid_lists = [values for values in ownership_values.values() if values is not None]
        if len(valid_lists) == len(OWNERSHIP_CATEGORIES):
            owners = {}
            for category, values in ownership_values.items():
                for pattern in values:
                    previous = owners.get(pattern)
                    if previous is not None and previous != category:
                        reporter.error(
                            manifest_path,
                            f"ownership.{category}",
                            f"patterns disjoint from ownership.{previous}",
                            pattern,
                        )
                    owners[pattern] = category

    assets = {
        "manifest": manifest_path.as_posix(),
        "stage_dir": path_fields.get("stage_dir"),
        "required_files": required_files,
        "visible_tests": path_fields.get("visible_tests"),
        "challenge_tests": path_fields.get("challenge_tests"),
        "certification_tests": path_fields.get("certification_tests"),
        "title": stage_meta["title"],
    }

    if require_assets:
        stage_dir = assets["stage_dir"]
        if stage_dir is not None:
            full_stage_dir = repo_path(stage_dir)
            if not full_stage_dir.is_dir():
                reporter.error(manifest_path, "stage_dir", "existing directory", stage_dir)
            else:
                stage_md = full_stage_dir / "STAGE.md"
                if not stage_md.is_file():
                    reporter.error(stage_md.relative_to(ROOT), None, "existing STAGE.md", "missing")

        if required_files is not None:
            for index, required in enumerate(required_files):
                if is_safe_relative_path(required) and not repo_path(required).is_file():
                    reporter.error(manifest_path, f"required_files[{index}]", "existing file", required)

        for field in ("visible_tests", "challenge_tests", "certification_tests"):
            suite = assets[field]
            if suite is None:
                continue
            full_suite = repo_path(suite)
            if not full_suite.is_dir():
                reporter.error(manifest_path, field, "existing test-suite directory", suite)
                continue
            tests = sorted(full_suite.glob("test_*.c"))
            if not tests:
                reporter.error(manifest_path, field, "directory containing test_*.c", suite)

    if reporter.errors:
        return None
    reporter.ok(f"manifest and assets ({manifest_path})")
    return assets


def compile_tests(assets_by_stage, reporter):
    compiler = shutil.which("cc")
    if compiler is None:
        reporter.fail("required executable cc not found")
        reporter.skip("test compilation (cc unavailable)")
        return

    with tempfile.TemporaryDirectory(prefix="emulator-course-verify-") as temp_dir:
        for console_id, stage_id, assets in assets_by_stage:
            core_sources = sorted(glob.glob(str(repo_path(f"src/{console_id}/*.c"))))
            if not core_sources:
                reporter.fail(f"no core sources in src/{console_id}/")
                continue
            suites = (
                assets["visible_tests"],
                assets["challenge_tests"],
                assets["certification_tests"],
            )
            for suite in suites:
                if suite is None:
                    continue
                for test_source in sorted(repo_path(suite).glob("test_*.c")):
                    output = Path(temp_dir) / f"{console_id}-{stage_id}-{test_source.stem}.bin"
                    command = [
                        compiler,
                        "-std=c11",
                        "-Wall",
                        "-Wextra",
                        "-Werror",
                        "-O1",
                        "-g",
                        f"-I{ROOT / 'src'}",
                        f"-I{ROOT / 'tools'}",
                        str(test_source),
                        *core_sources,
                        "-o",
                        str(output),
                    ]
                    try:
                        result = subprocess.run(command, capture_output=True, text=True, timeout=30)
                    except FileNotFoundError:
                        reporter.fail(f"compiler disappeared before compiling {test_source.relative_to(ROOT)}")
                        return
                    except subprocess.TimeoutExpired:
                        reporter.fail(f"compiler timed out for {test_source.relative_to(ROOT)}")
                        continue
                    except OSError as exc:
                        reporter.fail(f"could not run compiler for {test_source.relative_to(ROOT)}: {exc}")
                        continue
                    if result.returncode != 0:
                        detail = result.stderr.strip() or f"exit {result.returncode}"
                        reporter.fail(f"compile failed for {test_source.relative_to(ROOT)}: {detail}")
                    else:
                        reporter.ok(f"compiles {test_source.relative_to(ROOT)}")


def validate_ownership_document(reporter):
    path = Path("OWNERSHIP.md")
    full = repo_path(path)
    if not full.is_file():
        reporter.error(path, None, "existing ownership document", "missing")
        return
    try:
        text = full.read_text(encoding="utf-8")
    except OSError as exc:
        reporter.error(path, None, "readable ownership document", str(exc))
        return
    lowered = text.lower()
    for keyword in ("student-owned", "agent-owned", "grader-owned"):
        if keyword not in lowered:
            reporter.error(path, "content", f"text containing {keyword!r}", "missing")
    if text.count("```") % 2:
        reporter.error(path, "Markdown fences", "matched opening and closing fences", text.count("```"))
    if not reporter.errors:
        reporter.ok("ownership boundaries and Markdown fences")


def validate_chip8_01_facts(catalog, reporter):
    console = catalog["consoles"].get("chip8")
    if console is None or "CHIP8-01" not in console["stage_index"]:
        return
    header = repo_path("src/chip8/chip8.h")
    stage_doc = repo_path("course/chip8/CHIP8-01/STAGE.md")
    if header.is_file():
        text = header.read_text(encoding="utf-8")
        for expected, label in (("V0..VF", "V0..VF"), ("stack[16]", "16-entry stack"), ("memory[4096]", "4096-byte memory")):
            if expected not in text:
                reporter.error(header.relative_to(ROOT), "content", label, "missing")
    if stage_doc.is_file():
        text = stage_doc.read_text(encoding="utf-8")
        for forbidden, label in (
            ("V0..VE", "obsolete V0..VE wording"),
            ("12 x 16-bit", "obsolete 12-entry stack wording"),
            ("13 x 16-bit", "obsolete 13-entry stack wording"),
            ("quarter of the RAM", "incorrect framebuffer arithmetic"),
        ):
            if forbidden in text:
                reporter.error(stage_doc.relative_to(ROOT), "content", f"without {label}", forbidden)
    if not reporter.errors:
        reporter.ok("CHIP8-01 factual invariants")

HOST_TIME_BANNED_CALLS = (
    "sleep",
    "usleep",
    "nanosleep",
    "Sleep",
    "mach_absolute_time",
    "mach_continuous_time",
    "CFAbsoluteTimeGetCurrent",
    "CFAbsoluteTimeGetGregorianDate",
    "CFAbsoluteTimeGetCPUTime",
    "clock_gettime",
    "clock_get_time",
    "clock",
    "gettimeofday",
    "time",
)
HOST_TIME_CALL_PATTERN = re.compile(
    r"\b(?:" + "|".join(re.escape(name) for name in HOST_TIME_BANNED_CALLS) + r")\s*\("
)


def validate_core_host_time_ban(catalog, reporter):
    """Blueprint v1.2.0 §4/§5: the deterministic core must never read host time.

    Scans .c and .h files in every console core with implemented stages.
    Comments and literals are removed before matching, preserving line
    numbers. Any code-position hit rejects verification.
    """
    for console_id, console in catalog["consoles"].items():
        if not any(stage["implemented"] for stage in console["stages"]):
            continue
        core_dir = repo_path(f"src/{console_id}")
        core_sources = sorted(core_dir.glob("*.c")) + sorted(core_dir.glob("*.h"))
        for source in core_sources:
            try:
                text = source.read_text(encoding="utf-8")
            except OSError as exc:
                reporter.error(source.relative_to(ROOT), None, "readable core source", str(exc))
                continue
            code_only = _strip_c_comments_and_strings(text)
            for line_number, line in enumerate(code_only.splitlines(), start=1):
                for match in HOST_TIME_CALL_PATTERN.finditer(line):
                    call = match.group(0).split("(", 1)[0].strip()
                    reporter.error(
                        source.relative_to(ROOT),
                        f"line {line_number}",
                        "core source without host-time calls",
                        f"{call} in: {line.strip()[:120]}",
                    )
    if not reporter.errors:
        reporter.ok("core host-time ban (blueprint v1.2.0 §4/§5)")


def _strip_c_comments_and_strings(text):
    """Remove C comments and literal contents while preserving newlines."""
    out = []
    i = 0
    n = len(text)
    while i < n:
        ch = text[i]
        nxt = text[i + 1] if i + 1 < n else ""
        if ch == "/" and nxt == "*":
            end = text.find("*/", i + 2)
            end = n if end == -1 else end + 2
            out.append(re.sub(r"[^\n]", " ", text[i:end]))
            i = end
        elif ch == "/" and nxt == "/":
            end = text.find("\n", i)
            end = n if end == -1 else end
            out.append(re.sub(r"[^\n]", " ", text[i:end]))
            i = end
        elif ch == '"' or ch == "'":
            quote = ch
            j = i + 1
            while j < n and text[j] != quote:
                j += 2 if text[j] == "\\" else 1
            j = min(j + 1, n)
            out.append(quote + re.sub(r"[^\n]", " ", text[i + 1:j - 1]) + quote)
            i = j
        else:
            out.append(ch)
            i += 1
    return "".join(out)


def emit_runtime_metadata(catalog):
    active = catalog["active_console"]
    console = catalog["consoles"][active]
    print(f"CONSOLE\t{active}\t{console['title']}")
    for stage in console["stages"]:
        implemented = "1" if stage["implemented"] else "0"
        print(f"STAGE\t{stage['id']}\t{stage['title']}\t{implemented}")


def emit_stage_assets(assets):
    print(f"TITLE\t{assets['title']}")
    print(f"STAGE_DIR\t{assets['stage_dir']}")
    for required in assets["required_files"]:
        print(f"REQUIRED_FILE\t{required}")
    print(f"VISIBLE_TESTS\t{assets['visible_tests']}")
    print(f"CHALLENGE_TESTS\t{assets['challenge_tests']}")
    print(f"CERTIFICATION_TESTS\t{assets['certification_tests']}")


def verify_course():
    reporter = Reporter(verbose=True)
    print("verify-course: validating course material integrity")
    print(f"  root: {ROOT}")
    print("")

    catalog = load_catalog(reporter)
    assets_by_stage = []
    if catalog is not None:
        implemented = []
        for console_id, console in catalog["consoles"].items():
            for stage in console["stages"]:
                if stage["implemented"]:
                    implemented.append((console_id, stage["id"]))
        if not implemented:
            reporter.fail("console catalog contains no implemented stages")
        for console_id, stage_id in implemented:
            assets = validate_manifest(catalog, console_id, stage_id, reporter, require_assets=True)
            if assets is not None:
                assets_by_stage.append((console_id, stage_id, assets))

        if assets_by_stage:
            compile_tests(assets_by_stage, reporter)
        else:
            reporter.skip("test compilation (no valid implemented stage assets)")
        validate_chip8_01_facts(catalog, reporter)
        validate_core_host_time_ban(catalog, reporter)

    validate_ownership_document(reporter)
    print("")
    if reporter.errors:
        print(f"verify-course: FAIL — {reporter.errors} issue(s) found", file=sys.stderr)
        return 1
    print("verify-course: PASS — course material is structurally and semantically valid")
    return 0


def parse_args(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--runtime-metadata", action="store_true", help="emit runner metadata")
    group.add_argument(
        "--stage-assets",
        nargs=2,
        metavar=("CONSOLE", "STAGE"),
        help="validate and emit one implemented stage's runtime assets",
    )
    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)
    if not args.runtime_metadata and args.stage_assets is None:
        return verify_course()

    reporter = Reporter(verbose=False)
    catalog = load_catalog(reporter)
    if catalog is None:
        return 1
    if args.runtime_metadata:
        emit_runtime_metadata(catalog)
        return 0

    console_id, stage_id = args.stage_assets
    assets = validate_manifest(catalog, console_id, stage_id, reporter, require_assets=True)
    if assets is None or reporter.errors:
        return 1
    emit_stage_assets(assets)
    return 0


if __name__ == "__main__":
    sys.exit(main())
