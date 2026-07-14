# Frappe Framework v16 Installation

This repository contains installation scripts for Frappe Framework v16 on Ubuntu 22.04 LTS.

## Installation Options

### 1. Docker Installation (Recommended)

The Docker installation provides a containerized setup with all dependencies isolated and properly configured.

#### Quick Start

```bash
# Make the script executable
chmod +x install_docker.sh

# Run the installation
bash install_docker.sh
```

#### What gets installed:
- Docker and Docker Compose
- MariaDB 10.6 container
- Redis 7 container  
- Frappe Framework v16 container
- Nginx reverse proxy container

#### Access:
- **Main Application**: http://frappe.localhost
- **Direct Access**: http://localhost:8081
- **Default Login**: Administrator / admin

#### Docker Commands:
```bash
# Start services
docker-compose up -d

# Stop services
docker-compose down

# View logs
docker-compose logs -f

# Enter Frappe container
docker-compose exec frappe bash

# Restart services
docker-compose restart
```

### 2. Native Installation

The native installation installs Frappe directly on the Ubuntu system.

#### Quick Start

```bash
# Make the script executable
chmod +x install_frappe_ubuntu24.sh

# Run the installation
bash install_frappe_ubuntu24.sh
```

#### Access:
- **Application**: http://frappe.localhost:8081
- **Default Login**: Administrator / admin

## Files Structure

```
.
├── install_docker.sh           # Docker-based installation script
├── install_frappe_ubuntu24.sh  # Native installation script  
├── docker-compose.yml          # Docker services configuration
├── Dockerfile                  # Frappe container image
├── start.sh                    # Container startup script
├── supervisord.conf            # Process management config
├── mariadb.cnf                 # MariaDB configuration
├── nginx.conf                  # Nginx configuration
├── apps/                       # Directory for external apps
└── README.md                   # This file
```

## Post-Installation

### Security (Important!)
1. **Change default passwords immediately**
2. Configure firewall rules
3. Set up SSL certificates for production
4. Regular backups

### Development
```bash
# Enter Frappe bench (Docker)
docker-compose exec frappe bash
cd /home/frappe/frappe-bench

# Enter Frappe bench (Native)
sudo -u frappe bash
cd /home/frappe/frappe-bench

# Common bench commands
bench start                                    # Start development server
bench new-site <sitename>                    # Create new site
bench --site <sitename> install-app <app>    # Install app
bench migrate                                 # Run migrations
bench --site <sitename> set-config developer_mode 1  # Enable dev mode
```

### Adding Custom Apps

#### Docker Installation
1. Place your app in the `apps/` directory
2. Rebuild containers: `docker-compose up --build -d`

#### Native Installation
```bash
cd /home/frappe/frappe-bench
bench get-app <app-source>
bench --site <sitename> install-app <appname>
```

## Troubleshooting

### Docker Issues
```bash
# Check container status
docker-compose ps

# View container logs
docker-compose logs -f frappe

# Restart all services
docker-compose restart

# Rebuild containers
docker-compose up --build -d
```

### Permission Issues (Native)
```bash
# Fix bench permissions
sudo chown -R frappe:frappe /home/frappe/frappe-bench

# Add user to required groups
sudo usermod -aG sudo frappe
```

### Database Connection Issues
- Ensure MariaDB service is running
- Check database credentials in site config
- Verify network connectivity between services

## System Requirements

- Ubuntu 22.04 LTS (recommended)
- 4GB RAM minimum (8GB recommended)
- 20GB free disk space
- Docker and Docker Compose (for Docker installation)

## Ports Used

### Docker Installation
- **80**: Nginx reverse proxy
- **8081**: Direct Frappe access  
- **3306**: MariaDB (exposed for external access)

### Native Installation
- **8081**: Frappe web interface
- **3306**: MariaDB
- **6379**: Redis

## Default Credentials

- **Frappe Admin**: Administrator / admin
- **Database**: frappe / frappe
- **MariaDB Root**: root / frappe

**⚠️ Change these passwords immediately after installation!**

## Support

For issues and questions:
1. Check the logs for error messages
2. Verify all services are running
3. Ensure proper file permissions
4. Review Frappe Framework documentation

## License

This installation script is provided as-is for educational and development purposes.