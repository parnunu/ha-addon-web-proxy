ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base:latest
FROM $BUILD_FROM

ARG BUILD_ARCH
ARG BUILD_DATE
ARG BUILD_DESCRIPTION="Lightweight tinyproxy-based HTTP/HTTPS forward proxy for Home Assistant OS."
ARG BUILD_NAME="Lightweight Forward Proxy"
ARG BUILD_REF
ARG BUILD_VERSION

LABEL \
    io.hass.name="${BUILD_NAME}" \
    io.hass.description="${BUILD_DESCRIPTION}" \
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.type="addon" \
    io.hass.version="${BUILD_VERSION}" \
    maintainer="parnunu" \
    org.opencontainers.image.created="${BUILD_DATE}" \
    org.opencontainers.image.description="${BUILD_DESCRIPTION}" \
    org.opencontainers.image.documentation="https://github.com/parnunu/ha-addon-web-proxy" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.revision="${BUILD_REF}" \
    org.opencontainers.image.source="https://github.com/parnunu/ha-addon-web-proxy" \
    org.opencontainers.image.title="${BUILD_NAME}" \
    org.opencontainers.image.version="${BUILD_VERSION}"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apk add --no-cache \
    bash \
    jq \
    tinyproxy

COPY run.sh /run.sh
RUN chmod 755 /run.sh && \
    mkdir -p /etc/tinyproxy /var/log/tinyproxy /run/tinyproxy

CMD ["/run.sh"]
