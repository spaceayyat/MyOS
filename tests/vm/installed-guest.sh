#!/bin/bash
# Runs INSIDE the installed system, on the first boot and again after a reboot
# (injected by tests/vm/install_test.py).
#
# shellcheck disable=SC2016
exec >/dev/ttyS0 2>&1
set -u

disk_mode="$(cat "${CREDENTIALS_DIRECTORY}/myos.disk")"
marker=/var/lib/myos-install-test.rebooted
check() {
  local n="$1" out; shift
  if out="$("$@" 2>&1)"; then echo "MYOS-CHECK ${n} PASS $(tail -n1 <<<"${out}")"
  else echo "MYOS-CHECK ${n} FAIL $(tail -n3 <<<"${out}" | tr '\n' ' ')"; fi
}
wait_for() {
  local end=$((SECONDS + $1)); shift
  until "$@" >/dev/null 2>&1; do (( SECONDS < end )) || return 1; sleep 5; done
}
active() { wait_for 120 systemctl is-active --quiet "$1" && echo "$1 active"; }
online() { wait_for 90 curl -fsS --max-time 20 -o /dev/null https://fedoraproject.org/static/hotspot.txt; }

if command -v gnome-shell >/dev/null; then
  edition=gnome shell=gnome-shell dm=gdm.service
else
  edition=plasma shell=plasmashell dm=plasmalogin.service
fi

if [[ -e "${marker}" ]]; then
  echo "MYOS-REBOOTED"
  check reboot-selinux bash -c '[[ $(getenforce) == Enforcing ]]'
  check reboot-display-manager active "${dm}"
  check reboot-network online
  check reboot-persistence grep -qx persisted "${marker}"
  sleep 10
  echo "MYOS-DONE"
  systemctl poweroff
  exit 0
fi

echo "MYOS-BEGIN installed system $(. /etc/os-release; echo "${PRETTY_NAME}")"
[[ -d /sys/firmware/efi ]] && echo "MYOS-FACT firmware uefi" || echo "MYOS-FACT firmware bios"
echo "MYOS-FACT edition ${edition}"

check not-live bash -c '! grep -q rd.live.image /proc/cmdline'
check no-live-user bash -c '! id liveuser'
check user-created bash -c 'id -nG tester | grep -wq wheel && id -nG tester'
check root-locked bash -c '[[ $(getent shadow root | cut -d: -f2) == [!*]* ]]'
check no-empty-passwords bash -c '[[ -z $(awk -F: "\$2 == \"\"" /etc/shadow) ]]'
check root-btrfs bash -c '[[ $(findmnt -no FSTYPE /) == btrfs ]]'
echo "MYOS-FACT disk $(lsblk -nro NAME,TYPE,FSTYPE /dev/vda | tr '\n' ';')"
if [[ "${disk_mode}" == luks ]]; then
  check disk-encryption bash -c '[[ $(findmnt -no SOURCE /) == /dev/mapper/luks-* ]] && lsblk -nro FSTYPE /dev/vda | grep -x crypto_LUKS'
else
  check disk-encryption bash -c '! lsblk -nro FSTYPE /dev/vda | grep -x crypto_LUKS'
fi
check selinux-enforcing bash -c '[[ $(getenforce) == Enforcing ]]'
check firewalld active firewalld.service
check ssh-server-off bash -c '! systemctl is-active --quiet sshd.service sshd.socket'
check update-timer active dnf5-automatic.timer
check display-manager active "${dm}"
check network online
if [[ "${edition}" == gnome ]]; then
  check applications bash -c 'command -v helium nautilus ptyxis gnome-software gnome-tweaks'
else
  check applications bash -c 'command -v firefox dolphin konsole plasma-discover'
fi
check snapper-config wait_for 180 test -f /etc/snapper/configs/root
check snapper-recovery bash -c 'set -e
  f=/etc/myos-snapshot-test; echo original > $f
  n=$(snapper -c root create --print-number --description test)
  echo changed > $f
  snapper -c root undochange $n..0 $f
  grep -x original $f'
update_packages=(curl ca-certificates)
if [[ "${edition}" == gnome ]]; then update_packages+=(helium-bin); fi
check system-update timeout 900 dnf -y upgrade --refresh "${update_packages[@]}"

# Real login: the host types the password into the login screen.
sleep 20
echo "MYOS-REQUEST login"
check login wait_for 180 pgrep -u tester -x "${shell}"
echo "MYOS-FACT avc-denials $(journalctl -b --no-pager -q _AUDIT_TYPE_NAME=AVC 2>/dev/null | grep -c denied)"
echo "MYOS-FACT failed-units $(systemctl --failed --plain --no-legend | awk '{print $1}' | tr '\n' ' ')"
sleep 40
echo "MYOS-SHOT"
sleep 15
echo persisted > "${marker}"; sync
echo "MYOS-REBOOT"
systemctl reboot
