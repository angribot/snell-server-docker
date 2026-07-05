# Keep Snell version, runtime config, and repository contracts as deep modules

We decided to keep Snell version lifecycle, Snell runtime configuration, and repository contract verification behind deep modules instead of spreading their rules through workflow YAML, entrypoint shell, Dockerfile fragments, and grep-only test scripts. The reason is locality: version ordering, publishability, env validation, config rendering, and repository-wide contracts should each have one interface where future changes concentrate.

## Considered Options

- Keep rules inline where they are used. This keeps files small at first, but makes each future change bounce across workflows, Dockerfile, entrypoint logic, docs, and tests.
- Put the rules behind deep modules with thin adapters. This makes the module interface more deliberate, but gives callers leverage and keeps workflow/test adapters shallow.

## Consequences

Future maintenance should deepen these modules rather than bypass them. GitHub Actions remain adapters for version lifecycle decisions, `entrypoint.sh` remains an adapter for Snell runtime configuration, and the small contract scripts remain adapters for `tests/repository_contract.sh`.
