#!/usr/bin/env bash
# Smoke test: build the image, then inspect it. Does NOT boot anything.
# Usage: scripts/smoke-test.sh [--no-build]
#   --no-build   reuse an existing local image instead of rebuilding
# Exit code is non-zero if any check fails.
set -uo pipefail
# shellcheck source=scripts/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require_cmd podman "Install it: sudo apt install -y podman (see docs/development.md)"

pass=0; failed=0
check() {
  # check <description> <command...>
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    printf '  PASS  %s\n' "${desc}"; pass=$((pass + 1))
  else
    printf '  FAIL  %s\n' "${desc}"; failed=$((failed + 1))
  fi
}

ref="${IMAGE_NAME}:${IMAGE_TAG}"

if [[ "${1:-}" != "--no-build" ]]; then
  info "Step 1/2: build"
  "${MYOS_ROOT}/scripts/build-image.sh" || die "Build failed; smoke test cannot continue."
else
  info "Step 1/2: build skipped (--no-build)"
fi

info "Step 2/2: inspect ${ref}"
check "image exists locally"                podman image exists "${ref}"
check "image has My OS title label"        bash -c "podman image inspect '${ref}' --format '{{index .Config.Labels \"org.opencontainers.image.title\"}}' | grep -qxF 'My OS'"
check "bootc binary runs in the image"      podman run --rm --network=none "${ref}" bootc --version
check "base OS is Fedora"                   bash -c "podman run --rm --network=none '${ref}' cat /etc/os-release | grep -qx 'ID=fedora'"
check "bootc container lint passes"         podman run --rm --network=none "${ref}" bootc container lint
check "kernel is present (/usr/lib/modules)" bash -c "podman run --rm --network=none '${ref}' ls /usr/lib/modules | grep -q ."

echo
info "Result: ${pass} passed, ${failed} failed"
info "Not covered: converting to a disk image and booting it in a VM."
(( failed == 0 ))
