#!/bin/bash
# KIWI image configuration script. Runs inside the new image root (a chroot),
# after the packages and the overlay (image/config/rootfs + built desktop) are
# in place. It never touches the build host.
set -ex

test -f /.kconfig && . /.kconfig
test -f /.profile && . /.profile

# The built desktop binaries and the session script must be executable.
chmod 0755 /usr/bin/myos-shell /usr/bin/myos-settings /usr/bin/myos-session

# Boot to a text console; the getty autologin drop-in starts the session.
systemctl set-default multi-user.target

echo "myos" > /etc/hostname

# Make sure a PAM profile exists (with pam_systemd) so the autologin session
# gets a logind seat and XDG_RUNTIME_DIR. Not fatal if it is already set up.
authselect select minimal --force || echo "authselect select failed (continuing)"

systemctl enable dbus-broker.service || true
