#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repos_file="$repo_root/scripts/repos.txt"
routes_file="$repo_root/scripts/agent-routes.txt"
validators_file="$repo_root/scripts/repo-validators.txt"

source "$repo_root/scripts/lib/repos.sh"
source "$repo_root/scripts/lib/repo-state.sh"
source "$repo_root/scripts/lib/validators.sh"

usage() {
    printf "Usage: %s [--summary|--verbose]\\n" "$0" >&2
}

mode="${1:---summary}"

case "$mode" in
    --summary|--verbose)
        ;;
    *)
        usage
        exit 2
        ;;
esac

manifest_has_path() {
    local wanted_path="$1"
    local repo
    local path
    local category

    [ "$wanted_path" = "." ] && return 0

    while IFS='|' read -r repo path category _ || [ -n "$repo" ]; do
        [[ "$repo" =~ ^[[:space:]]*# || -z "$repo" ]] && continue
        : "$category"
        [ "$path" = "$wanted_path" ] && return 0
    done < "$repos_file"

    return 1
}

route_paths() {
    local route_id
    local path
    local summary
    local keywords

    while IFS='|' read -r route_id path summary keywords _ || [ -n "$route_id" ]; do
        [[ "$route_id" =~ ^[[:space:]]*# || -z "$route_id" ]] && continue
        : "$summary" "$keywords"
        printf "%s\\n" "$path"
    done < "$routes_file"
}

route_exists_for_path() {
    local wanted_path="$1"
    local path

    while IFS= read -r path; do
        [ "$path" = "$wanted_path" ] && return 0
    done < <(route_paths)

    return 1
}

count_state() {
    case "$1" in
        missing)
            missing=$((missing + 1))
            ;;
        not-git)
            not_git=$((not_git + 1))
            ;;
        dirty)
            dirty=$((dirty + 1))
            ;;
        detached)
            detached=$((detached + 1))
            ;;
        changed)
            changed=$((changed + 1))
            ;;
        clean)
            clean=$((clean + 1))
            ;;
    esac
}

inspect_repo() {
    local repo="$1"
    local path="$2"
    local category="$3"
    local state
    local validator
    local validator_label="none"
    local route_status="missing-route"

    : "$repo" "$category"
    total=$((total + 1))
    state="$(smu_repo_state "$path")"
    count_state "$state"

    if smu_validator_for_repo "$validators_file" "$path" >/dev/null; then
        validator="$(smu_validator_for_repo "$validators_file" "$path")"
        validator_label="$(smu_validator_label "$validator")"
        has_validator=$((has_validator + 1))
    else
        no_validator=$((no_validator + 1))
    fi

    if route_exists_for_path "$path"; then
        route_status="routed"
        routed=$((routed + 1))
    else
        unrouted=$((unrouted + 1))
    fi

    if [ "$mode" = "--verbose" ]; then
        printf "%s\\t%s\\t%s\\t%s\\n" \
            "$path" "$state" "$validator_label" "$route_status"
    fi
}

check_route_drift() {
    local route_id
    local path
    local summary
    local keywords

    while IFS='|' read -r route_id path summary keywords _ || [ -n "$route_id" ]; do
        [[ "$route_id" =~ ^[[:space:]]*# || -z "$route_id" ]] && continue
        : "$summary" "$keywords"
        if ! manifest_has_path "$path"; then
            route_drift=$((route_drift + 1))
            [ "$mode" = "--verbose" ] && \
                printf "route-drift\\t%s\\t%s\\n" "$route_id" "$path"
        fi
    done < "$routes_file"
}

cd "$repo_root"
smu_validate_repos_manifest "$repos_file"

total=0
missing=0
not_git=0
dirty=0
detached=0
changed=0
clean=0
has_validator=0
no_validator=0
routed=0
unrouted=0
route_drift=0

if [ "$mode" = "--verbose" ]; then
    printf "path\\tstate\\tvalidator\\troute\\n"
fi

smu_each_repo "$repos_file" inspect_repo
check_route_drift

printf "set-me-up doctor\\n"
printf "repos: total=%s clean=%s changed=%s dirty=%s detached=%s missing=%s not-git=%s\\n" \
    "$total" "$clean" "$changed" "$dirty" "$detached" "$missing" "$not_git"
printf "validators: present=%s missing=%s\\n" "$has_validator" "$no_validator"
printf "routes: present=%s missing=%s drift=%s\\n" \
    "$routed" "$unrouted" "$route_drift"
