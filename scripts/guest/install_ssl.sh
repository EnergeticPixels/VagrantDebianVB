#!/bin/bash
# Generate self-signed SSL certificates and configure Apache for HTTPS
# Usage: install_ssl.sh <domain>
# Example: install_ssl.sh web.local

set -euo pipefail

DOMAIN="${1:-web.local}"
CERT_DIR="/etc/ssl/certs"
KEY_DIR="/etc/ssl/private"
CERT_FILE="${CERT_DIR}/${DOMAIN}.crt"
KEY_FILE="${KEY_DIR}/${DOMAIN}.key"
VHOST_CONFIG="/etc/apache2/sites-available/${DOMAIN}.conf"

echo "=========================================="
echo "SSL Certificate Setup for: $DOMAIN"
echo "=========================================="

# Check if certificates already exist
if [[ -f "$CERT_FILE" && -f "$KEY_FILE" ]]; then
    echo "✓ SSL certificates already exist for $DOMAIN"
    echo "  Certificate: $CERT_FILE"
    echo "  Key: $KEY_FILE"
    # Still ensure SSL module is enabled and vhost is configured
else
    echo "→ Generating self-signed SSL certificate..."
    
    # Generate private key (2048-bit RSA)
    openssl genrsa -out "$KEY_FILE" 2048 2>/dev/null
    echo "  ✓ Private key created: $KEY_FILE"
    
    # Generate self-signed certificate (valid for 365 days)
    # Using -subj to avoid interactive prompt
    openssl req -new -x509 \
        -key "$KEY_FILE" \
        -out "$CERT_FILE" \
        -days 365 \
        -subj "/C=US/ST=Development/L=Development/O=Development/CN=${DOMAIN}" \
        2>/dev/null
    
    echo "  ✓ Self-signed certificate created: $CERT_FILE"
    
    # Set secure permissions
    chmod 600 "$KEY_FILE"
    chmod 644 "$CERT_FILE"
    echo "  ✓ Permissions set correctly"
fi

# Enable Apache SSL module (idempotent - safe to run multiple times)
echo "→ Enabling Apache SSL module..."
a2enmod ssl >/dev/null 2>&1 && echo "  ✓ SSL module enabled" || echo "  ✓ SSL module already enabled"

# Create Apache virtual host configuration
echo "→ Configuring Apache virtual host..."

cat > "$VHOST_CONFIG" <<EOF
# HTTP vhost - redirects all traffic to HTTPS
<VirtualHost *:80>
    ServerName ${DOMAIN}
    ServerAlias www.${DOMAIN}
    DocumentRoot /var/www/html
    
    # Redirect all HTTP traffic to HTTPS
    RewriteEngine On
    RewriteCond %{HTTPS} off
    RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]
</VirtualHost>

# HTTPS vhost - serves content over SSL
<VirtualHost *:443>
    ServerName ${DOMAIN}
    ServerAlias www.${DOMAIN}
    DocumentRoot /var/www/html
    
    # Enable SSL
    SSLEngine on
    SSLCertificateFile ${CERT_FILE}
    SSLCertificateKeyFile ${KEY_FILE}
    
    # Optional: Additional SSL configuration for security
    SSLProtocol all -SSLv2 -SSLv3 -TLSv1 -TLSv1.1
    SSLCipherSuite ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256
    SSLHonorCipherOrder on
    
    # Standard headers
    Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"
</VirtualHost>
EOF

echo "  ✓ Virtual host configuration created: $VHOST_CONFIG"

# Enable the site (idempotent)
echo "→ Enabling Apache site..."
a2ensite "${DOMAIN}.conf" >/dev/null 2>&1 && echo "  ✓ Site enabled" || echo "  ✓ Site already enabled"

# Enable mod_rewrite for HTTP→HTTPS redirect
echo "→ Enabling Apache rewrite module..."
a2enmod rewrite >/dev/null 2>&1 && echo "  ✓ Rewrite module enabled" || echo "  ✓ Rewrite module already enabled"

# Enable mod_headers for HSTS security headers
echo "→ Enabling Apache headers module..."
a2enmod headers >/dev/null 2>&1 && echo "  ✓ Headers module enabled" || echo "  ✓ Headers module already enabled"

# Test Apache configuration
echo "→ Testing Apache configuration..."
if apache2ctl configtest > /dev/null 2>&1; then
    echo "  ✓ Configuration is valid"
else
    echo "  ✗ Configuration error detected"
    apache2ctl configtest
    exit 1
fi

# Reload Apache to apply changes
echo "→ Reloading Apache..."
systemctl reload apache2
echo "  ✓ Apache reloaded"

echo ""
echo "=========================================="
echo "✓ SSL Setup Complete!"
echo "=========================================="
echo "Domain: $DOMAIN"
echo "Certificate: $CERT_FILE"
echo "Private Key: $KEY_FILE"
echo "Config: $VHOST_CONFIG"
echo ""
echo "Access your site at: https://${DOMAIN}"
echo "HTTP traffic will auto-redirect to HTTPS"
echo ""
echo "Note: Browsers will show a security warning for"
echo "self-signed certificates. This is expected in development."
echo "=========================================="
