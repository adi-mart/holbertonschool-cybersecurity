# VPN DESIGN: LogiCorp Gateway

## 1. Objectives

| Need | Gap covered |
|---|---|
| Remote accountants upload their invoices over FTP **without changing their software** | ACC-05, ENC-01 (business constraint) |
| Administrators manage the gateway and the servers without exposing SSH to the Internet | ACC-02, ACC-03 |
| A single encrypted and authenticated entry point from the Internet | ENC-02 |

## 2. Technology choice: WireGuard

| Criterion | WireGuard | OpenVPN |
|---|---|---|
| Attack surface | ~4,000 lines of code, built into the Linux kernel | Very large, depends on OpenSSL |
| Exposure | Silent: answers no packet without a valid key, invisible to scans | Answers TLS handshakes |
| Cryptography | Modern and fixed (Curve25519, ChaCha20-Poly1305), no negotiation to get wrong | Configurable, hence a risk of weak cipher suites |
| Configuration | One file per peer, a few lines | Full PKI (CA, certificates, CRL) |
| Limits | No native MFA, no user directory | MFA and LDAP possible |

**Decision: WireGuard.** For an SME that has had no dedicated security administrator for 10 years, simplicity reduces the risk of misconfiguration. The lack of MFA is handled in §7.

## 3. Topology

**Remote-access hub-and-spoke** topology: each client connects to the gateway, and clients do not communicate with each other.

```
   Accountant (home)           Admin (home / on-call)
   192.168.1.x (router)        any network
          │                            │
          │  UDP 51820 encrypted       │  UDP 51820 encrypted
          └──────────┐      ┌──────────┘
                     ▼      ▼
              eth1 (WAN) ── LogiCorp gateway
                     wg0 = 10.8.0.1/24
                     │
        ┌────────────┼──────────────────────┐
        ▼            ▼                      ▼
   FTP 10.50.60.40   Gateway :22      DB 10.50.50.50:22
   (DMZ, VLAN 60)    (admins)         FTP 10.50.60.40:22 (admins)
      ▲
      └── accountants only
```

There is no site-to-site VPN: LogiCorp has only one site.

## 4. Addressing

VPN subnet: **`10.8.0.0/24`**, interface `wg0`.

Subnet choice:
- outside the internal space `10.50.0.0/16`;
- outside the lab network `10.42.0.0/16`;
- outside the ranges of home routers (`192.168.0.x`, `192.168.1.x`), otherwise an accountant's workstation could not tell whether `192.168.1.10` is their printer or a LogiCorp machine.

| Range | Use |
|---|---|
| `10.8.0.1` | Gateway (`wg0`) |
| `10.8.0.10 – 10.8.0.19` | Administrators (10 peers max) |
| `10.8.0.100 – 10.8.0.149` | Accountants (50 peers max) |
| rest | Reserved |

Each peer has a **fixed IP**, tied to its public key (`AllowedIPs = 10.8.0.x/32` on the server side). WireGuard rejects any packet from the tunnel whose source IP does not match the key that encrypted it. **An accountant therefore cannot spoof an admin IP**: this is what makes the firewall rules based on ranges reliable (I5, F9, F10, F13).

## 5. Access control (who accesses what)

| Group | VPN IP | Allowed access | Rules | Everything else |
|---|---|---|---|---|
| Accountants | `10.8.0.100–149` | FTP `10.50.60.40`: TCP 21 + 30000–30100 | F9, F10 | DROP |
| Administrators | `10.8.0.10–19` | Gateway TCP 22; DB and FTP TCP 22 | I5, F13 | DROP |

No VPN user reaches the Office, Finance or Guest zones, nor the Internet through the tunnel.

## 6. Split tunnel

**Decision: split tunnel.** Only traffic destined for LogiCorp goes through the tunnel:

| Peer | `AllowedIPs` (client side) |
|---|---|
| Accountant | `10.50.60.40/32` |
| Administrator | `10.8.0.1/32, 10.50.50.50/32, 10.50.60.40/32` |

| | Split tunnel (chosen) | Full tunnel |
|---|---|---|
| User's personal browsing | Goes through their own router | Goes through LogiCorp (bandwidth, responsibility) |
| What the workstation can reach through the tunnel | Only the necessary IPs | Everything, filtered by the firewall |
| Risk | The workstation is connected to the Internet and to the tunnel at the same time | Less bridging risk, but load and complexity |

The firewall applies least privilege anyway (§5). `AllowedIPs` is a **second layer**: even if a firewall rule were too broad, the client would send nothing else into the tunnel.

## 7. Authentication and key management

- **One key pair per person and per device.** Never a shared key: each connection is attributable (fixes the lack of traceability in ACC-03).
- **Pre-shared key (PSK)** per peer in addition: defence against a future break of Curve25519 (post-quantum).
- The private key is generated **on the client's workstation** and never leaves it. Only the public key is sent to the admin.
- **Revocation**: remove the `[Peer]` block on the gateway, then `wg syncconf`. Immediate effect. To be done on the day an employee leaves or a device is lost.
- **Quarterly review** of active peers (`wg show`: last handshake date). A peer inactive for more than 90 days is removed.
- **No native MFA** (a WireGuard limitation). Compensating measures:
  - admin peers: the VPN key **and** an SSH key are required (two separate secrets);
  - accountant peers: the VPN key **and** the FTP login are required; access is limited to a single server.
  - Possible evolution: an MFA portal in front (e.g. firezone, netbird). Out of scope for this week.

Server configuration (excerpt):

```ini
[Interface]
Address    = 10.8.0.1/24
ListenPort = 51820
PrivateKey = <server private key>

# Admin - J. Dupont - laptop
[Peer]
PublicKey    = <public key>
PresharedKey = <PSK>
AllowedIPs   = 10.8.0.10/32

# Accounting - M. Martin - home PC
[Peer]
PublicKey    = <public key>
PresharedKey = <PSK>
AllowedIPs   = 10.8.0.100/32
```

The server has no `PostUp` with iptables: filtering is handled entirely by the nftables ruleset (FIREWALL_POLICY.md), to have a single source of truth.

---

## 8. Legacy App: FTP

### 8.1 Constraint

The remote accountants use software that **only speaks FTP** and **cannot be modified**. FTP sends credentials and files **in cleartext**. Exposed on the Internet (current situation, D5), any intermediary can read the invoices and replay the passwords.

### 8.2 Approach: tunneling

The software is kept as is, but it no longer sees the Internet: it talks to `10.50.60.40`, an address that is reachable **only inside the WireGuard tunnel**.

```
Accounting software ──cleartext FTP──► wg0 (client) ══ ChaCha20 encrypted ══► wg0 (gateway) ──cleartext FTP──► FTP 10.50.60.40
     (workstation)                                         Internet                                            (DMZ)
```

- On the Internet, only encrypted UDP 51820 is visible: ENC-01 is fixed on the most exposed segment.
- The FTP server is no longer reachable from the WAN (F3, and no DNAT).
- The only change on the user side: enable the VPN, then enter `10.50.60.40` as the server address.

**Why not FTPS or SFTP?** SFTP is a different protocol that the software does not support. FTPS depends on client support, which is unknown at this stage. The tunnel works whatever the client. If the software supports FTPS, it is enabled **in addition** (defence in depth).

### 8.3 Why in the DMZ

FTP is an old, cleartext protocol, and the server **receives files from the outside**, potentially booby-trapped. It is the service most likely to be compromised. It is therefore isolated in the DMZ: if it is compromised, rule **F4** prevents it from initiating any connection to Office, Finance, the Database or the Internet. The attacker can neither pivot (lateral movement) nor exfiltrate.

### 8.4 vsftpd server hardening

| Parameter | Value | Reason |
|---|---|---|
| `listen_address` | `10.50.60.40` | Listens only on its DMZ interface (today: `0.0.0.0`, audit §3) |
| `anonymous_enable` | `NO` | No access without an account |
| `chroot_local_user` | `YES` | Each accountant is locked into their own directory |
| `pasv_enable` / `pasv_min_port` / `pasv_max_port` | `YES` / `30000` / `30100` | Fixed passive range, matches F10/F11 |
| `port_enable` | `NO` | Active mode disabled: the server does not initiate connections (consistent with F4) |
| `userlist_enable` + `userlist_deny=NO` | allowlist | Only the listed accountant accounts can log in |
| `xferlog_enable` / `log_ftp_protocol` | `YES` | Traceability of uploads and downloads |

Uploaded files are scanned by antivirus (ClamAV) before Finance retrieves them.

### 8.5 Residual risk acceptance

| Item | Content |
|---|---|
| **Residual risk** | FTP remains in cleartext **between the gateway and the server** (VLAN 60) and between the server and Finance (F11). An attacker already present on the gateway or in the DMZ could read credentials and invoices. A compromised accountant workstation passes its booby-trapped files through the tunnel |
| **Likelihood** | Low: the gateway or the DMZ must be compromised first, and both are hardened and logged |
| **Impact** | High: financial data, FTP credentials |
| **Compensating measures** | Encrypted tunnel over the Internet; FTP isolated in the DMZ with no outbound connection (F4); VPN access limited to the accounting group (F9, F10); chroot + allowlist; FTP and firewall logs; antivirus on uploads; FTP credentials distinct from any other password |
| **Risk owner** | LogiCorp management (CEO), on the security team's recommendation |
| **Review date** | 6 months after deployment, or immediately in case of an incident |
| **Exit plan** | Ask the software vendor for FTPS/SFTP support; failing that, evaluate a replacement. As soon as an encrypted protocol is available: enable it, then close cleartext TCP 21 |
