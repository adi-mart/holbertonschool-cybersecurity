Executive Summary: 
ApexVault est conçu selon une approche Zero Trust. L'objectif est de protéger les données des clients même en cas de compromission du serveur ou d'un administrateur.

1. Authentication Strategy:

    • **Selected Technology:** FIDO2 (clé de sécurité matérielle)

    • **Justification:** FIDO2 permet une authentification sans mot de passe et est résistante au phishing grâce à la cryptographie

2. Authorization Model:

    • **Model Selected:** RBAC (Role-Based Access Control) : Les permissions sont définies selon le rôle de l'utilisateur

    • **Admin Restriction:** Les fichiers clients sont chiffrés côté client avant d'être envoyés au serveur. Donc même le SysAdmin peut accéder au fichier chiffré sur le serveur, mais il n'a pas la clé nécessaire pour lire son contenu

3. Accounting Architecture:

    • **Storage Location:** Les logs sont envoyés vers un serveur de logs centralisé et séparé du serveur ApexVault

    • **Integrity Mechanism:** Les logs sont stockés et protégés par des mécanismes cryptographiques comme le hachage. Donc un attaquant qui compromet le serveur ApexVault ne peut pas simplement supprimer ou modifier les logs pour effacer ses traces
