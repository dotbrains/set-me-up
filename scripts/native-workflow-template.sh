#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repos_file="$repo_root/scripts/repos.txt"
mode="${1:---report}"

source "$repo_root/scripts/lib/repos.sh"

usage() {
    printf "Usage: %s [--report|--check]\\n" "$0" >&2
}

case "$mode" in
    --report | --check)
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
printf "path\\tstate\\n"
while IFS='|' read -r repo path category _ || [ -n "$repo" ]; do
    [[ "$repo" =~ ^[[:space:]]*# || -z "$repo" ]] && continue
    : "$category"
    [ -d "$path" ] || continue
    [ -x "$path/scripts/validate.sh" ] || continue

    if workflows_use_native_validator "$path/.github/workflows"; then
        printf "%s\\tnative-workflow\\n" "$path"
    else
        missing=$((missing + 1))
        printf "%s\\tmissing-native-workflow\\n" "$path"
    fi
done < "$repos_file"

[ "$mode" = "--report" ] || [ "$missing" -eq 0 ]
