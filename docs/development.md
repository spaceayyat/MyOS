# Development guide (Windows 11 + WSL2)

Everything below runs inside **Ubuntu on WSL2** unless marked "PowerShell". Commands marked *(unverified)* were not executed in the Phase 0 sandbox, which was not WSL2 and had no Podman or access to quay.io.

## 1. Install WSL2 and Ubuntu (PowerShell as Administrator)

```powershell
wsl --install -d Ubuntu-24.04
wsl --version
wsl --list --verbose     # the VERSION column for Ubuntu must say 2
```

Restart if asked, then open "Ubuntu" from the Start menu and create your Linux user.

## 2. Install tools (inside Ubuntu)

```bash
sudo apt update
sudo apt install -y git podman skopeo shellcheck make jq
git --version
podman --version
```

*(unverified)* Check that rootless Podman works:

```bash
podman info --format '{{.Host.Security.Rootless}}'   # expect: true
podman run --rm quay.io/fedora/fedora:44 cat /etc/os-release
```

If Podman is too old to build the image, install a newer one from your Ubuntu release's updates or build from upstream and re-run `scripts/check-env.sh`.

## 3. Get the code and check the environment

Work inside the Linux filesystem (for example `~/src`), not under `/mnt/c`, for speed and correct file permissions.

```bash
mkdir -p ~/src && cd ~/src
# clone or copy the myos folder here, then:
cd myos
scripts/check-env.sh
tests/unit/test_repo_layout.sh
```

## 4. Pin the base image (once)

```bash
scripts/pin-base-digest.sh        # needs skopeo and network access to quay.io
git diff image/base-image.env
```

Commit `image/base-image.env` after reviewing it. Builds then use the digest automatically.

## 5. Build and smoke-test the image

```bash
scripts/build-image.sh
scripts/smoke-test.sh --no-build
podman run --rm localhost/myos:dev cat /etc/os-release
```

The smoke test checks the image exists, carries the My OS label, contains `bootc`, is Fedora, passes `bootc container lint`, and has a kernel. It does **not** boot anything.

## 6. (Phase 0 note) disk image and VM boot

Converting the container to a disk image needs root, loop devices and mounts; booting needs a hypervisor. Whether WSL2 can do this is **unverified**. The next practical step is to try `image-builder` (the successor to the archived `bootc-image-builder`) following its current documentation, and if WSL2 cannot do it, build on a Linux VM or machine and boot the result with QEMU or Hyper-V. Record the result in `docs/roadmap.md`.

## Troubleshooting

| Symptom | Likely cause |
| --- | --- |
| `podman build` cannot pull the base | No network access to `quay.io`, or a typo in the tag |
| `bootc container lint` fails during build | The image violates bootc conventions; read the lint message |
| Slow builds or odd permissions | Repository is under `/mnt/c`; move it into the Linux home folder |

---

# Phase 1: desktop and live ISO

Commands marked *(unverified)* have never been run by the author.

## 1. Build the desktop (Ubuntu/WSL2, rootless Podman) *(unverified)*

```bash
scripts/build-desktop.sh
ls build/stage/usr/bin          # expect myos-shell and myos-settings
```

This compiles inside `quay.io/fedora/fedora:44`, so it needs access to quay.io and Fedora mirrors.

## 2. Where to build the ISO

KIWI needs **root, loop devices and mounts**. WSL2 may not provide all of them (unverified). Pick one:

- **Recommended: a Fedora 44 VM.** Install Fedora in VirtualBox (any edition, 4 GB RAM, 40 GB disk), then inside it:
  ```bash
  sudo dnf install -y git podman kiwi kiwi-systemdeps distribution-gpg-keys
  # copy or clone the repository, then:
  scripts/build-desktop.sh
  sudo scripts/build-iso.sh
  ```
- **Experimental: privileged Fedora container in WSL2** *(unverified)*. After step 1, from the repository root:
  ```bash
  sudo podman run --rm -it --privileged -v /dev:/dev -v "$PWD":/work -w /work \
    quay.io/fedora/fedora:44 bash -c \
    'dnf install -y kiwi kiwi-systemdeps distribution-gpg-keys && scripts/build-iso.sh'
  ```
  If it fails with loop-device or mount errors, WSL2 is the limitation; use the VM.

The ISO appears in `output/iso/`. Copy it to Windows (for example `cp output/iso/*.iso /mnt/c/Users/<you>/Downloads/`), because VirtualBox cannot reliably open files through `\\wsl$`.

## 6. Boot test in a VM (VirtualBox) *(unverified)*

This creates a new VM only; it does not touch your disks or Windows. In PowerShell (adjust the ISO path):

```powershell
$vbm = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
$vm  = "MyOS-Test"
$iso = "C:\Users\<you>\Downloads\MyOS-Live.x86_64-0.1.0.iso"
& $vbm createvm --name $vm --ostype Fedora_64 --register
& $vbm modifyvm $vm --memory 3072 --cpus 2 --firmware efi --graphicscontroller vmsvga --vram 128 --boot1 dvd --nic1 nat
& $vbm storagectl $vm --name SATA --add sata
& $vbm storageattach $vm --storagectl SATA --port 0 --device 0 --type dvddrive --medium $iso
& $vbm startvm $vm
```

**What success looks like:** the VM boots to a blue wallpaper showing the OS name, a panel at the bottom with the name button on the left and a clock on the right. Click the button: a menu opens with a search box, application list, Settings and Terminal buttons. Settings opens a window; the "Dark theme" switch recolours everything. Terminal opens `foot`.

To delete the test VM later (your decision): `& $vbm unregistervm $vm --delete`.

## If the desktop does not appear

1. Press Ctrl+Alt+F2 (in VirtualBox: Right Ctrl + F2): a shell logged in as `liveuser`.
2. Read the log: `cat ~/.local/state/myos/session.log`.
3. Also check `journalctl -b` for errors from `myos-shell`.
4. Most likely causes: `layer-shell-qt` API or QML mistakes (the code was never compiled by the author), no EFI in the VM, or graphics issues; use VirtualBox graphics controller VMSVGA with 128 MB.

## If the ISO build fails

KIWI prints the failing step. Typical fixes:

| Error mentions | Look at |
| --- | --- |
| a package not found | `dnf5 repoquery <name>` on Fedora 44; fix the name in `image/kiwi/config.xml` |
| schema, attribute or element | the KIWI docs for your installed `kiwi` version (`rpm -q kiwi`); adjust `config.xml` |
| GPG key | `ls /usr/share/distribution-gpg-keys/fedora/` and fix the `<signing key=...>` path |
| loop device, mount, `losetup` | an environment that cannot do it (WSL2): use the Fedora VM |
| bootloader, grub, shim | the "Boot and live-media support" block of the package list |

Paste the last 40 lines of the output into the project chat and the description can be corrected.
