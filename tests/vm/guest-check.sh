#!/bin/bash
# Runs INSIDE the booted live system, injected by tests/vm/boot_test.py through
# a systemd credential. Writes results to the serial port.
#
# Single-quoted strings given to eval or bash -c are expanded later, on purpose.
# shellcheck disable=SC2016
exec >/dev/ttyS0 2>&1
set -u

result() { echo "MYOS-CHECK $1 $2 ${3:-}"; }
check() {
  local name="$1"; shift
  local out
  if out="$("$@" 2>&1)"; then result "${name}" PASS "$(tail -n1 <<<"${out}")"
  else result "${name}" FAIL "$(tail -n3 <<<"${out}" | tr '\n' ' ')"; fi
}
wait_for() {
  # wait_for <seconds> <command...>
  local end=$((SECONDS + $1)); shift
  until "$@" >/dev/null 2>&1; do
    (( SECONDS < end )) || return 1
    sleep 5
  done
}
active() { wait_for 120 systemctl is-active --quiet "$1" && echo "$1 active"; }
as_live() {
  runuser -u liveuser -- env XDG_RUNTIME_DIR="/run/user/$(id -u liveuser)" "$@"
}

echo "MYOS-BEGIN $(. /etc/os-release; echo "${PRETTY_NAME}") kernel $(uname -r)"

if [[ -d /sys/firmware/efi ]]; then
  echo "MYOS-FACT firmware uefi"
  echo "MYOS-FACT secureboot $(mokutil --sb-state 2>&1 | head -1)"
else
  echo "MYOS-FACT firmware bios"
fi

if command -v gnome-shell >/dev/null; then
  edition=gnome compositor=gnome-shell shell=gnome-shell dm=gdm.service
else
  edition=plasma compositor=kwin_wayland shell=plasmashell dm=plasmalogin.service
fi
echo "MYOS-FACT edition ${edition}"

wayland_session() {
  local id
  for id in $(loginctl list-sessions --no-legend | awk '{print $1}'); do
    [[ "$(loginctl show-session "${id}" -p Name --value)" == liveuser ]] || continue
    [[ "$(loginctl show-session "${id}" -p Type --value)" == wayland ]] || continue
    echo "wayland session ${id}"
    return 0
  done
  return 1
}

# Desktop: the live user must end up in a running Wayland session.
check live-user wait_for 300 id liveuser
check compositor wait_for 600 pgrep -u liveuser -x "${compositor}"
check desktop-shell wait_for 300 pgrep -u liveuser -x "${shell}"
check user-session wait_for 120 wayland_session
check display-manager active "${dm}"

# Network
check networkmanager active NetworkManager.service
check network-connected wait_for 90 bash -c 'nmcli -t -f STATE general | grep -qx connected'
check https curl -fsS --retry 3 --max-time 30 -o /dev/null -w 'HTTP %{http_code}\n' https://fedoraproject.org/static/hotspot.txt

# Sound
check soundcard grep -m1 . /proc/asound/cards
check pipewire wait_for 120 as_live systemctl --user is-active pipewire.service
check wireplumber wait_for 120 as_live systemctl --user is-active wireplumber.service
check audio-sink wait_for 60 bash -c "runuser -u liveuser -- env XDG_RUNTIME_DIR=/run/user/\$(id -u liveuser) wpctl inspect @DEFAULT_AUDIO_SINK@"

# Bluetooth: the VM has no adapter. Loading the stack lets the service start;
# this proves the daemon runs, not that any hardware works.
modprobe bluetooth
systemctl start bluetooth.service
check bluetooth-service active bluetooth.service

# Printing
check cups-socket active cups.socket
check cups-scheduler bash -c 'lpstat -r | grep -x "scheduler is running"'

# Security
check selinux-enforcing bash -c '[[ $(getenforce) == Enforcing ]] && getenforce'
check firewalld active firewalld.service

# Root account. Record the real state first, then test how it behaves.
root_state() {
  local field
  field="$(getent shadow root | cut -d: -f2)"
  case "${field}" in
    "") echo "empty" ;;
    "!"*|"*"*) echo "locked" ;;
    *) echo "password-set" ;;
  esac
}
echo "MYOS-FACT root-password $(root_state)"
echo "MYOS-FACT root-passwd-status $(passwd -S root 2>&1)"
echo "MYOS-FACT root-before-lock $(journalctl -b -u livesys.service -o cat 2>/dev/null | grep -m1 'root password before')"
echo "MYOS-FACT livesys-passwd-lines $(grep -h 'passwd' /usr/libexec/livesys/livesys-main 2>&1 | tr '\n' ';')"
echo "MYOS-FACT liveuser-groups $(id -nG liveuser 2>&1)"
check root-no-usable-password bash -c "[[ \$(getent shadow root | cut -d: -f2) == [!*]* ]] && echo locked"
# An unprivileged account must not become root by pressing Enter.
check root-su-refused bash -c '! echo | timeout 30 runuser -u nobody -- su root -c true'
check ssh-server-off bash -c '! systemctl is-active --quiet sshd.service sshd.socket'
check no-auto-update-on-live bash -c '! systemctl is-active --quiet dnf5-automatic.timer'

# MyOS extras
check myos-binaries bash -c 'test -x /usr/bin/myos-shell && test -x /usr/bin/myos-settings && ! ldd /usr/bin/myos-shell /usr/bin/myos-settings | grep "not found"'
check installer bash -c 'command -v liveinst'

have_commands() {
  local name
  for name in "$@"; do command -v "${name}" || { echo "missing ${name}"; return 1; }; done
}
setting() { as_live dbus-run-session gsettings get "$1" "$2"; }

# Browser: Helium is the default in both editions and must actually start.
if [[ "${edition}" == gnome ]]; then desktop_name=GNOME; else desktop_name=KDE; fi
check default-browser eval '[[ $(as_live env XDG_CURRENT_DESKTOP=${desktop_name} xdg-mime query default x-scheme-handler/https) == helium.desktop ]] && echo helium.desktop'
check helium-runs eval 'as_live timeout 90 helium --headless --disable-gpu --dump-dom https://fedoraproject.org/static/hotspot.txt | grep -m1 OK'

if [[ "${edition}" == gnome ]]; then
  check applications have_commands nautilus ptyxis gnome-text-editor gnome-software gnome-control-center gnome-system-monitor loupe papers
  check customization-tools have_commands gnome-tweaks gnome-extensions-app
  check default-theme eval '[[ $(setting org.gnome.desktop.interface color-scheme) == *prefer-dark* && $(setting org.gnome.desktop.background picture-uri-dark) == */MyOS/* ]] && echo "MyOS dark"'
  check no-firefox eval '! rpm -q firefox'
else
  check applications have_commands dolphin konsole kate plasma-discover systemsettings okular gwenview helium firefox
  check default-theme eval '[[ $(as_live kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage) == org.myos.dark.desktop ]] && echo org.myos.dark.desktop'
fi

echo "MYOS-FACT default-sink $(as_live wpctl inspect @DEFAULT_AUDIO_SINK@ 2>&1 | grep -m1 node.description)"
echo "MYOS-FACT avc-denials $(journalctl -b --no-pager -q _AUDIT_TYPE_NAME=AVC 2>/dev/null | grep -c 'denied')"
journalctl -b --no-pager -q 2>/dev/null | grep 'avc:  *denied' | head -20 | sed 's/^/MYOS-AVC /'
echo "MYOS-FACT failed-units $(systemctl --failed --plain --no-legend | awk '{print $1}' | tr '\n' ' ')"

sleep 30          # let the desktop finish drawing
echo "MYOS-SHOT"
sleep 15
echo "MYOS-DONE"
systemctl poweroff
