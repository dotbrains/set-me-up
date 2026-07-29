#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repos_file="$repo_root/scripts/repos.txt"
mode="${1:---report}"
format="--tsv"

source "$repo_root/scripts/lib/repos.sh"
source "$repo_root/scripts/lib/json.sh"

usage() {
    printf "Usage: %s [--report|--check] [--tsv|--json]\\n" "$0" >&2
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --report | --check)
            mode="$1"
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

workflows_use_native_validator() {
    local workflow_dir="$1"

    [ -d "$workflow_dir" ] || return 1
    find "$workflow_dir" -maxdepth 1 -type f \
        \( -name '*.yml' -o -name '*.yaml' \) -print0 |
        xargs -0 grep -F "scripts/validate.sh --all" >/dev/null 2>&1
}

cd "$repo_root"
smu_validate_repos_manifest "$repos_file"

missing=0
if [ "$format" = "--json" ]; then
    printf '{"repositories":['
    comma=""
else
    printf "path\\tstate\\n"
fi
while IFS='|' read -r repo path category _ || [ -n "$repo" ]; do
    [[ "$repo" =~ ^[[:space:]]*# || -z "$repo" ]] && continue
    : "$category"
    [ -d "$path" ] || continue
    [ -x "$path/scripts/validate.sh" ] || continue

    if workflows_use_native_validator "$path/.github/workflows"; then
        state="native-workflow"
    else
        missing=$((missing + 1))
        state="missing-native-workflow"
    fi
    if [ "$format" = "--json" ]; then
        printf '%s{"path":"%s","state":"%s"}' \
            "$comma" "$(smu_json_escape "$path")" "$state"
        comma=","
    else
        printf "%s\\t%s\\n" "$path" "$state"
    fi
done < "$repos_file"
[ "$format" = "--tsv" ] || printf ']}\n'

[ "$mode" = "--report" ] || [ "$missing" -eq 0 ]
