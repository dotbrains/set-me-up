#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repos_file="$repo_root/scripts/repos.txt"
since="${1:---since=7.days}"
format="--tsv"

source "$repo_root/scripts/lib/repos.sh"
source "$repo_root/scripts/lib/json.sh"

usage() {
    printf "Usage: %s [--since=<git-date>] [--tsv|--json]\n" "$0" >&2
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --since=*)
            since="${1#--since=}"
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

cd "$repo_root"
smu_validate_repos_manifest "$repos_file"

if [ "$format" = "--json" ]; then
    printf '{"commits":['
    comma=""
else
    printf "path\tcommit\tdate\tsubject\n"
fi
while IFS='|' read -r repo path category _ || [ -n "$repo" ]; do
    [[ "$repo" =~ ^[[:space:]]*# || -z "$repo" ]] && continue
    : "$repo" "$category"
    [ -d "$path/.git" ] || continue
    while IFS=$'\t' read -r commit date subject || [ -n "$commit" ]; do
        [ -n "$commit" ] || continue
        if [ "$format" = "--json" ]; then
            printf '%s{"path":"%s","commit":"%s","date":"%s","subject":"%s"}' \
                "$comma" "$(smu_json_escape "$path")" \
                "$(smu_json_escape "$commit")" "$(smu_json_escape "$date")" \
                "$(smu_json_escape "$subject")"
            comma=","
        else
            printf "%s\t%s\t%s\t%s\n" "$path" "$commit" "$date" "$subject"
        fi
    done < <(git -C "$path" log --since="$since" --format="%h%x09%cs%x09%s")
done < "$repos_file"
[ "$format" = "--tsv" ] || printf ']}\n'
