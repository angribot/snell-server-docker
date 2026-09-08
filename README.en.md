# Snell Server Docker

[中文](README.md)

A Snell Server Docker image for Linux server/VPS deployments.

## Features

- Linux server/VPS only
- `host` networking is the recommended mode
- No mounted config file required
- Runtime configuration is generated from environment variables
- Containers must enable Docker init at runtime: `docker run --init` or Compose `init: true`

## Quick Start

### docker run

```shell
docker run -d \
  --name snell \
  --init \
  --network host \
  -e PSK=your_secure_password \
  angribot/snell:latest
```

### docker compose

```yaml
services:
  snell:
    image: angribot/snell:latest
    container_name: snell
    restart: always
    init: true
    network_mode: host
    environment:
      PSK: your_secure_password
```

## Environment Variables

| Variable | Required | Default | Description |
| --- | --- | --- | --- |
| `PSK` | Yes | None | Pre-shared key. Length must be 12-255 bytes |
| `PORT` | No | `2345` | Snell listen port |
| `MODE` | No | `default` | Allowed values: `default`, `unshaped`, `unsafe-raw` |
| `DNS` | No | None | Comma-separated DNS server list |
| `DNS_IP_PREFERENCE` | No | None | Allowed values: `default`, `prefer-ipv4`, `prefer-ipv6`, `ipv4-only`, `ipv6-only` |
| `EGRESS_INTERFACE` | No | None | Outbound interface name for Snell traffic |
| `LOG_LEVEL` | No | `notify` | Value passed to `snell-server -l` |

## Compatibility and Deprecation

The following legacy environment variables still work, but the container prints a deprecation warning when they are used:

- `DNSIP` -> `DNS_IP_PREFERENCE`
- `EGRESS` -> `EGRESS_INTERFACE`
- `LOG` -> `LOG_LEVEL`

These legacy names will be removed when Snell Server v6 stable is released.

`VERSION` is no longer a runtime setting. The Snell binary version is selected when the image is built.

## Versioning

- Stable versions use `vX.Y.Z`, release candidates use `vX.Y.Zrc` or `vX.Y.ZrcN`, and beta versions use `vX.Y.ZbN`
- A bare `rc` sorts as `rc1`; versions with the same `X.Y.Z` sort as beta, release candidate, then stable
- Tag-triggered builds require the Git tag name to match the bundled `SNELL_VERSION`
- The build fails if the tag and bundled version differ
- Tag-triggered publishing updates `latest` only when the tagged commit is also the live default branch HEAD; before Snell Server v6 stable, it can point to a beta or release candidate that passes version validation
- Manual publishing updates only `latest` and requires the default branch ref at its live HEAD

## Auto Update

The repository includes an optional GitHub Actions workflow: `.github/workflows/auto_bump.yaml`.

- It runs every day at `23:00` China Standard Time (`0 15 * * *` in GitHub UTC cron)
- It fetches the Snell release notes page and resolves the newest downloadable version
- It only updates `SNELL_VERSION` when that resolved version is strictly newer than the version currently bundled in `Dockerfile`
- When an update is found, it creates a commit named `chore: bump snell to <version>` and a Git tag with the same version name

To let that automated tag still trigger the existing Docker publish workflow, configure the repository secret `REPO_PUSH_TOKEN`.

- The default `GITHUB_TOKEN` is not enough because push / tag events created by it do not trigger downstream workflows
- The token needs write access to this repository

## Image Build

The runtime uses official `alpine:3.23`, not a third-party alpine-glibc image or `gcompat`. Alpine's musl remains intact for its system tools.

An official Debian builder compiles [GNU glibc 2.44](https://ftp.gnu.org/gnu/glibc/glibc-2.44.tar.xz) from source, verified by the SHA-256 in `Dockerfile`, for `linux/amd64` and `linux/arm64`. The target compiler runs on the build host architecture. glibc is installed under `/opt/glibc`; only the loader, selected stripped shared libraries, and matching GNU C++/GCC runtime libraries from Debian enter the final image. Compiler tools, headers, static libraries, locale archives, and build sources are excluded. Runtime library license notices are retained under `/usr/share/licenses`.

```shell
docker buildx build --platform linux/amd64 --load -t snell:alpine .
```

`GLIBC_VERSION` and `GLIBC_SHA256` must be updated together. glibc and the copied GNU runtime libraries are not managed by Alpine's `apk`: security updates require rebuilding the image, using `--pull --no-cache` to refresh the builder packages. Changing only `SNELL_VERSION` can reuse the glibc build cache. This is a minimal Snell runtime, not a general-purpose glibc environment; full locale and character conversion modules are intentionally omitted.

## Tests

CI runs shell syntax checks and host contracts for version rules and runtime configuration on pull requests and pushes to `main`, using one `ubuntu-latest` runner. Publishing runs independently without a test gate. Published images are not runtime-tested; this is an accepted risk. See the [testing guide](docs/testing.md) for commands and coverage limits.

## Networking Notes

- `host` mode is the primary and recommended deployment path
- bridge / port mapping is not the main support path
- For IPv6 deployments, prefer `host` mode
