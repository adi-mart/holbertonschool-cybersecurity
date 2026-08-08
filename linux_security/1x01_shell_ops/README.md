# 1x01 Shell Operations

## Overview

This module focuses on shell I/O, redirections, filters, process substitution,
batch file operations, and simple automation utilities.

Each exercise is paired with a corresponding `N-flag.txt` file.

## Script Index

### `0-logging.sh`
- Purpose: redirect stdout and stderr to one log file, then emit test messages.
- Usage: `./0-logging.sh /tmp/task.log`

### `1-compare.sh`
- Purpose: compare file first-column values with their sorted version.
- Technique: process substitution with `diff <(...) <(...)`.
- Usage: `./1-compare.sh /etc/passwd`

### `2-mass_rename.sh`
- Purpose: rename top-level `.log` files by appending `.old`.
- Technique: `find ... -print0 | xargs -0` for safe filename handling.
- Usage: `./2-mass_rename.sh /var/log/myapp`

### `3-anonymize.sh`
- Purpose: mask IPv4 addresses in a text file.
- Output token: `[REDACTED_IP]`
- Usage: `./3-anonymize.sh access.log`

### `4-heavy_files.sh`
- Purpose: list files larger than 1024 bytes from `ls -l` output.
- Usage: `./4-heavy_files.sh /path/to/dir`

### `5-cleanup.sh`
- Purpose: read usernames from a file and lock matching accounts.
- Intended action: `usermod -L <user>`
- Usage: `sudo ./5-cleanup.sh users.txt`

### `6-wait_for.sh`
- Purpose: wait until TCP port 80 is reachable on a target host.
- Behavior: loops with `nc -z <host> 80`, prints `Waiting...`, then `Service UP!`.
- Usage: `./6-wait_for.sh example.com`

### `7-rotate.sh`
- Purpose: rotate large `.log` files into a `backups` directory after gzip compression.
- Threshold: files larger than 1024 bytes.
- Usage: `./7-rotate.sh /path/to/logdir`

## Notes

- Scripts generally assume valid arguments and existing paths.
- `5-cleanup.sh` and other account/system scripts should be run as root.
- For production usage, add defensive checks (`set -euo pipefail`, argument validation, and error handling).
