#!/bin/bash
while read -r ligne; do
    if id line 2>/dev/null; then
			usermod -L $line
		else
			echo "User $line not found"
		fi
done < $1
