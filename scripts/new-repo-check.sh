#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repos_file="$repo_root/scripts/repos.txt"
routes_file="$repo_root/scripts/agent-routes.txt"
validators_file="$repo_root/scripts/repo-validators.txt"
path="${1:-}"

source "$repo_root/scripts/lib/repos.sh"
source "$repo_root/scripts/lib/routes.sh"
source "$repo_root/scripts/lib/validators.sh"

usage() {
    printf "Usage: %s <managed-local-path>\\n" "$0" >&2
}

check() {
    local label="$1"
    shift

    if "$@"; then
        printf "OK\\t%s\\n" "$label"
    else
        failed=$((failed + 1))
        printf "FAIL\\t%s\\n" "$label"
    fi
}

in_manifest() {
    awk -F '|' -v wanted="$path" \
        '$1 !~ /^#/ && $2 == wanted { found = 1 } END { exit found ? 0 : 1 }' \
        "$repos_file"
}

has_route() {
    smu_route_for_path "$routes_file" "$path" >/dev/null
}

has_validator() {
    smu_validator_for_repo "$validators_file" "$path" >/dev/null
}

has_native_validator() {
    [ -x "$path/scripts/validate.sh" ]
}

has_workflow() {
    [ -d "$path/.github/workflows" ] && \
        find "$path/.github/workflows" -maxdepth 1 -type f \
            \( -name '*.yml' -o -name '*.yaml' \) | grep -q .
}

[ -n "$path" ] || {
    usage
    exit 2
}

cd "$repo_root"
smu_validate_repos_manifest "$repos_file"

failed=0
check "manifest entry" in_manifest
check "route entry" has_route
check "validator" has_validator
check "native validator" has_native_validator
check "workflow" has_workflow

[ "$failed" -eq 0 ]
