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
  foot nautilus gnome-text-editor gnome-software lxqt-policykit libnotify sddm fastfetch python3
echo "== policy agent files"
rpm -ql lxqt-policykit | grep -E '/(bin|libexec)/' | tee "${out}/policy-agent.log"
VYLO_NATIVE=1 "${VYLO_ROOT}/scripts/build-desktop.sh"
cp -a "${VYLO_ROOT}/build/stage/usr/." /usr/
# The login screen reads its wallpaper from the installed location.
cp -r "${VYLO_ROOT}/image/config/rootfs/usr/share/wallpapers/vylo" /usr/share/wallpapers/

# The `vylo` command, the terminal's look and the system name, as installed.
vylo_root="${VYLO_ROOT}/image/config/rootfs-vylo"
mkdir -p /usr/share/vylo
cp -r "${vylo_root}/usr/share/vylo/fastfetch" "${vylo_root}/usr/share/vylo/xdg" /usr/share/vylo/
install -m 0755 "${vylo_root}/usr/bin/vylo" /usr/bin/vylo
sh "${vylo_root}/usr/libexec/vylo/os-name"
foot --check-config -c /usr/share/vylo/xdg/foot/foot.ini 2>&1 | tee "${out}/foot-config.log"

work="$(mktemp -d)"
mkdir -p "${work}/run" "${work}/labwc" "${work}/home"
chmod 700 "${work}/run"
cp "${VYLO_ROOT}"/image/config/rootfs/usr/share/vylo/labwc/{rc.xml,themerc-override} "${work}/labwc/"
export XDG_RUNTIME_DIR="${work}/run" HOME="${work}/home" USER=traveller
export VYLO_DATA_DIR="${VYLO_ROOT}/image/config/rootfs/usr/share"
export WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 WLR_RENDERER=pixman
export LANG=C.UTF-8
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
mkdir -p "${HOME}/.config/vylo"
# The installation-media and first-start welcome windows.
shot welcome-live env VYLO_LIVE=1 vylo-shell
shot welcome vylo-shell
printf '[prefs]\nwelcomeDone=true\n' >"${HOME}/.config/vylo/vylo.conf"
shot desktop vylo-shell
shot launcher env VYLO_PREVIEW=launcher vylo-shell
shot quick-panel env VYLO_PREVIEW=flyout vylo-shell
vylo-shell >"${OUT}/shell-behind.log" 2>&1 &
behind=$!
sleep 4
shot settings vylo-settings
kill "${behind}"
# Two open windows and a notification: the dock and the popups.
vylo-shell >"${OUT}/windows.log" 2>&1 &
behind=$!
sleep 4
foot >/dev/null 2>&1 &
terminal=$!
sleep 2
vylo-settings >>"${OUT}/windows.log" 2>&1 &
settings=$!
sleep 4
notify-send -a "VYLO" "Welcome aboard" "Notifications show up here." || echo "notify-send failed" >>"${OUT}/errors"
sleep 2
grim "${OUT}/windows.png"
vylo-shell --launcher || echo "launcher shortcut failed" >>"${OUT}/errors"
sleep 2
grim "${OUT}/shortcut.png"
kill "${terminal}" "${settings}" "${behind}"
wait
# The same desktop after choosing another accent colour.
mkdir -p "${HOME}/.config/vylo"
printf '[prefs]\naccent=lilac\nwelcomeDone=true\n' >"${HOME}/.config/vylo/vylo.conf"
shot lilac vylo-shell
# Every colour has its own wallpaper.
for colour in cyan rose amber; do
  printf '[prefs]\naccent=%s\nwelcomeDone=true\n' "${colour}" >"${HOME}/.config/vylo/vylo.conf"
  shot "${colour}" vylo-shell
done
rm "${HOME}/.config/vylo/vylo.conf"
# The themed terminal showing `vylo info`.
printf '[prefs]\nwelcomeDone=true\n' >"${HOME}/.config/vylo/vylo.conf"
vylo-shell >"${OUT}/terminal-behind.log" 2>&1 &
behind=$!
sleep 4
shot terminal foot -c /usr/share/vylo/xdg/foot/foot.ini -W 108x28 sh -c 'vylo info; sleep 60'
kill "${behind}"; wait "${behind}" 2>/dev/null
rm "${HOME}/.config/vylo/vylo.conf"
shot login sddm-greeter-qt6 --test-mode --theme "${VYLO_ROOT}/image/config/rootfs-vylo/usr/share/sddm/themes/vylo"
SHOTS
chmod +x "${work}/shots.sh"
timeout 300 dbus-run-session labwc -C "${work}/labwc" -S "${work}/shots.sh" >"${out}/labwc.log" 2>&1 || true

status=0
for name in welcome-live welcome desktop launcher quick-panel settings windows shortcut lilac cyan rose amber terminal login; do
  [[ -s "${out}/${name}.png" ]] || { echo "missing screenshot: ${name}"; status=1; }
done
[[ ! -s "${out}/errors" ]] || { cat "${out}/errors"; status=1; }
echo "== program output"
tail -n +1 "${out}"/*.log
# Any QML complaint is a failure.
if grep -nE 'qrc:/|TypeError|ReferenceError|is not installed|Binding loop' \
     "${out}"/{welcome-live,welcome,desktop,launcher,quick-panel,settings,windows,lilac,cyan,rose,amber,shell-behind}.log \
   || grep -nE 'Main\.qml:[0-9]+' "${out}/login.log"; then
  echo "QML problems found"; status=1
fi
exit "${status}"
