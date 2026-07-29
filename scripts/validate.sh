#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

mode="${1:---all}"

shell_checks() {
    bash -n scripts/setup.sh scripts/update.sh scripts/validate.sh
    shellcheck --severity=warning scripts/setup.sh scripts/update.sh scripts/validate.sh
}

markdown_checks() {
    npx markdownlint-cli2 "**/*.md" "#blueprint" "#docs" "#home" \
        "#installer" "#modules" "#shared" "#tests" "#utilities"
}

structure_checks() {
    local required_files=(
        README.md
        scripts/SCRIPTS.md
        scripts/setup.sh
        scripts/update.sh
        scripts/repos.txt
        .gitignore
    )
    local required_ignores=(
        blueprint/
        docs/
        home/
        installer/
        modules/
        shared/
        tests/
        utilities/
    )

    for file in "${required_files[@]}"; do
        [ -f "$file" ] || {
            printf "Missing required file: %s\\n" "$file" >&2
            exit 1
        }
    done

    [ -x scripts/setup.sh ] || {
        printf "scripts/setup.sh must be executable\\n" >&2
        exit 1
    }
    [ -x scripts/update.sh ] || {
        printf "scripts/update.sh must be executable\\n" >&2
        exit 1
    }

    for entry in "${required_ignores[@]}"; do
        grep -Fxq "$entry" .gitignore || {
            printf "Missing .gitignore entry: %s\\n" "$entry" >&2
            exit 1
        }
    done

    grep -Fq "set-me-up-tests|tests|top-level" scripts/repos.txt || {
        printf "Missing set-me-up-tests manifest entry\\n" >&2
        exit 1
    }

    grep -q "Quick Setup" README.md
    grep -q "Directory Structure" README.md
    grep -q "Repositories" README.md
}

case "$mode" in
    --shell)
        shell_checks
        ;;
    --markdown)
        markdown_checks
        ;;
    --structure)
        structure_checks
        ;;
    --all)
        shell_checks
        markdown_checks
        structure_checks
        ;;
    *)
        printf "Usage: %s [--all|--shell|--markdown|--structure]\\n" "$0" >&2
        exit 2
        ;;
esac
