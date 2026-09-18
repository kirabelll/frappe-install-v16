#!/bin/bash
# setup-cloudflared-service.sh
# Sets up cloudflared to run automatically as a systemd service on Ubuntu

set -e

CLOUDFLARED_BIN="/usr/local/bin/cloudflared"
SERVICE_FILE="/etc/systemd/system/cloudflared.service"

# --- 1. Check cloudflared is installed ---
if ! command -v cloudflared &> /dev/null; then
    echo "cloudflared not found. Installing..."
    curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    sudo dpkg -i cloudflared.deb
    rm cloudflared.deb
fi

CLOUDFLARED_BIN=$(command -v cloudflared)
echo "Using cloudflared at: $CLOUDFLARED_BIN"

# Tunnel configuration
TUNNEL_ID="9ee345d8-6234-4dfd-8a2d-4e6734ca357b"
CRED_FILE="/home/frappe/.cloudflared/9ee345d8-6234-4dfd-8a2d-4e6734ca357b.json"
CONFIG_FILE="/home/frappe/.cloudflared/config.yml"

# --- 2. Choose Execution Mode ---
# OPTION A: Credentials-file-based tunnel (matches your JSON credentials file)
EXEC_START="$CLOUDFLARED_BIN tunnel --credentials-file $CRED_FILE run $TUNNEL_ID"

# OPTION B: Config-file-based tunnel (uncomment if you have a config.yml with ingress rules)
# EXEC_START="$CLOUDFLARED_BIN tunnel --config $CONFIG_FILE run"

# --- 3. Write the systemd unit file ---
sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Cloudflare Tunnel
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
ExecStart=$EXEC_START
Restart=on-failure
RestartSec=5
User=frappe
Group=frappe
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

# --- 4. Reload systemd and enable the service ---
sudo systemctl daemon-reload
sudo systemctl enable cloudflared
sudo systemctl restart cloudflared

echo ""
echo "Done. Checking status:"
sudo systemctl status cloudflared --no-pager
