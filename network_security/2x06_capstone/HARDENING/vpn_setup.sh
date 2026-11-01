#!/bin/bash
# vpn_setup.sh - WireGuard secure access for the LogiCorp Gateway
#
# Deliverable for the LogiCorp gateway administrator.
#   ./vpn_setup.sh --dry-run   Shows what would be done (no privileges needed)
#   sudo ./vpn_setup.sh        Deploys the VPN (administrator, root privileges)
#
#   - IT admins: VPN access to the gateway and the internal networks (LAN_NETS)
#   - Finance:   VPN access to the gateway FTP only (FTP-over-VPN)
# Client configs are generated in /etc/wireguard/clients/. They contain private
# keys: hand them over securely and never commit them.
#
# Run after clean.sh, and before firewall.sh (panic button first).

set -u

# --- Settings (align with the Design package) --------------------------------
WG_IF="wg0"
WG_PORT="51820"
WG_NET="10.8.0"                 # VPN subnet: 10.8.0.0/24
WG_SERVER_IP="$WG_NET.1"
# Public address the clients connect to (override: sudo WG_ENDPOINT=x.x.x.x ./vpn_setup.sh)
WG_ENDPOINT="${WG_ENDPOINT:-$(ip -4 route get 1.1.1.1 2>/dev/null \
    | awk '{for (i = 1; i < NF; i++) if ($i == "src") print $(i + 1)}')}"
# Internal networks IT reaches through the VPN, comma separated (e.g. "192.168.10.0/24")
LAN_NETS="${LAN_NETS:-}"
# Clients as "name:last byte of the VPN IP".
# IT in .10-.99, Finance in .100-.199: the firewall can tell the two roles apart.
ADMIN_CLIENTS=("it-admin1:10")
FINANCE_CLIENTS=("finance1:100")
# Passive FTP range, same as clean.sh
FTP_PASV_MIN=40000
FTP_PASV_MAX=40100

WG_DIR="/etc/wireguard"
KEY_DIR="$WG_DIR/keys"
CLIENT_DIR="$WG_DIR/clients"
VSFTPD_CONF="/etc/vsftpd.conf"
VSFTPD_DROPIN="/etc/systemd/system/vsftpd.service.d/after-vpn.conf"

# --- Mode selection ----------------------------------------------------------
DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then
    DRY_RUN=1
fi

if [ "$DRY_RUN" -eq 0 ] && [ "$EUID" -ne 0 ]; then
    echo "[!] Deploying the VPN requires root: sudo $0" >&2
    echo "[i] To preview the changes without privileges: $0 --dry-run" >&2
    exit 1
fi

# --- Helpers (same as clean.sh) ----------------------------------------------
WORKDIR="$(cd "$(dirname "$0")" && pwd)"
LOG="$WORKDIR/vpn_setup.log"
log() { echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }

# Executes a privileged command, or only prints it in dry-run mode
run() {
    if [ "$DRY_RUN" -eq 1 ]; then
        log "[DRY-RUN] would run: $*"
    else
        "$@" >/dev/null 2>&1
    fi
}

# Logs a success message, only when the change was really applied
ok() { [ "$DRY_RUN" -eq 1 ] || log "[+] $*"; }

# write_file <path> <mode>: writes stdin to the file (only shown in dry-run mode)
write_file() {
    local content
    content="$(cat)"
    if [ "$DRY_RUN" -eq 1 ]; then
        log "[DRY-RUN] would write $1 (mode $2):"
        printf '%s\n' "$content" | sed 's/^/        | /' | tee -a "$LOG"
    else
        printf '%s\n' "$content" > "$1" && chmod "$2" "$1"
    fi
}

# set_option <file> <key> <separator> <value>
# Replaces the active "key" line, or inserts it at the top of the file.
set_option() {
    local file="$1" key="$2" sep="$3" value="$4"
    if grep -qE "^\s*${key}[[:space:]=]" "$file"; then
        run sed -i -E "s|^\s*${key}[[:space:]=].*|${key}${sep}${value}|" "$file" \
            && ok "$key set to $value in $file"
    else
        run sed -i "1i ${key}${sep}${value}" "$file" \
            && ok "$key added to $file"
    fi
}

# Generates a key pair once: re-running the script keeps the existing keys
gen_keys() {
    if [ "$DRY_RUN" -eq 1 ]; then
        log "[DRY-RUN] would generate (if missing): $KEY_DIR/$1.key and $1.pub"
    elif [ ! -f "$KEY_DIR/$1.key" ]; then
        (umask 077; wg genkey > "$KEY_DIR/$1.key")
        wg pubkey < "$KEY_DIR/$1.key" > "$KEY_DIR/$1.pub"
        ok "Keys generated for $1"
    else
        log "[i] Keys already exist for $1 (kept)"
    fi
}

# key_of <name> <key|pub>: prints a key, or a placeholder in dry-run mode
# (private keys never appear in the logs)
key_of() {
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "<$2 of $1>"
    else
        cat "$KEY_DIR/$1.$2"
    fi
}

[ "$DRY_RUN" -eq 1 ] && log "=== DRY-RUN mode: no change will be made ==="

# --- 1. Install WireGuard -----------------------------------------------------
log "=== [1] Installing WireGuard ==="
if command -v wg >/dev/null 2>&1; then
    log "[i] wireguard-tools already installed"
else
    run apt-get install -y wireguard-tools \
        && ok "wireguard-tools installed" \
        || { log "[!] wireguard-tools installation failed"; exit 1; }
fi

if [ -z "$WG_ENDPOINT" ]; then
    WG_ENDPOINT="GATEWAY_PUBLIC_IP"
    log "[!] Public IP not detected: edit Endpoint in the client configs (or set WG_ENDPOINT)"
fi

# --- 2. Keys ------------------------------------------------------------------
log "=== [2] Generating keys ==="
run mkdir -p "$KEY_DIR" "$CLIENT_DIR"
run chmod 700 "$WG_DIR" "$KEY_DIR" "$CLIENT_DIR"
gen_keys server
for client in "${ADMIN_CLIENTS[@]}" "${FINANCE_CLIENTS[@]}"; do
    gen_keys "${client%%:*}"
done

# --- 3. Server configuration --------------------------------------------------
log "=== [3] Writing server configuration ==="
# The private key is loaded from its file: it never appears in wg0.conf
SERVER_CONF="[Interface]
Address = $WG_SERVER_IP/24
ListenPort = $WG_PORT
PostUp = wg set %i private-key $KEY_DIR/server.key"

# add_peer <name:byte> <role>
add_peer() {
    SERVER_CONF="$SERVER_CONF

[Peer]
# ${1%%:*} ($2)
PublicKey = $(key_of "${1%%:*}" pub)
AllowedIPs = $WG_NET.${1##*:}/32"
}
for client in "${ADMIN_CLIENTS[@]}"; do
    add_peer "$client" "IT"
done
for client in "${FINANCE_CLIENTS[@]}"; do
    add_peer "$client" "Finance"
done
printf '%s\n' "$SERVER_CONF" | write_file "$WG_DIR/$WG_IF.conf" 600

# --- 4. Client configurations -------------------------------------------------
log "=== [4] Generating client configurations ==="
# IT: VPN subnet + internal networks. Finance: the gateway only (FTP).
ADMIN_ALLOWED="$WG_NET.0/24${LAN_NETS:+, $LAN_NETS}"
FINANCE_ALLOWED="$WG_SERVER_IP/32"

# write_client <name:byte> <allowed IPs> <role>
write_client() {
    local name="${1%%:*}"
    write_file "$CLIENT_DIR/$name.conf" 600 <<EOF
# LogiCorp VPN - $name ($3)
[Interface]
PrivateKey = $(key_of "$name" key)
Address = $WG_NET.${1##*:}/32

[Peer]
PublicKey = $(key_of server pub)
Endpoint = $WG_ENDPOINT:$WG_PORT
AllowedIPs = $2
PersistentKeepalive = 25
EOF
    ok "Client config: $CLIENT_DIR/$name.conf"
}
for client in "${ADMIN_CLIENTS[@]}"; do
    write_client "$client" "$ADMIN_ALLOWED" "IT"
done
for client in "${FINANCE_CLIENTS[@]}"; do
    write_client "$client" "$FINANCE_ALLOWED" "Finance"
done

# --- 5. Start the VPN ---------------------------------------------------------
log "=== [5] Starting the VPN ==="
run systemctl enable "wg-quick@$WG_IF"
run systemctl restart "wg-quick@$WG_IF"

VPN_UP=0
if [ "$DRY_RUN" -eq 1 ]; then
    VPN_UP=1
elif ip link show "$WG_IF" >/dev/null 2>&1; then
    VPN_UP=1
    ok "WireGuard up: $WG_IF ($WG_SERVER_IP), port $WG_PORT/udp"
else
    log "[!] $WG_IF is down: see 'journalctl -u wg-quick@$WG_IF' (WireGuard kernel module missing?)"
fi

# --- 6. FTP-over-VPN for Finance ----------------------------------------------
log "=== [6] Configuring FTP-over-VPN for Finance ==="
if [ ! -f "$VSFTPD_CONF" ]; then
    log "[!] vsftpd not installed: nothing to bind"
elif [ "$VPN_UP" -eq 0 ]; then
    log "[!] VPN is down: FTP left unchanged so Finance keeps working"
else
    # Copy used to roll back if vsftpd does not start on the VPN address
    [ "$DRY_RUN" -eq 0 ] && cp -p "$VSFTPD_CONF" "$VSFTPD_CONF.pre-vpn"

    # FTP is cleartext: it only listens inside the encrypted tunnel
    set_option "$VSFTPD_CONF" listen "=" YES
    set_option "$VSFTPD_CONF" listen_ipv6 "=" NO
    set_option "$VSFTPD_CONF" listen_address "=" "$WG_SERVER_IP"
    set_option "$VSFTPD_CONF" pasv_enable "=" YES
    set_option "$VSFTPD_CONF" pasv_address "=" "$WG_SERVER_IP"
    set_option "$VSFTPD_CONF" pasv_min_port "=" "$FTP_PASV_MIN"
    set_option "$VSFTPD_CONF" pasv_max_port "=" "$FTP_PASV_MAX"

    # vsftpd needs the VPN address: it starts after WireGuard
    run mkdir -p "$(dirname "$VSFTPD_DROPIN")"
    write_file "$VSFTPD_DROPIN" 644 <<EOF
[Unit]
After=wg-quick@$WG_IF.service
Requires=wg-quick@$WG_IF.service
EOF
    run systemctl daemon-reload
    run systemctl restart vsftpd

    if [ "$DRY_RUN" -eq 0 ]; then
        sleep 1
        if ss -ltn "sport = :21" | grep -q "$WG_SERVER_IP:21"; then
            ok "FTP listens only on $WG_SERVER_IP:21 (VPN)"
        else
            cp -p "$VSFTPD_CONF.pre-vpn" "$VSFTPD_CONF"
            rm -f "$VSFTPD_DROPIN"
            systemctl daemon-reload
            systemctl restart vsftpd >/dev/null 2>&1
            log "[!] vsftpd did not start on the VPN address: previous FTP config restored"
        fi
    fi
fi

# --- Summary ------------------------------------------------------------------
log "=== Done ==="
log "[i] Hand over the client configs from $CLIENT_DIR securely (they contain private keys)"
log "[i] firewall.sh must allow: $WG_PORT/udp in; on $WG_IF: SSH from IT ($WG_NET.10-99),"
log "[i]   21/tcp + $FTP_PASV_MIN-$FTP_PASV_MAX/tcp from Finance ($WG_NET.100-199) to $WG_SERVER_IP"
