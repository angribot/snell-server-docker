#!/bin/sh
set -eu

for file in README.md README.en.md; do
  grep -q -- '--init' "$file"
  grep -q 'init: true' "$file"
  grep -q 'PSK' "$file"
  grep -q 'DNS_IP_PREFERENCE' "$file"
  grep -q 'EGRESS_INTERFACE' "$file"
  grep -q 'LOG_LEVEL' "$file"
  grep -q 'latest' "$file"
  grep -q 'Snell Server v6' "$file"
done
