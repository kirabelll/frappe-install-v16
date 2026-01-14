#!/bin/bash

# Frappe Framework Version 16 Installation Script for Ubuntu 24.04 LTS
# This script installs Frappe Framework v16 with all dependencies
# Run with: bash install_frappe_ubuntu24.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   error "This script should not be run as root. Please run as a regular user with sudo privileges."
fi

# Check Ubuntu version
if ! grep -q "24.04" /etc/os-release; then
    warning "This script is designed for Ubuntu 24.04 LTS. Proceeding anyway..."
fi

log "Starting Frappe Framework v16 installation on Ubuntu 24.04 LTS"

# Update system packages
log "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install system dependencies
log "Installing system dependencies..."
sudo apt install -y \
    python3-dev \
    python3-pip \
    python3-venv \
    python3-setuptools \
    software-properties-common \
    mariadb-server \
    mariadb-client \
    redis-server \
    xvfb \
    libfontconfig \
    wkhtmltopdf \
    git \
    curl \
    wget \
    nginx \
    supervisor \
    cron \
    build-essential \
    libssl-dev \
    libffi-dev \
    libxml2-dev \
    libxslt1-dev \
    libjpeg-dev \
    libpng-dev \
    zlib1g-dev \
    libmysqlclient-dev \
    pkg-config \
    fail2ban

# Install Node.js 18 (required for Frappe v16)
log "Installing Node.js 18..."
curl -fsSL https://deb.nodesource.com/setp_18.x | sudo -E bash -
sudo apt install -y nodejs

# Verify Node.js installation
node_version=$(node --version)
npm_version=$(npm --version)
log "Node.js version: $node_version"
log "npm version: $npm_version"

# Install Yarn
log "Installing Yarn..."
sudo npm install -g yarn

# Configure MariaDB
log "Configuring MariaDB..."
sudo systemctl start mariadb
sudo systemctl enable mariadb

# Secure MariaDB installation
log "Securing MariaDB installation..."
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'frappe';"
sudo mysql -e "DELETE FROM mysql.user WHERE User='';"
sudo mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
sudo mysql -e "DROP DATABASE IF EXISTS test;"
sudo mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
sudo mysql -e "FLUSH PRIVILEGES;"

# Configure MariaDB for Frappe
log "Configuring MariaDB for Frappe...
sudo tee /etc/mysql/mariadb.conf.d/frappe.cnf > /dev/null <<EOF
[mysqld]
character-set-client-handshake = FALSE
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci

[mysql]
default-character-set = utf8mb4
EOF

sudo systemctl restart mariadb

# Start and enable Redis
log "Starting Redis server..."
sudo systemctl start redis-server
sudo systemctl enable redis-server

# Create frappe user
log "Creating frappe user..."
sudo adduser --disabled-password --gecos "" frappe
sudo usermod -aG sudo frappe

# Install bench
log "Installing bench..."
sudo -H pip3 install frappe-bench

# Switch to frappe user and setup bench
log "Setting up bench as frappe user..."
sudo -u frappe bash <<'EOF'
cd /home/frappe

# Initialize bench with Frappe v16
bench init --frappe-branch version-16 frappe-bench
cd frappe-bench

# Create a new site
bench new-site frappe.localhost --admin-password admin --mariadb-root-password frappe_root_password

# Set developer mode
bench --site frappe.localhost set-config developer_mode 1
# Enable scheduler
bench --site frappe.localhost enable-scheduler

# Setup production configuration        
sudo bench setup production frappe --yes

EOF

# Configure Nginx (basic configuration)
log "Configuring Nginx..."
sudo tee /etc/nginx/sites-available/frappe.localhost > /dev/null <<EOF
server {
    listen 80;
    server_name frappe.localhost;
    
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/frappe.localhost /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# Add frappe.localhost to hosts file
log "Adding frappe.localhost to hosts file..."
echo "127.0.0.1 frappe.localhost" | sudo tee -a /etc/hosts

# Create systemd service for bench
log "Creating systemd service for bench..."
sudo tee /etc/systemd/system/frappe.service > /dev/null <<EOF
[Unit]
Description=Frappe web server
After=network.target


[Service]
Type=simple
User=frappe
WorkingDirectory=/home/frappe/frappe-bench
ExecStart=/usr/local/bin/bench start
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable frappe

# Set proper permissions
log "Setting proper permissions..."
sudo chown -R frappe:frappe /home/frappe/frappe-bench

# Save passwords to file
log "Saving passwords to file..."
sudo tee /home/frappe/frappe_passwords.txt > /dev/null <<EOF
Frappe Installation Passwords:
=============================
MariaDB Root Password: frappe_root_password
Frappe Administrator Password: admin
Site: frappe.localhost

Access URLs:
============
Local: http://frappe.localhost:8000
Development: http://127.0.0.1:8000

Commands to start development server:
====================================
sudo -u frappe bash
cd /home/frappe/frappe-bench
bench start

Production setup (optional):
============================
sudo bench setup production frappe
EOF

sudo chown frappe:frappe /home/frappe/frappe_passwords.txt

log "Installation completed successfully!"
info "Passwords saved to: /home/frappe/frappe_passwords.txt"
info "To start development server:"
info "  sudo -u frappe bash"
info "  cd /home/frappe/frappe-bench"
info "  bench start"
info ""
info "Access your site at: http://frappe.localhost:8000"
info "Default login: Administrator / admin"
info ""
warning "Remember to change default passwords in production!"
# Configure fail2ban
log "Configuring fail2ban..."
sudo systemctl start fail2ban
sudo systemctl enable fail2ban

# Final system checks
log "Performing final system checks..."
sudo systemctl status mariadb --no-pager
sudo systemctl status redis-server --no-pager
sudo systemctl status nginx --no-pager

# Start frappe service
log "Starting Frappe service..."
sudo systemctl start frappe

log "Installation completed successfully!"
info "Passwords saved to: /home/frappe/frappe_passwords.txt"
info ""
info "=== IMPORTANT NEXT STEPS ==="
info "1. Access your site at: http://frappe.localhost"
info "2. Default login: Administrator / admin"
info "3. Change default passwords immediately!"
info ""
info "=== DEVELOPMENT MODE ==="
info "To start development server manually:"
info "  sudo -u frappe bash"
info "  cd /home/frappe/frappe-bench"
info "  bench start"
info ""
info "=== PRODUCTION MODE ==="
info "Production setup is already configured and running"
info "Services: nginx, supervisor, mariadb, redis"
info ""
warning "Remember to:"
warning "- Change default passwords"
warning "- Configure firewall rules"
warning "- Set up SSL certificates for production"
warning "- Regular backups"