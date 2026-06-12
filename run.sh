#!/usr/bin/env bash
set -Eeuo pipefail

source /usr/lib/bashio/bashio.sh

readonly TINYPROXY_CONFIG=/etc/tinyproxy/tinyproxy.conf

fail() {
    bashio::log.error "$1"
    exit 1
}

json_array_lines() {
    local option=${1}
    jq -r ".${option} // [] | .[]" /data/options.json
}

PORT=$(bashio::config port)
MAX_CLIENTS=$(bashio::config max_clients)
UPSTREAM_PROXY=$(bashio::config upstream_proxy)
LOG_LEVEL=$(bashio::config log_level)

[[ "${PORT}" =~ ^[0-9]+$ ]] || fail "port must be an integer."
(( PORT >= 1 && PORT <= 65535 )) || fail "port must be between 1 and 65535."

[[ "${MAX_CLIENTS}" =~ ^[0-9]+$ ]] || fail "max_clients must be an integer."
(( MAX_CLIENTS >= 1 && MAX_CLIENTS <= 10000 )) || fail "max_clients must be between 1 and 10000."

case "${LOG_LEVEL}" in
    Critical|Error|Warning|Notice|Connect|Info) ;;
    *) fail "log_level must be one of Critical, Error, Warning, Notice, Connect, or Info." ;;
esac

mapfile -t ALLOWED_NETWORKS < <(json_array_lines allowed_networks)
mapfile -t CONNECT_PORTS < <(json_array_lines connect_ports)

(( ${#ALLOWED_NETWORKS[@]} > 0 )) || fail "allowed_networks must contain at least one network or IP address."
(( ${#CONNECT_PORTS[@]} > 0 )) || fail "connect_ports must contain at least one port."

for connect_port in "${CONNECT_PORTS[@]}"; do
    [[ "${connect_port}" =~ ^[0-9]+$ ]] || fail "connect_ports entries must be integers."
    (( connect_port >= 1 && connect_port <= 65535 )) || fail "connect_ports entries must be between 1 and 65535."
done

mkdir -p /etc/tinyproxy /var/log/tinyproxy /run/tinyproxy

cat > "${TINYPROXY_CONFIG}" <<EOF
User root
Group root
Port ${PORT}
Listen 0.0.0.0
Timeout 600
DefaultErrorFile "/usr/share/tinyproxy/default.html"
StatFile "/usr/share/tinyproxy/stats.html"
LogFile "/dev/stdout"
LogLevel ${LOG_LEVEL}
PidFile "/run/tinyproxy/tinyproxy.pid"
MaxClients ${MAX_CLIENTS}
StartServers 2
MinSpareServers 1
MaxSpareServers 5
ViaProxyName "haos-lightweight-forward-proxy"
DisableViaHeader Yes
EOF

for network in "${ALLOWED_NETWORKS[@]}"; do
    [[ -n "${network}" ]] || fail "allowed_networks entries must not be empty."
    printf 'Allow %s\n' "${network}" >> "${TINYPROXY_CONFIG}"
done

for connect_port in "${CONNECT_PORTS[@]}"; do
    printf 'ConnectPort %s\n' "${connect_port}" >> "${TINYPROXY_CONFIG}"
done

if [[ -n "${UPSTREAM_PROXY}" ]]; then
    [[ "${UPSTREAM_PROXY}" =~ ^[^[:space:]]+:[0-9]+$ ]] || fail "upstream_proxy must be host:port when set."
    printf 'Upstream http %s\n' "${UPSTREAM_PROXY}" >> "${TINYPROXY_CONFIG}"
fi

tinyproxy -t -c "${TINYPROXY_CONFIG}"

bashio::log.info "Starting lightweight forward proxy on 0.0.0.0:${PORT}"
exec tinyproxy -d -c "${TINYPROXY_CONFIG}"
