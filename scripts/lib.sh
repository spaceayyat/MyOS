#!/usr/bin/env bash
# Shared helpers for My OS scripts. Source this file; do not execute it.

# Resolve repository root from this file's location.
MYOS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export MYOS_ROOT

IMAGE_NAME="${MYOS_IMAGE_NAME:-localhost/myos}"
IMAGE_TAG="${MYOS_IMAGE_TAG:-dev}"
DEFAULT_BASE="quay.io/fedora/fedora-bootc:44"
BASE_ENV_FILE="${MYOS_ROOT}/image/base-image.env"

info() { printf '[myos] %s\n' "$*"; }
warn() { printf '[myos] WARNING: %s\n' "$*" >&2; }
die()  { printf '[myos] ERROR: %s\n' "$*" >&2; exit 1; }

require_cmd() {
  # require_cmd <command> <install hint>
  command -v "$1" >/dev/null 2>&1 || die "'$1' is not installed. ${2:-}"
}

# Echo the base image reference to build from: digest-pinned if available.
resolve_base_image() {
  if [[ -n "${MYOS_BASE_IMAGE:-}" ]]; then
    printf '%s\n' "${MYOS_BASE_IMAGE}"
  elif [[ -f "${BASE_ENV_FILE}" ]]; then
    # shellcheck disable=SC1090
    ( . "${BASE_ENV_FILE}" && printf '%s\n' "${BASE_IMAGE_PINNED:-${DEFAULT_BASE}}" )
  else
    printf '%s\n' "${DEFAULT_BASE}"
  fi
}
