#!/usr/bin/env bash

set -euo pipefail

smu_repo_health_sync_for_state() {
    local path="$1"
    local state="$2"

    if [ "$state" = "missing" ] || [ "$state" = "not-git" ] || \
        [ "$state" = "detached" ]; then
        printf "unknown"
    else
        smu_repo_sync_status "$path"
    fi
}

smu_repo_health_validator_label() {
    local validators_file="$1"
    local path="$2"
    local validator

    if validator="$(smu_validator_for_repo "$validators_file" "$path")"; then
        smu_validator_label "$validator"
    else
        printf "none"
    fi
}

smu_repo_health_route_id() {
    local routes_file="$1"
    local path="$2"
    local route

    if route="$(smu_route_for_path "$routes_file" "$path")"; then
        printf "%s" "${route%%|*}"
    fi
}

smu_repo_health_docs() {
    local repo_root="$1"
    local path="$2"
    local base="$repo_root/$path"
    local docs=""
    local candidate

    [ "$path" = "." ] && base="$repo_root"
    for candidate in AGENTS.md CLAUDE.md README.md CONTRIBUTING.md; do
        [ -f "$base/$candidate" ] || continue
        docs+="${docs:+,}$candidate"
    done

    printf "%s" "$docs"
}

smu_repo_health_doc_warnings() {
    local repo_root="$1"
    local path="$2"
    local base="$repo_root/$path"
    local warnings=""

    [ "$path" = "." ] && base="$repo_root"
    [ -f "$base/AGENTS.md" ] || warnings="${warnings:+,}missing AGENTS.md"
    [ -f "$base/README.md" ] || [ -f "$base/README" ] || \
        warnings="${warnings:+,}missing README"

    printf "%s" "$warnings"
}

smu_repo_health_branch() {
    local repo_root="$1"
    local path="$2"

    git -C "$repo_root/$path" rev-parse --abbrev-ref HEAD 2>/dev/null || \
        printf "unknown"
}

smu_repo_health_head() {
    local repo_root="$1"
    local path="$2"

    git -C "$repo_root/$path" rev-parse HEAD 2>/dev/null || printf "unknown"
}

smu_repo_health_upstream_sync() {
    local repo_root="$1"
    local path="$2"
    local left_right

    git -C "$repo_root/$path" rev-parse --git-dir >/dev/null 2>&1 || {
        printf "not-git"
        return 0
    }

    if git -C "$repo_root/$path" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
        left_right="$(git -C "$repo_root/$path" rev-list --left-right --count HEAD...'@{u}')"
        case "$left_right" in
            "0	0") printf "synced" ;;
            0$'\t'*) printf "behind" ;;
            *$'\t'0) printf "ahead" ;;
            *) printf "diverged" ;;
        esac
    else
        printf "unknown"
    fi
}

smu_repo_health_clean() {
    local repo_root="$1"
    local path="$2"

    [ -z "$(git -C "$repo_root/$path" status --porcelain 2>/dev/null || printf "unknown")" ]
}

smu_each_repo_health() {
    local repo_root="$1"
    local repos_file="$2"
    local routes_file="$3"
    local validators_file="$4"
    local callback="$5"
    local repo
    local path
    local category
    local state
    local sync
    local route_id
    local validator

    while IFS='|' read -r repo path category _ || [ -n "$repo" ]; do
        [[ "$repo" =~ ^[[:space:]]*# || -z "$repo" ]] && continue
        state="$(smu_repo_state "$path")"
        sync="$(smu_repo_health_sync_for_state "$path" "$state")"
        route_id="$(smu_repo_health_route_id "$routes_file" "$path")"
        validator="$(smu_repo_health_validator_label "$validators_file" "$path")"
        "$callback" "$repo" "$path" "$category" "$state" "$sync" "$route_id" "$validator"
    done < "$repos_file"
}
