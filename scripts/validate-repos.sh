#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repos_file="$repo_root/scripts/repos.txt"
validators_file="$repo_root/scripts/repo-validators.txt"
mode="${1:---changed}"

source "$repo_root/scripts/lib/repos.sh"
source "$repo_root/scripts/lib/repo-state.sh"
source "$repo_root/scripts/lib/validators.sh"

usage() {
    printf "Usage: %s [--changed|--clean|--all|--list]\\n" "$0" >&2
}

run_validator() {
    local path="$1"
    local validator="$2"

    printf "\\n== %s ==\\n" "$path"
    printf "Running: %s\\n" "$(smu_validator_label "$validator")"
    smu_run_validator "$repo_root" "$path" "$validator"
}

selected_repo() {
    local state="$1"

    case "$mode" in
        --all|--list)
            return 0
            ;;
        --clean)
            [ "$state" = "clean" ]
            ;;
        --changed)
            [ "$state" = "dirty" ] || [ "$state" = "changed" ]
            ;;
        *)
            usage
            exit 2
            ;;
    esac
}

cd "$repo_root"

validate_manifest_repo() {
    local repo="$1"
    local path="$2"
    local category="$3"
    local state
    local validator

    : "$repo" "$category"
    state="$(smu_repo_state "$path")"

    if [ "$state" = "missing" ]; then
        printf "skip missing: %s\\n" "$path"
        skipped=$((skipped + 1))
        return 0
    fi

    if [ "$state" = "not-git" ]; then
        printf "skip not-git: %s\\n" "$path"
        skipped=$((skipped + 1))
        return 0
    fi

    if ! selected_repo "$state"; then
        return 0
    fi

    if [ "$state" = "dirty" ]; then
        printf "skip dirty: %s\\n" "$path"
        skipped=$((skipped + 1))
        return 0
    fi

    if ! validator="$(smu_validator_for_repo "$validators_file" "$path")"; then
        printf "skip no validator: %s\\n" "$path"
        skipped=$((skipped + 1))
        return 0
    fi

    if [ "$mode" = "--list" ]; then
        printf "%s: %s\\n" "$path" "$(smu_validator_label "$validator")"
    else
        run_validator "$path" "$validator"
    fi
    ran=$((ran + 1))
}

ran=0
skipped=0

smu_each_repo "$repos_file" validate_manifest_repo

printf "\\nValidated %s repo(s); skipped %s.\\n" "$ran" "$skipped"
