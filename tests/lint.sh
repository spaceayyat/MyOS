#!/usr/bin/env bash
# shellcheck every shell script in the repository (found by shebang).
# Usage: tests/lint.sh
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
command -v shellcheck >/dev/null || { echo "shellcheck is not installed" >&2; exit 1; }

mapfile -t scripts < <(git ls-files -z | xargs -0 awk \
  'FNR==1 && /^#!.*(bash|[\/ ]sh)( |$)/ {print FILENAME}')
(( ${#scripts[@]} > 0 )) || { echo "no scripts found" >&2; exit 1; }
printf 'shellcheck: %s\n' "${scripts[@]}"
shellcheck --version
shellcheck -x "${scripts[@]}"
echo "shellcheck passed for ${#scripts[@]} scripts"
