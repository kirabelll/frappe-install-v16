# Frappe Framework v16 Installation Script for Ubuntu 24.04 LTS

This repository contains an automated installation script for Frappe Framework version 16 on Ubuntu 24.04 LTS.

## What is Frappe Framework?

Frappe Framework is a full-stack web application framework that uses Python and MariaDB on the server side with a tightly integrated client-side library. It's the foundation for ERPNext and other business applications.

## Prerequisites

- Ubuntu 24.04 LTS server or desktop
- User account with sudo privileges
- Internet connection
- At least 4GB RAM and 20GB disk space
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

### Frappe Components
- Frappe Framework version 16
- Bench (Frappe's CLI tool)
- A new site at `frappe.localhost`

## Post-Installation

After successful installation:

1. **Access your site:**
   - URL: `http://frappe.localhost:8000`
   - Username: `Administrator`
   - Password: `admin`

2. **Start development server:**
   ```bash
   sudo -u frappe bash
   cd /home/frappe/frappe-bench
   bench start
   ```

3. **Check installation details:**
   ```bash
   cat /home/frappe/frappe_passwords.txt
   ```

## Important Security Notes

⚠️ **Change default passwords immediately in production!**

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

# Update bench
bench update
```

### Production Setup (Optional)
```bash
# Setup production configuration
sudo bench setup production frappe

# Start services
sudo systemctl start frappe
sudo systemctl enable frappe
```

## Troubleshooting

### Common Issues

1. **Permission errors:**
   ```bash
   sudo chown -R frappe:frappe /home/frappe/frappe-bench
   ```

2. **MariaDB connection issues:**
   ```bash
   sudo systemctl restart mariadb
   sudo mysql -u root -p
   ```

3. **Node.js version conflicts:**
   ```bash
   node --version  # Should be v18.x
   npm --version
   ```

### Log Files
- Bench logs: `/home/frappe/frappe-bench/logs/`
- MariaDB logs: `/var/log/mysql/`
- Nginx logs: `/var/log/nginx/`

## File Structure

```
/home/frappe/frappe-bench/
├── apps/
│   └── frappe/          # Frappe Framework
├── sites/
│   └── frappe.localhost/  # Your site
├── config/
├── logs/
└── env/                 # Python virtual environment
```

## Additional Resources

- [Official Frappe Documentation](https://docs.frappe.io/framework)
- [Frappe GitHub Repository](https://github.com/frappe/frappe)
- [Frappe Community Forum](https://discuss.frappe.io/)
- [Frappe School](https://frappe.school/)

## Support

If you encounter issues:

1. Check the troubleshooting section above
2. Review log files for error messages
3. Visit the [Frappe Community Forum](https://discuss.frappe.io/)
4. Check the [official documentation](https://docs.frappe.io/framework)

## License

This installation script is provided as-is. Frappe Framework is licensed under MIT License.

---

**Note:** This script is designed specifically for Ubuntu 24.04 LTS. For other distributions or versions, please refer to the official Frappe installation documentation.