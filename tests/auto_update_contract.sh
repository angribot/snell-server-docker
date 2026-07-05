#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"

sh "$ROOT_DIR/tests/repository_contract.sh" auto-update
