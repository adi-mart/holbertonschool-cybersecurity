#!/bin/bash
while read -r ligne; do
    if id line 2>/dev/null; then
			passwd -l $line
		else
			echo "User $line not found"
		fi
done < $1
