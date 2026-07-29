#!/usr/bin/env bash

set -euo pipefail

smu_route_for_path() {
    local routes_file="$1"
    local wanted_path="$2"
    local route_id
    local path
    local summary
    local keywords
    local extra

    [ -f "$routes_file" ] || return 1

    while IFS='|' read -r route_id path summary keywords extra || \
        [ -n "$route_id" ]; do
        [[ "$route_id" =~ ^[[:space:]]*# || -z "$route_id" ]] && continue
        : "${extra:-}"
        [ "$path" = "$wanted_path" ] || continue
        printf "%s|%s|%s" "$route_id" "$summary" "$keywords"
        return 0
    done < "$routes_file"

    return 1
}
