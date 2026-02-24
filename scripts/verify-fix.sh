#!/bin/bash

# 🔍 Script de Vérification - Cloudflare Cache Fix
# Ce script vérifie si le problème de cache Cloudflare est résolu

echo "🔍 Vérification du Fix Cloudflare..."
echo "=================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# URLs à tester
YTIFY_URL="https://ytify.ml4-lab.com"
MUSIC_URL="https://music.ml4-lab.com"
VPS_IP="100.92.200.92"

# Test 1: Vérifier CSP Headers via Cloudflare
echo "📋 Test 1: Vérification Headers CSP (via Cloudflare)"
echo "=================================================="

CSP_HEADER=$(curl -sI "$YTIFY_URL/" | grep -i "content-security-policy:" | head -n 1)

if [[ -z "$CSP_HEADER" ]]; then
    echo -e "${RED}❌ ERREUR: Aucun header CSP trouvé${NC}"
    exit 1
fi

echo "CSP Header reçu:"
echo "$CSP_HEADER" | head -c 200
echo "..."
echo ""

# Vérifier présence des domaines critiques
MISSING_DOMAINS=()
REQUIRED_DOMAINS=(
    "invidious.f5.si"
    "yt.omada.cafe"
    "invidious.darkness.services"
    "invidious.reallyaweso.me"
    "invidious.materialio.us"
    "inv.vern.cc"
    "y.com.sb"
)

for domain in "${REQUIRED_DOMAINS[@]}"; do
    if echo "$CSP_HEADER" | grep -q "$domain"; then
        echo -e "${GREEN}✅ $domain - Présent${NC}"
    else
        echo -e "${RED}❌ $domain - MANQUANT${NC}"
        MISSING_DOMAINS+=("$domain")
    fi
done

echo ""

# Test 2: Vérifier Cache Status
echo "📦 Test 2: Vérification Cache Status"
echo "====================================="

CACHE_STATUS=$(curl -sI "$YTIFY_URL/" | grep -i "cf-cache-status:" | awk '{print $2}' | tr -d '\r')

echo "Cache Status: $CACHE_STATUS"

if [[ "$CACHE_STATUS" == "HIT" ]]; then
    echo -e "${YELLOW}⚠️  AVERTISSEMENT: Cache encore actif (HIT)${NC}"
    echo "   → Le cache Cloudflare sert toujours du contenu caché"
    echo "   → Purger à nouveau ou attendre quelques minutes"
elif [[ "$CACHE_STATUS" == "MISS" ]] || [[ "$CACHE_STATUS" == "EXPIRED" ]] || [[ "$CACHE_STATUS" == "DYNAMIC" ]]; then
    echo -e "${GREEN}✅ Cache Status OK ($CACHE_STATUS)${NC}"
else
    echo -e "${YELLOW}⚠️  Cache Status inconnu: $CACHE_STATUS${NC}"
fi

echo ""

# Test 3: Vérifier DNS/Proxy Status
echo "🌐 Test 3: Vérification DNS/Proxy"
echo "=================================="

DNS_IP=$(dig +short music.ml4-lab.com A | head -n 1)

if [[ -z "$DNS_IP" ]]; then
    echo -e "${RED}❌ ERREUR: Impossible de résoudre music.ml4-lab.com${NC}"
else
    echo "DNS résolu: $DNS_IP"

    if [[ "$DNS_IP" == "100.92.200.92" ]]; then
        echo -e "${YELLOW}⚠️  Proxy Cloudflare DÉSACTIVÉ (DNS direct vers VPS)${NC}"
        echo "   → Headers Nginx appliqués directement"
        echo "   → Pas de protection DDoS/CDN Cloudflare"
    elif [[ "$DNS_IP" =~ ^104\. ]] || [[ "$DNS_IP" =~ ^172\. ]]; then
        echo -e "${GREEN}✅ Proxy Cloudflare ACTIVÉ (IP Cloudflare)${NC}"
        echo "   → Cache doit être purgé pour voir nouveaux headers"
    else
        echo -e "${YELLOW}⚠️  IP inattendue: $DNS_IP${NC}"
    fi
fi

echo ""

# Test 4: Vérifier VPS Direct (sans Cloudflare)
echo "🖥️  Test 4: Vérification VPS Direct"
echo "===================================="

VPS_RESPONSE=$(curl -sI "http://$VPS_IP/" -H "Host: ytify.ml4-lab.com" | head -n 1)

if [[ "$VPS_RESPONSE" =~ "200" ]] || [[ "$VPS_RESPONSE" =~ "404" ]]; then
    echo -e "${GREEN}✅ VPS accessible (Nginx répond)${NC}"
else
    echo -e "${RED}❌ VPS ne répond pas correctement${NC}"
    echo "   Réponse: $VPS_RESPONSE"
fi

echo ""

# Test 5: Vérifier Nginx CSP sur VPS
echo "🔧 Test 5: Vérification Nginx CSP (sur VPS)"
echo "============================================"

if command -v ssh &> /dev/null; then
    echo "Tentative de connexion SSH au VPS..."

    VPS_CSP=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "root@$VPS_IP" \
        "curl -sI http://localhost -H 'Host: ytify.ml4-lab.com' | grep -i 'content-security-policy:'" 2>/dev/null)

    if [[ -n "$VPS_CSP" ]]; then
        echo "CSP Nginx (sur VPS):"
        echo "$VPS_CSP" | head -c 200
        echo "..."

        # Vérifier présence domaines sur VPS
        VPS_MISSING=()
        for domain in "${REQUIRED_DOMAINS[@]}"; do
            if echo "$VPS_CSP" | grep -q "$domain"; then
                echo -e "${GREEN}✅ $domain - Présent sur VPS${NC}"
            else
                echo -e "${RED}❌ $domain - MANQUANT sur VPS${NC}"
                VPS_MISSING+=("$domain")
            fi
        done
    else
        echo -e "${YELLOW}⚠️  Impossible de se connecter au VPS via SSH${NC}"
        echo "   (Normal si SSH key non configuré)"
    fi
else
    echo -e "${YELLOW}⚠️  SSH non disponible sur ce système${NC}"
fi

echo ""
echo "=================================="
echo "📊 RÉSUMÉ"
echo "=================================="
echo ""

if [[ ${#MISSING_DOMAINS[@]} -eq 0 ]]; then
    echo -e "${GREEN}✅ SUCCÈS: Tous les domaines Invidious sont présents dans le CSP${NC}"
    echo ""
    echo "Actions suivantes:"
    echo "1. Fermer COMPLÈTEMENT votre navigateur"
    echo "2. Rouvrir et aller sur https://music.ml4-lab.com"
    echo "3. Appuyer Ctrl+Shift+R (force reload)"
    echo "4. Ouvrir Console (F12) et exécuter le script de nettoyage Service Worker"
    echo "5. Tester une recherche"
else
    echo -e "${RED}❌ PROBLÈME: ${#MISSING_DOMAINS[@]} domaine(s) manquant(s) dans le CSP${NC}"
    echo ""
    echo "Domaines manquants:"
    for domain in "${MISSING_DOMAINS[@]}"; do
        echo "  - $domain"
    done
    echo ""
    echo "Actions requises:"

    if [[ "$CACHE_STATUS" == "HIT" ]]; then
        echo "1. ⚠️  Purger à nouveau le cache Cloudflare (encore en cache)"
        echo "2. Attendre 1-2 minutes"
        echo "3. Relancer ce script"
    else
        echo "1. Vérifier que la configuration Nginx contient tous les domaines"
        echo "2. Recharger Nginx: systemctl reload nginx"
        echo "3. Purger cache Cloudflare"
        echo "4. Relancer ce script"
    fi
fi

echo ""
echo "=================================="
echo "Pour plus d'infos, voir: FIX_CLOUDFLARE_NOW.md"
echo "=================================="
