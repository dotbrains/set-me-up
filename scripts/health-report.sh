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
source "$repo_root/scripts/lib/repo-health.sh"
source "$repo_root/scripts/lib/json.sh"

usage() {
    printf "Usage: %s [--json]\\n" "$0" >&2
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
    sync="$(smu_repo_health_sync_for_state "$path" "$state")"
    route_id="$(smu_repo_health_route_id "$routes_file" "$path")"
    validator="$(smu_repo_health_validator_label "$validators_file" "$path")"
    printf '%s{"repo":"%s","path":"%s","category":"%s","state":"%s","sync":"%s","route":"%s","validator":"%s"}' \
        "$comma" "$(smu_json_escape "$repo")" "$(smu_json_escape "$path")" \
        "$(smu_json_escape "$category")" "$(smu_json_escape "$state")" \
        "$(smu_json_escape "$sync")" "$(smu_json_escape "$route_id")" \
        "$(smu_json_escape "$validator")"
    comma=","
done < "$repos_file"
printf ']}\n'
