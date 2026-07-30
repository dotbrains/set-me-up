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
print_repo() {
    local repo="$1"
    local path="$2"
    local category="$3"
    local state="$4"
    local sync="$5"
    local route_id="$6"
    local validator="$7"

    printf '%s{"repo":"%s","path":"%s","category":"%s","state":"%s","sync":"%s","route":"%s","validator":"%s"}' \
        "$comma" "$(smu_json_escape "$repo")" "$(smu_json_escape "$path")" \
        "$(smu_json_escape "$category")" "$(smu_json_escape "$state")" \
        "$(smu_json_escape "$sync")" "$(smu_json_escape "$route_id")" \
        "$(smu_json_escape "$validator")"
    comma=","
}

smu_each_repo_health "$repo_root" "$repos_file" "$routes_file" "$validators_file" print_repo
printf ']}\n'
