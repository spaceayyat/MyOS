# Changelog

## 0.3.0 (unreleased)

- New main edition: GNOME with Helium Browser (no Firefox). KDE Plasma remains
  as a second edition, now with Helium as its default browser (Firefox
  stays installed).
- CI builds and boot-tests both editions.

- KDE Plasma is the default desktop; the myos-shell session is optional.
- Anaconda live installer included.
- No built-in user accounts; the live user exists only on live media.
- SELinux enforcing, firewalld, security-only automatic updates.
- CI: shellcheck, unit tests, KIWI and package validation, ISO build,
  QEMU boot tests (BIOS, UEFI, UEFI Secure Boot).
- Fixed: the live system left root without a password.
- Fixed: the boot test misread results; it now judges them strictly.
- ISOs are named by version (development builds include the commit) and ship
  with `BUILD-INFO.txt`.

## 0.1.0

- Initial labwc-based live image description (never built successfully).
