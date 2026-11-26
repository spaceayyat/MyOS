#!/usr/bin/env python3
"""Unit tests for tests/vm/results.py, the boot-test judge."""
import pathlib
import subprocess
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests/vm"))
import results  # noqa: E402


def log(mode="uefi", drop=(), extra=(), done=True, override=None):
    override = override or {}
    lines = ["\x1b[2J firmware noise MYOS-BEGIN Fedora",
             f"MYOS-FACT firmware {'bios' if mode == 'bios' else 'uefi'}"]
    if mode == "secureboot":
        lines.append("MYOS-FACT secureboot SecureBoot enabled")
    lines += [override.get(n, f"MYOS-CHECK {n} PASS ok")
              for n in sorted(results.REQUIRED) if n not in drop]
    lines += list(extra) + ["MYOS-SHOT"] + (["MYOS-DONE"] if done else [])
    return "\r\n".join(lines) + "\r\n"


class Judge(unittest.TestCase):
    def assert_problem(self, text, serial, mode="uefi"):
        problems = results.evaluate(serial, mode)
        self.assertTrue(any(text in p for p in problems), problems)

    def test_all_pass_in_every_mode(self):
        for mode in ("bios", "uefi", "secureboot"):
            self.assertEqual(results.evaluate(log(mode), mode), [])
        self.assertEqual(results.passed_checks(log()), len(results.REQUIRED))

    def test_failed_check(self):
        serial = log(override={"https": "MYOS-CHECK https FAIL timeout"})
        self.assert_problem("check failed: https timeout", serial)

    def test_missing_check(self):
        self.assert_problem("check missing: kwin", log(drop={"kwin"}))

    def test_old_reversed_order_is_rejected(self):
        serial = log(override={"kwin": "MYOS-CHECK PASS kwin"})
        self.assert_problem("malformed check line", serial)
        self.assert_problem("check missing: kwin", serial)

    def test_unknown_status_check_and_record(self):
        self.assert_problem("malformed", log(extra=["MYOS-CHECK kwin MAYBE"]))
        self.assert_problem("unknown check", log(extra=["MYOS-CHECK x PASS"]))
        self.assert_problem("unexpected output", log(extra=["MYOS-WAT 1"]))

    def test_duplicate_cannot_hide_a_failure(self):
        serial = log(override={"kwin": "MYOS-CHECK kwin FAIL"},
                     extra=["MYOS-CHECK kwin PASS"])
        self.assert_problem("check failed: kwin", serial)
        self.assert_problem("reported twice", serial)

    def test_boot_failures(self):
        self.assert_problem("never started", "")
        self.assert_problem("Kernel panic", "Kernel panic - not syncing\n")
        self.assert_problem("no MYOS-DONE", log(done=False))

    def test_wrong_firmware_and_secure_boot_off(self):
        self.assert_problem("expected bios", log("uefi"), "bios")
        self.assert_problem("Secure Boot is not enabled", log("uefi"),
                            "secureboot")

    def test_guest_script_reports_exactly_the_required_checks(self):
        script = (ROOT / "tests/vm/guest-check.sh").read_text()
        names = {line.split()[1] for line in script.splitlines()
                 if line.startswith("check ")}
        self.assertEqual(names, set(results.REQUIRED))

    def test_guest_output_format_matches_parser(self):
        """Run the real shell functions and parse what they print."""
        script = (ROOT / "tests/vm/guest-check.sh").read_text()
        start = script.index("result() {")
        end = script.index("wait_for() {")
        shell = script[start:end] + (
            "check good true\ncheck bad false\n")
        out = subprocess.run(["bash", "-c", shell], capture_output=True,
                             text=True, check=True).stdout.splitlines()
        self.assertEqual([results.CHECK.match(l.rstrip()).group(1, 2)
                          for l in out], [("good", "PASS"), ("bad", "FAIL")])


if __name__ == "__main__":
    unittest.main()
