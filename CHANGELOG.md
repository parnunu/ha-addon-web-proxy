# Changelog

## 1.0.3

- Add `build.yaml` so HAOS Supervisor passes the correct Home Assistant base image for each architecture.
- Fix aarch64 installs failing when Docker tried to build from the amd64 base image.

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
