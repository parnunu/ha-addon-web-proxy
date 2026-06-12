# Lightweight Forward Proxy Home Assistant Add-on

A small Home Assistant OS add-on that runs a bundled HTTP/HTTPS forward proxy.

Use it when devices or services on your network need an outbound proxy endpoint running on HAOS.

## Features

- No Alpine package download during HAOS install; the proxy binary is bundled in the add-on source.
- HTTP proxy support.
- HTTPS tunneling via `CONNECT` for configured ports.
- Configurable listen port, allowed client networks, max clients, CONNECT ports, optional upstream proxy, and log level.

## Install

1. Add this add-on repository in Home Assistant:
   `https://github.com/parnunu/home-assistant-addons`
2. Refresh the add-on store.
3. Install **Lightweight Forward Proxy**.
4. Configure allowed client networks.
5. Start the add-on.
6. Point clients at `http://<home-assistant-host>:8888` or your configured port.

## Options

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

- `port`: Forward proxy listen port inside the add-on and default host mapping.
- `allowed_networks`: Client IP addresses or CIDR ranges allowed to use the proxy.
- `max_clients`: Maximum simultaneous proxy clients.
- `connect_ports`: Ports allowed for HTTPS `CONNECT` tunneling.
- `upstream_proxy`: Optional parent proxy as `host:port`.
- `log_level`: Reserved for add-on UI compatibility; current logs go to stdout.

## Client examples

```bash
curl -x http://homeassistant.local:8888 http://example.com/
curl -x http://homeassistant.local:8888 https://example.com/
```

## Security notes

Do not expose this proxy to the public internet. Keep `allowed_networks` as narrow as practical and only map the port on trusted networks.
