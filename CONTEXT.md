# Snell Server Docker

This context describes how the repository packages and publishes a Snell Server Docker image.

## Language

**Bundled Snell Version**:
The Snell Server version selected at image build time and recorded in the Dockerfile. Runtime configuration does not change it.
_Avoid_: runtime VERSION, image version

**Snell Version Ordering**:
The ordering rule for Snell release identifiers. Stable releases use `vX.Y.Z`; beta releases use `vX.Y.ZbN`; all numeric parts compare numerically, and a stable `vX.Y.Z` is higher than any beta `vX.Y.ZbN` with the same `X.Y.Z`.
_Avoid_: lexical ordering, tag ordering

**Publishable Snell Version**:
A Snell Server version whose release assets are available for every supported image platform before the Docker image is built and published.
_Avoid_: partially available version, amd64-only version

**Version Bump**:
An update that changes the Bundled Snell Version only when the latest resolved Publishable Snell Version is strictly higher under Snell Version Ordering.
_Avoid_: version sync, auto update
