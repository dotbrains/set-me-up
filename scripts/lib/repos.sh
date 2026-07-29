#!/usr/bin/env bash

set -euo pipefail

readonly SMU_REPO_CATEGORIES=("top-level" "shared" "module" "config")

smu_category_icon() {
    case "$1" in
        top-level)
            printf "📦"
            ;;
        shared)
            printf "🔗"
            ;;
        module)
            printf "🧩"
            ;;
        config)
            printf "⚙️"
            ;;
        *)
            printf "?"
            ;;
    esac
}

smu_valid_category() {
    local category="$1"
    local valid_category

    for valid_category in "${SMU_REPO_CATEGORIES[@]}"; do
        [ "$category" = "$valid_category" ] && return 0
    done

    return 1
}

smu_validate_repos_manifest() {
    local repos_file="$1"
    local line_number=0
    local repo
    local path
    local category
    local extra
    local seen_repos=" "
    local seen_paths=" "

    if [ ! -f "$repos_file" ]; then
        printf "Error: %s not found. Please ensure it exists.\\n" \
            "$repos_file" >&2
        return 1
    fi

    while IFS='|' read -r repo path category extra || [ -n "$repo" ]; do
        line_number=$((line_number + 1))

        [[ "$repo" =~ ^[[:space:]]*# || -z "$repo" ]] && continue

        if [ -n "${extra:-}" ] || [ -z "$path" ] || [ -z "$category" ]; then
            printf "Invalid manifest line %s: expected repo|path|category\\n" \
                "$line_number" >&2
            return 1
        fi

        if ! smu_valid_category "$category"; then
            printf "Invalid manifest category on line %s: %s\\n" \
                "$line_number" "$category" >&2
            return 1
        fi

        if [[ "$seen_repos" == *" $repo "* ]]; then
            printf "Duplicate manifest repo on line %s: %s\\n" \
                "$line_number" "$repo" >&2
            return 1
        fi
        if [[ "$seen_paths" == *" $path "* ]]; then
            printf "Duplicate manifest path on line %s: %s\\n" \
                "$line_number" "$path" >&2
            return 1
        fi

        seen_repos+="$repo "
        seen_paths+="$path "
    done < "$repos_file"
}

smu_each_repo() {
    local repos_file="$1"
    local callback="$2"
    local repo
    local path
    local category
    local extra

    smu_validate_repos_manifest "$repos_file"

    while IFS='|' read -r repo path category extra || [ -n "$repo" ]; do
        [[ "$repo" =~ ^[[:space:]]*# || -z "$repo" ]] && continue
        "$callback" "$repo" "$path" "$category"
    done < "$repos_file"
}

smu_each_repo_in_category() {
    local repos_file="$1"
    local requested_category="$2"
    local callback="$3"
    local repo
    local path
    local category
    local extra

    smu_validate_repos_manifest "$repos_file"

    while IFS='|' read -r repo path category extra || [ -n "$repo" ]; do
        [[ "$repo" =~ ^[[:space:]]*# || -z "$repo" ]] && continue
        [ "$category" = "$requested_category" ] || continue
        "$callback" "$repo" "$path" "$category"
    done < "$repos_file"
}
