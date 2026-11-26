#!/usr/bin/env python3
"""Install VYLO from the ISO into a virtual disk, then boot and test it.

Stage 1: boot the ISO (UEFI) and run install-guest.sh, which installs onto a
blank disk. Stage 2: boot that disk alone, run installed-guest.sh, type the
disk passphrase (LUKS) and the login password on the virtual keyboard, reboot
once and check again.

Usage: install_test.py --iso X.iso --disk plain|luks --edition gnome|plasma
       --out DIR
Needs: qemu-system-x86_64, qemu-img, OVMF, and in practice /dev/kvm.
"""
import argparse
import pathlib
import subprocess
import sys
import time

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import boot_test  # noqa: E402
import results  # noqa: E402

LUKS_PASSPHRASE = "luks0passphrase1"
USER_PASSWORD = "tester0pass1"


def type_line(sock: str, text: str) -> None:
    for key in [*text, "ret"]:
        boot_test.qmp(sock, "send-key", keys=[{"type": "qcode", "data": key}])
        time.sleep(0.15)


def run_stage(command, out: pathlib.Path, luks: bool, timeout: int) -> str:
    """Run one QEMU session to completion and return its serial log."""
    serial, sock = out / "serial.log", str(out / "qmp.sock")
    serial.write_text("")
    process = subprocess.Popen(command)
    start = last_typed = time.time()
    seen = 0
    waiting_for_unlock = luks
    try:
        while time.time() - start < timeout and process.poll() is None:
            time.sleep(5)
            log = serial.read_text(errors="replace")
            complete = log.count("\n")
            for line in log.splitlines()[seen:complete]:
                if "VYLO-" not in line:
                    if line.startswith("["):
                        print(line, flush=True)
                    continue
                print(f"[{int(time.time() - start):4d}s] {line.strip()}", flush=True)
                record = line[line.find("VYLO-"):].strip()
                if record.startswith(("VYLO-BEGIN", "VYLO-REBOOTED")):
                    waiting_for_unlock = False
                elif record == "VYLO-REQUEST login":
                    time.sleep(3)
                    boot_test.qmp(sock, "screendump", format="png",
                                  filename=str(out / "login-screen.png"))
                    type_line(sock, "")  # choose the only user
                    time.sleep(5)
                    type_line(sock, USER_PASSWORD)
                elif record == "VYLO-SHOT":
                    boot_test.qmp(sock, "screendump", format="png",
                                  filename=str(out / "desktop.png"))
                elif record == "VYLO-REBOOT" and luks:
                    waiting_for_unlock = True
                    last_typed = time.time() + 15
            seen = complete
            # Nothing on the serial port while the disk is locked: type the
            # passphrase periodically until the system reports in.
            if waiting_for_unlock and time.time() - last_typed > 30:
                boot_test.qmp(sock, "screendump", format="png",
                              filename=str(out / "unlock-prompt.png"))
                type_line(sock, LUKS_PASSPHRASE)
                last_typed = time.time()
        if process.poll() is None:
            boot_test.qmp(sock, "screendump", format="png",
                          filename=str(out / "timeout.png"))
    finally:
        try:
            process.wait(timeout=60)
        except subprocess.TimeoutExpired:
            process.kill()
    return serial.read_text(errors="replace")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--iso", required=True)
    parser.add_argument("--disk", choices=["plain", "luks"], required=True)
    parser.add_argument("--edition", choices=sorted(results.EDITIONS), required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    out = pathlib.Path(args.out).resolve()
    disk = out / "disk.qcow2"
    (out / "install").mkdir(parents=True, exist_ok=True)
    (out / "installed").mkdir(parents=True, exist_ok=True)
    subprocess.run(["qemu-img", "create", "-q", "-f", "qcow2", str(disk), "40G"],
                   check=True)
    drive = ["-drive", f"if=virtio,format=qcow2,file={disk}"]
    extra = boot_test.credential("vylo.disk", args.disk.encode())

    problems = []
    stages = [("install", "install-guest.sh", args.iso, 2100),
              ("installed", "installed-guest.sh", None, 2100)]
    for stage, script, iso, timeout in stages:
        print(f"===== stage: {stage} =====", flush=True)
        command = boot_test.qemu_command(
            "uefi", out / stage, HERE / script, iso=iso,
            reboot=(stage == "installed"))
        # The installed system reuses the firmware variables written by stage 1.
        if stage == "installed":
            (out / stage / "vars.fd").write_bytes(
                (out / "install" / "vars.fd").read_bytes())
        log = run_stage(command + drive + extra, out / stage,
                        luks=(stage == "installed" and args.disk == "luks"),
                        timeout=timeout)
        found = results.evaluate(log, "uefi", args.edition, stage)
        problems += [f"{stage}: {p}" for p in found]
        print(f"{stage}: {results.passed_checks(log)}/"
              f"{len(results.required(args.edition, stage))} checks passed, "
              f"{len(found)} problem(s)")
        if found:
            print("--- last 80 serial lines ---")
            print("\n".join(log.splitlines()[-80:]))
            break
    for problem in problems:
        print(f"PROBLEM {problem}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
