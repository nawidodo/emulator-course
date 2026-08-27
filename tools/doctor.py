#!/usr/bin/env python3
"""
doctor.py — validate the local dev environment for the CHIP-8 course.

Checks (current CHIP-8 portion):
  cc, make, bash, python3
Extensible for future Metal: checks xcrun, metal, xcodebuild optionally
when MTL tracks are present.

Exit 0 if all required tools present, 1 otherwise.
"""
import shutil
import subprocess
import sys
import os

REQUIRED = [
    ("cc", ["cc", "--version"]),
    ("make", ["make", "--version"]),
    ("bash", ["bash", "--version"]),
    ("python3", ["python3", "--version"]),
]

OPTIONAL_METAL = [
    ("xcrun", ["xcrun", "--version"]),
    ("xcodebuild", ["xcodebuild", "-version"]),
]

def check(cmd, args):
    path = shutil.which(cmd)
    if not path:
        print(f"  missing: {cmd}", file=sys.stderr)
        return False
    try:
        out = subprocess.run(args, capture_output=True, text=True, timeout=5)
        ver = (out.stdout or out.stderr).strip().splitlines()[0] if (out.stdout or out.stderr) else path
        print(f"  ok: {cmd} ({ver}) [{path}]")
        return True
    except Exception as e:
        print(f"  ok: {cmd} [{path}] (version check failed: {e})")
        return True

def main():
    print("doctor: validating development environment")
    print("")
    print("[required]")
    ok = True
    for cmd, args in REQUIRED:
        if not check(cmd, args):
            ok = False

    # Verify C11 compilation works with current flags
    print("")
    print("[self-test: C11 compile]")
    import tempfile, pathlib
    src = "#include <stdint.h>\nint main(void){return 0;}\n"
    with tempfile.TemporaryDirectory() as td:
        c = pathlib.Path(td) / "t.c"
        o = pathlib.Path(td) / "t.bin"
        c.write_text(src)
        proc = subprocess.run(["cc", "-std=c11", "-Wall", "-Wextra", "-Werror", "-O1", "-g", str(c), "-o", str(o)], capture_output=True, text=True)
        if proc.returncode != 0:
            print(f"  fail: C11 compile self-test: {proc.stderr.strip()}", file=sys.stderr)
            ok = False
        else:
            print("  ok: C11 compile (cc -std=c11 -Wall -Wextra -Werror)")

    # Optional Metal checks — only warn, don't fail, unless MLT stages are active
    # We detect if course has generated MTL stages by looking for stage dirs
    has_mtl = any(os.path.exists(os.path.join("course", "chip8", s, "STAGE.md")) for s in ["MTL-00", "MTL-01"])
    has_mtl = has_mtl or os.path.exists("config/consoles/chip8.json") and "MTL" in open("config/consoles/chip8.json").read() if os.path.exists("config/consoles/chip8.json") else has_mtl
    print("")
    print("[optional: Metal toolchain]")
    metal_ok = True
    for cmd, args in OPTIONAL_METAL:
        path = shutil.which(cmd)
        if not path:
            # only report as missing if MTL stages exist
            if has_mtl:
                print(f"  missing (optional for CHIP-8, required for Metal): {cmd}")
                metal_ok = False
            else:
                print(f"  optional not found: {cmd} (ok for CHIP-8)")
        else:
            check(cmd, args)

    print("")
    if ok:
        print("doctor: PASS — required tools present")
        if not metal_ok and has_mtl:
            print("doctor: note: Metal toolchain incomplete (needed for MTL tracks)", file=sys.stderr)
        return 0
    else:
        print("doctor: FAIL — missing required tools", file=sys.stderr)
        return 1

if __name__ == "__main__":
    sys.exit(main())
