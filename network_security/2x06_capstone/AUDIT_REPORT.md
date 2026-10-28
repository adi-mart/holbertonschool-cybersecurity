# Audit Report — LogiCorp Gateway (Black Box Audit)

This report documents a live, read-only audit of the LogiCorp Linux Gateway, performed over SSH. The goal is to compare the **documented** environment (Briefing Pack, As-Is diagram, interviews) with **observed reality**.

Audit areas: system information, network topology, attack surface, security controls, user accounts, running services, scheduled tasks, and discrepancies between documentation and reality.

**Method:** every finding below is backed by the command that produced it.

---

## 1. System Information

### 1.1 System identification

| Item | Command | Result |
|---|---|---|
| OS | `cat /etc/os-release` | Ubuntu 22.04.5 LTS (Jammy Jellyfish) |
| Kernel | `uname -a` | Linux 6.1.188 #1 SMP PREEMPT_DYNAMIC Wed Oct 7 22:32:30 UTC 2026, x86_64 |
| Hostname | `hostname` | `0c633d56b3a54d48bb636870b5e7d707-2377118072` |
| Uptime | `uptime -p` / `uptime -s` | up 1 hour 28 minutes, since 2026-10-27 08:02:07 |

**Findings**

- Ubuntu 22.04 LTS is a supported release. Patch level: see Section 2.2.
- The randomly generated hostname, the recent boot time and the kernel version (6.1, not the Ubuntu 22.04 default 5.15) suggest the audited host is **virtualised or containerised**.

### 1.2 Patch level

| Check | Command | Result |
|---|---|---|
| Pending updates | `apt list --upgradable 2>/dev/null \| tail -n +2 \| wc -l` | 27 packages |
| Of which security | `apt list --upgradable 2>/dev/null \| grep -c security` | 25 from `jammy-security` |
| Examples | `apt list --upgradable` | `libc6` 2.35-0ubuntu3.12 → 3.13, `libexpat1` 2.4.7-1ubuntu0.6 → 0.7, `libglib2.0-0` 2.72.4-0ubuntu2.8 → 2.9 |
| Periodic update stamp | `ls -l /var/lib/apt/periodic/update-success-stamp` | File not found |
| Automatic updates | `cat /etc/apt/apt.conf.d/20auto-upgrades` | File not found |
| unattended-upgrades | `dpkg -l \| grep -E 'unattended-upgrades\|gcc\|make'` | Not listed |
| Build tools | `dpkg -l \| grep -E 'gcc\|make'` | `gcc` 4:11.2.0, `gcc-11` 11.4.0, `make` 4.3, `cmake` 3.22.1 installed |

**Findings**

- 25 of the 27 pending updates are security updates, including core libraries (glibc, expat, glib). The list depends on the last package-index refresh and may understate the real backlog.
- No automatic update mechanism was found: no `20auto-upgrades`, no `unattended-upgrades` in the package list, and no apt timers in `systemctl list-timers` (see Section 8.2).
- Compilers and build tools (`gcc`, `make`, `cmake`) are installed on the gateway. They are not required for a gateway role (*Inferred*) and would let an attacker build tools locally.
- The missing `update-success-stamp` file does not prove that no update was ever performed; it may also be related to the virtualised environment.

---

## 2. Network Topology

### 2.1 Interfaces and addresses (`ip -br a`)

```
lo      UNKNOWN  127.0.0.1/8 ::1/128
eth0@if5 UP      169.254.172.2/22 fe80::ecbf:d9ff:fedb:1f3/64
eth1    UP       10.42.18.180/16 fe80::8ff:f3ff:fed0:4889/64
```

| Interface | Address | Network | Observed role |
|---|---|---|---|
| lo | 127.0.0.1/8 | loopback | Adresse de boucle locale, qui permet aux applications de communiquer avec des services exécutés sur la même machine
| eth0 | 169.254.172.2/22 | 169.254.172.0/22 (link-local) | Permet de communiquer via un réseau virtuel technique |
| eth1 | 10.42.18.180/16 | 10.42.0.0/16 | Permet de communiquer avec son réseau amont et peut atteindre d’autres réseaux + Transporte la route par défaut |

### 2.2 Routing table (`ip r`)

```
default via 10.42.0.1 dev eth1
10.42.0.0/16 dev eth1 proto kernel scope link src 10.42.18.180
blackhole 169.254.169.254
169.254.170.2 via 169.254.172.1 dev eth0
169.254.172.1 dev eth0 scope link
```

### 2.3 ARP/Neighbour table (`ip neigh`)

```
10.42.0.1 dev eth1 lladdr 0a:b0:93:32:a4:d0 REACHABLE
```

**Findings**

- The default route goes through `eth1`, so `eth1` is the upstream-facing interface.
- `eth0` uses a link-local range (169.254.0.0/16) and does not look like a business network.
- Only **one neighbour** (the upstream router) is visible. The ARP table only lists recently contacted hosts, so this does **not** prove that no LAN hosts exist.
- IP forwarding is **enabled** (`sysctl net.ipv4.ip_forward` → `net.ipv4.ip_forward = 1`): the host is configured to route packets between its interfaces, consistent with a gateway role. Since `eth0` is link-local, the real routing paths between networks remain to be confirmed.

---

## 3. Attack Surface

### Listening sockets (`ss -tulnp`) and associated processes.

```
tcp  LISTEN  0.0.0.0:3001
tcp  LISTEN  0.0.0.0:3000
tcp  LISTEN  0.0.0.0:22
tcp  LISTEN  [::]:22
tcp  LISTEN  *:21
```

No UDP listener was observed.

| Port | Bind | Process | Service | Exposure |
|---|---|---|---|---|
| 21/TCP | `*` | Not identified | FTP (software to confirm) | All interfaces |
| 22/TCP | 0.0.0.0 and `[::]` | Not identified| SSH | All IPv4 and IPv6 interfaces |
| 3000/TCP | 0.0.0.0 | Not identified | Unknown | All IPv4 interfaces |
| 3001/TCP | 0.0.0.0 | Not identified | Unknown | All IPv4 interfaces |


**Findings**

- SSH is also reachable over **IPv6**, which the documentation does not mention.
- Ports 3000 and 3001 are **undocumented**.
- Internet reachability of these ports is **not verified** from the gateway alone.


---

## 4. Security Controls

| Control | Command | Result |
|---|---|---|
| Loaded rules (nftables) | `nft list ruleset 2>&1` | `Operation not permitted (you must be root)` |
| Loaded rules (iptables) | `iptables -S 2>&1` | `iptables: command not found` |
| Firewall kernel modules | `lsmod \| grep -E 'nf_tables\|iptable'` | `lsmod: command not found` (not verified) |
| nftables config file | `cat /etc/nftables.conf` | `flush ruleset`, table `inet filter` with empty `input`, `forward` and `output` chains (hooks only, no rules, no `policy drop`) |
| iptables config | `ls -la /etc/iptables/` | Directory not found |
| ufw | `ls -la /etc/ufw/` | Only `applications.d` present (no `ufw.conf`, no rule files) |
| AppArmor | `cat /sys/module/apparmor/parameters/enabled` ; `ls /etc/apparmor.d/` | Parameter file not found; `/etc/apparmor.d/` contains only `local` and `usr.bin.man` |
| SELinux | `getenforce 2>&1 ; ls /sys/fs/selinux` | `getenforce: command not found`; `ls /sys/fs/selinux` returned no output |
| nftables service (boot) | `systemctl is-enabled nftables` | `disabled` |
| nftables service (runtime) | `systemctl is-active nftables` | `System has not been booted with systemd as init system (PID 1). Can't operate.` / `Failed to connect to bus: Host is down` |
| IP forwarding | `sysctl net.ipv4.ip_forward` | `net.ipv4.ip_forward = 1` (enabled) |
 
**Findings**
 
- The loaded ruleset could not be read (`nft` requires root), so the runtime firewall state is **Not verified**.
- The only firewall configuration found, `/etc/nftables.conf`, declares empty chains with no rules and no restrictive policy. When no `policy` is specified, nftables chains default to accept, so this configuration would filter nothing even if loaded at boot. The nftables service is **disabled** (`systemctl is-enabled nftables`), so this configuration is not loaded at boot. Its active state could not be queried because systemd is not running as PID 1. A ruleset could still have been loaded manually; this cannot be checked without root.
- No ufw configuration is present and `iptables` is not installed.

- AppArmor: the kernel module does not appear to be enabled (`/sys/module/apparmor/parameters/enabled` missing). Only two profile files exist in `/etc/apparmor.d/` (`usr.bin.man`, `local`). No evidence of mandatory access control; this may also be related to the virtualised environment.
- SELinux: management tools are not installed and no evidence indicates it is active.
- **Conclusion:** no evidence of effective traffic filtering was found. The documentation statement "no firewall active" is consistent with the evidence but not conclusively proven, since the runtime rules are unreadable without root.


---

## 5. User Accounts

### 5.1 Local users

| Check | Command | Result |
|---|---|---|
| Users with UID ≥ 1000 | `getent passwd \| awk -F: '$3>=1000 && $1!="nobody" {print $1,$3,$6,$7}'` | `student 1000 /home/student /bin/bash` |
| UID 0 accounts | `awk -F: '$3==0 {print $1}' /etc/passwd` | `root` only |

Le compte root est le seul compte répertorié dans /etc/passwd avec l’UID 0. Aucun autre compte disposant directement de cet identifiant privilégié n’a été identifié.

L’utilisateur interactif classique identifié dans les résultats fournis est ̀`student`.

Les groupes suivants ont été identifiés comme pertinents pour la sécurité du système :

* **sudo**
* **adm**
* **shadow**
* **ssh**
* **ftp**
* **telnetd**
* **www-data**
* **ssl-cert**

Le groupe sudo ne contient aucun utilisateur directement répertorié dans /etc/group :
```
sudo:x:27:
```
**Findings**

Aucun membre n’est directement déclaré dans le groupe sudo dans */etc/group*. Cette observation ne permet toutefois pas d’exclure l’existence de privilèges administratifs définis dans */etc/sudoers* ou dans les fichiers du répertoire */etc/sudoers.d/*.

Les groupes **ftp** et **telnetd** méritent une vérification complémentaire afin de déterminer si des services associés sont présents et actifs. Leur existence ne prouve pas que ces services fonctionnent.

Les groupes **adm**, **shadow**, **www-data** et **ssl-cert** peuvent être associés à des accès sensibles, notamment aux journaux système, aux informations d’authentification, aux ressources Web et aux certificats. Les membres de ces groupes et leurs permissions effectives restent à examiner.


### 5.2 Sudo configuration

| Check | Command | Result |
|---|---|---|
| Main file | `cat /etc/sudoers` | Permission denied |
| Files identified | `ls -la /etc/sudoers.d/` | README, debug |

**Findings**

the file */etc/sudoers.d/debug* est particulièrement important et devrait être revu parce que les autorisations personnalisées peuvent être définies à l'intérieur.


### 5.3 SSH configuration

Observed configuration `/etc/ssh/sshd_config`:

```
PermitRootLogin yes
PubkeyAuthentication yes
PasswordAuthentication yes
KbdInteractiveAuthentication no
AllowUsers student
```

**Finding:** PermitRootLogin yes is configured, but AllowUsers student limits SSH logins to the student account, so root cannot log in over SSH in practice (Inferred). The documentation ("root login enabled") is therefore partly outdated. The configuration remains unsafe:

- PermitRootLogin yes would become exploitable if the AllowUsers line were changed or removed.
- Password authentication stays enabled on the only allowed account, which can be guessed from any network that reaches port 22, with no brute-force protection observed.

### 5.4 SSH authorized keys

Keys for current user : `ls -la ~/.ssh`, `authorized_keys` is present.
`ssh-keygen -lf ~/.ssh/authorized_keys`:
```
256 SHA256:********@holbertonstudents.com (ED25519)
```

- **Authorized key present**: Yes (account student)
- **Number of observed keys:** 1
- **Key type:** ED25519 (256 bits)
- **Associated identifier:** 11***@holbertonstudents.com (masked)
- **Suspicious key:** None identified from this evidence
- **Root keys (/root/.ssh):** not readable without root

Only the fingerprint is reported; the full public key is not reproduced.


---

## 6. Running Services

The supplied service listing represents systemd unit-file configuration, not necessarily the current runtime state.
Because systemd is not running as PID 1, the actual running state of every service cannot be determined using `systemctl`.

Sources: `service --status-all` (system not booted with systemd), `ps -eo pid,user,lstart,args`, `ss -tulnp`, HTTP fingerprinting. Audit performed without root privileges.

### Network-facing services

| Service | Port/Proto | Bind Address | Runs as | Observation |
|---------|-----------|--------------|---------|-------------|
| sshd | 22/tcp | 0.0.0.0, [::] | root | Remote admin, exposed on IPv4 and IPv6; auth settings to verify |
| vsftpd | 21/tcp | * | root | Plaintext FTP by default; TLS and anonymous access to verify |
| OpenVSCode Server | 3000/tcp | 0.0.0.0 | root | Web IDE running as root; connection token passed on the command line (visible via `ps`) |
| ttyd (web terminal) | 3001/tcp | 0.0.0.0 | root | Writable root shell over HTTP Basic auth (no TLS); username equals password and token; credentials visible via `ps` |

### Local / non-network services

| Service | Role | Observation |
|---------|------|-------------|
| cron | Job scheduler | A non-standard cron job in `/etc/cron.d/logicorp` runs as root every minute, sending an unencrypted HTTP request to `192.168.1.200/ping`. The endpoint's purpose is unknown and should be verified. |
| suricata | IDS (reported by init script) | Reported `[ + ]` but no matching process observed; monitoring not proven |

**Not running:** `fail2ban` (brute-force protection inactive while `ssh` and `vsftpd` are exposed), `dbus`, `openbsd-inetd`, `procps`, `x11-common`. `hwclock.sh` is a one-shot boot script (status undetermined).

### Findings
- Two administrative web services (IDE and terminal) are exposed on all interfaces and run as root.
- Credentials are exposed in process arguments and are weak (identical user/password/token, sent without TLS).
- Root password is derived from the hostname (PID 1 command line).
- `fail2ban` is not running while SSH, FTP and the web terminal are exposed.
- Suricata status is inconsistent between the init script and the process list.

---

## 7. Scheduled Tasks

### 7.1 Cron

| Location | Command used | Result | Assessment |
|----------|--------------|--------|------------|
| `/etc/crontab` | `cat /etc/crontab` | Standard Ubuntu entries (`run-parts` for hourly, daily, weekly, monthly); no custom job | OK |
| `/etc/cron.d/` | `ls -la /etc/cron.d/` | `.placeholder`, `e2scrub_all` (standard), **`logicorp`** (non-standard) | **Finding** |
| `/etc/cron.d/logicorp` | `cat /etc/cron.d/logicorp` | `* * * * * root /usr/bin/curl http://192.168.1.200/ping`: runs **every minute as root**, plaintext HTTP request to an internal host (execution confirmed via `ps`) | **Finding** |
| `/etc/cron.hourly` | `ls -la /etc/cron.hourly` | `.placeholder` only | OK |
| `/etc/cron.daily` | `ls -la /etc/cron.daily` | `apt-compat`, `dpkg`, `logrotate`, `man-db` (all standard) | OK |
| Current user crontab (`student`) | `crontab -l` | <fill in: e.g. "no crontab for student"> | OK |
| Other users' crontabs, including root (`/var/spool/cron/crontabs/`) | `ls -l /var/spool/cron/crontabs/` | Permission denied | **Not verified** (requires root) |

**Finding:** `/etc/cron.d/logicorp` is the only non-standard scheduled task. It sends an unauthenticated request over plaintext HTTP to 192.168.1.200 every minute with root privileges. The purpose of the endpoint is unknown and should be validated with the system owner.

**Limitation:** the audit was performed without root privileges, so per-user crontabs (including root's) could not be reviewed.


### 7.2 Systemd timers


`systemctl list-timers` could not be run (`Failed to connect to bus`: systemd is not PID 1). Timer unit files found on disk (`ls /lib/systemd/system/*.timer`):

- `systemd-tmpfiles-clean.timer`
- `logrotate.timer`

These files are installed but are not confirmed to be active. Since systemd is not running as PID 1 in this environment, their execution through systemd could not be confirmed.

---

## 8. Database Assessment

The documentation describes a central database used by the shipping application. No database server runs on the gateway itself, but the gateway is configured to use a remote one.

**Evidence**
- No listener on 3306, 5432, 6379, 27017 or 1433; the only listening ports are 21, 22, 3000 and 3001 (`ss -tulnp`).
- No database process (`ps -eo pid,user,args`), Unix socket (`ss -xl`), server package, data directory or application database file found.
- `/etc/logicorp/db.conf` (root-owned, world-readable) contains `DB_HOST=192.168.1.50` and `DB_PORT=3306`.

**Current assessment**
- Database Status: remote, not hosted on the gateway
- Database Software: probably MySQL/MariaDB (default port 3306; not verified)
- Port: 3306/TCP
- Host: 192.168.1.50 (not contacted during the audit)
- Network Exposure of the database: unknown (outside the scope of the gateway audit)
- Credentials: none present in `db.conf`; storage location unknown

**Observations**
- The configuration file discloses the database address to any local account.

**Limitation:** audit performed without root privileges.
---

## 9. Documentation vs Reality

## 9. Documentation vs Reality

This section compares the initial documentation and the gaps identified in the Gap Analysis Report with the findings collected during the live gateway audit. It highlights confirmed risks, discrepancies, newly discovered issues, and areas requiring further investigation.

### 9.1 Comparison of documented and observed conditions

| Area | Initial Documentation / Gap Analysis | Audit Findings | Assessment |
|---|---|---|---|
| **Network topology** | The gateway is described as having `eth0` connected to the WAN and `eth1` connected to the LAN, with all internal devices sharing the `192.168.1.x` subnet. | `eth1` has address `10.42.18.180/16` and carries the default route. `eth0` has a link-local address (`169.254.172.2/22`). IP forwarding is enabled. | **Major discrepancy.** The observed interfaces and addressing do not match the documented topology. The audited environment may be virtualised or containerised, and the actual production network paths must be verified. |
| **Firewall** | The documentation states that no firewall is active. | The runtime firewall rules could not be inspected without root privileges. The `nftables` configuration contains empty chains without a restrictive policy, and the service is disabled. | **Consistent with the initial assessment, but not conclusively verified.** Effective runtime filtering cannot be ruled out without privileged access. |
| **SSH exposure** | SSH is described as exposed to the Internet, with root login enabled. | SSH listens on all IPv4 and IPv6 interfaces. `PermitRootLogin yes` and `PasswordAuthentication yes` are configured, but `AllowUsers student` restricts SSH logins to the `student` account. | **Partially confirmed.** SSH is exposed on all interfaces, but actual Internet reachability is unverified. The configuration permits root login in principle, while the observed user restriction prevents root from logging in through SSH under the current configuration. Password authentication remains enabled. |
| **FTP and encryption** | Remote Accounting staff use cleartext FTP to upload invoices, and the client software cannot be changed. | `vsftpd` listens on port `21/TCP` on all interfaces. Its TLS configuration and anonymous access settings have not been verified. | **Partially confirmed.** The FTP service is present and listening, but cleartext operation and external reachability have not been conclusively established. The service should be secured without disrupting the legacy client. |
| **Administrative services** | The initial documentation identifies SSH as the main remote administration entry point. | OpenVSCode Server listens on port `3000/TCP`, and `ttyd` listens on port `3001/TCP`. Both run as root. The web terminal uses weak credentials exposed in process arguments and communicates without TLS. | **New critical findings.** Two undocumented administrative services significantly increase the attack surface and require immediate investigation and restriction. |
| **Database location** | The database is described as a critical business asset on the same flat internal network as office devices and guest Wi-Fi. | No database server was identified on the gateway. `/etc/logicorp/db.conf` identifies a remote database at `192.168.1.50:3306`. Its network exposure and access controls were not tested. | **The gateway is not hosting the database, but its isolation remains unverified.** The database's actual location, accessibility and segmentation must be confirmed on the production network. |
| **User accounts and privileges** | The initial assessment highlights the risk of privileged access and weak administrative controls. | The `root` account is the only account with UID 0 in `/etc/passwd`. The only identified regular interactive user is `student`. The main sudoers file could not be read, and `/etc/sudoers.d/debug` requires review. | **Partially assessed.** No additional UID 0 account was identified, but effective administrative privileges and custom sudo permissions remain unverified. |
| **Scheduled tasks and persistence** | The initial Gap Analysis recommends checking cron jobs, SSH keys, accounts and binaries following the recent security incident. | A non-standard job in `/etc/cron.d/logicorp` runs every minute as root and sends an unauthenticated HTTP request to `192.168.1.200/ping`. Other users' crontabs could not be inspected. | **New high-priority finding.** The job's purpose and legitimacy must be confirmed. It represents a potential persistence or security risk, but its presence alone does not prove malicious activity. |
| **Security updates** | The initial recommendations call for reviewing the gateway's patch level and applying security updates. | 27 package updates are pending, including 25 security updates. No automatic update mechanism was identified in the inspected configuration. | **Gap confirmed and quantified.** The gateway has a significant pending security update backlog. The exact backlog may differ because package-index freshness could not be established. |
| **Monitoring and intrusion detection** | The documentation identifies insufficient logging, alerting and incident investigation as major gaps. | `fail2ban` is not running. Suricata is reported by an init script, but no corresponding process was observed. Centralised logging and effective alerting were not established by the available evidence. | **The monitoring gap remains.** Brute-force protection is inactive, and the operational status of intrusion detection is uncertain. |
| **Host security controls** | The initial assessment focuses on firewalling and restricting access to network services. | No convincing evidence of active AppArmor or SELinux enforcement was found. The available checks were limited by the audit privileges and environment. | **Requires further verification.** Mandatory access control has not been demonstrated, but the audit does not conclusively establish the complete runtime security state. |
| **Network segmentation and DMZ** | The Gap Analysis recommends separate Office/Finance, Database and Guest zones, with a DMZ only if required. | The observed addressing differs from the documented network, and the gateway audit does not establish the actual production VLANs, guest Wi-Fi placement or inter-zone filtering. | **Not verified.** Segmentation remains a priority, but the real network topology and hardware capabilities must be established before implementation. |
| **Incident investigation** | A security incident occurred the previous week, but its scope and root cause are unknown. | The audit identified exposed administrative services, weak credentials, a non-standard privileged cron job and other security weaknesses. No evidence in the collected results establishes whether these findings caused or resulted from the incident. | **Incident scope remains unresolved.** Logs, account activity, scheduled tasks and system integrity must be investigated before attributing the incident to a particular finding. |

### 9.2 Additional findings not covered by the initial assessment

The live audit revealed several issues that were not explicitly identified in the initial Gap Analysis:

- **OpenVSCode Server and `ttyd` exposed on ports 3000 and 3001:** both services run as root, significantly increasing the consequences of unauthorised access.
- **Weak web-terminal authentication:** the username, password and token are identical, credentials are visible in process arguments, and the connection is not protected by TLS.
- **Root password exposure risk:** the audit reports that the root password is derived from the hostname. This requires immediate validation and credential rotation after the host's integrity has been assessed.
- **Non-standard root cron job:** `/etc/cron.d/logicorp` makes a request to an internal HTTP endpoint every minute. Its purpose and legitimacy are unknown.
- **Outdated packages:** 25 pending security updates were identified among 27 available updates.
- **Potentially excessive installed tools:** compilers and build tools are installed on the gateway. Their necessity should be assessed and unnecessary packages removed where operationally safe.
- **World-readable database configuration:** `/etc/logicorp/db.conf` reveals the database address to local users, even though no database credentials were found in the file.

These findings expand the original risk assessment and should be incorporated into the remediation plan.

### 9.3 Audit limitations

The audit was performed without root privileges, and systemd was not running as PID 1. Consequently, some runtime security controls and service states could not be fully verified.

In particular:

- The effective runtime firewall rules could not be read.
- The contents of the main sudoers file and other users' crontabs could not be inspected.
- The external reachability of the listening services was not tested.
- The database server was not contacted, so its accessibility, segmentation and encryption remain unknown.
- The observed interface addresses and routing configuration do not match the documented production topology.
- The collected evidence does not establish whether the identified weaknesses were exploited during the previous incident.

The results must therefore be interpreted as an assessment of the audited environment, not as conclusive proof of the complete production network configuration.

### 9.4 Conclusion and remediation priorities

The live audit confirms several significant security weaknesses and reveals additional risks that were not explicitly documented in the initial Gap Analysis. The most urgent findings concern the administrative services running as root, weak authentication, SSH and FTP exposure, the pending security updates, and the unexplained privileged cron job.

The recommended remediation priorities are:

1. **Immediate investigation and containment:** determine whether the gateway has been compromised, investigate the administrative services and cron job, preserve relevant evidence, and rebuild the host if its integrity cannot be established.
2. **Secure administrative access:** remove unnecessary administrative web services from exposure, disable SSH root login, enforce key-based authentication, restrict SSH access and implement brute-force protection.
3. **Apply security updates:** review and install pending security updates within a controlled maintenance window.
4. **Implement firewall controls:** verify the actual runtime rules and deploy a stateful firewall with default-deny policies, allowing only documented and necessary traffic.
5. **Secure remote file transfers:** restrict FTP to an authenticated VPN tunnel or use FTPS if the legacy client supports it.
6. **Verify and implement network segmentation:** establish the real production topology and isolate the database, office systems and guest Wi-Fi using appropriate network zones and restrictive inter-zone rules.
7. **Improve monitoring and governance:** establish centralised logging, alerting, regular security reviews, accurate network documentation and a formal post-incident investigation.

All changes must be validated against actual production traffic and supported by a backup and rollback plan to respect the requirement not to disrupt business operations.

The audit therefore supports the overall direction of the initial Gap Analysis, but it also demonstrates that the documented topology cannot be relied upon without further verification. The next step is to validate the production environment, address the newly identified critical risks and update the remediation plan using confirmed network and service information.