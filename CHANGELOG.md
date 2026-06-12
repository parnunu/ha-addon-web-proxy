# Changelog

## 1.0.2

- Fix HAOS install/build failures caused by downloading Alpine packages during local add-on builds.
- Bundle a small static forward-proxy binary for `aarch64`, `amd64`, and `armv7`.
- Keep HTTP forward proxy and HTTPS `CONNECT` support without requiring `apk add` during installation.

## 1.0.1

- Correct add-on purpose from reverse proxy to forward proxy.
- Replace nginx reverse proxy implementation with HTTP/HTTPS forward proxy behavior.
- Rename add-on slug to `lightweight_forward_proxy`.

## 1.0.0

- Initial release attempt.
