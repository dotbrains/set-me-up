#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repos_file="$repo_root/scripts/repos.txt"
routes_file="$repo_root/scripts/agent-routes.txt"
validators_file="$repo_root/scripts/repo-validators.txt"
path="${1:-}"

source "$repo_root/scripts/lib/repos.sh"
source "$repo_root/scripts/lib/repo-state.sh"
source "$repo_root/scripts/lib/validators.sh"

usage() {
    printf "Usage: %s <managed-local-path>\\n" "$0" >&2
}

manifest_has_path() {
    local wanted_path="$1"
    local repo
    local local_path
    local category

    while IFS='|' read -r repo local_path category _ || [ -n "$repo" ]; do
        [[ "$repo" =~ ^[[:space:]]*# || -z "$repo" ]] && continue
        : "$category"
        [ "$local_path" = "$wanted_path" ] && return 0
    done < "$repos_file"
    return 1
}

route_exists_for_path() {
    local wanted_path="$1"
    local route_id
    local local_path
    local summary
    local keywords

    while IFS='|' read -r route_id local_path summary keywords _ || \
        [ -n "$route_id" ]; do
        [[ "$route_id" =~ ^[[:space:]]*# || -z "$route_id" ]] && continue
        : "$summary" "$keywords"
        [ "$local_path" = "$wanted_path" ] && return 0
    done < "$routes_file"
    return 1
}

check() {
    local label="$1"
    shift

    if "$@"; then
        printf "OK\\t%s\\n" "$label"
    else
        printf "FAIL\\t%s\\n" "$label"
        failed=$((failed + 1))
    fi
}

has_validator() {
    smu_validator_for_repo "$validators_file" "$path" >/dev/null
}

has_native_validator() {
    [ -x "$repo_root/$path/scripts/validate.sh" ]
}

has_readme() {
    [ -f "$repo_root/$path/README.md" ] || [ -f "$repo_root/$path/README" ]
}

has_license() {
    [ -f "$repo_root/$path/LICENSE" ] || [ -f "$repo_root/$path/LICENSE.md" ]
}

is_clean_and_synced() {
    local state
    local sync

    state="$(smu_repo_state "$path")"
    sync="$(smu_repo_sync_status "$path")"
    [ "$state" = "clean" ] && [ "$sync" = "synced" ]
}

[ -n "$path" ] || {
    usage
    exit 2
}

cd "$repo_root"
smu_validate_repos_manifest "$repos_file"

failed=0
check "manifest path" manifest_has_path "$path"
check "route entry" route_exists_for_path "$path"
check "validator" has_validator
check "native validator" has_native_validator
check "README" has_readme
check "license" has_license
check "clean and synced" is_clean_and_synced

[ "$failed" -eq 0 ]
