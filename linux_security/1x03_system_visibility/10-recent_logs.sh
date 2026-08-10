#!/bin/bash
journalctl -u sshd --since "30 minutes ago"
