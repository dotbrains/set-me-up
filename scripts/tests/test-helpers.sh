#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmp_root="${SMU_TEST_TMP_ROOT:-$(mktemp -d)}"

cleanup() {
    if [ -z "${SMU_TEST_KEEP_TMP:-}" ]; then
        rm -rf "$tmp_root"
    fi
}

if [ -z "${SMU_TEST_TMP_ROOT:-}" ]; then
    trap cleanup EXIT
fi

fail() {
    printf "FAIL: %s\\n" "$1" >&2
    exit 1
}

assert_file() {
    [ -f "$1" ] || fail "missing file: $1"
}

assert_contains() {
    local file="$1"
    local pattern="$2"

    grep -Fq "$pattern" "$file" || {
        printf "Expected pattern not found: %s\\n" "$pattern" >&2
        printf "%s\\n" "--- $file ---" >&2
        cat "$file" >&2
        exit 1
    }
}

install_mock_git() {
    local bin_dir="$1"

    mkdir -p "$bin_dir"
    cat > "$bin_dir/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ "${1:-}" = "-C" ]; then
    cd "$2"
    shift 2
fi

case "${1:-}" in
    rev-parse)
        [ -d .git ]
        ;;
    clone)
        dest="${@: -1}"
        repo_url="${*:1:$#-1}"
        case "$repo_url" in
            *fail-repo.git*)
                printf "clone failed for %s\\n" "$repo_url" >&2
                exit 42
                ;;
        esac
        mkdir -p "$dest/.git"
        if [ "$dest" = "set-me-up" ]; then
            cp "$SMU_TEST_REPO_ROOT/README.md" "$dest/"
            cp -R "$SMU_TEST_REPO_ROOT/scripts" "$dest/"
        fi
        ;;
    diff-index)
        [ ! -f .dirty ]
        ;;
    ls-files)
        [ -f .untracked ] && printf "untracked.txt\\n"
        ;;
    pull)
        if [ -f .fail-pull ]; then
            printf "pull failed\\n" >&2
            exit 43
        fi
        printf "Already up to date.\\n"
        ;;
    submodule)
        printf "Submodules up to date.\\n"
        ;;
    *)
        exit 0
        ;;
esac
EOF
    chmod +x "$bin_dir/git"
}

copy_root_scripts() {
    local target="$1"

    mkdir -p "$target/scripts/lib" "$target/scripts/schemas" "$target/scripts/docs"
    cp "$repo_root/README.md" "$target/"
    cp "$repo_root/REPOSITORIES.md" "$target/"
    cp "$repo_root/.gitignore" "$target/"
    cp "$repo_root/scripts/SCRIPTS.md" "$target/scripts/"
    cp "$repo_root/scripts/setup.sh" "$target/scripts/"
    cp "$repo_root/scripts/update.sh" "$target/scripts/"
    cp "$repo_root/scripts/route.sh" "$target/scripts/"
    cp "$repo_root/scripts/doctor.sh" "$target/scripts/"
    cp "$repo_root/scripts/sync-report.sh" "$target/scripts/"
    cp "$repo_root/scripts/check-repo-contract.sh" "$target/scripts/"
    cp "$repo_root/scripts/validator-exceptions.sh" "$target/scripts/"
    cp "$repo_root/scripts/capabilities.sh" "$target/scripts/"
    cp "$repo_root/scripts/ci-workflow-report.sh" "$target/scripts/"
    cp "$repo_root/scripts/generate-docs.sh" "$target/scripts/"
    cp "$repo_root/scripts/native-workflow-template.sh" "$target/scripts/"
    cp "$repo_root/scripts/health-report.sh" "$target/scripts/"
    cp "$repo_root/scripts/route-quality.sh" "$target/scripts/"
    cp "$repo_root/scripts/freshness-report.sh" "$target/scripts/"
    cp "$repo_root/scripts/new-repo-check.sh" "$target/scripts/"
    cp "$repo_root/scripts/add-repo.sh" "$target/scripts/"
    cp "$repo_root/scripts/change-report.sh" "$target/scripts/"
    cp "$repo_root/scripts/tree-smoke-test.sh" "$target/scripts/"
    cp "$repo_root/scripts/generate-command-docs.sh" "$target/scripts/"
    cp "$repo_root/scripts/validate.sh" "$target/scripts/"
    cp "$repo_root/scripts/validate-repos.sh" "$target/scripts/"
    cp "$repo_root/scripts/test-root-scripts.sh" "$target/scripts/"
    cp -R "$repo_root/scripts/tests" "$target/scripts/"
    cp "$repo_root/scripts/repos.txt" "$target/scripts/"
    cp "$repo_root/scripts/agent-routes.txt" "$target/scripts/"
    cp "$repo_root/scripts/repo-validators.txt" "$target/scripts/"
    cp "$repo_root/scripts/lib/repos.sh" "$target/scripts/lib/"
    cp "$repo_root/scripts/lib/repo-state.sh" "$target/scripts/lib/"
    cp "$repo_root/scripts/lib/routes.sh" "$target/scripts/lib/"
    cp "$repo_root/scripts/lib/validators.sh" "$target/scripts/lib/"
    cp "$repo_root/scripts/lib/json.sh" "$target/scripts/lib/"
    cp "$repo_root/scripts/schemas/"*.json "$target/scripts/schemas/"
    cp "$repo_root/scripts/docs/"*.md "$target/scripts/docs/"
}
