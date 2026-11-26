# MyOS

A Fedora 44 based KDE Plasma workstation, built as a live ISO with KIWI and
GitHub Actions. This is an early preview. Test it in a virtual machine.

## Build

On GitHub: open **Actions**, run **Build MyOS ISO** (it also runs on every
push), then download the `MyOS-ISO` artifact.

Locally, with Docker or root Podman:

```bash
sudo scripts/build-in-container.sh     # result in output/iso/
```

## Test

```bash
tests/lint.sh                                        # needs shellcheck
for t in tests/unit/test_*.sh; do "$t"; done          # needs bash, python3, g++
# on Fedora 44 as root:
tests/validate-image.sh
# needs QEMU and OVMF; modes: bios, uefi, secureboot
python3 tests/vm/boot_test.py --iso output/iso/*.iso --mode uefi --out vm-out
```

The boot test starts the ISO and checks the Plasma session, network, audio,
Bluetooth daemon, printing and security services from inside the guest. The
status of each CI run is the record of what passed.

## Not covered yet

- Installing to disk, disk encryption and the installed system are untested.
- Booting a snapshot from the boot menu is not provided.
- No custom welcome app, boot splash, GRUB theme or login screen theme.
- Real hardware (GPU, Wi-Fi, Bluetooth, printers, suspend) is untested.
- The image still carries Fedora's name and logos in places. Review Fedora's
  trademark guidelines before distributing it.

## Documentation

[Install](docs/install.md) · [Customize](docs/customization.md) ·
[Troubleshoot](docs/troubleshooting.md) · [Security](docs/security.md) ·
[Changelog](CHANGELOG.md)

## Layout

| Path | Purpose |
| --- | --- |
| `image/kiwi` | ISO description |
| `image/config/rootfs` | Files copied into the image |
| `desktop/`, `shared/` | Optional MyOS Shell and Settings (Qt 6 / QML) |
| `scripts/`, `tests/` | Build and test |
| `image/Containerfile` | Old bootc experiment, not built by CI |

MIT licence, see [`LICENSE`](LICENSE).
