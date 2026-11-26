set -u
base=https://download.copr.fedorainfracloud.org/results/imput/helium
dnf -y -q install gnupg2 curl >/dev/null
echo "=== KEY"; curl -fsS $base/pubkey.gpg | tee /tmp/k; gpg --show-keys --with-fingerprint /tmp/k
Q="dnf -q repoquery --repofrompath=helium,$base/fedora-44-x86_64/ --repo=helium"
echo "=== helium packages"; $Q --qf '%{name} %{evr} %{arch}\n'
echo "=== helium files"; $Q -l helium-bin | grep -E 'desktop$|bin/|policies|/etc/' | head -30
echo "=== helium requires"; $Q --requires helium-bin | head -40
echo "=== helium scripts"; $Q --qf '%{name}\n' helium-bin; dnf -q download --repofrompath=helium,$base/fedora-44-x86_64/ --repo=helium helium-bin --destdir /tmp/rpm && rpm -qp --scripts /tmp/rpm/*.rpm; rpm --import /tmp/k && rpm -Kv /tmp/rpm/*.rpm
echo "=== names"
F="dnf -q repoquery --repo=fedora --repo=updates"
want="gnome-shell gdm gnome-session-wayland-session mutter gnome-control-center nautilus ptyxis gnome-text-editor gnome-software gnome-tweaks gnome-extensions-app loupe papers gnome-system-monitor gnome-disk-utility file-roller gnome-calculator xdg-desktop-portal-gnome gnome-bluetooth adwaita-icon-theme gnome-tour gnome-settings-daemon gnome-backgrounds fedora-release-workstation fedora-release-identity-workstation anaconda-live anaconda-webui snapshot showtime decibels gnome-calendar gnome-clocks gnome-weather baobab gnome-logs flatpak"
$F --qf '%{name}\n' $want | sort -u > /tmp/found; for p in $want; do grep -qx "$p" /tmp/found || echo "MISSING $p"; done
for p in anaconda-live anaconda-webui gnome-shell gnome-software gnome-tour; do echo "== requires $p"; $F --requires $p | grep -iE 'firefox|browser|webkit'; done
echo "== whatprovides webclient"; $F --whatprovides webclient --qf '%{name}\n' | sort -u | head -20
echo "== livesys"; dnf -q download --repo=fedora --repo=updates livesys-scripts --destdir /tmp/ls && (cd /tmp/ls && rpm2archive *.rpm | tar -xz -C /tmp/ls || rpm2cpio *.rpm | cpio -idm); grep -rn "passwd\|firefox" /tmp/ls/usr/libexec/livesys/
