#!/bin/sh
set -eu

DEFAULT_DOCKERFILE_PATH="Dockerfile"
DEFAULT_RELEASE_NOTES_URL="https://kb.nssurge.com/surge-knowledge-base/release-notes/snell"
SNELL_DOWNLOAD_BASE="${SNELL_DOWNLOAD_BASE:-https://dl.nssurge.com/snell}"
SUPPORTED_SNELL_ARCHES="${SUPPORTED_SNELL_ARCHES:-amd64 aarch64}"

usage() {
  cat >&2 <<'EOF'
usage: snell-version-lifecycle.sh COMMAND [ARG]

commands:
  current [DOCKERFILE]              print the bundled Snell version
  validate-current [DOCKERFILE]     print the bundled Snell version and validate tag context
  select                            select the highest Snell version from stdin
  latest-publishable [SOURCE]       print newest version with all supported release assets
  state [SOURCE] [DOCKERFILE]       print current/latest/needs_bump facts
EOF
  exit 2
}

die() {
  echo "$*" >&2
  exit 1
}

is_valid_snell_version() {
  printf '%s\n' "$1" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+(b[0-9]+|rc[0-9]*)?$'
}

canonicalize_snell_version() {
  case "$1" in
    *rc) printf '%s1\n' "$1" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

read_current_version() {
  dockerfile_path="${1:-$DEFAULT_DOCKERFILE_PATH}"

  [ -f "$dockerfile_path" ] || die "Dockerfile not found: ${dockerfile_path}"

  versions="$(awk '
    /^ARG SNELL_VERSION=/ {
      sub(/^ARG SNELL_VERSION=/, "")
      print
    }
  ' "$dockerfile_path")"

  version_count="$(printf '%s\n' "$versions" | sed '/^$/d' | wc -l | awk '{print $1}')"
  if [ "$version_count" -ne 1 ]; then
    die "Dockerfile must contain exactly one defaulted ARG SNELL_VERSION"
  fi

  current_version="$(printf '%s\n' "$versions" | sed '/^$/d')"
  is_valid_snell_version "$current_version" || die "invalid SNELL_VERSION: ${current_version}"

  printf '%s\n' "$current_version"
}

validate_tag_matches_current() {
  current_version=$1

  if [ "${GITHUB_REF_TYPE:-}" = "tag" ] && [ "${GITHUB_REF_NAME:-}" != "$current_version" ]; then
    die "Git tag ${GITHUB_REF_NAME:-<unset>} does not match SNELL_VERSION ${current_version}"
  fi
}

select_version() {
  selected_version="$({
    awk '
      function emit(original, normalized, parts, major, minor, patch, stability, prerelease_num) {
        normalized = original
        prerelease_num = 0

        if (normalized ~ /^v[0-9]+\.[0-9]+\.[0-9]+b[0-9]+$/) {
          stability = 0
          prerelease_num = normalized
          sub(/^.*b/, "", prerelease_num)
          sub(/b[0-9]+$/, "", normalized)
        } else if (normalized ~ /^v[0-9]+\.[0-9]+\.[0-9]+rc[0-9]*$/) {
          stability = 1
          prerelease_num = normalized
          sub(/^.*rc/, "", prerelease_num)
          if (prerelease_num == "") {
            prerelease_num = 1
          }
          sub(/rc[0-9]*$/, "", normalized)
        } else if (normalized ~ /^v[0-9]+\.[0-9]+\.[0-9]+$/) {
          stability = 2
        } else {
          return
        }

        sub(/^v/, "", normalized)
        split(normalized, parts, /\./)
        major = parts[1] + 0
        minor = parts[2] + 0
        patch = parts[3] + 0

        printf "%09d %09d %09d %01d %09d %s\n", major, minor, patch, stability, prerelease_num, original
      }

      { emit($0) }
    ' | sort | tail -n 1 | awk '{print $6}'
  } || true)"

  if [ -z "$selected_version" ]; then
    die "no valid Snell versions provided"
  fi

  printf '%s\n' "$selected_version"
}

load_release_notes() {
  source="${1:-$DEFAULT_RELEASE_NOTES_URL}"

  if [ -f "$source" ]; then
    cat "$source"
  else
    curl -fsSL "$source"
  fi
}

extract_publishable_versions() {
  source="${1:-$DEFAULT_RELEASE_NOTES_URL}"

  asset_pairs="$(load_release_notes "$source" |
    grep -Eo 'snell-server-v[0-9]+\.[0-9]+\.[0-9]+(b[0-9]+|rc[0-9]*)?-linux-(amd64|aarch64)\.zip' |
    sed -E 's/^snell-server-(v[^-]+)-linux-(amd64|aarch64)\.zip$/\1 \2/' |
    sort -u || true)"

  if [ -z "$asset_pairs" ]; then
    return 0
  fi

  printf '%s\n' "$asset_pairs" |
    awk -v required_arches="$SUPPORTED_SNELL_ARCHES" '
      BEGIN { split(required_arches, arches, " ") }
      {
        seen[$1 " " $2] = 1
        versions[$1] = 1
      }
      END {
        for (version in versions) {
          publishable = 1
          for (i in arches) {
            if (!seen[version " " arches[i]]) {
              publishable = 0
            }
          }
          if (publishable) {
            print version
          }
        }
      }
    '
}

validate_remote_assets() {
  source=$1
  version=$2

  if [ -f "$source" ]; then
    return
  fi

  for snell_arch in $SUPPORTED_SNELL_ARCHES; do
    curl -fsSLI -o /dev/null "${SNELL_DOWNLOAD_BASE}/snell-server-${version}-linux-${snell_arch}.zip"
  done
}

latest_publishable_version() {
  source="${1:-$DEFAULT_RELEASE_NOTES_URL}"

  versions="$(extract_publishable_versions "$source" || true)"
  if [ -z "$versions" ]; then
    die "failed to extract publishable Snell versions from $source"
  fi

  latest_version="$(printf '%s\n' "$versions" | select_version)"
  validate_remote_assets "$source" "$latest_version"
  printf '%s\n' "$latest_version"
}

print_state() {
  source="${1:-$DEFAULT_RELEASE_NOTES_URL}"
  dockerfile_path="${2:-$DEFAULT_DOCKERFILE_PATH}"

  current_version="$(read_current_version "$dockerfile_path")"
  latest_version="$(latest_publishable_version "$source")"
  newest_known_version="$(printf '%s\n%s\n' "$current_version" "$latest_version" | select_version)"
  canonical_current_version="$(canonicalize_snell_version "$current_version")"
  canonical_latest_version="$(canonicalize_snell_version "$latest_version")"
  canonical_newest_known_version="$(canonicalize_snell_version "$newest_known_version")"
  needs_bump=false

  if [ "$canonical_latest_version" != "$canonical_current_version" ] &&
    [ "$canonical_newest_known_version" = "$canonical_latest_version" ]; then
    needs_bump=true
  fi

  printf 'current_version=%s\n' "$current_version"
  printf 'latest_version=%s\n' "$latest_version"
  printf 'needs_bump=%s\n' "$needs_bump"
}

command="${1:-}"
[ -n "$command" ] || usage
shift || true

case "$command" in
  current)
    read_current_version "${1:-$DEFAULT_DOCKERFILE_PATH}"
    ;;
  validate-current)
    current_version="$(read_current_version "${1:-$DEFAULT_DOCKERFILE_PATH}")"
    validate_tag_matches_current "$current_version"
    printf '%s\n' "$current_version"
    ;;
  select)
    select_version
    ;;
  latest-publishable)
    latest_publishable_version "${1:-$DEFAULT_RELEASE_NOTES_URL}"
    ;;
  state)
    print_state "${1:-$DEFAULT_RELEASE_NOTES_URL}" "${2:-$DEFAULT_DOCKERFILE_PATH}"
    ;;
  *)
    usage
    ;;
esac
