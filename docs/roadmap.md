# Roadmap

Ordered by dependency, not by date. An item is done only when a test or a
recorded manual check shows it.

## Done in 0.3.0 preview

- GNOME and KDE Plasma live ISOs built with KIWI on GitHub Actions.
- Boot tests: BIOS, UEFI, UEFI Secure Boot (QEMU).
- Scripted installation tests, plain and LUKS, with login and reboot.

## Next

1. Test the graphical installer, then real hardware.
2. Branding: boot splash, GRUB theme, login screen, welcome app, and a review of
   Fedora's trademark guidelines.
3. A MyOS customization app.
4. Snapshot recovery from the boot menu.
5. A bootc image as an additional output.

## Stable release criteria

Build, tests, checksums and security checks pass for the tagged commit, and the
graphical installer has been tested.
