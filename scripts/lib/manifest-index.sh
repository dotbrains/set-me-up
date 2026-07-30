#!/usr/bin/env bash

set -euo pipefail

smu_manifest_has_path() {
    local repos_file="$1"
    local wanted_path="$2"
    local repo
    local path
    local category

    [ "$wanted_path" = "." ] && return 0

    while IFS='|' read -r repo path category _ || [ -n "$repo" ]; do
        [[ "$repo" =~ ^[[:space:]]*# || -z "$repo" ]] && continue
        : "$category"
        [ "$path" = "$wanted_path" ] && return 0
    done < "$repos_file"

    return 1
}

smu_repo_name_for_path() {
    local repos_file="$1"
    local wanted_path="$2"
    local root_name="${3:-set-me-up}"
    local repo
    local path
    local category

    if [ "$wanted_path" = "." ]; then
        printf "%s" "$root_name"
        return 0
    fi

    while IFS='|' read -r repo path category _ || [ -n "$repo" ]; do
        [[ "$repo" =~ ^[[:space:]]*# || -z "$repo" ]] && continue
        : "$category"
        if [ "$path" = "$wanted_path" ]; then
            printf "%s" "$repo"
            return 0
        fi
    done < "$repos_file"

    return 1
}

smu_route_paths() {
    local routes_file="$1"
    local route_id
    local path
    local summary
    local keywords

    while IFS='|' read -r route_id path summary keywords _ || [ -n "$route_id" ]; do
        [[ "$route_id" =~ ^[[:space:]]*# || -z "$route_id" ]] && continue
        : "$summary" "$keywords"
        printf "%s\n" "$path"
    done < "$routes_file"
}

smu_route_exists_for_path() {
    local routes_file="$1"
    local wanted_path="$2"
    local path

    while IFS= read -r path; do
        [ "$path" = "$wanted_path" ] && return 0
    done < <(smu_route_paths "$routes_file")

    return 1
}

smu_route_drift_count() {
    local repos_file="$1"
    local routes_file="$2"
    local route_id
    local path
    local summary
    local keywords
    local drift=0

    while IFS='|' read -r route_id path summary keywords _ || [ -n "$route_id" ]; do
        [[ "$route_id" =~ ^[[:space:]]*# || -z "$route_id" ]] && continue
        : "$summary" "$keywords"
        smu_manifest_has_path "$repos_file" "$path" || drift=$((drift + 1))
    done < "$routes_file"

    printf "%s" "$drift"
}
