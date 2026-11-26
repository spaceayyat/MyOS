#!/usr/bin/env python3
"""Offline validation of the image description's security and consistency rules.

The real schema check is tests/validate-image.sh (needs Fedora's KIWI).
Usage: python3 -I tests/unit/check_config.py REPO_ROOT
"""
import collections
import pathlib
import re
import sys
import xml.etree.ElementTree as ET


def main(root: pathlib.Path) -> int:
    problems = []
    xml = ET.parse(root / "image/kiwi/config.xml").getroot()

    users = [(u.get("name"), u.get("password")) for u in xml.iter("user")]
    if users != [("root", "*")]:
        problems.append(f"only a locked root may be defined, found {users}")

    kind = xml.find("./preferences/type")
    cmdline = kind.get("kernelcmdline", "")
    for bad in ("selinux=0", "enforcing=0", "mitigations=off"):
        if bad in cmdline:
            problems.append(f"kernel command line weakens security: {bad}")
    if "rd.live.image" not in cmdline:
        problems.append("rd.live.image missing: live-only units would misbehave")
    if xml.findtext("./preferences/rpm-check-signatures") != "true":
        problems.append("rpm-check-signatures must be true")

    for repo in xml.iter("repository"):
        if repo.get("package_gpgcheck") != "true":
            problems.append(f"{repo.get('alias')}: package_gpgcheck is not true")
        source = repo.find("source")
        if not source.get("path", "").startswith("https://"):
            problems.append(f"{repo.get('alias')}: not https")
        if source.find("signing") is None:
            problems.append(f"{repo.get('alias')}: no signing key")

    names = set()
    for edition in ("GNOME", "Plasma"):
        listed = [p.get("name") for group in xml.iter("packages")
                  if group.get("profiles") in (None, edition)
                  for p in group.iter("package")]
        names.update(listed)
        for name, count in collections.Counter(listed).items():
            if count > 1:
                problems.append(f"{edition}: package listed {count} times: {name}")
        if "helium-bin" not in listed:
            problems.append(f"{edition}: helium-bin is missing")
        if edition == "GNOME" and "firefox" in listed:
            problems.append("GNOME edition must ship Helium, not Firefox")

    # The Helium key shipped to users must be the one the build trusts.
    key = "image/config/rootfs/etc/pki/rpm-gpg/RPM-GPG-KEY-imput-helium"
    if not (root / key).is_file():
        problems.append(f"missing {key}")
    if "gpgcheck=1" not in (root / "image/config/rootfs/etc/yum.repos.d/"
                            "imput-helium.repo").read_text().splitlines():
        problems.append("installed Helium repository must keep gpgcheck=1")

    # Every unit enabled in config.sh that this repository ships must exist.
    script = (root / "image/kiwi/config.sh").read_text()
    for unit in re.findall(r"\b(myos-[\w-]+\.(?:service|timer))\b", script):
        if not (root / "image/config/rootfs/etc/systemd/system" / unit).is_file():
            problems.append(f"config.sh enables {unit} but the repo does not ship it")

    for problem in problems:
        print("PROBLEM", problem)
    print(f"checked {len(names)} packages; {len(problems)} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(pathlib.Path(sys.argv[1])))
