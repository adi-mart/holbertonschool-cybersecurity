# 1x00 Linux Fundamentals

## Overview

This module contains shell scripts focused on Linux basics for auditing, file discovery,
permissions, and simple system hardening helpers.

Each exercise is paired with a corresponding `N-flag.txt` file.

## Script Index

### `0-its_me.sh`
- Purpose: print the current effective user.
- Command used: `whoami`
- Usage: `./0-its_me.sh`

### `1-find_complex.sh`
- Purpose: find recent files larger than 1 MB, excluding `.gz` files.
- Command used: `find <path> -type f -mtime -7 -size +1M ! -name "*.gz"`
- Usage: `./1-find_complex.sh /path/to/search`

### `2-grep_secrets.sh`
- Purpose: recursively search files containing `password =`.
- Command used: `grep -Rl 'password =' <path>`
- Usage: `./2-grep_secrets.sh /path/to/project`

### `3-stats.sh`
- Purpose: show the most represented file owner in a directory listing.
- Commands used: `ls -l`, `awk`, `uniq -c`, `sort -nr`, `head -1`
- Usage: `./3-stats.sh /path/to/dir`

### `4-suid_hunter.sh`
- Purpose: list files with SUID bit set.
- Command used: `find <path> -type f -perm -4000`
- Usage: `./4-suid_hunter.sh /`

### `5-unlock.sh`
- Purpose: remove immutable attribute, then delete a file.
- Commands used: `chattr -i`, `rm`
- Usage: `sudo ./5-unlock.sh /path/to/file`

### `6-setup_shared.sh`
- Purpose: create and secure a shared directory for a group.
- Actions: create directory, set owner `root:<group>`, apply SGID and sticky bit.
- Usage: `sudo ./6-setup_shared.sh /srv/shared devops`

### `7-audit_gateway.sh`
- Purpose: deploy a root-readable helper and grant limited sudo access to one user.
- Actions: create `/usr/local/bin/audit-read-secret`, write sudoers rule in `/etc/sudoers.d/audit`.
- Usage: `sudo ./7-audit_gateway.sh auditor_user`

### `8-log_policy.sh`
- Purpose: create log directory policy and a `logrotate` rule.
- Actions: create directory, set `root:<group>` ownership, mode `2750`, weekly rotation with compression.
- Usage: `sudo ./8-log_policy.sh /var/log/myapp adm`

## Notes

- Most scripts expect positional arguments and have little input validation.
- Scripts modifying system files should be executed with root privileges.
- Always validate generated sudoers or configuration files before using them in production.
