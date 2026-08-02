#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repos_file="$repo_root/scripts/repos.txt"
routes_file="$repo_root/scripts/agent-routes.txt"
validators_file="$repo_root/scripts/repo-validators.txt"
output=""

source "$repo_root/scripts/lib/repos.sh"
source "$repo_root/scripts/lib/repo-state.sh"
source "$repo_root/scripts/lib/routes.sh"
source "$repo_root/scripts/lib/validators.sh"
source "$repo_root/scripts/lib/repo-health.sh"

usage() {
    printf "Usage: %s [--output PATH]\n" "$0" >&2
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --output)
            shift
            output="${1:-}"
            ;;
        --output=*)
            output="${1#*=}"
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

print_repo() {
    local repo="$1"
    local path="$2"
    local category="$3"
    local state="$4"
    local sync="$5"
    local route_id="$6"
    local validator="$7"

    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
        "$repo" "$path" "$category" "$state" "$sync" "$route_id" "$validator"
}

cd "$repo_root"
smu_validate_repos_manifest "$repos_file"

if [ -n "$output" ]; then
    {
        printf "repo\tpath\tcategory\tstate\tsync\troute\tvalidator\n"
        smu_each_repo_health "$repo_root" "$repos_file" "$routes_file" "$validators_file" print_repo
    } > "$output"
else
    printf "repo\tpath\tcategory\tstate\tsync\troute\tvalidator\n"
    smu_each_repo_health "$repo_root" "$repos_file" "$routes_file" "$validators_file" print_repo
fi
