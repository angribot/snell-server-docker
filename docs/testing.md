# Testing

Run commands from the repository root. Tests cover version lifecycle and runtime configuration on the host, not built-image behavior. Keep generated logs and temporary files outside Git.

## Host contracts

Requires a POSIX shell:

```sh
sh tests/release_version_contract.sh
sh tests/latest_version_contract.sh
sh tests/runtime_contract.sh
```

## Shell syntax

```sh
sh -n entrypoint.sh
sh -n runtime-config.sh
sh -n .github/scripts/snell-version-lifecycle.sh
sh -n tests/release_version_contract.sh
sh -n tests/latest_version_contract.sh
sh -n tests/runtime_contract.sh
```

## CI and publishing

Pull requests and pushes to `main` run shell syntax checks and all three host contracts on a single `ubuntu-latest` runner. Running these lightweight checks on both events is intentional. CI does not build images, run Docker smoke or Alpine/glibc image contracts, or report image size.

Publishing is independent of CI: it does not run tests or wait for verification. Tag-triggered publishing still validates the tag against the Bundled Snell Version, publishes the version tag, and updates `latest` only when the tagged commit is the live default branch HEAD. Manual publishing updates only `latest` and requires both the default branch ref and its live HEAD. Production builds still build and push `linux/amd64` and `linux/arm64` images.

Published images are not runtime-tested. Host contracts do not verify Alpine shell behavior, glibc hosts/DNS resolution, container startup, networking, or shutdown; this coverage gap is an accepted risk.
