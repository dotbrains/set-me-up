#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=scripts/tests/test-helpers.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/test-helpers.sh"

: "$repo_root" "$tmp_root"


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

test_validate_repos_reports_missing_validators() {
    local work_dir="$tmp_root/missing-validators"
    local bin_dir="$work_dir/bin"
    local output="$work_dir/output.log"

    copy_root_scripts "$work_dir"
    mkdir -p "$work_dir/.git" "$work_dir/covered/.git" "$work_dir/uncovered/.git"
    printf "covered|covered|top-level\\nuncovered|uncovered|top-level\\n" \
        > "$work_dir/scripts/repos.txt"
    printf "covered|custom validate\\n" > "$work_dir/scripts/repo-validators.txt"
    install_mock_git "$bin_dir"

    (
        cd "$work_dir"
        PATH="$bin_dir:$PATH" bash scripts/validate-repos.sh --missing > "$output"
    )

    assert_contains "$output" "path"
    assert_contains "$output" "uncovered"
    assert_contains "$output" "Missing validators for 1 repo(s)."
}

test_add_repo_updates_manifests_and_docs() {
    local work_dir="$tmp_root/add-repo"
    local output="$work_dir/output.log"

    copy_root_scripts "$work_dir"
    mkdir -p "$work_dir/.git" "$work_dir/new/repo/scripts" \
        "$work_dir/new/repo/.github/workflows"
    touch "$work_dir/new/repo/README.md" "$work_dir/new/repo/LICENSE"
    printf '#!/usr/bin/env bash\nexit 0\n' \
        > "$work_dir/new/repo/scripts/validate.sh"
    chmod +x "$work_dir/new/repo/scripts/validate.sh"
    touch "$work_dir/new/repo/.github/workflows/validate.yml"

    (
        cd "$work_dir"
        bash scripts/add-repo.sh new-repo new/repo config new-repo \
            "New repo config" "new,repo" > "$output"
    )

    assert_contains "$work_dir/scripts/repos.txt" "new-repo|new/repo|config"
    assert_contains "$work_dir/scripts/agent-routes.txt" \
        "new-repo|new/repo|New repo config|new,repo"
    assert_contains "$work_dir/scripts/repo-validators.txt" \
        "new/repo|scripts/validate.sh --all"
    assert_contains "$work_dir/REPOSITORIES.md" "### new-repo"
    assert_contains "$output" "Added managed repo new-repo at new/repo."
}


test_manifest_validation_rejects_duplicates
test_validate_repos_rejects_invalid_categories
test_repo_state_classifies_worktrees
test_route_map_rejects_unknown_paths
test_repo_validators_reject_unknown_paths
test_validate_repos_lists_declared_validator
test_validate_repos_reports_missing_validators
test_add_repo_updates_manifests_and_docs
