# 3x00 Security Core

## Vue d'ensemble

Ce module introduit les fondements de la sécurité informatique appliquée au design d'une architecture sécurisée. Il met l'accent sur trois piliers essentiels :

- l'authentification,
- l'autorisation,
- la traçabilité et l'audit.

L'objectif est de comprendre comment concevoir un système capable de protéger les données sensibles, même en cas de compromission partielle de l'infrastructure.

## Cas d'étude : ApexVault

ApexVault est un système conçu selon une approche Zero Trust. Le principe central est simple : aucun utilisateur, processus ou composant ne doit être implicitement considéré comme fiable.

Le but du design est de garantir que même si un serveur est compromis, ou qu'un administrateur malveillant tente d'accéder aux données, les informations clients restent protégées.

---

## Résumé exécutif

ApexVault vise à garantir la confidentialité, l'intégrité et la non-répudiation des données, malgré les menaces internes et externes. La protection repose sur :

- une authentification forte et résistante au phishing,
- des mécanismes de contrôle d'accès stricts,
- un stockage des traces d'audit hors du système principal,
- un chiffrement des données afin de limiter les risques de fuite.

---

## 1. Stratégie d'authentification

### Technologie sélectionnée : FIDO2

Le système utilise la norme FIDO2 basée sur des clés de sécurité matérielles.

### Pourquoi ce choix ?

- pas de mot de passe traditionnel,
- meilleure résistance au phishing,
- forte sécurité grâce à la cryptographie asymétrique,
- meilleure expérience utilisateur tout en renforçant la sécurité.

### Impact sur la sécurité

L'authentification repose sur un mécanisme physique ou cryptographique, ce qui réduit significativement le risque d'usurpation d'identité par vol de mot de passe ou ingénierie sociale.

---

## 2. Modèle d'autorisation

### Modèle sélectionné : RBAC (Role-Based Access Control)

Les permissions sont attribuées selon le rôle de l'utilisateur. Cela permet de limiter les privilèges au strict nécessaire.

### Exemple de principe appliqué

- un administrateur système n'a pas nécessairement accès au contenu clair des fichiers clients,
- les droits sont limités à la maintenance technique, sans détenir la clé de lecture des données sensibles,
- les accès sont segmentés selon les responsabilités.

### Protection des données client

Les fichiers clients sont chiffrés côté client avant d'être envoyés au serveur. Cela signifie que même un administrateur ou un opérateur système qui accède au serveur ne peut pas lire le contenu sans la clé de déchiffrement.

Ce mécanisme renforce le principe de moindre privilège et réduit le risque de fuite de données en cas de compromission du backend.

---

## 3. Architecture de comptabilité et d'audit

### Emplacement de stockage des logs

Les journaux sont envoyés vers un serveur de logs centralisé et distinct du serveur principal ApexVault.

### Objectif

- séparer les traces d'audit du système applicatif,
- éviter la suppression ou la modification facile des logs en cas d'intrusion,
- faciliter l'investigation de sécurité.

### Intégrité des logs

Les événements sont protégés par des mécanismes cryptographiques, notamment le hachage. Cela permet de détecter toute modification, suppression ou falsification des traces.

### Valeur sécurité

Même si un attaquant compromet le serveur d'application, il ne peut pas facilement effacer ses traces sans laisser de preuve. Cela améliore la capacité d'enquête et la conformité réglementaire.

---

## 4. Principes de sécurité mis en œuvre

Le design proposé s'appuie sur plusieurs principes de sécurité classiques :

- Zero Trust : aucune confiance implicite,
- Moindre privilège : accès limité aux droits strictement nécessaires,
- Séparation des responsabilités : admin / opérations / données,
- Chiffrement des données sensibles,
- Audit centralisé et vérifiable,
- Résilience face à la compromission interne.

---

## 5. Conclusion

Le modèle de sécurité d'ApexVault met en place une architecture orientée sécurité par conception. Il montre qu'un système peut rester robuste même lorsqu'un composant technique est compromis, à condition que :

- l'identité soit vérifiée de manière forte,
- l'accès soit strictement contrôlé,
- les données soient chiffrées avant stockage,
- les traces d'activité soient sécurisées et centralisées.

Cette approche constitue une base solide pour la conception de services sensibles, notamment dans des environnements où la confidentialité des données est cruciale.
