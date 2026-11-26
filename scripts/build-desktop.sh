#!/usr/bin/env bash
# Compile the My OS desktop (Qt 6 / QML) inside a Fedora 44 container so it
# links against the same Qt that the ISO will ship. Rootless Podman is enough.
# Output: build/stage/usr/bin/{myos-shell,myos-settings} and the .desktop file.
# Usage: [MYOS_DISPLAY_NAME="My OS"] scripts/build-desktop.sh   (default name: My OS)
set -euo pipefail
# shellcheck source=scripts/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

builder_image="${MYOS_BUILDER_IMAGE:-registry.fedoraproject.org/fedora:44}"
stage="${MYOS_ROOT}/build/stage"
mkdir -p "${stage}"

build_packages=(cmake gcc-c++ make qt6-qtbase-devel qt6-qtdeclarative-devel layer-shell-qt-devel)

# Runs on Fedora 44, either directly (MYOS_NATIVE=1) or inside Podman.
native_build() {
  local src="$1" dest="$2" work
  work="$(mktemp -d)"
  cmake -S "${src}" -B "${work}" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr \
    -DMYOS_DISPLAY_NAME="${MYOS_DISPLAY_NAME:-My OS}"
  cmake --build "${work}" -j"$(nproc)"
  DESTDIR="${dest}" cmake --install "${work}"
  rm -r -- "${work}"
}

if [[ "${MYOS_NATIVE:-0}" == 1 ]]; then
  dnf install -y "${build_packages[@]}"
  native_build "${MYOS_ROOT}" "${stage}"
else
  require_cmd podman "Install it: sudo apt install -y podman (see docs/troubleshooting.md)"
  info "Building the desktop in ${builder_image} (first run downloads packages)"
  podman run --rm \
      -v "${MYOS_ROOT}:/src:Z" \
      -e MYOS_NATIVE=1 \
      -e "MYOS_DISPLAY_NAME=${MYOS_DISPLAY_NAME:-My OS}" \
      "${builder_image}" /src/scripts/build-desktop.sh \
    || die "Desktop build failed. Read the compiler output above."
fi

for f in usr/bin/myos-shell usr/bin/myos-settings usr/share/applications/myos-settings.desktop; do
  [[ -f "${stage}/${f}" ]] || die "Expected build output is missing: ${stage}/${f}"
done
info "Desktop built into ${stage}"
