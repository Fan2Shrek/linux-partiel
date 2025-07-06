#!/bin/bash

apache2 -v || sudo apt install apache2 -y

php -v || sudo apt install php -y

sudo apt install apache2-utils -y

sudo a2enmod ssl
sudo a2enmod rewrite
sudo a2enmod headers

sudo mkdir -p /etc/apache2/auth

sudo htpasswd -cb /etc/apache2/auth/.htpasswd admin admin123

sudo tee /etc/apache2/sites-available/000-default-auth.conf > /dev/null << 'EOF'
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html

    <Directory "/var/www/html">
        AuthType Basic
        AuthName "Authentification requise"
        AuthUserFile /etc/apache2/auth/.htpasswd
        Require valid-user
        
        Options Indexes FollowSymLinks
        AllowOverride None
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

sudo a2dissite 000-default
sudo a2ensite 000-default-auth

sudo apache2ctl configtest

sudo systemctl restart apache2