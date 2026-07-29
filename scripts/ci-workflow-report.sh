#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repos_file="$repo_root/scripts/repos.txt"
strict=0
checked_out_only=0
count=0

usage() {
    printf "Usage: %s [--checked-out] [--strict]\\n" "$0" >&2
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --checked-out)
            checked_out_only=1
            ;;
        --strict)
            strict=1
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
    shift
done

source "$repo_root/scripts/lib/repos.sh"

cd "$repo_root"
smu_validate_repos_manifest "$repos_file"

missing=0
printf "path\\tstate\\tworkflows\\n"
while IFS='|' read -r repo path category _ || [ -n "$repo" ]; do
    [[ "$repo" =~ ^[[:space:]]*# || -z "$repo" ]] && continue
    : "$category"
    [ "$path" = "." ] && continue
    [ "$checked_out_only" -eq 0 ] || [ -d "$path" ] || continue

    if [ ! -d "$path" ]; then
        printf "%s\\tmissing\\tunknown\\n" "$path"
    elif [ -d "$path/.github/workflows" ] && \
        find "$path/.github/workflows" -maxdepth 1 -type f \
            \( -name '*.yml' -o -name '*.yaml' \) | grep -q .; then
        count="$(find "$path/.github/workflows" -maxdepth 1 -type f \
            \( -name '*.yml' -o -name '*.yaml' \) | wc -l | tr -d ' ')"
        printf "%s\\tpresent\\t%s\\n" "$path" "$count"
    else
        missing=$((missing + 1))
        printf "%s\\tmissing\\t0\\n" "$path"
    fi
done < "$repos_file"

[ "$strict" -eq 0 ] || [ "$missing" -eq 0 ]
