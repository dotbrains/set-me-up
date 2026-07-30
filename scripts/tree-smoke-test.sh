#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_root="$(mktemp -d)"

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

cleanup() {
    rm -rf "$tmp_root"
}
trap cleanup EXIT

cd "$repo_root"

mkdir -p "$tmp_root/set-me-up/.github" "$tmp_root/set-me-up/scripts/lib"
cp README.md REPOSITORIES.md .gitignore "$tmp_root/set-me-up/"
cp -R .github/workflows "$tmp_root/set-me-up/.github/"
cp scripts/*.sh scripts/*.txt scripts/*.md "$tmp_root/set-me-up/scripts/"
cp scripts/lib/*.sh "$tmp_root/set-me-up/scripts/lib/"
cp -R scripts/tests "$tmp_root/set-me-up/scripts/"
cp -R scripts/schemas "$tmp_root/set-me-up/scripts/"
cp -R scripts/docs "$tmp_root/set-me-up/scripts/"

(
    cd "$tmp_root/set-me-up"
    bash scripts/validate.sh --bash
    bash scripts/validate.sh --structure
    bash scripts/health-report.sh --json >/dev/null
    bash scripts/doctor.sh --json >/dev/null
    bash scripts/freshness-report.sh --json >/dev/null
    bash scripts/change-report.sh --json >/dev/null
    bash scripts/capabilities.sh --json >/dev/null
    bash scripts/sync-report.sh --json >/dev/null
    bash scripts/validate-json-schemas.sh >/dev/null
    bash scripts/capabilities.sh >/dev/null
    bash scripts/change-report.sh --since=1.day >/dev/null
)

printf "Tree smoke test passed.\n"
