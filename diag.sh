#!/bin/bash

# Script de monitoring pour Serveur Samba Active Directory

# Configuration
LOG_FILE="/var/log/samba-ad-monitor.log"
REPORT_FILE="/tmp/samba_ad_report_$(date +%Y%m%d_%H%M%S).html"
ADMIN_EMAIL="serviceinfo@h3campus.fr"
DOMAIN_NAME=$(hostname -d)
REALM=$(samba-tool domain info $(hostname -f) | grep "Realm" | cut -d: -f2 | tr -d '[:space:]')
ADMIN_USER="Administrator"

# Couleurs pour le rapport HTML
COLOR_GREEN="#e6ffe6"
COLOR_RED="#ffe6e6"
COLOR_YELLOW="#fffae6"

# Fonction de logging
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Vérification des outils LDAP
check_ldap_tools() {
    local ldap_packages=("ldap-utils")
    local missing_packages=()

    for pkg in "${ldap_packages[@]}"; do
        if ! dpkg -s "$pkg" &> /dev/null; then
            missing_packages+=("$pkg")
        fi
    done

    if [ ${#missing_packages[@]} -gt 0 ]; then
        log_message "Installation des paquets LDAP manquants : ${missing_packages[*]}"
        apt-get update
        apt-get install -y "${missing_packages[@]}"
    fi
}

# Vérification des processus Samba
check_samba_processes() {
    local processes_to_check=(
        "samba" 
        "winbind_server" 
        "ldap_server" 
        "dns" 
        "kdc_server" 
        "dreplsrv" 
        "rpc_server" 
        "cldap_server" 
        "nbt_server"
    )
    local process_status=()

    log_message "Début de la vérification des processus Samba"
    
    local samba_processes=$(samba-tool processes | tail -n +3 | awk '{print $1}' | sort | uniq)

    for proc in "${processes_to_check[@]}"; do
        if echo "$samba_processes" | grep -q "$proc"; then
            process_status+=("<tr style='background-color: $COLOR_GREEN;'><td>$proc</td><td>Actif</td></tr>")
        else
            process_status+=("<tr style='background-color: $COLOR_RED;'><td>$proc</td><td>Inactif</td></tr>")
        fi
    done

    echo "${process_status[@]}"
}

# Vérification détaillée Kerberos
check_kerberos() {
    local kerberos_checks=()
    local password

    # Demander interactivement le mot de passe
    read -s -p "Mot de passe pour $ADMIN_USER : " password
    echo

    local kdc_processes=$(samba-tool processes | grep "kdc_server")
    
    if [ -n "$kdc_processes" ]; then
        if echo "$password" | kinit "$ADMIN_USER" &> /dev/null; then
            kerberos_checks+=("<tr style='background-color: $COLOR_GREEN;'><td>Authentification Kerberos</td><td>Actif et Valide</td></tr>")
        else
            kerberos_checks+=("<tr style='background-color: $COLOR_RED;'><td>Authentification Kerberos</td><td>Problème détecté</td></tr>")
            kerberos_checks+=("<tr><td colspan='2'>Le script a vérifié la présence des processus KDC et a tenté d'obtenir un ticket Kerberos avec le compte utilisateur '$ADMIN_USER'. Un problème a été détecté, probablement lié à la configuration ou au fonctionnement du service Kerberos.</td></tr>")
        fi
    else
        kerberos_checks+=("<tr style='background-color: $COLOR_RED;'><td>Authentification Kerberos</td><td>Problème détecté</td></tr>")
        kerberos_checks+=("<tr><td colspan='2'>Aucun processus KDC n'a été trouvé. Le service Kerberos semble être inactif ou mal configuré.</td></tr>")
    fi

    echo "${kerberos_checks[@]}"
}

# Vérification LDAP
check_ldap() {
    local ldap_checks=()
    
    # Vérifier la configuration LDAP via samba-tool
    if samba-tool domain info $(hostname -f) &> /dev/null; then
        ldap_checks+=("<tr style='background-color: $COLOR_GREEN;'><td>Annuaire LDAP</td><td>Configuré et Accessible</td></tr>")
    else
        ldap_checks+=("<tr style='background-color: $COLOR_RED;'><td>Annuaire LDAP</td><td>Problème de configuration</td></tr>")
        ldap_checks+=("<tr><td colspan='2'>Impossible de récupérer les informations du domaine. Vérifiez la configuration Samba AD.</td></tr>")
    fi

    echo "${ldap_checks[@]}"
}


# Vérification DNS
check_dns() {
    local dns_checks=()
    
    local dns_processes=$(samba-tool processes | grep "dns")
    
    if [ -n "$dns_processes" ] && host "$DOMAIN_NAME" &> /dev/null; then
        dns_checks+=("<tr style='background-color: $COLOR_GREEN;'><td>Serveur DNS</td><td>Actif et Fonctionnel</td></tr>")
    else
        dns_checks+=("<tr style='background-color: $COLOR_RED;'><td>Serveur DNS</td><td>Problème détecté</td></tr>")
        dns_checks+=("<tr><td colspan='2'>Le script a vérifié la présence des processus DNS et a tenté de résoudre le nom de domaine. Un problème a été détecté, probablement lié à la configuration ou au fonctionnement du service DNS.</td></tr>")
    fi

    echo "${dns_checks[@]}"
}

# Génération du rapport HTML
generate_html_report() {
    cat << EOF > "$REPORT_FILE"
<!DOCTYPE html>
<html>
<head>
    <title>Rapport Monitoring Samba AD DC</title>
    <style>
        body { font-family: Arial, sans-serif; }
        table { width: 100%; border-collapse: collapse; margin-bottom: 20px; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        h2 { color: #333; }
    </style>
</head>
<body>
    <h1>Rapport de Monitoring Samba AD DC - $(date '+%d/%m/%Y %H:%M:%S')</h1>

    <h2>Processus Samba AD</h2>
    <table>
        $(check_samba_processes)
    </table>

    <h2>Authentification Kerberos</h2>
    <table>
        $(check_kerberos)
    </table>

    <h2>Serveur LDAP</h2>
    <table>
        $(check_ldap)
    </table>

    <h2>Serveur DNS</h2>
    <table>
        $(check_dns)
    </table>
</body>
</html>
EOF
}

# Envoi du rapport par email
send_email_report() {
    if [ -f "$REPORT_FILE" ]; then
        if command -v sendmail &> /dev/null; then
            (
                echo "To: $ADMIN_EMAIL"
                echo "Subject: Rapport Monitoring Samba AD DC - $(date '+%d/%m/%Y')"
                echo "Content-Type: text/html"
                echo ""
                cat "$REPORT_FILE"
            ) | sendmail -t
            log_message "Rapport envoyé via sendmail à $ADMIN_EMAIL"
        elif command -v ssmtp &> /dev/null; then
            (
                echo "To: $ADMIN_EMAIL"
                echo "Subject: Rapport Monitoring Samba AD DC - $(date '+%d/%m/%Y')"
                echo "Content-Type: text/html"
                echo ""
                cat "$REPORT_FILE"
            ) | ssmtp "$ADMIN_EMAIL"
            log_message "Rapport envoyé via ssmtp à $ADMIN_EMAIL"
        else
            cp "$REPORT_FILE" "/var/www/html/samba-ad-report-latest.html"
            log_message "ATTENTION : Impossible d'envoyer l'email. Rapport sauvegardé dans /var/www/html/samba-ad-report-latest.html"
        fi
    else
        log_message "Erreur: Fichier de rapport introuvable"
    fi
}

# Fonction principale
main() {
    check_ldap_tools
    log_message "Début du monitoring Samba AD DC"
    generate_html_report
    send_email_report
    log_message "Monitoring terminé"
}

# Exécution du script
main
