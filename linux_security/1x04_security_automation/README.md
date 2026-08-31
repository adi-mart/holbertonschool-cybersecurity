# 1x04 Security Automation

## Overview

This module introduces a lightweight security monitoring agent designed to detect
abnormal service state, file tampering, and unauthorized network listeners.

The project includes a monitoring script, a systemd timer/service pair, and a
persistence setup used to run the checks automatically.

Each exercise is paired with a corresponding `N-flag.txt` file.

## Components

### `sentinel.sh`
- Purpose: enforce basic security monitoring and self-healing checks.
- Behaviors:
  - verifies required services are running;
  - restarts failed services when possible;
  - validates the integrity of critical files;
  - kills rogue processes bound to unauthorized ports;
  - logs all actions to `/var/log/sentinel.log` in JSON format.
- Configuration file: `sentinel.conf`
- Usage: `sudo ./sentinel.sh`

### `sentinel.conf`
- Purpose: central configuration for the sentinel agent.
- Variables:
  - `SERVICES`: monitored services to keep alive;
  - `FILES_TO_WATCH`: critical files whose integrity is checked;
  - `ALLOWED_PORTS`: ports allowed to remain open.

### `sentinel.service`
- Purpose: systemd service definition to run the monitor once.
- Behavior: executes `/opt/sentinel/sentinel.sh` as `root`.

### `sentinel.timer`
- Purpose: schedule periodic execution of the sentinel service.
- Interval: every 5 minutes.

### `setup_persistence.sh`
- Purpose: install the systemd unit files and enable the timer for automatic startup.
- Actions:
  - copies the service and timer to `/etc/systemd/system/`;
  - reloads systemd;
  - enables and starts the sentinel timer.
- Usage: `sudo ./setup_persistence.sh`

## Security Model

The sentinel monitors:
- service availability;
- file integrity via MD5 hash comparison;
- unexpected listening ports;
- suspicious activity that should trigger remediation.

## Notes

- This automation is a simple example and should be hardened before deployment in a real production environment.
- Run it with root privileges, since it may restart services and terminate rogue processes.
- Always test in a lab or VM before applying to a live system.
- Keep backups of monitored files and review the generated logs regularly.

