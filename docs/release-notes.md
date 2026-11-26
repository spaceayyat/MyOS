VYLO 0.3.0 preview 1: a Fedora 44 based desktop in two editions.

**This is a preview.** The graphical installer and real hardware are untested.
Try it in a virtual machine first.

| Edition | Desktop | Browser | File |
| --- | --- | --- | --- |
| GNOME (main) | GNOME | Helium | `VYLO-0.3.0-preview.1-x86_64.iso` |
| Plasma | KDE Plasma | Helium and Firefox | `VYLO-0.3.0-preview.1-plasma-x86_64.iso` (in parts) |

Before publishing, the workflow run for this tag booted both ISOs in QEMU
(BIOS, UEFI, UEFI Secure Boot) and installed both to a virtual disk, with and
without encryption (UEFI).

How to join split files, verify checksums and install:
[docs/install.md](https://github.com/spaceayyat/MyOS/blob/v0.3.0-preview.1/docs/install.md).

Known limitations:
[README](https://github.com/spaceayyat/MyOS/blob/v0.3.0-preview.1/README.md#known-limitations).
