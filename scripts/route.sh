#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
routes_file="$repo_root/scripts/agent-routes.txt"
query="$*"

usage() {
    printf "Usage: %s <query>\\n" "$0" >&2
}

normalize() {
    printf "%s" "$1" | tr '[:upper:]' '[:lower:]'
}

route_matches() {
    local haystack="$1"
    local needle="$2"
    local haystack_normal
    local word

    haystack_normal="$(normalize "$haystack")"
    [[ "$haystack_normal" == *"$(normalize "$needle")"* ]] && return 0

    for word in $(normalize "$needle"); do
        [[ "$haystack_normal" == *"$word"* ]] || return 1
    done
}

if [ -z "$query" ]; then
    usage
    exit 2
fi

if [ ! -f "$routes_file" ]; then
    printf "Missing route map: %s\\n" "$routes_file" >&2
    exit 1
fi

matched=0

while IFS='|' read -r route_id path summary keywords extra || [ -n "$route_id" ]; do
    [[ "$route_id" =~ ^[[:space:]]*# || -z "$route_id" ]] && continue
    : "${extra:-}"

    if route_matches "$route_id $path $summary $keywords" "$query"; then
        printf "%s\\t%s\\t%s\\n" "$route_id" "$path" "$summary"
        matched=$((matched + 1))
    fi
done < "$routes_file"

if [ "$matched" -eq 0 ]; then
    printf "No routes matched: %s\\n" "$query" >&2
    exit 1
fi
