#!/usr/bin/env python3
"""Validate required local tools and the C11 compiler path."""

import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent
REQUIRED = (
    ("cc", ("--version",)),
    ("make", ("--version",)),
    ("bash", ("--version",)),
    ("python3", ("--version",)),
)
OPTIONAL_METAL = (
    ("xcrun", ("--version",)),
    ("xcodebuild", ("-version",)),
)


def first_line(text):
    lines = text.strip().splitlines()
    return lines[0] if lines else "version unavailable"


def check_tool(name, arguments, required=True):
    path = shutil.which(name)
    label = "FAIL" if required else "SKIP"
    stream = sys.stderr if required else sys.stdout
    if path is None:
        print(f"  [{label}] {name} not found", file=stream)
        return None
    try:
        result = subprocess.run(
            [path, *arguments],
            capture_output=True,
            text=True,
            timeout=5,
        )
    except FileNotFoundError:
        print(f"  [{label}] {name} disappeared before execution", file=stream)
        return None
    except subprocess.TimeoutExpired:
        print(f"  [{label}] {name} version check timed out", file=stream)
        return None
    except OSError as exc:
        print(f"  [{label}] could not execute {name}: {exc}", file=stream)
        return None
    if result.returncode != 0:
        detail = first_line(result.stderr or result.stdout)
        print(
            f"  [{label}] {name} version check exited {result.returncode}: {detail}",
            file=stream,
        )
        return None
    print(f"  [OK] {name}: {first_line(result.stdout or result.stderr)} [{path}]")
    return path


def metal_is_required():
    config = ROOT / "config/consoles/chip8.json"
    try:
        data = json.loads(config.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError, TypeError):
        return False
    stages = data.get("stages")
    if not isinstance(stages, list):
        return False
    return any(
        isinstance(stage, dict)
        and stage.get("implemented") is True
        and isinstance(stage.get("id"), str)
        and stage["id"].startswith("MTL-")
        for stage in stages
    )


def compiler_self_test(compiler):
    if compiler is None:
        print("  [SKIP] C11 compiler self-test (cc not found)")
        return False
    source = "#include <stdint.h>\nint main(void) { return 0; }\n"
    try:
        with tempfile.TemporaryDirectory(prefix="emulator-course-doctor-") as temp_dir:
            temp = Path(temp_dir)
            input_file = temp / "test.c"
            output_file = temp / "test.bin"
            input_file.write_text(source, encoding="utf-8")
            result = subprocess.run(
                [
                    compiler,
                    "-std=c11",
                    "-Wall",
                    "-Wextra",
                    "-Werror",
                    "-O1",
                    "-g",
                    str(input_file),
                    "-o",
                    str(output_file),
                ],
                capture_output=True,
                text=True,
                timeout=30,
            )
    except FileNotFoundError:
        print("  [FAIL] cc disappeared before C11 compiler self-test", file=sys.stderr)
        return False
    except subprocess.TimeoutExpired:
        print("  [FAIL] C11 compiler self-test timed out", file=sys.stderr)
        return False
    except OSError as exc:
        print(f"  [FAIL] could not run C11 compiler self-test: {exc}", file=sys.stderr)
        return False
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip() or f"exit {result.returncode}"
        print(f"  [FAIL] C11 compiler self-test: {detail}", file=sys.stderr)
        return False
    print("  [OK] C11 compiler self-test")
    return True


def main():
    print("doctor: validating development environment")
    print("")
    print("[required]")
    required_paths = {}
    healthy = True
    for name, arguments in REQUIRED:
        path = check_tool(name, arguments, required=True)
        required_paths[name] = path
        if path is None:
            healthy = False

    print("")
    print("[self-test]")
    if not compiler_self_test(required_paths.get("cc")):
        healthy = False

    print("")
    print("[Metal toolchain]")
    metal_required = metal_is_required()
    for name, arguments in OPTIONAL_METAL:
        path = check_tool(name, arguments, required=metal_required)
        if metal_required and path is None:
            healthy = False

    print("")
    if healthy:
        print("doctor: PASS — required tools present")
        return 0
    print("doctor: FAIL — required tool or self-test unavailable", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
