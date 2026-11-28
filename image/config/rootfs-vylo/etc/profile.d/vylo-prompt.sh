# shellcheck shell=sh
# A coloured prompt in VYLO desktop terminals. The colours come from the
# terminal's own palette. Other desktops and the text console are left alone.
if [ -n "${BASH_VERSION:-}" ] && [ "${XDG_CURRENT_DESKTOP:-}" = VYLO ] && [ -n "${PS1:-}" ]; then
    PS1='\[\e[1;34m\]\u@\h\[\e[0m\] \[\e[35m\]\w\[\e[0m\] \$ '
fi
