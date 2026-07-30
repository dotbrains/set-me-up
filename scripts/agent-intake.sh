#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repos_file="$repo_root/scripts/repos.txt"
routes_file="$repo_root/scripts/agent-routes.txt"
validators_file="$repo_root/scripts/repo-validators.txt"
intents_file="$repo_root/scripts/agent-intents.txt"
format="--tsv"
explain=0
strict=0
query=""

source "$repo_root/scripts/lib/repos.sh"
source "$repo_root/scripts/lib/routes.sh"
source "$repo_root/scripts/lib/repo-state.sh"
source "$repo_root/scripts/lib/validators.sh"
source "$repo_root/scripts/lib/json.sh"
source "$repo_root/scripts/lib/manifest-index.sh"
source "$repo_root/scripts/lib/repo-health.sh"
source "$repo_root/scripts/lib/agent-intake.sh"
source "$repo_root/scripts/lib/agent-intake-render.sh"

usage() {
    printf "Usage: %s [--tsv|--json|--plan] [--explain] [--strict] <query>\n" "$0" >&2
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --tsv | --json | --plan)
            format="$1"
            ;;
        --explain)
            explain=1
            ;;
        --strict)
            strict=1
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
            [ -z "$query" ] || {
                usage
                exit 2
            }
            query="$1"
            ;;
    esac
    shift
done

[ -n "$query" ] || {
    usage
    exit 2
}

cd "$repo_root"
run_agent_intake
