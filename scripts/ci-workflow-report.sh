#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repos_file="$repo_root/scripts/repos.txt"
strict=0
checked_out_only=0
format="--tsv"
count=0

usage() {
    printf "Usage: %s [--checked-out] [--strict] [--tsv|--json]\\n" "$0" >&2
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --checked-out)
            checked_out_only=1
            ;;
        --strict)
            strict=1
            ;;
        --tsv | --json)
            format="$1"
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
source "$repo_root/scripts/lib/json.sh"

cd "$repo_root"
smu_validate_repos_manifest "$repos_file"

missing=0
if [ "$format" = "--json" ]; then
    printf '{"repositories":['
    comma=""
else
    printf "path\\tstate\\tworkflows\\n"
fi
while IFS='|' read -r repo path category _ || [ -n "$repo" ]; do
    [[ "$repo" =~ ^[[:space:]]*# || -z "$repo" ]] && continue
    : "$category"
    [ "$path" = "." ] && continue
    [ "$checked_out_only" -eq 0 ] || [ -d "$path" ] || continue

    if [ ! -d "$path" ]; then
        state="missing"
        workflows="unknown"
    elif [ -d "$path/.github/workflows" ] && \
        find "$path/.github/workflows" -maxdepth 1 -type f \
            \( -name '*.yml' -o -name '*.yaml' \) | grep -q .; then
        count="$(find "$path/.github/workflows" -maxdepth 1 -type f \
            \( -name '*.yml' -o -name '*.yaml' \) | wc -l | tr -d ' ')"
        state="present"
        workflows="$count"
    else
        missing=$((missing + 1))
        state="missing"
        workflows="0"
    fi
    if [ "$format" = "--json" ]; then
        printf '%s{"path":"%s","state":"%s","workflows":"%s"}' \
            "$comma" "$(smu_json_escape "$path")" "$state" "$workflows"
        comma=","
    else
        printf "%s\\t%s\\t%s\\n" "$path" "$state" "$workflows"
    fi
done < "$repos_file"
[ "$format" = "--tsv" ] || printf ']}\n'

[ "$strict" -eq 0 ] || [ "$missing" -eq 0 ]
