#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repos_file="$repo_root/scripts/repos.txt"
stale_days="${SMU_STALE_DAYS:-180}"
now_epoch="$(date +%s)"
mode="${1:---tsv}"

source "$repo_root/scripts/lib/repos.sh"
source "$repo_root/scripts/lib/json.sh"

usage() {
    printf "Usage: %s [--tsv|--json]\n" "$0" >&2
}

case "$mode" in
    --tsv | --json)
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    *)
        usage
        exit 2
        ;;
esac

cd "$repo_root"
smu_validate_repos_manifest "$repos_file"

if [ "$mode" = "--json" ]; then
    printf '{"repositories":['
    comma=""
else
    printf "path\\tdays\\tdate\\tstate\\n"
fi
while IFS='|' read -r repo path category _ || [ -n "$repo" ]; do
    [[ "$repo" =~ ^[[:space:]]*# || -z "$repo" ]] && continue
    : "$repo" "$category"
    if [ ! -d "$path/.git" ]; then
        days="unknown"
        commit_date="unknown"
        state="missing"
        if [ "$mode" = "--json" ]; then
            printf '%s{"path":"%s","days":"%s","date":"%s","state":"%s"}' \
                "$comma" "$(smu_json_escape "$path")" "$days" "$commit_date" "$state"
            comma=","
        else
            printf "%s\\t%s\\t%s\\t%s\\n" "$path" "$days" "$commit_date" "$state"
        fi
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
    if [ "$mode" = "--json" ]; then
        printf '%s{"path":"%s","days":%s,"date":"%s","state":"%s"}' \
            "$comma" "$(smu_json_escape "$path")" "$days" \
            "$(smu_json_escape "$commit_date")" "$state"
        comma=","
    else
        printf "%s\\t%s\\t%s\\t%s\\n" "$path" "$days" "$commit_date" "$state"
    fi
done < "$repos_file"
[ "$mode" = "--tsv" ] || printf ']}\n'
