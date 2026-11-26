# Architecture

Status legend: **[Implemented]** exists in the repository now. **[Planned]** is a design intention only.

## 1. Base: Fedora via bootc

- **[Implemented]** `image/Containerfile` derives from `quay.io/fedora/fedora-bootc:44` (Fedora 44, released 28 April 2026).
- **Why bootc:** the whole OS (kernel, userspace, config) is a container image. Updates are atomic and can be rolled back, and the build is a normal `podman build`, which suits a beginner-friendly, reproducible workflow.
- **Pinning:** the tag selects the release; `scripts/pin-base-digest.sh` records the exact digest in `image/base-image.env` so rebuilds start from identical bytes. The digest is not committed yet because it could not be resolved from the Phase 0 sandbox.

## 2. Image strategy

1. **[Implemented]** A minimal derived image: labels plus `bootc container lint`. No extra packages.
2. **[Planned]** Configuration drop-ins in `image/config/` copied into the image (systemd units, defaults, branding).
3. **[Planned]** My OS RPMs (built under `packaging/`) installed into the image from a repository we control.
4. **[Planned]** Disk-image creation (qcow2/raw/ISO) from the container, then VM boot tests in `tests/vm/`. The tooling for this is in transition upstream (see roadmap risks).

## 3. Desktop (all **[Planned]**)

- Qt 6 + QML applications under `desktop/`: shell, launcher, settings, system monitor, software center.
- Shared code under `shared/`: reusable QML components (`ui`), design tokens (`theme`), and a thin typed API layer over system services (`system-api`).
- Compositor: not decided. Phase 1 will evaluate running the shell on an existing Wayland compositor before considering anything custom.

## 4. Integration with existing Linux services (all **[Planned]**)

The desktop talks to the system through standard interfaces rather than reimplementing them:

| Need | Existing service |
| --- | --- |
| Services, power, sessions | systemd, logind (D-Bus) |
| Networking | NetworkManager (D-Bus) |
| Audio | PipeWire / WirePlumber |
| Privileged actions | polkit |
| Notifications, tray, portals | freedesktop specs, xdg-desktop-portal |
| Software | Flatpak and `bootc` updates; no direct package-manager scripting from the UI |

## 5. Known limitations

- Fedora bootc images are real and widely used, but the tooling around them (disk-image builders, base-image tiering) is still evolving. See `docs/roadmap.md`.
- `/usr` is read-only on a deployed system; customization must go through image layers, `/etc`, `/var`, or Flatpak.

---

## Phase 1 architecture (code written, not yet built or booted)

**Session:** getty autologin (live user) on tty1 -> `/etc/profile.d/myos-session.sh` -> `myos-session` -> `labwc` -> `/etc/xdg/labwc/autostart` -> `myos-shell`. No display manager, which keeps the package set small and the start-up path easy to read.

**Desktop processes**
- `myos-shell` (layer-shell): wallpaper (background layer), panel (top layer, reserves 44 px at the bottom), menu/launcher (top layer, anchored above the panel).
- `myos-settings` (normal window): the theme switch. It is a separate process because layer-shell mode applies to every window of a process.
- Both use `shared/system-api` (theme persistence in `~/.config/myos/myos.conf`, live sync via a directory watcher, application list from `.desktop` files, terminal detection, program launching without a shell) and `shared/theme/Theme.qml`.

## Why a KIWI live ISO for the first milestone

| Option | Verdict |
| --- | --- |
| **bootc `anaconda-iso`** | Produces an *installer*, not a live desktop. The upstream author describes the type as deprecated and slated for removal, and a Fedora 45 build failure was reported. Poor fit for a first, testable milestone. |
| **Kickstart + livemedia-creator** | The `fedora-kickstarts` repository is retired; Fedora moved its live images to KIWI. Older guides exist but are dated. |
| **KIWI live ISO (chosen)** | What Fedora itself uses now; gives a boot-and-run image with no install step. Downsides: thin Fedora-specific documentation, needs root/loop devices, and this repository's description is untested. |

**Staying compatible with bootc:** the desktop sources, the session files in `image/config/rootfs` and the package list are plain data. The future bootc image can `COPY image/config/rootfs/ /` and install the same packages in `image/Containerfile`; only the image-assembly step differs. The package list currently lives in `image/kiwi/config.xml` and will be shared once both paths exist.
