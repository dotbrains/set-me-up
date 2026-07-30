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

test_update_plans_skips_and_current_repos() {
    local work_dir="$tmp_root/update"
    local bin_dir="$work_dir/bin"
    local output="$work_dir/output.log"

    copy_root_scripts "$work_dir"
    mkdir -p "$work_dir/clean/.git" "$work_dir/dirty/.git"
    touch "$work_dir/dirty/.dirty"
    cat > "$work_dir/scripts/repos.txt" <<'EOF'
clean|clean|top-level
dirty|dirty|top-level
missing|missing|top-level
EOF
    install_mock_git "$bin_dir"

    (
        cd "$work_dir"
        SMU_TEST_REPO_ROOT="$repo_root" PATH="$bin_dir:$PATH" \
            bash scripts/update.sh --plan > "$output"
    )

    assert_contains "$output" "path"
    assert_contains "$output" "clean"
    assert_contains "$output" "current"
    assert_contains "$output" "skip-dirty"
    assert_contains "$output" "skip-missing"
}

test_update_outputs_json_plan() {
    local work_dir="$tmp_root/update-json"
    local bin_dir="$work_dir/bin"
    local output="$work_dir/output.json"

    copy_root_scripts "$work_dir"
    mkdir -p "$work_dir/clean/.git"
    printf "clean|clean|top-level\\n" > "$work_dir/scripts/repos.txt"
    install_mock_git "$bin_dir"

    (
        cd "$work_dir"
        PATH="$bin_dir:$PATH" bash scripts/update.sh --plan --json > "$output"
    )

    assert_contains "$output" '"repositories":['
    assert_contains "$output" '"path":"clean"'
    assert_contains "$output" '"action":"current"'
}

test_update_json_plan_reports_repo_states() {
    local work_dir="$tmp_root/update-json-states"
    local bin_dir="$work_dir/bin"
    local output="$work_dir/output.json"

    copy_root_scripts "$work_dir"
    mkdir -p "$work_dir/clean/.git" "$work_dir/dirty/.git" "$work_dir/not-git"
    touch "$work_dir/dirty/.dirty"
    cat > "$work_dir/scripts/repos.txt" <<'EOF'
clean|clean|top-level
dirty|dirty|top-level
missing|missing|top-level
not-git|not-git|top-level
EOF
    install_mock_git "$bin_dir"

    (
        cd "$work_dir"
        PATH="$bin_dir:$PATH" bash scripts/update.sh --plan --json > "$output"
    )

    assert_contains "$output" '"path":"clean"'
    assert_contains "$output" '"action":"current"'
    assert_contains "$output" '"path":"dirty"'
    assert_contains "$output" '"action":"skip-dirty"'
    assert_contains "$output" '"path":"missing"'
    assert_contains "$output" '"action":"skip-missing"'
    assert_contains "$output" '"path":"not-git"'
    assert_contains "$output" '"action":"skip-not-git"'
}

test_update_json_plan_does_not_fetch() {
    local work_dir="$tmp_root/update-json-no-fetch"
    local bin_dir="$work_dir/bin"
    local output="$work_dir/output.json"
    local fetch_log="$work_dir/fetch.log"

    copy_root_scripts "$work_dir"
    mkdir -p "$work_dir/clean/.git"
    printf "clean|clean|top-level\\n" > "$work_dir/scripts/repos.txt"
    install_mock_git "$bin_dir"

    (
        cd "$work_dir"
        SMU_TEST_GIT_FETCH_LOG="$fetch_log" PATH="$bin_dir:$PATH" \
            bash scripts/update.sh --plan --json > "$output"
    )

    [ ! -f "$fetch_log" ] || fail "update plan mode unexpectedly fetched"
    assert_contains "$output" '"path":"clean"'
}


test_piped_setup_resolves_cloned_manifest
test_piped_setup_ignores_unrelated_git_repo
test_setup_propagates_clone_failures
test_update_plans_skips_and_current_repos
test_update_outputs_json_plan
test_update_json_plan_reports_repo_states
test_update_json_plan_does_not_fetch
