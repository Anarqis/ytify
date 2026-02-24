#!/bin/bash
mkdir -p /etc/nginx/snippets
cat > /etc/nginx/snippets/security.conf << 'EOF'
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
EOF

# Add include if not already added
for conf in /etc/nginx/sites-available/ytify.ml4-lab.conf /etc/nginx/sites-available/music.ml4-lab.conf; do
  if ! grep -q "snippets/security.conf" "$conf"; then
    sed -i '/ssl_certificate_key/a \    include snippets/security.conf;' "$conf"
  fi
done

nginx -t && systemctl reload nginx
