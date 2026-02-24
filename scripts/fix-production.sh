#!/bin/bash

# ============================================
# YTFY Production Fix Script
# ============================================
# Quick-fix pour résoudre les problèmes identifiés dans DIAGNOSTIC_REPORT.md
# Run: bash scripts/fix-production.sh [option]
#
# Options:
#   quickfix    - Fix CSP sur music.ml4-lab.conf (5 min)
#   unify       - Nettoyage complet et unification (30 min)
#   dns         - Affiche les instructions DNS
# ============================================

set -e

VPS_HOST="root@100.92.200.92"
VPS_DIR="/var/www/ytify"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# CSP corrigé complet
CSP_FIXED='add_header Content-Security-Policy "default-src '\''self'\''; script-src '\''self'\'' '\''unsafe-inline'\'' '\''unsafe-eval'\'' https://accounts.google.com https://apis.google.com blob:; style-src '\''self'\'' '\''unsafe-inline'\''; img-src '\''self'\'' data: https: blob:; media-src '\''self'\'' blob: https://*.googlevideo.com https://*.youtube.com https://*.invidious.io https://inv.nadeko.net https://invidious.nerdvpn.de https://invidious.private.coffee https://invidious.protokolla.fi https://iv.melmac.space https://*.zeabur.app https://invidious.f5.si https://y.com.sb https://inv.vern.cc https://invidious.darkness.services https://invidious.reallyaweso.me https://yt.omada.cafe https://invidious.materialio.us; connect-src '\''self'\'' https://accounts.google.com https://www.googleapis.com https://oauth2.googleapis.com https://*.googlevideo.com https://*.youtube.com https://*.ytimg.com https://*.invidious.io https://*.piped.video https://rapid-email-verifier.fly.dev https://uma.instinct.rip https://raw.githubusercontent.com https://*.vercel.app https://inv.nadeko.net https://invidious.nerdvpn.de https://invidious.private.coffee https://invidious.protokolla.fi https://iv.melmac.space https://*.zeabur.app https://invidious.f5.si https://y.com.sb https://inv.vern.cc https://invidious.darkness.services https://invidious.reallyaweso.me https://yt.omada.cafe https://invidious.materialio.us wss:; font-src '\''self'\'' data:; frame-src '\''self'\'' https://accounts.google.com; frame-ancestors '\''self'\''; base-uri '\''self'\''; form-action '\''self'\''; worker-src '\''self'\'' blob:; manifest-src '\''self'\'';" always;'

function print_header() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo ""
}

function print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

function print_error() {
    echo -e "${RED}❌ $1${NC}"
}

function print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

function check_ssh() {
    print_header "Vérification de la connexion SSH"

    if ! ssh -o ConnectTimeout=5 "$VPS_HOST" "echo 'SSH OK'"; then
        print_error "Impossible de se connecter au VPS"
        exit 1
    fi
    print_success "Connexion SSH établie"
    echo ""
}

function quickfix_csp() {
    print_header "QUICK-FIX: Correction CSP sur music.ml4-lab.conf"

    check_ssh

    echo "📦 Backup de la config actuelle..."
    ssh "$VPS_HOST" "mkdir -p /root/nginx-backups && cp /etc/nginx/sites-available/music.ml4-lab.conf /root/nginx-backups/music.ml4-lab.conf.backup-\$(date +%Y%m%d-%H%M%S)"
    print_success "Backup créé"

    echo ""
    echo "🔧 Mise à jour du CSP..."
    ssh "$VPS_HOST" "bash -s" <<'ENDSSH'
        # Lire la config actuelle
        if [ ! -f /etc/nginx/sites-available/music.ml4-lab.conf ]; then
            echo "❌ Config music.ml4-lab.conf introuvable!"
            exit 1
        fi

        # Chercher et remplacer la ligne CSP
        if grep -q "Content-Security-Policy" /etc/nginx/sites-available/music.ml4-lab.conf; then
            echo "✅ CSP existant trouvé, remplacement..."
            # Créer un fichier temporaire avec le nouveau CSP
            cat > /tmp/new_csp.txt <<'EOF'
    # Content Security Policy - Full Invidious Support
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval' https://accounts.google.com https://apis.google.com blob:; style-src 'self' 'unsafe-inline'; img-src 'self' data: https: blob:; media-src 'self' blob: https://*.googlevideo.com https://*.youtube.com https://*.invidious.io https://inv.nadeko.net https://invidious.nerdvpn.de https://invidious.private.coffee https://invidious.protokolla.fi https://iv.melmac.space https://*.zeabur.app https://invidious.f5.si https://y.com.sb https://inv.vern.cc https://invidious.darkness.services https://invidious.reallyaweso.me https://yt.omada.cafe https://invidious.materialio.us; connect-src 'self' https://accounts.google.com https://www.googleapis.com https://oauth2.googleapis.com https://*.googlevideo.com https://*.youtube.com https://*.ytimg.com https://*.invidious.io https://*.piped.video https://rapid-email-verifier.fly.dev https://uma.instinct.rip https://raw.githubusercontent.com https://*.vercel.app https://inv.nadeko.net https://invidious.nerdvpn.de https://invidious.private.coffee https://invidious.protokolla.fi https://iv.melmac.space https://*.zeabur.app https://invidious.f5.si https://y.com.sb https://inv.vern.cc https://invidious.darkness.services https://invidious.reallyaweso.me https://yt.omada.cafe https://invidious.materialio.us wss:; font-src 'self' data:; frame-src 'self' https://accounts.google.com; frame-ancestors 'self'; base-uri 'self'; form-action 'self'; worker-src 'self' blob:; manifest-src 'self';" always;
EOF

            # Supprimer l'ancien CSP et insérer le nouveau
            sed -i '/Content-Security-Policy/d' /etc/nginx/sites-available/music.ml4-lab.conf
            # Trouver la ligne des Security Headers et ajouter après
            sed -i '/# Security Headers/r /tmp/new_csp.txt' /etc/nginx/sites-available/music.ml4-lab.conf
        else
            echo "⚠️  Aucun CSP trouvé, ajout d'un nouveau..."
            # Ajouter après les Security Headers
            sed -i '/# Security Headers/a \    # Content Security Policy - Full Invidious Support\n    add_header Content-Security-Policy "default-src '\''self'\''; script-src '\''self'\'' '\''unsafe-inline'\'' '\''unsafe-eval'\'' https://accounts.google.com https://apis.google.com blob:; style-src '\''self'\'' '\''unsafe-inline'\''; img-src '\''self'\'' data: https: blob:; media-src '\''self'\'' blob: https://*.googlevideo.com https://*.youtube.com https://*.invidious.io https://inv.nadeko.net https://invidious.nerdvpn.de https://invidious.private.coffee https://invidious.protokolla.fi https://iv.melmac.space https://*.zeabur.app https://invidious.f5.si https://y.com.sb https://inv.vern.cc https://invidious.darkness.services https://invidious.reallyaweso.me https://yt.omada.cafe https://invidious.materialio.us; connect-src '\''self'\'' https://accounts.google.com https://www.googleapis.com https://oauth2.googleapis.com https://*.googlevideo.com https://*.youtube.com https://*.ytimg.com https://*.invidious.io https://*.piped.video https://rapid-email-verifier.fly.dev https://uma.instinct.rip https://raw.githubusercontent.com https://*.vercel.app https://inv.nadeko.net https://invidious.nerdvpn.de https://invidious.private.coffee https://invidious.protokolla.fi https://iv.melmac.space https://*.zeabur.app https://invidious.f5.si https://y.com.sb https://inv.vern.cc https://invidious.darkness.services https://invidious.reallyaweso.me https://yt.omada.cafe https://invidious.materialio.us wss:; font-src '\''self'\'' data:; frame-src '\''self'\'' https://accounts.google.com; frame-ancestors '\''self'\''; base-uri '\''self'\''; form-action '\''self'\''; worker-src '\''self'\'' blob:; manifest-src '\''self'\'';" always;' /etc/nginx/sites-available/music.ml4-lab.conf
        fi

        echo "✅ CSP mis à jour"
ENDSSH

    print_success "CSP corrigé"

    echo ""
    echo "🧪 Test de la configuration Nginx..."
    if ssh "$VPS_HOST" "nginx -t 2>&1"; then
        print_success "Configuration Nginx valide"
    else
        print_error "Configuration Nginx invalide - restauration du backup..."
        ssh "$VPS_HOST" "cp /root/nginx-backups/music.ml4-lab.conf.backup-* /etc/nginx/sites-available/music.ml4-lab.conf | tail -1"
        exit 1
    fi

    echo ""
    echo "🔄 Rechargement de Nginx..."
    ssh "$VPS_HOST" "systemctl reload nginx"
    print_success "Nginx rechargé avec le nouveau CSP"

    echo ""
    print_header "✅ QUICK-FIX TERMINÉ"
    echo ""
    echo "Prochaines étapes:"
    echo "1. Ouvrez https://music.ml4-lab.com dans votre navigateur"
    echo "2. Ouvrez DevTools (F12) → Console"
    echo "3. Vérifiez qu'il n'y a plus d'erreurs CSP bloquant Invidious"
    echo "4. Testez la lecture audio et le chargement du Hub"
    echo ""
}

function unify_configs() {
    print_header "UNIFICATION COMPLÈTE DES CONFIGURATIONS"

    check_ssh

    echo "📦 Backup de toutes les configs..."
    ssh "$VPS_HOST" <<'ENDSSH'
        mkdir -p /root/nginx-backups
        BACKUP_DATE=$(date +%Y%m%d-%H%M%S)
        cp /etc/nginx/sites-available/ytify /root/nginx-backups/ytify.backup-$BACKUP_DATE
        cp /etc/nginx/sites-available/music.ml4-lab.conf /root/nginx-backups/music.ml4-lab.conf.backup-$BACKUP_DATE 2>/dev/null || true
        cp /etc/nginx/sites-enabled/ytify.conf /root/nginx-backups/ytify.conf.backup-$BACKUP_DATE 2>/dev/null || true
        echo "✅ Backups créés dans /root/nginx-backups/"
ENDSSH

    echo ""
    echo "🗑️  Suppression des configs redondantes..."
    ssh "$VPS_HOST" <<'ENDSSH'
        # Supprimer ytify.conf (direct file in sites-enabled)
        if [ -f /etc/nginx/sites-enabled/ytify.conf ]; then
            rm /etc/nginx/sites-enabled/ytify.conf
            echo "✅ ytify.conf supprimé"
        fi

        # Supprimer music.ml4-lab.conf
        if [ -f /etc/nginx/sites-enabled/music.ml4-lab.conf ]; then
            rm /etc/nginx/sites-enabled/music.ml4-lab.conf
            echo "✅ music.ml4-lab.conf supprimé"
        fi
ENDSSH

    echo ""
    echo "📁 Restructuration du frontend..."
    ssh "$VPS_HOST" <<'ENDSSH'
        # Créer la structure correcte
        if [ ! -d /var/www/ytify/current ]; then
            echo "Création de /var/www/ytify/current..."
            mkdir -p /var/www/ytify/current

            # Copier depuis dist si il existe
            if [ -d /var/www/ytify/dist ]; then
                echo "Copie du build depuis dist/..."
                cp -r /var/www/ytify/dist/* /var/www/ytify/current/
                echo "✅ Frontend copié dans current/"
            else
                echo "⚠️  Dossier dist/ introuvable - un nouveau build sera nécessaire"
            fi
        else
            echo "✅ /var/www/ytify/current existe déjà"
        fi

        # Permissions correctes
        chown -R www-data:www-data /var/www/ytify/current/
        chmod -R 755 /var/www/ytify/current/
        echo "✅ Permissions configurées"
ENDSSH

    echo ""
    echo "🔗 Activation de la config optimisée..."
    ssh "$VPS_HOST" <<'ENDSSH'
        # S'assurer que le symlink existe
        ln -sf /etc/nginx/sites-available/ytify /etc/nginx/sites-enabled/ytify
        echo "✅ Config ytify activée"
ENDSSH

    echo ""
    echo "🧪 Test de la configuration Nginx..."
    if ssh "$VPS_HOST" "nginx -t 2>&1"; then
        print_success "Configuration Nginx valide"
    else
        print_error "Configuration Nginx invalide - restauration des backups..."
        ssh "$VPS_HOST" <<'ENDSSH'
            LATEST_BACKUP=$(ls -t /root/nginx-backups/*.backup-* 2>/dev/null | head -1)
            if [ -n "$LATEST_BACKUP" ]; then
                echo "Restauration depuis: $LATEST_BACKUP"
                # Restaurer les configs
                cp /root/nginx-backups/ytify.backup-* /etc/nginx/sites-available/ytify 2>/dev/null | tail -1
                cp /root/nginx-backups/music.ml4-lab.conf.backup-* /etc/nginx/sites-available/music.ml4-lab.conf 2>/dev/null | tail -1
                cp /root/nginx-backups/ytify.conf.backup-* /etc/nginx/sites-enabled/ytify.conf 2>/dev/null | tail -1
            fi
ENDSSH
        exit 1
    fi

    echo ""
    echo "🔄 Rechargement de Nginx..."
    ssh "$VPS_HOST" "systemctl reload nginx"
    print_success "Nginx rechargé avec la config unifiée"

    echo ""
    echo "🧪 Vérification du déploiement..."
    ssh "$VPS_HOST" <<'ENDSSH'
        echo ""
        echo "=== Health Check ==="
        curl -s http://localhost:3000/health | head -5

        echo ""
        echo "=== Nginx Status ==="
        curl -I http://localhost 2>&1 | head -10

        echo ""
        echo "=== Configs actives ==="
        ls -lh /etc/nginx/sites-enabled/
ENDSSH

    echo ""
    print_header "✅ UNIFICATION TERMINÉE"
    echo ""
    print_warning "IMPORTANT: Vérifiez que le DNS pointe vers 159.195.45.46"
    echo ""
    echo "Vérification DNS:"
    echo "  nslookup ytify.ml4-lab.com 8.8.8.8"
    echo "  nslookup music.ml4-lab.com 8.8.8.8"
    echo ""
    echo "Si le DNS n'est pas correct, lancez:"
    echo "  bash scripts/fix-production.sh dns"
    echo ""
}

function show_dns_instructions() {
    print_header "INSTRUCTIONS CONFIGURATION DNS"

    echo "Votre VPS a l'IP publique: ${GREEN}159.195.45.46${NC}"
    echo ""
    echo "📝 Étapes pour corriger le DNS:"
    echo ""
    echo "1. Connectez-vous à votre panneau de gestion DNS (registrar de ml4-lab.com)"
    echo ""
    echo "2. Modifiez/Ajoutez les enregistrements suivants:"
    echo ""
    echo "   ${BLUE}Enregistrement 1:${NC}"
    echo "   Type: A"
    echo "   Name: ytify"
    echo "   Value: 159.195.45.46"
    echo "   TTL: 300 (5 minutes)"
    echo ""
    echo "   ${BLUE}Enregistrement 2:${NC}"
    echo "   Type: A"
    echo "   Name: music"
    echo "   Value: 159.195.45.46"
    echo "   TTL: 300 (5 minutes)"
    echo ""
    echo "3. ${YELLOW}Supprimez${NC} les enregistrements CNAME vers Netlify (si présents)"
    echo ""
    echo "4. Si vous utilisez Cloudflare:"
    echo "   - Désactivez le proxy (cloud gris) pour ces enregistrements"
    echo "   - OU configurez Cloudflare pour utiliser votre certificat Origin"
    echo ""
    echo "5. Vérifiez la propagation DNS (peut prendre 5 min à 48h):"
    echo ""
    echo "   ${BLUE}nslookup ytify.ml4-lab.com 8.8.8.8${NC}"
    echo "   ${BLUE}nslookup music.ml4-lab.com 8.8.8.8${NC}"
    echo ""
    echo "   Attendez que l'IP affichée soit: ${GREEN}159.195.45.46${NC}"
    echo ""
    print_header "FIN DES INSTRUCTIONS DNS"
}

# ============================================
# Main
# ============================================

if [ $# -eq 0 ]; then
    echo "Usage: $0 [option]"
    echo ""
    echo "Options:"
    echo "  quickfix    - Fix CSP sur music.ml4-lab.conf (5 min)"
    echo "  unify       - Nettoyage complet et unification (30 min)"
    echo "  dns         - Affiche les instructions DNS"
    echo ""
    echo "Exemple:"
    echo "  bash scripts/fix-production.sh quickfix"
    echo ""
    exit 1
fi

case "$1" in
    quickfix)
        quickfix_csp
        ;;
    unify)
        unify_configs
        ;;
    dns)
        show_dns_instructions
        ;;
    *)
        print_error "Option invalide: $1"
        echo "Options valides: quickfix, unify, dns"
        exit 1
        ;;
esac
