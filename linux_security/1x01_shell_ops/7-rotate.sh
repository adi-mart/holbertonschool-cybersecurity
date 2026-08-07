#!/bin/bash
TRUC="$1"
if [ ! -d "$TRUC" ]; then
	exit 1
fi
mkdir -p "$TRUC/backups"
for file in "$TRUC"/*.log; do
	if [ $(stat -c%s "$file") -gt 1024 ]; then
		gzip "$file"
		mv "$file.gz" "$TRUC/backups"
	else
		echo "Skipping small file: $file"
	fi
done
