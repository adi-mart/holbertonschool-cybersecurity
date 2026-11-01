# AUDIT_REPORT.md — LogiCorp Gateway
 
Black-box audit of the LogiCorp Linux gateway, performed live and read-only over SSH. Goal: compare the **documented** environment (briefing pack, As-Is diagram, interviews) with the **observed** reality.
 
Structure per section: what the documentation claims / what was found (with the command that produced it) / verdict.
 
## Scope & method
 
Audit conducted as the `student` user, without root privileges (root out of scope: not mentioned in the brief, and discovered as a vulnerability — see section 5).
 
The target is a **container** hosted on AWS/ECS, not a classic VM: kernel shared with the host, restricted system capabilities, no systemd. This limits some checks (firewall, AppArmor), marked "not verifiable live".
 
Throughout the report, a distinction is made between:
 
- the **LogiCorp scenario** (what is planted for the exercise, to be audited);
- the **lab infrastructure** (the host provider's plumbing and the school's tools: `eth0`, ttyd, openvscode-server), out of scope but flagged.
 
Evidence is labelled *Observed* (a command shows it) or *Inferred* (deduced from observations). Interface addresses and hostnames change between container sessions (an earlier run showed `10.42.18.180/16` on `eth1`); the values below come from the latest run.
 
**Limitations.** The runtime firewall ruleset, `/etc/sudoers`, `/root/.ssh/` and other users' crontabs are not readable without root. External reachability of the listening ports was not tested from outside, and the remote database host was never contacted.
 
---
 
## 1. System Information
 
**Doc:** the brief specifies neither the OS nor the kernel. No reference to compare against — inventory only.
 
**Found:**
 
| Item | Command | Result |
| --- | --- | --- |
| OS | `cat /etc/os-release` | Ubuntu 22.04 (jammy) |
| Kernel | `uname -a` | Linux 6.1.188 (host kernel, shared by the container) |
| Hostname | `hostname` | ECS task identifier (`d70f...-...`) |
| Uptime | `uptime` | Container age, not the "gateway" age |
| Pending updates | `apt list --upgradable` | 27 packages, 25 from `jammy-security` (libc6, libexpat1, libglib2.0-0) |
| Automatic updates | `cat /etc/apt/apt.conf.d/20auto-upgrades`; `dpkg -l \| grep unattended` | File not found; package not installed |
 
**Verdict:** inventory recorded. The kernel and hostname belong to the host provider, not the scenario. The patch backlog is real (25 security updates, no automatic mechanism), but may differ from production because the package index freshness is unknown.
 
---
 
## 2. Network Topology
 
**Doc:** Document D (the intern's diagram, flagged "likely wrong"): `eth0` = WAN, `eth1` = LAN. Document C: "FLAT NETWORK, same subnet 192.168.1.x".
 
**Found:** (commands `ip -br a`, `ip r`, `ip route get 1.1.1.1`, `ip neigh`, `sysctl net.ipv4.ip_forward`)
 
| Interface | Address | Observed role |
| --- | --- | --- |
| `lo` | `127.0.0.1/8` | Loopback |
| `eth0` | `169.254.x.x` (link-local, RFC 3927) | No default route: link to the host provider's infrastructure, **not a WAN** |
| `eth1` | `10.42.166.24/16` | Holds the default route (`via 10.42.0.1 dev eth1`): **egress interface (WAN) and local network** |
 
- Egress proven by `curl` and `ip route get 1.1.1.1` (via `10.42.0.1 dev eth1`).
- Real subnet: `10.42.0.0/16`, not `192.168.1.x` (the latter exists on no interface).
- LAN and WAN on the same interface `eth1`: **flat** network, no segmentation.
- Only one neighbour is visible (`10.42.0.1`, the upstream router). The ARP table only lists recent contacts, so this does not prove that no other host exists.
- IP forwarding is enabled (`net.ipv4.ip_forward = 1`): consistent with a gateway role.
- Routes to `169.254.170.2` and a `blackhole 169.254.169.254` are typical of the ECS metadata endpoints (*Inferred*: container).
 
**Verdict:** documentation partly wrong — `eth0`/`eth1` roles reversed, subnet non-existent. However, the "flat" nature of the network is confirmed (and `network.conf` says `NETWORK_MODE=FLAT`).
 
### Remote database dependency
 
**Doc:** the database is a critical business asset on the same flat network as office devices and guest Wi-Fi.
 
**Found:** no database server on the gateway: no listener on 3306, 5432, 6379, 27017 or 1433 (`ss -tulnp`), no database process (`ps -ef`), no database packages or data directories (`dpkg -l`, `ls -ld /var/lib/mysql /var/lib/postgresql`). The LogiCorp configuration files are all readable by any local account (`ls -l /etc/logicorp/`: root-owned, `-rw-r--r--`, dated 12 Feb 2026), and `db.conf` points to a remote database:
 
```
DB_HOST=192.168.1.50
DB_PORT=3306
```
 
- Port 3306 is the MySQL/MariaDB default (*Inferred*; the product was not verified).
- No credentials appear in `db.conf`; where the application stores them is unknown.
- `192.168.1.50` is a different host from the cron target `192.168.1.200` (section 7) and lies in a range the gateway has no interface in.
- The database host was not contacted: its exposure and access controls are out of the scope of this audit.
 
**Verdict:** the database is remote, not hosted on the gateway. Its isolation cannot be assessed from the gateway and relies on the segmentation proposed in the Gap Analysis. The service port (3306) feeds firewall rule F12.
 
---
 
## 3. Attack Surface
 
**Doc:** Document C — SSH open to the whole Internet, FTP in cleartext. No other exposure mentioned.
 
**Found:** 4 listening ports, all on all interfaces, firewall flushed → genuinely reachable. Commands: `ss -tulnp`, `ps -ef --forest` (process identification), `curl -sI http://localhost:<port>` (fingerprinting).
 
| Port | Process | PID | Bind | Category | Documented? |
| --- | --- | --- | --- | --- | --- |
| 22 | sshd | 89 | `0.0.0.0` and `[::]` | LogiCorp scenario | yes (IPv6 not mentioned) |
| 21 | vsftpd | 63 | `*` | LogiCorp scenario | yes |
| 3000 | node → openvscode-server | 105 | `0.0.0.0` | Lab infra | no |
| 3001 | ttyd (web terminal) | 91 | `0.0.0.0` | Lab infra | no |
 
No UDP listener was observed.
 
**Lab infrastructure, flagged but out of scenario:** openvscode-server and ttyd run as root and take their credentials from the command line (visible to any local user with `ps`); the PID 1 command sets the root password from the hostname. These belong to the school's environment, not to the LogiCorp scenario.
 
**Verdict:** SSH and FTP confirmed exposed (SSH also over IPv6). Ports 3000/3001 belong to the lab infrastructure (the school's editor + web console), flagged but out of scenario.
 
---
 
## 4. Security Controls
 
**Doc:** Document C — "No Firewall active". Target: "Default Deny" policy.
 
**Found:**
 
| Control | Command | Result |
| --- | --- | --- |
| Loaded rules | `nft list ruleset` | `Operation not permitted` (root required) |
| Boot behaviour | `cat /etc/run.sh` | Runs `nft flush ruleset` at every boot → no rules |
| nftables config | `cat /etc/nftables.conf` | Table `inet filter` with empty `input`, `forward`, `output` chains and no restrictive policy |
| nftables service | `systemctl is-enabled nftables` | `disabled` |
| Other firewalls | `iptables -S`; `ls /etc/ufw` | `iptables` not installed; no ufw configuration |
| Brute-force protection | `service --status-all` | `fail2ban` not running |
| Intrusion detection | `ps aux`; `service --status-all` | Suricata reported `[ + ]` by the init script, but **no process** |
| AppArmor / SELinux | `aa-status`; `ls /sys/module/apparmor` | AppArmor not installed or exposed; SELinux absent |
| Container capabilities | `capsh --print` | `!cap_net_admin`: no firewall can be loaded even by root |
 
- **Firewall:** the live ruleset cannot be read, but the boot flush and the empty configuration establish the absence of filtering.
- **Suricata:** configuration `/etc/suricata/` and `fast.log` exist, but the IDS is not running and `run.sh` has no startup for it. The `fast.log` is written by hand by `run.sh`, not by the IDS.
- **SELinux / AppArmor:** not verifiable live (container, kernel not controlled).
 
**Verdict:** "No firewall active" confirmed. No real intrusion detection despite appearances. No brute-force protection. No mandatory access control verifiable.
 
---
 
## 5. User Accounts
 
**Doc:** Document C — SSH open, "Root enabled". The internal policy (`security.policy`) says "root login should never happen".
 
**Found:** (commands `cat /etc/passwd`, `cat /etc/ssh/sshd_config`, `ls -la /root/.ssh/`, `ssh-keygen -lf ~/.ssh/authorized_keys`, `ls -la /etc/sudoers.d/`)
 
| Item | Finding | Verdict |
| --- | --- | --- |
| Accounts with a shell | `root` + `student` only | clean |
| Duplicate UID 0 | none | clean |
| `telnetd` account + package | installed (`/usr/sbin/in.telnetd`), service inactive | finding — obsolete leftover, unencrypted, undocumented |
| `PermitRootLogin` | `yes` | finding — confirms the doc, violates `security.policy` |
| `AllowUsers` | `student` | root cannot log in over SSH in practice (*Inferred*); the setting is fragile |
| `PasswordAuthentication` | `yes` | finding — brute-force target, no protection (section 4) |
| `PermitEmptyPasswords` | absent → default `no` | compliant |
| student SSH keys | the 2 intranet keys (ED25519), nothing foreign | clean |
| root SSH keys | `/root/.ssh/` not readable (permission denied) | not verified |
| sudo configuration | `/etc/sudoers` unreadable; `/etc/sudoers.d/` contains `README` and `debug` | to verify — content of `debug` not reviewed, `student`'s sudo rights unknown |
 
**Verdict:** root login confirmed in the configuration (contradicts the internal policy). Telnet finding as a bonus. Accounts otherwise clean; the custom `sudoers.d/debug` file must be reviewed.
 
---
 
## 6. Running Services
 
**Doc:** the brief does not list the services; it describes SSH, FTP and the absence of a firewall. To be cross-checked against reality.
 
**Found:** (commands `ps -ef --forest`, `service --status-all`)
 
- **PID 1 = `/bin/sh -c ...`** (not systemd) → container; all services are started by `/etc/run.sh`. Because systemd is absent, `systemctl` cannot be used and no systemd timer can be active.
- Active: `sshd` (22), `vsftpd` (21), `cron` (77) — LogiCorp scenario; `ttyd` + `openvscode-server` — lab infra.
- The **cron backdoor is visible live**: PIDs 333-338 show the `curl http://192.168.1.200/ping` calls launched by cron, stuck in timeout and piling up every minute.
- Inactive, to flag: Telnet (installed), Suricata (config present, no process), `fail2ban`.
 
**Verdict:** real services inventoried. No systemd (container): expected, not a defect.
 
---
 
## 7. Scheduled Tasks
 
**Doc:** nothing in the brief. But section ACC-06 of the GAP_ANALYSIS expects a search for attacker persistence (cron jobs, keys, backdoors) after the incident.
 
**Found:** (commands `cat /etc/crontab`, `ls -la /etc/cron.d/ /etc/cron.*`, `cat /etc/cron.d/logicorp`, `ps -eo pid,user,lstart,args`)
 
- **Critical finding — cron backdoor**: `/etc/cron.d/logicorp` (root-owned, world-readable, dated 12 Feb 2026) runs, as root and **every minute**:
 
```
  * * * * * root /usr/bin/curl http://192.168.1.200/ping
```
 
  Beacon behaviour ("calling home") typical of a backdoor: unauthenticated plaintext HTTP request to a fixed internal host. The target is not routable from `10.42.x.x` → the request fails, but the mechanism is present and designed for the LogiCorp network (`192.168.1.x`). The response is not piped into a shell, so the line alone does not execute remote code; it still acts as a persistence and command-and-control candidate until explained.
- **Noise discarded**: `/etc/crontab` + `cron.hourly/daily/weekly/monthly` = standard Ubuntu maintenance tasks (`apt-compat`, `dpkg`, `logrotate`, `man-db`).
- **Not verified:** per-user crontabs, including root's (`/var/spool/cron/crontabs/`: permission denied).
 
**Verdict:** persistence backdoor confirmed (illustrates ACC-06). To be removed.
 
---
 
## 8. Discrepancies — Documentation vs Reality
 
The client's diagram (Document D) was announced as unreliable; the audit confirms this and additionally reveals undocumented elements.
 
| # | What the doc says | Reality found | Type |
| --- | --- | --- | --- |
| D1 | `eth0` = WAN, `eth1` = LAN | reversed: `eth1` = egress + LAN, `eth0` = link-local infra link | doc wrong |
| D2 | Subnet `192.168.1.x` | real `10.42.0.0/16`; `192.168.1.x` absent from interfaces | doc wrong (lab env.) |
| D3 | Flat network | confirmed (all on `eth1`, `network.conf` = `NETWORK_MODE=FLAT`) | doc correct |
| D4 | SSH open, root enabled | `PermitRootLogin yes` confirmed and violates `security.policy`; SSH also on IPv6; `AllowUsers student` blocks root in practice | doc partly correct |
| D5 | FTP in cleartext | confirmed (vsftpd:21 active, exposed on all interfaces) | doc correct |
| D6 | No firewall | confirmed (`nft flush` at boot, empty config) | doc correct |
| D7 | — (undocumented) | **cron backdoor** as root every minute to `192.168.1.200` | undocumented |
| D8 | — (undocumented) | **Telnet server** installed (inactive) | undocumented |
| D9 | — (undocumented) | `/etc/logicorp/` files world-readable; `db.conf` reveals the database host and port (`192.168.1.50:3306`) | undocumented |
| D10 | "no IDS" (MON-04) | Suricata config present but **IDS inactive**, logs falsified | doc correct (trap) |
| D11 | Database on the flat network | remote database, not on the gateway; isolation unverified | doc partly confirmed |
| D12 | Patch level to be reviewed (Phase 1) | 25 pending security updates, no automatic updates | gap confirmed |
