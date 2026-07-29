#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_file="$repo_root/scripts/docs/COMMANDS.md"
mode="${1:---write}"

usage() {
    printf "Usage: %s [--write|--check]\n" "$0" >&2
}

case "$mode" in
    --write | --check)
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
mkdir -p scripts/docs
tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

{
    printf "# Command Reference\n\n"
    printf "<!-- markdownlint-disable MD012 MD013 -->\n\n"
    printf "Generated from script usage output. Do not edit by hand.\n\n"
    printf "Regenerate with:\n\n"
    printf '```bash\n'
    printf "scripts/generate-command-docs.sh\n"
    printf '```\n\n'
    while IFS= read -r script; do
        usage_line="$(grep -m 1 'printf "Usage:' "$script" || true)"
        printf "## %s\n\n" "$script"
        printf '```text\n'
        if [ -n "$usage_line" ]; then
            printf "%s\n" "$usage_line" |
                sed -E 's/.*printf "([^"]+)".*/\1/' |
                sed "s|%s|$script|" |
                sed 's/\\n//g; s/\\$//'
        else
            printf "No usage output declared.\n"
        fi
        printf '```\n\n'
    done < <(find scripts -maxdepth 1 -type f -name '*.sh' | sort)
} > "$tmp_file"

if [ "$mode" = "--check" ]; then
    diff -u "$output_file" "$tmp_file"
else
    cp "$tmp_file" "$output_file"
fi
