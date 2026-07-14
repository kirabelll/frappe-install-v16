#!/bin/bash

# Frappe Framework v16 Docker Installation Script for Ubuntu 22.04 LTS
# This script installs Frappe Framework v16 using Docker containers
# Run with: bash install_docker.sh

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

# Check Ubuntu version
if ! grep -q "22.04" /etc/os-release; then
    warning "This script is designed for Ubuntu 22.04 LTS. Proceeding anyway..."
fi

log "Starting Frappe Framework v16 Docker installation on Ubuntu 22.04 LTS"

# Update system packages
log "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install Docker dependencies
log "Installing Docker dependencies..."
sudo apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker GPG key
log "Adding Docker GPG key..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
log "Adding Docker repository..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package index
sudo apt update

# Install Docker
log "Installing Docker..."
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start and enable Docker
log "Starting Docker service..."
sudo systemctl start docker
sudo systemctl enable docker

# Add current user to docker group
log "Adding current user to docker group..."
sudo usermod -aG docker $USER

# Install Docker Compose (standalone)
log "Installing Docker Compose..."
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)
sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Verify Docker installation
log "Verifying Docker installation..."
sudo docker --version
docker-compose --version

# Create apps directory for external apps
log "Creating apps directory..."
mkdir -p apps

# Build and start Frappe containers
log "Building and starting Frappe containers..."
sudo docker-compose up --build -d

# Wait for services to be ready
log "Waiting for services to start..."
sleep 30

# Check container status
log "Checking container status..."
sudo docker-compose ps

# Add frappe.localhost to hosts file
log "Adding frappe.localhost to hosts file..."
if ! grep -q "frappe.localhost" /etc/hosts; then
    echo "127.0.0.1 frappe.localhost" | sudo tee -a /etc/hosts
fi

# Save installation information
log "Saving installation information..."
cat > frappe_docker_info.txt <<EOF
Frappe Framework v16 Docker Installation Complete
=================================================

Services Running:
- MariaDB Database: Port 3306
- Redis Cache: Internal network
- Frappe Application: Port 8081 (mapped to container port 8000)
- Nginx Reverse Proxy: Port 80

Access URLs:
============
Main Application: http://frappe.localhost
Direct Access: http://localhost:8081

Default Credentials:
===================
Username: Administrator
Password: admin

Database Credentials:
====================
Database Host: localhost:3306
Database Name: frappe
Username: frappe
Password: frappe
Root Password: frappe

Docker Commands:
===============
Start services:     docker-compose up -d
Stop services:      docker-compose down
View logs:          docker-compose logs -f
Restart services:   docker-compose restart
Enter container:    docker-compose exec frappe bash

Frappe Commands (inside container):
==================================
Enter bench:       docker-compose exec frappe bash
Bench directory:   /home/frappe/frappe-bench
Create new site:   bench new-site <sitename>
Install app:       bench --site <sitename> install-app <appname>
Enable developer:  bench --site <sitename> set-config developer_mode 1

Volumes:
========
- frappe_data: Frappe application data
- mariadb_data: Database data
- redis_data: Redis data

External Apps:
=============
Place custom apps in the 'apps' directory and rebuild:
docker-compose down
docker-compose up --build -d

Security Notes:
==============
- Change default passwords immediately
- Configure firewall rules for production
- Set up SSL certificates for production
- Regular backups of volumes
EOF

log "Installation completed successfully!"
info ""
info "=== FRAPPE FRAMEWORK v16 DOCKER INSTALLATION COMPLETE ==="
info ""
info "🚀 Access your site at: http://frappe.localhost"
info "🔑 Login: Administrator / admin"
info "📊 Direct access: http://localhost:8081"
info ""
info "📁 Installation info saved to: frappe_docker_info.txt"
info ""
info "🐳 Docker Commands:"
info "   Start:    docker-compose up -d"
info "   Stop:     docker-compose down"
info "   Logs:     docker-compose logs -f"
info "   Shell:    docker-compose exec frappe bash"
info ""
warning "⚠️  Important:"
warning "   - Change default passwords immediately!"
warning "   - You may need to log out and back in for Docker group permissions"
warning "   - For production: configure SSL, firewall, and regular backups"

# Show next steps
info ""
info "🔄 If you can't access the site, try:"
info "   1. Log out and back in (for Docker group permissions)"
info "   2. Check container status: docker-compose ps"
info "   3. View logs: docker-compose logs -f frappe"