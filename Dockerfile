# Frappe Framework v16 Docker Image
FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV FRAPPE_USER=frappe
ENV BENCH_BRANCH=version-16

# Install system dependencies
RUN apt-get update && apt-get install -y \
    python3 \
    python3-dev \
    python3-pip \
    python3-venv \
    python3-setuptools \
    software-properties-common \
    mariadb-client \
    redis-tools \
    xvfb \
    libfontconfig \
    wkhtmltopdf \
    git \
    curl \
    wget \
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
    cron \
    supervisor \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 18
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs

# Install Yarn
RUN npm install -g yarn

# Create frappe user
RUN useradd -m -d /home/frappe -s /bin/bash frappe \
    && echo 'frappe ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Switch to frappe user
USER frappe
WORKDIR /home/frappe

# Install bench
RUN pip3 install --user frappe-bench

# Add local bin to PATH
ENV PATH="/home/frappe/.local/bin:$PATH"

# Create bench directory (initialization will happen at startup)
RUN mkdir -p /home/frappe/frappe-bench
WORKDIR /home/frappe/frappe-bench

# Create startup script
USER root
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Create supervisor configuration
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Expose ports
EXPOSE 8000 9000

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8000 || exit 1

# Start command
CMD ["/start.sh"]