#!/usr/bin/env bash
# Unit test: repository layout, script hygiene, and honesty of the docs.
# Needs only bash and grep. Usage: tests/unit/test_repo_layout.sh
set -uo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
pass=0; failed=0
ok()   { printf '  PASS  %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  FAIL  %s\n' "$1"; failed=$((failed + 1)); }

for f in README.md LICENSE .gitignore \
         docs/architecture.md docs/roadmap.md docs/security.md docs/development.md \
         image/Containerfile \
         scripts/lib.sh scripts/check-env.sh scripts/pin-base-digest.sh scripts/build-image.sh scripts/smoke-test.sh; do
  [[ -f "${root}/${f}" ]] && ok "file exists: ${f}" || bad "file missing: ${f}"
done

for d in image/config desktop/shell desktop/launcher desktop/settings desktop/monitor desktop/software-center \
         shared/ui shared/theme shared/system-api packaging scripts tests/unit tests/integration tests/vm; do
  [[ -d "${root}/${d}" ]] && ok "dir exists: ${d}" || bad "dir missing: ${d}"
done

for s in "${root}"/scripts/*.sh "${root}"/tests/unit/*.sh; do
  bash -n "${s}" 2>/dev/null && ok "syntax ok: ${s#"${root}"/}" || bad "syntax error: ${s#"${root}"/}"
done

# Containerfile must pin an explicit Fedora release, never 'latest'.
grep -Eq '^ARG BASE_IMAGE=quay\.io/fedora/fedora-bootc:[0-9]+$' "${root}/image/Containerfile" \
  && ok "Containerfile pins an explicit Fedora release" || bad "Containerfile base is not an explicit release tag"
! grep -Eqi ':latest' "${root}/image/Containerfile" \
  && ok "Containerfile does not use :latest" || bad "Containerfile uses :latest"

# No obvious hard-coded secrets or destructive commands in scripts/Containerfile.
if grep -Eniq '(password|passwd|secret|token)[[:space:]]*=|rm -rf|mkfs|dd if=|chpasswd' \
     "${root}"/scripts/*.sh "${root}/image/Containerfile"; then
  bad "found a secret-like or destructive pattern in scripts/Containerfile"
else
  ok "no secret-like or destructive patterns in scripts/Containerfile"
fi

# Docs must not claim the OS boots or has a working desktop.
if grep -Eniq 'bootable (and )?(verified|works)|already boots|working desktop (is )?(available|ready)' \
     "${root}/README.md" "${root}"/docs/*.md; then
  bad "docs contain a claim that the OS boots / has a working desktop"
else
  ok "docs make no false boot/desktop claims"
fi

echo
echo "[myos] Result: ${pass} passed, ${failed} failed"
(( failed == 0 ))
