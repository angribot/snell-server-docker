#!/bin/bash
set -euo pipefail

readonly SNELL_HOME="${SNELL_HOME:-/snell}"
readonly CONFIG_PATH="${SNELL_HOME}/snell.conf"
readonly SNELL_BIN="${SNELL_HOME}/snell-server"

warn() {
  echo "$*" >&2
}

die() {
  echo "$*" >&2
  exit 1
}

use_compat_env() {
  local old_name="$1"
  local new_name="$2"
  local old_value="${!old_name-}"
  local new_value="${!new_name-}"

  if [ -n "$new_value" ]; then
    return
  fi

  if [ -n "$old_value" ]; then
    export "$new_name=$old_value"
    warn "[deprecated] ${old_name} is deprecated and will be removed when Snell Server v6 stable is released. Use ${new_name} instead."
  fi
}

validate_no_control_chars() {
  local name="$1"
  local value="$2"
  local sanitized_value

  sanitized_value="$(printf '%s' "$value" | LC_ALL=C tr -d '\000-\037\177')"
  if [ "$sanitized_value" != "$value" ]; then
    die "[error] ${name} must not contain control characters"
  fi
}

validate_psk() {
  local psk_length

  if [ -z "${PSK:-}" ]; then
    die "[error] PSK is required"
  fi

  psk_length="$(printf '%s' "$PSK" | wc -c | tr -d ' ')"
  if [ "$psk_length" -lt 12 ] || [ "$psk_length" -gt 255 ]; then
    die "[error] PSK length must be between 12 and 255 bytes"
  fi

  validate_no_control_chars PSK "$PSK"
}

validate_port() {
  case "$PORT" in
    ''|*[!0-9]*) die "[error] PORT must be an integer between 1 and 65535" ;;
  esac

  if [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
    die "[error] PORT must be an integer between 1 and 65535"
  fi
}

validate_mode() {
  if [ -z "${MODE:-}" ]; then
    return
  fi

  case "$MODE" in
    default|unshaped|unsafe-raw) ;;
    *) die "[error] MODE must be one of: default, unshaped, unsafe-raw" ;;
  esac
}

validate_dns_ip_preference() {
  if [ -z "${DNS_IP_PREFERENCE:-}" ]; then
    return
  fi

  case "$DNS_IP_PREFERENCE" in
    default|prefer-ipv4|prefer-ipv6|ipv4-only|ipv6-only) ;;
    *) die "[error] DNS_IP_PREFERENCE must be one of: default, prefer-ipv4, prefer-ipv6, ipv4-only, ipv6-only" ;;
  esac
}

validate_log_level() {
  if [ -z "$LOG_LEVEL" ]; then
    die "[error] LOG_LEVEL cannot be empty"
  fi

  validate_no_control_chars LOG_LEVEL "$LOG_LEVEL"
}

validate_dns() {
  if [ -z "${DNS:-}" ]; then
    return
  fi

  validate_no_control_chars DNS "$DNS"
}

validate_egress_interface() {
  if [ -z "${EGRESS_INTERFACE:-}" ]; then
    return
  fi

  validate_no_control_chars EGRESS_INTERFACE "$EGRESS_INTERFACE"
}

write_config() {
  cat >"$CONFIG_PATH" <<EOF
[snell-server]
listen = 0.0.0.0:${PORT},[::]:${PORT}
psk = ${PSK}
EOF

  if [ -n "${MODE:-}" ]; then
    echo "mode = ${MODE}" >>"$CONFIG_PATH"
  fi

  if [ -n "${DNS:-}" ]; then
    echo "dns = ${DNS}" >>"$CONFIG_PATH"
  fi

  if [ -n "${DNS_IP_PREFERENCE:-}" ]; then
    echo "dns-ip-preference = ${DNS_IP_PREFERENCE}" >>"$CONFIG_PATH"
  fi

  if [ -n "${EGRESS_INTERFACE:-}" ]; then
    echo "egress-interface = ${EGRESS_INTERFACE}" >>"$CONFIG_PATH"
  fi
}

print_summary() {
  echo "PORT:${PORT}"
  echo "LOG_LEVEL:${LOG_LEVEL}"

  if [ -n "${MODE:-}" ]; then
    echo "MODE:${MODE}"
  fi

  if [ -n "${DNS:-}" ]; then
    echo "DNS:${DNS}"
  fi

  if [ -n "${DNS_IP_PREFERENCE:-}" ]; then
    echo "DNS_IP_PREFERENCE:${DNS_IP_PREFERENCE}"
  fi

  if [ -n "${EGRESS_INTERFACE:-}" ]; then
    echo "EGRESS_INTERFACE:${EGRESS_INTERFACE}"
  fi
}

main() {
  use_compat_env DNSIP DNS_IP_PREFERENCE
  use_compat_env EGRESS EGRESS_INTERFACE
  use_compat_env LOG LOG_LEVEL

  if [ -n "${VERSION:-}" ]; then
    warn "[deprecated] VERSION is deprecated and ignored. Snell Server version is selected at image build time."
  fi

  if [ "${PORT+x}" != x ]; then
    PORT=2345
  fi

  if [ "${LOG_LEVEL+x}" != x ]; then
    LOG_LEVEL=notify
  fi

  validate_psk
  validate_port
  validate_mode
  validate_dns_ip_preference
  validate_dns
  validate_egress_interface
  validate_log_level

  test -x "$SNELL_BIN" || die "[error] snell-server binary not found at ${SNELL_BIN}"

  write_config
  print_summary

  exec "$SNELL_BIN" -c "$CONFIG_PATH" -l "$LOG_LEVEL"
}

main "$@"
