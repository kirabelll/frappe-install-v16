# Frappe Framework v16 & ERPNext v16 Beta Installation Script for Ubuntu 24.04 LTS

This repository contains an automated installation script for Frappe Framework version 16 and ERPNext v16 Beta on Ubuntu 24.04 LTS.

## What is Frappe Framework & ERPNext?

**Frappe Framework** is a full-stack web application framework that uses Python and MariaDB on the server side with a tightly integrated client-side library.

**ERPNext** is a comprehensive ERP system built on Frappe Framework, offering modules for accounting, inventory, CRM, manufacturing, and more.

## Prerequisites

- Ubuntu 24.04 LTS server or desktop
- User account with sudo privileges
- Internet connection
- At least 4GB RAM and 20GB disk space
- Root access to MySQL during installation

## Quick Installation

1. Clone or download this repository
2. Make the script executable:
   ```bash
   chmod +x install_frappe_ubuntu24.sh
   ```
3. Run the installation script:
   ```bash
   bash install_frappe_ubuntu24.sh
   ```

## What the Script Installs

### System Dependencies
- Python 3 development tools
- MariaDB server and client
- Redis server
- Node.js 18 and Yarn
- Nginx web server
- Git, curl, wget
- Build tools and libraries
- wkhtmltopdf for PDF generation
- fail2ban for security
- Supervisor for process management

### Frappe Components
- Frappe Framework version 16
- ERPNext version 16 Beta
- Bench (Frappe's CLI tool)
- A new site at `frappe.localhost`
- Production-ready configuration

## Post-Installation

After successful installation:

1. **Access your site:**
   - URL: `http://frappe.localhost`
   - Username: `Administrator`
   - Password: `admin`

2. **For development mode:**
   ```bash
   sudo -u frappe bash
   cd /home/frappe/frappe-bench
   bench start
   ```
   Then access: `http://frappe.localhost:8000`

3. **Check installation details:**
   ```bash
   cat /home/frappe/frappe_passwords.txt
   ```

## Installation Steps Overview

The script follows these major steps:

1. **Initial Setup** - System updates and user verification
2. **Install Prerequisites** - Python, Node.js, system libraries
3. **Configure MariaDB** - Database server setup and security
4. **Install Additional Dependencies** - Redis, Nginx, build tools
5. **Install Frappe Bench** - Framework management tool
6. **Create New Site** - Site creation with ERPNext installation
7. **Production Setup** - Nginx, Supervisor configuration
8. **Security Configuration** - fail2ban setup

## Important Security Notes

⚠️ **Change default passwords immediately!**

- MariaDB root password: `frappe_root_password`
- Frappe Administrator password: `admin`

## Common Commands

### Development
```bash
# Switch to frappe user
sudo -u frappe bash

# Navigate to bench directory
cd /home/frappe/frappe-bench

# Start development server
bench start

# Create new app
bench new-app myapp

# Install app to site
bench --site frappe.localhost install-app myapp

# Update bench and apps
bench update

# Database migration
bench migrate
```

### Production Management
```bash
# Restart all services
sudo supervisorctl restart all

# Check service status
sudo systemctl status nginx
sudo systemctl status mariadb
sudo systemctl status redis-server

# Restart individual services
sudo systemctl restart nginx
sudo systemctl restart mariadb
```

## Troubleshooting Guide

### 1. Internal Server Error

**Possible Causes:**
- MySQL database issues
- Code errors in hooks.py

**Solutions:**
```bash
# Database migration
bench migrate

# Check MySQL status
sudo systemctl status mariadb

# Restart MySQL if needed
sudo systemctl restart mariadb
```

### 2. "Sorry! We will be back soon" Error

**Possible Cause:**
- Supervisor service issues

**Solution:**
```bash
# Restart supervisor
bench restart
# OR
sudo supervisorctl restart all
```

### 3. "This site can't be reached" Error

**Possible Causes:**
- fail2ban service blocking connections
- Nginx not running or misconfigured

**Solutions:**
```bash
# Stop fail2ban temporarily
sudo systemctl stop fail2ban

# Check and restart Nginx
sudo systemctl status nginx
sudo systemctl restart nginx

# Check Nginx configuration
sudo nginx -t
```

### 4. Permission Issues
```bash
# Fix ownership
sudo chown -R frappe:frappe /home/frappe/frappe-bench

# Fix permissions
sudo chmod -R 755 /home/frappe/frappe-bench
```

### 5. Node.js Version Issues
```bash
# Check Node.js version (should be v18.x)
node --version
npm --version

# If wrong version, reinstall Node.js 18
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs
```

## Log Files

- Bench logs: `/home/frappe/frappe-bench/logs/`
- MariaDB logs: `/var/log/mysql/`
- Nginx logs: `/var/log/nginx/`
- Supervisor logs: `/var/log/supervisor/`

## File Structure

```
/home/frappe/frappe-bench/
├── apps/
│   ├── frappe/          # Frappe Framework
│   └── erpnext/         # ERPNext application
├── sites/
│   └── frappe.localhost/  # Your site
├── config/
├── logs/
└── env/                 # Python virtual environment
```

## Service Management

### Systemd Services
- `frappe.service` - Main Frappe application
- `nginx.service` - Web server
- `mariadb.service` - Database server
- `redis-server.service` - Cache server
- `fail2ban.service` - Security service

### Supervisor Processes
- Web workers
- Background workers
- Scheduler
- Socket.io server

## Additional Resources

- [Official Frappe Documentation](https://docs.frappe.io/framework)
- [ERPNext Documentation](https://docs.erpnext.com/)
- [Frappe GitHub Repository](https://github.com/frappe/frappe)
- [ERPNext GitHub Repository](https://github.com/frappe/erpnext)
- [Frappe Community Forum](https://discuss.frappe.io/)
- [Frappe School](https://frappe.school/)

## Support

If you encounter issues:

1. Check the troubleshooting section above
2. Review log files for error messages
3. Visit the [Frappe Community Forum](https://discuss.frappe.io/)
4. Check the [official documentation](https://docs.frappe.io/framework)

## License

This installation script is provided as-is. Frappe Framework and ERPNext are licensed under MIT License.

---

**Note:** This script installs ERPNext v16 Beta. For production use, consider using stable releases when available.