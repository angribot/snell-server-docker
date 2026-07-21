#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"

usage() {
  cat >&2 <<'EOF'
usage: repository_contract.sh COMMAND

commands:
  readme       verify user-facing runtime documentation
  ci           verify CI and Docker smoke-test repository contracts
  auto-update  verify scheduled Snell version bump repository contracts
  all          verify all repository contracts
EOF
  exit 2
}

fail() {
  echo "$*" >&2
  exit 1
}

repo_path() {
  printf '%s/%s\n' "$ROOT_DIR" "$1"
}

assert_file_contains() {
  file=$1
  pattern=$2
  message=$3

  if ! grep -q -- "$pattern" "$(repo_path "$file")"; then
    fail "$message"
  fi
}

assert_file_not_contains() {
  file=$1
  pattern=$2
  message=$3

  if grep -q -- "$pattern" "$(repo_path "$file")"; then
    fail "$message"
  fi
}

assert_readme_documents_runtime_contract() {
  file=$1

  assert_file_contains "$file" '--init' "${file} must document Docker init for docker run"
  assert_file_contains "$file" 'init: true' "${file} must document Docker init for Compose"
  assert_file_contains "$file" 'PSK' "${file} must document the required PSK setting"
  assert_file_contains "$file" 'DNS_IP_PREFERENCE' "${file} must document DNS_IP_PREFERENCE"
  assert_file_contains "$file" 'EGRESS_INTERFACE' "${file} must document EGRESS_INTERFACE"
  assert_file_contains "$file" 'LOG_LEVEL' "${file} must document LOG_LEVEL"
  assert_file_contains "$file" 'latest' "${file} must document latest tag behavior"
  assert_file_contains "$file" 'Snell Server v6' "${file} must document Snell Server v6 compatibility"
}

assert_readme_contract() {
  assert_readme_documents_runtime_contract README.md
  assert_readme_documents_runtime_contract README.en.md
}

assert_ci_runs_repository_contracts() {
  assert_file_contains .github/workflows/ci.yaml 'readme_contract.sh' 'CI must run README repository contracts'
  assert_file_contains .github/workflows/ci.yaml 'auto_update_contract.sh' 'CI must run auto-update repository contracts'
  assert_file_contains .github/workflows/ci.yaml 'repository_contract.sh' 'CI must syntax-check repository contract module'
}

assert_ci_checks_deep_modules() {
  assert_file_contains .github/workflows/ci.yaml 'snell-version-lifecycle.sh' 'CI must syntax-check Snell version lifecycle module'
  assert_file_contains .github/workflows/ci.yaml 'runtime-config.sh' 'CI must syntax-check Snell runtime configuration module'
  assert_file_contains Dockerfile 'COPY entrypoint.sh runtime-config.sh /snell/' 'Docker image must include Snell runtime configuration module'
}

assert_docker_smoke_contract() {
  assert_file_contains tests/docker_smoke.sh '--network host' 'Docker smoke test must cover host networking'
  assert_file_contains tests/docker_smoke.sh 'docker inspect -f' 'Docker smoke test must inspect container exit state'
  assert_file_contains tests/docker_smoke.sh 'stop_elapsed=' 'Docker smoke test must verify graceful stop timing'
}

assert_posix_shell_contract() {
  assert_file_contains entrypoint.sh '^#!/bin/sh$' 'entrypoint must stay POSIX sh'
  assert_file_not_contains Dockerfile 'install -y --no-install-recommends bash' 'Docker image must not install bash'
  assert_file_not_contains .github/workflows/ci.yaml 'bash -n' 'CI must not require bash syntax checks'
}

assert_ci_contract() {
  assert_ci_runs_repository_contracts
  assert_ci_checks_deep_modules
  assert_docker_smoke_contract
  assert_posix_shell_contract
}

assert_auto_update_contract() {
  workflow=.github/workflows/auto_bump.yaml

  assert_file_contains "$workflow" '30 16 \* \* \*' 'auto bump workflow must run at 00:30 CST'
  assert_file_contains "$workflow" 'workflow_dispatch' 'auto bump workflow must be manually triggerable'
  assert_file_contains "$workflow" 'REPO_PUSH_TOKEN' 'auto bump workflow must use a token that can trigger publish workflows'
  assert_file_contains "$workflow" 'persist-credentials: false' 'checkout token must not override the publish-triggering push token'
  assert_file_contains "$workflow" 'snell-version-lifecycle.sh state' 'auto bump workflow must use Snell version lifecycle state'
  assert_file_contains "$workflow" 'needs_bump' 'auto bump workflow must branch on version bump state'
  assert_file_contains "$workflow" 'git tag -a' 'auto bump workflow must create an annotated tag'
  assert_file_contains "$workflow" 'git push origin "HEAD:' 'auto bump workflow must push commit and tag together'
}

command="${1:-}"
[ -n "$command" ] || usage

case "$command" in
  readme)
    assert_readme_contract
    ;;
  ci)
    assert_ci_contract
    ;;
  auto-update)
    assert_auto_update_contract
    ;;
  all)
    assert_readme_contract
    assert_ci_contract
    assert_auto_update_contract
    ;;
  *)
    usage
    ;;
esac
