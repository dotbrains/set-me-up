#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repos_file="$repo_root/scripts/repos.txt"
mode="${1:---changed}"

usage() {
    printf "Usage: %s [--changed|--clean|--all|--list]\\n" "$0" >&2
}

repo_has_changes() {
    local path="$1"

    [ -n "$(git -C "$path" status --short)" ]
}

repo_head_changed_from_origin() {
    local path="$1"
    local branch

    branch="$(git -C "$path" branch --show-current)"
    [ -n "$branch" ] || return 1

    git -C "$path" rev-parse --verify "origin/$branch" >/dev/null 2>&1 || \
        return 1
    [ "$(git -C "$path" rev-parse HEAD)" != \
        "$(git -C "$path" rev-parse "origin/$branch")" ]
}

validator_for_repo() {
    local path="$1"

    if [ -x "$path/scripts/validate.sh" ]; then
        printf "root-validator"
    elif [ -f "$path/package.json" ]; then
        printf "npm-test"
    elif [ -x "$path/test.sh" ]; then
        printf "test-script"
    else
        return 1
    fi
}

run_validator() {
    local path="$1"
    local validator="$2"

    printf "\\n== %s ==\\n" "$path"
    printf "Running: %s\\n" "$(validator_label "$validator")"
    (
        cd "$repo_root/$path"
        case "$validator" in
            root-validator)
                scripts/validate.sh --all
                ;;
            npm-test)
                npm test
                ;;
            test-script)
                ./test.sh
                ;;
            *)
                printf "Unknown validator: %s\\n" "$validator" >&2
                exit 2
                ;;
        esac
    )
}

validator_label() {
    case "$1" in
        root-validator)
            printf "scripts/validate.sh --all"
            ;;
        npm-test)
            printf "npm test"
            ;;
        test-script)
            printf "./test.sh"
            ;;
        *)
            printf "%s" "$1"
            ;;
    esac
}

selected_repo() {
    local path="$1"

    case "$mode" in
        --all|--list)
            return 0
            ;;
        --clean)
            ! repo_has_changes "$path"
            ;;
        --changed)
            repo_has_changes "$path" || repo_head_changed_from_origin "$path"
            ;;
        *)
            usage
            exit 2
            ;;
    esac
}

cd "$repo_root"

ran=0
skipped=0

while IFS='|' read -r repo path category extra || [ -n "$repo" ]; do
    [[ "$repo" =~ ^[[:space:]]*# || -z "$repo" ]] && continue

    if [ -n "${extra:-}" ] || [ -z "$path" ] || [ -z "$category" ]; then
        printf "Invalid manifest entry: %s|%s|%s\\n" \
            "$repo" "$path" "$category" >&2
        exit 1
    fi

    if ! git -C "$path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        printf "skip missing: %s\\n" "$path"
        skipped=$((skipped + 1))
        continue
    fi

    if ! selected_repo "$path"; then
        continue
    fi

    status="$(git -C "$path" status --short)"
    if [ -n "$status" ]; then
        printf "skip dirty: %s\\n" "$path"
        skipped=$((skipped + 1))
        continue
    fi

    if ! validator="$(validator_for_repo "$path")"; then
        printf "skip no validator: %s\\n" "$path"
        skipped=$((skipped + 1))
        continue
    fi

    if [ "$mode" = "--list" ]; then
        printf "%s: %s\\n" "$path" "$(validator_label "$validator")"
    else
        run_validator "$path" "$validator"
    fi
    ran=$((ran + 1))
done < "$repos_file"

printf "\\nValidated %s repo(s); skipped %s.\\n" "$ran" "$skipped"
