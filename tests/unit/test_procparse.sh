#!/usr/bin/env bash
# Compiles and runs the Qt-free /proc parser tests. Needs g++.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "${tmp}"' EXIT
g++ -std=c++17 -Wall -Wextra -I"${root}/shared/system-api" "${root}/tests/unit/test_procparse.cpp" -o "${tmp}/t"
"${tmp}/t" | tee "${tmp}/out"
if grep -q FAIL "${tmp}/out"; then echo "[myos] Result: failed"; exit 1; fi
echo "[myos] Result: $(grep -c PASS "${tmp}/out") passed, 0 failed"
