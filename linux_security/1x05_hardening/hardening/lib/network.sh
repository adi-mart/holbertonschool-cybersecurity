#!/bin/bash

harden_network() {
  log "NETWORK" "FIREWALL" "STARTED" "Generating firewall policy file"

  # Ensure the target directory exists
  mkdir -p "$(dirname "$FIREWALL_RULES_FILE")"

  # Idempotent by design: we always regenerate the whole file from scratch
  # instead of appending, so re-running the script never duplicates rules
	{
		echo "DEFAULT_INPUT=deny"
		echo "DEFAULT_OUTPUT=allow"
		echo "ALLOW_TCP=${SSH_PORT}"

		# Only add HTTP/HTTPS if enabled in config (no hardcoded ports)
		[[ "$ALLOW_HTTP" == "true" ]] && echo "ALLOW_TCP=${HTTP_PORT}"
		[[ "$ALLOW_HTTPS" == "true" ]] && echo "ALLOW_TCP=${HTTPS_PORT}"
	} > "$FIREWALL_RULES_FILE"

	log "NETWORK" "FIREWALL" "SUCCESS" "Firewall policy created: ports ${SSH_PORT}, ${HTTP_PORT}, ${HTTPS_PORT} ALLOWED" 

	log "NETWORK" "SYSCTL" "STARTED" "Applying persistent kernel network hardening"

	# disable IP forwarding (idempotent: skip if already present)
	if ! grep -q "^net.ipv4.ip_forward=0" "$SYSCTL_FILE"; then
		echo "net.ipv4.ip_forward=0" >> "$SYSCTL_FILE"
		log "NETWORK" "SYSCTL" "SUCCESS" "Added ip_forward=0 to ${SYSCTL_FILE}"
	else
		log "NETWORK" "SYSCTL" "SKIPPED" "ip_forward=0 already present"
	fi

	# ignore ICMP echo requests (idempotent: skip if already present)
	if ! grep -q "^net.ipv4.icmp_echo_ignore_all=1" "$SYSCTL_FILE"; then
		echo "net.ipv4.icmp_echo_ignore_all=1" >> "$SYSCTL_FILE"
		log "NETWORK" "SYSCTL" "SUCCESS" "Added icmp_echo_ignore_all=1 to ${SYSCTL_FILE}"
	else
		log "NETWORK" "SYSCTL" "SKIPPED" "icmp_echo_ignore_all=1 already present"
	fi

	log "NETWORK" "SYSCTL" "COMPLETED" "Kernel network hardening finished"
}
