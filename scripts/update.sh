#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
repos_file="$script_dir/repos.txt"
mode="--apply"
validate_after=0
format="--text"

source "$script_dir/lib/repos.sh"
source "$script_dir/lib/repo-state.sh"
source "$script_dir/lib/validators.sh"
source "$script_dir/lib/repo-health.sh"
source "$script_dir/lib/json.sh"

usage() {
    printf "Usage: %s [--plan|--apply] [--validate] [--text|--json]\n" "$0" >&2
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --plan | --apply)
            mode="$1"
            ;;
        --validate)
            validate_after=1
            ;;
        --text | --json)
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

command -v git >/dev/null 2>&1 || {
    printf "Error: git is not installed.\n" >&2
    exit 1
}

repo_head() {
    git -C "$1" rev-parse HEAD 2>/dev/null || printf "unknown"
}

fetch_origin_quiet() {
    local path="$1"
    local timeout_seconds="${SMU_UPDATE_FETCH_TIMEOUT:-15}"

    GIT_TERMINAL_PROMPT=0 python3 - "$path" "$timeout_seconds" <<'PY'
import subprocess
import sys

path = sys.argv[1]
timeout_seconds = int(sys.argv[2])
try:
    subprocess.run(
        ["git", "-C", path, "fetch", "--quiet", "origin"],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        timeout=timeout_seconds,
    )
except (OSError, subprocess.TimeoutExpired):
    pass
PY
}

repo_action() {
    local state="$1"
    local sync="$2"

    case "$state" in
        missing | not-git | dirty | detached)
            printf "skip-%s" "$state"
            ;;
        *)
            case "$sync" in
                synced)
                    printf "current"
                    ;;
                behind:*)
                    printf "update"
                    ;;
                ahead:*)
                    printf "skip-ahead"
                    ;;
                diverged:*)
                    printf "skip-diverged"
                    ;;
                *)
                    printf "skip-unknown-sync"
                    ;;
            esac
            ;;
    esac
}

inspect_repo() {
    local repo="$1"
    local path="$2"
    local category="$3"
    local state sync before after action validation
    local cached _route_id _validator_label

    : "$repo" "$category"
    cached=""
    _route_id=""
    _validator_label=""
    if [ -n "${SMU_REPO_HEALTH_CACHE:-}" ]; then
        cached="$(smu_repo_health_cache_for_path "$SMU_REPO_HEALTH_CACHE" "$path" || true)"
    fi
    if [ -n "$cached" ]; then
        IFS=$'\t' read -r repo path category state sync _route_id _validator_label <<< "$cached"
    else
        state="$(smu_repo_state "$path")"
        sync="unknown"
    fi
    before="unknown"
    after="unknown"
    validation="not-run"

    if [ "$state" != "missing" ] && [ "$state" != "not-git" ]; then
        before="$(repo_head "$path")"
    fi
    if [ "$mode" = "--apply" ] && \
        [ "$state" != "missing" ] && [ "$state" != "not-git" ] && \
        [ "$state" != "detached" ]; then
        fetch_origin_quiet "$path"
    fi
    if [ -z "$cached" ] && [ "$state" != "missing" ] && [ "$state" != "not-git" ] && \
        [ "$state" != "detached" ]; then
        sync="$(smu_repo_sync_status "$path")"
    fi

    action="$(repo_action "$state" "$sync")"
    if [ "$mode" = "--apply" ] && [ "$action" = "update" ]; then
        if git -C "$path" pull --rebase --recurse-submodules; then
            after="$(repo_head "$path")"
            action="updated"
            updated_paths+=("$path")
        else
            after="$(repo_head "$path")"
            action="failed"
            failed=$((failed + 1))
        fi
    elif [ "$mode" = "--apply" ] && [ "$action" = "current" ]; then
        after="$before"
    fi

    rows+=("$path|$state|$sync|$action|$before|$after|$validation")
}

validate_updated_repos() {
    local path validator index row

    for path in "${updated_paths[@]}"; do
        if validator="$(smu_validator_for_repo "$script_dir/repo-validators.txt" "$path")"; then
            if smu_run_validator "$repo_root" "$path" "$validator"; then
                validation="passed"
            else
                validation="failed"
                failed=$((failed + 1))
            fi
        else
            validation="missing"
            failed=$((failed + 1))
        fi

        for index in "${!rows[@]}"; do
            IFS='|' read -r row_path state sync action before after _ <<< "${rows[$index]}"
            if [ "$row_path" = "$path" ]; then
                rows[$index]="$row_path|$state|$sync|$action|$before|$after|$validation"
            fi
        done
    done
}

print_text() {
    local row path state sync action before after validation

    printf "path\tstate\tsync\taction\tbefore\tafter\tvalidation\n"
    for row in "${rows[@]}"; do
        IFS='|' read -r path state sync action before after validation <<< "$row"
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
            "$path" "$state" "$sync" "$action" "$before" "$after" "$validation"
    done
}

print_json() {
    local row path state sync action before after validation comma=""

    printf '{"repositories":['
    for row in "${rows[@]}"; do
        IFS='|' read -r path state sync action before after validation <<< "$row"
        printf '%s{"path":"%s","state":"%s","sync":"%s","action":"%s","before":"%s","after":"%s","validation":"%s"}' \
            "$comma" "$(smu_json_escape "$path")" "$(smu_json_escape "$state")" \
            "$(smu_json_escape "$sync")" "$(smu_json_escape "$action")" \
            "$(smu_json_escape "$before")" "$(smu_json_escape "$after")" \
            "$(smu_json_escape "$validation")"
        comma=","
    done
    printf '],"failed":%s}\n' "$failed"
}

cd "$repo_root"
smu_validate_repos_manifest "$repos_file"

rows=()
updated_paths=()
failed=0

if [ "$format" = "--text" ]; then
    printf "\nUpdating set-me-up repositories...\n\n"
fi

smu_each_repo "$repos_file" inspect_repo

if [ "$mode" = "--apply" ] && [ "$validate_after" -eq 1 ]; then
    validate_updated_repos
    scripts/validate.sh --coverage >/dev/null || failed=$((failed + 1))
fi

if [ "$format" = "--json" ]; then
    print_json
else
    print_text
fi

[ "$failed" -eq 0 ]
