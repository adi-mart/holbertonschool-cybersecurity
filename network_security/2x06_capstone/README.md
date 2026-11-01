# LogiCorp Gateway Security Capstone

This project documents and implements a secure redesign of a legacy LogiCorp network gateway under a zero-trust model. The goal is to reduce exposure, isolate critical assets, and protect remote-access flows while preserving business continuity for finance operations that still rely on FTP.

## Project overview

The original environment was a flat network with direct exposure to the Internet, no firewall, weak remote-access controls, and no realistic segmentation. A compromised gateway could pivot to the office, finance, guest, and database segments with little resistance.

This capstone addresses that reality by providing:

- a technical audit of the existing state;
- a gap analysis and risk matrix;
- a hardened architecture based on segmentation, default-deny filtering, and remote VPN access;
- implementation and validation artifacts for the security design;
- a documented enforcement plan to preserve service continuity while reducing risk.

## Business goal

Protect the critical database and internal services while allowing remote finance users to continue using a legacy FTP workflow without exposing the service directly to the Internet.

## Security principles

- Zero trust: no network is trusted by default.
- Least privilege: each user and zone is allowed only the specific flows it needs.
- Default deny: deny all traffic unless a rule explicitly allows it.
- Segmentation: isolate guest, office, finance, database, and DMZ traffic.
- Remote access only through authenticated encrypted channels.
- No root access by default; admin access must be controlled and auditable.

---

## Repository structure

```text
2x06_capstone/
├── README.md
├── AUDIT_REPORT.md
├── GAP_ANALYSIS.md
├── DEFENSE.md
├── DESIGN_PACKAGE/
│   ├── FIREWALL_POLICY.md
│   ├── IMPLEMENTATION_PLAN.md
│   └── VPN_DESIGN.md
├── HARDENING/
│   ├── clean.sh
│   ├── firewall.sh
│   ├── panic_button.sh
│   └── vpn_setup.sh
├── VALIDATION/
│   └── tests.sh
├── 0-flag.txt
├── 1-flag.txt
├── 2-flag.txt
├── 3-flag.txt
├── 4-flag.txt
└── ...
```

## Key documents

- [AUDIT_REPORT.md](AUDIT_REPORT.md): live audit of the existing gateway configuration, risks, and exposed services.
- [GAP_ANALYSIS.md](GAP_ANALYSIS.md): current-state assessment, gaps, risk matrix, and phased remediation plan.
- [DEFENSE.md](DEFENSE.md): answers to architectural objections and explains the final hardening strategy.
- [DESIGN_PACKAGE/FIREWALL_POLICY.md](DESIGN_PACKAGE/FIREWALL_POLICY.md): detailed firewall rules and segmentation logic.
- [DESIGN_PACKAGE/IMPLEMENTATION_PLAN.md](DESIGN_PACKAGE/IMPLEMENTATION_PLAN.md): ordered deployment and rollback plan.
- [DESIGN_PACKAGE/VPN_DESIGN.md](DESIGN_PACKAGE/VPN_DESIGN.md): WireGuard design and access-control model.
- [VALIDATION/tests.sh](VALIDATION/tests.sh): regression checks to validate the hardened state.

---

## Architecture summary

The target state is designed around a segmented, gateway-based architecture with multiple trust zones:

- Internet / WAN: untrusted by default
- VPN: authenticated remote access only
- DMZ: public-facing or risky services such as FTP
- Office VLAN: managed business endpoints
- Finance VLAN: sensitive business workstations
- Database VLAN: restricted access to critical data
- Guest Wi-Fi VLAN: Internet-only access with no internal reachability

### Trust model

- The gateway enforces traffic control between zones.
- Access is granted only by explicit policy.
- The database is not reachable broadly from the flat network.
- Remote administration occurs only over an authenticated VPN path.
- Legacy FTP is moved behind the VPN and isolated in the DMZ instead of being exposed directly to the Internet.

---

## Main hardening objectives

### 1. Remove direct exposure

- no SSH exposed to the entire Internet;
- no FTP exposed to the public network;
- no direct administrative access from untrusted sources.

### 2. Enforce segmentation

- guest traffic cannot reach the office or the database;
- the DMZ cannot initiate arbitrary outbound traffic;
- the database is reachable only by explicitly approved hosts and ports.

### 3. Secure remote access

- administrative access is restricted to VPN peers;
- remote accountants connect through WireGuard and reach the FTP server only through the approved path.

### 4. Remove persistence and weak controls

- eliminate insecure legacy services such as Telnet;
- remove or neutralize suspicious cron-based backdoors;
- enforce key-based SSH access and disable root login.

### 5. Improve observability

- log denied flows;
- keep firewall and access logs under review;
- validate configuration after every change.

---

## Design decisions

### Firewall strategy

The design uses a default-deny model on INPUT and FORWARD, combined with explicit allow rules for trusted traffic. The rules are documented in [DESIGN_PACKAGE/FIREWALL_POLICY.md](DESIGN_PACKAGE/FIREWALL_POLICY.md).

### VPN design

WireGuard is selected as the encrypted remote access mechanism because it is modern, compact, and simpler to manage than a heavier solution. The design is detailed in [DESIGN_PACKAGE/VPN_DESIGN.md](DESIGN_PACKAGE/VPN_DESIGN.md).

### FTP handling

The project respects the business requirement that Finance keep using FTP, while removing it from direct Internet exposure. The solution is to keep the protocol in use but place it behind a secure VPN tunnel and isolate the service in a DMZ.

### Network isolation

The redesign introduces multiple VLANs and requires inter-zone communication to be explicitly allowed. This prevents lateral movement and drastically reduces the blast radius of a compromised host.

---

## Hardened implementation artifacts

The scripts in the [HARDENING](HARDENING) folder are intended to automate the hardening workflow.

- [HARDENING/clean.sh](HARDENING/clean.sh): remove legacy, risky, or unnecessary components and restore a cleaner baseline.
- [HARDENING/firewall.sh](HARDENING/firewall.sh): deploy the default-deny firewall policy and traffic restrictions.
- [HARDENING/vpn_setup.sh](HARDENING/vpn_setup.sh): configure the WireGuard tunnel and peer access rules.
- [HARDENING/panic_button.sh](HARDENING/panic_button.sh): emergency rollback or containment helper for rapid recovery.

---

## Validation

The validation script [VALIDATION/tests.sh](VALIDATION/tests.sh) checks compliance against the expected hardened state and acts as a regression guard after changes.

Validation includes checks for:

- firewall default policy;
- secure SSH configuration;
- WireGuard interface availability;
- absence of exposed services;
- VLAN segmentation rules;
- restricted administrative flows;
- service and package hygiene.

---

## Deployment philosophy

The project follows a phased implementation approach:

1. Prepare and backup the system.
2. Remove persistence and insecure services.
3. Harden SSH and create a VPN-based admin path.
4. Validate firewall rules in observation mode.
5. Switch to blocking mode.
6. Deploy VLANs and isolate guest and server segments.
7. Relocate FTP to the DMZ behind VPN access.
8. Enforce output filtering and persistent configuration.

This sequencing avoids breaking production while progressively strengthening the network.

---

## Risks and known limitations

This project acknowledges a few important limits:

- The lab environment is a container and does not fully represent a full physical gateway deployment.
- Some host-level controls such as AppArmor or SELinux may be constrained by the environment.
- High availability and redundancy were treated as future work, not as part of the first hardening phase.
- Legacy FTP remains a risk in principle, but it is reduced by VPN isolation and DMZ placement.

---

## Final outcome

The resulting design shifts the environment from a flat, Internet-exposed, weakly managed gateway to a segmented architecture with:

- encrypted remote admin access;
- default-deny filtering;
- isolated guest and server networks;
- limited database access;
- controlled FTP access behind the VPN;
- clearer operational monitoring and enforceable security policy.

This makes the network far more resilient to common attack paths, especially lateral movement from a compromised host or exposed service.

---

## Credits

This capstone was developed as a network-security hardening and architecture exercise focused on practical defense-in-depth, zero-trust principles, and realistic operational constraints.
