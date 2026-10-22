# syntax=docker/dockerfile:1
ARG SNELL_VERSION=v6.0.0

FROM debian:trixie-slim AS builder

RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates wget unzip libstdc++6 && \
    rm -rf /var/lib/apt/lists/*

ARG TARGETARCH

# BusyBox provides glibc; add only Snell's missing runtime libraries and licenses.
RUN set -eu; \
    case "${TARGETARCH}" in \
      amd64) target=x86_64-linux-gnu ;; \
      arm64) target=aarch64-linux-gnu ;; \
      *) echo "Unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    mkdir -p /runtime/lib /runtime/usr/share/licenses/glibc \
      /runtime/usr/share/licenses/gcc-runtime; \
    for library in libdl.so.2 libstdc++.so.6 libgcc_s.so.1; do \
      cp -L "/usr/lib/${target}/${library}" /runtime/lib/; \
    done; \
    cp /usr/share/doc/libc6/copyright /usr/share/common-licenses/LGPL-2.1 \
      /runtime/usr/share/licenses/glibc/; \
    cp /usr/share/doc/libstdc++6/copyright /usr/share/common-licenses/GPL-3 \
      /runtime/usr/share/licenses/gcc-runtime/

WORKDIR /tmp/snell-build

ARG SNELL_VERSION

RUN case "${TARGETARCH}" in \
      amd64) snell_arch=amd64 ;; \
      arm64) snell_arch=aarch64 ;; \
    esac && \
    wget -q -O snell.zip "https://dl.nssurge.com/snell/snell-server-${SNELL_VERSION}-linux-${snell_arch}.zip" && \
    unzip -q snell.zip && \
    test -x /tmp/snell-build/snell-server

FROM busybox:1.38.0-glibc AS runtime

ARG SNELL_VERSION
ARG BUILD_DATE=unknown
ARG VCS_REF=unknown
ARG VCS_URL=https://github.com/angribot/snell-server-docker

LABEL org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.source="${VCS_URL}" \
      org.opencontainers.image.version="${SNELL_VERSION}"

WORKDIR /snell

COPY --from=builder /runtime/ /
COPY --from=builder --chmod=0755 /tmp/snell-build/snell-server /snell/snell-server
COPY entrypoint.sh runtime-config.sh /snell/

ENTRYPOINT ["/snell/entrypoint.sh"]
