#!/bin/bash
file=$2
if ! dpkg -s "$1" 1>/dev/null 2>&1; then
	apt-get update -y
	apt-get install -y "$1"
fi
sed -i 's/^password.*pam_unix\.so.*/password requisite pam_pwquality.so minlen=12 minclass=3\n&/' "$file"
