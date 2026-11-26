# Customization guide

| Change | File |
| --- | --- |
| Add or remove packages | `image/kiwi/config.xml` |
| Services enabled at boot | `image/kiwi/config.sh` |
| Files added to the system | `image/config/rootfs/` |
| Wallpaper | `image/config/rootfs/usr/share/wallpapers/MyOS/` |
| Light and dark global themes | `image/config/rootfs/usr/share/plasma/look-and-feel/` |
| Default global theme | `image/config/rootfs/etc/xdg/kdeglobals` |
| Automatic update policy | `image/config/rootfs/etc/dnf/automatic.conf` |
| MyOS Shell session | `desktop/`, `image/config/rootfs/usr/share/myos/` |

Every new package name is checked against the Fedora repositories by CI
(`tests/validate-image.sh`). Raise `<version>` in `config.xml` and add a
`CHANGELOG.md` entry before tagging `v<version>`.

On a running system, use **System Settings > Colors & Themes** to switch between
MyOS Dark and MyOS Light.

The experimental **MyOS Shell** session can be picked on the login screen. CI
checks that its programs are present and their libraries resolve; the session
itself has not been tested.
