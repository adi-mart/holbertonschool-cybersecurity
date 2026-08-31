# 1x03 System Visibility

## Overview

This module focuses on observing and analyzing running processes, system state,
network listeners, and recent kernel or service activity on a Linux host.

Each exercise is paired with a corresponding `N-flag.txt` file.

## Script Index

### `0-hog.sh`
- Purpose: identify the process using the most CPU time.
- Method: sorts `ps` output by `%CPU` and prints the top consumer.
- Usage: `./0-hog.sh`

### `1-proc_env.sh`
- Purpose: display the environment of a given process.
- Input: process ID.
- Usage: `./1-proc_env.sh <pid>`

### `2-zombies.sh`
- Purpose: list zombie processes currently present on the system.
- Detection: filters `ps` output for state `Z`.
- Usage: `./2-zombies.sh`

### `3-parent.sh`
- Purpose: display the parent process ID of a target process.
- Usage: `./3-parent.sh <pid>`

### `4-term.sh`
- Purpose: gracefully terminate a process with `SIGTERM`.
- Usage: `./4-term.sh <pid>`

### `5-kill.sh`
- Purpose: forcefully terminate a process with `SIGKILL`.
- Usage: `./5-kill.sh <pid>`

### `6-freeze.sh`
- Purpose: pause a process with `SIGSTOP`.
- Usage: `./6-freeze.sh <pid>`

### `7-listening.sh`
- Purpose: list listening TCP sockets on IPv4.
- Output: ports bound by active listeners.
- Usage: `./7-listening.sh`

### `8-who_listens.sh`
- Purpose: identify the process name that owns a given listening port.
- Usage: `./8-who_listens.sh <port>`

### `9-process_user.sh`
- Purpose: display the user owning a specific process.
- Usage: `./9-process_user.sh <pid>`

### `10-recent_logs.sh`
- Purpose: filter log entries for recent `sshd` activity within the last 30 minutes.
- Usage: `./10-recent_logs.sh /var/log/auth.log`

### `11-kernel.sh`
- Purpose: search system logs for `segfault` entries.
- Usage: `./11-kernel.sh /var/log/syslog`

## Notes

- These scripts are intended for Linux hosts and often depend on standard system tools such as `ps`, `ss`, `awk`, and `lsof`.
- Process termination scripts should only be used carefully and only against processes you intentionally target.
- For production troubleshooting, combine these checks with logs, service status, and a clear understanding of the system’s normal behavior.

