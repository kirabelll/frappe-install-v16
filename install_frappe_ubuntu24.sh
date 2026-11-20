#!/bin/bash
# =============================================================================
# Frappe Framework v16 Installation Script for Ubuntu
# =============================================================================
# This script installs Frappe Framework v16 with all dependencies on Ubuntu 22.04/24.04
# Run as a non-root user with sudo privileges
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
FRAPPE_VERSION="version-16"
FRAPPE_USER="${FRAPPE_USER:-frappe}"
FRAPPE_HOME="/home/${FRAPPE_USER}"
FRAPPE_BENCH_DIR="${FRAPPE_BENCH_DIR:-${FRAPPE_HOME}/frappe-bench}"
PYTHON_VERSION="3.14"
NODE_VERSION="24"
MARIADB_VERSION="11.8"
REDIS_VERSION="7"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root. Run as a user with sudo privileges."
        exit 1
    fi
}

# Check Ubuntu version
check_ubuntu() {
    if [[ ! -f /etc/os-release ]]; then
        log_error "Cannot detect OS. This script is for Ubuntu."
        exit 1
    fi

    source /etc/os-release
    if [[ "$ID" != "ubuntu" ]]; then
        log_error "This script is for Ubuntu. Detected: $ID"
        exit 1
    fi

    log_info "Detected Ubuntu $VERSION_ID ($VERSION_CODENAME)"

    # Check for supported versions
    case "$VERSION_ID" in
        22.04|24.04)
            log_success "Ubuntu $VERSION_ID is supported"
            ;;
        *)
            log_warning "Ubuntu $VERSION_ID may not be fully tested. Proceeding anyway..."
            ;;
    esac
}

# Check sudo privileges
check_sudo() {
    if ! sudo -n true 2>/dev/null; then
        log_info "This script requires sudo privileges. You may be prompted for your password."
        sudo -v
    fi
}

# Update system packages
update_system() {
    log_info "Updating system packages..."
    sudo apt-get update -y
    sudo apt-get upgrade -y
    log_success "System updated"
}

# Install essential packages
install_essentials() {
    log_info "Installing essential packages..."
    sudo apt-get install -y \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        curl \
        wget \
        gnupg \
        lsb-release \
        git \
        build-essential \
        libssl-dev \
        libffi-dev \
        python3-dev \
        python3-venv \
        python3-pip \
        pkg-config \
        libmariadb-dev \
        libmariadb-dev-compat
    log_success "Essential packages installed"
}

# Install uv and Python 3.14 for the Frappe user. Ubuntu 24.04 ships Python 3.12,
# so Python 3.14 must be installed separately rather than through apt.
install_python() {
    log_info "Installing uv and Python ${PYTHON_VERSION} for ${FRAPPE_USER}..."
    sudo -H -u "${FRAPPE_USER}" bash -c '
        set -e
        curl -LsSf https://astral.sh/uv/install.sh | sh
        export PATH="$HOME/.local/bin:$PATH"
        uv python install "'"${PYTHON_VERSION}"'"
        uv python find "'"${PYTHON_VERSION}"'" | grep -q .
    '
    log_success "Python ${PYTHON_VERSION} installed"
}

# Install Node.js 24
install_nodejs() {
    log_info "Installing Node.js ${NODE_VERSION}..."

    # Add NodeSource repository
    curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | sudo -E bash -
    sudo apt-get install -y nodejs

    # Verify installation
    node_version=$(node --version)
    npm_version=$(npm --version)
    log_success "Node.js ${node_version} and npm ${npm_version} installed"

    # Install yarn globally
    sudo npm install -g yarn
    log_success "Yarn installed"
}

# Install MariaDB
install_mariadb() {
    log_info "Installing MariaDB ${MARIADB_VERSION}..."

    # Configure MariaDB's official repository. Avoid pinning a single mirror,
    # since individual mirrors can be unreachable from some networks.
    curl -fsSL https://r.mariadb.com/downloads/mariadb_repo_setup | \
        sudo bash -s -- --mariadb-server-version="mariadb-${MARIADB_VERSION}"

    sudo apt-get update -y
    sudo apt-get install -y mariadb-server mariadb-client

    # Secure MariaDB installation
    log_info "Securing MariaDB installation..."
    sudo mysql_secure_installation <<EOF

y
y
y
y
EOF

    # Configure MariaDB for Frappe
    log_info "Configuring MariaDB for Frappe..."
    sudo tee /etc/mysql/mariadb.conf.d/99-frappe.cnf > /dev/null <<EOF
[mysqld]
character-set-client-handshake = FALSE
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
innodb-file-format = barracuda
innodb-file-per-table = 1
innodb-large-prefix = 1
innodb-buffer-pool-size = 1G
innodb-log-file-size = 256M
max-allowed-packet = 256M
sql-mode = STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION
EOF

    sudo systemctl restart mariadb
    sudo systemctl enable mariadb

    log_success "MariaDB ${MARIADB_VERSION} installed and configured"
}

# Install Redis
install_redis() {
    log_info "Installing Redis ${REDIS_VERSION}..."

    # Add Redis repository
    curl -fsSL https://packages.redis.io/gpg | sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list

    sudo apt-get update -y
    sudo apt-get install -y redis

    # Configure Redis for Frappe
    log_info "Configuring Redis for Frappe..."
    sudo sed -i 's/^supervised no/supervised systemd/' /etc/redis/redis.conf
    sudo sed -i 's/^# maxmemory <bytes>/maxmemory 256mb/' /etc/redis/redis.conf
    sudo sed -i 's/^# maxmemory-policy noeviction/maxmemory-policy allkeys-lru/' /etc/redis/redis.conf

    sudo systemctl restart redis-server
    sudo systemctl enable redis-server

    log_success "Redis ${REDIS_VERSION} installed and configured"
}

# Install Nginx
install_nginx() {
    log_info "Installing Nginx..."
    sudo apt-get install -y nginx

    sudo systemctl start nginx
    sudo systemctl enable nginx

    log_success "Nginx installed"
}

# Create Frappe user
create_frappe_user() {
    log_info "Creating Frappe user: ${FRAPPE_USER}..."

    if id "${FRAPPE_USER}" &>/dev/null; then
        log_warning "User ${FRAPPE_USER} already exists"
    else
        sudo adduser --disabled-password --gecos "" "${FRAPPE_USER}"
        sudo usermod -aG sudo "${FRAPPE_USER}"
        log_success "User ${FRAPPE_USER} created"
    fi

    # Add current user to frappe group for easier access
    sudo usermod -aG "${FRAPPE_USER}" "$USER"
}

# Set up Chromium for Frappe v16 PDF generation
setup_chromium() {
    log_info "Setting up Chromium for Frappe v16..."

    sudo -H -u "${FRAPPE_USER}" bash -c '
        set -e
        cd "'"${FRAPPE_BENCH_DIR}"'"
        export PATH="$HOME/.local/bin:$PATH"
        bench setup-chrome
    '

    log_success "Chromium configured for Frappe"
}

# Install bench CLI
install_bench() {
    log_info "Installing bench CLI..."

    # Install bench with uv so it does not modify Ubuntu's system Python.
    sudo -H -u "${FRAPPE_USER}" bash -c '
        set -e
        export PATH="$HOME/.local/bin:$PATH"
        uv tool install --upgrade frappe-bench --python '"${PYTHON_VERSION}"'
        grep -qxF "export PATH=\$HOME/.local/bin:\$PATH" "$HOME/.bashrc" || \
            echo "export PATH=\$HOME/.local/bin:\$PATH" >> "$HOME/.bashrc"
    '

    log_success "Bench CLI installed"
}

# Initialize Frappe Bench
init_frappe_bench() {
    log_info "Initializing Frappe Bench (version ${FRAPPE_VERSION})..."

    if [[ -d "${FRAPPE_BENCH_DIR}" ]]; then
        if [[ -x "${FRAPPE_BENCH_DIR}/env/bin/python" && -d "${FRAPPE_BENCH_DIR}/apps/frappe" ]]; then
            log_warning "Bench directory already exists; keeping the existing bench"
            return
        fi
        log_error "${FRAPPE_BENCH_DIR} exists but is not a complete bench. Move it aside and rerun the installer."
        exit 1
    fi

    sudo -H -u "${FRAPPE_USER}" bash -c '
        set -e
        cd "'"${FRAPPE_HOME}"'"
        export PATH="$HOME/.local/bin:$PATH"
        bench init frappe-bench --frappe-branch '"${FRAPPE_VERSION}"' --python "$(uv python find '"${PYTHON_VERSION}"')"
    '

    log_success "Frappe Bench initialized"
}

# Configure bench for production
configure_bench() {
    log_info "Configuring bench for production..."

    sudo -H -u "${FRAPPE_USER}" bash -c "
        cd ${FRAPPE_BENCH_DIR}
        export PATH=\"\$HOME/.local/bin:\$PATH\"

        # Set config
        bench set-config -g db_host localhost
        bench set-config -g redis_cache redis://localhost:6379
        bench set-config -g redis_queue redis://localhost:6379
        bench set-config -g redis_socketio redis://localhost:6379
        bench set-config -g auto_update off
        bench set-config -g maintenance_mode off
        bench set-config -g shallow_clone on
    "

    log_success "Bench configured"
}

# Create a new site
create_site() {
    local site_name="${1:-site1.local}"
    local admin_password="${2:-admin}"
    local mariadb_root_password="${3:-}"

    log_info "Creating new site: ${site_name}..."

    if [[ -d "${FRAPPE_BENCH_DIR}/sites/${site_name}" ]]; then
        log_warning "Site ${site_name} already exists; skipping creation"
        return
    fi

    if [[ -z "$mariadb_root_password" ]]; then
        log_warning "MariaDB root password not provided. You'll need to enter it manually."
        read -s -p "Enter MariaDB root password: " mariadb_root_password
        echo
    fi

    sudo -H -u "${FRAPPE_USER}" bash -c "
        cd ${FRAPPE_BENCH_DIR}
        export PATH=\"\$HOME/.local/bin:\$PATH\"
        bench new-site ${site_name} --admin-password '${admin_password}' --mariadb-root-password '${mariadb_root_password}' --no-mariadb-socket
    "

    # Set as default site
    sudo -H -u "${FRAPPE_USER}" bash -c "
        cd ${FRAPPE_BENCH_DIR}
        export PATH=\"\$HOME/.local/bin:\$PATH\"
        bench use ${site_name}
    "

    log_success "Site ${site_name} created and set as default"
}

# Setup production configuration
setup_production() {
    log_info "Setting up production configuration..."

    # Setup nginx config
    sudo -H -u "${FRAPPE_USER}" bash -c "
        cd ${FRAPPE_BENCH_DIR}
        export PATH=\"\$HOME/.local/bin:\$PATH\"
        bench setup nginx
    "

    # Copy nginx config
    sudo cp "${FRAPPE_BENCH_DIR}/config/nginx.conf" /etc/nginx/sites-available/frappe
    sudo ln -sf /etc/nginx/sites-available/frappe /etc/nginx/sites-enabled/frappe
    sudo rm -f /etc/nginx/sites-enabled/default

    # Test nginx config
    sudo nginx -t
    sudo systemctl reload nginx

    # Setup supervisor
    sudo -H -u "${FRAPPE_USER}" bash -c "
        cd ${FRAPPE_BENCH_DIR}
        export PATH=\"\$HOME/.local/bin:\$PATH\"
        bench setup supervisor
    "

    sudo cp "${FRAPPE_BENCH_DIR}/config/supervisor.conf" /etc/supervisor/conf.d/frappe.conf
    sudo supervisorctl reread
    sudo supervisorctl update
    sudo supervisorctl restart all

    # Setup systemd services for bench
    sudo -H -u "${FRAPPE_USER}" bash -c "
        cd ${FRAPPE_BENCH_DIR}
        export PATH=\"\$HOME/.local/bin:\$PATH\"
        bench setup systemd
    "

    sudo cp /home/${FRAPPE_USER}/frappe-bench/config/systemd/* /etc/systemd/system/
    sudo systemctl daemon-reload

    # Enable and start services
    sudo systemctl enable frappe-bench-webserver frappe-bench-workers frappe-bench-schedule
    sudo systemctl start frappe-bench-webserver frappe-bench-workers frappe-bench-schedule

    log_success "Production configuration completed"
}

# Install ERPNext (optional)
install_erpnext() {
    log_info "Installing ERPNext..."

    sudo -H -u "${FRAPPE_USER}" bash -c "
        cd ${FRAPPE_BENCH_DIR}
        export PATH=\"\$HOME/.local/bin:\$PATH\"
        bench get-app --branch version-16 erpnext https://github.com/frappe/erpnext
        bench --site all install-app erpnext
    "

    log_success "ERPNext installed"
}

# Setup firewall
setup_firewall() {
    log_info "Configuring firewall..."

    sudo ufw allow OpenSSH
    sudo ufw allow 'Nginx Full'
    sudo ufw --force enable

    log_success "Firewall configured"
}

# Print summary
print_summary() {
    local site_name="${1:-site1.local}"

    echo
    echo "============================================================================="
    echo -e "${GREEN}✓ Frappe Framework v16 Installation Complete!${NC}"
    echo "============================================================================="
    echo
    echo -e "${BLUE}Installation Details:${NC}"
    echo "  Frappe User:      ${FRAPPE_USER}"
    echo "  Bench Directory:  ${FRAPPE_BENCH_DIR}"
    echo "  Site Name:        ${site_name}"
    echo "  Python Version:   $(python3 --version)"
    echo "  Node Version:     $(node --version)"
    echo "  MariaDB Version:  $(mysql --version | awk '{print $5}' | sed 's/,//')"
    echo "  Redis Version:    $(redis-server --version | awk '{print $3}' | sed 's/v=//')"
    echo
    echo -e "${BLUE}Access URLs:${NC}"
    echo "  Site:             http://$(hostname -I | awk '{print $1}')"
    echo "  Admin Login:      http://$(hostname -I | awk '{print $1}')/login"
    echo
    echo -e "${BLUE}Default Credentials:${NC}"
    echo "  Username:         Administrator"
    echo "  Password:         admin (change this immediately!)"
    echo
    echo -e "${BLUE}Useful Commands:${NC}"
    echo "  Switch to frappe user:  sudo su - ${FRAPPE_USER}"
    echo "  Start bench:            cd ${FRAPPE_BENCH_DIR} && bench start"
    echo "  Run migrations:         bench --site ${site_name} migrate"
    echo "  Backup site:            bench --site ${site_name} backup"
    echo "  Install app:            bench get-app <app_name> && bench --site ${site_name} install-app <app_name>"
    echo
    echo -e "${YELLOW}Important:${NC}"
    echo "  1. Change the default admin password immediately!"
    echo "  2. Configure SSL/TLS for production use"
    echo "  3. Set up regular backups"
    echo "  4. Review /etc/nginx/sites-available/frappe for custom domains"
    echo
    echo "============================================================================="
}

# Main installation flow
main() {
    local site_name="${1:-site1.local}"
    local admin_password="${2:-admin}"
    local mariadb_root_password="${3:-}"
    local install_erpnext_flag="${4:-false}"

    echo "============================================================================="
    echo -e "${BLUE}Frappe Framework v16 Installation Script${NC}"
    echo "============================================================================="
    echo

    check_root
    check_ubuntu
    check_sudo

    log_info "Starting Frappe v16 installation..."
    echo

    update_system
    install_essentials
    create_frappe_user
    install_python
    install_nodejs
    install_mariadb
    install_redis
    install_nginx
    install_bench
    init_frappe_bench
    setup_chromium
    configure_bench
    create_site "$site_name" "$admin_password" "$mariadb_root_password"
    setup_production
    setup_firewall

    if [[ "$install_erpnext_flag" == "true" ]]; then
        install_erpnext
    fi

    print_summary "$site_name"
}

# Help function
show_help() {
    cat <<EOF
Frappe Framework v16 Installation Script for Ubuntu

Usage: $0 [OPTIONS] [SITE_NAME] [ADMIN_PASSWORD] [MARIADB_ROOT_PASSWORD] [INSTALL_ERPNEXT]

Arguments:
  SITE_NAME              Site name (default: site1.local)
  ADMIN_PASSWORD         Admin password (default: admin)
  MARIADB_ROOT_PASSWORD  MariaDB root password (will prompt if not provided)
  INSTALL_ERPNEXT        Install ERPNext (true/false, default: false)

Options:
  -h, --help             Show this help message
  --site-name            Site name
  --admin-password       Admin password
  --mariadb-password     MariaDB root password
  --with-erpnext         Install ERPNext

Examples:
  $0                                                                    # Interactive with defaults
  $0 mysite.local mypassword dbpassword                                 # Quick install
  $0 --site-name mysite.local --admin-password mypass --with-erpnext    # With ERPNext
  $0 --help                                                             # Show help

EOF
}

# Parse arguments
SITE_NAME="site1.local"
ADMIN_PASSWORD="admin"
MARIADB_ROOT_PASSWORD=""
INSTALL_ERPNEXT="false"

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        --site-name)
            SITE_NAME="$2"
            shift 2
            ;;
        --admin-password)
            ADMIN_PASSWORD="$2"
            shift 2
            ;;
        --mariadb-password)
            MARIADB_ROOT_PASSWORD="$2"
            shift 2
            ;;
        --with-erpnext)
            INSTALL_ERPNEXT="true"
            shift
            ;;
        *)
            # Positional arguments
            if [[ -z "${POSITIONAL_ARGS[0]}" ]]; then
                SITE_NAME="$1"
            elif [[ -z "${POSITIONAL_ARGS[1]}" ]]; then
                ADMIN_PASSWORD="$1"
            elif [[ -z "${POSITIONAL_ARGS[2]}" ]]; then
                MARIADB_ROOT_PASSWORD="$1"
            elif [[ -z "${POSITIONAL_ARGS[3]}" ]]; then
                INSTALL_ERPNEXT="$1"
            fi
            POSITIONAL_ARGS+=("$1")
            shift
            ;;
    esac
done

# Run main installation
main "$SITE_NAME" "$ADMIN_PASSWORD" "$MARIADB_ROOT_PASSWORD" "$INSTALL_ERPNEXT"
