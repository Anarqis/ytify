#!/bin/bash

# Quick deployment script for Windows (uses scp instead of rsync)
# Usage: bash scripts/deploy-quick.sh

set -e

VPS_HOST="root@100.92.200.92"
VPS_DIR="/var/www/ytify"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🚀 Quick Deployment to VPS"
echo "=========================="

# ============================================
# Phase 1: Build Frontend
# ============================================
echo ""
echo "🏗️  Phase 1: Building Frontend"
echo "-------------------------------"
cd "$PROJECT_ROOT"
npm run build

echo "✅ Frontend built"

# ============================================
# Phase 2: Deploy Frontend
# ============================================
echo ""
echo "📤 Phase 2: Deploying Frontend"
echo "-------------------------------"

# Create temporary archive
echo "📦 Creating deployment archive..."
cd dist
tar -czf ../deploy.tar.gz .
cd ..

echo "📤 Uploading to VPS..."
scp deploy.tar.gz "$VPS_HOST:/tmp/deploy.tar.gz"

echo "📦 Extracting on VPS..."
ssh "$VPS_HOST" "mkdir -p $VPS_DIR/current && tar -xzf /tmp/deploy.tar.gz -C $VPS_DIR/current && rm /tmp/deploy.tar.gz"

echo "🧹 Cleaning up..."
rm deploy.tar.gz

echo "✅ Frontend deployed"

# ============================================
# Phase 3: Deploy Backend
# ============================================
echo ""
echo "🦕 Phase 3: Deploying Backend"
echo "------------------------------"

echo "📦 Creating backend archive..."
cd "$PROJECT_ROOT/backend"
tar -czf ../backend-deploy.tar.gz .
cd ..

echo "📤 Uploading backend to VPS..."
scp backend-deploy.tar.gz "$VPS_HOST:/tmp/backend-deploy.tar.gz"

echo "📦 Extracting backend on VPS..."
ssh "$VPS_HOST" "mkdir -p $VPS_DIR/backend && tar -xzf /tmp/backend-deploy.tar.gz -C $VPS_DIR/backend && rm /tmp/backend-deploy.tar.gz"

echo "🧹 Cleaning up..."
rm backend-deploy.tar.gz

echo "🔄 Restarting backend service..."
ssh "$VPS_HOST" "systemctl restart ytify-backend"

# Wait for backend to start
sleep 3

# Check backend status
if ssh "$VPS_HOST" "systemctl is-active --quiet ytify-backend"; then
    echo "✅ Backend service is running"
else
    echo "⚠️  Backend service may have issues. Check logs with: ssh $VPS_HOST journalctl -u ytify-backend -f"
fi

# ============================================
# Phase 4: Verification
# ============================================
echo ""
echo "✅ Phase 4: Verification"
echo "-------------------------"

# Test health endpoint
echo "🏥 Testing health endpoint..."
if curl -f -s https://ytify.ml4-lab.com/health > /dev/null 2>&1; then
    echo "✅ Health check passed"
else
    echo "⚠️  Health check failed (this is OK if /health doesn't exist)"
fi

# Test main page
echo "🌐 Testing main page..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://ytify.ml4-lab.com/)
if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Main page accessible (HTTP $HTTP_CODE)"
else
    echo "⚠️  Main page returned HTTP $HTTP_CODE"
fi

# ============================================
# Summary
# ============================================
echo ""
echo "=========================="
echo "🎉 Deployment Complete!"
echo "=========================="
echo ""
echo "📊 Test your deployment:"
echo "  🌐 Visit: https://ytify.ml4-lab.com"
echo "  📊 View logs: ssh $VPS_HOST 'journalctl -u ytify-backend -f'"
echo "  📝 Nginx logs: ssh $VPS_HOST 'tail -f /var/log/nginx/error.log'"
echo ""
