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

## Limits

- Root on an installed system has not been tested.
- The live session logs in automatically and its user has administrator
  rights. Treat anyone with physical access to a live session as an admin.
- Repository metadata signatures are not checked (Fedora does not sign them);
  packages are.
- Firewall zone rules have not been reviewed for this project.
- Automatic updates on an installed system are untested.
- Release provenance is signed only for `v*` tags; the release job has not run.

## Reporting vulnerabilities

Use GitHub private vulnerability reporting on this repository (enable it under
Settings > Code security).
