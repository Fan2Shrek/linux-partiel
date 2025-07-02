#!/bin/bash

PROJECT_NAME=$1
OUTPUT_DIR=$(pwd)/certs

if [ -z "$PROJECT_NAME" ]; then
  echo "Usage: $0 <certificate-name>"
  exit 1
fi

if [ ! -d "$OUTPUT_DIR" ]; then
  mkdir -p "$OUTPUT_DIR"
fi

NAME="$OUTPUT_DIR/$PROJECT_NAME"

openssl genrsa -out $NAME.key 4096
openssl req -x509 -new -key $NAME.key -days 30 -out $NAME.pem
openssl x509 -in $NAME.pem -inform PEM -out $NAME.crt

echo "Certificate and key files created"

## Apache things

cat /etc/apache2/sites-available/default-ssl.conf \
	| sed "s#SSLCertificateFile      /etc/ssl/certs/ssl-cert-snakeoil.pem#SSLCertificateFile $NAME.crt#" \
	| sed "s#SSLCertificateKeyFile   /etc/ssl/private/ssl-cert-snakeoil.key#SSLCertificateKeyFile $NAME.key#" \
	| sed "s#/var/www/html#/var/www/$PROJECT_NAME#" \
	>> /etc/apache2/sites-available/001-$PROJECT_NAME.conf

systemctl reload apache2
