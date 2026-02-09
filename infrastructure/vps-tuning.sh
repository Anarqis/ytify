#!/bin/bash

# YTFY VPS System Tuning Script
# Run as root: sudo bash infrastructure/vps-tuning.sh

set -e

echo "🔧 Starting VPS system tuning for YTFY..."

# Backup original sysctl.conf
if [ ! -f /etc/sysctl.conf.backup ]; then
    echo "📦 Backing up /etc/sysctl.conf..."
    cp /etc/sysctl.conf /etc/sysctl.conf.backup
fi

# Network optimizations
echo "🌐 Applying network optimizations..."
cat >> /etc/sysctl.conf << 'EOF'

# ============================================
# YTFY Performance Optimizations
# ============================================

# Increase connection backlog
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535

# Enable TCP TIME-WAIT socket reuse
net.ipv4.tcp_tw_reuse = 1

# Increase local port range
net.ipv4.ip_local_port_range = 1024 65535

# Increase netdev backlog
net.core.netdev_max_backlog = 262144

# Reduce FIN timeout
net.ipv4.tcp_fin_timeout = 15

# TCP keepalive settings
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_intvl = 15

# Enable TCP Fast Open
net.ipv4.tcp_fastopen = 3

# Increase TCP buffer sizes
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864

# Enable TCP window scaling
net.ipv4.tcp_window_scaling = 1

# Increase max number of file descriptors
fs.file-max = 2097152

# Increase inotify watches (for file monitoring)
fs.inotify.max_user_watches = 524288

# Reduce swappiness (prefer RAM over swap)
vm.swappiness = 10

# Increase dirty page ratio (better write performance)
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5

EOF

# Apply sysctl changes
echo "✅ Applying sysctl changes..."
sysctl -p

# File descriptor limits
echo "📁 Configuring file descriptor limits..."
if ! grep -q "YTFY Performance" /etc/security/limits.conf; then
    cat >> /etc/security/limits.conf << 'EOF'

# YTFY Performance Optimizations
* soft nofile 65535
* hard nofile 65535
root soft nofile 65535
root hard nofile 65535

EOF
fi

# PAM limits
echo "🔐 Configuring PAM limits..."
if ! grep -q "pam_limits.so" /etc/pam.d/common-session; then
    echo "session required pam_limits.so" >> /etc/pam.d/common-session
fi

# Nginx user limits
echo "🚀 Configuring Nginx worker limits..."
mkdir -p /etc/systemd/system/nginx.service.d/
cat > /etc/systemd/system/nginx.service.d/limits.conf << 'EOF'
[Service]
LimitNOFILE=65535
LimitNPROC=65535
EOF

# Deno backend service limits
echo "🦕 Configuring Deno backend limits..."
mkdir -p /etc/systemd/system/ytify-backend.service.d/
cat > /etc/systemd/system/ytify-backend.service.d/limits.conf << 'EOF'
[Service]
LimitNOFILE=65535
LimitNPROC=65535
EOF

# Reload systemd
systemctl daemon-reload

# Create cache directory for Nginx
echo "📦 Creating Nginx cache directory..."
mkdir -p /var/cache/nginx/ytify
chown -R www-data:www-data /var/cache/nginx/ytify
chmod -R 755 /var/cache/nginx/ytify

# Verify changes
echo ""
echo "✅ System tuning complete!"
echo ""
echo "📊 Current settings:"
echo "  - Max connections: $(sysctl net.core.somaxconn | awk '{print $3}')"
echo "  - File descriptors: $(ulimit -n)"
echo "  - TCP Fast Open: $(sysctl net.ipv4.tcp_fastopen | awk '{print $3}')"
echo ""
echo "⚠️  IMPORTANT: Reboot required for all changes to take effect"
echo "   Run: sudo reboot"
