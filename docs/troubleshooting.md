# Troubleshooting

## The ISO build fails

- Build only on Fedora 44 (`sudo scripts/build-in-container.sh` does this).
  Ubuntu's KIWI is too old and reports a schema error.
- "package not found": run `tests/validate-image.sh` on Fedora 44.
- Loop device or mount errors: the container needs `--privileged` and `/dev`.
  WSL2 is untested.

## The live desktop does not appear

Remove `quiet rhgb` from the kernel line (press `e` in the boot menu) to see
boot messages. Switch to a text console with Ctrl+Alt+F3, then check:

```bash
systemctl --failed
journalctl -b -p warning
journalctl -b -u plasmalogin -u livesys -u livesys-late
```

## Recovering from a bad change (btrfs installs)

On first boot MyOS creates a snapper configuration for `/` if it is btrfs.
**Choosing a snapshot from the boot menu is not supported**, and
`snapper rollback` does not match Fedora's default subvolume layout. You can
undo file changes between two snapshots:

```bash
sudo snapper -c root list
sudo snapper -c root status 1..2
sudo snapper -c root undochange 1..2
```

This is untested on MyOS. Back up your data separately; snapshots are not
backups.

## Proprietary NVIDIA driver

MyOS ships the open drivers only. The proprietary driver comes from a
third-party repository (RPM Fusion) that is not enabled by default. With Secure
Boot on, its kernel module must be signed with a key you enrol yourself.
