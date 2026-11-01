#!/bin/bash
# =====================================================================
# firewall.sh - LogiCorp Gateway Firewall
# Firewall managed with nftables
#
# Usage:
#   ./firewall.sh --dry-run check      # syntax validation without applying rules
#   ./firewall.sh --dry-run apply      # preview the generated nftables config
#   sudo ./firewall.sh check
#   sudo ./firewall.sh apply
#   sudo ./firewall.sh status
# =====================================================================

set -euo pipefail

DRY_RUN=0
ACTION="${1:-apply}"

if [ "${1:-}" = "--dry-run" ]; then
    DRY_RUN=1
    ACTION="${2:-apply}"
fi

# 1. Network configuration

WAN="eth1"
TRUNK="eth2"
VPN="wg0"

# VLAN interfaces
V_OFFICE="${TRUNK}.10"
V_FINANCE="${TRUNK}.20"
V_GUEST="${TRUNK}.30"
V_DB="${TRUNK}.50"
V_DMZ="${TRUNK}.60"

# Internal network subnets
NET_OFFICE="10.50.10.0/24"
NET_FINANCE="10.50.20.0/24"
NET_GUEST="10.50.30.0/24"
NET_DB="10.50.50.0/24"
NET_DMZ="10.50.60.0/24"

# VPN configuration
VPN_ADMINS="10.8.0.10-10.8.0.19"
VPN_ACCOUNTANTS="10.8.0.100-10.8.0.149"
WG_PORT="51820"

# FTP server in the DMZ
FTP_HOST="10.50.60.40"
FTP_PORT="21"
FTP_PASV="30000-30100"

# Database server (VLAN 50)
DB_HOST="10.50.50.50"
DB_PORT="3306"      # DBMS port, from /etc/logicorp/db.conf

# Firewall configuration paths
RULES_FILE="/etc/nftables.conf"

# OUTPUT policy:
# drop = only explicitly authorized outgoing traffic is allowed.
OUTPUT_POLICY="drop"


# 2. Generate nftables rules

build_rules() {

cat <<EOF
#!/usr/sbin/nft -f

# Remove existing nftables rules
flush ruleset

# ================================================================
# FILTER TABLE
# ================================================================

table inet logicorp {

    # ------------------------------------------------------------
    # INPUT : Traffic destined for the gateway itself
    # ------------------------------------------------------------

    chain input {
        type filter hook input priority 0; policy drop;

        # Drop invalid packets
        ct state invalid drop

        # Allow established and related connections
        ct state established,related accept

        # Allow local loopback traffic
        iifname "lo" accept

        # Block FTP and SSH from the WAN
        iifname "${WAN}" tcp dport { 21, 22 } limit rate 5/second log prefix "FW-WAN-21-22: "
        iifname "${WAN}" tcp dport { 21, 22 } drop

        # Block SSH attempts from VPN accountants
        iifname "${VPN}" ip saddr ${VPN_ACCOUNTANTS} tcp dport 22 limit rate 5/second log prefix "FW-SSH-ACCOUNTANTS: "
        iifname "${VPN}" ip saddr ${VPN_ACCOUNTANTS} tcp dport 22 drop

        # Allow ICMP IPv4 and IPv6 for network diagnostics
        ip protocol icmp accept
        meta l4proto ipv6-icmp accept

        # Allow WireGuard traffic from the Internet
        iifname "${WAN}" udp dport ${WG_PORT} accept

        # Allow SSH to the gateway only for VPN administrators
        iifname "${VPN}" ip saddr ${VPN_ADMINS} tcp dport 22 ct state new accept

        # Allow DHCP requests from Office, Finance and Guest VLANs
        iifname { "${V_OFFICE}", "${V_FINANCE}", "${V_GUEST}" } udp sport 68 udp dport 67 accept

        # Log other unauthorized incoming packets
        limit rate 5/second log prefix "FW-INPUT-DROP: "
    }


    # ------------------------------------------------------------
    # FORWARD : Traffic passing through the gateway
    # ------------------------------------------------------------

    chain forward {
        type filter hook forward priority 0; policy drop;

        # Drop invalid packets
        ct state invalid drop

        # Allow established and related connections
        ct state established,related accept

        # Block FTP from the WAN to the DMZ server (never exposed to the Internet)
        iifname "${WAN}" ip daddr ${FTP_HOST} tcp dport ${FTP_PORT} limit rate 5/second log prefix "FW-WAN-FTP: "
        iifname "${WAN}" ip daddr ${FTP_HOST} tcp dport ${FTP_PORT} drop

        # VPN accountants -> FTP server in the DMZ
        # FTP control connection and passive data connections
        iifname "${VPN}" ip saddr ${VPN_ACCOUNTANTS} oifname "${V_DMZ}" ip daddr ${FTP_HOST} tcp dport { ${FTP_PORT}, ${FTP_PASV} } ct state new accept

        # Finance VLAN -> FTP server in the DMZ
        # Finance retrieves the invoices uploaded by the remote accountants.
        iifname "${V_FINANCE}" oifname "${V_DMZ}" ip daddr ${FTP_HOST} tcp dport { ${FTP_PORT}, ${FTP_PASV} } ct state new accept

        # VPN administrators -> database and FTP servers (SSH only)
        # SSH is limited to these two servers, never to the entire internal network.
        iifname "${VPN}" ip saddr ${VPN_ADMINS} ip daddr { ${DB_HOST}, ${FTP_HOST} } tcp dport 22 ct state new accept

        # Block connections initiated from the DMZ
        iifname "${V_DMZ}" limit rate 5/second log prefix "FW-DMZ-INITIATED: "
        iifname "${V_DMZ}" drop

        # Block Guest access to internal network zones
        iifname "${V_GUEST}" oifname { "${V_OFFICE}", "${V_FINANCE}", "${V_DB}", "${V_DMZ}" } limit rate 5/second log prefix "FW-GUEST-INTERNAL: "
        iifname "${V_GUEST}" oifname { "${V_OFFICE}", "${V_FINANCE}", "${V_DB}", "${V_DMZ}" } drop

        # Allow HTTPS access to the Internet from internal VLANs
        iifname { "${V_OFFICE}", "${V_FINANCE}", "${V_GUEST}" } oifname "${WAN}" tcp dport 443 ct state new accept

        # Allow DNS requests to the Internet
        iifname { "${V_OFFICE}", "${V_FINANCE}", "${V_GUEST}" } oifname "${WAN}" udp dport 53 ct state new accept
        iifname { "${V_OFFICE}", "${V_FINANCE}", "${V_GUEST}" } oifname "${WAN}" tcp dport 53 ct state new accept

        # Database access:
        # Office and Finance VLANs -> database server, DBMS port only
        iifname { "${V_OFFICE}", "${V_FINANCE}" } oifname "${V_DB}" ip daddr ${DB_HOST} tcp dport ${DB_PORT} ct state new accept

        # Log other unauthorized forwarded packets
        limit rate 5/second log prefix "FW-FORWARD-DROP: "
    }


    # ------------------------------------------------------------
    # OUTPUT : Traffic generated by the gateway
    # ------------------------------------------------------------

    chain output {
        type filter hook output priority 0; policy ${OUTPUT_POLICY};

        # Allow local loopback traffic
        oifname "lo" accept

        # Drop invalid packets
        ct state invalid drop

        # Allow established and related connections
        ct state established,related accept

        # Allow DHCP responses to Office, Finance and Guest VLANs
        oifname { "${V_OFFICE}", "${V_FINANCE}", "${V_GUEST}" } udp sport 67 udp dport 68 accept

        # Allow ICMP IPv4 and IPv6
        ip protocol icmp accept
        meta l4proto ipv6-icmp accept

        # Allow DNS requests from the gateway
        oifname "${WAN}" udp dport 53 accept
        oifname "${WAN}" tcp dport 53 accept

        # Allow NTP synchronization
        oifname "${WAN}" udp dport 123 accept

				# Allow WireGuard replies and handshakes initiated by the gateway
        oifname "${WAN}" udp sport ${WG_PORT} accept

        # Allow HTTP/HTTPS for updates and external services
        oifname "${WAN}" tcp dport { 80, 443 } accept

        # Log other unauthorized outgoing packets
        limit rate 5/second log prefix "FW-OUTPUT-DROP: "
    }
}


# ================================================================
# NAT TABLE
# ================================================================

table ip nat {

    chain postrouting {
        type nat hook postrouting priority srcnat; policy accept;

        # Masquerade internal VLAN traffic when leaving through the WAN
        oifname "${WAN}" ip saddr {
            ${NET_OFFICE},
            ${NET_FINANCE},
            ${NET_GUEST}
        } masquerade
    }
}
EOF

}


# 3. Utility functions

require_root() {

    if [ "$(id -u)" -ne 0 ]; then
        echo "ERROR: This script must be executed as root (sudo)." >&2
        exit 1
    fi

}


check_dependencies() {

    command -v nft >/dev/null 2>&1 \
        || { echo "ERROR: nftables is not installed."; exit 1; }

}


# 4. Check configuration without applying it

cmd_check() {

    check_dependencies

    local tmp
    tmp="$(mktemp)"

    trap 'rm -f "${tmp}"' RETURN

    build_rules > "${tmp}"

    if [ "$DRY_RUN" -eq 1 ] && [ "$(id -u)" -ne 0 ]; then
        echo "[DRY-RUN] Not running as root: skipping nft validation."
        echo "[DRY-RUN] Generated config preview:"
        cat "${tmp}"
        return
    fi

    nft -c -f "${tmp}"

    echo "Firewall syntax is valid."
    echo "No firewall rules have been applied."

    if [ "$DRY_RUN" -eq 1 ]; then
        echo "[DRY-RUN] Validation was performed without applying the rules."
    fi

}


# 5. Apply firewall configuration

cmd_apply() {

    if [ "$DRY_RUN" -eq 1 ]; then
        check_dependencies

        local tmp
        tmp="$(mktemp)"

        trap 'rm -f "${tmp}"' RETURN

        build_rules > "${tmp}"

        if [ "$(id -u)" -ne 0 ]; then
            echo "[DRY-RUN] Not running as root: skipping nft validation and apply."
            echo "[DRY-RUN] Generated rules preview:"
            cat "${tmp}"
            return
        fi

        nft -c -f "${tmp}"

        echo "[DRY-RUN] Firewall config is valid. No rules were applied."
        echo "[DRY-RUN] Generated rules preview:"
        cat "${tmp}"
        return
    fi

    require_root
    check_dependencies

    local tmp
    tmp="$(mktemp)"

    trap 'rm -f "${tmp}"' RETURN

    # Generate firewall configuration
    build_rules > "${tmp}"

    # Validate syntax before applying anything
    nft -c -f "${tmp}"

    echo "Firewall configuration validated."

    # Backup existing configuration
    if [ -f "${RULES_FILE}" ]; then
        cp -a "${RULES_FILE}" "${RULES_FILE}.bak"
        echo "Previous configuration backed up."
    fi

    # Install new nftables configuration
    install -m 600 "${tmp}" "${RULES_FILE}"

    # Kernel settings (IP forwarding, rp_filter...) are applied by clean.sh.
    # The gateway must route between zones: warn if forwarding is off.
    if [ "$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null)" != "1" ]; then
        echo "WARNING: IP forwarding is disabled: run clean.sh first."
    fi

    # Apply firewall rules
    nft -f "${RULES_FILE}"

    echo "Firewall rules successfully applied."

    # Enable nftables at startup when systemd is available
    if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
        systemctl enable nftables >/dev/null 2>&1 || true
        echo "nftables service enabled at startup."
    else
        echo "systemd not detected."
        echo "Configure firewall loading at startup manually."
    fi

    echo ""
    echo "IMPORTANT: Verify network access before closing your current session."

}


# 6. Display current firewall rules

cmd_status() {

    require_root
    check_dependencies

    nft list ruleset

}


# 7. Main command

case "${ACTION}" in

    check)
        cmd_check
        ;;

    apply)
        cmd_apply
        ;;

    status)
        cmd_status
        ;;

    *)
        echo "Usage: ./firewall.sh [--dry-run] {check|apply|status} | sudo ./firewall.sh {check|apply|status}"
        exit 1
        ;;

esac