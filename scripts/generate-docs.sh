#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_file="$repo_root/REPOSITORIES.md"
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
tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

{
    printf "# Repository Index\n\n"
    printf "Generated from scripts manifests. Do not edit by hand.\n\n"
    printf "Regenerate with:\n\n"
    printf '```bash\n'
    printf "scripts/generate-docs.sh\n"
    printf '```\n\n'
    printf "## Capabilities\n\n"
    scripts/capabilities.sh --declared | awk -F '\t' '
    function print_command(command,    remaining, chunk, cut) {
        remaining = command
        while (length(remaining) > 68) {
            cut = 68
            while (cut > 1 && substr(remaining, cut, 1) != " ") {
                cut--
            }
            if (cut == 1) {
                cut = 68
            }
            chunk = substr(remaining, 1, cut)
            sub(/[[:space:]]+$/, "", chunk)
            printf "  %s \\\n", chunk
            remaining = substr(remaining, cut + 1)
            sub(/^[[:space:]]+/, "", remaining)
        }
        printf "  %s\n", remaining
    }
    NR > 1 {
        printf "### %s\n\n", $1
        printf "- URL: <https://github.com/dotbrains/%s>\n", $1
        printf "- Path: `%s`\n", $2
        printf "- Category: `%s`\n", $3
        printf "- Route: `%s`\n", $4
        printf "- Summary: %s\n", $5
        printf "- Keywords: `%s`\n", $6
        printf "- Validator:\n\n"
        printf "  ```bash\n"
        print_command($7)
        printf "  ```\n"
        if (NR < 29) {
            printf "\n"
        }
    }'
} > "$tmp_file"

if [ "$mode" = "--check" ]; then
    cmp -s "$output_file" "$tmp_file" || {
        printf "%s is out of date. Run scripts/generate-docs.sh.\n" \
            "$output_file" >&2
        exit 1
    }
else
    cp "$tmp_file" "$output_file"
fi
