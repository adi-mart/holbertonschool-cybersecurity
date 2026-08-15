# Linux Capstone : Hardening Automation

## 1. Présentation du projet

Ce projet a pour objectif de transformer un système Linux Ubuntu 22.04 fraîchement installé en un hôte sécurisé, conforme à une politique de durcissement de type STIG-2024. L’objectif n’est pas seulement d’appliquer quelques commandes manuelles, mais de concevoir un outil automatisé, modulaire, idempotent et traçable capable de renforcer la sécurité d’un serveur de manière reproductible.

Le projet repose sur un script principal nommé `harden.sh` qui charge une configuration externe, appelle plusieurs bibliothèques de fonctions et applique les règles de sécurité selon les domaines suivants :

- réseau
- SSH
- identité / mot de passe
- système / gestion des paquets

Le résultat attendu est un système plus difficile à exploiter, avec des politiques de sécurité imposées automatiquement, une journalisation complète et un rapport d’audit final permettant de prouver les changements effectués.

---

## 2. Contexte et enjeu

Dans le monde réel, un administrateur système ou un ingénieur cybersécurité ne reçoit pas toujours des instructions “pas à pas” pour durcir un serveur. Il reçoit une politique de sécurité, parfois rédigée en anglais technique, et doit la traduire en commandes, scripts et procédures automatisées.

Ce projet simule précisément ce type de situation :

- un serveur est livré “propre” et non durci ;
- il doit être transformé en bastion sécurisé ;
- les règles doivent être appliquées sans intervention manuelle ;
- les modifications doivent être idempotentes, c’est-à-dire sûres à relancer plusieurs fois ;
- un rapport d’audit doit prouver que le durcissement a bien été appliqué.

Le projet vise à développer un outil d’automatisation réellement exploitable dans un cadre professionnel, avec une séparation claire entre :

- les configurations variables ;
- la logique métier ;
- le journaling ;
- la vérification finale.

---

## 4. Structure du projet

Le projet est organisé de la manière suivante :

```text
linux_security/
└── 1x05_hardening/
    ├── README.md
    └── hardening/
        ├── harden.sh
        ├── config/
        │   └── harden.cfg
        └── lib/
            ├── network.sh
            ├── ssh.sh
            ├── identity.sh
            └── system.sh
```

### 4.1 Rôle de chaque fichier

- `harden.sh` : point d’entrée principal du durcissement.
- `config/harden.cfg` : variables globales de configuration.
- `lib/network.sh` : règles réseau, pare-feu et paramètres kernel.
- `lib/ssh.sh` : configuration sécurisée de SSH.
- `lib/identity.sh` : politique de mot de passe, blocage d’accès, nettoyage des comptes.
- `lib/system.sh` : mise à jour du système, suppression de logiciels inutiles et installation des outils de sécurité.
- `README.md` : documentation du projet.
- `audit_report.txt` : rapport généré automatiquement à la fin du script.

---

## 5. Politique de sécurité appliquée

Le projet implémente une politique de durcissement inspirée des standards de sécurité et des bonnes pratiques de hardening Linux. Les règles principales sont les suivantes.

### 5.1 Domaine réseau

#### N-01 : Pare-feu

Le script génère une politique de pare-feu persistante dans :

```text
/etc/hardening/firewall.rules
```

La règle principale impose :

- entrée par défaut : `deny`
- sortie par défaut : `allow`
- ports autorisés : SSH, HTTP et HTTPS selon les paramètres de configuration

#### N-02 : Ports autorisés

Les ports HTTP et HTTPS sont autorisés par défaut :

- 80
- 443

Le port SSH est configurable via la variable `SSH_PORT` dans le fichier de configuration.

#### N-03 : Paramètres kernel

Le script applique des paramètres persistants dans `/etc/sysctl.conf` afin de :

- désactiver le transfert d’IP (`ip_forward=0`) ;
- ignorer les requêtes ICMP echo (`ping`) ;
- renforcer le comportement réseau de la machine.

### 5.2 Domaine SSH

#### S-01 : Authentification

- désactivation de l’authentification par mot de passe ;
- activation de l’authentification par clé publique ;
- validation du fichier de configuration SSH avant application.

#### S-02 : Connexion root

- `PermitRootLogin no`

Cela empêche la connexion directe en tant que root au serveur.

### 5.3 Domaine identité

#### I-01 : Politique de mots de passe

Le script configure les paramètres de robustesse des mots de passe :

- longueur minimale : 12 caractères
- présence de majuscules, minuscules, chiffres et caractères spéciaux
- âge maximum : 90 jours

#### I-02 : Blocage des comptes

- blocage après 5 échecs d’authentification (`FAIL_LOCK_ATTEMPTS=5`)

#### I-03 : Nettoyage des comptes inutiles

Les comptes utilisateurs créés avec un UID supérieur à 1000 et non présents dans les groupes `sudo` ou `wheel` sont supprimés.

#### I-04 : Root

Le compte root est verrouillé via `passwd -l root`, ce qui empêche l’utilisation du mot de passe root pour la connexion locale.

### 5.4 Domaine système

#### H-01 : Mises à jour

Le script met à jour les dépôts APT et effectue la mise à niveau du système de manière non interactive.

#### H-02 : Logiciels superflus

Les paquets inutiles sont supprimés :

- telnet
- ftp
- netcat-traditional

#### H-03 : Outils de sécurité

Les outils suivants sont installés :

- `auditd`
- `fail2ban`

---

## 6. Architecture technique

Le script a été conçu selon une approche modulaire, avec séparation de la logique et de la configuration.

### 6.1 Point d’entrée

Le script principal `harden.sh` fait ceci :

1. vérifie que le script est exécuté par root ;
2. charge le fichier de configuration `config/harden.cfg` ;
3. initialise le journal système ;
4. charge les bibliothèques de hardening ;
5. applique les fonctions de durcissement ;
6. génère le rapport d’audit final.

### 6.2 Configuration externe

Le fichier `config/harden.cfg` centralise les variables importantes :

```bash
LOG_FILE="/var/log/hardening.log"
SSH_PORT="2222"
ALLOW_HTTP="true"
ALLOW_HTTPS="true"
FIREWALL_RULES_FILE="/etc/hardening/firewall.rules"
SYSCTL_FILE="/etc/sysctl.conf"
SSHD_CONFIG_FILE="/etc/ssh/sshd_config"
SSH_PERMIT_ROOT_LOGIN="no"
SSH_PASSWORD_AUTHENTICATION="no"
PASS_MIN_LEN="12"
PASS_MAX_DAYS="90"
FAIL_LOCK_ATTEMPTS="5"
BLOATWARE_PACKAGES=("telnet" "ftp" "netcat-traditional")
INSTALL_TOOLS=("auditd" "fail2ban")
```

Cette méthode évite de coder directement des valeurs sensibles dans le code logique, ce qui améliore la maintenabilité et la sécurité.

### 6.3 Idempotence

Le script est volontairement idempotent :

- s’il est relancé plusieurs fois, il n’ajoute pas de lignes dupliquées ;
- il vérifie si une modification est déjà présente avant d’écrire ;
- il réécrit les fichiers de configuration selon un schéma contrôlé lorsque nécessaire.

Exemple : après le premier lancement, la ligne `PermitRootLogin no` ne sera pas ajoutée plusieurs fois dans `sshd_config`.

### 6.4 Journalisation

Chaque action est journalisée dans `/var/log/hardening.log` avec un format structuré de type JSON. Exemple :

```json
{"timestamp": "2026-08-15T12:00:00Z", "component": "ENGINE", "target": "HARDENING FRAMEWORK", "status": "INITIALIZED", "details": "Hardening framework initialized"}
```

Cela permet de retracer :

- l’étape exécutée ;
- la cible concernée ;
- le statut ;
- le détail de l’action.

---

## 7. Fichiers et fonctions

### 7.1 `lib/network.sh`

Cette bibliothèque gère :

- la génération du fichier de politique du pare-feu ;
- la création du dossier `/etc/hardening` ;
- l’écriture des règles de filtrage ;
- la configuration persistante de `sysctl`.

Fonctions principales :

- `harden_network()`

### 7.2 `lib/ssh.sh`

Cette bibliothèque s’occupe de la sécurisation de SSH :

- sauvegarde du fichier `sshd_config` ;
- désactivation du login root ;
- désactivation de l’authentification par mot de passe ;
- activation de l’authentification par clé ;
- validation syntaxique via `sshd -t` ;
- rechargement du service SSH si la configuration est valide.

Fonctions principales :

- `harden_ssh()`

### 7.3 `lib/identity.sh`

Cette bibliothèque applique les règles d’identité :

- installation du package `libpam-pwquality` si absent ;
- ajout de la politique de complexité dans `/etc/pam.d/common-password` ;
- définition de `PASS_MAX_DAYS` dans `/etc/login.defs` ;
- parametrage de `deny` dans `/etc/security/faillock.conf` ;
- suppression des comptes utilisateur non autorisés ;
- verrouillage du compte root.

Fonctions principales :

- `harden_identity()`

### 7.4 `lib/system.sh`

Cette bibliothèque assure :

- la mise à jour des paquets ;
- la mise à niveau du système ;
- la suppression des paquets inutiles ;
- l’installation des outils de sécurité ;
- la génération du rapport d’audit final.

Fonctions principales :

- `is_installed()`
- `harden_system()`
- `generate_report()`

---

## 8. Utilisation du projet

### 8.1 Prérequis

Le projet est prévu pour fonctionner sur :

- Ubuntu 22.04 LTS
- un système exécuté avec des privilèges root
- accès réseau pour récupérer les mises à jour et installer des paquets

### 8.2 Lancer le script

Depuis le répertoire du projet :

```bash
cd /home/aurelie12/Projets/holbertonschool-cybersecurity/linux_security/1x05_hardening
sudo bash hardening/harden.sh
```

Ou, si le script est rendu exécutable :

```bash
sudo ./hardening/harden.sh
```

### 8.3 Vérification

Après exécution, le script produit :

- un journal dans `/var/log/hardening.log` ;
- un rapport d’audit dans le répertoire courant : `audit_report.txt`.

---

## 9. Rapport d’audit

Le rapport d’audit est généré automatiquement par la fonction `generate_report()`. Il contient :

- les actions effectuées ;
- les changements appliqués ;
- le statut de chaque étape (`INFO`, `WARN`, `ERROR`) ;
- la conclusion globale du projet : `PASS` ou `FAIL`.


## 10. Bonnes pratiques respectées

Ce projet est conforme à plusieurs principes essentiels de la sécurité Linux et du scripting robustes :

- utilisation de fichiers de configuration séparés ;
- pas de valeurs codées en dur dans la logique ;
- scripts exécutables avec shebang `#!/bin/bash` ;
- vérification stricte du contexte root ;
- journalisation de chaque action ;
- idempotence ;
- validation de la syntaxe avant application de certaines modifications ;
- génération d’un rapport final explicite.

---

## 12. Conclusion

Ce projet est un exercice de type “capstone” qui illustre la vraie logique du travail d’un ingénieur cybersécurité : transformer une politique de sécurité en code exécutable, fiable et réutilisable.

Le résultat est un automate de durcissement Linux qui :

- sécurise le système à partir d’un état brut ;
- applique des règles modérées mais efficaces ;
- protège les accès distants ;
- réduit les vulnérabilités liées aux comptes et aux services ;
- s’assure d’une traçabilité complète ;
- génère une preuve de conformité sous forme de rapport.

En somme, il ne s’agit pas seulement d’un script Bash, mais d’une base solide pour un outil de hardening automatisé à grande échelle.
