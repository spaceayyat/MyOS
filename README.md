# My OS

My OS is an open-source, Fedora-based operating system project with its own identity, a Qt 6 / QML desktop, and a planned customization system.

> **Status: Phase 1, code written and renamed to My OS, NOT yet built or boot-tested.**
> Latest session (rename and hardening): the project was renamed to My OS from its earlier working name, and a few session/KIWI robustness fixes were made by inspection only. The sandbox used had no network, no Qt, no Podman, no KIWI and no KVM, so **no desktop compile, no ISO build and no VM boot happened**. No ISO exists.
> The desktop source, the live-session configuration and the ISO build scripts exist. The author has **not** compiled the desktop, built the ISO, or booted it in a VM (the authoring environment had no Podman, Qt, KVM, or access to Fedora mirrors). Treat the first build on your machine as the real test, and expect to fix a few things. See [Known limitations](#known-limitations).

## Build the ISO on GitHub (no Fedora machine needed)

1. Create a GitHub repository and push this project to the `main` branch.
2. Open the **Actions** tab, choose **Build My OS ISO**, press **Run workflow** (it also runs on every push to `main`).
3. Wait roughly 30-60 minutes. On success, download the **MyOS-Live-iso** artifact from the run page (the `.iso` and its `.sha256`).
4. If it fails, download the **build-logs** artifact (or copy the failing step's log) and use it to fix the configuration.

The workflow runs the repository's own tests, compiles the desktop, runs KIWI in a privileged Fedora 44 container and checks that the ISO has El Torito boot records. It cannot boot the ISO: test it in a UEFI VM (QEMU with OVMF, VirtualBox with EFI enabled) before trusting it. **This workflow has never been run.**

## Phase 1A: the My OS desktop design

The desktop now follows the My OS blueprint: dark-by-default navy theme with accents, left launcher with search, top widget area (clock, local calendar, weather empty state, CPU/memory monitor), right workspace drawer, slim bottom panel with pinned apps, and a Settings app with theme, accent, wallpaper and widget controls. Details, per-feature status (implemented / simulated / needs integration) and risks: [`docs/desktop.md`](docs/desktop.md).

**Verified so far:** static tests (layout, branding, QML cross-references, brackets, security rules) and the `/proc` parser unit tests (compiled and run with g++). **Not verified:** compiling the Qt code, running the desktop, any screenshot or layout check, the ISO build, any VM boot.

Run the desktop tests: `for t in tests/unit/test_*.sh; do bash "$t"; done`

## What Phase 1 contains

| Piece | State |
| --- | --- |
| Desktop shell (Qt 6 / QML): wallpaper with the OS name, bottom panel, menu button, clock | Written, not compiled |
| Application launcher (searchable list, Settings and Terminal buttons) | Written, not compiled |
| Settings window with a light/dark theme switch (live-updates the shell) | Written, not compiled |
| Session: automatic login on tty1 into the `labwc` compositor, which starts the shell | Written, not run |
| Live ISO description (KIWI, Fedora 44, UEFI) and build scripts | Written, never executed |
| `output/iso/*.iso` | **Does not exist yet** |
| VM boot test | **Not done** |
| Fedora bootc image (`image/Containerfile`, from Phase 0) | Unchanged, does not contain the desktop yet |

Checks that *have* been run: repository layout test and Phase 1 static test (file presence, shell syntax, XML validity, bracket balance, security rules). They do not compile Qt code or build an image.

## How it is put together

- **Base:** Fedora 44 packages. **Compositor:** `labwc` (existing Wayland compositor, nothing custom). **Terminal:** `foot`.
- **Desktop:** `myos-shell` draws the wallpaper, panel and menu as layer-shell surfaces (via `layer-shell-qt`), so normal windows never cover the panel. `myos-settings` is an ordinary window.
- **Image method:** a KIWI live ISO, the tool Fedora itself now uses for its live images. The trade-off versus the bootc path is explained in [`docs/architecture.md`](docs/architecture.md).

## Prerequisites

- Windows 11 with WSL2 + Ubuntu 24.04 (for the desktop build), as in [`docs/development.md`](docs/development.md).
- **A Fedora environment with root** to build the ISO: KIWI needs loop devices and mounts. The most reliable choice is a Fedora 44 VM; a privileged Fedora container in WSL2 is possible but unverified.
- VirtualBox on Windows (or any VM tool with UEFI) to test the ISO. Nothing is ever installed onto your physical computer.

## Build and test (reproducible steps)

1. **Check the repository** (any Linux, no extra tools):
   ```bash
   tests/unit/test_repo_layout.sh
   tests/unit/test_phase1_static.sh
   tests/unit/test_branding.sh
   ```
2. **Build the desktop** (Ubuntu/WSL2 with Podman; compiles inside a Fedora 44 container):
   ```bash
   scripts/build-desktop.sh          # optional: MYOS_DISPLAY_NAME="My OS" scripts/build-desktop.sh
   ```
3. **Build the ISO** (on Fedora 44, as root):
   ```bash
   sudo dnf install -y kiwi kiwi-systemdeps distribution-gpg-keys
   sudo scripts/build-iso.sh
   ```
   Result: `output/iso/<name>.iso` and a `.sha256` file next to it.
4. **Boot it in a VM** and check the desktop appears: [`docs/development.md`](docs/development.md#6-boot-test-in-a-vm-virtualbox).

If a step fails, see "If the ISO build fails" in [`docs/development.md`](docs/development.md).

## Known limitations

- **Never built or booted by the author.** The KIWI description (`image/kiwi/config.xml`) was written from documentation; package names or KIWI attributes may need small fixes.
- **UEFI only.** Enable EFI in the VM settings.
- **Live only:** no installer, nothing is saved between boots.
- **SELinux is off in the live image** (`selinux=0`), no firewall, no networking tools. Not suitable for real use. See `docs/security.md`.
- **Software rendering** (`QT_QUICK_BACKEND=software`) for VM robustness; no GPU acceleration.
- No power-off or logout button yet: close the VM window or use the VM's power menu.
- The wallpaper and menu button show **My OS**. Build with `MYOS_DISPLAY_NAME="Other Name"` to show another name.
- The desktop is compiled against Fedora 44 Qt at build time; if Fedora updates Qt before you build the ISO, rebuild the desktop first.
- The bootc image does not include the desktop yet; the two image paths share source but not packages.

## Repository layout

| Path | Purpose |
| --- | --- |
| `desktop/shell`, `desktop/launcher`, `desktop/settings` | Phase 1 desktop (QML + small C++ host) |
| `desktop/monitor`, `desktop/software-center` | Later phases (empty) |
| `shared/system-api`, `shared/theme` | System bridge (C++) and colour palette (QML) |
| `image/kiwi` | Live ISO description |
| `image/config/rootfs` | Files copied into the image (session, autologin, labwc) |
| `image/Containerfile` | Phase 0 bootc image |
| `scripts/`, `tests/`, `docs/` | Build scripts, tests, documentation |

## License

MIT. See [`LICENSE`](LICENSE). (A placeholder choice; confirm it before the first public release.)

## Naming

The OS is called **My OS** (two words) in everything a person reads: wallpaper, panel button, window titles, `.desktop` entries, image labels and documentation. Technical identifiers use `myos` / `MyOS` / `MYOS_` (binaries `myos-shell`, `myos-settings`, `myos-session`; config `~/.config/myos/myos.conf`; CMake project `MyOS`; ISO name `MyOS-Live`). Identifiers never contain a space.

## Changes since the earlier-named version

- Full rename to My OS (files, identifiers, docs, tests); `tests/unit/test_branding.sh` guards it.
- Display name is now passed to C++ through a generated header (`myos_config.h`) instead of a quoted compile definition, so names with spaces are safe.
- Session: autologin detection uses the tty (`/dev/tty1`) instead of `XDG_VTNR`, a fallback `XDG_RUNTIME_DIR` is created if PAM did not provide one, `XDG_CURRENT_DESKTOP` is `MyOS`.
- KIWI: added `pam`, `authselect`, `systemd-pam`; `config.sh` selects the `minimal` authselect profile and enables `dbus-broker`. All **untested**.
