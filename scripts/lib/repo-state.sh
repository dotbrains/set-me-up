#!/usr/bin/env bash

set -euo pipefail

smu_repo_exists() {
    [ -d "$1" ]
}

smu_repo_is_git_worktree() {
    git -C "$1" rev-parse --is-inside-work-tree >/dev/null 2>&1
}

smu_repo_has_changes() {
    local path="$1"

    ! git -C "$path" diff-index --quiet HEAD -- 2>/dev/null || \
        [ -n "$(git -C "$path" ls-files --others --exclude-standard 2>/dev/null)" ]
}

smu_repo_branch() {
    git -C "$1" branch --show-current
}

smu_repo_is_ahead_or_behind_origin() {
    local path="$1"
    local branch

    branch="$(smu_repo_branch "$path")"
    [ -n "$branch" ] || return 1

    git -C "$path" rev-parse --verify "origin/$branch" >/dev/null 2>&1 || \
        return 1
    [ "$(git -C "$path" rev-parse HEAD)" != \
        "$(git -C "$path" rev-parse "origin/$branch")" ]
}

smu_repo_sync_counts() {
    local path="$1"
    local branch

    branch="$(smu_repo_branch "$path")"
    [ -n "$branch" ] || return 1

    git -C "$path" rev-parse --verify "origin/$branch" >/dev/null 2>&1 || \
        return 1
    git -C "$path" rev-list --left-right --count "HEAD...origin/$branch"
}

smu_repo_sync_status() {
    local path="$1"
    local counts
    local ahead
    local behind

    counts="$(smu_repo_sync_counts "$path")" || {
        printf "unknown"
        return 0
    }
    ahead="${counts%%[[:space:]]*}"
    behind="${counts##*[[:space:]]}"

    if [ "$ahead" -gt 0 ] && [ "$behind" -gt 0 ]; then
        printf "diverged:%s:%s" "$ahead" "$behind"
    elif [ "$ahead" -gt 0 ]; then
        printf "ahead:%s" "$ahead"
    elif [ "$behind" -gt 0 ]; then
        printf "behind:%s" "$behind"
    else
        printf "synced"
    fi
}

smu_repo_state() {
    local path="$1"

    if ! smu_repo_exists "$path"; then
        printf "missing"
    elif ! smu_repo_is_git_worktree "$path"; then
        printf "not-git"
    elif smu_repo_has_changes "$path"; then
        printf "dirty"
    elif [ -z "$(smu_repo_branch "$path")" ]; then
        printf "detached"
    elif smu_repo_is_ahead_or_behind_origin "$path"; then
        printf "changed"
    else
        printf "clean"
    fi
}
