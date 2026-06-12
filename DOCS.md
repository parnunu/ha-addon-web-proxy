# Home Assistant Add-on: Lightweight Forward Proxy

## Configuration

```yaml
port: 8888
allowed_networks:
  - "10.0.0.0/8"
  - "172.16.0.0/12"
  - "192.168.0.0/16"
max_clients: 100
connect_ports:
  - 443
  - 563
upstream_proxy: ""
log_level: "Info"
```

### Option: `port`

The forward proxy listen port. The default is `8888`.

### Option: `allowed_networks`

Client IP addresses or CIDR ranges that may use the proxy. Keep this list as narrow as possible.

Examples:

```yaml
allowed_networks:
  - "192.168.1.0/24"
  - "10.8.0.5"
```

### Option: `max_clients`

Maximum simultaneous proxy clients.

### Option: `connect_ports`

Ports allowed for HTTPS `CONNECT` tunneling. Defaults to `443` and `563`.

### Option: `upstream_proxy`

Optional parent proxy in `host:port` form. Leave blank for direct outbound connections.

### Option: `log_level`

tinyproxy log level: `Critical`, `Error`, `Warning`, `Notice`, `Connect`, or `Info`.

## Client setup

Set your client HTTP proxy to:

```text
http://<home-assistant-host>:8888
```

For HTTPS clients, use the same proxy endpoint. tinyproxy tunnels HTTPS using `CONNECT` for ports listed in `connect_ports`.

## Troubleshooting

- If clients cannot connect, confirm the add-on port mapping is enabled and reachable from the client network.
- If requests are denied, add the client IP or network to `allowed_networks`.
- If HTTPS to a non-standard port fails, add that port to `connect_ports`.
- Do not expose the proxy to untrusted networks.
