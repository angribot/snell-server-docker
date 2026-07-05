#!/bin/sh
set -eu

readonly ENTRYPOINT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
# shellcheck source=runtime-config.sh
. "${ENTRYPOINT_DIR}/runtime-config.sh"

readonly SNELL_HOME="${SNELL_HOME:-/snell}"
readonly CONFIG_PATH="${SNELL_HOME}/snell.conf"
readonly SNELL_BIN="${SNELL_HOME}/snell-server"

main() {
  snell_runtime_prepare

  test -x "$SNELL_BIN" || snell_runtime_die "[error] snell-server binary not found at ${SNELL_BIN}"

  snell_runtime_apply "$CONFIG_PATH"

  exec "$SNELL_BIN" -c "$CONFIG_PATH" -l "$LOG_LEVEL"
}

main "$@"
