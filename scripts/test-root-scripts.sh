#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_root="$(mktemp -d)"

cleanup() {
    rm -rf "$tmp_root"
}
trap cleanup EXIT

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

    mkdir -p "$target/scripts/lib"
    cp "$repo_root/README.md" "$target/"
    cp "$repo_root/.gitignore" "$target/"
    cp "$repo_root/scripts/SCRIPTS.md" "$target/scripts/"
    cp "$repo_root/scripts/setup.sh" "$target/scripts/"
    cp "$repo_root/scripts/update.sh" "$target/scripts/"
    cp "$repo_root/scripts/route.sh" "$target/scripts/"
    cp "$repo_root/scripts/doctor.sh" "$target/scripts/"
    cp "$repo_root/scripts/validate.sh" "$target/scripts/"
    cp "$repo_root/scripts/validate-repos.sh" "$target/scripts/"
    cp "$repo_root/scripts/test-root-scripts.sh" "$target/scripts/"
    cp "$repo_root/scripts/repos.txt" "$target/scripts/"
    cp "$repo_root/scripts/agent-routes.txt" "$target/scripts/"
    cp "$repo_root/scripts/repo-validators.txt" "$target/scripts/"
    cp "$repo_root/scripts/lib/repos.sh" "$target/scripts/lib/"
    cp "$repo_root/scripts/lib/repo-state.sh" "$target/scripts/lib/"
    cp "$repo_root/scripts/lib/validators.sh" "$target/scripts/lib/"
}

test_piped_setup_resolves_cloned_manifest() {
    local work_dir="$tmp_root/piped"
    local bin_dir="$work_dir/bin"
    local output="$work_dir/output.log"

    mkdir -p "$work_dir"
    install_mock_git "$bin_dir"

    (
        cd "$work_dir"
        SMU_TEST_REPO_ROOT="$repo_root" PATH="$bin_dir:$PATH" \
            bash < "$repo_root/scripts/setup.sh" > "$output"
    )

    assert_file "$work_dir/set-me-up/scripts/repos.txt"
    assert_contains "$output" "Cloning set-me-up repository"
}

test_piped_setup_ignores_unrelated_git_repo() {
    local work_dir="$tmp_root/unrelated/work"
    local bin_dir="$tmp_root/unrelated/bin"
    local output="$tmp_root/unrelated/output.log"

    mkdir -p "$work_dir/.git"
    touch "$work_dir/README.md"
    install_mock_git "$bin_dir"

    (
        cd "$work_dir"
        SMU_TEST_REPO_ROOT="$repo_root" PATH="$bin_dir:$PATH" \
            bash < "$repo_root/scripts/setup.sh" > "$output"
    )

    assert_file "$work_dir/set-me-up/scripts/repos.txt"
    assert_contains "$output" "Cloning set-me-up repository"
}

test_setup_propagates_clone_failures() {
    local work_dir="$tmp_root/clone-failure/set-me-up"
    local bin_dir="$tmp_root/clone-failure/bin"
    local output="$tmp_root/clone-failure/output.log"

    copy_root_scripts "$work_dir"
    mkdir -p "$work_dir/.git"
    printf "fail-repo|fail|top-level\\n" > "$work_dir/scripts/repos.txt"
    install_mock_git "$bin_dir"

    if (
        cd "$work_dir"
        SMU_TEST_REPO_ROOT="$repo_root" PATH="$bin_dir:$PATH" \
            bash scripts/setup.sh > "$output" 2>&1
    ); then
        fail "setup.sh succeeded after clone failure"
    fi

    assert_contains "$output" "clone failed"
}

test_update_skips_dirty_and_reports_failures() {
    local work_dir="$tmp_root/update"
    local bin_dir="$work_dir/bin"
    local output="$work_dir/output.log"

    copy_root_scripts "$work_dir"
    mkdir -p "$work_dir/clean/.git" "$work_dir/dirty/.git" "$work_dir/fail/.git"
    touch "$work_dir/dirty/.dirty" "$work_dir/fail/.fail-pull"
    cat > "$work_dir/scripts/repos.txt" <<'EOF'
clean|clean|top-level
dirty|dirty|top-level
fail|fail|top-level
missing|missing|top-level
EOF
    install_mock_git "$bin_dir"

    if (
        cd "$work_dir"
        SMU_TEST_REPO_ROOT="$repo_root" PATH="$bin_dir:$PATH" \
            bash scripts/update.sh > "$output" 2>&1
    ); then
        fail "update.sh succeeded after pull failure"
    fi

    assert_contains "$output" "Updating clean"
    assert_contains "$output" "dirty has uncommitted changes, skipping"
    assert_contains "$output" "Error updating fail"
    assert_contains "$output" "missing doesn't exist, skipping"
}

test_manifest_validation_rejects_duplicates() {
    local work_dir="$tmp_root/manifest-duplicates"
    local output="$work_dir/output.log"

    copy_root_scripts "$work_dir"
    mkdir -p "$work_dir/.git"
    cat > "$work_dir/scripts/repos.txt" <<'EOF'
one|same|top-level
two|same|top-level
EOF

    if (
        cd "$work_dir"
        bash scripts/validate.sh --structure > "$output" 2>&1
    ); then
        fail "validate.sh accepted duplicate manifest paths"
    fi

    assert_contains "$output" "Duplicate manifest path"
}

test_validate_repos_rejects_invalid_categories() {
    local work_dir="$tmp_root/manifest-categories"
    local output="$work_dir/output.log"

    copy_root_scripts "$work_dir"
    mkdir -p "$work_dir/.git"
    printf "bad|bad|invalid\\n" > "$work_dir/scripts/repos.txt"

    if (
        cd "$work_dir"
        bash scripts/validate-repos.sh --list > "$output" 2>&1
    ); then
        fail "validate-repos.sh accepted invalid manifest category"
    fi

    assert_contains "$output" "Invalid manifest category"
}

test_repo_state_classifies_worktrees() {
    local work_dir="$tmp_root/repo-state"
    local bin_dir="$work_dir/bin"

    copy_root_scripts "$work_dir"
    mkdir -p "$work_dir/clean/.git" "$work_dir/dirty/.git" "$work_dir/not-git"
    touch "$work_dir/dirty/.dirty"
    install_mock_git "$bin_dir"

    (
        cd "$work_dir"
        PATH="$bin_dir:$PATH"
        source scripts/lib/repo-state.sh
        [ "$(smu_repo_state missing)" = "missing" ] || \
            fail "missing repo state was not detected"
        [ "$(smu_repo_state not-git)" = "not-git" ] || \
            fail "not-git repo state was not detected"
        [ "$(smu_repo_state dirty)" = "dirty" ] || \
            fail "dirty repo state was not detected"
    )
}

test_route_map_rejects_unknown_paths() {
    local work_dir="$tmp_root/route-map"
    local output="$work_dir/output.log"

    copy_root_scripts "$work_dir"
    mkdir -p "$work_dir/.git"
    printf "bad|missing/path|Broken route|missing\\n" \
        > "$work_dir/scripts/agent-routes.txt"

    if (
        cd "$work_dir"
        bash scripts/validate.sh --structure > "$output" 2>&1
    ); then
        fail "validate.sh accepted route path outside manifest"
    fi

    assert_contains "$output" "is not in scripts/repos.txt"
}

test_repo_validators_reject_unknown_paths() {
    local work_dir="$tmp_root/repo-validators"
    local output="$work_dir/output.log"

    copy_root_scripts "$work_dir"
    mkdir -p "$work_dir/.git"
    printf "missing/path|scripts/validate.sh --all\\n" \
        > "$work_dir/scripts/repo-validators.txt"

    if (
        cd "$work_dir"
        bash scripts/validate.sh --structure > "$output" 2>&1
    ); then
        fail "validate.sh accepted validator path outside manifest"
    fi

    assert_contains "$output" "Validator path"
}

test_validate_repos_lists_declared_validator() {
    local work_dir="$tmp_root/declared-validator"
    local bin_dir="$work_dir/bin"
    local output="$work_dir/output.log"

    copy_root_scripts "$work_dir"
    mkdir -p "$work_dir/.git" "$work_dir/clean/.git"
    printf "clean|clean|top-level\\n" > "$work_dir/scripts/repos.txt"
    printf "clean|custom validate\\n" > "$work_dir/scripts/repo-validators.txt"
    install_mock_git "$bin_dir"

    (
        cd "$work_dir"
        PATH="$bin_dir:$PATH" bash scripts/validate-repos.sh --list > "$output"
    )

    assert_contains "$output" "clean: custom validate"
}

test_route_lookup_finds_keyword_matches() {
    local work_dir="$tmp_root/route-lookup"
    local output="$work_dir/output.log"

    copy_root_scripts "$work_dir"

    (
        cd "$work_dir"
        bash scripts/route.sh theme > "$output"
    )

    assert_contains "$output" "modules-colorschemes"
    assert_contains "$output" "modules/colorschemes"
}

test_route_lookup_fails_without_matches() {
    local work_dir="$tmp_root/route-miss"
    local output="$work_dir/output.log"

    copy_root_scripts "$work_dir"

    if (
        cd "$work_dir"
        bash scripts/route.sh no-such-route > "$output" 2>&1
    ); then
        fail "route.sh succeeded without a matching route"
    fi

    assert_contains "$output" "No routes matched"
}

test_route_lookup_covers_core_concepts() {
    local work_dir="$tmp_root/route-coverage"
    local output="$work_dir/output.log"

    copy_root_scripts "$work_dir"

    (
        cd "$work_dir"
        bash scripts/route.sh smu > "$output"
        assert_contains "$output" "installer"

        bash scripts/route.sh prompt > "$output"
        assert_contains "$output" "home/.config/bash"

        bash scripts/route.sh claude > "$output"
        assert_contains "$output" "home/claude"

        bash scripts/route.sh codex > "$output"
        assert_contains "$output" "home/codex"

        bash scripts/route.sh macos > "$output"
        assert_contains "$output" "modules/macos"

        bash scripts/route.sh debian > "$output"
        assert_contains "$output" "modules/debian"

        bash scripts/route.sh nvim > "$output"
        assert_contains "$output" "home/.config/nvim"
    )
}

test_doctor_reports_repo_health_summary() {
    local work_dir="$tmp_root/doctor-summary"
    local bin_dir="$work_dir/bin"
    local output="$work_dir/output.log"

    copy_root_scripts "$work_dir"
    mkdir -p "$work_dir/.git" "$work_dir/clean/.git" "$work_dir/dirty/.git"
    touch "$work_dir/dirty/.dirty"
    cat > "$work_dir/scripts/repos.txt" <<'EOF'
clean|clean|top-level
dirty|dirty|top-level
missing|missing|top-level
EOF
    cat > "$work_dir/scripts/agent-routes.txt" <<'EOF'
clean|clean|Clean repo|clean
dirty|dirty|Dirty repo|dirty
EOF
    printf "clean|custom validate\\n" > "$work_dir/scripts/repo-validators.txt"
    install_mock_git "$bin_dir"

    (
        cd "$work_dir"
        PATH="$bin_dir:$PATH" bash scripts/doctor.sh > "$output"
    )

    assert_contains "$output" "set-me-up doctor"
    assert_contains "$output" "repos: total=3"
    assert_contains "$output" "dirty=1"
    assert_contains "$output" "missing=1"
    assert_contains "$output" "validators: present=1 missing=2"
    assert_contains "$output" "routes: present=2 missing=1"
}

test_doctor_verbose_reports_route_drift() {
    local work_dir="$tmp_root/doctor-route-drift"
    local bin_dir="$work_dir/bin"
    local output="$work_dir/output.log"

    copy_root_scripts "$work_dir"
    mkdir -p "$work_dir/.git" "$work_dir/clean/.git"
    printf "clean|clean|top-level\\n" > "$work_dir/scripts/repos.txt"
    printf "bad|missing|Broken route|missing\\n" \
        > "$work_dir/scripts/agent-routes.txt"
    : > "$work_dir/scripts/repo-validators.txt"
    install_mock_git "$bin_dir"

    (
        cd "$work_dir"
        PATH="$bin_dir:$PATH" bash scripts/doctor.sh --verbose > "$output"
    )

    assert_contains "$output" "route-drift"
    assert_contains "$output" "routes: present=0 missing=1 drift=1"
}

test_piped_setup_resolves_cloned_manifest
test_piped_setup_ignores_unrelated_git_repo
test_setup_propagates_clone_failures
test_update_skips_dirty_and_reports_failures
test_manifest_validation_rejects_duplicates
test_validate_repos_rejects_invalid_categories
test_repo_state_classifies_worktrees
test_route_map_rejects_unknown_paths
test_repo_validators_reject_unknown_paths
test_validate_repos_lists_declared_validator
test_route_lookup_finds_keyword_matches
test_route_lookup_fails_without_matches
test_route_lookup_covers_core_concepts
test_doctor_reports_repo_health_summary
test_doctor_verbose_reports_route_drift

printf "Root script tests passed.\\n"
