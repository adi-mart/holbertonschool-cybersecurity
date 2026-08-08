#!/bin/bash
file=$1
params=("PermitRootLogin" "PasswordAuthentication")

edit_sshd_config(){
	for PARAM in "${params[@]}"; do
		sed -i 's/^#\?[[:space:]]*'"$PARAM"'.*/'"$PARAM"' no/' "$file"
	done
	sed -i 's/^#\?[[:space:]]*'PubkeyAuthentication'.*/PubkeyAuthentication yes/' "$file"
}
edit_sshd_config
if sshd -t -f "$file"; then
    service ssh reload
fi
