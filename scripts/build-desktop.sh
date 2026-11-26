#!/usr/bin/env bash
# Compile the My OS desktop (Qt 6 / QML) inside a Fedora 44 container so it
# links against the same Qt that the ISO will ship. Rootless Podman is enough.
# Output: build/stage/usr/bin/{myos-shell,myos-settings} and the .desktop file.
# Usage: [MYOS_DISPLAY_NAME="My OS"] scripts/build-desktop.sh   (default name: My OS)
set -euo pipefail
# shellcheck source=scripts/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require_cmd podman "Install it: sudo apt install -y podman (see docs/development.md)"

builder_image="${MYOS_BUILDER_IMAGE:-quay.io/fedora/fedora:44}"
stage="${MYOS_ROOT}/build/stage"
mkdir -p "${stage}"

info "Building the desktop in ${builder_image} (first run downloads packages)"
if ! podman run --rm \
      -v "${MYOS_ROOT}:/src:ro,Z" \
      -v "${stage}:/stage:Z" \
      -e "MYOS_DISPLAY_NAME=${MYOS_DISPLAY_NAME:-My OS}" \
      "${builder_image}" \
      bash -euxo pipefail -c '
        dnf install -y cmake gcc-c++ make qt6-qtbase-devel qt6-qtdeclarative-devel layer-shell-qt-devel
        cmake -S /src -B /tmp/build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DMYOS_DISPLAY_NAME="$MYOS_DISPLAY_NAME"
        cmake --build /tmp/build -j"$(nproc)"
        DESTDIR=/stage cmake --install /tmp/build
      '; then
  die "Desktop build failed. Read the compiler output above; paste it into an issue if you are stuck."
fi

for f in usr/bin/myos-shell usr/bin/myos-settings usr/share/applications/myos-settings.desktop; do
  [[ -f "${stage}/${f}" ]] || die "Expected build output is missing: ${stage}/${f}"
done
info "Desktop built into ${stage}"
