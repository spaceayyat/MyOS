#!/usr/bin/env bash
# Shared helpers for VYLO OS scripts. Source this file; do not execute it.

# Resolve repository root from this file's location.
VYLO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export VYLO_ROOT

# Used by the scripts that source this file.
# shellcheck disable=SC2034
IMAGE_NAME="${VYLO_IMAGE_NAME:-localhost/vylo}"
# shellcheck disable=SC2034
IMAGE_TAG="${VYLO_IMAGE_TAG:-dev}"
DEFAULT_BASE="quay.io/fedora/fedora-bootc:44"
BASE_ENV_FILE="${VYLO_ROOT}/image/base-image.env"

info() { printf '[vylo] %s\n' "$*"; }
warn() { printf '[vylo] WARNING: %s\n' "$*" >&2; }
die()  { printf '[vylo] ERROR: %s\n' "$*" >&2; exit 1; }

require_cmd() {
  # require_cmd <command> <install hint>
  command -v "$1" >/dev/null 2>&1 || die "'$1' is not installed. ${2:-}"
}

# Echo the base image reference to build from: digest-pinned if available.
resolve_base_image() {
  if [[ -n "${VYLO_BASE_IMAGE:-}" ]]; then
    printf '%s\n' "${VYLO_BASE_IMAGE}"
  elif [[ -f "${BASE_ENV_FILE}" ]]; then
    # shellcheck disable=SC1090
    ( . "${BASE_ENV_FILE}" && printf '%s\n' "${BASE_IMAGE_PINNED:-${DEFAULT_BASE}}" )
  else
    printf '%s\n' "${DEFAULT_BASE}"
  fi
}
