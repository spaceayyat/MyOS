"""Parse and judge the serial output of tests/vm/guest-check.sh.

Protocol (one record per line, anything before "VYLOTEST-" is firmware noise):
    VYLOTEST-BEGIN <description>
    VYLOTEST-FACT <key> [value]
    VYLOTEST-CHECK <name> PASS|FAIL [detail]
    VYLOTEST-AVC <text>
    VYLOTEST-SHOT
    VYLOTEST-DONE
Anything else that starts with "VYLOTEST-" is an error, so a change to the guest
script can never be silently ignored.
"""
import re

COMMON = frozenset({
    "live-user", "compositor", "desktop-shell", "user-session",
    "display-manager", "networkmanager", "network-connected", "https",
    "soundcard", "pipewire", "wireplumber", "audio-sink", "bluetooth-service",
    "cups-socket", "cups-scheduler", "selinux-enforcing", "firewalld",
    "root-no-usable-password", "root-su-refused", "ssh-server-off",
    "no-auto-update-on-live", "applications", "default-theme",
    "vylo-binaries", "installer", "helium-runs", "default-browser",
})
EDITIONS = {
    "gnome": COMMON | {"no-firefox", "customization-tools"},
    "plasma": COMMON,
    "vylo": COMMON | {"no-firefox", "vylo-session-parts",
                      "pointer-drawn-by-desktop", "installer-starts",
                      "installer-stays", "vylo-name",
                      "installer-theme"},
}

# Installation test (tests/vm/install_test.py).
INSTALL = frozenset({"payload-found", "anaconda-finished", "partitions-created"})
INSTALLED = frozenset({
    "not-live", "no-live-user", "user-created", "root-locked",
    "no-empty-passwords", "root-btrfs", "disk-encryption",
    "selinux-enforcing", "firewalld", "ssh-server-off", "update-timer",
    "display-manager", "network", "applications", "snapper-config",
    "snapper-recovery", "system-update", "login", "reboot-selinux",
    "reboot-display-manager", "reboot-network", "reboot-persistence",
})


def required(edition: str, stage: str = "live") -> frozenset:
    return {"live": EDITIONS[edition], "install": INSTALL,
            "installed": INSTALLED}[stage]


FATAL = ("Kernel panic", "You are in emergency mode",
         "Entering emergency mode", "dracut-emergency")

CHECK = re.compile(r"^VYLOTEST-CHECK ([a-z0-9-]+) (PASS|FAIL)(?: (.*))?$")


def evaluate(serial: str, mode: str, edition: str,
             stage: str = "live") -> list:
    """Return a list of problems. An empty list means the boot test passed."""
    wanted = required(edition, stage)
    reboots = 0
    problems = []
    checks = {}
    facts = {}
    begun = done = False

    for marker in FATAL:
        if marker in serial:
            problems.append(f"guest boot failure: '{marker}' on the console")

    for raw in serial.splitlines():
        start = raw.find("VYLOTEST-")
        if start < 0:
            continue
        line = raw[start:].rstrip()
        if done:
            problems.append(f"output after VYLOTEST-DONE: {line}")
        elif line.startswith("VYLOTEST-BEGIN "):
            if begun:
                problems.append("test script started twice (guest rebooted?)")
            begun = True
        elif not begun:
            problems.append(f"output before VYLOTEST-BEGIN: {line}")
        elif line.startswith("VYLOTEST-CHECK"):
            match = CHECK.match(line)
            if not match:
                problems.append(f"malformed check line: {line}")
                continue
            name, status, detail = match.groups()
            if name in checks:
                problems.append(f"check reported twice: {name}")
            if name not in wanted:
                problems.append(f"unknown check: {name}")
            checks[name] = status
            if status == "FAIL":
                problems.append(f"check failed: {name} {detail or ''}".rstrip())
        elif edition == "vylo" and stage == "live" and line in (
                "VYLOTEST-REQUEST install", "VYLOTEST-INSTALLERSHOT"):
            continue
        elif stage == "installed" and line in ("VYLOTEST-REQUEST login",
                                              "VYLOTEST-REBOOT"):
            continue
        elif stage == "installed" and line == "VYLOTEST-REBOOTED":
            reboots += 1
        elif line.startswith("VYLOTEST-FACT "):
            parts = line.split(" ", 2)
            facts[parts[1]] = parts[2] if len(parts) > 2 else ""
        elif line == "VYLOTEST-DONE":
            done = True
        elif line != "VYLOTEST-SHOT" and not line.startswith("VYLOTEST-AVC "):
            problems.append(f"unexpected output: {line}")

    if not begun:
        problems.append("guest boot failure: the test script never started")
        return problems
    if not done:
        problems.append("guest did not finish: no VYLOTEST-DONE")
    for name in sorted(wanted - checks.keys()):
        problems.append(f"check missing: {name}")

    if stage == "installed" and reboots != 1:
        problems.append(f"expected exactly one reboot, saw {reboots}")

    firmware = "bios" if mode == "bios" else "uefi"
    if facts.get("firmware") != firmware:
        problems.append(f"expected {firmware} firmware, guest reported "
                        f"{facts.get('firmware')!r}")
    if facts.get("edition") != edition:
        problems.append(f"expected the {edition} edition, guest reported "
                        f"{facts.get('edition')!r}")
    if mode == "secureboot" and facts.get("secureboot") != "SecureBoot enabled":
        problems.append("Secure Boot is not enabled in the guest: "
                        f"{facts.get('secureboot')!r}")
    return problems


def passed_checks(serial: str) -> int:
    return len({m.group(1) for line in serial.splitlines()
                if (m := CHECK.match(line[max(line.find('VYLOTEST-'), 0):].rstrip()))
                and m.group(2) == "PASS"})
