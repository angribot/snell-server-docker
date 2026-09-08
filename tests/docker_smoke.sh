#!/bin/sh
set -eu

IMAGE="${1:-snell:test}"
PORT_VALUE="${PORT_VALUE:-28345}"
CONTAINER_ENGINE="${CONTAINER_ENGINE:-docker}"
CONTAINER_NAME="snell-smoke-$$"
PSK_VALUE=snell-smoke-test-key
LOG_FILE="$(mktemp)"
RUN_PID=""

cleanup() {
  result=$?
  if [ "$result" -ne 0 ]; then
    cat "$LOG_FILE" >&2
  fi
  "$CONTAINER_ENGINE" rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
  if [ -n "$RUN_PID" ]; then
    wait "$RUN_PID" 2>/dev/null || true
  fi
  rm -f "$LOG_FILE"
}
trap cleanup EXIT

case "$CONTAINER_ENGINE" in
  docker) set -- --network host ;;
  container) set -- ;;
  *) echo "CONTAINER_ENGINE must be docker or container" >&2; exit 1 ;;
esac

# Keep the attached process so both engines expose the actual exit status.
"$CONTAINER_ENGINE" run --init --name "$CONTAINER_NAME" "$@" \
  -e PORT="$PORT_VALUE" -e PSK="$PSK_VALUE" \
  -e DNS_IP_PREFERENCE=ipv4-only -e LOG_LEVEL=verbose "$IMAGE" >"$LOG_FILE" 2>&1 &
RUN_PID=$!

attempt=0
until "$CONTAINER_ENGINE" exec "$CONTAINER_NAME" nc -z -w 1 127.0.0.1 "$PORT_VALUE" >/dev/null 2>&1 && \
  "$CONTAINER_ENGINE" exec "$CONTAINER_NAME" nc -z -w 1 ::1 "$PORT_VALUE" >/dev/null 2>&1; do
  if ! kill -0 "$RUN_PID" 2>/dev/null; then
    echo "container exited before Snell was ready" >&2
    exit 1
  fi
  attempt=$((attempt + 1))
  if [ "$attempt" -ge 30 ]; then
    echo "Snell did not listen on both IPv4 and IPv6 before the timeout" >&2
    exit 1
  fi
  sleep 1
done

grep -Fxq "PORT:${PORT_VALUE}" "$LOG_FILE"
grep -Fxq 'LOG_LEVEL:verbose' "$LOG_FILE"
grep -Fxq 'DNS_IP_PREFERENCE:ipv4-only' "$LOG_FILE"

"$CONTAINER_ENGINE" stop -t 2 "$CONTAINER_NAME" >/dev/null
exit_code=0
wait "$RUN_PID" || exit_code=$?
RUN_PID=""

if grep -Fq "$PSK_VALUE" "$LOG_FILE" || grep -q '^PSK:' "$LOG_FILE"; then
  echo "container logs must not expose PSK" >&2
  exit 1
fi

case "$exit_code" in
  0|143) ;;
  *) echo "unexpected container exit code: ${exit_code}" >&2; exit 1 ;;
esac

printf 'Snell smoke passed: %s (exit %s)\n' "$IMAGE" "$exit_code"
