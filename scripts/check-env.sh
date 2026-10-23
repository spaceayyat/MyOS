#!/usr/bin/env bash
# Read-only environment check for My OS development. Changes nothing.
# Usage: scripts/check-env.sh
set -uo pipefail
# shellcheck source=scripts/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

fail=0
row() { printf '  %-12s %s\n' "$1" "$2"; }

info "Operating system"
if [[ -r /etc/os-release ]]; then
  ( . /etc/os-release && row "distro" "${PRETTY_NAME:-unknown}" )
else
  row "distro" "unknown (/etc/os-release missing)"
fi
row "kernel" "$(uname -r)"
if grep -qi microsoft /proc/version 2>/dev/null; then
  row "WSL" "yes ($(grep -oiE 'WSL2|microsoft-standard' /proc/version | head -1))"
else
  row "WSL" "no (not running inside WSL)"
fi
if [[ -e /dev/kvm ]]; then row "/dev/kvm" "present"; else row "/dev/kvm" "absent (no hardware-accelerated VMs here)"; fi
if [[ "$(ps -p 1 -o comm= 2>/dev/null)" == "systemd" ]]; then row "systemd" "PID 1"; else row "systemd" "not PID 1"; fi

info "Tools"
required=(git podman)
optional=(skopeo shellcheck make jq qemu-system-x86_64)
for t in "${required[@]}"; do
  if command -v "$t" >/dev/null 2>&1; then
    row "$t" "$("$t" --version 2>&1 | head -1)"
  else
    row "$t" "MISSING (required)"; fail=1
  fi
done
for t in "${optional[@]}"; do
  if command -v "$t" >/dev/null 2>&1; then
    row "$t" "$("$t" --version 2>&1 | head -1)"
  else
    row "$t" "missing (optional)"
  fi
done

if command -v podman >/dev/null 2>&1; then
  info "Podman details"
  row "rootless" "$(podman info --format '{{.Host.Security.Rootless}}' 2>&1 | head -1)"
  row "graphroot" "$(podman info --format '{{.Store.GraphRoot}}' 2>&1 | head -1)"
fi

if (( fail )); then
  warn "Required tools are missing. See docs/development.md for install commands."
  exit 1
fi
info "Environment check passed (required tools present)."
