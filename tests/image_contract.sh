#!/bin/sh
set -eu

DNS_PID=""
cleanup() {
  if [ -n "$DNS_PID" ]; then
    kill "$DNS_PID" 2>/dev/null || true
    wait "$DNS_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

# Run the existing configuration contract with Alpine's shell and tools.
test -f /etc/alpine-release
sh "$(dirname "$0")/runtime_contract.sh"

printf '\n192.0.2.124 snell-host.test\n' >> /etc/hosts
/usr/local/bin/glibc-getent ahostsv4 snell-host.test | grep -q '^192\.0\.2\.124 '

# Keep resolver checks independent of public DNS and the host's proxy settings.
printf 'nameserver 127.0.0.1\noptions timeout:1 attempts:1\n' > /etc/resolv.conf
dnsmasq --keep-in-foreground --conf-file=/dev/null --no-resolv --no-hosts \
  --bind-interfaces --listen-address=127.0.0.1 --user=root \
  --address=/snell.test/192.0.2.123 &
DNS_PID=$!

attempt=0
until /usr/local/bin/glibc-getent ahostsv4 snell.test | grep -q '^192\.0\.2\.123 '; do
  attempt=$((attempt + 1))
  if [ "$attempt" -ge 10 ]; then
    echo "glibc could not resolve the local DNS fixture" >&2
    exit 1
  fi
  sleep 1
done

printf 'Alpine runtime configuration and glibc resolution passed\n'
