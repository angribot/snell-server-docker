# Domain Docs

This repository uses a single-context layout:
- `GLOSSARY.md` at the repository root.
- `docs/adr/` for architectural decisions.

## Before exploring

Read `GLOSSARY.md` and ADRs relevant to the area being explored.

If these files are absent, proceed silently. Domain modeling creates
them lazily when terms or decisions are resolved.

## Use the glossary's vocabulary

Use glossary terms when naming domain concepts in issue titles,
refactor proposals, hypotheses, and tests. Respect explicitly avoided
synonyms.

If a needed concept is missing, reconsider whether it belongs to the
domain or note the gap for domain modeling.

## Flag ADR conflicts

Explicitly identify any proposal that contradicts an existing ADR,
and explain why the decision should be reopened.
