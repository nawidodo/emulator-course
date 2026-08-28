#!/usr/bin/env python3
"""Regression tests for fail-closed course-engine behavior."""

import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VERIFY = Path("tools/verify_course.py")


def copy_ignore(_directory, names):
    return {name for name in names if name in {".git", "build", "__pycache__"}}


def copied_repository(destination):
    repository = destination / "repo"
    shutil.copytree(ROOT, repository, ignore=copy_ignore)
    return repository


class CourseEngineRegressionTests(unittest.TestCase):
    def verify_copy(self, mutate):
        with tempfile.TemporaryDirectory(prefix="emulator-course-engine-") as directory:
            repository = copied_repository(Path(directory))
            mutate(repository)
            return subprocess.run(
                [sys.executable, str(VERIFY)],
                cwd=repository,
                capture_output=True,
                text=True,
                timeout=60,
            )

    def assert_rejected(self, mutate):
        result = self.verify_copy(mutate)
        self.assertNotEqual(
            result.returncode,
            0,
            msg="validator accepted invalid repository:\n" + result.stdout + result.stderr,
        )

    def test_clean_repository_is_accepted(self):
        result = subprocess.run(
            [sys.executable, str(VERIFY)],
            cwd=ROOT,
            capture_output=True,
            text=True,
            timeout=60,
        )
        self.assertEqual(
            result.returncode,
            0,
            msg="validator rejected clean repository:\n" + result.stdout + result.stderr,
        )

    def test_invalid_manifest_json_is_rejected(self):
        def mutate(repository):
            (repository / "course/chip8/CHIP8-01/manifest.json").write_text(
                "{\n", encoding="utf-8"
            )

        self.assert_rejected(mutate)

    def test_missing_visible_suite_is_rejected(self):
        def mutate(repository):
            shutil.rmtree(repository / "tests/chip8/CHIP8-01")

        self.assert_rejected(mutate)

    def test_empty_certification_suite_is_rejected(self):
        def mutate(repository):
            suite = repository / "tests/hidden/chip8/CHIP8-01"
            for test_source in suite.glob("test_*.c"):
                test_source.unlink()

        self.assert_rejected(mutate)

    def test_implemented_stage_gap_is_rejected(self):
        def mutate(repository):
            path = repository / "config/consoles/chip8.json"
            data = json.loads(path.read_text(encoding="utf-8"))
            for stage in data["stages"]:
                if stage["id"] == "CHIP8-03":
                    stage["implemented"] = True
            path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")

        self.assert_rejected(mutate)

    def test_future_prerequisite_is_rejected(self):
        def mutate(repository):
            path = repository / "course/chip8/CHIP8-01/manifest.json"
            data = json.loads(path.read_text(encoding="utf-8"))
            data["prerequisites"] = ["CHIP8-02"]
            path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")

        self.assert_rejected(mutate)

    def test_host_time_call_in_core_is_rejected(self):
        def mutate(repository):
            path = repository / "src/chip8/chip8.c"
            original = path.read_text(encoding="utf-8")
            path.write_text(
                "#include <time.h>\n"
                + original
                + "\nunsigned review_host_time(void) { return (unsigned)time(0); }\n",
                encoding="utf-8",
            )

        self.assert_rejected(mutate)

    def test_rand_call_in_core_is_rejected(self):
        def mutate(repository):
            path = repository / "src/chip8/chip8.c"
            original = path.read_text(encoding="utf-8")
            path.write_text(
                "#include <stdlib.h>\n"
                + original
                + "\nunsigned review_host_rng(void) { return (unsigned)rand(); }\n",
                encoding="utf-8",
            )

        self.assert_rejected(mutate)

    def test_arc4random_call_in_core_is_rejected(self):
        def mutate(repository):
            path = repository / "src/chip8/chip8.c"
            original = path.read_text(encoding="utf-8")
            path.write_text(
                "extern unsigned int arc4random(void);\n"
                + original
                + "\nunsigned review_host_rng(void) { return arc4random(); }\n",
                encoding="utf-8",
            )

        self.assert_rejected(mutate)

    def test_overlapping_ownership_pattern_is_rejected(self):
        def mutate(repository):
            path = repository / "course/chip8/CHIP8-01/manifest.json"
            data = json.loads(path.read_text(encoding="utf-8"))
            data["ownership"]["agent_owned"].append("src/**")
            path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")

        self.assert_rejected(mutate)

    def test_missing_required_source_is_rejected(self):
        def mutate(repository):
            (repository / "src/chip8/chip8.h").unlink()

        self.assert_rejected(mutate)

    def test_certification_runner_is_cumulative(self):
        with tempfile.TemporaryDirectory(prefix="emulator-course-cumulative-") as directory:
            repository = copied_repository(Path(directory))
            config_path = repository / "config/consoles/chip8.json"
            config = json.loads(config_path.read_text(encoding="utf-8"))
            for stage in config["stages"]:
                if stage["id"] == "CHIP8-02":
                    stage["implemented"] = True
            config_path.write_text(json.dumps(config, indent=2) + "\n", encoding="utf-8")

            passing_test = "int main(void) { return 0; }\n"
            stage_one_cert = repository / "tests/hidden/chip8/CHIP8-01/test_hidden_state.c"
            stage_one_cert.write_text(passing_test, encoding="utf-8")

            stage_two_root = repository / "course/chip8/CHIP8-02"
            stage_two_root.mkdir(parents=True)
            (stage_two_root / "STAGE.md").write_text(
                "# Temporary cumulative certification fixture\n", encoding="utf-8"
            )
            stage_two_manifest = json.loads(
                (repository / "course/chip8/CHIP8-01/manifest.json").read_text(encoding="utf-8")
            )
            stage_two_manifest.update(
                {
                    "stage": "CHIP8-02",
                    "title": "Memory and ROM Loading",
                    "prerequisites": ["CHIP8-01"],
                    "stage_dir": "course/chip8/CHIP8-02",
                    "visible_tests": "tests/chip8/CHIP8-02",
                    "challenge_tests": "tests/challenge/chip8/CHIP8-02",
                    "certification_tests": "tests/hidden/chip8/CHIP8-02",
                }
            )
            (stage_two_root / "manifest.json").write_text(
                json.dumps(stage_two_manifest, indent=2) + "\n", encoding="utf-8"
            )
            for suite in (
                "tests/chip8/CHIP8-02",
                "tests/challenge/chip8/CHIP8-02",
                "tests/hidden/chip8/CHIP8-02",
            ):
                suite_path = repository / suite
                suite_path.mkdir(parents=True)
                (suite_path / "test_passing.c").write_text(passing_test, encoding="utf-8")

            state = repository / ".progress/state"
            state.parent.mkdir(parents=True, exist_ok=True)
            state.write_text(
                "active=CHIP8-02\nCHIP8-01=certified\nCHIP8-02=active\n"
                + "\n".join(
                    f"{stage['id']}=pending"
                    for stage in config["stages"]
                    if stage["id"] not in {"CHIP8-01", "CHIP8-02"}
                )
                + "\n",
                encoding="utf-8",
            )

            result = subprocess.run(
                ["bash", "course.sh", "hidden"],
                cwd=repository,
                capture_output=True,
                text=True,
                timeout=60,
            )
            self.assertEqual(
                result.returncode,
                0,
                msg="cumulative certification runner failed:\n" + result.stdout + result.stderr,
            )
            first = result.stdout.find("== [certification] CHIP8-01")
            second = result.stdout.find("== [certification] CHIP8-02")
            self.assertGreaterEqual(first, 0, msg=result.stdout)
            self.assertGreater(second, first, msg=result.stdout)


if __name__ == "__main__":
    unittest.main()
