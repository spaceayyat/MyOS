#!/usr/bin/env bash
# Static checks for the Phase 1 desktop and ISO configuration.
# These do NOT compile Qt code or build an ISO; they catch typos and unsafe
# patterns early. Needs bash, grep and python3.
# Usage: tests/unit/test_phase1_static.sh
# ok() and bad() always succeed, so "test && ok || bad" is safe here.
# shellcheck disable=SC2015
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
         desktop/shell/{CMakeLists.txt,main.cpp,shellstate.h,appicons.h,Wallpaper.qml,Panel.qml,Widgets.qml,Dock.qml,Flyout.qml} \
         desktop/widgets/{ClockWidget,CalendarWidget,MonthView,WeatherWidget,MonitorWidget}.qml shared/ui/{Card,Icon,AppIcon,Toggle,Logo}.qml \
         shared/system-api/procparse.h tests/unit/{check_qml_refs.py,test_procparse.sh} \
         desktop/launcher/Launcher.qml \
         desktop/settings/{CMakeLists.txt,main.cpp,main.qml,vylo-settings.desktop} \
         image/kiwi/{config.xml,config.sh} \
         image/config/rootfs/usr/share/vylo/labwc/{environment,autostart} \
         image/config/rootfs/usr/share/wayland-sessions/vylo.desktop \
         image/config/rootfs/usr/bin/vylo-session \
         image/config/rootfs-{gnome,plasma}/etc/sysconfig/livesys \
         image/config/rootfs-vylo/usr/share/sddm/themes/vylo/{Main.qml,metadata.desktop,theme.conf,logo.png} \
         image/config/rootfs-vylo/usr/share/plymouth/themes/vylo/{vylo.plymouth,vylo.script,logo.png,dot.png} \
         image/config/rootfs-vylo/{etc/systemd/system/vylo-live.service,usr/libexec/vylo/live-setup} \
         tests/{lint.sh,validate-image.sh,check_packages.py,vm/boot_test.py,vm/guest-check.sh} \
         scripts/build-desktop.sh scripts/build-iso.sh; do
  [[ -f "${root}/${f}" ]] && ok "file exists: ${f}" || bad "file missing: ${f}"
done

# --- syntax ---------------------------------------------------------------
for s in "${root}"/scripts/*.sh "${root}"/tests/*.sh "${root}"/tests/vm/*.sh \
         "${root}"/image/kiwi/config.sh "${root}"/image/config/rootfs/usr/bin/vylo-session \
         "${root}"/image/config/rootfs/usr/libexec/vylo/{snapper-setup,lock-root} \
         "${root}"/image/config/rootfs-vylo/usr/libexec/vylo/live-setup; do
  bash -n "${s}" 2>/dev/null && ok "shell syntax ok: ${s#"${root}"/}" || bad "shell syntax error: ${s#"${root}"/}"
done

check "kiwi config.xml is well-formed XML" \
  python3 -I -c "import sys, xml.dom.minidom as m; m.parse(sys.argv[1])" "${root}/image/kiwi/config.xml"

# Balanced braces / parentheses / brackets in QML and C++ (see check_brackets.py).
for f in desktop/shell/Wallpaper.qml desktop/shell/Panel.qml desktop/launcher/Launcher.qml \
         desktop/shell/Widgets.qml desktop/shell/Dock.qml desktop/shell/Flyout.qml \
         desktop/widgets/MonthView.qml shared/ui/Icon.qml shared/ui/AppIcon.qml \
         desktop/widgets/ClockWidget.qml desktop/widgets/CalendarWidget.qml \
         desktop/widgets/WeatherWidget.qml desktop/widgets/MonitorWidget.qml shared/ui/Card.qml \
         desktop/settings/main.qml shared/theme/Theme.qml \
         desktop/shell/main.cpp desktop/settings/main.cpp desktop/shell/shellstate.h \
         shared/system-api/systemapi.cpp shared/system-api/systemapi.h; do
  check "balanced brackets: ${f}" python3 -I "${root}/tests/unit/check_brackets.py" "${root}/${f}"
done

# --- every QML file the CMake resource lists names must exist -------------
for f in Wallpaper.qml Panel.qml Widgets.qml Dock.qml Flyout.qml; do
  grep -q "${f}" "${root}/desktop/shell/CMakeLists.txt" && ok "shell CMake lists ${f}" || bad "shell CMake does not list ${f}"
done
grep -q 'Launcher.qml' "${root}/desktop/shell/CMakeLists.txt" && ok "shell CMake lists Launcher.qml" || bad "shell CMake does not list Launcher.qml"
grep -q 'main.qml' "${root}/desktop/settings/CMakeLists.txt" && ok "settings CMake lists main.qml" || bad "settings CMake does not list main.qml"
# main.cpp loads every shell window.
for f in Wallpaper Widgets Panel Dock Launcher Flyout; do
  grep -q "QStringLiteral(\"${f}\")" "${root}/desktop/shell/main.cpp" && ok "main.cpp loads ${f}" || bad "main.cpp does not load ${f}"
done

# --- the required desktop features are present ----------------------------
grep -q 'Qt.formatDateTime' "${root}/desktop/shell/Panel.qml" && ok "panel has a clock" || bad "panel has no clock"
grep -q 'Qt.formatTime' "${root}/desktop/widgets/ClockWidget.qml" && ok "clock widget uses real time" || bad "clock widget does not use real time"
! grep -Eq '°|sunny|cloudy|rain' "${root}/desktop/widgets/WeatherWidget.qml" && ok "weather widget shows no invented conditions" || bad "weather widget contains invented conditions"
grep -q 'Sys.cpuPercent' "${root}/desktop/widgets/MonitorWidget.qml" && ok "monitor widget reads system data" || bad "monitor widget has no system data"
for w in 'Search applications' 'All apps' 'Sys.launch' 'Sys.power' 'Sys.togglePin'; do grep -q "${w}" "${root}/desktop/launcher/Launcher.qml" && ok "launcher has: ${w}" || bad "launcher lacks: ${w}"; done
grep -q 'Sys.pinnedApps' "${root}/desktop/shell/Dock.qml" && ok "dock shows the pinned applications" || bad "dock does not show pinned applications"
check "QML cross-references resolve (Sys/Shell/Theme/CMake)" python3 "${root}/tests/unit/check_qml_refs.py"
check "/proc parser unit tests pass" bash "${root}/tests/unit/test_procparse.sh"
grep -q 'Sys.prefs.wallpaper' "${root}/desktop/shell/Wallpaper.qml" && ok "wallpaper follows the user's choice" || bad "wallpaper ignores the user's choice"
for w in orbit-hills-{indigo,lilac,cyan,rose,amber} observatory-isles nebula-drift deep-void; do
  [[ -s "${root}/image/config/rootfs/usr/share/wallpapers/vylo/${w}.jpg" ]] && ok "wallpaper shipped: ${w}" || bad "wallpaper missing: ${w}"
done
grep -q 'Toggle {' "${root}/desktop/settings/main.qml" && ok "settings has a theme switch" || bad "settings has no theme switch"
grep -q 'AnchorTop' "${root}/desktop/shell/main.cpp" && ok "bar is anchored to the top" || bad "bar is not anchored to the top"
grep -q 'password.text === ""' "${root}/image/config/rootfs-vylo/usr/share/sddm/themes/vylo/Main.qml" && ok "login screen never sends an empty password" || bad "login screen may send an empty password"
grep -q 'ConditionKernelCommandLine=rd.live.image' "${root}/image/config/rootfs-vylo/etc/systemd/system/vylo-live.service" && ok "automatic login is limited to live media" || bad "automatic login is not limited to live media"
grep -q 'SetDisplayPasswordFunction' "${root}/image/config/rootfs-vylo/usr/share/plymouth/themes/vylo/vylo.script" && ok "boot splash can ask for the disk passphrase" || bad "boot splash cannot ask for the disk passphrase"

# --- image security rules --------------------------------------------------
check "image defines no user except a locked root (config validation)" \
  python3 -I "${root}/tests/unit/check_config.py" "${root}"
! grep -Eq '<source path="http://' "${root}/image/kiwi/config.xml" && ok "repositories use https" || bad "a repository uses plain http"
grep -q 'package_gpgcheck="true"' "${root}/image/kiwi/config.xml" && ok "package signatures are checked" || bad "package signature checking is not enabled"
! grep -Eqi 'curl[^|]*\|[[:space:]]*(ba)?sh|chpasswd|NOPASSWD' \
    "${root}/image/kiwi/config.sh" "${root}"/scripts/*.sh "${root}"/image/config/rootfs/usr/bin/vylo-session \
  && ok "no curl|sh, chpasswd or NOPASSWD in scripts" || bad "found curl|sh, chpasswd or NOPASSWD"
! grep -Eq 'system\(|popen\(|"/bin/sh"|"sh", *"-c"|sh -c' "${root}/shared/system-api/systemapi.cpp" \
  && ok "system API never runs shell command strings" || bad "system API runs a shell"

echo
echo "[vylo] Result: ${pass} passed, ${failed} failed"
(( failed == 0 ))
