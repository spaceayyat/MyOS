#!/usr/bin/env python3
"""Unit tests for tests/vm/results.py, the boot-test judge."""
import pathlib
import subprocess
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests/vm"))
import results  # noqa: E402


def log(mode="uefi", drop=(), extra=(), done=True, override=None,
        edition="gnome"):
    override = override or {}
    lines = ["\x1b[2J firmware noise VYLO-BEGIN Fedora",
             f"VYLO-FACT edition {edition}",
             f"VYLO-FACT firmware {'bios' if mode == 'bios' else 'uefi'}"]
    if mode == "secureboot":
        lines.append("VYLO-FACT secureboot SecureBoot enabled")
    lines += [override.get(n, f"VYLO-CHECK {n} PASS ok")
              for n in sorted(results.EDITIONS[edition]) if n not in drop]
    lines += list(extra) + ["VYLO-SHOT"] + (["VYLO-DONE"] if done else [])
    return "\r\n".join(lines) + "\r\n"


class Judge(unittest.TestCase):
    def assert_problem(self, text, serial, mode="uefi"):
        problems = results.evaluate(serial, mode, "gnome")
        self.assertTrue(any(text in p for p in problems), problems)

    def test_all_pass_in_every_mode(self):
        for edition, required in results.EDITIONS.items():
            for mode in ("bios", "uefi", "secureboot"):
                serial = log(mode, edition=edition)
                self.assertEqual(results.evaluate(serial, mode, edition), [])
                self.assertEqual(results.passed_checks(serial), len(required))

    def test_wrong_edition(self):
        self.assert_problem("expected the gnome", log(edition="plasma"))

    def test_failed_check(self):
        serial = log(override={"https": "VYLO-CHECK https FAIL timeout"})
        self.assert_problem("check failed: https timeout", serial)

    def test_missing_check(self):
        self.assert_problem("check missing: compositor", log(drop={"compositor"}))

    def test_old_reversed_order_is_rejected(self):
        serial = log(override={"compositor": "VYLO-CHECK PASS compositor"})
        self.assert_problem("malformed check line", serial)
        self.assert_problem("check missing: compositor", serial)

    def test_unknown_status_check_and_record(self):
        self.assert_problem("malformed", log(extra=["VYLO-CHECK compositor MAYBE"]))
        self.assert_problem("unknown check", log(extra=["VYLO-CHECK x PASS"]))
        self.assert_problem("unexpected output", log(extra=["VYLO-WAT 1"]))

    def test_duplicate_cannot_hide_a_failure(self):
        serial = log(override={"compositor": "VYLO-CHECK compositor FAIL"},
                     extra=["VYLO-CHECK compositor PASS"])
        self.assert_problem("check failed: compositor", serial)
        self.assert_problem("reported twice", serial)

    def test_boot_failures(self):
        self.assert_problem("never started", "")
        self.assert_problem("Kernel panic", "Kernel panic - not syncing\n")
        self.assert_problem("no VYLO-DONE", log(done=False))

    def test_wrong_firmware_and_secure_boot_off(self):
        self.assert_problem("expected bios", log("uefi"), "bios")
        self.assert_problem("Secure Boot is not enabled", log("uefi"),
                            "secureboot")

    def test_guest_script_reports_exactly_the_required_checks(self):
        script = (ROOT / "tests/vm/guest-check.sh").read_text()
        names = {line.split()[1] for line in script.splitlines()
                 if line.lstrip().startswith("check ")}
        self.assertEqual(names, set().union(*results.EDITIONS.values()))

    def test_install_guests_report_exactly_the_required_checks(self):
        for script, wanted in (("install-guest.sh", results.INSTALL),
                               ("installed-guest.sh", results.INSTALLED)):
            text = (ROOT / "tests/vm" / script).read_text()
            names = {line.split()[1] for line in text.splitlines()
                     if line.lstrip().startswith("check ")
                     and not line.lstrip().startswith("check()")}
            self.assertEqual(names, set(wanted), script)

    def test_installed_stage_needs_one_reboot(self):
        lines = ["VYLO-BEGIN x", "VYLO-FACT firmware uefi",
                 "VYLO-FACT edition gnome"]
        lines += [f"VYLO-CHECK {n} PASS" for n in sorted(results.INSTALLED)]
        ok = lines + ["VYLO-REQUEST login", "VYLO-REBOOT", "VYLO-REBOOTED",
                      "VYLO-DONE"]
        judge = lambda l: results.evaluate("\n".join(l), "uefi", "gnome",
                                           "installed")
        self.assertEqual(judge(ok), [])
        self.assertTrue(any("reboot" in p for p in judge(lines + ["VYLO-DONE"])))

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
