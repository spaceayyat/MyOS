#!/usr/bin/env bash
# Copy the screenshots taken by the VM tests into the repository, under stable
# names. Fails if one is missing or is (almost) a single colour.
# Needs ImageMagick (identify).
# Usage: scripts/collect-screenshots.sh ARTIFACT-DIR OUTPUT-DIR
set -euo pipefail

[[ $# -eq 2 ]] || { echo "usage: $0 ARTIFACT-DIR OUTPUT-DIR" >&2; exit 2; }
in="$1" out="$2"
command -v identify >/dev/null || { echo "ImageMagick (identify) is not installed" >&2; exit 1; }
mkdir -p "${out}"

copy() {
  local from="${in}/$1" to="${out}/$2" colours
  [[ -f "${from}" ]] || { echo "missing screenshot: ${from}" >&2; return 1; }
  colours="$(identify -format '%k' "${from}")"
  (( colours > 64 )) || { echo "screenshot looks blank (${colours} colours): ${from}" >&2; return 1; }
  cp -- "${from}" "${to}"
  echo "$2: ${colours} colours"
}

status=0
for edition in gnome plasma vylo; do
  copy "boot-${edition}-uefi/desktop.png" "${edition}-live.png" || status=1
  copy "install-${edition}-plain/installed/login-screen.png" "${edition}-login.png" || status=1
  copy "install-${edition}-plain/installed/desktop.png" "${edition}-installed.png" || status=1
done
exit "${status}"
