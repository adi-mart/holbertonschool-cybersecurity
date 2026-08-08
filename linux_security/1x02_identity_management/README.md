# 1x02 Identity and Access Management

## Overview

This module contains scripts for user/group auditing, authentication hardening,
password policy management, account onboarding, and controlled sudo delegation.

Each exercise is paired with a corresponding `N-flag.txt` file.

## Script Index

### `0-audit_uid.sh`
- Purpose: detect accounts with UID 0 that are not `root`.
- Input format: passwd-like file.
- Usage: `./0-audit_uid.sh /etc/passwd`

### `1-audit_shells.sh`
- Purpose: list system users (`UID < 1000`, excluding `root`) with interactive shells.
- Shell filter: entries ending with `sh` or `bash`.
- Usage: `./1-audit_shells.sh /etc/passwd`

### `2-audit_groups.sh`
- Purpose: find users (UID >= 1000) belonging to sensitive groups.
- Checked groups: `disk`, `docker`, `shadow`.
- Output format: `user:group`
- Usage: `./2-audit_groups.sh /etc/passwd`

### `3-harden_ssh.sh`
- Purpose: enforce key SSH security settings in an `sshd_config`-style file.
- Enforced values:
	- `PermitRootLogin no`
	- `PasswordAuthentication no`
	- `PubkeyAuthentication yes`
- Behavior: validates config with `sshd -t -f <file>` before reload.
- Usage: `sudo ./3-harden_ssh.sh /etc/ssh/sshd_config`

### `4-pw_policy.sh`
- Purpose: ensure a package is installed, then update PAM password policy.
- Behavior: installs package if missing, edits provided PAM config file.
- Usage: `sudo ./4-pw_policy.sh libpam-pwquality /etc/pam.d/common-password`

### `5-audit_crypto.sh`
- Purpose: identify users still using weak MD5 password hashes.
- Detection pattern: shadow hash field starting with `$1$`.
- Usage: `sudo ./5-audit_crypto.sh /etc/shadow`

### `6-onboard.sh`
- Purpose: create a user for SSH key-based access only.
- Actions: create home, lock password, create `.ssh`, install `authorized_keys`, fix permissions/ownership.
- Usage: `sudo ./6-onboard.sh newuser "ssh-ed25519 AAAA... comment"`

### `7-sudo_config.sh`
- Purpose: grant restricted sudo permissions for operational commands.
- Granted commands:
	- `/usr/bin/systemctl restart apache2`
	- `/usr/bin/journalctl`
- Behavior: writes `/etc/sudoers.d/junior` and runs `visudo -c`.
- Usage: `sudo ./7-sudo_config.sh junior_admin`

## Notes

- These scripts can modify sensitive system security settings.
- Always test in a lab or VM before applying on a production host.
- Keep backups of `/etc/ssh/sshd_config`, PAM files, and sudoers includes.
