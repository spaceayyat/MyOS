# Customization guide

| Change | File |
| --- | --- |
| Add or remove packages | `image/kiwi/config.xml` |
| Services enabled at boot | `image/kiwi/config.sh` |
| Files added to both editions | `image/config/rootfs/` |
| Files for one edition | `image/config/rootfs-gnome/`, `image/config/rootfs-plasma/` |
| GNOME defaults (theme, dock, touchpad) | `rootfs-gnome/usr/share/glib-2.0/schemas/zz-vylo.gschema.override` |
| Wallpaper | `image/config/rootfs/usr/share/wallpapers/VYLO/` |
| Light and dark global themes | `image/config/rootfs-plasma/usr/share/plasma/look-and-feel/` |
| Default global theme | `image/config/rootfs-plasma/etc/xdg/kdeglobals` |
| Automatic update policy | `image/config/rootfs/etc/dnf/automatic.conf` |
| VYLO Shell session | `desktop/`, `image/config/rootfs/usr/share/vylo/` |

Every new package name is checked against the Fedora repositories by CI
(`tests/validate-image.sh`). Raise `<version>` in `config.xml` and add a
`CHANGELOG.md` entry before tagging `v<version>`.

On a running system, GNOME users switch light and dark style in **Settings >
Appearance**, and can use **Tweaks** and **Extensions**. Plasma users switch
between VYLO Dark and VYLO Light in **System Settings > Colors & Themes**.

The experimental **VYLO Shell** session can be picked on the login screen. CI
checks that its programs are present and their libraries resolve; the session
itself has not been tested.
