#!/bin/bash
[ -f "sentinel.conf" ] || exit 1; source "sentinel.conf"; [ -n "${SERVICES+x}" ] && [ -n "${FILES_TO_WATCH+x}" ] || exit 1

check_services() {
	for service in "${SERVICES[@]}"; do
		if pgrep -f "$service"; then 
			echo "OK: $service is running"
		else
			eval "$service" 
			if pgrep -f "$service"; then
				echo "FIXED: Restarted $service"
			else
				echo "Error "
			fi
		fi
	done 
	}
check_services


check_integrity() {
	for file in "${FILES_TO_WATCH[@]}"; do
		GOLDEN="/var/backups/sentinel/$(basename "$file").gold"
		LIVE_HASH=$(md5sum "$file"| awk '{print $1}')
		GOLD_HASH=$(md5sum "$GOLDEN"| awk '{print $1}')
			if [ "${LIVE_HASH}" != "$GOLDEN" ]; then
				cp "$GOLDEN" "$file"
				echo "FIXED: Restored $file"
			else
				echo "OK: $file integrity verified"
			fi
	done
}

check_integrity 
