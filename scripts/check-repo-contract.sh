#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repos_file="$repo_root/scripts/repos.txt"
routes_file="$repo_root/scripts/agent-routes.txt"
validators_file="$repo_root/scripts/repo-validators.txt"
output_json=0
allow_diverged=0
check_all=0
checked_out_only=0
path=""

source "$repo_root/scripts/lib/repos.sh"
source "$repo_root/scripts/lib/repo-state.sh"
source "$repo_root/scripts/lib/validators.sh"
source "$repo_root/scripts/lib/json.sh"

usage() {
    printf "Usage: %s [--json] [--allow-diverged] [--checked-out] [--all|<managed-local-path>]\\n" "$0" >&2
}

manifest_has_path() {
    local wanted_path="$1"
    local repo
    local local_path
    local category

    while IFS='|' read -r repo local_path category _ || [ -n "$repo" ]; do
        [[ "$repo" =~ ^[[:space:]]*# || -z "$repo" ]] && continue
        : "$category"
        [ "$local_path" = "$wanted_path" ] && return 0
    done < "$repos_file"
    return 1
}

route_exists_for_path() {
    local wanted_path="$1"
    local route_id
    local local_path
    local summary
    local keywords

    while IFS='|' read -r route_id local_path summary keywords _ || \
        [ -n "$route_id" ]; do
        [[ "$route_id" =~ ^[[:space:]]*# || -z "$route_id" ]] && continue
        : "$summary" "$keywords"
        [ "$local_path" = "$wanted_path" ] && return 0
    done < "$routes_file"
    return 1
}

check() {
    local label="$1"
    shift

    if "$@"; then
        record_check "$label" 0
    else
        record_check "$label" 1
        failed=$((failed + 1))
    fi
}

record_check() {
    local label="$1"
    local failed_check="$2"
    local status="OK"

    [ "$failed_check" -eq 0 ] || status="FAIL"

    if [ "$output_json" -eq 1 ]; then
        check_names+=("$label")
        check_results+=("$failed_check")
    else
        printf "%s\\t%s\\n" "$status" "$label"
    fi
}

print_json() {
    local index
    local comma=""
    local ok

    printf '{"path":"%s","allowDiverged":%s,"failed":%s,"checks":[' \
        "$(smu_json_escape "$path")" "$allow_diverged" "$failed"
    for index in "${!check_names[@]}"; do
        [ "${check_results[$index]}" -eq 0 ] && ok=true || ok=false
        printf '%s{"name":"%s","ok":%s}' \
            "$comma" "$(smu_json_escape "${check_names[$index]}")" "$ok"
        comma=","
    done
    printf ']}\n'
}

reset_checks() {
    failed=0
    check_names=()
    check_results=()
}

run_contract_checks() {
    reset_checks
    check "manifest path" manifest_has_path "$path"
    check "route entry" route_exists_for_path "$path"
    check "validator" has_validator
    check "native validator" has_native_validator
    check "README" has_readme
    check "license" has_license
    check "acceptable sync state" is_acceptable_sync_state

    [ "$output_json" -eq 0 ] || print_json
    return "$failed"
}

check_all_repos() {
    local repo
    local repo_path
    local category
    local total=0
    local failed_repos=0

    while IFS='|' read -r repo repo_path category _ || [ -n "$repo" ]; do
        [[ "$repo" =~ ^[[:space:]]*# || -z "$repo" ]] && continue
        : "$category"
        [ "$repo_path" != "." ] || continue
        [ "$checked_out_only" -eq 0 ] || [ -d "$repo_path" ] || continue
        path="$repo_path"
        total=$((total + 1))
        if [ "$output_json" -eq 0 ]; then
            printf "== %s ==\\n" "$path"
        fi
        run_contract_checks || failed_repos=$((failed_repos + 1))
    done < "$repos_file"

    if [ "$output_json" -eq 0 ]; then
        printf "contracts: total=%s failed=%s\\n" "$total" "$failed_repos"
    fi
    [ "$failed_repos" -eq 0 ]
}

has_validator() {
    smu_validator_for_repo "$validators_file" "$path" >/dev/null
}

has_native_validator() {
    [ -x "$repo_root/$path/scripts/validate.sh" ]
}

has_readme() {
    [ -f "$repo_root/$path/README.md" ] || [ -f "$repo_root/$path/README" ]
}

has_license() {
    [ -f "$repo_root/$path/LICENSE" ] || [ -f "$repo_root/$path/LICENSE.md" ]
}

is_acceptable_sync_state() {
    local state
    local sync

    state="$(smu_repo_state "$path")"
    sync="$(smu_repo_sync_status "$path")"
    if [ "$state" = "clean" ] && [ "$sync" = "synced" ]; then
        return 0
    fi
    [ "$allow_diverged" -eq 1 ] && [ "$state" = "changed" ] && \
        [[ "$sync" == diverged:* ]]
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --json)
            output_json=1
            ;;
        --allow-diverged)
            allow_diverged=1
            ;;
        --all)
            check_all=1
            ;;
        --checked-out)
            checked_out_only=1
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        -*)
            usage
            exit 2
            ;;
        *)
            [ -z "$path" ] || {
                usage
                exit 2
            }
            path="$1"
            ;;
    esac
    shift
done

cd "$repo_root"
smu_validate_repos_manifest "$repos_file"

if [ "$check_all" -eq 1 ]; then
    [ -z "$path" ] || {
        usage
        exit 2
    }
    check_all_repos
else
    [ -n "$path" ] || {
        usage
        exit 2
    }
    run_contract_checks
fi
