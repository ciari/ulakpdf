#!/usr/bin/env bash
# UlakPDF — Debian 12 bootstrap.
# Installs docker, host nginx, certbot, and configures the firewall.
# Idempotent: re-running on a configured host is safe.
#
# Run as root: sudo bash deploy/install.sh
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "[install] must be run as root (use sudo)" >&2
    exit 1
fi

. /etc/os-release
if [ "${ID:-}" != "debian" ] || [ "${VERSION_ID:-}" != "12" ]; then
    echo "[install] WARNING: this script targets Debian 12, you're on ${ID:-?} ${VERSION_ID:-?}."
    echo "[install] Continuing in 5s — Ctrl-C to abort."
    sleep 5
fi

export DEBIAN_FRONTEND=noninteractive

# ---------- 1. Base packages ----------
echo "[install] base packages..."
apt-get update -qq
apt-get install -y --no-install-recommends \
    ca-certificates curl gnupg lsb-release \
    nginx certbot python3-certbot-nginx \
    rsyslog \
    ufw logrotate \
    git rsync

# ---------- 2. Docker engine (official repo) ----------
if ! command -v docker >/dev/null 2>&1; then
    echo "[install] docker engine..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/debian bookworm stable" \
        > /etc/apt/sources.list.d/docker.list
    apt-get update -qq
    apt-get install -y \
        docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin
    systemctl enable --now docker
else
    echo "[install] docker already installed — skipping."
fi

# ---------- 3. Firewall ----------
echo "[install] firewall (ufw)..."
ufw --force default deny incoming
ufw --force default allow outgoing
ufw allow 22/tcp comment 'ssh' || true
ufw allow 80/tcp comment 'http (certbot + redirect)' || true
ufw allow 443/tcp comment 'https' || true
yes | ufw --force enable >/dev/null

# ---------- 4. ACME challenge webroot ----------
mkdir -p /var/www/letsencrypt
chown -R www-data:www-data /var/www/letsencrypt

# ---------- 5. Project + project user ----------
PROJECT_DIR=/opt/spdf
if [ ! -d "$PROJECT_DIR" ]; then
    echo "[install] $PROJECT_DIR not found — clone or rsync the project here, then re-run this script."
    exit 1
fi

# ---------- 6. Log rotation for the docker stack's nginx logs ----------
echo "[install] logrotate..."
install -m 0644 "${PROJECT_DIR}/deploy/logrotate.conf" /etc/logrotate.d/ulakpdf

# ---------- 7. rsyslog: forward stats.log + shibd transaction.log to loghost ----
# imfile tails the named-volume paths on disk and forwards to UDP 514.
# A local copy lives under /var/log/ulakpdf/ as a safety net.
echo "[install] rsyslog forwarder..."
mkdir -p /var/log/ulakpdf
chmod 0750 /var/log/ulakpdf
install -m 0644 "${PROJECT_DIR}/deploy/rsyslog/ulakpdf.conf" /etc/rsyslog.d/30-ulakpdf.conf
# Validate before bouncing the daemon.
if rsyslogd -N1 -f /etc/rsyslog.d/30-ulakpdf.conf >/dev/null 2>&1; then
    systemctl restart rsyslog
    echo "[install] rsyslog reloaded; tailing logs to loghost.ulakbim.gov.tr"
else
    echo "[install] WARNING: rsyslog config validation failed — not restarting."
    echo "[install] Run 'rsyslogd -N1' to see errors, then 'systemctl restart rsyslog'."
fi

# ---------- 7. Disable default nginx site (don't serve "Welcome to nginx" on our domain) ----------
if [ -L /etc/nginx/sites-enabled/default ]; then
    rm /etc/nginx/sites-enabled/default
    echo "[install] removed nginx default site"
fi

echo ""
echo "[install] DONE. Next steps:"
echo "  1. cp deploy/.env.production.example .env   # then fill in DOMAIN, IDP_*, ADMIN_EPPNS"
echo "  2. envsubst < deploy/nginx-host.conf > /etc/nginx/sites-available/ulakpdf"
echo "     ln -sf /etc/nginx/sites-available/ulakpdf /etc/nginx/sites-enabled/ulakpdf"
echo "     nginx -t && systemctl reload nginx"
echo "  3. certbot --nginx -d <your-domain> --redirect --agree-tos -m <admin-email>"
echo "  4. bash deploy/deploy.sh   # builds + starts the docker stack"
echo "  5. Register https://<your-domain>/Shibboleth.sso/Metadata with Yetkim"
