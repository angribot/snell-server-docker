#!/bin/sh
set -eu

DOCKERFILE_PATH="${1:-Dockerfile}"
SNELL_VERSION="$(awk -F= '/^ARG SNELL_VERSION=/{print $2; exit}' "$DOCKERFILE_PATH")"

if [ -z "$SNELL_VERSION" ]; then
  echo "SNELL_VERSION arg not found in ${DOCKERFILE_PATH}" >&2
  exit 1
fi

if [ "${GITHUB_REF_TYPE:-}" = "tag" ] && [ "${GITHUB_REF_NAME:-}" != "$SNELL_VERSION" ]; then
  echo "Git tag ${GITHUB_REF_NAME:-<unset>} does not match SNELL_VERSION ${SNELL_VERSION}" >&2
  exit 1
fi

printf '%s\n' "$SNELL_VERSION"
