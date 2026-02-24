#!/bin/bash

# 🔥 Script d'urgence - Désactiver CSP temporairement
# Pour diagnostic uniquement - DANGEREUX en production

echo "🔥 DÉSACTIVATION TEMPORAIRE DU CSP"
echo "=================================="
echo ""
echo "⚠️  AVERTISSEMENT: Ceci désactive la sécurité CSP"
echo "    À utiliser UNIQUEMENT pour diagnostic"
echo ""

read -p "Continuer? (oui/non): " confirm

if [[ "$confirm" != "oui" ]]; then
    echo "Annulé."
    exit 0
fi

VPS_IP="100.92.200.92"

echo ""
echo "📡 Connexion au VPS..."

# Backup de la config actuelle
ssh root@$VPS_IP << 'EOF'
    # Backup
    cp /etc/nginx/sites-available/ytify /etc/nginx/sites-available/ytify.backup-$(date +%Y%m%d-%H%M%S)
    echo "✅ Backup créé"

    # Désactiver CSP (commenter la ligne)
    sed -i 's/^\(\s*add_header Content-Security-Policy.*\)/# DISABLED-FOR-TESTING \1/' /etc/nginx/sites-available/ytify

    # Vérifier la config
    nginx -t

    if [ $? -eq 0 ]; then
        # Recharger Nginx
        systemctl reload nginx
        echo ""
        echo "✅ CSP DÉSACTIVÉ (temporairement)"
        echo ""
        echo "TESTEZ MAINTENANT:"
        echo "1. Aller sur https://music.ml4-lab.com"
        echo "2. Ctrl+Shift+R"
        echo "3. Tester une recherche"
        echo ""
        echo "Si ça MARCHE = le problème était le CSP"
        echo "Si ça NE MARCHE PAS = le problème est ailleurs"
    else
        echo "❌ Erreur dans la config Nginx"
        echo "Restoration du backup..."
        mv /etc/nginx/sites-available/ytify.backup-* /etc/nginx/sites-available/ytify
    fi
EOF

echo ""
echo "=================================="
echo "Pour RÉACTIVER le CSP après le test:"
echo "  ./scripts/restore-csp.sh"
echo "=================================="
