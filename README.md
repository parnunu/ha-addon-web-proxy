# Lightweight Web Proxy Home Assistant Add-on

A small Home Assistant OS add-on that runs nginx as a reverse proxy and exposes the proxied web UI through Home Assistant ingress.

Use it when a local or VPN-only service has a web interface you want to open from Home Assistant without publishing that service directly.

## Features

- Tiny nginx-based image using Home Assistant base images.
- Home Assistant ingress support (`Open Web UI`).
- Optional direct port mapping on `8099/tcp`.
- WebSocket headers enabled for dashboards and admin UIs.
- Configurable target URL, Host header, TLS verification, body size, timeout, and nginx log level.

## Install

1. Add this add-on repository in Home Assistant:
   `https://github.com/parnunu/home-assistant-addons`
2. Refresh the add-on store.
3. Install **Lightweight Web Proxy**.
4. Set `target_url` to the web service you want to proxy.
5. Start the add-on and click **Open Web UI**.

## Options

```yaml
target_url: "http://192.168.1.10:8080"
host_header: ""
allow_insecure_ssl: false
request_timeout: 300
max_body_size: "64m"
log_level: "notice"
```

- `target_url`: Absolute `http://` or `https://` URL to proxy.
- `host_header`: Optional Host header override. Leave blank to send the target host.
- `allow_insecure_ssl`: Set `true` only for HTTPS targets with self-signed or private certificates you trust.
- `request_timeout`: Proxy connect/send/read timeout in seconds.
- `max_body_size`: nginx `client_max_body_size` value.
- `log_level`: nginx error log verbosity.

## Notes

This add-on is a generic reverse proxy, not an authentication layer. When used through Home Assistant ingress, access is controlled by Home Assistant. If you expose the optional direct port, secure it at your network boundary.
