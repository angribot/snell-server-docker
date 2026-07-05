#!/bin/sh

snell_runtime_warn() {
  echo "$*" >&2
}

snell_runtime_die() {
  echo "$*" >&2
  exit 1
}

snell_runtime_resolve_dns_ip_preference() {
  if [ -n "${DNS_IP_PREFERENCE:-}" ]; then
    return
  fi

  if [ -n "${DNSIP:-}" ]; then
    DNS_IP_PREFERENCE=$DNSIP
    export DNS_IP_PREFERENCE
    snell_runtime_warn "[deprecated] DNSIP is deprecated and will be removed when Snell Server v6 stable is released. Use DNS_IP_PREFERENCE instead."
  fi
}

snell_runtime_resolve_egress_interface() {
  if [ -n "${EGRESS_INTERFACE:-}" ]; then
    return
  fi

  if [ -n "${EGRESS:-}" ]; then
    EGRESS_INTERFACE=$EGRESS
    export EGRESS_INTERFACE
    snell_runtime_warn "[deprecated] EGRESS is deprecated and will be removed when Snell Server v6 stable is released. Use EGRESS_INTERFACE instead."
  fi
}

snell_runtime_resolve_log_level() {
  if [ -n "${LOG_LEVEL:-}" ]; then
    return
  fi

  if [ -n "${LOG:-}" ]; then
    LOG_LEVEL=$LOG
    export LOG_LEVEL
    snell_runtime_warn "[deprecated] LOG is deprecated and will be removed when Snell Server v6 stable is released. Use LOG_LEVEL instead."
  fi
}

snell_runtime_resolve_legacy_env() {
  snell_runtime_resolve_dns_ip_preference
  snell_runtime_resolve_egress_interface
  snell_runtime_resolve_log_level

  if [ -n "${VERSION:-}" ]; then
    snell_runtime_warn "[deprecated] VERSION is deprecated and ignored. Snell Server version is selected at image build time."
  fi
}

snell_runtime_apply_defaults() {
  : "${PORT:=2345}"
  : "${LOG_LEVEL:=notify}"
}

snell_runtime_validate_no_control_chars() {
  value_name=$1
  value_data=$2
  sanitized_value=$(printf '%s' "$value_data" | LC_ALL=C tr -d '[:cntrl:]')

  if [ "$sanitized_value" != "$value_data" ]; then
    snell_runtime_die "[error] ${value_name} must not contain control characters"
  fi
}

snell_runtime_validate_psk() {
  if [ -z "${PSK:-}" ]; then
    snell_runtime_die "[error] PSK is required"
  fi

  psk_length=$(printf '%s' "$PSK" | wc -c | awk '{print $1}')
  if [ "$psk_length" -lt 12 ] || [ "$psk_length" -gt 255 ]; then
    snell_runtime_die "[error] PSK length must be between 12 and 255 bytes"
  fi

  snell_runtime_validate_no_control_chars PSK "$PSK"
}

snell_runtime_validate_port() {
  case "$PORT" in
    ''|*[!0-9]*) snell_runtime_die "[error] PORT must be an integer between 1 and 65535" ;;
  esac

  if [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
    snell_runtime_die "[error] PORT must be an integer between 1 and 65535"
  fi
}

snell_runtime_validate_mode() {
  if [ -z "${MODE:-}" ]; then
    return
  fi

  case "$MODE" in
    default|unshaped|unsafe-raw) ;;
    *) snell_runtime_die "[error] MODE must be one of: default, unshaped, unsafe-raw" ;;
  esac
}

snell_runtime_validate_dns_ip_preference() {
  if [ -z "${DNS_IP_PREFERENCE:-}" ]; then
    return
  fi

  case "$DNS_IP_PREFERENCE" in
    default|prefer-ipv4|prefer-ipv6|ipv4-only|ipv6-only) ;;
    *) snell_runtime_die "[error] DNS_IP_PREFERENCE must be one of: default, prefer-ipv4, prefer-ipv6, ipv4-only, ipv6-only" ;;
  esac
}

snell_runtime_validate_log_level() {
  if [ -z "$LOG_LEVEL" ]; then
    snell_runtime_die "[error] LOG_LEVEL cannot be empty"
  fi

  snell_runtime_validate_no_control_chars LOG_LEVEL "$LOG_LEVEL"
}

snell_runtime_validate_dns() {
  if [ -z "${DNS:-}" ]; then
    return
  fi

  snell_runtime_validate_no_control_chars DNS "$DNS"
}

snell_runtime_validate_egress_interface() {
  if [ -z "${EGRESS_INTERFACE:-}" ]; then
    return
  fi

  snell_runtime_validate_no_control_chars EGRESS_INTERFACE "$EGRESS_INTERFACE"
}

snell_runtime_validate_env() {
  snell_runtime_validate_psk
  snell_runtime_validate_port
  snell_runtime_validate_mode
  snell_runtime_validate_dns_ip_preference
  snell_runtime_validate_dns
  snell_runtime_validate_egress_interface
  snell_runtime_validate_log_level
}

snell_runtime_write_config() {
  config_path=$1

  cat >"$config_path" <<EOF
[snell-server]
listen = 0.0.0.0:${PORT},[::]:${PORT}
psk = ${PSK}
EOF

  if [ -n "${MODE:-}" ]; then
    echo "mode = ${MODE}" >>"$config_path"
  fi

  if [ -n "${DNS:-}" ]; then
    echo "dns = ${DNS}" >>"$config_path"
  fi

  if [ -n "${DNS_IP_PREFERENCE:-}" ]; then
    echo "dns-ip-preference = ${DNS_IP_PREFERENCE}" >>"$config_path"
  fi

  if [ -n "${EGRESS_INTERFACE:-}" ]; then
    echo "egress-interface = ${EGRESS_INTERFACE}" >>"$config_path"
  fi
}

snell_runtime_print_summary() {
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

snell_runtime_prepare() {
  snell_runtime_resolve_legacy_env
  snell_runtime_apply_defaults
  snell_runtime_validate_env
}

snell_runtime_apply() {
  config_path=$1

  snell_runtime_write_config "$config_path"
  snell_runtime_print_summary
}

snell_runtime_configure() {
  config_path=$1

  snell_runtime_prepare
  snell_runtime_apply "$config_path"
}
