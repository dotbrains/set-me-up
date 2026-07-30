#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repos_file="$repo_root/scripts/repos.txt"
validators_file="$repo_root/scripts/repo-validators.txt"
format="${1:---tsv}"

source "$repo_root/scripts/lib/repos.sh"
source "$repo_root/scripts/lib/repo-state.sh"
source "$repo_root/scripts/lib/validators.sh"
source "$repo_root/scripts/lib/repo-health.sh"
source "$repo_root/scripts/lib/json.sh"

usage() {
    printf "Usage: %s [--tsv|--json]\n" "$0" >&2
}

case "$format" in
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

print_repo() {
    local repo="$1"
    local path="$2"
    local category="$3"
    local state
    local sync
    local validator="none"
    local dirty_paths
    local submodule_paths

    : "$repo" "$category"
    state="$(smu_repo_state "$path")"
    sync="$(smu_repo_health_sync_for_state "$path" "$state")"
    validator="$(smu_repo_health_validator_label "$validators_file" "$path")"

    if [ "$format" = "--json" ]; then
        printf '%s{"path":"%s","state":"%s","sync":"%s","validator":"%s"}' \
            "$comma" "$(smu_json_escape "$path")" "$(smu_json_escape "$state")" \
            "$(smu_json_escape "$sync")" "$(smu_json_escape "$validator")"
        comma=","
    else
        printf "%s\\t%s\\t%s\\t%s\\n" "$path" "$state" "$sync" "$validator"
    fi

    if [ "$format" = "--tsv" ] && [ "$state" = "dirty" ]; then
        dirty_paths="$(git -C "$path" status --short 2>/dev/null | sed 's/^/  /')"
        [ -z "$dirty_paths" ] || printf "%s\\n" "$dirty_paths"
    fi

    if [ "$format" = "--tsv" ] && [ "$state" != "missing" ] && \
        [ "$state" != "not-git" ]; then
        submodule_paths="$(
            git -C "$path" submodule status --recursive 2>/dev/null |
                awk '$1 ~ /^[+-]/ {print "  submodule " $2 " " $1}'
        )"
        [ -z "$submodule_paths" ] || printf "%s\\n" "$submodule_paths"
    fi
}

cd "$repo_root"
if [ "$format" = "--json" ]; then
    printf '{"repositories":['
    comma=""
else
    printf "path\\tstate\\tsync\\tvalidator\\n"
fi
smu_each_repo "$repos_file" print_repo
[ "$format" = "--tsv" ] || printf ']}\n'
