# Handoff: end of phase 1, start of phase 2 (customization)

Written 2026-11-26. Check it against the code and the latest workflow runs.

## State

- `main` and `plasma-distro` were identical at `6f26310`. Work happens on
  `plasma-distro`; ask the owner before merging into `main`.
- Last full pass: run 45904927211 (commit `2134616`): both ISOs built, live boot
  passed on BIOS, UEFI and Secure Boot, scripted plain and LUKS installs passed.
- Runs for later commits were still in progress when this was written.
- No release yet. Pushing the tag from the build workspace was refused (403), so
  the owner publishes `v0.3.0-preview.1` on the GitHub website.

## Built in phase 1

- Fedora 44 KIWI live ISO, profiles GNOME (default) and Plasma, built and tested
  by `.github/workflows/build-iso.yaml`.
- Helium in both editions (default browser); Plasma also keeps Firefox.
- Tests: lint, unit, package validation, VM boot and install tests (`tests/`).
- Release job (both ISOs) and screenshot publishing workflows.
- README with logo and screenshots, docs, changelog.

## Problems found and how they were fixed

| Problem | Fix |
| --- | --- |
| Live system left root without a password | `livesys.service` drop-in locks root |
| `xdg-mime` missing in GNOME | ship `xdg-utils` |
| Installer could not partition disks | ship `anaconda-install-env-deps` |
| Test install: VM rebooted before reporting | hide power commands from Anaconda in the test |
| Test install: could not mount the image | copy from `/dev/mapper/live-base` |
| Test install: no login screen | `xconfig --startxonboot` in the test kickstart |

## Where customization lives

See [customization.md](customization.md). Current defaults: MyOS wallpaper,
GNOME dark style and dock favourites, Plasma `org.myos.dark` global theme, and
an optional labwc session running the Qt 6 / QML shell (`desktop/`, `shared/`),
which the desktop tests do not cover.

## Not done

Graphical installer and real hardware tests; boot splash, GRUB and login screen
branding; welcome app; customization app; boot-menu snapshot recovery; bootc
image; Fedora trademark review.
