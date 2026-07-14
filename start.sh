#!/bin/bash

# Frappe Docker Startup Script
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

# Change to frappe user and bench directory
cd /home/frappe/frappe-bench

# Wait for database to be ready
log "Waiting for database to be ready..."
until mysqladmin ping -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASSWORD" --silent; do
    warning "Waiting for database connection..."
    sleep 5
done

log "Database is ready!"

# Wait for Redis to be ready
log "Waiting for Redis to be ready..."
until redis-cli -h redis ping; do
    warning "Waiting for Redis connection..."
    sleep 2
done

log "Redis is ready!"

# Check if site exists, if not create it
if [ ! -d "sites/frappe.localhost" ]; then
    log "Creating new site: frappe.localhost"
    su - frappe -c "cd /home/frappe/frappe-bench && bench new-site frappe.localhost --admin-password admin --mariadb-root-password $DB_ROOT_PASSWORD --db-host $DB_HOST --db-port $DB_PORT"
    
    # Set developer mode if enabled
    if [ "$DEVELOPER_MODE" = "1" ]; then
        log "Enabling developer mode"
        su - frappe -c "cd /home/frappe/frappe-bench && bench --site frappe.localhost set-config developer_mode 1"
    fi
    
    # Enable scheduler
    log "Enabling scheduler"
    su - frappe -c "cd /home/frappe/frappe-bench && bench --site frappe.localhost enable-scheduler"
    
    # Set default site
    su - frappe -c "cd /home/frappe/frappe-bench && bench use frappe.localhost"
    
    log "Site created successfully!"
else
    log "Site frappe.localhost already exists"
fi

# Install any external apps from apps-external directory
if [ -d "/home/frappe/frappe-bench/apps-external" ] && [ "$(ls -A /home/frappe/frappe-bench/apps-external)" ]; then
    log "Installing external apps..."
    for app_dir in /home/frappe/frappe-bench/apps-external/*/; do
        if [ -d "$app_dir" ]; then
            app_name=$(basename "$app_dir")
            log "Installing app: $app_name"
            su - frappe -c "cd /home/frappe/frappe-bench && bench get-app file:///home/frappe/frappe-bench/apps-external/$app_name"
            su - frappe -c "cd /home/frappe/frappe-bench && bench --site frappe.localhost install-app $app_name"
        fi
    done
fi

# Update bench configuration for container
log "Updating bench configuration..."
su - frappe -c "cd /home/frappe/frappe-bench && bench set-config -g db_host $DB_HOST"
su - frappe -c "cd /home/frappe/frappe-bench && bench set-config -g db_port $DB_PORT"
su - frappe -c "cd /home/frappe/frappe-bench && bench set-config -g redis_cache $REDIS_CACHE"
su - frappe -c "cd /home/frappe/frappe-bench && bench set-config -g redis_queue $REDIS_QUEUE"
su - frappe -c "cd /home/frappe/frappe-bench && bench set-config -g redis_socketio $REDIS_SOCKETIO"

# Set proper permissions
chown -R frappe:frappe /home/frappe/frappe-bench

log "Starting Frappe services..."

# Start supervisor
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf