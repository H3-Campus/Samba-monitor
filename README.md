# Samba-monitor

## Objectif du Script

Script de surveillance automatisé pour vérifier l'intégrité et le fonctionnement d'un contrôleur de domaine Samba Active Directory.

## Prérequis Techniques

- Samba AD DC installé
- Droits administrateur
- Paquets LDAP installés
- Serveur email configuré (sendmail)

## Fréquence d'Exécution

- Programmé via crontab
- Exécution tous les lundis matins
- Génération et transmission d'un rapport de santé système (sur l’email : serviceinfo@h3campus.fr)

## Fonctionnalités Principales

1. Vérification de l'état des processus Samba critiques
2. Contrôle de l'authentification Kerberos
3. Validation de la configuration du domaine
4. Surveillance des services DNS
5. Génération d'un rapport HTML
6. Envoi du rapport par email

## Détection et Gestion des Erreurs

### Processus Inactifs

- **Action Immédiate** : Notification dans le rapport HTML
- **Couleur Rouge** indiquant un dysfonctionnement
- Nécessite une intervention manuelle rapide

### Types d'Alertes Possibles

- Processus Samba arrêtés
- Authentification Kerberos défaillante
- Problèmes de résolution DNS
- Configuration du domaine corrompue

### Procédure de Réaction

### Étape 1 : Analyse du Rapport

- Consulter le rapport HTML détaillé
- Identifier précisément les services défaillants
- Vérifier les logs system (/var/log/samba-ad-monitor.log)

### Étape 2 : Diagnostic Technique

1. **Processus Samba**
    - Redémarrer le service : `systemctl restart samba-ad-dc`
    - Vérifier les logs : `journalctl -u samba-ad-dc`
2. **Kerberos**
    - Vérifier la synchronisation horaire
    - Renouveler les keytabs
    - Contrôler la configuration Kerberos
3. **DNS**
    - Vérifier la résolution : `dig @localhost H3ADM.LAN`
    - Contrôler la configuration réseau
    - Redémarrer le service DNS
4. **Configuration Domaine**
    - Vérifier l'intégrité de la base de données
5. **Process Tis-Sysvol**

### Étape 3 : Remontée d'Information

- Diagnostic de ce qui fonctionne et ce qui ne fonctionne plus
- Documenter les incidents
