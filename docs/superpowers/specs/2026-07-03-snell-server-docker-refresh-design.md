# Snell Server Docker Refresh Design

Status: Draft for review
Date: 2026-07-03
Repo: `snell-server-docker`

## Summary

This design refreshes the repository from a lightweight wrapper into a more predictable Docker image for Linux server/VPS deployments.

The core shift is:

- download `snell-server` at image build time, not container startup time
- treat runtime environment variables as the only supported configuration input
- require `PSK` explicitly instead of generating random credentials
- keep `host` networking as the primary and documented deployment mode
- preserve old environment variable names during a transition period, with explicit deprecation warnings
- enforce that release tags and bundled Snell binary versions always match

## Confirmed Constraints

These constraints were confirmed during design discussion and are treated as hard requirements:

- Target environment is Linux server/VPS only.
- Recommended network mode is `host`.
- Bridge mode and Docker port mapping are not the primary support path, especially for IPv6.
- The image should not require mounted configuration files.
- `PSK` must be provided by the operator and must not be randomly generated.
- Default `PORT` is `2345`.
- Old environment variables remain temporarily supported, with a plan to remove them when Snell Server v6 stable is released.
- Before Snell Server v6 stable is released, `latest` should continue to point at the newest beta image that passes tag/version validation.

## Goals

- Make image contents reproducible and independent from runtime network availability.
- Make container behavior deterministic from environment variables alone.
- Reduce surprise in credentials, ports, and startup output.
- Keep the repository small and easy to maintain.
- Improve documentation quality and CI coverage without over-engineering the project.

## Non-Goals

- Supporting Docker Desktop on macOS or Windows.
- Making bridge networking a first-class deployment path.
- Supporting mounted `snell.conf` as a primary workflow.
- Turning the repository into a large multi-script or multi-service project.
- Defining the final post-v6-stable meaning of `latest`.

## Current Repository Assessment

The repository is intentionally small and already has a workable top-level structure:

- `Dockerfile` prepares the runtime environment.
- `entrypoint.sh` currently downloads Snell, generates config, and starts the server.
- `README.md` documents usage.
- `.github/workflows/docker_build.yaml` publishes the image.

The structure itself is acceptable for a single-purpose image repo. The main problems are behavioral:

- runtime download of `snell-server` makes images non-reproducible
- random `PSK` and random `PORT` create unstable runtime behavior
- startup logs expose sensitive material
- docs and implementation have already drifted
- release metadata and validation are incomplete
- CI coverage is minimal

## Proposed Repository Shape

The repository should stay small and flat. The proposed shape is:

```text
.
├── .github/workflows/
│   ├── ci.yaml
│   └── docker_build.yaml
├── .dockerignore
├── Dockerfile
├── README.md
├── README.en.md
├── entrypoint.sh
└── docs/superpowers/specs/
    └── 2026-07-03-snell-server-docker-refresh-design.md
```

This keeps the current simplicity while adding the missing operational and documentation pieces.

`snell-server-help.txt` is treated as a temporary analysis artifact used during the redesign. It is not part of the intended final repository shape and may be removed after the refactor is implemented and verified.

## Runtime Contract

### Primary environment variables

These are the only environment variables documented in the new README files:

- `PSK`: required
- `PORT`: optional, default `2345`
- `MODE`: optional
- `DNS`: optional
- `DNS_IP_PREFERENCE`: optional
- `EGRESS_INTERFACE`: optional
- `LOG_LEVEL`: optional, default `notify`

### Mapping to Snell config

The runtime contract maps env vars to Snell parameters as follows:

- `PSK` -> `psk`
- `PORT` -> `listen = 0.0.0.0:<PORT>,[::]:<PORT>`
- `MODE` -> `mode`
- `DNS` -> `dns`
- `DNS_IP_PREFERENCE` -> `dns-ip-preference`
- `EGRESS_INTERFACE` -> `egress-interface`
- `LOG_LEVEL` -> `snell-server -l`

### Backward compatibility

Old names remain supported during the transition window:

- `DNSIP` -> `DNS_IP_PREFERENCE`
- `EGRESS` -> `EGRESS_INTERFACE`
- `LOG` -> `LOG_LEVEL`

Compatibility behavior:

- if only the old name is provided, map it to the new name and print a deprecation warning
- if both old and new names are provided, the new name wins
- README examples must use only the new names
- deprecation warnings must clearly state that old names will be removed when Snell Server v6 stable is released

Example warning text:

```text
[deprecated] DNSIP is deprecated and will be removed when Snell Server v6 stable is released. Use DNS_IP_PREFERENCE instead.
```

### Runtime treatment of `VERSION`

`VERSION` should no longer control runtime behavior.

If `VERSION` is provided at runtime:

- print a deprecation warning
- ignore the value
- continue startup using the binary already bundled into the image

This keeps binary versioning in the build phase, where it belongs.

## Startup Lifecycle

The container startup flow should become a pure translation from env vars to config file plus process launch.

### Flow

1. Read new environment variables.
2. Read old compatibility variables only when the new names are absent.
3. Print deprecation warnings for any old names that were used.
4. Validate required values and enums.
5. Apply defaults.
6. Generate `/snell/snell.conf` from scratch.
7. Print a non-sensitive startup summary.
8. `exec` the Snell process.

### Init and signal handling

The final container should continue to run behind `tini`.

Reasoning:

- it improves signal forwarding to `snell-server`
- it avoids relying on operators to remember Docker's optional `--init` flag
- it reduces the chance that `docker stop` waits for the full timeout before the container exits
- it provides normal PID 1 child reaping behavior

`tini` is therefore treated as part of the runtime contract, not as an incidental package.

### Validation rules

- `PSK` is required.
- `PSK` length must be between 12 and 255 bytes.
- `PORT` must be a valid integer in the range `1-65535`.
- `MODE` must be one of `default`, `unshaped`, or `unsafe-raw`.
- `DNS_IP_PREFERENCE` must be one of `default`, `prefer-ipv4`, `prefer-ipv6`, `ipv4-only`, or `ipv6-only`.
- `LOG_LEVEL` defaults to `notify`.

`LOG_LEVEL` should not use a hardcoded whitelist unless an authoritative upstream list is available. For now, the image should guarantee a default and reject only empty values when explicitly set. This avoids blocking valid upstream values by mistake.

### Generated config behavior

- `/snell/snell.conf` is generated on every startup.
- the config file is a runtime artifact, not durable state.
- no mounted config is required or expected.
- optional config lines are emitted only when their env vars are present.

### Startup summary

The startup summary should be operator-friendly but must not expose secrets.

Allowed in logs:

- `PORT`
- `MODE` when set
- `DNS` when set
- `DNS_IP_PREFERENCE` when set
- `EGRESS_INTERFACE` when set
- `LOG_LEVEL`
- whether deprecated env names were detected

Not allowed in logs:

- `PSK`

## Build Strategy

### Build-time download

`snell-server` should be downloaded during `docker build` instead of at runtime.

Effects:

- image contents become reproducible
- runtime no longer depends on network reachability
- startup becomes faster
- download failures happen in CI/build, not in production startup paths

### Build stages and dependency boundaries

The Docker image should use a multi-stage build.

Builder stage responsibilities:

- install fetch and archive tools such as `wget` and `unzip`
- download the selected Snell release archive
- extract the `snell-server` binary
- fail early if the archive layout is not as expected

Final runtime stage responsibilities:

- copy in the extracted `snell-server` binary
- copy in `entrypoint.sh`
- include only runtime dependencies

Dependency expectations:

- `unzip` is builder-only and must not remain in the final runtime image
- `tini` remains in the final runtime image as an explicit dependency

This keeps the runtime image smaller and clearer while preserving predictable container behavior.

### Build inputs

The build should use:

- `TARGETPLATFORM` to select the correct archive
- `SNELL_VERSION` as the build-time binary version input
- optional metadata args such as `BUILD_DATE`

### Platform scope

Published release targets should remain aligned with the current workflow:

- `linux/amd64`
- `linux/arm64`

If additional architectures are kept in local build logic, they should not be documented as supported unless they are also included in CI and release publishing.

### Image metadata

The Dockerfile should accept metadata build args and write OCI labels such as:

- creation time
- source repository
- image revision
- bundled Snell version

This closes the gap between workflow metadata and the final image.

## Release and Versioning Strategy

### Version boundaries

There are two distinct version layers:

1. Docker image version
2. bundled Snell binary version

The design makes these layers consistent but keeps their responsibilities separate:

- runtime env config controls server behavior
- build-time version selection controls which Snell binary is embedded

### Tag/version consistency rule

When a Git tag triggers a release build:

- the Git tag name must equal `SNELL_VERSION`
- if they do not match, the build must fail

This prevents publishing an image whose tag says one version but whose bundled binary is another.

### `latest` behavior before v6 stable

Until Snell Server v6 stable is released:

- `latest` should point to the newest beta image that passes the tag/version consistency rule
- only validated tag builds are allowed to move `latest`

After v6 stable is released, the meaning of `latest` can be revised in a separate design update.

## CI Strategy

A new CI workflow should be added for regular validation outside release publishing.

Minimum CI scope:

- syntax check for `entrypoint.sh` using `bash -n`
- image build
- smoke test: startup fails when `PSK` is missing
- smoke test: startup reaches the server process when minimal required env is present
- smoke test: container stops promptly under `docker stop` without waiting for the default timeout

This is intentionally narrow. The repo does not need a large test matrix yet, but it does need proof that its runtime contract works.

## Documentation Strategy

### File layout

Documentation should be split into two README files:

- `README.md`: Chinese
- `README.en.md`: English

The two files should link to each other at the top and keep the same structure.

### README structure

Both README files should contain the same sections:

1. Project positioning
2. Quick start
3. Environment variables
4. Compatibility and deprecation
5. Versioning behavior
6. Networking notes

### Documentation messaging

The README files should state clearly:

- Linux server/VPS only
- `host` networking is the recommended and primary path
- mounted config files are not required
- `PSK` is required
- `PORT` defaults to `2345`
- bridge mode is not the main supported path, especially for IPv6
- the image includes `tini` so normal `docker stop` behavior does not depend on users passing `--init`

The main examples should be:

- `docker run --network host ...`
- `docker compose` with `network_mode: host`

Examples should use only the new environment variable names.

## Migration Notes

From the current implementation to the new design:

- runtime download of Snell is removed
- random `PORT` generation is removed
- random `PSK` generation is removed
- secret logging is removed
- old env names remain functional temporarily
- runtime `VERSION` is ignored and deprecated

This is a behavior cleanup, not a feature expansion.

## Risks and Trade-offs

### Benefits

- more predictable runtime behavior
- simpler incident debugging
- better release integrity
- smaller operational surprise surface

### Trade-offs

- users who relied on runtime `VERSION` changes must adapt to image-based version selection
- users of old env names will see warnings until they migrate
- bridge networking remains possible but intentionally under-documented

These trade-offs are acceptable because they directly support the repo's stated operating model.

## Acceptance Criteria

The design is considered implemented when all of the following are true:

- the image no longer downloads `snell-server` at container startup
- `PSK` is required and validated
- `PORT` defaults to `2345`
- generated config is derived from env vars on every startup
- `PSK` is never printed to logs
- old env names still work and produce deprecation warnings
- runtime `VERSION` is ignored with warning
- release builds fail when Git tag and bundled Snell version differ
- `latest` continues to track the newest validated beta until v6 stable is released
- both Chinese and English README files exist and match the new contract
- CI verifies the runtime contract at a basic level
