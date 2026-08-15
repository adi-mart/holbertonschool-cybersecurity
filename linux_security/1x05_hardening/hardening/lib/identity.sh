#!/bin/bash


harden_identity() {
	log "IDENTITY" "PAM" "STARTED" "Configuring identity hardening"

	# complexity policy
	dpkg -s libpam-pwquality >/dev/null 2>&1 || apt-get install -y >/dev/null 2>&1 libpam-pwquality
	grep -q "pam_pwquality.so" /etc/pam.d/common-password ||
		sed -i "/pam_unix\.so/i password requisite pam_pwquality.so retry=3 minlen=${PASS_MIN_LEN} ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1" /etc/pam.d/common-password

	# max password age
	grep -q "^PASS_MAX_DAYS" /etc/login.defs &&
		sed -i "s/^PASS_MAX_DAYS.*/PASS_MAX_DAYS ${PASS_MAX_DAYS}/" /etc/login.defs ||
		echo "PASS_MAX_DAYS ${PASS_MAX_DAYS}" >> /etc/login.defs

	# lockout threshold
	grep -q "^deny" /etc/security/faillock.conf &&
		sed -i "s/^deny.*/deny = ${FAIL_LOCK_ATTEMPTS}/" /etc/security/faillock.conf ||
		echo "deny = ${FAIL_LOCK_ATTEMPTS}" >> /etc/security/faillock.conf

	log "IDENTITY" "PAM" "SUCCESS" "Password policy: min ${PASS_MIN_LEN} chars, max ${PASS_MAX_DAYS} days, lockout after ${FAIL_LOCK_ATTEMPTS}"

	# delete UID>1000 users NOT in sudo/wheel
	unauthorized_user=$(awk -F: '$3 > 1000 {print $1}' /etc/passwd)
	removed=""
	for user in $unauthorized_user; do
		if ! id -nG "$user" | grep -qwE 'sudo|wheel'; then
			userdel -r "$user" >/dev/null 2>&1
			[[ -n "$removed" ]] && removed="${removed}, ${user}" || removed="${user}"
		fi
	done

	count=$(echo "$removed" | tr ',' '\n' | grep -c .)

	if [[ "$count" -gt 0 ]]; then
		log "IDENTITY" "USERS" "SUCCESS" "${count} unauthorized users removed: $(echo "$removed" | paste -sd, -)"
	else
		log "IDENTITY" "USERS" "SKIPPED" "No unauthorized users found"
	fi

	# lock root
	passwd -l root >/dev/null 2>&1
	log "IDENTITY" "ROOT" "SUCCESS" "Root account password locked"

	log "IDENTITY" "PAM" "COMPLETED" "Identity hardening finished"
}