#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
source "$repo_root/scripts/lib/repos.sh"

mode="${1:---all}"

bash_checks() {
    bash -n scripts/setup.sh scripts/update.sh scripts/validate.sh \
        scripts/test-root-scripts.sh scripts/validate-repos.sh \
        scripts/lib/repos.sh
}

shell_checks() {
    bash_checks
    shellcheck --severity=warning scripts/setup.sh scripts/update.sh \
        scripts/validate.sh scripts/test-root-scripts.sh scripts/validate-repos.sh \
        scripts/lib/repos.sh
}

markdown_checks() {
    npx markdownlint-cli2 "**/*.md" "#blueprint" "#docs" "#home" \
        "#installer" "#modules" "#shared" "#tests" "#utilities"
}

manifest_checks() {
    smu_validate_repos_manifest scripts/repos.txt
}

structure_checks() {
    local required_files=(
        README.md
        scripts/SCRIPTS.md
        scripts/setup.sh
        scripts/update.sh
        scripts/repos.txt
        scripts/lib/repos.sh
        scripts/test-root-scripts.sh
        scripts/validate-repos.sh
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
    [ -x scripts/test-root-scripts.sh ] || {
        printf "scripts/test-root-scripts.sh must be executable\\n" >&2
        exit 1
    }
    [ -x scripts/validate-repos.sh ] || {
        printf "scripts/validate-repos.sh must be executable\\n" >&2
        exit 1
    }

    for entry in "${required_ignores[@]}"; do
        grep -Fxq "$entry" .gitignore || {
            printf "Missing .gitignore entry: %s\\n" "$entry" >&2
            exit 1
        }
    done

    manifest_checks

    grep -q "Quick Setup" README.md
    grep -q "Directory Structure" README.md
    grep -q "Repositories" README.md
}

test_checks() {
    scripts/test-root-scripts.sh
}

case "$mode" in
    --bash)
        bash_checks
        ;;
    --shell)
        shell_checks
        ;;
    --markdown)
        markdown_checks
        ;;
    --structure)
        structure_checks
        ;;
    --test)
        test_checks
        ;;
    --all)
        shell_checks
        markdown_checks
        structure_checks
        test_checks
        ;;
    *)
        printf "Usage: %s [--all|--bash|--shell|--markdown|--structure|--test]\\n" "$0" >&2
        exit 2
        ;;
esac
