#!/bin/sh
set -eu

IMAGE="${1:-snell:test}"
LOG_FILE="$(mktemp)"
CONTAINER_ID=""

cleanup() {
  rm -f "$LOG_FILE"
  if [ -n "$CONTAINER_ID" ]; then
    docker rm -f "$CONTAINER_ID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

expect_failure() {
  if "$@" >"$LOG_FILE" 2>&1; then
    echo "expected failure but command succeeded: $*" >&2
    cat "$LOG_FILE" >&2
    exit 1
  fi
}

expect_failure docker run --rm --init "$IMAGE"
grep -q '\[error\] PSK is required' "$LOG_FILE"

expect_failure docker run --rm --init -e PSK=short "$IMAGE"
grep -q '\[error\] PSK length must be between 12 and 255 bytes' "$LOG_FILE"

CONTAINER_ID="$(docker run -d --init -e PSK=abcdefghijkl -e DNSIP=ipv4-only -e LOG=debug "$IMAGE")"
sleep 2
docker logs "$CONTAINER_ID" >"$LOG_FILE" 2>&1

grep -q 'PORT:2345' "$LOG_FILE"
grep -q 'LOG_LEVEL:debug' "$LOG_FILE"
grep -q '\[deprecated\] DNSIP is deprecated' "$LOG_FILE"
grep -q '\[deprecated\] LOG is deprecated' "$LOG_FILE"
! grep -q '^PSK:' "$LOG_FILE"

docker stop -t 2 "$CONTAINER_ID" >/dev/null
CONTAINER_ID=""
