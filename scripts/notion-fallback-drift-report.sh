#!/usr/bin/env bash

# Report Notion fallback command drift across the claude, codex, and
# opencode managed repos.
#
# Each of those repos hand-maintains its own copy of the `ntn` (official
# Notion CLI) fallback invocation, since the command body differs per tool
# (claude/opencode use a slash command, codex uses a sandbox prefix_rule).
# This has no shared source of truth to assemble from, so drift can only be
# caught by comparing the invocation shape across repos.
#
# For each of the two operations (search, page) this checks that every
# repo's fallback file still invokes the same `ntn` subcommand with the
# same flags, ignoring argument values (repos differ on placeholder vs.
# example args by design).
#
# States:
#   ok       all repos use the expected ntn subcommand and flags
#   drift    at least one repo is missing an expected fragment
#   missing  repo is not checked out, or its fallback file doesn't exist
#
# Exits non-zero when any operation has drift.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repos_file="$repo_root/scripts/repos.txt"

source "$repo_root/scripts/lib/repos.sh"

usage() {
    printf "Usage: %s [--tsv]\n" "$0" >&2
}

case "${1:---tsv}" in
    --tsv) ;;
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

path_for_repo() {
    local wanted="$1" repo path category
    while IFS='|' read -r repo path category _ || [ -n "$repo" ]; do
        [[ "$repo" =~ ^[[:space:]]*# || -z "$repo" ]] && continue
        : "$category"
        if [ "$repo" = "$wanted" ]; then
            printf "%s" "$path"
            return 0
        fi
    done <"$repos_file"
    return 1
}

claude_path="$(path_for_repo claude)"
codex_path="$(path_for_repo codex)"
opencode_path="$(path_for_repo opencode)"

# tool|file (relative to the tool's checkout)
search_files="claude|$claude_path/commands/notion-search.md
codex|$codex_path/rules/default.rules
opencode|$opencode_path/command/notion-search.md"

page_files="claude|$claude_path/commands/notion-page.md
codex|$codex_path/rules/default.rules
opencode|$opencode_path/command/notion-page.md"

drift=0

check_operation() {
    local operation="$1" files="$2"
    shift 2
    local fragments=("$@")
    local tool file frag missing_frag state

    while IFS='|' read -r tool file || [ -n "$tool" ]; do
        [ -n "$tool" ] || continue

        if [ ! -f "$file" ]; then
            printf "%s\t%s\t-\tmissing\n" "$operation" "$tool"
            continue
        fi

        state="ok"
        missing_frag=""
        for frag in "${fragments[@]}"; do
            if ! grep -qF -- "$frag" "$file"; then
                state="drift"
                missing_frag="$frag"
                break
            fi
        done

        [ "$state" = "drift" ] && drift=1
        printf "%s\t%s\t%s\t%s\n" "$operation" "$tool" "${missing_frag:--}" "$state"
    done <<<"$files"
}

printf "operation\ttool\tmissing_fragment\tstate\n"
check_operation "search" "$search_files" "ntn" "api v1/search" "query=" "page_size=="
check_operation "page" "$page_files" "ntn" "pages get" "--json"

exit "$drift"
