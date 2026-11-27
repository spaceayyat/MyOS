#!/usr/bin/env bash
# Validate the image description with real tools. Run on Fedora 44 as root:
#   kiwi parses and schema-checks config.xml, and every package name is looked
#   up in the Fedora 44 repositories.
# Usage: tests/validate-image.sh
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

dnf install -y kiwi distribution-gpg-keys python3

echo "== kiwi-ng image info"
for profile in GNOME Plasma VYLO; do
  kiwi-ng --profile "${profile}" image info --description "${root}/image/kiwi"
done

echo "== package existence"
python3 -I "${root}/tests/check_packages.py" "${root}/image/kiwi/config.xml" \
  "${root}/scripts/build-desktop.sh"
