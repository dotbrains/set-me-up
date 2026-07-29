#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repos_file="$repo_root/scripts/repos.txt"
routes_file="$repo_root/scripts/agent-routes.txt"
validators_file="$repo_root/scripts/repo-validators.txt"
query="${1:-}"

source "$repo_root/scripts/lib/repos.sh"
source "$repo_root/scripts/lib/routes.sh"
source "$repo_root/scripts/lib/validators.sh"

usage() {
    printf "Usage: %s [query]\\n" "$0" >&2
}

[ "$#" -le 1 ] || {
    usage
    exit 2
}

matches_query() {
    local haystack="$1"

    [ -z "$query" ] && return 0
    [[ "${haystack,,}" == *"${query,,}"* ]]
}

cd "$repo_root"
smu_validate_repos_manifest "$repos_file"

printf "repo\\tpath\\tcategory\\troute\\tsummary\\tkeywords\\tvalidator\\n"
while IFS='|' read -r repo path category _ || [ -n "$repo" ]; do
    [[ "$repo" =~ ^[[:space:]]*# || -z "$repo" ]] && continue
    route_id=""
    summary=""
    keywords=""
    route=""
    rest=""
    if route="$(smu_route_for_path "$routes_file" "$path")"; then
        route_id="${route%%|*}"
        rest="${route#*|}"
        summary="${rest%%|*}"
        keywords="${rest#*|}"
    fi
    validator="none"
    resolved=""
    if resolved="$(smu_validator_for_repo "$validators_file" "$path")"; then
        validator="$(smu_validator_label "$resolved")"
    fi
    haystack="$repo $path $category $route_id $summary $keywords $validator"
    matches_query "$haystack" || continue
    printf "%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n" \
        "$repo" "$path" "$category" "$route_id" "$summary" "$keywords" \
        "$validator"
done < "$repos_file"
