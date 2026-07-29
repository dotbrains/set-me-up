#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_root="$(mktemp -d)"

cleanup() {
    rm -rf "$tmp_root"
}
trap cleanup EXIT

cd "$repo_root"

mkdir -p "$tmp_root/set-me-up/scripts/lib"
cp README.md REPOSITORIES.md .gitignore "$tmp_root/set-me-up/"
cp scripts/*.sh scripts/*.txt scripts/SCRIPTS.md "$tmp_root/set-me-up/scripts/"
cp scripts/lib/*.sh "$tmp_root/set-me-up/scripts/lib/"
cp -R scripts/tests "$tmp_root/set-me-up/scripts/"
cp -R scripts/schemas "$tmp_root/set-me-up/scripts/"

(
    cd "$tmp_root/set-me-up"
    bash scripts/validate.sh --bash
    bash scripts/validate.sh --structure
    bash scripts/health-report.sh --json >/dev/null
    bash scripts/capabilities.sh >/dev/null
    bash scripts/change-report.sh --since=1.day >/dev/null
)

printf "Tree smoke test passed.\n"
