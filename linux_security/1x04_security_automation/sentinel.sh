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

check_ports() {
	PORT=$(ss -tln | awk 'NR>1 {split($4,a,":"); print a[2] }')
	for port in "${PORT}"; do
		ALLOWED=false
		for allowed_port in "${ALLOWED_PORTS[@]}"; do
			if [ "$port" = "${allowed_port}" ]; then
				ALLOWED=true
				break
			fi
		done
			if [ "$ALLOWED" = false ]; then
				PID=$(ss -lptn "sport = :$port" | grep -oP 'pid=\K[0-9]+')
				kill -9 "$PID" 
				echo "ALERT: Killed rogue process on port $PORT"
			fi
	done
}

check_ports