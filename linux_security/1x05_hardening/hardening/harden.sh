#!/bin/bash

# Absolute path to the directory containing this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Absolute path to the configuration file
CONFIG_FILE="${SCRIPT_DIR}/config/harden.cfg"

# Check if the configuration file exists and is readable
[ -f "$CONFIG_FILE" ] || { echo "Error: config file not found." >&2; exit 1; }

# Load configuration variables (LOG_FILE, SSH_PORT, etc.) into the current shell
source "$CONFIG_FILE"

# EUID: effective user ID of whoever is running the script (0 = root)
if [[ "$EUID" -ne 0 ]]; then
  echo "Error: this script must be run as root." >&2 # Not running as root: print error to stderr and abort
  exit 1
fi

# Ensure the log file exists and is writable, or create it if it doesn't exist
touch "$LOG_FILE" 2>/dev/null || { echo "Error: cannot write to $LOG_FILE." >&2; exit 1; }
LOG_START_LINE=$(wc -l < "$LOG_FILE")

# log(): writes a structured JSON log entry to $LOG_FILE
log() {
    local component="$1"
    local target="$2"
    local status="$3"
    local details="$4"
    local timestamp
    timestamp=$(date -u +%FT%TZ)

    # Append a single-line JSON object to the log file
    echo "{\"timestamp\": \"$timestamp\", \"component\": \"$component\", \"target\": \"$target\", \"status\": \"$status\", \"details\": \"$details\"}" >> "$LOG_FILE"
}
# First log entry, required by the subject: confirms the framework started correctly
log "ENGINE" "HARDENING FRAMEWORK" "INITIALIZED" "Hardening framework initialized"

source "${SCRIPT_DIR}/lib/network.sh"
source "${SCRIPT_DIR}/lib/ssh.sh"
source "${SCRIPT_DIR}/lib/identity.sh"
source "${SCRIPT_DIR}/lib/system.sh"


main() {
	harden_network
	harden_ssh
	harden_identity
	harden_system
	generate_report
	log "ENGINE" "HARDENING FRAMEWORK" "COMPLETED" "Hardening process completed successfully"
}

main "$@"