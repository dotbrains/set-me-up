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
source "$repo_root/scripts/lib/repo-state.sh"
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
print_repo() {
    local repo="$1"
    local path="$2"
    local category="$3"
    local state="$4"
    local sync="$5"
    local health_route_id="$6"
    local health_validator="$7"
    local route_id=""
    local summary=""
    local keywords=""
    local validator
    local resolved
    local haystack
    local route
    local rest

    : "$state" "$sync" "$health_route_id"
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
        validator="$health_validator" && \
        [ "$validator" != "none" ]
    then
        :
    else
        validator="none"
    fi
    haystack="$repo $path $category $route_id $summary $keywords $validator"
    if matches_query "$haystack"; then
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
    fi
}

smu_each_repo_health "$repo_root" "$repos_file" "$routes_file" "$validators_file" print_repo
[ "$format" = "--tsv" ] || printf ']}\n'
