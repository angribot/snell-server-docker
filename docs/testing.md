# Testing

Run commands from the repository root. Tests cover version lifecycle, runtime configuration, and normal image-integration boundaries—not complete encrypted proxy requests or rare failure injection. Keep generated logs and temporary files outside Git.

## Host contracts

Requires a POSIX shell:

```sh
sh tests/release_version_contract.sh
sh tests/latest_version_contract.sh
sh tests/runtime_contract.sh
```

## Linux Docker

Use an IPv6-enabled Linux host and build for its native architecture:

```sh
docker build -t snell:test .
sh tests/docker_smoke.sh snell:test
docker build --target test -t snell:checks .
docker run --rm snell:checks
```

- **Smoke:** runs the production image with init and host networking; waits for IPv4/IPv6 TCP connectivity, checks runtime summaries and that logs do not expose the test PSK, and accepts only exit codes 0 or 143 after stopping. Set `PORT_VALUE` to override port `28345`.
- **Image contract:** reuses the runtime configuration tests under Alpine and checks glibc hosts/DNS resolution using the build's `getent` and a local DNS fixture, without public DNS. Tools and fixtures are confined to the `test` target; the default production image excludes them.

## Apple container

With the `container` system running on macOS:

```sh
container build --platform linux/arm64 -t snell:test .
CONTAINER_ENGINE=container sh tests/docker_smoke.sh snell:test
container build --platform linux/arm64 --target test -t snell:checks .
container run --rm snell:checks
```

For amd64, replace the build platform with `linux/amd64` and export `CONTAINER_DEFAULT_PLATFORM=linux/amd64` for the run commands. These checks use the container VM's network, not Docker's Linux host network.

## CI

Pushes to `main`/`alpine` and pull requests run checks on native `ubuntu-24.04` (amd64) and `ubuntu-24.04-arm` runners. Tag publishing calls the same verification workflow and waits for both architectures before building and pushing.

CI reports Docker's image-size value without a fixed threshold; its interpretation can vary with the Docker storage backend.
