# syntax=docker/dockerfile:1
ARG SNELL_VERSION=v6.0.0rc

FROM debian:stable-slim AS builder

ARG TARGETPLATFORM=linux/amd64
ARG SNELL_VERSION

RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates wget unzip && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /tmp/snell-build

RUN case "${TARGETPLATFORM}" in \
      "linux/amd64") snell_arch="amd64" ;; \
      "linux/arm64") snell_arch="aarch64" ;; \
      *) echo "Unsupported TARGETPLATFORM: ${TARGETPLATFORM}" >&2; exit 1 ;; \
    esac && \
    wget -q -O snell.zip "https://dl.nssurge.com/snell/snell-server-${SNELL_VERSION}-linux-${snell_arch}.zip" && \
    unzip -q snell.zip && \
    test -x /tmp/snell-build/snell-server

FROM debian:stable-slim

ARG SNELL_VERSION
ARG BUILD_DATE=unknown
ARG VCS_REF=unknown
ARG VCS_URL=https://github.com/angribot/snell-server-docker

LABEL org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.source="${VCS_URL}" \
      org.opencontainers.image.version="${SNELL_VERSION}"

WORKDIR /snell

COPY --from=builder /tmp/snell-build/snell-server /snell/snell-server
COPY entrypoint.sh runtime-config.sh /snell/

RUN chmod +x /snell/snell-server /snell/entrypoint.sh

ENTRYPOINT ["/snell/entrypoint.sh"]
