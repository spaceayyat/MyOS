# Roadmap

Phases are ordered by dependency, not by dates. A phase is done only when its exit criteria are verified.

## Phase 0: Foundation (current)

- Repository, documentation, minimal Containerfile, build/smoke-test scripts.
- **Exit:** layout test passes; `scripts/smoke-test.sh` passes on the maintainer's machine (WSL2 + Podman).
- **Status:** layout and script syntax verified in the Phase 0 sandbox. Image build and inspection still need to be run on a machine with Podman and access to quay.io.

## Phase 0.5: First bootable image

- Pin the base digest and commit `image/base-image.env`.
- Convert the image to a disk image and boot it in a VM. Try `image-builder` first (see risks), on a native Linux host or Linux VM if WSL2 cannot do loop-device builds.
- **Exit:** the VM boots to a login prompt; recorded in `tests/vm/`.

## Phase 1: Minimal session and live ISO (current: code written, unverified)

- Existing Wayland compositor (labwc) with automatic session start (getty autologin, no display manager).
- First Qt 6 / QML app (the shell skeleton) autostarting in a session.
- **Exit:** the ISO builds, boots in a VM, and shows the desktop (wallpaper, panel, menu, clock, settings, terminal).
- **Status:** all code and the ISO build scripts are written. Nothing has been compiled, built or booted yet; see the README, Known limitations.

## Phase 2: Core desktop apps

- Launcher, settings (network, display, appearance), system monitor, using the D-Bus integrations in `architecture.md`.
- Theme tokens in `shared/theme`.

## Phase 3: Software and updates

- Software center on top of Flatpak and `bootc` update/rollback.
- Update channel and signed image publishing.

## Phase 4: Bootable preview

- Installable ISO or disk image, published with checksums and documentation, clearly labelled as a preview.

## Risks and maturity concerns

- **Disk-image tooling is in transition.** The `bootc-image-builder` repository was archived on 18 June 2026 and merged into the unified `image-builder` project; its own deprecation notice names `image-builder` as the replacement. Commands and flags should be re-verified before each use.
- **Base-image internals may change.** Fedora's bootc base-image project describes its image tiers as an implementation detail that may change. Depend only on the published `fedora-bootc` image and tag.
- **WSL2 limits.** Building disk images needs root, loop devices and mounts, and booting needs a hypervisor. WSL2 may not support all of this; this is unverified.
- **Fedora lifecycle.** Fedora releases are supported for a limited time; plan a rebase to the next release (Fedora 45 was not yet released as of this writing).
