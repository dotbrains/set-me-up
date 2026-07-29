#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repos_file="$repo_root/scripts/repos.txt"
stale_days="${SMU_STALE_DAYS:-180}"
now_epoch="$(date +%s)"

source "$repo_root/scripts/lib/repos.sh"

cd "$repo_root"
smu_validate_repos_manifest "$repos_file"

printf "path\\tdays\\tdate\\tstate\\n"
while IFS='|' read -r repo path category _ || [ -n "$repo" ]; do
    [[ "$repo" =~ ^[[:space:]]*# || -z "$repo" ]] && continue
    : "$repo" "$category"
    if [ ! -d "$path/.git" ]; then
        printf "%s\\tunknown\\tunknown\\tmissing\\n" "$path"
        continue
    fi
    commit_epoch="$(git -C "$path" log -1 --format=%ct)"
    commit_date="$(git -C "$path" log -1 --format=%cs)"
    days=$(((now_epoch - commit_epoch) / 86400))
    if [ "$days" -gt "$stale_days" ]; then
        state="stale"
    else
        state="fresh"
    fi
    printf "%s\\t%s\\t%s\\t%s\\n" "$path" "$days" "$commit_date" "$state"
done < "$repos_file"
