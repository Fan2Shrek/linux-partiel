#!/bin/bash

DESTINATION="/var/www"
APACHE_DIR="/etc/apache2/sites-available"
APACHE_TEMPLATE="/etc/apache2/sites-available/000-default.conf"

# Vérifier si l'archive existe
if [ ! -f "./glpi-10.0.18.tgz" ]; then
    echo "Error: glpi-10.0.18.tgz not found in current directory"
    exit 1
fi

# Créer le répertoire de destination
sudo mkdir -p $DESTINATION

# Extraire l'archive
tar -xzf ./glpi-10.0.18.tgz -C $DESTINATION

cd $DESTINATION

# Créer le fichier de configuration Apache avec les bonnes permissions
if ! sudo touch $APACHE_DIR/001-glpi.conf; then
    echo "Failed to create Apache configuration file, please retry as root"
    exit 1
fi

sudo cat $APACHE_TEMPLATE | sed "s#www.example.com#\n\tServerName glpi.local#" | sed "s#/var/www/html#$DESTINATION/glpi#" | sudo tee $APACHE_DIR/001-glpi.conf > /dev/null

sudo a2ensite 001-glpi.conf
sudo systemctl reload apache2

./bdd.sh glpi
