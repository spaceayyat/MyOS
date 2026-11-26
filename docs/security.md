# Security

## Defaults

| Area | Setting | Checked by |
| --- | --- | --- |
| Package signatures | Required for every repository during the build | `tests/unit/check_config.py` |
| Accounts | Only a locked `root` in the image; live user created at boot on live media | `check_config.py`, boot test |
| Root on live media | Fedora's `livesys` scripts remove the root password at boot; MyOS locks it again | boot test: shadow field, and `su` from an unprivileged user |
| SELinux | Enforcing | build (`config.sh`), boot test |
| Firewall | firewalld enabled (Fedora's default zone for the KDE edition) | boot test checks the service only |
| Updates | Security updates applied daily, no automatic reboot, off on live media | boot test checks the live case only |
| Secure Boot | Fedora's signed shim and GRUB | boot test in QEMU with Microsoft keys |

## Helium Browser (both editions)

Helium comes from a third-party repository, the project's own COPR. Packages
must be signed with the key stored in this repository (fingerprint
`07BC FCA3 0AC7 E51B CFED FFF7 4A31 86EA 4791 2C39`), which was first fetched
over HTTPS from the COPR server. The repository's metadata is not signed.

**Automatic security updates do not cover Helium**, because the repository
publishes no security advisories. Update it with Software or
`sudo dnf upgrade helium-bin`.

## Limits

- On installed systems the tests confirm a locked root account, no empty
  passwords, SELinux enforcing, firewalld running and SSH off.
- The live session logs in automatically and its user has administrator
  rights. Treat anyone with physical access to a live session as an admin.
- Repository metadata signatures are not checked (Fedora does not sign them);
  packages are.
- Firewall zone rules have not been reviewed for this project.
- On installed systems the tests confirm the update timer is active, not that
  an automatic update was applied.
- Release provenance is signed only for `v*` tags.

## Reporting vulnerabilities

Use GitHub private vulnerability reporting on this repository (enable it under
Settings > Code security).
