#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DOCKERFILE_PATH="${1:-Dockerfile}"

sh "$SCRIPT_DIR/snell-version-lifecycle.sh" validate-current "$DOCKERFILE_PATH"
