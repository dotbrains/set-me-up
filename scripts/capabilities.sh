#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repos_file="$repo_root/scripts/repos.txt"
routes_file="$repo_root/scripts/agent-routes.txt"
validators_file="$repo_root/scripts/repo-validators.txt"
declared_only=0
format="--tsv"
query=""

source "$repo_root/scripts/lib/repos.sh"
source "$repo_root/scripts/lib/routes.sh"
source "$repo_root/scripts/lib/validators.sh"
source "$repo_root/scripts/lib/repo-health.sh"
source "$repo_root/scripts/lib/json.sh"

usage() {
    printf "Usage: %s [--declared] [--tsv|--json] [query]\\n" "$0" >&2
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --declared)
            declared_only=1
            ;;
        --tsv | --json)
            format="$1"
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        -*)
            usage
            exit 2
            ;;
        *)
            [ -z "$query" ] || {
                usage
                exit 2
            }
            query="$1"
            ;;
    esac
    shift
done

matches_query() {
    local haystack="$1"

    [ -z "$query" ] && return 0
    [[ "${haystack,,}" == *"${query,,}"* ]]
}

cd "$repo_root"
smu_validate_repos_manifest "$repos_file"

if [ "$format" = "--json" ]; then
    printf '{"repositories":['
    comma=""
else
    printf "repo\\tpath\\tcategory\\troute\\tsummary\\tkeywords\\tvalidator\\n"
fi
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
    if [ "$declared_only" -eq 1 ] && \
        resolved="$(smu_declared_validator_for_repo "$validators_file" "$path")"
    then
        validator="$(smu_validator_label "$resolved")"
    elif [ "$declared_only" -eq 0 ] && \
        validator="$(smu_repo_health_validator_label "$validators_file" "$path")" && \
        [ "$validator" != "none" ]
    then
        :
    else
        validator="none"
    fi
    haystack="$repo $path $category $route_id $summary $keywords $validator"
    matches_query "$haystack" || continue
    if [ "$format" = "--json" ]; then
        printf '%s{"repo":"%s","path":"%s","category":"%s","route":"%s","summary":"%s","keywords":"%s","validator":"%s"}' \
            "$comma" "$(smu_json_escape "$repo")" "$(smu_json_escape "$path")" \
            "$(smu_json_escape "$category")" "$(smu_json_escape "$route_id")" \
            "$(smu_json_escape "$summary")" "$(smu_json_escape "$keywords")" \
            "$(smu_json_escape "$validator")"
        comma=","
    else
        printf "%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n" \
            "$repo" "$path" "$category" "$route_id" "$summary" "$keywords" \
            "$validator"
    fi
done < "$repos_file"
[ "$format" = "--tsv" ] || printf ']}\n'
