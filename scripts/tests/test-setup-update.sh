#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=scripts/tests/test-helpers.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/test-helpers.sh"

: "$repo_root" "$tmp_root"


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


test_piped_setup_resolves_cloned_manifest
test_piped_setup_ignores_unrelated_git_repo
test_setup_propagates_clone_failures
test_update_skips_dirty_and_reports_failures
