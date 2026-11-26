# Install guide

> **Status: installation has not been tested.** CI boots the live ISO only. Try
> it in a virtual machine first, with an empty virtual disk.

## Get and verify the ISO

Download the `MyOS-ISO-gnome` or `MyOS-ISO-plasma` artifact from a successful **Build MyOS ISO** run (or
the assets of a tagged release), then:

```bash
sha256sum -c SHA256SUMS
```

For tagged releases you can also verify who built it:

```bash
gh attestation verify MyOS-Live.*.iso --repo spaceayyat/MyOS
```

If a release ISO is split into `.part00`, `.part01`, ... join it first with
`cat *.iso.part* > MyOS.iso`, then compare its checksum with `SHA256SUMS`.

## Try it in a VM

Give the VM at least 4 GB RAM and a 40 GB empty disk. UEFI and BIOS are both
boot-tested in CI with QEMU. Other hypervisors are untested.

## Install

1. Boot the ISO and start **Install to Hard Drive** (command: `liveinst`).
2. Choose language and keyboard, then the destination disk.
3. Tick the encryption option if you want LUKS full-disk encryption. A lost
   passphrase cannot be recovered.
4. Keep the default btrfs layout if you want snapshots.
5. Set the timezone and create your user, then install and reboot.

The installer erases or resizes the disk you select. Back up first.
