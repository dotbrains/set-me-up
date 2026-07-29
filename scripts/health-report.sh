#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repos_file="$repo_root/scripts/repos.txt"
routes_file="$repo_root/scripts/agent-routes.txt"
validators_file="$repo_root/scripts/repo-validators.txt"
mode="${1:---json}"

source "$repo_root/scripts/lib/repos.sh"
source "$repo_root/scripts/lib/repo-state.sh"
source "$repo_root/scripts/lib/routes.sh"
source "$repo_root/scripts/lib/validators.sh"

usage() {
    printf "Usage: %s [--json]\\n" "$0" >&2
}

json_escape() {
    local value="$1"

    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//$'\n'/\\n}"
    printf "%s" "$value"
}

case "$mode" in
    --json)
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    *)
        usage
        exit 2
        ;;
esac

cd "$repo_root"
smu_validate_repos_manifest "$repos_file"

printf '{"repositories":['
comma=""
while IFS='|' read -r repo path category _ || [ -n "$repo" ]; do
    [[ "$repo" =~ ^[[:space:]]*# || -z "$repo" ]] && continue
    state="$(smu_repo_state "$path")"
    sync="unknown"
    if [ "$state" != "missing" ] && [ "$state" != "not-git" ] && \
        [ "$state" != "detached" ]; then
        sync="$(smu_repo_sync_status "$path")"
    fi
    route_id=""
    if route="$(smu_route_for_path "$routes_file" "$path")"; then
        route_id="${route%%|*}"
    fi
    validator="none"
    if resolved="$(smu_validator_for_repo "$validators_file" "$path")"; then
        validator="$(smu_validator_label "$resolved")"
    fi
    printf '%s{"repo":"%s","path":"%s","category":"%s","state":"%s","sync":"%s","route":"%s","validator":"%s"}' \
        "$comma" "$(json_escape "$repo")" "$(json_escape "$path")" \
        "$(json_escape "$category")" "$(json_escape "$state")" \
        "$(json_escape "$sync")" "$(json_escape "$route_id")" \
        "$(json_escape "$validator")"
    comma=","
done < "$repos_file"
printf ']}\n'
