#!/usr/bin/env bash
# Branding checks: the project is called "VYLO OS" (two words) for people and
# "vylo" / "VYLO" / "VYLO_" in technical identifiers. Needs bash and grep.
# Usage: tests/unit/test_branding.sh
# ok() and bad() always succeed, so "test && ok || bad" is safe here.
# shellcheck disable=SC2015
set -uo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
pass=0; failed=0
ok()  { printf '  PASS  %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL  %s\n' "$1"; failed=$((failed + 1)); }

# No old names anywhere outside .git and this test file.
if grep -rIniE 'youros|kivra' "${root}" --exclude-dir=.git --exclude-dir=build --exclude-dir=output \
     --exclude=test_branding.sh | grep -q .; then
  bad "old project names (YouROS / KIVRA) still present"
else
  ok "no old project names left"
fi

# Default display name is exactly "VYLO OS".
grep -q 'set(VYLO_DISPLAY_NAME "VYLO OS"' "${root}/CMakeLists.txt" \
  && ok "default display name is 'VYLO OS'" || bad "default display name is not 'VYLO OS'"

# Technical identifiers must never contain a space.
if grep -rn 'VYLO OS' "${root}/CMakeLists.txt" "${root}/image/config" "${root}/image/kiwi/config.sh" \
     | grep -vE '^[^:]*:[0-9]+:\s*(#|//|/\*)|VYLO_DISPLAY_NAME|(PRETTY_)?NAME="VYLO OS' | grep -q .; then
  bad "'VYLO OS' (with a space) used inside a technical identifier"
else
  ok "no spaced name in CMake/session/config identifiers"
fi
grep -q '^project(VYLO ' "${root}/CMakeLists.txt" && ok "CMake project() is VYLO" || bad "CMake project() name is wrong"

# User-facing strings carry the new name.
for f in desktop/shell/Panel.qml desktop/shell/Wallpaper.qml desktop/launcher/Launcher.qml \
         desktop/settings/main.qml desktop/settings/vylo-settings.desktop; do
  grep -q 'VYLO OS' "${root}/${f}" && ok "branded: ${f}" || bad "not branded: ${f}"
done
grep -q 'title="VYLO OS"' "${root}/image/Containerfile" 2>/dev/null \
  || grep -q 'image.title=\\\?"VYLO OS' "${root}/image/Containerfile" \
  && ok "Containerfile title label is VYLO OS" || bad "Containerfile title label"

echo
echo "[vylo] Result: ${pass} passed, ${failed} failed"
(( failed == 0 ))
