#!/bin/bash
grep -E '^[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+[[:space:]]+.*localhost' /etc/hosts | awk '{print $1}' | head -n 1
