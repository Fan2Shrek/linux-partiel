#!/bin/bash

# Script de déploiement complet avec certificats SSL
# Usage: ./deploy-with-ssl.sh <application> [domain]

APPLICATION=$1
DOMAIN=${2:-"$APPLICATION.local"}

if [ -z "$APPLICATION" ]; then
    echo "Usage: $0 <application> [domain]"
    echo "Applications disponibles: dolibarr, glpi"
    exit 1
fi

case $APPLICATION in
    "dolibarr"|"glpi")
        echo "Déploiement de $APPLICATION..."
        ;;
    *)
        echo "Application non supportée: $APPLICATION"
        echo "Applications disponibles: dolibarr, glpi"
        exit 1
        ;;
esac

if [ -f "./${APPLICATION}.sh" ]; then
    sudo bash "./${APPLICATION}.sh"
    if [ $? -ne 0 ]; then
        echo "Erreur lors du déploiement de $APPLICATION"
        exit 1
    fi
else
    echo "Script de déploiement ${APPLICATION}.sh non trouvé"
    exit 1
fi

sudo bash "./certs.sh" "$APPLICATION" "$DOMAIN"
if [ $? -ne 0 ]; then
    echo "Erreur lors de la génération des certificats"
    exit 1
fi

case $APPLICATION in
    "dolibarr")
        sudo mkdir -p "/var/www/dolibarr-21.0.1/htdocs"
        sudo chown -R www-data:www-data "/var/www/dolibarr-21.0.1"
        sudo chmod -R 755 "/var/www/dolibarr-21.0.1"
        
        sudo sed -i "s#/var/www/$APPLICATION/htdocs#/var/www/dolibarr-21.0.1/htdocs#g" "/etc/apache2/sites-available/001-$APPLICATION-ssl.conf"
        ;;
    "glpi")
        sudo mkdir -p "/var/www/glpi"
        sudo chown -R www-data:www-data "/var/www/glpi"
        sudo chmod -R 755 "/var/www/glpi"
        
        sudo sed -i "s#/var/www/$APPLICATION/htdocs#/var/www/glpi#g" "/etc/apache2/sites-available/001-$APPLICATION-ssl.conf"
        ;;
esac

sudo systemctl restart apache2

if sudo apache2ctl configtest; then
    echo "Configuration Apache valide"
else
    echo "Erreur dans la configuration Apache"
    exit 1
fi

if [ -f "/etc/ssl/custom/$APPLICATION.crt" ]; then
    echo "Certificat serveur: ✓"
    openssl x509 -in "/etc/ssl/custom/$APPLICATION.crt" -noout -subject -dates
else
    echo "Certificat serveur: ✗"
fi

if [ -f "/etc/ssl/ca/ca.crt" ]; then
    echo "Certificat CA: ✓"
else
    echo "Certificat CA: ✗"
fi

echo ""
echo "=== Déploiement terminé ==="
echo "Application: $APPLICATION"
echo "Domaine: $DOMAIN"
echo "URL HTTP: http://$DOMAIN (redirigé vers HTTPS)"
echo "URL HTTPS: https://$DOMAIN"
echo ""
echo "Certificats disponibles:"
echo "  - CA: /etc/ssl/ca/ca.crt"
echo "  - Serveur: /etc/ssl/custom/$APPLICATION.crt"
echo ""