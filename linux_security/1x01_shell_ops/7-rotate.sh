#!/bin/bash
TRUC="$1"
if [ ! -d "$TRUC" ]; then
	exit 1
fi
mkdir -p "$TRUC/backups"
find $TRUC -type f -name "*.log" | while read -r file; do
	if [ $(stat -c%s "$file") -gt 1024 ]; then
		gzip "$file"
		mv "$file.gz" "$TRUC/backups"
	else
		echo "Skipping small file: $file"
	fi
done
