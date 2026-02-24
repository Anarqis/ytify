#!/bin/bash

# 🔄 Restaurer le CSP après diagnostic

echo "🔄 RESTAURATION DU CSP"
echo "====================="
echo ""

VPS_IP="100.92.200.92"

ssh root@$VPS_IP << 'EOF'
    # Réactiver CSP (décommenter)
    sed -i 's/^# DISABLED-FOR-TESTING \(.*\)/\1/' /etc/nginx/sites-available/ytify

    # Vérifier
    nginx -t

    if [ $? -eq 0 ]; then
        systemctl reload nginx
        echo "✅ CSP RÉACTIVÉ"
    else
        echo "❌ Erreur - Vérifier manuellement"
    fi
EOF

echo ""
echo "Terminé."
