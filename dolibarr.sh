#!/bin/bash

DESTINATION="/var/www"
APACHE_DIR="/etc/apache2/sites-available"
APACHE_TEMPLATE="/etc/apache2/sites-available/000-default.conf"

mkdir -p $DESTINATION

tar -xzf ./dolibarr-21.0.1.tar.gz -C $DESTINATION

cd $DESTINATION

# Create Apache configuration file
if ! sudo touch $APACHE_DIR/001-dolibarr.conf; then
    echo "Failed to create Apache configuration file, please retry as root"
    exit 1
fi

# Generate Apache configuration
sudo cat $APACHE_TEMPLATE | sed "s#www.example.com#\n\tServerName dolibarr.local#" | sed "s#/var/www/html#$DESTINATION/dolibarr-21.0.1/htdocs#" | sudo tee $APACHE_DIR/001-dolibarr.conf > /dev/null

sudo a2ensite 001-dolibarr.conf
sudo systemctl reload apache2