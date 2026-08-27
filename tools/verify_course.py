#!/usr/bin/env python3
"""
verify_course.py — validate that course material itself is structurally valid.

Checks (fail-closed):
  STAGE.md exists
  stage manifest exists (manifest.json) and is valid JSON
  visible tests exist
  challenge tests exist
  certification tests exist
  required starter files exist
  tests compile
  ownership rules are internally consistent
  config files exist and are consistent

Exit 0 if all checks pass, 1 if any fail (COURSE INFRASTRUCTURE ERROR).
"""
import json
import os
import sys
import subprocess
import glob

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONSOLE = "chip8"

def fail(msg):
    print(f"COURSE INFRASTRUCTURE ERROR: {msg}", file=sys.stderr)
    return False

def ok(msg):
    print(f"  ok: {msg}")
    return True

def check_exists(path, label):
    full = os.path.join(ROOT, path)
    if not os.path.exists(full):
        fail(f"missing {label} ({path})")
        return False
    return ok(f"{label} ({path})")

def main():
    errors = 0
    print("verify-course: validating course material integrity")
    print(f"  root: {ROOT}")
    print("")

    # 1. Config files
    print("[1/7] config")
    for p in ["config/course.json", "config/consoles/chip8.json"]:
        if not check_exists(p, "config"):
            errors += 1
        else:
            try:
                json.load(open(os.path.join(ROOT, p)))
            except Exception as e:
                fail(f"invalid JSON {p}: {e}")
                errors += 1
    # STAGE.md exists (for generated stages)
    # Discover generated stages: those with course/<console>/*/STAGE.md
    generated = []
    stage_dirs = glob.glob(os.path.join(ROOT, f"course/{CONSOLE}/*/STAGE.md"))
    for md in stage_dirs:
        stage_id = os.path.basename(os.path.dirname(md))
        generated.append(stage_id)
    if not generated:
        fail("no STAGE.md found for any stage")
        errors += 1
    else:
        for s in sorted(generated):
            ok(f"STAGE.md for {s} (course/{CONSOLE}/{s}/STAGE.md)")

    print("")
    print("[2/7] stage manifests")
    # Every generated stage should have manifest.json
    import json as _json
    manifests_ok = True
    for s in sorted(generated):
        mf = os.path.join(ROOT, f"course/{CONSOLE}/{s}/manifest.json")
        if not os.path.exists(mf):
            fail(f"missing stage manifest for {s} ({os.path.relpath(mf, ROOT)})")
            errors += 1
            manifests_ok = False
            continue
        try:
            data = _json.load(open(mf))
        except Exception as e:
            fail(f"invalid manifest JSON for {s}: {e}")
            errors += 1
            manifests_ok = False
            continue
        # Validate required fields
        for field in ["stage", "console", "prerequisites", "required_files", "visible_tests", "challenge_tests", "certification_tests", "ownership"]:
            if field not in data:
                fail(f"manifest for {s} missing field '{field}'")
                errors += 1
        if data.get("stage") != s:
            fail(f"manifest stage id mismatch for {s}: {data.get('stage')}")
            errors += 1
        else:
            ok(f"manifest for {s}")

    print("")
    print("[3/7] required tests and starter files")
    # Load manifests to know expected paths, or fallback to convention
    for s in sorted(generated):
        mf = os.path.join(ROOT, f"course/{CONSOLE}/{s}/manifest.json")
        if os.path.exists(mf):
            try:
                data = json.load(open(mf))
            except:
                continue
            for key, label in [("visible_tests", "visible tests"), ("challenge_tests", "challenge tests"), ("certification_tests", "certification tests")]:
                p = data.get(key)
                if not p:
                    continue
                full = os.path.join(ROOT, p)
                if not os.path.isdir(full):
                    fail(f"missing {label} for {s} ({p})")
                    errors += 1
                else:
                    c_files = glob.glob(os.path.join(full, "test_*.c"))
                    if not c_files:
                        fail(f"no test_*.c in {label} for {s} ({p})")
                        errors += 1
                    else:
                        ok(f"{label} for {s} ({len(c_files)} file(s))")
            for req in data.get("required_files", []):
                if not check_exists(req, f"required starter file for {s}"):
                    errors += 1
        else:
            # fallback convention
            for label, p in [("visible", f"tests/{CONSOLE}/{s}"), ("challenge", f"tests/challenge/{CONSOLE}/{s}"), ("certification", f"tests/hidden/{CONSOLE}/{s}")]:
                if not os.path.isdir(os.path.join(ROOT, p)):
                    fail(f"missing {label} tests for {s} ({p})")
                    errors += 1

    print("")
    print("[4/7] tests compile")
    # Try to compile each visible/challenge/certification test
    all_tests = []
    for s in sorted(generated):
        for kind in [f"tests/{CONSOLE}/{s}", f"tests/challenge/{CONSOLE}/{s}", f"tests/hidden/{CONSOLE}/{s}"]:
            for t in glob.glob(os.path.join(ROOT, kind, "test_*.c")):
                all_tests.append(t)
    if not all_tests:
        fail("no test files found to compile")
        errors += 1
    else:
        core = glob.glob(os.path.join(ROOT, f"src/{CONSOLE}/*.c"))
        if not core:
            fail(f"no core sources in src/{CONSOLE}/")
            errors += 1
        else:
            for t in sorted(all_tests):
                rel = os.path.relpath(t, ROOT)
                cmd = ["cc", "-std=c11", "-Wall", "-Wextra", "-Werror", "-O1", "-g", f"-I{ROOT}/src", f"-I{ROOT}/tools", t] + core + ["-o", "/tmp/verify_course_test.bin"]
                proc = subprocess.run(cmd, capture_output=True, text=True)
                if proc.returncode != 0:
                    fail(f"compile failed for {rel}: {proc.stderr.strip().splitlines()[-1] if proc.stderr else 'unknown'}")
                    errors += 1
                else:
                    ok(f"compiles {rel}")

    print("")
    print("[5/7] ownership rules")
    ownership_path = os.path.join(ROOT, "OWNERSHIP.md")
    if not os.path.exists(ownership_path):
        fail("missing OWNERSHIP.md")
        errors += 1
    else:
        txt = open(ownership_path).read()
        for kw in ["student-owned", "agent-owned", "grader-owned"]:
            if kw not in txt.lower():
                fail(f"OWNERSHIP.md missing '{kw}'")
                errors += 1
            else:
                ok(f"OWNERSHIP.md mentions {kw}")
        # check manifest ownership consistency
        for s in sorted(generated):
            mf = os.path.join(ROOT, f"course/{CONSOLE}/{s}/manifest.json")
            if not os.path.exists(mf):
                continue
            try:
                data = json.load(open(mf))
            except:
                continue
            ownership = data.get("ownership", {})
            if not all(k in ownership for k in ["student_owned", "agent_owned", "grader_owned"]):
                fail(f"manifest for {s} missing ownership partitions")
                errors += 1
            else:
                ok(f"manifest ownership for {s}")

    print("")
    print("[6/7] config consistency")
    # Verify config/course.json stages match hardcoded (warn) and consoles
    try:
        course_cfg = json.load(open(os.path.join(ROOT, "config/course.json")))
        if CONSOLE not in course_cfg.get("consoles", []):
            fail(f"config/course.json missing console {CONSOLE}")
            errors += 1
        else:
            ok("config/course.json consoles")
        # Check that every generated stage is listed in config
        for s in generated:
            if s not in course_cfg.get("stages", []):
                fail(f"generated stage {s} not listed in config/course.json")
                errors += 1
    except Exception as e:
        fail(f"config check failed: {e}")
        errors += 1

    print("")
    print("[7/7] stage-specific correctness (CHIP8-01)")
    # Spot-check CHIP8-01 spec if present
    if "CHIP8-01" in generated:
        h = os.path.join(ROOT, "src/chip8/chip8.h")
        if os.path.exists(h):
            txt = open(h).read()
            if "V0..VF" not in txt:
                fail("src/chip8/chip8.h should mention V0..VF")
                errors += 1
            else:
                ok("chip8.h mentions V0..VF")
            if "stack[12]" not in txt:
                fail("src/chip8/chip8.h should have stack[12] for this course")
                errors += 1
            else:
                ok("chip8.h stack depth 12")
            if "memory[4096]" not in txt and "memory[0x1000]" not in txt:
                fail("src/chip8/chip8.h memory should be 4096 bytes")
                errors += 1
            else:
                ok("chip8.h memory 4096")

        md = os.path.join(ROOT, "course/chip8/CHIP8-01/STAGE.md")
        if os.path.exists(md):
            txt = open(md).read()
            if "V0..VE" in txt:
                fail("STAGE.md still contains V0..VE (should be V0..VF)")
                errors += 1
            if "13 x 16-bit" in txt:
                fail("STAGE.md still claims 13-deep stack")
                errors += 1
            if "quarter of the RAM" in txt:
                fail("STAGE.md still has incorrect quarter-RAM claim")
                errors += 1
            else:
                ok("STAGE.md factual corrections")

    print("")
    if errors == 0:
        print("verify-course: PASS — course material is structurally valid")
        return 0
    else:
        print(f"verify-course: FAIL — {errors} issue(s) found", file=sys.stderr)
        return 1

if __name__ == "__main__":
    sys.exit(main())
