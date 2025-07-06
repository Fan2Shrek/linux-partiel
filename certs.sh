#!/bin/bash

# Script pour installation CA et génération de certificats SSL
# Usage: ./certs.sh <project-name> [domain]

PROJECT_NAME=$1
DOMAIN=${2:-"$PROJECT_NAME.local"}
OUTPUT_DIR="/etc/ssl/custom"
CA_DIR="/etc/ssl/ca"
CLIENT_CERT_DIR="/var/www/client-certs"

if [ -z "$PROJECT_NAME" ]; then
  echo "Usage: $0 <project-name> [domain]"
  echo "Example: $0 dolibarr dolibarr.local"
  exit 1
fi

sudo mkdir -p "$CA_DIR" "$OUTPUT_DIR" "$CLIENT_CERT_DIR"
sudo chmod 755 "$CA_DIR" "$OUTPUT_DIR" "$CLIENT_CERT_DIR"

if [ ! -f "$CA_DIR/ca.key" ]; then
    echo "Génération de la clé privée de la CA..."
    sudo openssl genrsa -out "$CA_DIR/ca.key" 4096
    sudo chmod 600 "$CA_DIR/ca.key"
fi

if [ ! -f "$CA_DIR/ca.crt" ]; then
    echo "Génération du certificat de la CA..."
    sudo openssl req -new -x509 -key "$CA_DIR/ca.key" -sha256 -days 3650 \
        -out "$CA_DIR/ca.crt"
    sudo chmod 644 "$CA_DIR/ca.crt"
fi

echo "Génération de la clé privée pour $PROJECT_NAME..."
sudo openssl genrsa -out "$OUTPUT_DIR/$PROJECT_NAME.key" 2048
sudo chmod 600 "$OUTPUT_DIR/$PROJECT_NAME.key"

echo "Génération de la demande de certificat..."
sudo openssl req -new -key "$OUTPUT_DIR/$PROJECT_NAME.key" \
    -out "$OUTPUT_DIR/$PROJECT_NAME.csr" \
    -subj "/C=FR/ST=France/CN=$DOMAIN"


sudo tee "$OUTPUT_DIR/$PROJECT_NAME.ext" > /dev/null << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = $DOMAIN
DNS.2 = localhost
IP.1 = 127.0.0.1
EOF

echo "Signature du certificat par la CA..."
sudo openssl x509 -req -in "$OUTPUT_DIR/$PROJECT_NAME.csr" \
    -CA "$CA_DIR/ca.crt" -CAkey "$CA_DIR/ca.key" \
    -CAcreateserial -out "$OUTPUT_DIR/$PROJECT_NAME.crt" \
    -days 365 -sha256 -extfile "$OUTPUT_DIR/$PROJECT_NAME.ext"

sudo chmod 644 "$OUTPUT_DIR/$PROJECT_NAME.crt"

# Nettoyage du fichier temporaire
sudo rm -f "$OUTPUT_DIR/$PROJECT_NAME.ext"

sudo cp "$CA_DIR/ca.crt" /usr/local/share/ca-certificates/lab-ca.crt
sudo update-ca-certificates

sudo tee "/etc/apache2/sites-available/001-$PROJECT_NAME-ssl.conf" > /dev/null << EOF
<IfModule mod_ssl.c>
    <VirtualHost *:443>
        ServerName $DOMAIN
        DocumentRoot /var/www/$PROJECT_NAME/htdocs
        
        SSLEngine on
        SSLCertificateFile $OUTPUT_DIR/$PROJECT_NAME.crt
        SSLCertificateKeyFile $OUTPUT_DIR/$PROJECT_NAME.key
        SSLCertificateChainFile $CA_DIR/ca.crt
        
        SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1
        SSLCipherSuite ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384
        SSLHonorCipherOrder off
        SSLSessionTickets off
        
        Header always set Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"
        Header always set X-Content-Type-Options nosniff
        Header always set X-Frame-Options DENY
        Header always set X-XSS-Protection "1; mode=block"
        
        # Configuration pour l'authentification client (optionnel)
        # SSLVerifyClient require
        # SSLCACertificateFile $CA_DIR/ca.crt
        
        <Directory "/var/www/$PROJECT_NAME/htdocs">
            AllowOverride All
            Require all granted
        </Directory>
        
        ErrorLog \${APACHE_LOG_DIR}/$PROJECT_NAME-ssl-error.log
        CustomLog \${APACHE_LOG_DIR}/$PROJECT_NAME-ssl-access.log combined
    </VirtualHost>
</IfModule>
EOF

sudo tee "/etc/apache2/sites-available/001-$PROJECT_NAME-redirect.conf" > /dev/null << EOF
<VirtualHost *:80>
    ServerName $DOMAIN
    Redirect permanent / https://$DOMAIN/
</VirtualHost>
EOF

sudo a2ensite "001-$PROJECT_NAME-ssl.conf"
sudo a2ensite "001-$PROJECT_NAME-redirect.conf"

if [ "$PROJECT_NAME" = "dolibarr" ] || [ "$PROJECT_NAME" = "glpi" ]; then
    sudo a2dissite "001-$PROJECT_NAME.conf" 2>/dev/null || true
fi

sudo systemctl reload apache2