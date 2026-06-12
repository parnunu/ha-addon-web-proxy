#!/usr/bin/env bash
set -Eeuo pipefail

source /usr/lib/bashio/bashio.sh

if [[ ! -x /usr/local/bin/forward-proxy ]]; then
    bashio::log.error "Missing forward-proxy binary for this architecture."
    exit 1
fi

bashio::log.info "Starting lightweight forward proxy."
exec /usr/local/bin/forward-proxy -config /data/options.json
