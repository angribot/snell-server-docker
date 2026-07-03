#!/bin/sh
set -eu

IMAGE="${1:-snell:test}"
PORT_VALUE="${PORT_VALUE:-28345}"
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

expect_failure docker run --rm --init --network host "$IMAGE"
grep -q '\[error\] PSK is required' "$LOG_FILE"

expect_failure docker run --rm --init --network host -e PSK=short "$IMAGE"
grep -q '\[error\] PSK length must be between 12 and 255 bytes' "$LOG_FILE"

CONTAINER_ID="$(docker run -d --init --network host -e PORT="$PORT_VALUE" -e PSK=abcdefghijkl -e DNSIP=ipv4-only -e LOG=debug "$IMAGE")"
sleep 2
docker logs "$CONTAINER_ID" >"$LOG_FILE" 2>&1

grep -q "PORT:${PORT_VALUE}" "$LOG_FILE"
grep -q 'LOG_LEVEL:debug' "$LOG_FILE"
grep -q '\[deprecated\] DNSIP is deprecated' "$LOG_FILE"
grep -q '\[deprecated\] LOG is deprecated' "$LOG_FILE"
! grep -q '^PSK:' "$LOG_FILE"

stop_started="$(date +%s)"
docker stop -t 2 "$CONTAINER_ID" >/dev/null
stop_finished="$(date +%s)"
stop_elapsed=$((stop_finished - stop_started))
exit_code="$(docker inspect -f '{{.State.ExitCode}}' "$CONTAINER_ID")"

if [ "$stop_elapsed" -ge 2 ]; then
  echo "container stop exceeded expected graceful window: ${stop_elapsed}s" >&2
  exit 1
fi

if [ "$exit_code" -eq 137 ]; then
  echo "container was force-killed instead of exiting gracefully" >&2
  exit 1
fi

CONTAINER_ID=""
