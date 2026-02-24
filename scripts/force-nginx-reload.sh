#!/bin/bash

# Force Nginx Config Reload
# Usage: bash scripts/force-nginx-reload.sh

set -e

VPS_HOST="root@100.92.200.92"

echo "🔍 Vérification de la config Nginx actuelle..."
echo "================================================"

# Check current CSP in active config
echo ""
echo "1. CSP dans la config active:"
ssh "$VPS_HOST" "grep -A 2 'Content-Security-Policy' /etc/nginx/sites-available/ytify | head -5"

# Check if specific domains are in CSP
echo ""
echo "2. Vérification des domaines Invidious dans CSP:"
ssh "$VPS_HOST" "grep 'yt.omada.cafe' /etc/nginx/sites-available/ytify && echo '✅ yt.omada.cafe présent' || echo '❌ yt.omada.cafe ABSENT'"
ssh "$VPS_HOST" "grep 'invidious.darkness.services' /etc/nginx/sites-available/ytify && echo '✅ darkness.services présent' || echo '❌ darkness.services ABSENT'"

# Test Nginx config
echo ""
echo "3. Test de la configuration Nginx..."
ssh "$VPS_HOST" "nginx -t"

# Force reload
echo ""
echo "4. Force reload Nginx..."
ssh "$VPS_HOST" "systemctl reload nginx"

# Wait a moment
sleep 2

# Check Nginx status
echo ""
echo "5. Statut Nginx:"
ssh "$VPS_HOST" "systemctl status nginx | head -15"

# Test local response
echo ""
echo "6. Test local (sur VPS):"
ssh "$VPS_HOST" "curl -I http://localhost 2>&1 | grep -i 'content-security-policy' | head -3"

echo ""
echo "================================================"
echo "✅ Nginx rechargé!"
echo ""
echo "IMPORTANT:"
echo "1. Purgez le cache Cloudflare maintenant"
echo "2. Attendez 30 secondes"
echo "3. Rechargez ytify.ml4-lab.com avec Ctrl+Shift+R"
echo ""
