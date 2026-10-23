# Security

This document describes the rules the project follows. Items are principles that the repository already respects, unless marked **[Planned]**.

## Least privilege

- Build and test scripts run as a normal user. They never call `sudo` themselves; if a future step needs root (disk-image creation), the script says so and the user runs it deliberately.
- The image adds no users, passwords, SSH keys or privileged services in Phase 0.
- Desktop applications will not run as root. Privileged operations go through polkit-mediated D-Bus services. **[Planned]**

## Trusted package sources

- Base image: `quay.io/fedora/fedora-bootc`, pinned to an explicit release and, once resolved, a digest (`scripts/pin-base-digest.sh`).
- Packages come only from official Fedora repositories, plus My OS-signed repositories later. No `curl | sh` installers in the image build.
- Third-party repositories (for example RPM Fusion) require an explicit, documented decision. **[Planned]**
- Image signing and verification at update time. **[Planned]**

## Secrets handling

- No credentials, tokens or keys in the repository, Containerfile, labels or build arguments. `.gitignore` excludes common secret file patterns.
- Wi-Fi passwords and similar must be provisioned at install or first boot, never baked into the image.
- `tests/unit/test_repo_layout.sh` greps scripts and the Containerfile for obvious secret-like assignments. It is a safety net, not a scanner; add a proper secret scanner to CI later. **[Planned]**

## Safe system-management boundaries

- The system-API layer (`shared/system-api`) will expose a small, typed set of operations rather than running arbitrary shell commands. **[Planned]**
- UI code never builds shell command strings from user input. **[Planned]**
- `/usr` is read-only on deployed systems; user customization is limited to user-owned locations and declared settings.

## Reporting vulnerabilities

Before the first public release, add a private contact (for example GitHub private vulnerability reporting) here.

## Phase 1 live image: known security trade-offs

The Phase 1 ISO is a **demo image, not a hardened system**.

- **Automatic login:** `liveuser` logs in on tty1 and tty2 without a password. The account has a locked password, no `sudo`, and no group beyond `video` and `audio`. `root` is locked.
- **SELinux disabled** (`selinux=0`) because the image is not relabelled at build time. Re-enable before any installable release.
- **No firewall or network services** are included, so nothing listens on the network.
- **Package trust:** packages come from Fedora repositories over HTTPS and are signature-checked with the Fedora key (`package_gpgcheck`). Repository metadata signing is off, as in Fedora's own repository files.
- **System API:** `shared/system-api` starts programs with an argument list, never through a shell, and reads only standard `.desktop` locations. The only file it writes is `~/.config/myos/myos.conf`.
- `tests/unit/test_phase1_static.sh` checks these properties statically (locked accounts, no plain-text passwords, https repositories, no shell execution in the system API).
