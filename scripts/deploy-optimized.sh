#!/bin/bash

# ============================================
# YTFY Performance Optimization Deployment
# ============================================
# This script automates the deployment of all performance optimizations to the VPS
# Run from local machine: bash scripts/deploy-optimized.sh

set -e

VPS_HOST="root@100.92.200.92"
VPS_DIR="/var/www/ytify"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🚀 Starting YTFY Performance Optimization Deployment"
echo "=================================================="

# ============================================
# Phase 1: Pre-deployment Checks
# ============================================
echo ""
echo "📋 Phase 1: Pre-deployment Checks"
echo "----------------------------------"

# Check SSH connectivity
echo "🔌 Testing SSH connection to VPS..."
if ! ssh -o ConnectTimeout=5 "$VPS_HOST" "echo 'SSH connection successful'"; then
    echo "❌ Cannot connect to VPS. Please check your SSH configuration."
    exit 1
fi
echo "✅ SSH connection verified"

# Check if Deno is installed on VPS
echo "🦕 Checking Deno installation on VPS..."
if ssh "$VPS_HOST" "command -v deno &> /dev/null"; then
    DENO_VERSION=$(ssh "$VPS_HOST" "deno --version | head -n1")
    echo "✅ Deno is installed: $DENO_VERSION"
else
    echo "⚠️  Deno not found. Will install during deployment."
    INSTALL_DENO=true
fi

# Check if Nginx is installed
echo "🌐 Checking Nginx installation on VPS..."
if ssh "$VPS_HOST" "command -v nginx &> /dev/null"; then
    NGINX_VERSION=$(ssh "$VPS_HOST" "nginx -v 2>&1")
    echo "✅ Nginx is installed: $NGINX_VERSION"
else
    echo "❌ Nginx not found on VPS. Please install Nginx first."
    exit 1
fi

# ============================================
# Phase 2: Install Dependencies on VPS
# ============================================
echo ""
echo "📦 Phase 2: Installing Dependencies"
echo "------------------------------------"

if [ "$INSTALL_DENO" = true ]; then
    echo "🦕 Installing Deno..."
    ssh "$VPS_HOST" "curl -fsSL https://deno.land/install.sh | sh"
    ssh "$VPS_HOST" "echo 'export DENO_INSTALL=\"\$HOME/.deno\"' >> ~/.bashrc"
    ssh "$VPS_HOST" "echo 'export PATH=\"\$DENO_INSTALL/bin:\$PATH\"' >> ~/.bashrc"
    echo "✅ Deno installed"
fi

# Check for Brotli module
echo "🗜️  Checking Nginx Brotli module..."
if ssh "$VPS_HOST" "nginx -V 2>&1 | grep -q brotli"; then
    echo "✅ Brotli module already installed"
else
    echo "⚠️  Brotli module not found. Installing nginx-extras..."
    ssh "$VPS_HOST" "apt update && apt install -y nginx-extras libnginx-mod-http-brotli-filter libnginx-mod-http-brotli-static"
    echo "✅ Brotli module installed"
fi

# Install Redis if not present
echo "💾 Checking Redis installation..."
if ssh "$VPS_HOST" "command -v redis-cli &> /dev/null"; then
    echo "✅ Redis is installed"
else
    echo "📥 Installing Redis..."
    ssh "$VPS_HOST" "apt install -y redis-server"
    ssh "$VPS_HOST" "systemctl enable redis-server && systemctl start redis-server"
    echo "✅ Redis installed and started"
fi

# ============================================
# Phase 3: VPS System Tuning
# ============================================
echo ""
echo "⚙️  Phase 3: VPS System Tuning"
echo "-------------------------------"

echo "📤 Uploading VPS tuning script..."
scp "$PROJECT_ROOT/infrastructure/vps-tuning.sh" "$VPS_HOST:/tmp/vps-tuning.sh"

echo "🔧 Running VPS tuning script..."
ssh "$VPS_HOST" "bash /tmp/vps-tuning.sh"
echo "✅ VPS system tuning complete"

# ============================================
# Phase 4: Deploy Optimized Nginx Config
# ============================================
echo ""
echo "🌐 Phase 4: Deploying Optimized Nginx Configuration"
echo "----------------------------------------------------"

# Backup current config
echo "📦 Backing up current Nginx configuration..."
ssh "$VPS_HOST" "cp /etc/nginx/sites-available/ytify /etc/nginx/sites-available/ytify.backup-\$(date +%Y%m%d-%H%M%S)"

# Upload new config
echo "📤 Uploading optimized Nginx configuration..."
scp "$PROJECT_ROOT/ytify.nginx.optimized.conf" "$VPS_HOST:/tmp/ytify.nginx.optimized.conf"

# Test configuration
echo "🧪 Testing Nginx configuration..."
ssh "$VPS_HOST" "cp /tmp/ytify.nginx.optimized.conf /etc/nginx/sites-available/ytify && nginx -t"

if [ $? -eq 0 ]; then
    echo "✅ Nginx configuration test passed"
    echo "🔄 Reloading Nginx..."
    ssh "$VPS_HOST" "systemctl reload nginx"
    echo "✅ Nginx reloaded with optimized configuration"
else
    echo "❌ Nginx configuration test failed. Rolling back..."
    ssh "$VPS_HOST" "cp /etc/nginx/sites-available/ytify.backup-* /etc/nginx/sites-available/ytify | tail -1"
    exit 1
fi

# ============================================
# Phase 5: Deploy Backend
# ============================================
echo ""
echo "🦕 Phase 5: Deploying Backend"
echo "------------------------------"

echo "📤 Syncing backend code..."
rsync -avz --delete "$PROJECT_ROOT/backend/" "$VPS_HOST:$VPS_DIR/backend/"

echo "🔄 Restarting backend service..."
ssh "$VPS_HOST" "systemctl restart ytify-backend"

# Wait for backend to start
sleep 3

# Check backend status
if ssh "$VPS_HOST" "systemctl is-active --quiet ytify-backend"; then
    echo "✅ Backend service is running"
else
    echo "⚠️  Backend service may have issues. Check logs with: journalctl -u ytify-backend -f"
fi

# ============================================
# Phase 6: Deploy Frontend
# ============================================
echo ""
echo "🎨 Phase 6: Deploying Frontend"
echo "-------------------------------"

echo "🏗️  Building frontend locally..."
cd "$PROJECT_ROOT"
npm run build

echo "📤 Syncing frontend build..."
rsync -avz --delete "$PROJECT_ROOT/dist/" "$VPS_HOST:$VPS_DIR/current/"

echo "✅ Frontend deployed"

# ============================================
# Phase 7: Verification
# ============================================
echo ""
echo "✅ Phase 7: Post-Deployment Verification"
echo "-----------------------------------------"

# Test health endpoint
echo "🏥 Testing health endpoint..."
if curl -f -s https://ytify.ml4-lab.com/health > /dev/null; then
    echo "✅ Health check passed"
else
    echo "⚠️  Health check failed"
fi

# Check cache headers
echo "📦 Verifying cache headers..."
CACHE_HEADER=$(curl -s -I https://ytify.ml4-lab.com/ | grep -i "x-cache-status" || echo "Not found")
echo "   Cache Status: $CACHE_HEADER"

# Check compression
echo "🗜️  Verifying Brotli compression..."
BROTLI_HEADER=$(curl -s -H "Accept-Encoding: br" -I https://ytify.ml4-lab.com/ | grep -i "content-encoding: br" || echo "Not found")
if [ "$BROTLI_HEADER" != "Not found" ]; then
    echo "✅ Brotli compression active"
else
    echo "⚠️  Brotli compression not detected"
fi

# Check HTTP/3
echo "🚀 Verifying HTTP/3 support..."
HTTP3_HEADER=$(curl -s -I https://ytify.ml4-lab.com/ | grep -i "alt-svc" || echo "Not found")
if [ "$HTTP3_HEADER" != "Not found" ]; then
    echo "✅ HTTP/3 advertised: $HTTP3_HEADER"
else
    echo "⚠️  HTTP/3 not detected (may require nginx with http_v3_module)"
fi

# ============================================
# Summary
# ============================================
echo ""
echo "=================================================="
echo "🎉 Deployment Complete!"
echo "=================================================="
echo ""
echo "📊 Next Steps:"
echo "  1. Monitor logs: ssh $VPS_HOST 'journalctl -u ytify-backend -f'"
echo "  2. Check Nginx logs: ssh $VPS_HOST 'tail -f /var/log/nginx/error.log'"
echo "  3. Run Lighthouse audit on https://ytify.ml4-lab.com"
echo "  4. Verify cache hit rates in Prometheus (if monitoring is set up)"
echo ""
echo "⚠️  IMPORTANT: VPS reboot required for all system tuning changes to take effect"
echo "   Run: ssh $VPS_HOST 'reboot'"
echo ""
