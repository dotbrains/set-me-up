#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

mode="${1:---all}"

bash_checks() {
    bash -n scripts/setup.sh scripts/update.sh scripts/validate.sh \
        scripts/test-root-scripts.sh scripts/validate-repos.sh
}

shell_checks() {
    bash_checks
    shellcheck --severity=warning scripts/setup.sh scripts/update.sh \
        scripts/validate.sh scripts/test-root-scripts.sh scripts/validate-repos.sh
}

markdown_checks() {
    npx markdownlint-cli2 "**/*.md" "#blueprint" "#docs" "#home" \
        "#installer" "#modules" "#shared" "#tests" "#utilities"
}

manifest_checks() {
    local line_number=0
    local repo
    local path
    local category
    local extra
    local seen_repos=" "
    local seen_paths=" "

    while IFS='|' read -r repo path category extra || [ -n "$repo" ]; do
        line_number=$((line_number + 1))

        [[ "$repo" =~ ^[[:space:]]*# || -z "$repo" ]] && continue

        if [ -n "${extra:-}" ] || [ -z "$path" ] || [ -z "$category" ]; then
            printf "Invalid manifest line %s: expected repo|path|category\\n" \
                "$line_number" >&2
            exit 1
        fi

        case "$category" in
            top-level|shared|module|config)
                ;;
            *)
                printf "Invalid manifest category on line %s: %s\\n" \
                    "$line_number" "$category" >&2
                exit 1
                ;;
        esac

        if [[ "$seen_repos" == *" $repo "* ]]; then
            printf "Duplicate manifest repo on line %s: %s\\n" \
                "$line_number" "$repo" >&2
            exit 1
        fi
        if [[ "$seen_paths" == *" $path "* ]]; then
            printf "Duplicate manifest path on line %s: %s\\n" \
                "$line_number" "$path" >&2
            exit 1
        fi

        seen_repos+="$repo "
        seen_paths+="$path "
    done < scripts/repos.txt
}

structure_checks() {
    local required_files=(
        README.md
        scripts/SCRIPTS.md
        scripts/setup.sh
        scripts/update.sh
        scripts/repos.txt
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
