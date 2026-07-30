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

smu_validate_route_map() {
    local repos_file="$1"
    local routes_file="$2"
    local line_number=0
    local route_id
    local path
    local summary
    local keywords
    local extra
    local seen_routes=" "

    while IFS='|' read -r route_id path summary keywords extra || \
        [ -n "$route_id" ]; do
        line_number=$((line_number + 1))
        [[ "$route_id" =~ ^[[:space:]]*# || -z "$route_id" ]] && continue

        if [ -n "${extra:-}" ] || [ -z "$path" ] || [ -z "$summary" ] || \
            [ -z "$keywords" ]; then
            printf "Invalid route line %s: expected route_id|local_path|summary|keywords\n" \
                "$line_number" >&2
            return 1
        fi
        if [[ ! "$route_id" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
            printf "Invalid route id on line %s: %s\n" \
                "$line_number" "$route_id" >&2
            return 1
        fi
        if [[ "$seen_routes" == *" $route_id "* ]]; then
            printf "Duplicate route id on line %s: %s\n" \
                "$line_number" "$route_id" >&2
            return 1
        fi
        if ! smu_manifest_has_path "$repos_file" "$path"; then
            printf "Route path on line %s is not in scripts/repos.txt: %s\n" \
                "$line_number" "$path" >&2
            return 1
        fi

        seen_routes+="$route_id "
    done < "$routes_file"
}

smu_validate_intent_map() {
    local repos_file="$1"
    local intents_file="$2"
    local line_number=0
    local intent_id
    local primary_paths
    local related_paths
    local validation_commands
    local summary
    local keywords
    local extra
    local seen_intents=" "
    local path
    local keyword

    while IFS='|' read -r intent_id primary_paths related_paths validation_commands summary keywords extra || \
        [ -n "$intent_id" ]; do
        line_number=$((line_number + 1))
        [[ "$intent_id" =~ ^[[:space:]]*# || -z "$intent_id" ]] && continue

        if [ -n "${extra:-}" ] || [ -z "$primary_paths" ] || \
            [ -z "$related_paths" ] || [ -z "$validation_commands" ] || \
            [ -z "$summary" ] || [ -z "$keywords" ]; then
            printf "Invalid intent line %s: expected intent_id|primary_paths|related_paths|validation_commands|summary|keywords\n" \
                "$line_number" >&2
            return 1
        fi
        if [[ ! "$intent_id" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
            printf "Invalid intent id on line %s: %s\n" \
                "$line_number" "$intent_id" >&2
            return 1
        fi
        if [[ "$seen_intents" == *" $intent_id "* ]]; then
            printf "Duplicate intent id on line %s: %s\n" \
                "$line_number" "$intent_id" >&2
            return 1
        fi

        IFS=',' read -r -a paths <<< "$primary_paths,$related_paths"
        for path in "${paths[@]}"; do
            [ -n "$path" ] || continue
            if ! smu_manifest_has_path "$repos_file" "$path"; then
                printf "Intent path on line %s is not in scripts/repos.txt: %s\n" \
                    "$line_number" "$path" >&2
                return 1
            fi
        done

        seen_intents+="$intent_id "
    done < "$intents_file"

    for intent_id in add-theme add-prompt change-smu-command add-managed-repo \
        add-module agent-config; do
        grep -Eq "^${intent_id}\\|" "$intents_file" || {
            printf "Missing core agent intent: %s\n" "$intent_id" >&2
            return 1
        }
    done

    for keyword in theme prompt smu agent module repo; do
        grep -Eq "^[^#].*\\|[^|]*\\b${keyword}\\b[^|]*$" "$intents_file" || {
            printf "Missing route-to-intent coverage keyword: %s\n" "$keyword" >&2
            return 1
        }
    done
}

smu_validate_repo_validators() {
    local repos_file="$1"
    local validators_file="$2"
    local line_number=0
    local path
    local command
    local extra
    local seen_paths=" "

    while IFS='|' read -r path command extra || [ -n "$path" ]; do
        line_number=$((line_number + 1))
        [[ "$path" =~ ^[[:space:]]*# || -z "$path" ]] && continue

        if [ -n "${extra:-}" ] || [ -z "$command" ]; then
            printf "Invalid validator line %s: expected local_path|command\n" \
                "$line_number" >&2
            return 1
        fi
        if [[ "$seen_paths" == *" $path "* ]]; then
            printf "Duplicate validator path on line %s: %s\n" \
                "$line_number" "$path" >&2
            return 1
        fi
        if ! smu_manifest_has_path "$repos_file" "$path"; then
            printf "Validator path on line %s is not in scripts/repos.txt: %s\n" \
                "$line_number" "$path" >&2
            return 1
        fi

        seen_paths+="$path "
    done < "$validators_file"
}
