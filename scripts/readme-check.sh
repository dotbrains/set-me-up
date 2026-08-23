#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repos_file="$repo_root/scripts/repos.txt"
readme_file="$repo_root/README.md"

usage() {
    printf "Usage: %s\n" "$0" >&2
}

case "${1:-}" in
    -h | --help)
        usage
        exit 0
        ;;
    "")
        ;;
    *)
        usage
        exit 2
        ;;
esac

cd "$repo_root"

# README.md's "## Repositories" section is hand-maintained prose, not
# generated -- unlike REPOSITORIES.md. This just checks that every repo
# in the manifest has a matching link somewhere in it, so a repo added
# via add-repo.sh (or by hand) without updating README can't slip by
# silently, the way set-me-up-omarchy-modules initially did.
missing=()
while IFS='|' read -r repo _path _category; do
    [[ "$repo" =~ ^#.*$ || -z "$repo" ]] && continue
    link="[$repo](https://github.com/smeltery/$repo)"
    grep -qF -- "$link" "$readme_file" || missing+=("$repo")
done < "$repos_file"

if [ "${#missing[@]}" -gt 0 ]; then
    printf "README.md is missing repository link(s) for:\n" >&2
    printf "  - %s\n" "${missing[@]}" >&2
    exit 1
fi

total="$(awk -F '|' '$1 !~ /^#/ && NF >= 3' "$repos_file" | wc -l | tr -d ' ')"
printf "README.md repository list is complete (%s repos).\n" "$total"
