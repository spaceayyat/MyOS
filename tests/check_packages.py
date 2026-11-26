#!/usr/bin/env python3
"""Fail if a package named by the image or the build does not exist in Fedora.

Names come from <package> elements in config.xml and the build_packages=(...)
array in build-desktop.sh. Needs dnf5 on the matching Fedora release.
Usage: python3 -I tests/check_packages.py config.xml build-desktop.sh
"""
import re
import subprocess
import sys
import xml.etree.ElementTree as ET


def main(config: str, build_script: str) -> int:
    wanted = {p.get("name") for p in ET.parse(config).getroot().iter("package")}
    with open(build_script, encoding="utf-8") as handle:
        match = re.search(r"^build_packages=\(([^)]*)\)", handle.read(), re.M)
    if not match:
        print("build_packages array not found")
        return 1
    wanted |= set(match.group(1).split())

    result = subprocess.run(
        ["dnf", "-q", "repoquery", "--repo=fedora", "--repo=updates",
         "--qf", "%{name}\n", *sorted(wanted)],
        check=True, capture_output=True, text=True)
    found = set(result.stdout.split())
    missing = sorted(wanted - found)
    print(f"checked {len(wanted)} package names; missing: {len(missing)}")
    for name in missing:
        print(f"MISSING {name}")
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:]))
