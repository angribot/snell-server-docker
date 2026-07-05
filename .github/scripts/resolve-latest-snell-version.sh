#!/bin/sh
set -eu

SOURCE="${1:-https://kb.nssurge.com/surge-knowledge-base/release-notes/snell}"
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

sh "$SCRIPT_DIR/snell-version-lifecycle.sh" latest-publishable "$SOURCE"
