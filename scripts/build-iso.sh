#!/usr/bin/env bash
# Build the MyOS live ISO with KIWI.
#
# Needs: root on Fedora 44 (host, VM or privileged container) and the desktop
# already built by scripts/build-desktop.sh. scripts/build-in-container.sh does
# all of this for you with Docker or Podman.
#   dnf install -y kiwi kiwi-systemdeps distribution-gpg-keys
# Usage: sudo scripts/build-iso.sh
# Output: output/iso/*.iso and output/iso/SHA256SUMS
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
target="${MYOS_ROOT}/build/target"
output="${MYOS_ROOT}/output/iso"

# Recreate the generated directories (only ever inside build/).
for d in "${description}" "${target}"; do
  [[ "${d}" == "${MYOS_ROOT}/build/"* ]] || die "Refusing to touch ${d}"
  if [[ -d "${d}" ]]; then rm -r -- "${d}"; fi
done
mkdir -p "${description}/root" "${target}" "${output}"

cp -- "${MYOS_ROOT}/image/kiwi/config.xml" "${MYOS_ROOT}/image/kiwi/config.sh" "${description}/"
cp -a -- "${MYOS_ROOT}/image/config/rootfs/." "${description}/root/"
cp -a -- "${stage}/." "${description}/root/"

info "Running KIWI (this downloads packages and can take a while)"
if ! kiwi-ng --type iso system build \
      --description "${description}" \
      --target-dir "${target}"; then
  die "KIWI failed. Read the log above, then see docs/troubleshooting.md."
fi

iso="$(find "${target}" -maxdepth 1 -name '*.iso' -print -quit)"
[[ -n "${iso}" ]] || die "KIWI finished but no .iso was found in ${target}"
mv -- "${iso}" "${output}/"
iso="${output}/$(basename "${iso}")"
find "${target}" -maxdepth 1 -name '*.packages' -exec cp -- {} "${output}/" \;
( cd "${output}" && sha256sum -- *.iso *.packages > SHA256SUMS )
info "ISO ready: ${iso}"
cat "${output}/SHA256SUMS"
