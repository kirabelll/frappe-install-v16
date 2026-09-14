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

# --- 2. Choose ONE of the ExecStart lines below ---

# OPTION A: Token-based tunnel (recommended, simplest)
# Replace YOUR_TUNNEL_TOKEN with your actual token from the Cloudflare Zero Trust dashboard
EXEC_START="$CLOUDFLARED_BIN tunnel run --token 9ee345d8-6234-4dfd-8a2d-4e6734ca357b"

# OPTION B: Config-file-based tunnel (comment out Option A above, uncomment this)
# EXEC_START="$CLOUDFLARED_BIN tunnel --config /etc/cloudflared/config.yml run"

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
User=root
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