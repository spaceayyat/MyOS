#!/usr/bin/env python3
"""Boot the VYLO ISO in QEMU and run tests/vm/guest-check.sh inside it.

The ISO boots through real firmware and its own boot loader. The test script is
handed to systemd as an SMBIOS credential (systemd.extra-unit), so the image
under test is not modified.

Usage: boot_test.py --iso X.iso --mode bios|uefi|secureboot
       --edition gnome|plasma|vylo --out DIR
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
Description=VYLO boot smoke test
After=multi-user.target
[Service]
Type=simple
ImportCredential=vylo.check
ImportCredential=vylo.disk
ExecStart=/bin/bash %d/vylo.check
"""
DROPIN = "[Unit]\nWants=vylo-boot-test.service\n"


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


def qemu_command(mode: str, out: pathlib.Path, script: pathlib.Path,
                 iso: str = None, reboot: bool = False,
                 video: str = "virtio") -> list:
    command = [
        "qemu-system-x86_64", "-m", "6144", "-smp", str(min(4, os.cpu_count() or 2)),
        "-display", "none",
        # A tablet is an absolute pointer, as VirtualBox and virt-manager use.
        "-device", "virtio-tablet-pci",
        "-netdev", "user,id=n0", "-device", "virtio-net-pci,netdev=n0",
        "-audiodev", "none,id=a0", "-device", "intel-hda",
        "-device", "hda-duplex,audiodev=a0",
        "-device", "virtio-rng-pci",
        "-serial", f"file:{out / 'serial.log'}",
        "-qmp", f"unix:{out / 'qmp.sock'},server=on,wait=off",
    ]
    # "std" is a plain adapter without GPU rendering.
    command += (["-vga", "std"] if video == "std"
                else ["-vga", "none", "-device", "virtio-vga"])
    if iso:
        command += ["-cdrom", iso, "-boot", "d"]
    if not reboot:
        command += ["-no-reboot"]
    if os.access("/dev/kvm", os.R_OK | os.W_OK):
        command += ["-enable-kvm", "-cpu", "host"]
    else:
        print("WARNING: no usable /dev/kvm; emulation will be very slow")
        command += ["-cpu", "max"]

    if mode == "bios":
        command += ["-machine", "q35"]
    else:
        secure = mode == "secureboot"
        code = OVMF / ("OVMF_CODE_4M.secboot.fd" if secure else "OVMF_CODE_4M.fd")
        template = OVMF / ("OVMF_VARS_4M.ms.fd" if secure else "OVMF_VARS_4M.fd")
        variables = out / "vars.fd"
        if not variables.exists():
            shutil.copy(template, variables)
        command += ["-machine", "q35,smm=on" if secure else "q35",
                    "-drive", f"if=pflash,format=raw,readonly=on,file={code}",
                    "-drive", f"if=pflash,format=raw,file={variables}"]
        if secure:
            command += ["-global", "driver=cfi.pflash01,property=secure,value=on"]

    command += credential("systemd.extra-unit.vylo-boot-test.service", UNIT.encode())
    command += credential("systemd.unit-dropin.multi-user.target", DROPIN.encode())
    command += credential("vylo.check", script.read_bytes())
    return command


def screen(sock: str, path: pathlib.Path):
    """Screenshot as PPM. Returns (width, height, number of colours)."""
    qmp(sock, "screendump", filename=str(path), format="ppm")
    data = path.read_bytes()
    header = data.split(b"\n", 3)
    width, height = map(int, header[1].split())
    pixels = header[3]
    return width, height, len({pixels[i:i + 3] for i in range(0, len(pixels), 3)})


def click(sock: str, x: int, y: int, width: int, height: int) -> None:
    """Move the pointer to a screen position and press the left button."""
    qmp(sock, "input-send-event", events=[
        {"type": "abs", "data": {"axis": "x", "value": x * 32767 // width}},
        {"type": "abs", "data": {"axis": "y", "value": y * 32767 // height}}])
    time.sleep(1)
    for down in (True, False):
        qmp(sock, "input-send-event", events=[
            {"type": "btn", "data": {"button": "left", "down": down}}])
        time.sleep(0.2)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--iso", required=True)
    parser.add_argument("--mode", choices=["bios", "uefi", "secureboot"], required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--edition", choices=sorted(results.EDITIONS),
                        required=True)
    parser.add_argument("--timeout", type=int, default=1500)
    args = parser.parse_args()
    out = pathlib.Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    serial = out / "serial.log"
    serial.write_text("")

    (out / "vars.fd").unlink(missing_ok=True)
    # One VYLO run uses a plain adapter, to cover machines without a usable GPU.
    video = "std" if (args.edition, args.mode) == ("vylo", "bios") else "virtio"
    command = qemu_command(args.mode, out, HERE / "guest-check.sh",
                           iso=args.iso, video=video)
    print(" ".join(c if len(c) < 200 else c[:80] + "..." for c in command), flush=True)
    process = subprocess.Popen(command)
    start = time.time()
    seen = 0
    shot = done = clicked = installer_shot = False
    screen_problems = []
    sock = str(out / "qmp.sock")
    try:
        while time.time() - start < args.timeout:
            lines = serial.read_text(errors="replace").splitlines()
            # The last line may still be incomplete unless it is a newline.
            complete = serial.read_text(errors="replace").count("\n")
            for line in lines[seen:complete]:
                if "VYLOTEST-" in line:
                    print(f"[{int(time.time() - start):4d}s] {line.strip()}", flush=True)
            seen = complete
            if not shot and any(l.strip() == "VYLOTEST-SHOT" for l in lines):
                qmp(str(out / "qmp.sock"), "screendump",
                    filename=str(out / "desktop.png"), format="png")
                shot = True
                if args.edition == "vylo":
                    colours = screen(sock, out / "desktop.ppm")[2]
                    print(f"desktop screenshot: {colours} colours", flush=True)
                    if colours <= 64:
                        screen_problems.append(f"the screen is blank ({colours} colours)")
            if not clicked and any(l.strip() == "VYLOTEST-REQUEST install" for l in lines):
                # The welcome window is 520x400 and centred; its first button
                # is 220x44 at (40, 318).
                width, height, _ = screen(sock, out / "welcome.ppm")
                qmp(sock, "screendump", filename=str(out / "welcome.png"), format="png")
                click(sock, width // 2 - 260 + 150, height // 2 - 200 + 340, width, height)
                clicked = True
            if not installer_shot and any(l.strip() == "VYLOTEST-INSTALLERSHOT" for l in lines):
                qmp(sock, "screendump", filename=str(out / "installer.png"), format="png")
                installer_shot = True
            if any(l.strip() == "VYLOTEST-DONE" for l in lines):
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
    problems = results.evaluate(log, args.mode, args.edition) + screen_problems
    for ppm in out.glob("*.ppm"):
        ppm.unlink()
    if process.returncode not in (0, None):
        problems.append(f"QEMU exited with status {process.returncode}")
    for problem in problems:
        print(f"PROBLEM {problem}")
    print(f"\n{args.mode}: {results.passed_checks(log)}/{len(results.EDITIONS[args.edition])} "
          f"checks passed, {len(problems)} problem(s)")
    if not done:
        print("--- last 60 serial lines ---")
        print("\n".join(log.splitlines()[-60:]))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
