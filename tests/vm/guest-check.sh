#!/bin/bash
# Runs INSIDE the booted live system, injected by tests/vm/boot_test.py through
# a systemd credential. Writes results to the serial port.
exec >/dev/ttyS0 2>&1
set -u

result() { echo "MYOS-CHECK $2 $1 ${3:-}"; }
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

# Desktop: the live user must end up in a running Plasma Wayland session.
check live-user wait_for 300 id liveuser
check kwin wait_for 600 pgrep -u liveuser -x kwin_wayland
check plasmashell wait_for 300 pgrep -u liveuser -x plasmashell
check display-manager active plasmalogin.service

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
# Single quotes are intentional: the inner bash expands this.
# shellcheck disable=SC2016
check selinux-enforcing bash -c '[[ $(getenforce) == Enforcing ]] && getenforce'
check firewalld active firewalld.service
check root-locked bash -c 'passwd -S root | grep -E "^root (L|LK) "'
check no-auto-update-on-live bash -c '! systemctl is-active --quiet dnf5-automatic.timer'

# MyOS extras
check myos-binaries bash -c 'test -x /usr/bin/myos-shell && test -x /usr/bin/myos-settings && ! ldd /usr/bin/myos-shell /usr/bin/myos-settings | grep "not found"'
check installer bash -c 'command -v liveinst'

echo "MYOS-FACT default-sink $(as_live wpctl inspect @DEFAULT_AUDIO_SINK@ 2>&1 | grep -m1 node.description)"
echo "MYOS-FACT lookandfeel $(as_live kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage 2>&1)"
echo "MYOS-FACT avc-denials $(journalctl -b --no-pager -q _AUDIT_TYPE_NAME=AVC 2>/dev/null | grep -c 'denied')"
journalctl -b --no-pager -q 2>/dev/null | grep 'avc:  *denied' | head -20 | sed 's/^/MYOS-AVC /'
echo "MYOS-FACT failed-units $(systemctl --failed --plain --no-legend | awk '{print $1}' | tr '\n' ' ')"

sleep 30          # let the desktop finish drawing
echo "MYOS-SHOT"
sleep 15
echo "MYOS-DONE"
systemctl poweroff
