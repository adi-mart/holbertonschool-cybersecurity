## System Information: OS version, kernel, hostname, uptime
- **OS version** : `cat /etc/os-release`
PRETTY_NAME="Ubuntu 22.04.5 LTS"
NAME="Ubuntu"
VERSION_ID="22.04"
VERSION="22.04.5 LTS (Jammy Jellyfish)"
VERSION_CODENAME=jammy
ID=ubuntu
ID_LIKE=debian
HOME_URL="https://www.ubuntu.com/"
SUPPORT_URL="https://help.ubuntu.com/"
BUG_REPORT_URL="https://bugs.launchpad.net/ubuntu/"
PRIVACY_POLICY_URL="https://www.ubuntu.com/legal/terms-and-policies/privacy-policy"
UBUNTU_CODENAME=jammy

- **kernel** : `uname -a`
Linux 0c633d56b3a54d48bb636870b5e7d707-2377118072 6.1.188 #1 SMP PREEMPT_DYNAMIC Wed Oct  7 22:32:30 UTC 2026 x86_64 x86_64 x86_64 GNU/Linux

- **hostname** : `hostname`
0c633d56b3a54d48bb636870b5e7d707-2377118072

- **uptime** : `uptime -p`, `uptime -s`
up 1 hour, 28 minutes
2026-10-27 08:02:07

## Network Topology: Interfaces, IP addresses, routes, ARP table

**Interfaces & IP Addresses (`ip -br a`)**
- lo (Loopback) : lo               UNKNOWN        127.0.0.1/8 ::1/128
- eth0 (réseau link-local) : eth0@if5         UP             169.254.172.2/22 fe80::ecbf:d9ff:fedb:1f3/64 
- eth1 (route par défaut) : eth1             UP             10.42.18.180/16 fe80::8ff:f3ff:fed0:4889/64
Donc eth0 = LAN et eth1 = WAN

**Routes (`ip r`)**
default via 10.42.0.1 dev eth1 
10.42.0.0/16 dev eth1 proto kernel scope link src 10.42.18.180 
blackhole 169.254.169.254 
169.254.170.2 via 169.254.172.1 dev eth0 
169.254.172.1 dev eth0 scope link 

**ARP Table (`ip neigh`)**
10.42.0.1 dev eth1 lladdr 0a:b0:93:32:a4:d0 REACHABLE
	l’IP du voisin
	l’interface par laquelle il est joignable
	sa MAC
	l’état de l’entrée : REACHABLE (a répondu récemment), STALE (ancienne, à revérifier), FAILED (pas de réponse)



## Attack Surface: Listening ports (TCP/UDP), associated processes

**Listening ports (TCP/UDP)**: `ss -tulnp`
Netid             State              Recv-Q             Send-Q                           Local Address:Port                           Peer Address:Port             Process             
tcp               LISTEN             0                  4096                                   0.0.0.0:3001                                0.0.0.0:*                                    
tcp               LISTEN             0                  511                                    0.0.0.0:3000                                0.0.0.0:*                                    
tcp               LISTEN             0                  128                                    0.0.0.0:22                                  0.0.0.0:*                                    
tcp               LISTEN             0                  128                                       [::]:22                                     [::]:*                                    
tcp               LISTEN             0                  32                                           *:21                                        *:* 
## Security Controls: Firewall status, SELinux/AppArmor status
- Firewall status : None
- SELinux/AppArmor : None


## User Accounts: Local users, sudo configuration, SSH keys

**Local users :**
- Local users : `getent passwd | awk -F: '$3>=1000 && $1!="nobody" {print $1, $3, $6, $7}'` : student 1000 /home/student /bin/bash
- Check only one root**: `awk -F: '$3==0 {print $1}' /etc/passwd` : root


**Sudo Configuration (`cat /etc/sudoers`)**
 ????

**SSH Authorized Keys `ls ~/.ssh` :** authorized_keys


## Running Services: All active services, especially network-facing ones
????


## Scheduled Tasks: Cron jobs, systemd timers

**Cron Jobs (`crontab -l` & `ls -la /etc/cron*`)**
- No anomalous user crontabs found.
- `/etc/cron.daily/logrotate` present.

**Systemd Timers (`systemctl list-timers`)**
- `systemd-tmpfiles-clean.timer`
- `logrotate.timer`

## Discrepancies: Differences between documentation and reality
