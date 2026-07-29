#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
routes_file="$repo_root/scripts/agent-routes.txt"
required_keywords=(theme prompt agent installer module ci)

cd "$repo_root"

missing=0
printf "keyword\\tstate\\n"
for keyword in "${required_keywords[@]}"; do
    if awk -F '|' -v keyword="$keyword" '
        $1 !~ /^#/ && NF >= 4 {
            haystack = tolower($1 " " $3 " " $4)
            if (haystack ~ "(^|,| )" keyword "($|,| )") {
                found = 1
            }
        }
        END { exit found ? 0 : 1 }
    ' "$routes_file"; then
        printf "%s\\tpresent\\n" "$keyword"
    else
        missing=$((missing + 1))
        printf "%s\\tmissing\\n" "$keyword"
    fi
done

[ "$missing" -eq 0 ]
