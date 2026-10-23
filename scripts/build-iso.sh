#!/usr/bin/env bash
# Build the My OS live ISO with KIWI.
#
# Needs: root, a Fedora host (or Fedora container/VM) with kiwi installed, and
# the desktop already built by scripts/build-desktop.sh.
#   sudo dnf install -y kiwi kiwi-systemdeps distribution-gpg-keys
# Usage: sudo scripts/build-iso.sh
# Output: output/iso/*.iso (+ a .sha256 file next to it)
set -euo pipefail
# shellcheck source=scripts/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

[[ ${EUID} -eq 0 ]] || die "KIWI needs root (loop devices and mounts). Run: sudo scripts/build-iso.sh"
require_cmd kiwi-ng "On Fedora: sudo dnf install -y kiwi kiwi-systemdeps distribution-gpg-keys"
[[ -d /usr/share/distribution-gpg-keys/fedora ]] \
  || die "Fedora signing keys missing. On Fedora: sudo dnf install -y distribution-gpg-keys"

stage="${MYOS_ROOT}/build/stage"
[[ -x "${stage}/usr/bin/myos-shell" ]] \
  || die "Desktop not built. Run scripts/build-desktop.sh first."

description="${MYOS_ROOT}/build/kiwi"
output="${MYOS_ROOT}/output/iso"

# Recreate the generated description directory (only ever inside build/).
[[ "${description}" == "${MYOS_ROOT}/build/"* ]] || die "Refusing to touch ${description}"
[[ -d "${description}" ]] && rm -r -- "${description}"
mkdir -p "${description}/root" "${output}"

cp -- "${MYOS_ROOT}/image/kiwi/config.xml" "${MYOS_ROOT}/image/kiwi/config.sh" "${description}/"
cp -a -- "${MYOS_ROOT}/image/config/rootfs/." "${description}/root/"
cp -a -- "${stage}/." "${description}/root/"

info "Running KIWI (this downloads packages and can take a while)"
if ! kiwi-ng --type iso system build \
      --description "${description}" \
      --target-dir "${output}"; then
  die "KIWI failed. Read the log above, then see 'If the ISO build fails' in docs/development.md."
fi

iso="$(find "${output}" -maxdepth 1 -name '*.iso' -print -quit)"
[[ -n "${iso}" ]] || die "KIWI finished but no .iso was found in ${output}"
( cd "${output}" && sha256sum "$(basename "${iso}")" > "$(basename "${iso}").sha256" )
info "ISO ready: ${iso}"
info "SHA256: $(cut -d' ' -f1 "${iso}.sha256")"
info "Not boot-tested until you do it in a VM (docs/development.md)."
