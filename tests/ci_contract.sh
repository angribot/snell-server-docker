#!/bin/sh
set -eu

grep -q 'readme_contract.sh' .github/workflows/ci.yaml
grep -q -- '--network host' tests/docker_smoke.sh
grep -q 'docker inspect -f' tests/docker_smoke.sh
grep -q 'stop_elapsed=' tests/docker_smoke.sh
grep -q '^#!/bin/sh$' entrypoint.sh
! grep -q 'install -y --no-install-recommends bash' Dockerfile
! grep -q 'bash -n' .github/workflows/ci.yaml
