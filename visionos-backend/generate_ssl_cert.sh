#!/bin/bash
# Generate self-signed SSL certificate for development

echo "🔒 Generating SSL certificate for development..."

mkdir -p ssl

# Generate private key
openssl genrsa -out ssl/server.key 2048

# Generate certificate signing request
openssl req -new -key ssl/server.key -out ssl/server.csr -subj "/C=US/ST=CA/L=SF/O=VisionOS/CN=localhost"

# Generate self-signed certificate
openssl x509 -req -days 365 -in ssl/server.csr -signkey ssl/server.key -out ssl/server.crt

# Generate PEM format for some applications
cat ssl/server.crt ssl/server.key > ssl/server.pem

echo "✅ SSL certificate generated in ssl/ directory"
echo "⚠️  This is a self-signed certificate for development only"
