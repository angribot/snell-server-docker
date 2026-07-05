#!/bin/sh
set -eu

WORKFLOW=".github/workflows/auto_bump.yaml"

grep -q "30 16 \* \* \*" "$WORKFLOW"
grep -q 'workflow_dispatch' "$WORKFLOW"
grep -q 'REPO_PUSH_TOKEN' "$WORKFLOW"
grep -q 'snell-version-lifecycle.sh state' "$WORKFLOW"
grep -q 'needs_bump' "$WORKFLOW"
grep -q 'git tag -a' "$WORKFLOW"
grep -q 'git push origin "HEAD:' "$WORKFLOW"
