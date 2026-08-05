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
  rm -rf .git .github qa deploy
  rm -f qa.ps1 README.md
)

ln -sfn "${RELEASE_DIR}" "${SITE_ROOT}/current.new"
mv -Tf "${SITE_ROOT}/current.new" "${SITE_ROOT}/current"

sudo tee "${NGINX_CONF}.new" >/dev/null <<'NGINX'
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
NGINX
sudo mv "${NGINX_CONF}.new" "${NGINX_CONF}"
sudo nginx -t
sudo systemctl reload nginx

status="$(curl -sS -o /dev/null -w '%{http_code}' -H 'Host: marygunn.com' http://127.0.0.1/)"
if [[ "${status}" != "200" ]]; then
  echo "Local virtual-host check failed: HTTP ${status}" >&2
  exit 1
fi

find "${SITE_ROOT}/releases" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %p\n' \
  | sort -nr \
  | awk 'NR>3 {sub(/^[^ ]+ /, ""); print}' \
  | xargs -r rm -rf

echo "DEPLOY_OK ${DOMAIN} ${RELEASE_ID} HTTP_${status}"
