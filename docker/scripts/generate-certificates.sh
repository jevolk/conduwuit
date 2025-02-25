#!/bin/sh
# Generate keys for server
openssl genpkey  -algorithm RSA -pkeyopt rsa_keygen_bits:2048 --out conduwuit-key.pem
openssl req -x509 -new -key conduwuit-key.pem -out conduwuit-cert.pem  -subj "/C=PE/ST=Lima/L=Lima/O=Acme Inc. /OU=IT Department/CN=acme.com"
