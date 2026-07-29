#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repos_file="$repo_root/scripts/repos.txt"
since="${1:---since=7.days}"

source "$repo_root/scripts/lib/repos.sh"

usage() {
    printf "Usage: %s [--since=<git-date>]\n" "$0" >&2
}

case "$since" in
    --since=*)
        since="${since#--since=}"
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

printf "path\tcommit\tdate\tsubject\n"
while IFS='|' read -r repo path category _ || [ -n "$repo" ]; do
    [[ "$repo" =~ ^[[:space:]]*# || -z "$repo" ]] && continue
    : "$repo" "$category"
    [ -d "$path/.git" ] || continue
    git -C "$path" log --since="$since" --format="%h%x09%cs%x09%s" |
        awk -v path="$path" 'NF { print path "\t" $0 }'
done < "$repos_file"
