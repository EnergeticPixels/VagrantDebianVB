#!/bin/bash
# Clean up SSL certificates and disable HTTPS configuration
# Usage: destroy_ssl.sh <domain>
# Example: destroy_ssl.sh web.local

set -euo pipefail

DOMAIN="${1:-web.local}"
CERT_DIR="/etc/ssl/certs"
KEY_DIR="/etc/ssl/private"
CERT_FILE="${CERT_DIR}/${DOMAIN}.crt"
KEY_FILE="${KEY_DIR}/${DOMAIN}.key"
VHOST_CONFIG="/etc/apache2/sites-available/${DOMAIN}.conf"

echo "=========================================="
echo "SSL Cleanup for: $DOMAIN"
echo "=========================================="

# Disable the site
echo "→ Disabling Apache site..."
if sudo a2dissite "${DOMAIN}.conf" >/dev/null 2>&1; then
    echo "  ✓ Site disabled"
else
    echo "  ✓ Site already disabled or not found"
fi

# Remove virtual host configuration
echo "→ Removing virtual host configuration..."
if [[ -f "$VHOST_CONFIG" ]]; then
    sudo rm -f "$VHOST_CONFIG"
    echo "  ✓ Virtual host config removed: $VHOST_CONFIG"
else
    echo "  ✓ Virtual host config not found"
fi

# Remove private key
echo "→ Removing private key..."
if [[ -f "$KEY_FILE" ]]; then
    sudo rm -f "$KEY_FILE"
    echo "  ✓ Private key removed: $KEY_FILE"
else
    echo "  ✓ Private key not found"
fi

# Remove certificate
echo "→ Removing certificate..."
if [[ -f "$CERT_FILE" ]]; then
    sudo rm -f "$CERT_FILE"
    echo "  ✓ Certificate removed: $CERT_FILE"
else
    echo "  ✓ Certificate not found"
fi

# Test Apache configuration
echo "→ Testing Apache configuration..."
if sudo apache2ctl configtest > /dev/null 2>&1; then
    echo "  ✓ Configuration is valid"
else
    echo "  ✗ Configuration error detected"
    sudo apache2ctl configtest
    exit 1
fi

# Reload Apache to apply changes
echo "→ Reloading Apache..."
sudo systemctl reload apache2
echo "  ✓ Apache reloaded"

echo ""
echo "=========================================="
echo "✓ SSL Cleanup Complete!"
echo "=========================================="
echo "Removed certificates and configuration for: $DOMAIN"
echo "=========================================="
