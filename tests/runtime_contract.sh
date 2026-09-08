#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)"
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

expect_failure env SNELL_HOME="$SNELL_HOME_DIR" PSK=abcdefghijkl PORT=invalid /bin/sh "$ENTRYPOINT"
grep -q '\[error\] PORT must be an integer between 1 and 65535' "$LOG_FILE"

expect_failure env SNELL_HOME="$SNELL_HOME_DIR" PSK=abcdefghijkl PORT=0 /bin/sh "$ENTRYPOINT"
grep -q '\[error\] PORT must be an integer between 1 and 65535' "$LOG_FILE"

expect_failure env SNELL_HOME="$SNELL_HOME_DIR" PSK=abcdefghijkl PORT=65536 /bin/sh "$ENTRYPOINT"
grep -q '\[error\] PORT must be an integer between 1 and 65535' "$LOG_FILE"

expect_failure env SNELL_HOME="$SNELL_HOME_DIR" PSK=abcdefghijkl MODE=fast /bin/sh "$ENTRYPOINT"
grep -q '\[error\] MODE must be one of' "$LOG_FILE"

expect_failure env SNELL_HOME="$SNELL_HOME_DIR" PSK=abcdefghijkl DNS_IP_PREFERENCE=ipv4 /bin/sh "$ENTRYPOINT"
grep -q '\[error\] DNS_IP_PREFERENCE must be one of' "$LOG_FILE"

env \
  SNELL_HOME="$SNELL_HOME_DIR" \
  PSK=abcdefghijkl \
  PORT=3456 \
  MODE=unshaped \
  DNS=1.1.1.1,8.8.8.8 \
  DNS_IP_PREFERENCE=prefer-ipv4 \
  EGRESS_INTERFACE=eth0 \
  LOG_LEVEL=verbose \
  /bin/sh "$ENTRYPOINT" >"$LOG_FILE" 2>&1

grep -q 'PORT:3456' "$LOG_FILE"
grep -q 'MODE:unshaped' "$LOG_FILE"
grep -q 'DNS:1.1.1.1,8.8.8.8' "$LOG_FILE"
grep -q 'DNS_IP_PREFERENCE:prefer-ipv4' "$LOG_FILE"
grep -q 'EGRESS_INTERFACE:eth0' "$LOG_FILE"
grep -q 'LOG_LEVEL:verbose' "$LOG_FILE"
grep -Fq "SNELL_STUB:-c ${SNELL_HOME_DIR}/snell.conf -l verbose" "$LOG_FILE"

if grep -q '^PSK:' "$LOG_FILE"; then
  echo "runtime summary must not expose PSK" >&2
  exit 1
fi

grep -q '^listen = 0.0.0.0:3456,\[::\]:3456$' "$SNELL_HOME_DIR/snell.conf"
grep -q '^psk = abcdefghijkl$' "$SNELL_HOME_DIR/snell.conf"
grep -q '^mode = unshaped$' "$SNELL_HOME_DIR/snell.conf"
grep -q '^dns = 1.1.1.1,8.8.8.8$' "$SNELL_HOME_DIR/snell.conf"
grep -q '^dns-ip-preference = prefer-ipv4$' "$SNELL_HOME_DIR/snell.conf"
grep -q '^egress-interface = eth0$' "$SNELL_HOME_DIR/snell.conf"

env \
  SNELL_HOME="$SNELL_HOME_DIR" \
  PSK=abcdefghijkl \
  DNSIP=ipv4-only \
  LOG=verbose \
  VERSION=v9.9.9 \
  /bin/sh "$ENTRYPOINT" >"$LOG_FILE" 2>&1

grep -q 'PORT:2345' "$LOG_FILE"
grep -q 'LOG_LEVEL:verbose' "$LOG_FILE"
grep -q '\[deprecated\] DNSIP is deprecated' "$LOG_FILE"
grep -q '\[deprecated\] LOG is deprecated' "$LOG_FILE"
grep -q '\[deprecated\] VERSION is deprecated and ignored' "$LOG_FILE"
grep -q '^listen = 0.0.0.0:2345,\[::\]:2345$' "$SNELL_HOME_DIR/snell.conf"
grep -q '^dns-ip-preference = ipv4-only$' "$SNELL_HOME_DIR/snell.conf"
