#!/bin/bash
awk -v start="$(date -d '30 minutes ago' +'%k:%M:%S')" ' $3 >= start && /sshd/' $1
