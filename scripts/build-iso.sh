#!/usr/bin/env bash
# Build the VYLO live ISO with KIWI.
#
# Needs: root on Fedora 44 (host, VM or privileged container) and the desktop
# already built by scripts/build-desktop.sh. scripts/build-in-container.sh does
# all of this for you with Docker or Podman.
#   dnf install -y kiwi kiwi-systemdeps distribution-gpg-keys
# Usage: sudo [VYLO_EDITION=gnome|plasma|vylo] scripts/build-iso.sh   (default gnome)
# Output: output/iso/*.iso and output/iso/SHA256SUMS
set -euo pipefail
# shellcheck source=scripts/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

[[ ${EUID} -eq 0 ]] || die "KIWI needs root (loop devices and mounts). Run: sudo scripts/build-iso.sh"
require_cmd kiwi-ng "On Fedora: sudo dnf install -y kiwi kiwi-systemdeps distribution-gpg-keys"
[[ -d /usr/share/distribution-gpg-keys/fedora ]] \
  || die "Fedora signing keys missing. On Fedora: sudo dnf install -y distribution-gpg-keys"

stage="${VYLO_ROOT}/build/stage"
[[ -x "${stage}/usr/bin/vylo-shell" ]] \
  || die "Desktop not built. Run scripts/build-desktop.sh first."

edition="${VYLO_EDITION:-gnome}"
case "${edition}" in
  gnome) profile=GNOME; suffix="" ;;
  plasma) profile=Plasma; suffix="-plasma" ;;
  vylo) profile=VYLO; suffix="-desktop" ;;
  *) die "VYLO_EDITION must be gnome, plasma or vylo, not '${edition}'" ;;
esac

description="${VYLO_ROOT}/build/kiwi"
target="${VYLO_ROOT}/build/target"
output="${VYLO_ROOT}/output/iso"

# Recreate the generated directories (only ever inside build/).
for d in "${description}" "${target}"; do
  [[ "${d}" == "${VYLO_ROOT}/build/"* ]] || die "Refusing to touch ${d}"
  if [[ -d "${d}" ]]; then rm -r -- "${d}"; fi
done
mkdir -p "${description}/root" "${target}" "${output}"

cp -- "${VYLO_ROOT}/image/kiwi/config.xml" "${VYLO_ROOT}/image/kiwi/config.sh" "${description}/"
cp -a -- "${VYLO_ROOT}/image/config/rootfs/." "${description}/root/"
cp -a -- "${VYLO_ROOT}/image/config/rootfs-${edition}/." "${description}/root/"
cp -a -- "${stage}/." "${description}/root/"
sed -i "s|@ROOT@|${VYLO_ROOT}|g" "${description}/config.xml"

info "Running KIWI (this downloads packages and can take a while)"
if ! kiwi-ng --profile "${profile}" --type iso system build \
      --description "${description}" \
      --target-dir "${target}"; then
  die "KIWI failed. Read the log above, then see docs/troubleshooting.md."
fi

iso="$(find "${target}" -maxdepth 1 -name '*.iso' -print -quit)"
[[ -n "${iso}" ]] || die "KIWI finished but no .iso was found in ${target}"
# Name the image after its release tag (v<version> or v<version>-<suffix>);
# anything else is a development build and says which commit it came from.
version="$(sed -n 's|.*<version>\(.*\)</version>.*|\1|p' "${description}/config.xml")"
commit="${VYLO_COMMIT:-$(git -C "${VYLO_ROOT}" rev-parse HEAD 2>/dev/null || echo unknown)}"
ref="${VYLO_REF:-}"
if [[ "${ref}" == "refs/tags/v${version}" || "${ref}" == "refs/tags/v${version}-"* ]]; then
  name="VYLO-${ref#refs/tags/v}${suffix}-x86_64"
else
  name="VYLO-${version}-dev.${commit:0:7}${suffix}-x86_64"
fi
rm -f -- "${output}"/*.iso "${output}"/*.packages
mv -- "${iso}" "${output}/${name}.iso"
iso="${output}/${name}.iso"
packages="$(find "${target}" -maxdepth 1 -name '*.packages' -print -quit)"
[[ -n "${packages}" ]] || die "KIWI wrote no package list"
cp -- "${packages}" "${output}/${name}.packages"
cat > "${output}/BUILD-INFO.txt" <<EOF
name:     ${name}.iso
version:  ${version}
edition:  ${edition}
commit:   ${commit}
ref:      ${VYLO_REF:-local}
built:    $(date -u +%Y-%m-%dT%H:%M:%SZ)
base:     Fedora $(rpm -E %fedora)
kiwi:     $(kiwi-ng --version 2>&1 | tail -n1)
packages: $(wc -l < "${output}/${name}.packages")
EOF
( cd "${output}" && sha256sum -- "${name}.iso" "${name}.packages" BUILD-INFO.txt > SHA256SUMS )
info "ISO ready: ${iso}"
cat "${output}/BUILD-INFO.txt"
cat "${output}/SHA256SUMS"
