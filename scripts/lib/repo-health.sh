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
