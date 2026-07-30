#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mode="${1:---check}"

usage() {
    printf "Usage: %s [--check|--push]\n" "$0" >&2
}

case "$mode" in
    --check | --push)
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

validate_repo() {
    local path="$1"
    local command="$2"

    printf "validate\t%s\t%s\n" "$path" "$command"
    (cd "$repo_root/$path" && eval "$command")
}

require_clean_repo() {
    local path="$1"

    if [ -n "$(git -C "$repo_root/$path" status --porcelain)" ]; then
        printf "Dirty repository: %s\n" "$path" >&2
        git -C "$repo_root/$path" status --short >&2
        return 1
    fi
}

push_repo() {
    local path="$1"
    local branch="$2"

    printf "push\t%s\t%s\n" "$path" "$branch"
    git -C "$repo_root/$path" push origin "$branch"
}

validate_repo "installer" "scripts/validate.sh --all"
validate_repo "blueprint" "scripts/validate.sh"
validate_repo "tests" "scripts/validate.sh"

require_clean_repo "installer"
require_clean_repo "blueprint"
require_clean_repo "tests"

if [ "$mode" = "--push" ]; then
    push_repo "installer" "main"
    push_repo "blueprint" "master"
    push_repo "tests" "main"
fi

printf "release install/update %s complete\n" "${mode#--}"
