#!/usr/bin/env bash
# Build the My OS container image with Podman.
# Usage: scripts/build-image.sh
# Environment overrides:
#   MYOS_IMAGE_NAME  (default localhost/myos)
#   MYOS_IMAGE_TAG   (default dev)
#   MYOS_BASE_IMAGE  (default: digest from image/base-image.env, else Fedora 44 tag)
set -euo pipefail
# shellcheck source=scripts/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require_cmd podman "Install it: sudo apt install -y podman (see docs/development.md)"

base="$(resolve_base_image)"
if [[ "${base}" != *@sha256:* ]]; then
  warn "Base image is not digest-pinned (${base}). Build is NOT fully reproducible."
  warn "Run scripts/pin-base-digest.sh and commit image/base-image.env."
fi

containerfile="${MYOS_ROOT}/image/Containerfile"
[[ -f "${containerfile}" ]] || die "Missing ${containerfile}. Is the repository complete?"

info "Building ${IMAGE_NAME}:${IMAGE_TAG} from ${base}"
if ! podman build \
      --file "${containerfile}" \
      --build-arg "BASE_IMAGE=${base}" \
      --tag "${IMAGE_NAME}:${IMAGE_TAG}" \
      "${MYOS_ROOT}/image"; then
  die "podman build failed. Common causes: no network access to quay.io, a typo in the base image, or 'bootc container lint' rejecting the image. Read the output above."
fi

info "Build finished: ${IMAGE_NAME}:${IMAGE_TAG}"
info "Note: this is a container image, not yet a verified bootable OS."
