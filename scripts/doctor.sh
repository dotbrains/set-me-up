#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repos_file="$repo_root/scripts/repos.txt"
routes_file="$repo_root/scripts/agent-routes.txt"
validators_file="$repo_root/scripts/repo-validators.txt"

source "$repo_root/scripts/lib/repos.sh"
source "$repo_root/scripts/lib/repo-state.sh"
source "$repo_root/scripts/lib/routes.sh"
source "$repo_root/scripts/lib/validators.sh"
source "$repo_root/scripts/lib/manifest-index.sh"
source "$repo_root/scripts/lib/repo-health.sh"
source "$repo_root/scripts/lib/json.sh"

usage() {
    printf "Usage: %s [--summary|--verbose|--json]\\n" "$0" >&2
}

mode="${1:---summary}"

case "$mode" in
    --summary|--verbose|--json)
        ;;
    *)
        usage
        exit 2
        ;;
esac

route_exists_for_path() {
    smu_route_exists_for_path "$routes_file" "$1"
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

count_sync() {
    case "$1" in
        synced)
            synced=$((synced + 1))
            ;;
        ahead:*)
            ahead=$((ahead + 1))
            ;;
        behind:*)
            behind=$((behind + 1))
            ;;
        diverged:*)
            diverged=$((diverged + 1))
            ;;
        unknown)
            unknown_sync=$((unknown_sync + 1))
            ;;
    esac
}

inspect_repo() {
    local repo="$1"
    local path="$2"
    local category="$3"
    local state="$4"
    local sync_status="$5"
    local route_id="$6"
    local validator_label="$7"
    local route_status="missing-route"

    : "$repo" "$category"
    total=$((total + 1))
    count_state "$state"
    count_sync "$sync_status"

    if [ "$validator_label" != "none" ]; then
        has_validator=$((has_validator + 1))
    else
        no_validator=$((no_validator + 1))
    fi

    if [ -n "$route_id" ]; then
        route_status="routed"
        routed=$((routed + 1))
    else
        unrouted=$((unrouted + 1))
    fi

    if [ "$mode" = "--verbose" ]; then
        printf "%s\\t%s\\t%s\\t%s\\t%s\\n" \
            "$path" "$state" "$sync_status" "$validator_label" "$route_status"
    elif [ "$mode" = "--json" ]; then
        printf '%s{"repo":"%s","path":"%s","category":"%s","state":"%s","sync":"%s","validator":"%s","route":"%s"}' \
            "$repo_comma" "$(smu_json_escape "$repo")" \
            "$(smu_json_escape "$path")" "$(smu_json_escape "$category")" \
            "$(smu_json_escape "$state")" "$(smu_json_escape "$sync_status")" \
            "$(smu_json_escape "$validator_label")" "$(smu_json_escape "$route_status")"
        repo_comma=","
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
        if ! smu_manifest_has_path "$repos_file" "$path"; then
            route_drift=$((route_drift + 1))
            [ "$mode" = "--verbose" ] && \
                printf "route-drift\\t%s\\t%s\\n" "$route_id" "$path"
            if [ "$mode" = "--json" ]; then
                printf '%s{"route":"%s","path":"%s"}' \
                    "$drift_comma" "$(smu_json_escape "$route_id")" \
                    "$(smu_json_escape "$path")"
                drift_comma=","
            fi
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
synced=0
ahead=0
behind=0
diverged=0
unknown_sync=0
repo_comma=""
drift_comma=""

if [ "$mode" = "--verbose" ]; then
    printf "path\\tstate\\tsync\\tvalidator\\troute\\n"
elif [ "$mode" = "--json" ]; then
    printf '{"repositories":['
fi

smu_each_repo_health "$repo_root" "$repos_file" "$routes_file" "$validators_file" inspect_repo
if [ "$mode" = "--json" ]; then
    printf '],"route_drift":['
fi
check_route_drift

if [ "$mode" = "--json" ]; then
    printf '],"summary":{"repos":{"total":%s,"clean":%s,"changed":%s,"dirty":%s,"detached":%s,"missing":%s,"not_git":%s},"validators":{"present":%s,"missing":%s},"routes":{"present":%s,"missing":%s,"drift":%s},"sync":{"synced":%s,"ahead":%s,"behind":%s,"diverged":%s,"unknown":%s}}}\n' \
        "$total" "$clean" "$changed" "$dirty" "$detached" "$missing" "$not_git" \
        "$has_validator" "$no_validator" "$routed" "$unrouted" "$route_drift" \
        "$synced" "$ahead" "$behind" "$diverged" "$unknown_sync"
else
    printf "set-me-up doctor\\n"
    printf "repos: total=%s clean=%s changed=%s dirty=%s detached=%s missing=%s not-git=%s\\n" \
        "$total" "$clean" "$changed" "$dirty" "$detached" "$missing" "$not_git"
    printf "validators: present=%s missing=%s\\n" "$has_validator" "$no_validator"
    printf "routes: present=%s missing=%s drift=%s\\n" \
        "$routed" "$unrouted" "$route_drift"
    printf "sync: synced=%s ahead=%s behind=%s diverged=%s unknown=%s\\n" \
        "$synced" "$ahead" "$behind" "$diverged" "$unknown_sync"
fi
