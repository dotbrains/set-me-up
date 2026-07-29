#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repos_file="$repo_root/scripts/repos.txt"
validators_file="$repo_root/scripts/repo-validators.txt"

source "$repo_root/scripts/lib/repos.sh"
source "$repo_root/scripts/lib/repo-state.sh"
source "$repo_root/scripts/lib/validators.sh"

print_repo() {
    local repo="$1"
    local path="$2"
    local category="$3"
    local state
    local sync
    local validator="none"
    local dirty_paths
    local submodule_paths

    : "$repo" "$category"
    state="$(smu_repo_state "$path")"
    sync="unknown"
    if [ "$state" != "missing" ] && [ "$state" != "not-git" ] && \
        [ "$state" != "detached" ]; then
        sync="$(smu_repo_sync_status "$path")"
    fi
    if smu_validator_for_repo "$validators_file" "$path" >/dev/null; then
        validator="$(smu_validator_label "$(smu_validator_for_repo "$validators_file" "$path")")"
    fi

    printf "%s\\t%s\\t%s\\t%s\\n" "$path" "$state" "$sync" "$validator"

    if [ "$state" = "dirty" ]; then
        dirty_paths="$(git -C "$path" status --short 2>/dev/null | sed 's/^/  /')"
        [ -z "$dirty_paths" ] || printf "%s\\n" "$dirty_paths"
    fi

    if [ "$state" != "missing" ] && [ "$state" != "not-git" ]; then
        submodule_paths="$(
            git -C "$path" submodule status --recursive 2>/dev/null |
                awk '$1 ~ /^[+-]/ {print "  submodule " $2 " " $1}'
        )"
        [ -z "$submodule_paths" ] || printf "%s\\n" "$submodule_paths"
    fi
}

cd "$repo_root"
printf "path\\tstate\\tsync\\tvalidator\\n"
smu_each_repo "$repos_file" print_repo
