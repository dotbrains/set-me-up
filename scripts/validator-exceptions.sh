#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repos_file="$repo_root/scripts/repos.txt"
validators_file="$repo_root/scripts/repo-validators.txt"

source "$repo_root/scripts/lib/repos.sh"
source "$repo_root/scripts/lib/validators.sh"

cd "$repo_root"
smu_validate_repos_manifest "$repos_file"

printf "path\\tstate\\tvalidator\\n"
while IFS='|' read -r repo path category _ || [ -n "$repo" ]; do
    [[ "$repo" =~ ^[[:space:]]*# || -z "$repo" ]] && continue
    : "$category"
    [ "$path" = "." ] && continue
    [ ! -x "$path/scripts/validate.sh" ] || continue

    if validator="$(smu_validator_for_repo "$validators_file" "$path")"; then
        printf "%s\\t%s\\t%s\\n" \
            "$path" "declared-or-inferred" "$(smu_validator_label "$validator")"
    else
        printf "%s\\t%s\\tnone\\n" "$path" "missing"
    fi
done < "$repos_file"
