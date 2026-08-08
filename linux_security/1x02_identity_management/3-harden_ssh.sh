#!/bin/bash
file=$1

edit_sshd_config(){
	sed -i 's/^#\?[[:space:]]*'PermitRootLogin'.*/PermitRootLogin no/' "$file"
	sed -i 's/^#\?[[:space:]]*'PasswordAuthentication'.*/PasswordAuthenticationn no/' "$file"
	sed -i 's/^#\?[[:space:]]*'PubkeyAuthentication'.*/PubkeyAuthentication yes/' "$file"
}

edit_sshd_config
if sshd -t -f "$file"; then
    service ssh reload
fi
