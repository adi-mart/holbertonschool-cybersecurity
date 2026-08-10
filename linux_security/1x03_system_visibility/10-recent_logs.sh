#!/bin/bash
FILE=$(date -d "30 minutes ago" +"%d-%m-%y %k:%M:%S")
awk -v start="$FILE" ' $3>"$FILE" && /sshd/' $1
