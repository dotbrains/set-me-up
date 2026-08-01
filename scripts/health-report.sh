#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repos_file="$repo_root/scripts/repos.txt"
routes_file="$repo_root/scripts/agent-routes.txt"
validators_file="$repo_root/scripts/repo-validators.txt"
mode="${1:---json}"

source "$repo_root/scripts/lib/repos.sh"
source "$repo_root/scripts/lib/repo-state.sh"
source "$repo_root/scripts/lib/routes.sh"
source "$repo_root/scripts/lib/validators.sh"
source "$repo_root/scripts/lib/repo-health.sh"
source "$repo_root/scripts/lib/json.sh"

usage() {
    printf "Usage: %s [--json]\\n" "$0" >&2
}

case "$mode" in
    --json)
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

printf '{"repositories":['
comma=""
total_repos=0
synced_repos=0
clean_repos=0
print_repo() {
    local repo="$1"
    local path="$2"
    local category="$3"
    local state="$4"
    local sync="$5"
    local route_id="$6"
    local validator="$7"

    printf '%s{"repo":"%s","path":"%s","category":"%s","state":"%s","sync":"%s","route":"%s","validator":"%s"}' \
        "$comma" "$(smu_json_escape "$repo")" "$(smu_json_escape "$path")" \
        "$(smu_json_escape "$category")" "$(smu_json_escape "$state")" \
        "$(smu_json_escape "$sync")" "$(smu_json_escape "$route_id")" \
        "$(smu_json_escape "$validator")"
    comma=","
    total_repos=$((total_repos + 1))
    if [ "$sync" = "synced" ]; then
        synced_repos=$((synced_repos + 1))
    fi
    if [ "$state" = "clean" ]; then
        clean_repos=$((clean_repos + 1))
    fi
}

smu_each_repo_health "$repo_root" "$repos_file" "$routes_file" "$validators_file" print_repo
candidate_head="$(git -C "$repo_root/installer" ls-remote origin refs/heads/candidate 2>/dev/null | awk 'NR == 1 { print $1 }')"
installer_head="$(git -C "$repo_root/installer" rev-parse HEAD)"
workflow_count="$(find "$repo_root" -path "*/.github/workflows/*" -type f 2>/dev/null | wc -l | tr -d ' ')"
module_manifest_count="$(find "$repo_root/modules" -name module.toml -type f 2>/dev/null | wc -l | tr -d ' ')"
module_dir_count="$(find "$repo_root/modules" -mindepth 2 -maxdepth 4 -type f \( -name packages -o -name brewfile -o -name "*.sh" \) 2>/dev/null | \
    sed 's#/[^/]*$##' | sort -u | wc -l | tr -d ' ')"
[ -n "$candidate_head" ] || candidate_head="unknown"
candidate_fresh=false
[ "$candidate_head" = "$installer_head" ] && candidate_fresh=true
trust_percent=0
if [ "$module_dir_count" -gt 0 ]; then
    trust_percent=$((module_manifest_count * 100 / module_dir_count))
fi
printf '],"summary":{"total":%s,"clean":%s,"synced":%s},' "$total_repos" "$clean_repos" "$synced_repos"
printf '"release_readiness":{"installer":"%s","candidate":"%s","candidate_fresh":%s},' \
    "$(smu_json_escape "$installer_head")" "$(smu_json_escape "$candidate_head")" "$candidate_fresh"
printf '"ci":{"workflow_files":%s},' "$workflow_count"
printf '"trust":{"module_manifests":%s,"module_payload_dirs":%s,"coverage_percent":%s},' \
    "$module_manifest_count" "$module_dir_count" "$trust_percent"
printf '"conformance":{"local_proxy_ready":%s}' "$([ "$total_repos" -eq "$synced_repos" ] && printf true || printf false)"
printf '}\n'
