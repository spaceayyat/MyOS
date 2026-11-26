#!/usr/bin/env bash
# Branding checks: the project is called "My OS" (two words) for people and
# "myos" / "MyOS" / "MYOS_" in technical identifiers. Needs bash and grep.
# Usage: tests/unit/test_branding.sh
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

# Default display name is exactly "My OS".
grep -q 'set(MYOS_DISPLAY_NAME "My OS"' "${root}/CMakeLists.txt" \
  && ok "default display name is 'My OS'" || bad "default display name is not 'My OS'"

# Technical identifiers must never contain a space.
if grep -rn 'My OS' "${root}/CMakeLists.txt" "${root}/image/config" "${root}/image/kiwi/config.sh" \
     | grep -vE '^[^:]*:[0-9]+:\s*(#|//)|MYOS_DISPLAY_NAME' | grep -q .; then
  bad "'My OS' (with a space) used inside a technical identifier"
else
  ok "no spaced name in CMake/session/config identifiers"
fi
grep -q '^project(MyOS ' "${root}/CMakeLists.txt" && ok "CMake project() is MyOS" || bad "CMake project() name is wrong"

# User-facing strings carry the new name.
for f in desktop/shell/Panel.qml desktop/shell/Wallpaper.qml desktop/launcher/Launcher.qml \
         desktop/settings/main.qml desktop/settings/myos-settings.desktop; do
  grep -q 'My OS' "${root}/${f}" && ok "branded: ${f}" || bad "not branded: ${f}"
done
grep -q 'title="My OS"' "${root}/image/Containerfile" 2>/dev/null \
  || grep -q 'image.title=\\\?"My OS' "${root}/image/Containerfile" \
  && ok "Containerfile title label is My OS" || bad "Containerfile title label"

echo
echo "[myos] Result: ${pass} passed, ${failed} failed"
(( failed == 0 ))
