#!/usr/bin/env bash
# Build the desktop and the ISO inside a privileged Fedora 44 container.
# Works with Docker or Podman (Podman must run as root for loop devices).
# Usage: sudo scripts/build-in-container.sh
set -euo pipefail
# shellcheck source=scripts/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

engine="${MYOS_ENGINE:-}"
if [[ -z "${engine}" ]]; then
  if command -v docker >/dev/null 2>&1; then engine=docker; else engine=podman; fi
fi
require_cmd "${engine}" "Install Docker or Podman."

commit="$(git -C "${MYOS_ROOT}" rev-parse HEAD 2>/dev/null || echo unknown)"

"${engine}" run --rm --privileged \
  -e "MYOS_COMMIT=${commit}" -e "MYOS_REF=${MYOS_REF:-}" -e "MYOS_EDITION=${MYOS_EDITION:-gnome}" \
  -v /dev:/dev \
  -v "${MYOS_ROOT}:/work" -w /work \
  registry.fedoraproject.org/fedora:44 \
  bash -euxo pipefail -c '
    dnf install -y kiwi kiwi-systemdeps distribution-gpg-keys
    MYOS_NATIVE=1 scripts/build-desktop.sh
    scripts/build-iso.sh
  '
