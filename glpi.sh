#!/bin/bash

DESTINATION="/var/www"
APACHE_DIR="/etc/apache2/sites-available"
APACHE_TEMPLATE="/etc/apache2/sites-available/000-default.conf"

mkdir -p $DESTINATION

tar -xzf ./glpi-10.0.18.tgz -C $DESTINATION

cd $DESTINATION

touch $APACHE_DIR/001-glpi.conf || echo "Failed to create Apache configuration file, please retry as root" && exit 1
cat $APACHE_TEMPLATE | sed "s#www.example.com#\n\tServerName glpi.local#" | sed "s#/var/www/html#$DESTINATION#" > $APACHE_DIR/001-glpi.conf

a2ensite 001-glpi.conf
sudo systemctl reload apache2
