#!/usr/bin/env bash
set -euo pipefail

DOMAIN="marygunn.com"
REPO="https://github.com/KirkAutomations/mary-gunn-school-board.git"
REVISION="${1:-main}"
SITE_ROOT="/var/www/${DOMAIN}"
RELEASE_ID="$(date -u +%Y%m%dT%H%M%SZ)-${REVISION:0:8}"
RELEASE_DIR="${SITE_ROOT}/releases/${RELEASE_ID}"
NGINX_CONF="/etc/nginx/conf.d/${DOMAIN}.conf"

command -v git >/dev/null
command -v nginx >/dev/null

sudo install -d -o "$(id -un)" -g "$(id -gn)" -m 0755 "${SITE_ROOT}" "${SITE_ROOT}/releases"
git clone --quiet --depth 1 "${REPO}" "${RELEASE_DIR}"
(
  cd "${RELEASE_DIR}"
  git fetch --quiet --depth 1 origin "${REVISION}"
  git checkout --quiet --detach FETCH_HEAD
  git rev-parse HEAD > .deployed-commit
  rm -rf .git .github qa
  rm -f qa.ps1 README.md
)

if [[ ! -f /etc/marygunn-contact.env ]]; then
  echo "Missing /etc/marygunn-contact.env" >&2
  exit 1
fi
id marycontact >/dev/null 2>&1 || sudo useradd --system --home-dir /nonexistent --shell /usr/sbin/nologin marycontact
sudo install -d -o root -g root -m 0755 /opt/marygunn-contact
sudo install -o root -g root -m 0755 "${RELEASE_DIR}/deploy/contact-api.py" /opt/marygunn-contact/contact-api.py
sudo install -o root -g root -m 0644 "${RELEASE_DIR}/deploy/marygunn-contact.service" /etc/systemd/system/marygunn-contact.service
sudo systemctl daemon-reload
sudo systemctl enable --now marygunn-contact.service
sudo systemctl restart marygunn-contact.service
curl -fsS --retry 10 --retry-connrefused --retry-delay 1 http://127.0.0.1:8787/health >/dev/null
rm -rf "${RELEASE_DIR}/deploy"

ln -sfn "${RELEASE_DIR}" "${SITE_ROOT}/current.new"
mv -Tf "${SITE_ROOT}/current.new" "${SITE_ROOT}/current"

if [[ -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]]; then
sudo tee "${NGINX_CONF}.new" >/dev/null <<'NGINX_SSL'
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name marygunn.com www.marygunn.com;

    root /var/www/marygunn.com/current;
    index index.html;

    access_log /var/log/nginx/marygunn.com.access.log;
    error_log /var/log/nginx/marygunn.com.error.log;

    location ^~ /.well-known/acme-challenge/ {
        try_files $uri =404;
    }

    location = /index.html {
        add_header Cache-Control "no-cache" always;
    }

    location = /api/contact {
        limit_except POST { deny all; }
        client_max_body_size 20k;
        proxy_pass http://127.0.0.1:8787/contact;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 30s;
    }

    location ^~ /assets/ {
        expires 30d;
        add_header Cache-Control "public, immutable";
        try_files $uri =404;
    }

    location / {
        try_files $uri $uri/ /index.html;
    }

    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header X-Frame-Options "SAMEORIGIN" always;

    ssl_certificate /etc/letsencrypt/live/marygunn.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/marygunn.com/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
}

server {
    listen 80;
    listen [::]:80;
    server_name marygunn.com www.marygunn.com;

    location ^~ /.well-known/acme-challenge/ {
        root /var/www/marygunn.com/current;
        try_files $uri =404;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}
NGINX_SSL
else
sudo tee "${NGINX_CONF}.new" >/dev/null <<'NGINX_HTTP'
server {
    listen 80;
    listen [::]:80;
    server_name marygunn.com www.marygunn.com;

    root /var/www/marygunn.com/current;
    index index.html;

    access_log /var/log/nginx/marygunn.com.access.log;
    error_log /var/log/nginx/marygunn.com.error.log;

    location ^~ /.well-known/acme-challenge/ {
        try_files $uri =404;
    }

    location = /index.html {
        add_header Cache-Control "no-cache" always;
    }

    location ^~ /assets/ {
        expires 30d;
        add_header Cache-Control "public, immutable";
        try_files $uri =404;
    }

    location / {
        try_files $uri $uri/ /index.html;
    }

    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
}
NGINX_HTTP
fi
sudo mv "${NGINX_CONF}.new" "${NGINX_CONF}"
if ! sudo nginx -t >/tmp/marygunn-nginx-test.log 2>&1; then
  cat /tmp/marygunn-nginx-test.log
  exit 1
fi
cat /tmp/marygunn-nginx-test.log
sudo systemctl reload nginx

if [[ -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]]; then
  protocol="HTTPS"
  status="$(curl -sS --resolve marygunn.com:443:127.0.0.1 -o /dev/null -w '%{http_code}' https://marygunn.com/)"
else
  protocol="HTTP"
  status="$(curl -sS -o /dev/null -w '%{http_code}' -H 'Host: marygunn.com' http://127.0.0.1/)"
fi
if [[ "${status}" != "200" ]]; then
  echo "Local virtual-host check failed: ${protocol} ${status}" >&2
  exit 1
fi

find "${SITE_ROOT}/releases" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %p\n' \
  | sort -nr \
  | awk 'NR>3 {sub(/^[^ ]+ /, ""); print}' \
  | xargs -r rm -rf

echo "DEPLOY_OK ${DOMAIN} ${RELEASE_ID} ${protocol}_${status}"
