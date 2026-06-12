# Home Assistant Add-on: Lightweight Web Proxy

## Configuration

```yaml
target_url: "http://192.168.1.10:8080"
host_header: ""
allow_insecure_ssl: false
request_timeout: 300
max_body_size: "64m"
log_level: "notice"
```

### Option: `target_url`

Absolute URL for the upstream web UI. Supported schemes are `http://` and `https://`.

### Option: `host_header`

Optional Host header override. Leave blank for the proxy to send the target host.

### Option: `allow_insecure_ssl`

Controls certificate verification for HTTPS upstreams.

- `false`: Verify certificates using the container CA bundle.
- `true`: Disable verification for self-signed/private certificates.

### Option: `request_timeout`

Connect, send, and read timeout in seconds. Valid range: 1-3600.

### Option: `max_body_size`

nginx `client_max_body_size`. Examples: `16m`, `64m`, `1g`.

### Option: `log_level`

nginx error log level: `debug`, `info`, `notice`, `warn`, or `error`.

## Access

After starting the add-on, use **Open Web UI** from the add-on page. You can also map `8099/tcp` to a host port if you need direct LAN access, but ingress is the intended default.

## Troubleshooting

- If the add-on starts but the UI is blank, confirm `target_url` is reachable from the Home Assistant host/network.
- For HTTPS services with private certificates, either install a certificate trusted by the container or set `allow_insecure_ssl: true`.
- If the upstream expects a specific virtual host, set `host_header` to that hostname.
