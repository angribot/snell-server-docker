# Snell Server Docker

This context describes how the repository packages and publishes a Snell Server Docker image.

## Language

**Snell Runtime Configuration**:
The container startup configuration derived from environment variables and rendered into the Snell Server config file. It includes required secret material, listen settings, DNS behavior, egress behavior, and log level.
_Avoid_: mounted config, runtime version

**Bundled Snell Version**:
The Snell Server version selected at image build time and recorded in the Dockerfile. Snell Runtime Configuration does not change it.
_Avoid_: runtime VERSION, image version

**Snell Version Ordering**:
The ordering rule for Snell release identifiers. Stable releases use `vX.Y.Z`, release candidates use `vX.Y.Zrc` or `vX.Y.ZrcN`, and beta releases use `vX.Y.ZbN`. All numeric parts compare numerically. A bare `rc` has release candidate number 1, and versions with the same `X.Y.Z` order as beta, release candidate, then stable.
_Avoid_: lexical ordering, tag ordering

**Publishable Snell Version**:
A Snell Server version whose release assets are available for every supported image platform before the Docker image is built and published.
_Avoid_: partially available version, amd64-only version

**Version Bump**:
An update that changes the Bundled Snell Version only when the latest resolved Publishable Snell Version is strictly higher under Snell Version Ordering.
_Avoid_: version sync, auto update
