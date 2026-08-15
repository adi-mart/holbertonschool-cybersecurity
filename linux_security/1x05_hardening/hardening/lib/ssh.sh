#!/bin/bash

# harden_ssh(): configures SSH hardening settings in /etc/ssh/sshd_config
harden_ssh() {
	log "SSH" "SSHD_CONFIG" "STARTED" "Backing up sshd_config"
	# backup the original sshd_config before making changes (for safety)
	cp -n "$SSHD_CONFIG_FILE" "${SSHD_CONFIG_FILE}.bak"

	# disable root login
	grep -q "^PermitRootLogin" "$SSHD_CONFIG_FILE" &&
		sed -i "s/^PermitRootLogin.*/PermitRootLogin ${SSH_PERMIT_ROOT_LOGIN}/" "$SSHD_CONFIG_FILE" ||
		echo "PermitRootLogin ${SSH_PERMIT_ROOT_LOGIN}" >> "$SSHD_CONFIG_FILE"

	# disable password auth
	grep -q "^PasswordAuthentication" "$SSHD_CONFIG_FILE" &&
		sed -i "s/^PasswordAuthentication.*/PasswordAuthentication ${SSH_PASSWORD_AUTHENTICATION}/" "$SSHD_CONFIG_FILE" ||
		echo "PasswordAuthentication ${SSH_PASSWORD_AUTHENTICATION}" >> "$SSHD_CONFIG_FILE"

	# enforce key-only auth
	grep -q "^PubkeyAuthentication" "$SSHD_CONFIG_FILE" &&
		sed -i "s/^PubkeyAuthentication.*/PubkeyAuthentication yes/" "$SSHD_CONFIG_FILE" ||
		echo "PubkeyAuthentication yes" >> "$SSHD_CONFIG_FILE"

	# validate before reloading, restore backup if broken
	if sshd -t -f "$SSHD_CONFIG_FILE"; then
		log "SSH" "SSHD_CONFIG" "SUCCESS" "SSH configured on port ${SSH_PORT}"
		service ssh reload
	else
		log "SSH" "SSHD_CONFIG" "ERROR" "Invalid sshd_config, restoring backup"
		cp "${SSHD_CONFIG_FILE}.bak" "$SSHD_CONFIG_FILE"
		exit 1
	fi
}
