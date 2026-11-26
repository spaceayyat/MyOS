#!/bin/bash
# Runs INSIDE the live system (injected by tests/vm/install_test.py). Installs
# MyOS onto the blank virtual disk /dev/vda with Anaconda and a kickstart file.
#
# The shipped installer ("liveinst") refuses kickstart files, so this calls
# Anaconda directly with a liveimg payload. It exercises Anaconda's storage,
# user, payload and boot loader steps, NOT the graphical installer screens.
exec >/dev/ttyS0 2>&1
set -u

echo "MYOS-BEGIN live installer"
[[ -d /sys/firmware/efi ]] && echo "MYOS-FACT firmware uefi" || echo "MYOS-FACT firmware bios"
if command -v gnome-shell >/dev/null; then echo "MYOS-FACT edition gnome"
else echo "MYOS-FACT edition plasma"; fi
disk_mode="$(cat "${CREDENTIALS_DIRECTORY}/myos.disk")"
check() { local n="$1"; shift; if "$@"; then echo "MYOS-CHECK ${n} PASS"; else echo "MYOS-CHECK ${n} FAIL"; fi; }

for _ in $(seq 60); do id liveuser >/dev/null 2>&1 && break; sleep 5; done

image=""
for candidate in /run/initramfs/live/LiveOS/squashfs.img /run/initramfs/squashed.img; do
  [[ -f "${candidate}" ]] && { image="${candidate}"; break; }
done
echo "MYOS-FACT payload ${image:-not-found} $(ls /run/initramfs/live/LiveOS 2>/dev/null | tr '\n' ' ')"
check payload-found test -n "${image}"

encrypt=""
[[ "${disk_mode}" == luks ]] && encrypt="--encrypted --passphrase=luks0passphrase1"
cat > /run/myos-test.ks <<EOF
cmdline
lang en_US.UTF-8
keyboard us
timezone Africa/Casablanca --utc
network --bootproto=dhcp --activate
rootpw --lock
user --name=tester --groups=wheel --plaintext --password=tester0pass1
firewall --enabled
selinux --enforcing
ignoredisk --only-use=vda
zerombr
clearpart --all --initlabel --drives=vda
autopart --type=btrfs ${encrypt}
bootloader
liveimg --url=file://${image}
EOF

# liveinst also switches SELinux to permissive while installing. This affects
# the throwaway live session only; the installed system is checked afterwards.
setenforce 0
timeout 1500 anaconda --cmdline --kickstart=/run/myos-test.ks </dev/null >/tmp/anaconda.out 2>&1
status=$?
setenforce 1
echo "MYOS-FACT anaconda-exit ${status}"
check anaconda-finished test "${status}" -eq 0
check partitions-created bash -c '[[ $(lsblk -nro NAME /dev/vda | wc -l) -ge 3 ]]'
echo "MYOS-FACT layout $(lsblk -nro NAME,FSTYPE /dev/vda | tr '\n' ';')"
if (( status != 0 )); then
  for f in /tmp/anaconda.out /tmp/anaconda.log /tmp/storage.log /tmp/program.log /tmp/packaging.log; do
    [[ -f "${f}" ]] && tail -n 40 "${f}" | sed "s|^|[${f##*/}] |"
  done
fi
sync
echo "MYOS-DONE"
systemctl poweroff
