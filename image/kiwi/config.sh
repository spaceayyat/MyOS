#!/bin/bash
# KIWI image configuration script. Runs inside the new image root (a chroot),
# after the packages and the overlay (image/config/rootfs plus the built
# desktop) are in place. It never touches the build host.
# KIWI tells us which edition (profile) is being built.
# shellcheck disable=SC1091
test -f /.profile && . /.profile

set -euxo pipefail

# The optional VYLO session must be executable.
chmod 0755 /usr/bin/vylo-shell /usr/bin/vylo-settings /usr/bin/vylo-session \
    /usr/libexec/vylo/snapper-setup /usr/libexec/vylo/lock-root

echo "vylo" > /etc/hostname

# Keep SELinux enforcing. Fail the build if the policy says anything else.
grep -qx 'SELINUX=enforcing' /etc/selinux/config

systemctl set-default graphical.target

case "${kiwi_profiles:-}" in
    GNOME)
        display_manager=gdm.service
        glib-compile-schemas --strict /usr/share/glib-2.0/schemas
        ;;
    Plasma) display_manager=plasmalogin.service ;;
    VYLO)
        display_manager=sddm.service
        # Our icons are added after the packages. A cache made before that would
        # hide them, and the dock would show letters instead.
        rm -f /usr/share/icons/hicolor/icon-theme.cache
        if command -v gtk-update-icon-cache >/dev/null; then
            gtk-update-icon-cache --force /usr/share/icons/hicolor
        fi
        chmod 0755 /usr/libexec/vylo/live-setup /usr/libexec/vylo/installer-theme \
            /usr/libexec/vylo/os-name
        # The installer and the system carry VYLO's name and look.
        /usr/libexec/vylo/os-name
        /usr/libexec/vylo/installer-theme
        systemctl enable vylo-os-name.service
        # labwc ships its own plain session; only the VYLO one belongs here.
        rm -f /usr/share/wayland-sessions/labwc.desktop
        systemctl enable vylo-live.service
        ;;
    *) echo "unknown profile '${kiwi_profiles:-}'" >&2; exit 1 ;;
esac

# A missing unit is a build error, not something to ignore.
systemctl enable \
    "${display_manager}" \
    NetworkManager.service \
    bluetooth.service \
    cups.socket \
    firewalld.service \
    tuned.service \
    tuned-ppd.service \
    livesys.service \
    livesys-late.service \
    dnf5-automatic.timer \
    vylo-snapper-setup.service
