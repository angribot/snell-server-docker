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

- Tag-triggered builds require the Git tag name to match the bundled `SNELL_VERSION`
- The build fails if the tag and bundled version differ
- Until Snell Server v6 stable is released, `latest` points to the newest validated beta image

## Networking Notes

- `host` mode is the primary and recommended deployment path
- bridge / port mapping is not the main support path
- For IPv6 deployments, prefer `host` mode
