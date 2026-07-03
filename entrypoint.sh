#!/bin/sh
set -eu

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

resolve_dns_ip_preference() {
  if [ -n "${DNS_IP_PREFERENCE:-}" ]; then
    return
  fi

  if [ -n "${DNSIP:-}" ]; then
    DNS_IP_PREFERENCE=$DNSIP
    export DNS_IP_PREFERENCE
    warn "[deprecated] DNSIP is deprecated and will be removed when Snell Server v6 stable is released. Use DNS_IP_PREFERENCE instead."
  fi
}

resolve_egress_interface() {
  if [ -n "${EGRESS_INTERFACE:-}" ]; then
    return
  fi

  if [ -n "${EGRESS:-}" ]; then
    EGRESS_INTERFACE=$EGRESS
    export EGRESS_INTERFACE
    warn "[deprecated] EGRESS is deprecated and will be removed when Snell Server v6 stable is released. Use EGRESS_INTERFACE instead."
  fi
}

resolve_log_level() {
  if [ -n "${LOG_LEVEL:-}" ]; then
    return
  fi

  if [ -n "${LOG:-}" ]; then
    LOG_LEVEL=$LOG
    export LOG_LEVEL
    warn "[deprecated] LOG is deprecated and will be removed when Snell Server v6 stable is released. Use LOG_LEVEL instead."
  fi
}

validate_no_control_chars() {
  value_name=$1
  value_data=$2
  sanitized_value=$(printf '%s' "$value_data" | LC_ALL=C tr -d '[:cntrl:]')

  if [ "$sanitized_value" != "$value_data" ]; then
    die "[error] ${value_name} must not contain control characters"
  fi
}

validate_psk() {
  if [ -z "${PSK:-}" ]; then
    die "[error] PSK is required"
  fi

  psk_length=$(printf '%s' "$PSK" | wc -c | awk '{print $1}')
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
  resolve_dns_ip_preference
  resolve_egress_interface
  resolve_log_level

  if [ -n "${VERSION:-}" ]; then
    warn "[deprecated] VERSION is deprecated and ignored. Snell Server version is selected at image build time."
  fi

  : "${PORT:=2345}"
  : "${LOG_LEVEL:=notify}"

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
