#!/usr/bin/env bash
set -Eeuo pipefail

source /usr/lib/bashio/bashio.sh

readonly LISTEN_PORT=8099
readonly NGINX_CONFIG=/etc/nginx/nginx.conf
readonly PROXY_CONFIG=/etc/nginx/http.d/web-proxy.conf

fail() {
    bashio::log.error "$1"
    exit 1
}

escape_nginx_value() {
    local value=${1}
    printf '%s' "${value}" | sed -e 's/\\/\\\\/g' -e 's/;/\\;/g'
}

read_option() {
    local name=${1}
    bashio::config "${name}"
}

TARGET_URL=$(read_option target_url)
HOST_HEADER=$(read_option host_header)
ALLOW_INSECURE_SSL=$(read_option allow_insecure_ssl)
REQUEST_TIMEOUT=$(read_option request_timeout)
MAX_BODY_SIZE=$(read_option max_body_size)
LOG_LEVEL=$(read_option log_level)

[[ -n "${TARGET_URL}" ]] || fail "target_url must not be empty."
[[ "${TARGET_URL}" =~ ^https?://[^[:space:]/]+.*$ ]] || fail "target_url must be an absolute http:// or https:// URL."

[[ "${REQUEST_TIMEOUT}" =~ ^[0-9]+$ ]] || fail "request_timeout must be an integer."
(( REQUEST_TIMEOUT >= 1 && REQUEST_TIMEOUT <= 3600 )) || fail "request_timeout must be between 1 and 3600 seconds."

case "${LOG_LEVEL}" in
    debug|info|notice|warn|error) ;;
    *) fail "log_level must be one of debug, info, notice, warn, or error." ;;
esac

case "${ALLOW_INSECURE_SSL}" in
    true) PROXY_SSL_VERIFY="off" ;;
    false) PROXY_SSL_VERIFY="on" ;;
    *) fail "allow_insecure_ssl must be true or false." ;;
esac

mkdir -p /etc/nginx/http.d /run/nginx /var/lib/nginx/tmp /var/log/nginx

cat > "${NGINX_CONFIG}" <<EOF
worker_processes  1;
error_log /dev/stderr ${LOG_LEVEL};
pid /run/nginx/nginx.pid;

events {
    worker_connections 512;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    access_log /dev/stdout;
    sendfile on;
    keepalive_timeout 65;

    map \$http_upgrade \$connection_upgrade {
        default upgrade;
        '' close;
    }

    include /etc/nginx/http.d/*.conf;
}
EOF

ESCAPED_TARGET_URL=$(escape_nginx_value "${TARGET_URL}")
ESCAPED_HOST_HEADER=$(escape_nginx_value "${HOST_HEADER}")
ESCAPED_MAX_BODY_SIZE=$(escape_nginx_value "${MAX_BODY_SIZE}")

cat > "${PROXY_CONFIG}" <<EOF
server {
    listen ${LISTEN_PORT};
    server_name _;

    client_max_body_size ${ESCAPED_MAX_BODY_SIZE};

    location / {
        proxy_pass ${ESCAPED_TARGET_URL};
        proxy_http_version 1.1;

        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Prefix \$http_x_ingress_path;

        proxy_ssl_server_name on;
        proxy_ssl_verify ${PROXY_SSL_VERIFY};
        proxy_ssl_trusted_certificate /etc/ssl/certs/ca-certificates.crt;

        proxy_connect_timeout ${REQUEST_TIMEOUT}s;
        proxy_send_timeout ${REQUEST_TIMEOUT}s;
        proxy_read_timeout ${REQUEST_TIMEOUT}s;
        send_timeout ${REQUEST_TIMEOUT}s;
    }
}
EOF

if [[ -n "${HOST_HEADER}" ]]; then
    sed -i "/proxy_set_header X-Real-IP/i\\        proxy_set_header Host ${ESCAPED_HOST_HEADER};" "${PROXY_CONFIG}"
else
    sed -i "/proxy_set_header X-Real-IP/i\\        proxy_set_header Host \\$proxy_host;" "${PROXY_CONFIG}"
fi

nginx -t

bashio::log.info "Starting lightweight web proxy on port ${LISTEN_PORT}; target=${TARGET_URL}"
exec nginx -g 'daemon off;'
