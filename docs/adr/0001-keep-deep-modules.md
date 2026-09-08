# Keep Snell version and runtime config as deep modules

We decided to keep Snell version lifecycle and Snell runtime configuration behind deep modules instead of spreading their rules through workflow YAML, Dockerfile fragments, and entrypoint shell. Version ordering and publishability belong in `snell-version-lifecycle.sh`; environment compatibility, validation, and config rendering belong in `runtime-config.sh`.

Repository-wide grep contracts are not deep modules. They couple tests to filenames and command spelling without verifying behavior, so workflow and README changes are reviewed directly while executable rules are tested through their interfaces.

## Considered Options

- Keep domain rules inline where they are used. This makes each future change bounce across workflows, Dockerfile, entrypoint logic, and tests.
- Put domain rules behind deep modules with thin adapters. Callers get a small interface while version and runtime behavior stay local.
- Centralize README and workflow string checks in a repository contract module. This adds an interface but little leverage because the checks still encode implementation text rather than behavior.

## Consequences

GitHub Actions remain adapters for Snell version lifecycle decisions, and `entrypoint.sh` remains an adapter for Snell runtime configuration. Host tests exercise those interfaces; Docker smoke and image-integration coverage have been removed. Repository documentation and workflow wiring do not have grep-only contract tests.
