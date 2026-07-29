#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repos_file="$repo_root/scripts/repos.txt"
routes_file="$repo_root/scripts/agent-routes.txt"
validators_file="$repo_root/scripts/repo-validators.txt"

source "$repo_root/scripts/lib/repos.sh"

usage() {
    printf "Usage: %s <repo> <local-path> <category> <route-id> <summary> <keywords> [validator]\n" "$0" >&2
}

append_line() {
    local file="$1"
    local line="$2"

    [ -s "$file" ] && [ "$(tail -c 1 "$file")" != "" ] && printf "\n" >> "$file"
    printf "%s\n" "$line" >> "$file"
}

repo="${1:-}"
path="${2:-}"
category="${3:-}"
route_id="${4:-}"
summary="${5:-}"
keywords="${6:-}"
validator="${7:-scripts/validate.sh --all}"

[ "$#" -ge 6 ] && [ "$#" -le 7 ] || {
    usage
    exit 2
}

cd "$repo_root"
smu_validate_repos_manifest "$repos_file"

if ! smu_valid_category "$category"; then
    printf "Invalid category: %s\n" "$category" >&2
    exit 1
fi

if [[ ! "$route_id" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    printf "Invalid route id: %s\n" "$route_id" >&2
    exit 1
fi

if awk -F '|' -v repo="$repo" -v path="$path" \
    '$1 !~ /^#/ && ($1 == repo || $2 == path) { found = 1 } END { exit found ? 0 : 1 }' \
    "$repos_file"; then
    printf "Repository or path already exists: %s %s\n" "$repo" "$path" >&2
    exit 1
fi

if awk -F '|' -v route_id="$route_id" \
    '$1 !~ /^#/ && $1 == route_id { found = 1 } END { exit found ? 0 : 1 }' \
    "$routes_file"; then
    printf "Route already exists: %s\n" "$route_id" >&2
    exit 1
fi

append_line "$repos_file" "$repo|$path|$category"
append_line "$routes_file" "$route_id|$path|$summary|$keywords"
append_line "$validators_file" "$path|$validator"

scripts/generate-docs.sh
scripts/new-repo-check.sh "$path"
scripts/validate.sh --structure

printf "Added managed repo %s at %s.\n" "$repo" "$path"
