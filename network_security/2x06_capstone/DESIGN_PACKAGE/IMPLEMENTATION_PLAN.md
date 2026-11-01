# IMPLEMENTATION PLAN: LogiCorp Gateway

## 1. Principles

1. **Never lose access**: out-of-band console access is verified before any change; a new administration path is validated **before** the old one is closed.
2. **Every step is reversible**: backup before, validation test after, written rollback procedure.
3. **Go / No-Go**: we move to the next step only if all the tests of the current step are green.
4. **Observe before blocking**: the rules are first loaded in logging mode, then in blocking mode.
5. **Persistence comes last**: a rule is made permanent (survives a reboot) only once validated. A reboot therefore remains a rollback method until the end.

All steps take place within a **maintenance window** announced to users (accountants are warned about the change in FTP access).

## 2. Overview

| Step | Action | Production impact | Rollback |
|---|---|---|---|
| 0 | Preparation, backups, console access | None | — |
| 1 | Containment: backdoor, Telnet, permissions, credentials | None | Targeted restoration |
| 2 | SSH hardening | None if the order is respected | Restore `sshd_config` |
| 3 | WireGuard VPN deployment | None (addition) | `wg-quick down wg0` |
| 4 | Firewall in observation mode | None | `nft flush ruleset` |
| 5 | Firewall in blocking mode (INPUT/FORWARD DROP) | High if error | Automatic (dead man's switch) |
| 6 | VLAN segmentation | High if error | Move the switch ports back to the old VLAN |
| 7 | FTP migration to the DMZ | Medium (accountants) | Re-enable the gateway's vsftpd |
| 8 | OUTPUT DROP | Low | Set the OUTPUT policy back to ACCEPT |
| 9 | Persistence and monitoring | None | Restore `run.sh` |

The order follows the logic "first what breaks nothing, then what can break things". Containment comes first: there is no point hardening a machine whose key the attacker still holds.

---

## 3. Detailed steps

### Step 0: preparation

| | |
|---|---|
| **Actions** | 1. Verify **out-of-band console** access (physical console, IPMI or the hosting provider's console): it is the safety net for all the following steps.<br>2. Back up: `nft list ruleset > /root/backup/nft.rules`, `/etc/ssh/sshd_config`, `/etc/vsftpd.conf`, `/etc/cron.d/`, `/etc/run.sh`, `/etc/logicorp/`, the package list (`dpkg -l`).<br>3. Copy the backups **off the machine**.<br>4. Read the database port in `/etc/logicorp/db.conf` and put the value in `$DB_PORT` (FIREWALL_POLICY §5).<br>5. Check that the switch supports 802.1Q. |
| **Validation** | Console login succeeds; backups present on a third-party machine; DBMS port known. |
| **Rollback** | Not applicable (no change made). |
| **No-Go if** | No console access or unmanageable switch: **stop**, the plan must be reviewed. |

### Step 1: containment

| | |
|---|---|
| **Actions** | 1. **Backdoor (D7)**: copy `/etc/cron.d/logicorp` as evidence (off the machine), then delete it. Kill the pending `curl` processes.<br>2. **Telnet (D8)**: `apt purge telnetd`.<br>3. **Permissions (D9)**: `chown -R root:root /etc/logicorp`, `chmod 750` on the directory, `chmod 640` on the files.<br>4. **Credentials**: change the root, student, FTP and database passwords (`db.conf` was readable by everyone, so it is considered exposed).<br>5. Look for other persistence mechanisms: `authorized_keys` of all accounts, recently modified files (`find / -mtime -30 -type f`), unknown services. |
| **Validation** | `ls /etc/cron.d/` no longer contains `logicorp`; `ps aux` no longer shows `curl` to `192.168.1.200`; `dpkg -l telnetd` = absent; `ls -l /etc/logicorp` = no read access for "others"; the business application connects to the database with the new password. |
| **Rollback** | Permissions: restore from backup. Credentials: if the application can no longer connect, fix `db.conf` (the password **never** goes back to the old one). The backdoor and Telnet are **never** restored. |
| **Alert** | If step 5 reveals a deeper compromise (modified binaries, rootkit): stop the plan and **rebuild** the gateway (Phase 0 recommendation of the Gap Analysis). |

### Step 2: SSH hardening

| | |
|---|---|
| **Actions** | 1. Create a named admin account with `sudo`, and add its SSH public key.<br>2. **In a new session** (keep the current session open), log in with this account and the key, then test `sudo -v`.<br>3. Only then, in `sshd_config`: `PermitRootLogin no`, `PasswordAuthentication no`.<br>4. `sshd -t` (syntax check), then `systemctl reload ssh`. |
| **Validation** | New session with the key: OK. `ssh root@...`: refused. Password login: refused. |
| **Rollback** | From the session left open (or the console): restore the backed-up `sshd_config`, then `reload`. |

### Step 3: VPN deployment

| | |
|---|---|
| **Actions** | 1. Install WireGuard, generate the server key pair.<br>2. Create `wg0` (`10.8.0.1/24`, port 51820) according to VPN_DESIGN.md.<br>3. Add **a single admin peer** (`10.8.0.10`) to start with.<br>4. The firewall still being empty, nothing blocks port 51820. |
| **Validation** | From the admin workstation: `wg show` displays a recent handshake; `ping 10.8.0.1` answers; `ssh admin@10.8.0.1` works. **This is the new administration path, it must work before step 5.** |
| **Rollback** | `wg-quick down wg0`, disable the service. Direct SSH access is still open at this stage. |

### Step 4: firewall in observation mode

| | |
|---|---|
| **Actions** | 1. Load the FIREWALL_POLICY §5 ruleset with the **INPUT and FORWARD policies temporarily set to `accept`**. The LOG rules (I8, F14) then log everything that *would* be blocked, without blocking anything.<br>2. Watch the logs (`journalctl -k \| grep -E "IN-DROP\|FWD-DROP"`) during a day of normal activity. |
| **Validation** | Every log line is analysed: is it a forgotten legitimate flow (add a rule) or a flow to block (do nothing)? No legitimate business flow in the logs = Go. |
| **Rollback** | `nft flush ruleset` (back to the original state). |

### Step 5: firewall in blocking mode

| | |
|---|---|
| **Actions** | 1. **Arm the dead man's switch**: `echo "nft -f /root/backup/nft.rules" \| at now + 10 minutes`. If access is lost, the old ruleset is restored automatically.<br>2. Set the INPUT and FORWARD policies to `drop`, reload the ruleset.<br>3. **Open a new SSH session via the VPN** (keep the old one open).<br>4. If everything works: disarm with `atrm <job>`. |
| **Validation** | SSH via VPN: OK. SSH from the WAN: timeout. From outside, `nmap` on the WAN IP no longer shows 21 or 22. Accountants: FTP through the old path still works until step 7 (temporary rule if needed). |
| **Rollback** | Automatic after 10 minutes if access is lost. Manual: `nft -f /root/backup/nft.rules` from the console. |

### Step 6: VLAN segmentation

Migration **zone by zone**, starting with the least critical: Guest → Office → Finance → Database. One zone at a time.

| | |
|---|---|
| **Actions (per zone)** | 1. Create the sub-interface (`eth2.30` etc.) with the gateway IP `10.50.X.1/24`, then the corresponding DHCP scope.<br>2. On the switch: create the VLAN, tag it on the trunk port towards `eth2`.<br>3. Move **a single test workstation** into the VLAN. Check: IP obtained, Internet access, and refused accesses (e.g. Guest → `10.50.50.50` fails).<br>4. Move the other workstations.<br>5. **Database last**: assign `10.50.50.50` statically, update `db.conf` and the business workstations' configuration, test the application. |
| **Validation** | For each zone, test the allowed **and** refused accesses of FIREWALL_POLICY. Guest: Internet OK, everything else KO. Office/Finance: Internet OK, DB OK on its port, DB KO on other ports. |
| **Rollback** | Put the affected switch ports back in the old flat VLAN. Workstations get their old address back. The other zones are not touched. |

### Step 7: FTP migration to the DMZ

| | |
|---|---|
| **Actions** | 1. Install the new server `10.50.60.40` (VLAN 60) with the hardened vsftpd configuration (VPN_DESIGN §8.4).<br>2. Copy the existing accounts and files.<br>3. Generate the accountants' WireGuard configurations (`10.8.0.100+`), then send them with a step-by-step guide.<br>4. **Pilot**: a single accountant tests VPN + upload + Finance retrieves the file.<br>5. Switch all accountants over.<br>6. Stop and disable the gateway's vsftpd (do not uninstall it for 2 weeks). |
| **Validation** | Accountant via VPN: upload OK. Finance: retrieval OK. From the Internet: port 21 of the WAN IP closed. From the DMZ: `curl` to the Internet or to `10.50.20.x` fails (F4). |
| **Rollback** | Re-enable the gateway's vsftpd and its temporary rule; accountants go back to the old address. Files uploaded in the meantime are copied back from `10.50.60.40`. |

### Step 8: OUTPUT to DROP

| | |
|---|---|
| **Actions** | 1. Analyse the traffic sent by the gateway during the previous steps, then complete O1 to O6 if needed (syslog collector address).<br>2. Arm the dead man's switch (as in step 5).<br>3. Set the OUTPUT policy to `drop`. |
| **Validation** | `apt update` OK, DNS resolution OK, NTP synchronised, DHCP served, VPN and SSH OK. No unexpected `OUT-DROP` for 24 h. |
| **Rollback** | Set the OUTPUT policy back to `accept`. |

### Step 9: persistence and monitoring

| | |
|---|---|
| **Actions** | 1. **Remove `nft flush ruleset` from `/etc/run.sh`**: otherwise the whole firewall disappears at the next boot (cause of finding D6).<br>2. Save the ruleset in `/etc/nftables.conf` and load it at boot.<br>3. Enable WireGuard at boot.<br>4. **Suricata (D10)**: remove the fake `fast.log` write from `run.sh`, configure Suricata on `eth1` and actually start it.<br>5. Export the logs (firewall, SSH, FTP, Suricata) to the remote collector (MON-03). |
| **Validation** | **Test reboot** within the maintenance window: after restart, `nft list ruleset` shows the rules, `wg show` shows the interface, Suricata is running (`ps aux`), logs arrive at the collector. |
| **Rollback** | Restore `run.sh` from the backup. The firewall is no longer persistent again, but access is preserved. |
