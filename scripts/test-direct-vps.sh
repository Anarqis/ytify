#!/bin/bash

# 🧪 Test Direct VPS - Sans Cloudflare
# Ce script teste si Nginx sur le VPS a la bonne configuration CSP

echo "🧪 Test Direct VPS - Configuration Nginx"
echo "========================================="
echo ""

VPS_IP="100.92.200.92"
DOMAIN="ytify.ml4-lab.com"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Domaines requis dans le CSP
REQUIRED_DOMAINS=(
    "invidious.f5.si"
    "yt.omada.cafe"
    "invidious.darkness.services"
    "invidious.reallyaweso.me"
    "invidious.materialio.us"
    "inv.vern.cc"
    "y.com.sb"
)

echo "📡 Test 1: Connexion VPS Direct (sans Cloudflare)"
echo "=================================================="

# Tester connexion directe via IP
RESPONSE=$(curl -sI "http://$VPS_IP/" -H "Host: $DOMAIN" --connect-timeout 5)

if [[ -z "$RESPONSE" ]]; then
    echo -e "${RED}❌ ERREUR: Impossible de se connecter au VPS${NC}"
    echo "   IP: $VPS_IP"
    echo "   Vérifier que le VPS est accessible"
    exit 1
fi

echo -e "${GREEN}✅ VPS accessible${NC}"
echo ""

# Extraire le CSP header
echo "📋 Test 2: Vérification Header CSP du VPS"
echo "=========================================="

CSP_HEADER=$(echo "$RESPONSE" | grep -i "content-security-policy:" | head -n 1)

if [[ -z "$CSP_HEADER" ]]; then
    echo -e "${RED}❌ ERREUR: Aucun header CSP trouvé sur le VPS${NC}"
    echo ""
    echo "Headers reçus:"
    echo "$RESPONSE"
    exit 1
fi

echo "CSP Header (VPS Nginx):"
echo "$CSP_HEADER"
echo ""

# Vérifier chaque domaine requis
echo "🔍 Test 3: Vérification Domaines Invidious"
echo "==========================================="

MISSING_DOMAINS=()
FOUND_DOMAINS=()

for domain in "${REQUIRED_DOMAINS[@]}"; do
    if echo "$CSP_HEADER" | grep -q "$domain"; then
        echo -e "${GREEN}✅ $domain${NC}"
        FOUND_DOMAINS+=("$domain")
    else
        echo -e "${RED}❌ $domain - MANQUANT${NC}"
        MISSING_DOMAINS+=("$domain")
    fi
done

echo ""

# Test 4: Vérifier présence zeabur (devrait être présent mais blacklisté côté frontend)
echo "⚠️  Test 4: Vérification Zeabur (devrait être présent)"
echo "======================================================"

if echo "$CSP_HEADER" | grep -q "zeabur.app"; then
    echo -e "${GREEN}✅ zeabur.app présent dans CSP${NC}"
    echo "   (Blacklist gérée côté frontend)"
else
    echo -e "${YELLOW}⚠️  zeabur.app absent du CSP${NC}"
    echo "   (Pas critique, mais attendu)"
fi

echo ""

# Résumé
echo "========================================="
echo "📊 RÉSUMÉ"
echo "========================================="
echo ""

echo "Domaines trouvés: ${#FOUND_DOMAINS[@]}/${#REQUIRED_DOMAINS[@]}"
echo "Domaines manquants: ${#MISSING_DOMAINS[@]}"
echo ""

if [[ ${#MISSING_DOMAINS[@]} -eq 0 ]]; then
    echo -e "${GREEN}✅ SUCCÈS: Nginx VPS a la bonne configuration CSP${NC}"
    echo ""
    echo "Le problème vient donc de Cloudflare qui cache les anciens headers."
    echo ""
    echo "Actions recommandées:"
    echo "1. Désactiver temporairement le proxy Cloudflare (orange → gris)"
    echo "2. Tester le site directement via VPS"
    echo "3. Si ça fonctionne, réactiver le proxy avec Page Rules"
    echo ""
    echo "Voir: SOLUTION_RADICALE.md"
else
    echo -e "${RED}❌ PROBLÈME: Nginx VPS n'a pas tous les domaines Invidious${NC}"
    echo ""
    echo "Domaines manquants sur VPS:"
    for domain in "${MISSING_DOMAINS[@]}"; do
        echo "  - $domain"
    done
    echo ""
    echo "Actions requises:"
    echo "1. Vérifier le fichier Nginx: /etc/nginx/sites-available/ytify"
    echo "2. S'assurer que tous les domaines sont présents"
    echo "3. Recharger Nginx: systemctl reload nginx"
    echo "4. Relancer ce test"
fi

echo ""
echo "========================================="

# Test supplémentaire via SSH si disponible
echo ""
echo "🔧 Test 5 (optionnel): Vérification Fichier Nginx sur VPS"
echo "==========================================================="

if command -v ssh &> /dev/null; then
    echo "Tentative connexion SSH..."

    # Tester SSH
    ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "root@$VPS_IP" "exit" 2>/dev/null

    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ SSH accessible${NC}"
        echo ""

        # Vérifier fichier Nginx
        echo "Vérification fichier Nginx..."

        NGINX_FILE=$(ssh "root@$VPS_IP" "cat /etc/nginx/sites-available/ytify 2>/dev/null")

        if [[ -n "$NGINX_FILE" ]]; then
            echo "Fichier Nginx trouvé: /etc/nginx/sites-available/ytify"
            echo ""

            # Compter les domaines dans le fichier
            for domain in "${REQUIRED_DOMAINS[@]}"; do
                COUNT=$(echo "$NGINX_FILE" | grep -c "$domain")
                if [[ $COUNT -ge 2 ]]; then
                    echo -e "${GREEN}✅ $domain - Présent ($COUNT occurrences)${NC}"
                elif [[ $COUNT -eq 1 ]]; then
                    echo -e "${YELLOW}⚠️  $domain - Présent mais 1 seule occurrence (devrait être 2)${NC}"
                else
                    echo -e "${RED}❌ $domain - Absent du fichier Nginx${NC}"
                fi
            done

            echo ""

            # Vérifier que le fichier est bien activé
            ENABLED=$(ssh "root@$VPS_IP" "ls -la /etc/nginx/sites-enabled/ | grep ytify")

            if [[ -n "$ENABLED" ]]; then
                echo -e "${GREEN}✅ Configuration Nginx activée (symlink exists)${NC}"
            else
                echo -e "${RED}❌ Configuration Nginx NON activée${NC}"
                echo "   Exécuter: ln -s /etc/nginx/sites-available/ytify /etc/nginx/sites-enabled/"
            fi

            echo ""

            # Tester config Nginx
            NGINX_TEST=$(ssh "root@$VPS_IP" "nginx -t 2>&1")
            if echo "$NGINX_TEST" | grep -q "test is successful"; then
                echo -e "${GREEN}✅ Configuration Nginx valide${NC}"
            else
                echo -e "${RED}❌ Erreur configuration Nginx:${NC}"
                echo "$NGINX_TEST"
            fi

        else
            echo -e "${RED}❌ Fichier Nginx introuvable sur VPS${NC}"
        fi

    else
        echo -e "${YELLOW}⚠️  SSH non accessible (normal si pas configuré)${NC}"
        echo "   Connectez-vous manuellement pour vérifier:"
        echo "   ssh root@$VPS_IP"
        echo "   cat /etc/nginx/sites-available/ytify | grep 'invidious.f5.si'"
    fi
else
    echo -e "${YELLOW}⚠️  SSH non disponible sur ce système${NC}"
fi

echo ""
echo "========================================="
echo "Pour plus d'infos, voir: SOLUTION_RADICALE.md"
echo "========================================="
