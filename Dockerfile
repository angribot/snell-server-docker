# syntax=docker/dockerfile:1
ARG SNELL_VERSION=v6.0.0rc2

FROM --platform=$BUILDPLATFORM debian:trixie-slim AS builder

ARG TARGETARCH
# Update the version and source checksum together.
ARG GLIBC_VERSION=2.44
ARG GLIBC_SHA256=37f600f2bef3c5e8300147059568b2a2e40a7ad6ccc65ce942556d49429cc667

RUN case "${TARGETARCH}" in \
      amd64) toolchain=x86-64; cross_arch=amd64 ;; \
      arm64) toolchain=aarch64; cross_arch=arm64 ;; \
      *) echo "Unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates wget unzip xz-utils make bison gawk python3 gcc \
      "gcc-${toolchain}-linux-gnu" "libc6-dev-${cross_arch}-cross" && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /tmp/glibc-build

RUN wget -q -O glibc.tar.xz "https://ftp.gnu.org/gnu/glibc/glibc-${GLIBC_VERSION}.tar.xz" && \
    echo "${GLIBC_SHA256}  glibc.tar.xz" | sha256sum -c - && \
    tar -xf glibc.tar.xz && \
    mkdir build && cd build && \
    case "${TARGETARCH}" in \
      amd64) target=x86_64-linux-gnu ;; \
      arm64) target=aarch64-linux-gnu ;; \
    esac && \
    CC="${target}-gcc" ../glibc-${GLIBC_VERSION}/configure \
      --build="$(gcc -dumpmachine)" --host="${target}" \
      --prefix=/opt/glibc --libdir=/opt/glibc/lib \
      --with-headers="/usr/${target}/include" \
      --disable-werror --disable-nscd --enable-stack-protector=strong \
      CFLAGS="-O2 -g0" && \
    make -j"$(nproc)" && \
    make install DESTDIR=/tmp/glibc-install

# Keep the loader, DNS support and Snell's runtime libraries, not development files.
RUN case "${TARGETARCH}" in \
      amd64) target=x86_64-linux-gnu ;; \
      arm64) target=aarch64-linux-gnu ;; \
    esac && \
    mkdir -p /runtime/opt/glibc/lib && \
    cp -a /tmp/glibc-install/opt/glibc/lib/ld-linux*.so.* /runtime/opt/glibc/lib/ && \
    for library in libc.so.6 libm.so.6 libdl.so.2 \
      libpthread.so.0 librt.so.1 libresolv.so.2; do \
      cp -a "/tmp/glibc-install/opt/glibc/lib/${library}" /runtime/opt/glibc/lib/ || exit 1; \
    done && \
    for library in libstdc++.so.6 libgcc_s.so.1; do \
      cp -L "$(${target}-gcc -print-file-name=${library})" \
        "/runtime/opt/glibc/lib/${library}" || exit 1; \
    done && \
    ${target}-strip --strip-unneeded /runtime/opt/glibc/lib/*.so* && \
    mkdir -p /runtime/usr/share/licenses/glibc && \
    cp glibc-${GLIBC_VERSION}/COPYING.LIB glibc-${GLIBC_VERSION}/LICENSES \
      /runtime/usr/share/licenses/glibc/ && \
    mkdir -p /runtime/usr/share/licenses/gcc-runtime && \
    cp /usr/share/doc/gcc-$(${target}-gcc -dumpversion)-base/copyright \
      /usr/share/common-licenses/GPL-3 /runtime/usr/share/licenses/gcc-runtime/ && \
    case "${TARGETARCH}" in \
      amd64) mkdir -p /runtime/lib64; \
        ln -s /opt/glibc/lib/ld-linux-x86-64.so.2 /runtime/lib64/ld-linux-x86-64.so.2 ;; \
      arm64) mkdir -p /runtime/lib; \
        ln -s /opt/glibc/lib/ld-linux-aarch64.so.1 /runtime/lib/ld-linux-aarch64.so.1 ;; \
    esac

WORKDIR /tmp/snell-build

ARG SNELL_VERSION

RUN case "${TARGETARCH}" in \
      amd64) snell_arch=amd64 ;; \
      arm64) snell_arch=aarch64 ;; \
    esac && \
    wget -q -O snell.zip "https://dl.nssurge.com/snell/snell-server-${SNELL_VERSION}-linux-${snell_arch}.zip" && \
    unzip -q snell.zip && \
    test -x /tmp/snell-build/snell-server

FROM alpine:3.23 AS runtime

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
COPY --from=builder /tmp/snell-build/snell-server /snell/snell-server
COPY entrypoint.sh runtime-config.sh /snell/

RUN chmod +x /snell/snell-server /snell/entrypoint.sh

ENTRYPOINT ["/snell/entrypoint.sh"]

FROM runtime AS test

RUN apk add --no-cache dnsmasq
COPY --from=builder /tmp/glibc-install/opt/glibc/bin/getent /usr/local/bin/glibc-getent
COPY tests/runtime_contract.sh tests/image_contract.sh /snell/tests/
ENTRYPOINT ["/bin/sh", "/snell/tests/image_contract.sh"]

# The default build remains the production image, without test tools or fixtures.
FROM runtime AS final
