# Install guide

> **Preview.** Automated tests install VYLO in a virtual machine using a
> text-mode script. **The graphical installer screens have not been tested.**
> Try it in a virtual machine first, with an empty virtual disk.

## Get and verify the ISO

Download from the [Releases page](https://github.com/spaceayyat/MyOS/releases),
including `SHA256SUMS`. ISOs over 2 GB are split into parts; join those first.

Linux:

```bash
cat VYLO-*-plasma-x86_64.iso.part* > VYLO-0.4.0-preview.1-plasma-x86_64.iso
sha256sum -c SHA256SUMS --ignore-missing
```

Windows (Command Prompt, in the download folder):

```bat
copy /b VYLO-0.4.0-preview.1-plasma-x86_64.iso.part00+VYLO-0.4.0-preview.1-plasma-x86_64.iso.part01 VYLO-0.4.0-preview.1-plasma-x86_64.iso
certutil -hashfile VYLO-0.4.0-preview.1-plasma-x86_64.iso SHA256
```

Compare the printed value with the matching line in `SHA256SUMS`. To verify who
built an ISO:

```bash
gh attestation verify VYLO-0.4.0-preview.1-x86_64.iso --repo spaceayyat/MyOS
```

## Try it in a VM

Create a 64-bit Fedora-type VM with 6 GB RAM and a 40 GB empty disk (the sizes
the tests use). UEFI and BIOS live boot are tested with QEMU. VirtualBox, VMware
and Hyper-V are untested.

## Install

1. Boot the ISO and start **Install to Hard Drive** (command: `liveinst`).
2. Choose language and keyboard, then the destination disk.
3. Choose encryption if you want LUKS full-disk encryption. A lost passphrase
   cannot be recovered.
4. Keep the default btrfs layout if you want snapshots.
5. Set the timezone and create your user, then install and reboot.

The installer erases or resizes the disk you select. Back up first.

## Manual test of the graphical installer

In a VM, run the steps above twice (with and without encryption), then check:

- the system boots without the ISO and the login screen appears;
- your user can log in, and `sudo -v` works;
- `getenforce` prints `Enforcing`;
- `systemctl is-active firewalld` prints `active`;
- Helium opens a web page.

Report anything that differs as a GitHub issue.
