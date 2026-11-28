#!/usr/bin/env bash
# The `vylo` command, run against a throwaway settings directory, and its
# colour and wallpaper names compared with the desktop's.
# Usage: tests/unit/test_vylo_cli.sh
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
vylo=image/config/rootfs-vylo/usr/bin/vylo
work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT
export XDG_CONFIG_HOME="${work}"
conf="${work}/vylo/vylo.conf"
fails=0
check() { # check <description> <command...>
  if "${@:2}" >/dev/null 2>&1; then echo "  PASS  $1"; else echo "  FAIL  $1"; fails=1; fi
}
# shellcheck disable=SC2317  # called through check
refuses() { ! "$@"; }

check "help is printed" bash -c "${vylo} help | grep -q 'vylo accent'"
check "accent defaults to indigo" bash -c "[[ \$(${vylo} accent) == indigo ]]"
check "an unknown accent is refused" refuses "${vylo}" accent beige
check "nothing was written for it" test ! -e "${conf}"

mkdir -p "${work}/vylo"
printf '[appearance]\ntheme=light\n\n[prefs]\nwelcomeDone=true\npinned=helium, foot\n' >"${conf}"
check "accent can be changed" "${vylo}" accent rose
check "wallpaper can be changed" "${vylo}" wallpaper deep-void
check "theme can be changed" "${vylo}" theme dark
check "new values are saved" bash -c "grep -qx accent=rose '${conf}' && grep -qx wallpaper=deep-void '${conf}' && grep -qx theme=dark '${conf}'"
check "other settings are kept" bash -c "grep -qx welcomeDone=true '${conf}' && grep -qx 'pinned=helium, foot' '${conf}'"
check "an unknown command fails" refuses "${vylo}" explode

check "colours match the desktop" python3 -I - <<'PY'
import re, runpy
cli = runpy.run_path("image/config/rootfs-vylo/usr/bin/vylo", run_name="cli")
theme = open("shared/theme/Theme.qml").read()
shell = dict(re.findall(r'(\w+):\s+\{ d: "(#\w{6})"', theme))
assert {k: v.lower() for k, v in cli["ACCENTS"].items()} == {k: v.lower() for k, v in shell.items()}
api = open("shared/system-api/systemapi.cpp").read()
body = api.split("SystemApi::wallpaperNames()")[1].split("}\n")[0]
assert list(cli["WALLPAPERS"]) == re.findall(r'QStringLiteral\("([\w-]+)"\)', body)
PY

[[ ${fails} -eq 0 ]] && echo "vylo command: all passed"
exit "${fails}"
