#!/usr/bin/env bash

# Report utilities version pins for managed repositories.
#
# A consumer repo may declare the minimum dotbrains/utilities release it
# expects in a .utilities-version file at its root (plain semver, e.g.
# "1.2.0"). This report compares each pin against the version of the
# local utilities checkout (UTILITIES_VERSION in utilities/import.sh)
# and flags repos whose pin is newer than the checkout.
#
# States:
#   ok        pin satisfied by the utilities checkout
#   stale     pin is newer than the utilities checkout (update utilities)
#   unpinned  repo is checked out but declares no pin
#   missing   repo is not checked out
#
# Exits non-zero when any pin is stale.

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

utilities_version="unknown"
if [ -f "utilities/import.sh" ]; then
    utilities_version="$(sed -n 's/^export UTILITIES_VERSION="\([0-9.]*\)"$/\1/p' utilities/import.sh)"
    [ -n "$utilities_version" ] || utilities_version="unknown"
fi

stale=0
printf "path\tpin\tutilities\tstate\n"
while IFS='|' read -r repo path category _ || [ -n "$repo" ]; do
    [[ "$repo" =~ ^[[:space:]]*# || -z "$repo" ]] && continue
    : "$repo" "$category"

    if [ ! -d "$path/.git" ]; then
        printf "%s\t-\t%s\tmissing\n" "$path" "$utilities_version"
        continue
    fi

    if [ ! -f "$path/.utilities-version" ]; then
        printf "%s\t-\t%s\tunpinned\n" "$path" "$utilities_version"
        continue
    fi

    pin="$(tr -d '[:space:]' <"$path/.utilities-version")"
    state="ok"

    if [ "$utilities_version" = "unknown" ]; then
        state="stale"
    else
        # The pin is satisfied when it sorts at or below the checkout
        # version (version sort).
        highest="$(printf '%s\n%s\n' "$pin" "$utilities_version" | sort -V | tail -1)"
        if [ "$highest" != "$utilities_version" ] && [ "$pin" != "$utilities_version" ]; then
            state="stale"
        fi
    fi

    [ "$state" = "stale" ] && stale=1
    printf "%s\t%s\t%s\t%s\n" "$path" "$pin" "$utilities_version" "$state"
done <"$repos_file"

exit "$stale"
