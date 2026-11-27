#!/usr/bin/env bash
# Build the desktop and photograph it running in a headless compositor. Fails on
# any QML warning. Meant for a throwaway Fedora 44 container (CI), as it
# installs packages. Usage: scripts/preview-shell.sh OUTPUT-DIR
set -euo pipefail
# shellcheck source=scripts/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
[[ $# -eq 1 ]] || die "usage: $0 OUTPUT-DIR"
out="$(mkdir -p "$1" && cd "$1" && pwd)"

dnf install -y labwc xorg-x11-server-Xwayland grim wlr-randr dbus-daemon qt6-qtwayland qt6-qtsvg layer-shell-qt \
  rsms-inter-fonts jetbrains-mono-fonts google-noto-sans-fonts papirus-icon-theme \
  foot nautilus gnome-text-editor gnome-software
VYLO_NATIVE=1 "${VYLO_ROOT}/scripts/build-desktop.sh"
cp -a "${VYLO_ROOT}/build/stage/usr/." /usr/

work="$(mktemp -d)"
mkdir -p "${work}/run" "${work}/labwc" "${work}/home"
chmod 700 "${work}/run"
cp "${VYLO_ROOT}"/image/config/rootfs/usr/share/vylo/labwc/{rc.xml,themerc-override} "${work}/labwc/"
export XDG_RUNTIME_DIR="${work}/run" HOME="${work}/home" USER=traveller
export VYLO_DATA_DIR="${VYLO_ROOT}/image/config/rootfs/usr/share"
export WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 WLR_RENDERER=pixman
export QT_QPA_PLATFORM=wayland QT_QUICK_BACKEND=software XDG_CURRENT_DESKTOP=VYLO
export OUT="${out}"

cat > "${work}/shots.sh" <<'SHOTS'
#!/usr/bin/env bash
set -u
wlr-randr --output HEADLESS-1 --custom-mode 1600x900
sleep 2
shot() {
  # shot <name> <command...>: start it, wait, photograph the screen, stop it.
  local name="$1"; shift
  "$@" >"${OUT}/${name}.log" 2>&1 &
  local pid=$!
  sleep 9
  if kill -0 "${pid}" 2>/dev/null; then grim "${OUT}/${name}.png"; else echo "${name}: exited early" >>"${OUT}/errors"; fi
  kill "${pid}" 2>/dev/null; wait "${pid}" 2>/dev/null
}
shot desktop vylo-shell
shot launcher env VYLO_PREVIEW=launcher vylo-shell
shot quick-panel env VYLO_PREVIEW=flyout vylo-shell
vylo-shell >"${OUT}/shell-behind.log" 2>&1 &
behind=$!
sleep 4
shot settings vylo-settings
kill "${behind}"
SHOTS
chmod +x "${work}/shots.sh"
timeout 180 dbus-run-session labwc -C "${work}/labwc" -S "${work}/shots.sh" >"${out}/labwc.log" 2>&1 || true

status=0
for name in desktop launcher quick-panel settings; do
  [[ -s "${out}/${name}.png" ]] || { echo "missing screenshot: ${name}"; status=1; }
done
[[ ! -s "${out}/errors" ]] || { cat "${out}/errors"; status=1; }
echo "== program output"
tail -n +1 "${out}"/*.log
# Any QML complaint is a failure.
if grep -nE 'qrc:/|TypeError|ReferenceError|is not installed|Binding loop' \
     "${out}"/{desktop,launcher,quick-panel,settings,shell-behind}.log; then
  echo "QML problems found"; status=1
fi
exit "${status}"
