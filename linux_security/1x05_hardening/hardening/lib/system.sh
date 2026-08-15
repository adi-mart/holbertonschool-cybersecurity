#!/bin/bash

# is_installed(): returns 0 if the given package is actually installed
is_installed() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"
}

# harden_system(): updates the system, removes bloatware, and installs security tools
harden_system() {
	log "SYSTEM" "APT" "STARTED" "Updating package repositories"

	if ! DEBIAN_FRONTEND=noninteractive apt-get update >/dev/null 2>&1; then
			log "SYSTEM" "APT" "ERROR" "apt-get update failed"
	else
			log "SYSTEM" "APT" "SUCCESS" "Repositories updated"
	fi

	upgrade_output=$(DEBIAN_FRONTEND=noninteractive apt-get -y \
    -o Dpkg::Options::="--force-confold" \
    -o Dpkg::Options::="--force-confdef" \
    upgrade 2>&1)

	if echo "$upgrade_output" | grep -qE "^0 upgraded, 0 newly installed, 0 to remove"; then
		log "SYSTEM" "APT" "SKIPPED" "Package updates skipped (already up to date)"
	else
		log "SYSTEM" "APT" "SUCCESS" "Packages upgraded"
	fi

	# remove bloatware, tracking what was actually removed
	local removed=""
	for pkg in "${BLOATWARE_PACKAGES[@]}"; do
		if is_installed "$pkg"; then
			DEBIAN_FRONTEND=noninteractive apt-get purge -y >/dev/null 2>&1 "$pkg"
			removed="${removed}${pkg}, "
		fi
	done

	if [[ -n "$removed" ]]; then
		log "SYSTEM" "BLOATWARE" "SUCCESS" "Removed: ${removed%, }"
	else
		local bloatware_list=""
		for pkg in "${BLOATWARE_PACKAGES[@]}"; do
			bloatware_list+="${pkg}, "
		done
		bloatware_list="${bloatware_list%, }"
		log "SYSTEM" "BLOATWARE" "SKIPPED" "No bloatware packages (${bloatware_list}) found to remove"
	fi

	# install security tools, tracking what was actually installed
	local installed=""
	for pkg in "${INSTALL_TOOLS[@]}"; do
		if ! is_installed "$pkg"; then
			DEBIAN_FRONTEND=noninteractive apt-get install -y >/dev/null 2>&1 "$pkg"
			installed="${installed}${pkg}, "
		fi
	done

	if [[ -n "$installed" ]]; then
		log "SYSTEM" "TOOLS" "SUCCESS" "Installed: ${installed%, }"
	else
		local tools_list=""
		for pkg in "${INSTALL_TOOLS[@]}"; do
			tools_list+="${pkg}, "
		done
		tools_list="${tools_list%, }"
		log "SYSTEM" "TOOLS" "SKIPPED" "Security tools: (${tools_list}) already installed"
	fi

	log "SYSTEM" "APT" "COMPLETED" "System hardening finished"
}

# generate_report(): parses $LOG_FILE and produces the audit report
generate_report() {
	local report_file="./audit_report.txt"
	local timestamp
	timestamp=$(date '+%Y-%m-%d %H:%M:%S')

	{
    echo "==============================================="
    echo " HARDENING AUDIT REPORT - ${timestamp}"
    echo "==============================================="
    echo ""
    echo "[INFO] Hardening procedure completed successfully."
	} > "$report_file"

	local error_count=0
	local component target status details level

	while IFS= read -r line; do
		[[ -z "$line" ]] && continue

		component=$(echo "$line" | sed -n 's/.*"component": "\([^"]*\)".*/\1/p')
		target=$(echo "$line"    | sed -n 's/.*"target": "\([^"]*\)".*/\1/p')
		status=$(echo "$line"    | sed -n 's/.*"status": "\([^"]*\)".*/\1/p')
		details=$(echo "$line"   | sed -n 's/.*"details": "\([^"]*\)".*/\1/p')

		# Skip internal bookkeeping noise: only report on meaningful outcomes
		if [[ "$status" == "STARTED" || "$status" == "INITIALIZED" || "$status" == "COMPLETED" ]]; then
			continue
		fi

		# Skip specific targets that are too detailed for a summary report
		if [[ "$target" == "PAM" || "$target" == "ROOT" || "$target" == "AUDIT" || "$target" == "SYSCTL" ]]; then
			continue
		fi
		# Skip APT success messages, since they are too verbose and not actionable
		if [[ "$target" == "APT" && "$status" == "SUCCESS" ]]; then
    	continue
		fi

		# Skip SSHD_CONFIG skipped messages, since they are not actionable and clutter the report
		if [[ "$target" == "SSHD_CONFIG" && "$status" == "SKIPPED" ]]; then
			continue
		fi

		# Determine the log level based on the status
		if [[ "$status" == "ERROR" ]]; then
			level="ERROR"
			((error_count++))
		elif [[ "$status" == "SKIPPED" ]]; then
			level="WARN"
		else
			level="INFO"
		fi

		echo "[${level}] ${details}" >> "$report_file"
	done < <(tail -n +"$((LOG_START_LINE + 1))" "$LOG_FILE")

	{
		echo ""
		echo "==============================================="
		if [[ "$error_count" -eq 0 ]]; then
			echo " COMPLIANCE STATUS: PASS"
		else
			echo " COMPLIANCE STATUS: FAIL (${error_count} error(s) detected)"
		fi
		echo "==============================================="
	} >> "$report_file"
}
