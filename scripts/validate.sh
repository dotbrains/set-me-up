#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
source "$repo_root/scripts/lib/repos.sh"

mode="${1:---all}"

bash_checks() {
    bash -n scripts/setup.sh scripts/update.sh scripts/validate.sh \
        scripts/test-root-scripts.sh scripts/validate-repos.sh scripts/route.sh \
        scripts/lib/repos.sh scripts/lib/repo-state.sh
}

shell_checks() {
    bash_checks
    shellcheck --severity=warning scripts/setup.sh scripts/update.sh \
        scripts/validate.sh scripts/test-root-scripts.sh scripts/validate-repos.sh \
        scripts/route.sh scripts/lib/repos.sh scripts/lib/repo-state.sh
}

markdown_checks() {
    npx markdownlint-cli2 "**/*.md" "#blueprint" "#docs" "#home" \
        "#installer" "#modules" "#shared" "#tests" "#utilities"
}

manifest_checks() {
    smu_validate_repos_manifest scripts/repos.txt
}

manifest_has_path() {
    local wanted_path="$1"
    local repo
    local path
    local category

    [ "$wanted_path" = "." ] && return 0

    while IFS='|' read -r repo path category _ || [ -n "$repo" ]; do
        [[ "$repo" =~ ^[[:space:]]*# || -z "$repo" ]] && continue
        : "$category"
        [ "$path" = "$wanted_path" ] && return 0
    done < scripts/repos.txt

    return 1
}

route_map_checks() {
    local line_number=0
    local route_id
    local path
    local summary
    local keywords
    local extra
    local seen_routes=" "

    while IFS='|' read -r route_id path summary keywords extra || \
        [ -n "$route_id" ]; do
        line_number=$((line_number + 1))

        [[ "$route_id" =~ ^[[:space:]]*# || -z "$route_id" ]] && continue

        if [ -n "${extra:-}" ] || [ -z "$path" ] || [ -z "$summary" ] || \
            [ -z "$keywords" ]; then
            printf "Invalid route line %s: expected route_id|local_path|summary|keywords\\n" \
                "$line_number" >&2
            exit 1
        fi

        if [[ ! "$route_id" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
            printf "Invalid route id on line %s: %s\\n" \
                "$line_number" "$route_id" >&2
            exit 1
        fi

        if [[ "$seen_routes" == *" $route_id "* ]]; then
            printf "Duplicate route id on line %s: %s\\n" \
                "$line_number" "$route_id" >&2
            exit 1
        fi

        if ! manifest_has_path "$path"; then
            printf "Route path on line %s is not in scripts/repos.txt: %s\\n" \
                "$line_number" "$path" >&2
            exit 1
        fi

        seen_routes+="$route_id "
    done < scripts/agent-routes.txt
}

repo_validator_checks() {
    local line_number=0
    local path
    local command
    local extra
    local seen_paths=" "

    while IFS='|' read -r path command extra || [ -n "$path" ]; do
        line_number=$((line_number + 1))

        [[ "$path" =~ ^[[:space:]]*# || -z "$path" ]] && continue

        if [ -n "${extra:-}" ] || [ -z "$command" ]; then
            printf "Invalid validator line %s: expected local_path|command\\n" \
                "$line_number" >&2
            exit 1
        fi

        if [[ "$seen_paths" == *" $path "* ]]; then
            printf "Duplicate validator path on line %s: %s\\n" \
                "$line_number" "$path" >&2
            exit 1
        fi

        if ! manifest_has_path "$path"; then
            printf "Validator path on line %s is not in scripts/repos.txt: %s\\n" \
                "$line_number" "$path" >&2
            exit 1
        fi

        seen_paths+="$path "
    done < scripts/repo-validators.txt
}

structure_checks() {
    local required_files=(
        README.md
        scripts/SCRIPTS.md
        scripts/setup.sh
        scripts/update.sh
        scripts/route.sh
        scripts/repos.txt
        scripts/agent-routes.txt
        scripts/repo-validators.txt
        scripts/lib/repos.sh
        scripts/lib/repo-state.sh
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
    [ -x scripts/route.sh ] || {
        printf "scripts/route.sh must be executable\\n" >&2
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
    route_map_checks
    repo_validator_checks

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
