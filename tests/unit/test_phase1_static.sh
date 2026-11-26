#!/usr/bin/env bash
# Static checks for the Phase 1 desktop and ISO configuration.
# These do NOT compile Qt code or build an ISO; they catch typos and unsafe
# patterns early. Needs bash, grep and python3.
# Usage: tests/unit/test_phase1_static.sh
set -uo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
pass=0; failed=0
ok()  { printf '  PASS  %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL  %s\n' "$1"; failed=$((failed + 1)); }
check() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else bad "$d"; fi; }

# --- required files -------------------------------------------------------
for f in CMakeLists.txt \
         shared/system-api/{CMakeLists.txt,systemapi.h,systemapi.cpp} \
         shared/theme/Theme.qml \
         desktop/shell/{CMakeLists.txt,main.cpp,shellstate.h,Wallpaper.qml,Panel.qml,Widgets.qml,Drawer.qml,EdgeHandle.qml} \
         desktop/widgets/{ClockWidget,CalendarWidget,WeatherWidget,MonitorWidget}.qml shared/ui/Card.qml \
         shared/system-api/procparse.h tests/unit/{check_qml_refs.py,test_procparse.sh} \
         desktop/launcher/Launcher.qml \
         desktop/settings/{CMakeLists.txt,main.cpp,main.qml,myos-settings.desktop} \
         image/kiwi/{config.xml,config.sh} \
         image/config/rootfs/etc/systemd/system/getty@tty1.service.d/autologin.conf \
         image/config/rootfs/etc/profile.d/myos-session.sh \
         image/config/rootfs/etc/xdg/labwc/{environment,autostart} \
         image/config/rootfs/usr/bin/myos-session \
         scripts/build-desktop.sh scripts/build-iso.sh; do
  [[ -f "${root}/${f}" ]] && ok "file exists: ${f}" || bad "file missing: ${f}"
done

# --- syntax ---------------------------------------------------------------
for s in "${root}"/scripts/*.sh "${root}"/image/kiwi/config.sh \
         "${root}"/image/config/rootfs/usr/bin/myos-session \
         "${root}"/image/config/rootfs/etc/profile.d/myos-session.sh; do
  bash -n "${s}" 2>/dev/null && ok "shell syntax ok: ${s#"${root}"/}" || bad "shell syntax error: ${s#"${root}"/}"
done

check "kiwi config.xml is well-formed XML" \
  python3 -I -c "import sys, xml.dom.minidom as m; m.parse(sys.argv[1])" "${root}/image/kiwi/config.xml"

# Balanced braces / parentheses / brackets in QML and C++ (see check_brackets.py).
for f in desktop/shell/Wallpaper.qml desktop/shell/Panel.qml desktop/launcher/Launcher.qml \
         desktop/shell/Widgets.qml desktop/shell/Drawer.qml desktop/shell/EdgeHandle.qml \
         desktop/widgets/ClockWidget.qml desktop/widgets/CalendarWidget.qml \
         desktop/widgets/WeatherWidget.qml desktop/widgets/MonitorWidget.qml shared/ui/Card.qml \
         desktop/settings/main.qml shared/theme/Theme.qml \
         desktop/shell/main.cpp desktop/settings/main.cpp desktop/shell/shellstate.h \
         shared/system-api/systemapi.cpp shared/system-api/systemapi.h; do
  check "balanced brackets: ${f}" python3 -I "${root}/tests/unit/check_brackets.py" "${root}/${f}"
done

# --- every QML file the CMake resource lists names must exist -------------
for f in Wallpaper.qml Panel.qml; do
  grep -q "${f}" "${root}/desktop/shell/CMakeLists.txt" && ok "shell CMake lists ${f}" || bad "shell CMake does not list ${f}"
done
grep -q 'Launcher.qml' "${root}/desktop/shell/CMakeLists.txt" && ok "shell CMake lists Launcher.qml" || bad "shell CMake does not list Launcher.qml"
grep -q 'main.qml' "${root}/desktop/settings/CMakeLists.txt" && ok "settings CMake lists main.qml" || bad "settings CMake does not list main.qml"
# main.cpp loads exactly the QML files that are bundled.
for f in Wallpaper.qml Panel.qml Launcher.qml; do
  grep -q "${f}" "${root}/desktop/shell/main.cpp" && ok "main.cpp loads ${f}" || bad "main.cpp does not load ${f}"
done

# --- the required desktop features are present ----------------------------
grep -q 'Qt.formatDateTime' "${root}/desktop/shell/Panel.qml" && ok "panel has a clock" || bad "panel has no clock"
grep -q 'Qt.formatTime' "${root}/desktop/widgets/ClockWidget.qml" && ok "clock widget uses real time" || bad "clock widget does not use real time"
! grep -Eq '°|sunny|cloudy|rain' "${root}/desktop/widgets/WeatherWidget.qml" && ok "weather widget shows no invented conditions" || bad "weather widget contains invented conditions"
grep -q 'Sys.cpuPercent' "${root}/desktop/widgets/MonitorWidget.qml" && ok "monitor widget reads system data" || bad "monitor widget has no system data"
for w in 'Search applications' Home Applications Appearance Settings; do grep -q "${w}" "${root}/desktop/launcher/Launcher.qml" && ok "launcher has: ${w}" || bad "launcher lacks: ${w}"; done
grep -q 'windowManagementAvailable' "${root}/desktop/shell/Drawer.qml" && ok "drawer gates window management behind a capability flag" || bad "drawer does not gate window management"
check "QML cross-references resolve (Sys/Shell/Theme/CMake)" python3 "${root}/tests/unit/check_qml_refs.py"
check "/proc parser unit tests pass" bash "${root}/tests/unit/test_procparse.sh"
grep -q 'Sys.osName' "${root}/desktop/shell/Wallpaper.qml" && ok "wallpaper shows the OS name" || bad "wallpaper does not show the OS name"
grep -q 'Switch' "${root}/desktop/settings/main.qml" && ok "settings has a theme switch" || bad "settings has no theme switch"
grep -q 'openTerminal' "${root}/desktop/launcher/Launcher.qml" && ok "launcher can open a terminal" || bad "launcher cannot open a terminal"
grep -q 'AnchorBottom' "${root}/desktop/shell/main.cpp" && ok "panel is anchored to the bottom" || bad "panel is not anchored to the bottom"

# --- image security rules --------------------------------------------------
! grep -q 'pwdformat="plain"' "${root}/image/kiwi/config.xml" && ok "no plain-text passwords in kiwi config" || bad "plain-text password in kiwi config"
[[ "$(grep -c 'password="\*"' "${root}/image/kiwi/config.xml")" -ge 2 ]] && ok "root and liveuser accounts are locked" || bad "an account is not locked"
! grep -Eq '<source path="http://' "${root}/image/kiwi/config.xml" && ok "repositories use https" || bad "a repository uses plain http"
grep -q 'package_gpgcheck="true"' "${root}/image/kiwi/config.xml" && ok "package signatures are checked" || bad "package signature checking is not enabled"
! grep -Eqi 'curl[^|]*\|[[:space:]]*(ba)?sh|chpasswd|NOPASSWD' \
    "${root}/image/kiwi/config.sh" "${root}"/scripts/*.sh "${root}"/image/config/rootfs/usr/bin/myos-session \
  && ok "no curl|sh, chpasswd or NOPASSWD in scripts" || bad "found curl|sh, chpasswd or NOPASSWD"
! grep -Eq 'system\(|popen\(|"/bin/sh"|"sh", *"-c"|sh -c' "${root}/shared/system-api/systemapi.cpp" \
  && ok "system API never runs shell command strings" || bad "system API runs a shell"

echo
echo "[myos] Result: ${pass} passed, ${failed} failed"
(( failed == 0 ))
