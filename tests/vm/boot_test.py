#!/usr/bin/env python3
"""Boot the MyOS ISO in QEMU and run tests/vm/guest-check.sh inside it.

The ISO boots through real firmware and its own boot loader. The test script is
handed to systemd as an SMBIOS credential (systemd.extra-unit), so the image
under test is not modified.

Usage: boot_test.py --iso X.iso --mode bios|uefi|secureboot --out DIR
Needs: qemu-system-x86_64, OVMF for the UEFI modes; /dev/kvm strongly advised.
Exit status 0 only if the guest finished and every check passed.
"""
import argparse
import base64
import json
import os
import pathlib
import shutil
import socket
import subprocess
import sys
import time

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import results  # noqa: E402

HERE = pathlib.Path(__file__).resolve().parent
OVMF = pathlib.Path("/usr/share/OVMF")
UNIT = """[Unit]
Description=MyOS boot smoke test
After=multi-user.target
[Service]
Type=simple
ImportCredential=myos.check
ExecStart=/bin/bash %d/myos.check
"""
DROPIN = "[Unit]\nWants=myos-boot-test.service\n"


def credential(name: str, content: bytes) -> list:
    blob = base64.b64encode(content).decode()
    return ["-smbios", f"type=11,value=io.systemd.credential.binary:{name}={blob}"]


def qmp(path: str, command: str, **arguments) -> None:
    with socket.socket(socket.AF_UNIX) as sock:
        sock.settimeout(30)
        sock.connect(path)
        stream = sock.makefile("rw")
        stream.readline()  # greeting
        for message in ({"execute": "qmp_capabilities"},
                        {"execute": command, "arguments": arguments}):
            stream.write(json.dumps(message) + "\n")
            stream.flush()
            while True:
                reply = json.loads(stream.readline())
                if "error" in reply:
                    raise RuntimeError(reply["error"])
                if "return" in reply:
                    break


def qemu_command(args, out: pathlib.Path) -> list:
    command = [
        "qemu-system-x86_64", "-m", "6144", "-smp", str(min(4, os.cpu_count() or 2)),
        "-display", "none", "-vga", "none", "-device", "virtio-vga",
        "-cdrom", args.iso, "-boot", "d",
        "-netdev", "user,id=n0", "-device", "virtio-net-pci,netdev=n0",
        "-audiodev", "none,id=a0", "-device", "intel-hda",
        "-device", "hda-duplex,audiodev=a0",
        "-device", "virtio-rng-pci",
        "-serial", f"file:{out / 'serial.log'}",
        "-qmp", f"unix:{out / 'qmp.sock'},server=on,wait=off",
        "-no-reboot",
    ]
    if os.access("/dev/kvm", os.R_OK | os.W_OK):
        command += ["-enable-kvm", "-cpu", "host"]
    else:
        print("WARNING: no usable /dev/kvm; emulation will be very slow")
        command += ["-cpu", "max"]

    if args.mode == "bios":
        command += ["-machine", "q35"]
    else:
        secure = args.mode == "secureboot"
        code = OVMF / ("OVMF_CODE_4M.secboot.fd" if secure else "OVMF_CODE_4M.fd")
        template = OVMF / ("OVMF_VARS_4M.ms.fd" if secure else "OVMF_VARS_4M.fd")
        variables = out / "vars.fd"
        shutil.copy(template, variables)
        command += ["-machine", "q35,smm=on" if secure else "q35",
                    "-drive", f"if=pflash,format=raw,readonly=on,file={code}",
                    "-drive", f"if=pflash,format=raw,file={variables}"]
        if secure:
            command += ["-global", "driver=cfi.pflash01,property=secure,value=on"]

    command += credential("systemd.extra-unit.myos-boot-test.service", UNIT.encode())
    command += credential("systemd.unit-dropin.multi-user.target", DROPIN.encode())
    command += credential("myos.check", (HERE / "guest-check.sh").read_bytes())
    return command


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--iso", required=True)
    parser.add_argument("--mode", choices=["bios", "uefi", "secureboot"], required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--timeout", type=int, default=1500)
    args = parser.parse_args()
    out = pathlib.Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    serial = out / "serial.log"
    serial.write_text("")

    command = qemu_command(args, out)
    print(" ".join(c if len(c) < 200 else c[:80] + "..." for c in command), flush=True)
    process = subprocess.Popen(command)
    start = time.time()
    seen = 0
    shot = done = False
    try:
        while time.time() - start < args.timeout:
            lines = serial.read_text(errors="replace").splitlines()
            # The last line may still be incomplete unless it is a newline.
            complete = serial.read_text(errors="replace").count("\n")
            for line in lines[seen:complete]:
                if "MYOS-" in line:
                    print(f"[{int(time.time() - start):4d}s] {line.strip()}", flush=True)
            seen = complete
            if not shot and any(l.strip() == "MYOS-SHOT" for l in lines):
                qmp(str(out / "qmp.sock"), "screendump",
                    filename=str(out / "desktop.png"), format="png")
                shot = True
            if any(l.strip() == "MYOS-DONE" for l in lines):
                done = True
                break
            if process.poll() is not None:
                break
            time.sleep(5)
        if not done and process.poll() is None:
            qmp(str(out / "qmp.sock"), "screendump",
                filename=str(out / "timeout.png"), format="png")
    finally:
        try:
            process.wait(timeout=90 if done else 1)
        except subprocess.TimeoutExpired:
            process.kill()

    log = serial.read_text(errors="replace")
    problems = results.evaluate(log, args.mode)
    if process.returncode not in (0, None):
        problems.append(f"QEMU exited with status {process.returncode}")
    for problem in problems:
        print(f"PROBLEM {problem}")
    print(f"\n{args.mode}: {results.passed_checks(log)}/{len(results.REQUIRED)} "
          f"checks passed, {len(problems)} problem(s)")
    if not done:
        print("--- last 60 serial lines ---")
        print("\n".join(log.splitlines()[-60:]))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
