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

# Check if Docker is already installed
if command -v docker &> /dev/null && command -v docker-compose &> /dev/null; then
    info "Docker is already installed:"
    docker --version
    docker-compose --version
    
    # Check if Docker service is running
    if ! sudo systemctl is-active --quiet docker; then
        log "Starting Docker service..."
        sudo systemctl start docker
        sudo systemctl enable docker
    else
        info "Docker service is already running"
    fi
    
    # Add current user to docker group if not already added
    if ! groups $USER | grep -q docker; then
        log "Adding current user to docker group..."
        sudo usermod -aG docker $USER
        warning "You may need to log out and back in for Docker group permissions"
    else
        info "User is already in docker group"
    fi
else
    log "Docker not found. Installing Docker..."
    
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
    
    log "Docker installation completed successfully!"
fi

# Check if Frappe containers are already running
if sudo docker-compose ps | grep -q "Up"; then
    info "Frappe containers are already running:"
    sudo docker-compose ps
    
    # Ask if user wants to recreate containers
    read -p "Frappe containers are already running. Do you want to recreate them? (y/N): " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Stopping existing containers..."
        sudo docker-compose down
        
        log "Removing old containers and images..."
        sudo docker-compose rm -f
        
        log "Building and starting fresh Frappe containers..."
        sudo docker-compose up --build -d
    else
        info "Keeping existing containers running"
    fi
else
    # Create apps directory for external apps
    log "Creating apps directory..."
    mkdir -p apps

    # Build and start Frappe containers
    log "Building and starting Frappe containers..."
    sudo docker-compose up --build -d
fi

# Wait for services to be ready and setup complete
log "Starting Frappe containers and waiting for setup to complete..."
sleep 10

# Monitor container startup
log "Monitoring container startup..."
for i in {1..30}; do
    if sudo docker-compose ps | grep -q "Up"; then
        log "Containers are running, checking Frappe initialization..."
        
        # Check if bench initialization is complete
        if sudo docker-compose exec -T frappe test -f /home/frappe/frappe-bench/sites/common_site_config.json 2>/dev/null; then
            log "Frappe initialization complete!"
            break
        else
            info "Waiting for Frappe initialization... ($i/30)"
        fi
    else
        warning "Containers still starting... ($i/30)"
    fi
    sleep 10
done

# Check final container status and provide detailed info
log "Checking final container status..."
sudo docker-compose ps

# Verify Frappe installation
log "Verifying Frappe installation..."
if sudo docker-compose exec -T frappe bench --version 2>/dev/null; then
    BENCH_VERSION=$(sudo docker-compose exec -T frappe bench --version 2>/dev/null || echo "Unknown")
    log "Bench version: $BENCH_VERSION"
else
    warning "Could not verify bench installation"
fi

# Test site accessibility
log "Testing site accessibility..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8081 | grep -q "200\|302"; then
    log "✅ Frappe site is accessible at http://localhost:8081"
else
    warning "⚠️  Site may still be starting up. Check logs with: docker-compose logs -f frappe"
fi

# Add frappe.localhost to hosts file
log "Adding frappe.localhost to hosts file..."
if ! grep -q "frappe.localhost" /etc/hosts; then
    echo "127.0.0.1 frappe.localhost" | sudo tee -a /etc/hosts
else
    info "frappe.localhost already exists in hosts file"
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

Container Management:
====================
Enter Frappe container: docker-compose exec frappe bash
View all logs:          docker-compose logs -f  
View Frappe logs:       docker-compose logs -f frappe
Restart containers:     docker-compose restart
Stop containers:        docker-compose down
Start containers:       docker-compose up -d

Frappe Bench Commands (inside container):
========================================
Enter container:        docker-compose exec frappe bash
Navigate to bench:      cd /home/frappe/frappe-bench
Create new site:        bench new-site mysite.local
Install app:            bench --site mysite.local install-app erpnext
List sites:             bench --site all list-apps
Update apps:            bench update
Migrate database:       bench migrate

Site Configuration:
==================
Enable developer mode:  bench --site frappe.localhost set-config developer_mode 1
Disable developer mode: bench --site frappe.localhost set-config developer_mode 0
Set maintenance mode:   bench --site frappe.localhost set-maintenance-mode on

Security Notes:
==============
- Change default passwords immediately
- Configure firewall rules for production
- Set up SSL certificates for production
- Regular backups of volumes
EOF

log "Frappe Framework v16 Docker installation completed successfully!"
info ""
info "=== 🎉 FRAPPE FRAMEWORK v16 INSTALLATION COMPLETE ==="
info ""
info "🌐 Access URLs:"
info "   Main Site:     http://frappe.localhost"
info "   Direct Access: http://localhost:8081"
info ""
info "🔑 Login Credentials:"
info "   Username: Administrator"
info "   Password: admin"
info ""
info "�️  Database Access:"
info "   Host:     localhost:3306"
info "   Database: frappe"
info "   User:     frappe"  
info "   Password: frappe"
info ""
info "🐳 Container Status:"
sudo docker-compose ps
info ""
info "📁 Files & Volumes:"
info "   Installation info: frappe_docker_info.txt"
info "   Custom apps dir:   ./apps/"
info "   Database volume:   frappe-install-v16_mariadb_data"
info "   App data volume:   frappe-install-v16_frappe_data"
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
if ! groups $USER | grep -q docker; then
    warning "   - You may need to log out and back in for Docker group permissions"
fi
warning "   - For production: configure SSL, firewall, and regular backups"

# Show next steps
info ""
info "🔄 If you can't access the site, try:"
if ! groups $USER | grep -q docker; then
    info "   1. Log out and back in (for Docker group permissions)"
fi
info "   2. Check container status: docker-compose ps"
info "   3. View logs: docker-compose logs -f frappe"
info "   4. Wait a few minutes for initial setup to complete"