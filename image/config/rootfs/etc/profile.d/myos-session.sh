# Start the My OS graphical session automatically for the live user on tty1.
# Sourced by login shells. Does nothing for other users, other ttys, or when a
# graphical session is already running.
if [ -z "${WAYLAND_DISPLAY:-}" ] && [ "$(tty 2>/dev/null)" = "/dev/tty1" ] \
   && [ "$(id -un)" = "liveuser" ]; then
    exec /usr/bin/myos-session
fi
