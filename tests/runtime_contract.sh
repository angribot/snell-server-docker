#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
ENTRYPOINT="$ROOT_DIR/entrypoint.sh"
SNELL_HOME_DIR="$(mktemp -d)"
LOG_FILE="$(mktemp)"

cleanup() {
  rm -rf "$SNELL_HOME_DIR" "$LOG_FILE"
}
trap cleanup EXIT

mkdir -p "$SNELL_HOME_DIR"
cat >"$SNELL_HOME_DIR/snell-server" <<'EOF'
#!/bin/sh
echo "SNELL_STUB:$*"
EOF
chmod +x "$SNELL_HOME_DIR/snell-server"

expect_failure() {
  if "$@" >"$LOG_FILE" 2>&1; then
    echo "expected failure but command succeeded: $*" >&2
    cat "$LOG_FILE" >&2
    exit 1
  fi
}

expect_failure env SNELL_HOME="$SNELL_HOME_DIR" /bin/sh "$ENTRYPOINT"
grep -q '\[error\] PSK is required' "$LOG_FILE"

expect_failure env SNELL_HOME="$SNELL_HOME_DIR" PSK=short /bin/sh "$ENTRYPOINT"
grep -q '\[error\] PSK length must be between 12 and 255 bytes' "$LOG_FILE"

expect_failure env SNELL_HOME="$SNELL_HOME_DIR" PSK="abcdefghijkl
mode = unsafe-raw" /bin/sh "$ENTRYPOINT"
grep -q '\[error\] PSK must not contain control characters' "$LOG_FILE"

expect_failure env SNELL_HOME="$SNELL_HOME_DIR" PSK=abcdefghijkl DNS="8.8.8.8
mode = unsafe-raw" /bin/sh "$ENTRYPOINT"
grep -q '\[error\] DNS must not contain control characters' "$LOG_FILE"

env \
  SNELL_HOME="$SNELL_HOME_DIR" \
  PSK=abcdefghijkl \
  DNSIP=ipv4-only \
  LOG=debug \
  VERSION=v9.9.9 \
  /bin/sh "$ENTRYPOINT" >"$LOG_FILE" 2>&1

grep -q 'PORT:2345' "$LOG_FILE"
grep -q 'LOG_LEVEL:debug' "$LOG_FILE"
grep -q '\[deprecated\] DNSIP is deprecated' "$LOG_FILE"
grep -q '\[deprecated\] LOG is deprecated' "$LOG_FILE"
grep -q '\[deprecated\] VERSION is deprecated and ignored' "$LOG_FILE"
! grep -q '^PSK:' "$LOG_FILE"

grep -q '^listen = 0.0.0.0:2345,\[::\]:2345$' "$SNELL_HOME_DIR/snell.conf"
grep -q '^psk = abcdefghijkl$' "$SNELL_HOME_DIR/snell.conf"
grep -q '^dns-ip-preference = ipv4-only$' "$SNELL_HOME_DIR/snell.conf"
